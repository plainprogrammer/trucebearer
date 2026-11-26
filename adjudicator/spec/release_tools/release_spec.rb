# frozen_string_literal: true

require "date"
require "fileutils"
require "open3"
require "stringio"
require "tmpdir"
require_relative "../../bin/release_tools/release"

# Every example works in a throwaway repository under a temp directory. The
# Git wrapper is given a scrubbed environment so nothing here can read the
# user's git configuration or reach the real repository.
RSpec.describe ReleaseTools::Release do
  GIT_ENV = {
    "GIT_CONFIG_GLOBAL" => File::NULL,
    "GIT_CONFIG_NOSYSTEM" => "1",
    "GIT_AUTHOR_NAME" => "Spec", "GIT_AUTHOR_EMAIL" => "spec@example.invalid",
    "GIT_COMMITTER_NAME" => "Spec", "GIT_COMMITTER_EMAIL" => "spec@example.invalid"
  }.freeze
  GIT_CONFIG = { "core.hooksPath" => File::NULL, "commit.gpgsign" => "false", "tag.gpgsign" => "false" }.freeze

  CHANGELOG = <<~MD
    # Changelog

    Intro.

    ## Unreleased

    ### Added

    - A new thing. (#1)

    ### Changed

    ### Fixed
  MD

  EMPTY_CHANGELOG = "# Changelog\n\n## Unreleased\n\n### Added\n\n### Changed\n\n### Fixed\n"
  VERSION_RB = "module Trucebearer\n  module Adjudicator\n    VERSION = \"0.0.0\"\n  end\nend\n"
  LOCK = "PATH\n  remote: .\n  specs:\n    trucebearer-adjudicator (0.0.0)\n\nCHECKSUMS\n  rake (1.0.0) sha256=abc\n  trucebearer-adjudicator (0.0.0)\n"

  let(:tmp) { Dir.mktmpdir("release-spec") }
  let(:repo) { File.join(tmp, "repo") }
  let(:root) { File.join(repo, "adjudicator") }
  let(:out) { StringIO.new }
  let(:git) { ReleaseTools::Git.new(root, env: GIT_ENV.merge("GIT_CEILING_DIRECTORIES" => tmp), config: GIT_CONFIG) }
  let(:lock_calls) { [] }
  let(:lock_command) do
    calls = lock_calls
    lambda do |dir|
      calls << dir
      version = File.read(File.join(dir, "lib/trucebearer/adjudicator/version.rb"))[/VERSION = "([^"]+)"/, 1]
      path = File.join(dir, "Gemfile.lock")
      File.write(path, File.read(path).gsub(/trucebearer-adjudicator \([^)]*\)/, "trucebearer-adjudicator (#{version})"))
    end
  end
  let(:changelog_text) { CHANGELOG }
  let(:release) do
    described_class.new(root: root, git: git, lock_command: lock_command, today: Date.new(2026, 11, 25), out: out)
  end

  def sh(*args)
    output, status = Open3.capture2e(GIT_ENV.merge("GIT_CEILING_DIRECTORIES" => tmp), "git", "-C", repo, *args)
    raise "git #{args.join(' ')} failed: #{output}" unless status.success?

    output
  end

  def write(relative, text)
    path = File.join(root, relative)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, text)
  end

  before do
    FileUtils.mkdir_p(repo)
    sh("init", "-q", "-b", "main")
    write("lib/trucebearer/adjudicator/version.rb", VERSION_RB)
    write("CHANGELOG.md", changelog_text)
    write("Gemfile.lock", LOCK)
    sh("add", ".")
    sh("-c", "commit.gpgsign=false", "-c", "core.hooksPath=#{File::NULL}", "commit", "-q", "-m", "Start")
  end

  after { FileUtils.remove_entry(tmp) }

  def head_message = sh("log", "-1", "--format=%s").strip
  def status = sh("status", "--porcelain")

  describe "refusals" do
    it "refuses a staged, uncommitted file and changes nothing" do
      write("README.md", "hello")
      sh("add", "adjudicator/README.md")

      expect { release.run("minor") }.to raise_error(ReleaseTools::Error, /not clean|uncommitted/i)
      expect(File.read(File.join(root, "CHANGELOG.md"))).to eq(CHANGELOG)
      expect(lock_calls).to be_empty
      expect(sh("tag")).to be_empty
    end

    it "refuses an untracked file" do
      write("scratch.txt", "x")

      expect { release.run("minor") }.to raise_error(ReleaseTools::Error, /not clean|uncommitted/i)
    end

    it "refuses a change outside the adjudicator folder, because the whole tree must be clean" do
      File.write(File.join(repo, "elsewhere.txt"), "x")

      expect { release.run("minor") }.to raise_error(ReleaseTools::Error, /whole repository/i)
    end

    context "with nothing under Unreleased" do
      let(:changelog_text) { EMPTY_CHANGELOG }

      it "refuses and changes nothing" do
        expect { release.run("minor") }.to raise_error(ReleaseTools::Error, /Unreleased.*empty/i)
        expect(status).to be_empty
        expect(lock_calls).to be_empty
      end
    end

    it "refuses when the tag already exists" do
      sh("tag", "adjudicator-v0.1.0")

      expect { release.run("minor") }.to raise_error(ReleaseTools::Error, /adjudicator-v0\.1\.0.*already exists/)
    end

    it "refuses a version that is not higher than the current one" do
      expect { release.run("0.0.0") }.to raise_error(ReleaseTools::Error, /higher/)
    end
  end

  describe "a dry run" do
    it "prints the plan and touches nothing" do
      release.run("minor", dry_run: true)

      expect(out.string).to include("0.0.0 -> 0.1.0", "## 0.1.0 (2026-11-25)", "- A new thing. (#1)")
      expect(out.string).to include("Release adjudicator-v0.1.0", "git push --atomic origin main adjudicator-v0.1.0")
      expect(status).to be_empty
      expect(sh("tag")).to be_empty
      expect(lock_calls).to be_empty
      expect(head_message).to eq("Start")
    end

    it "still refuses what a real run would refuse" do
      write("scratch.txt", "x")

      expect { release.run("minor", dry_run: true) }.to raise_error(ReleaseTools::Error)
    end
  end

  describe "a real run" do
    before { release.run("minor") }

    it "commits the version file, the CHANGELOG and the lock in one commit" do
      expect(head_message).to eq("Release adjudicator-v0.1.0")
      expect(sh("show", "--name-only", "--format=").split).to contain_exactly(
        "adjudicator/CHANGELOG.md", "adjudicator/Gemfile.lock", "adjudicator/lib/trucebearer/adjudicator/version.rb"
      )
      expect(status).to be_empty
    end

    it "rewrites the version file, the CHANGELOG and the lock" do
      expect(File.read(File.join(root, "lib/trucebearer/adjudicator/version.rb"))).to include('VERSION = "0.1.0"')
      expect(File.read(File.join(root, "CHANGELOG.md"))).to include("## Unreleased\n\n### Added\n\n### Changed\n\n### Fixed\n\n## 0.1.0 (2026-11-25)")
      expect(File.read(File.join(root, "Gemfile.lock"))).to include("trucebearer-adjudicator (0.1.0)")
    end

    it "creates an annotated tag adjudicator-v0.1.0 on the release commit" do
      expect(sh("tag").split).to eq(["adjudicator-v0.1.0"])
      expect(sh("cat-file", "-t", "adjudicator-v0.1.0").strip).to eq("tag")
      expect(sh("rev-parse", "adjudicator-v0.1.0^{commit}")).to eq(sh("rev-parse", "HEAD"))
    end

    it "prints the push command and never runs one" do
      expect(out.string).to include("git push --atomic origin main adjudicator-v0.1.0")
      expect(git.commands.flatten).not_to include("push")
    end
  end

  it "accepts patch and an explicit version too" do
    release.run("patch")

    expect(head_message).to eq("Release adjudicator-v0.0.1")
  end

  it "warns, but goes on, when not on main" do
    sh("checkout", "-q", "-b", "feature")

    release.run("minor")

    expect(out.string).to match(/warning.*feature/i)
    expect(head_message).to eq("Release adjudicator-v0.1.0")
    expect(out.string).to include("git push --atomic origin feature adjudicator-v0.1.0")
  end

  describe "when something fails after files were written" do
    it "restores the files if the lock step fails" do
      failing = ->(_dir) { raise ReleaseTools::Error, "lock failed" }
      broken = described_class.new(root: root, git: git, lock_command: failing, today: Date.new(2026, 11, 25), out: out)

      expect { broken.run("minor") }.to raise_error(ReleaseTools::Error, "lock failed")
      expect(status).to be_empty
      expect(head_message).to eq("Start")
      expect(sh("tag")).to be_empty
    end

    it "restores the files if the lock step changes more than the gem's own version" do
      greedy = lambda do |dir|
        path = File.join(dir, "Gemfile.lock")
        File.write(path, File.read(path).sub("rake (1.0.0)", "rake (2.0.0)"))
      end
      broken = described_class.new(root: root, git: git, lock_command: greedy, today: Date.new(2026, 11, 25), out: out)

      expect { broken.run("minor") }.to raise_error(ReleaseTools::Error, /Gemfile\.lock/)
      expect(status).to be_empty
      expect(head_message).to eq("Start")
    end

    it "says how to recover when the commit worked but tagging failed" do
      allow(git).to receive(:tag).and_raise(ReleaseTools::Error, "tag boom")

      expect { release.run("minor") }.to raise_error(ReleaseTools::Error, /committed.*tag boom.*git tag -a adjudicator-v0\.1\.0/im)
      expect(head_message).to eq("Release adjudicator-v0.1.0")
    end
  end
end

# frozen_string_literal: true

require_relative "changelog"
require_relative "error"
require_relative "git"
require_relative "lock"
require_relative "version"

module ReleaseTools
  # One release of the gem: bump the version, rewrite the CHANGELOG, regenerate
  # the lock, commit and tag. It never pushes and never publishes.
  class Release
    TAG_PREFIX = "adjudicator-v"
    VERSION_FILE = "lib/trucebearer/adjudicator/version.rb"
    CHANGELOG_FILE = "CHANGELOG.md"
    LOCK_FILE = "Gemfile.lock"
    GEM_NAME = "trucebearer-adjudicator"

    # root: the adjudicator/ folder. lock_command: anything that responds to
    # call(root) and regenerates Gemfile.lock there.
    def initialize(root:, git:, lock_command:, today:, out:)
      @root = root
      @git = git
      @lock_command = lock_command
      @today = today
      @out = out
    end

    def run(arg, dry_run: false)
      current = Version.read(File.read(path(VERSION_FILE)))
      version = Version.resolve(arg, current)
      tag = "#{TAG_PREFIX}#{version}"
      message = "Release #{tag}"

      check_clean_tree!
      raise Error, "Tag #{tag} already exists." if @git.tag_exists?(tag)

      changelog = Changelog.release(File.read(path(CHANGELOG_FILE)), version: version, date: @today)
      branch = @git.branch
      @out.puts "Warning: on branch #{branch}, not main. Release from main unless you mean otherwise.\n\n" unless branch == "main"

      if dry_run
        print_plan(current, version, tag, message, changelog)
      else
        apply(version, changelog, message)
        tag!(tag, message)
      end
      @out.puts "\nPush when ready (this script never pushes or publishes):\n  git push --atomic origin #{branch} #{tag}"
    end

    private

    def path(relative) = File.join(@root, relative)

    def files = [VERSION_FILE, CHANGELOG_FILE, LOCK_FILE].map { |relative| path(relative) }

    def check_clean_tree!
      dirty = @git.status_lines
      return if dirty.empty?

      raise Error, "The working tree is not clean. Commit or discard these first " \
                   "(the whole repository is checked, not just adjudicator/):\n  #{dirty.join("\n  ")}"
    end

    def print_plan(current, version, tag, message, changelog)
      released = changelog[/^## #{Regexp.escape(version)} \(.*?(?=^## |\z)/m].strip
      @out.puts <<~PLAN
        Dry run: nothing is written.

        Version: #{current} -> #{version}

        CHANGELOG.md gets this section, under a fresh empty Unreleased:

        #{released}

        Then:
          - regenerate #{LOCK_FILE} (bundle lock --local)
          - git commit -m "#{message}" (#{VERSION_FILE}, #{CHANGELOG_FILE}, #{LOCK_FILE})
          - git tag -a #{tag}
      PLAN
    end

    def apply(version, changelog, message)
      old_lock = File.read(path(LOCK_FILE))
      File.write(path(VERSION_FILE), Version.rewrite_file(File.read(path(VERSION_FILE)), version))
      File.write(path(CHANGELOG_FILE), changelog)
      @lock_command.call(@root)
      check_lock!(old_lock)
      @git.add(files)
      @git.commit(message)
    rescue StandardError
      @git.restore(files)
      raise
    end

    # Only the lines that name the gem itself may change when the version does.
    def check_lock!(old_text)
      old_lines = old_text.lines
      new_lines = File.read(path(LOCK_FILE)).lines
      changed = old_lines.size != new_lines.size || old_lines.zip(new_lines).any? { |old, new| old != new && !old.include?(GEM_NAME) }
      raise Error, "#{LOCK_FILE} changed in more than the gem's own version; nothing was committed." if changed
    end

    def tag!(tag, message)
      @git.tag(tag, message)
    rescue Error => e
      raise Error, "The release was committed (#{message}) but creating the tag failed: #{e.message}\n" \
                   "To finish by hand: git tag -a #{tag} -m \"#{message}\"\n" \
                   "To undo the commit instead: git reset --hard HEAD~1"
    end
  end
end

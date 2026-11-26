# frozen_string_literal: true

require "fileutils"
require "tmpdir"
require_relative "../../bin/release_tools/release"

RSpec.describe ReleaseTools::Lock do
  let(:dir) { Dir.mktmpdir("lock-spec") }

  after { FileUtils.remove_entry(dir) }

  it "writes Gemfile.lock for the Gemfile in the given folder, without the network" do
    File.write(File.join(dir, "Gemfile"), "source \"https://rubygems.org\"\n")

    described_class.call(dir)

    expect(File.read(File.join(dir, "Gemfile.lock"))).to include("BUNDLED WITH")
  end

  it "stops with a message naming bundle install when a gem is not in the local cache" do
    File.write(File.join(dir, "Gemfile"), "source \"https://rubygems.org\"\ngem \"gem-that-is-not-installed-anywhere\"\n")

    expect { described_class.call(dir) }
      .to raise_error(ReleaseTools::Error, /bundle lock --local.*failed.*bundle install/m)
    expect(File.exist?(File.join(dir, "Gemfile.lock"))).to be(false)
  end
end

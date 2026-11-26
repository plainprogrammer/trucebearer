require "spec_helper"

# Reads Gemfile text only. The early-warning job's unfrozen install rewrites Gemfile.lock to a
# path source, so nothing here reads the lockfile or the loaded gem.
RSpec.describe "The gem pin (AC-1.1, AC-2.8a)" do
  gemfile = File.read(File.expand_path("../../Gemfile", __dir__))

  it "pins the git tag with the gemspec glob when the variable is unset" do
    expect(gemfile).to include('git: "https://github.com/plainprogrammer/trucebearer.git"')
    expect(gemfile).to include('tag: "adjudicator-v0.1.0"')
    expect(gemfile).to include('glob: "adjudicator/*.gemspec"')
  end

  it "treats an empty ADJUDICATOR_PATH as unset" do
    expect(gemfile).to include('ENV["ADJUDICATOR_PATH"].to_s.empty?')
  end

  it "uses a path source only for the ADJUDICATOR_PATH branch" do
    paths = gemfile.lines.grep(/\bpath:/)
    expect(paths.size).to eq(1)
    expect(paths.first).to include('path: ENV["ADJUDICATOR_PATH"]')
  end

  it "declares the gem with require: false, so only the boundary file requires it" do
    gem_lines = gemfile.lines.select { |l| l.start_with?("  gem ") && l.include?("trucebearer-adjudicator") }
    expect(gem_lines.size).to eq(2)
    expect(gem_lines).to all(include("require: false"))
  end
end

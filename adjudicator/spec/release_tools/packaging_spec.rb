# frozen_string_literal: true

require "rubygems"

# The release script is development tooling. It must not ship inside the gem.
RSpec.describe "the packaged gem" do
  let(:gemspec) { Gem::Specification.load(File.expand_path("../../trucebearer-adjudicator.gemspec", __dir__)) }

  it "holds nothing from bin/" do
    expect(gemspec.files.grep(%r{\Abin/})).to be_empty
  end

  it "holds no release tooling" do
    expect(gemspec.files.grep(/release_tools/)).to be_empty
  end
end

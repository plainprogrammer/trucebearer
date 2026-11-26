require "spec_helper"
require_relative "../support/stylesheets"

RSpec.describe "The design-system document (AC-9.1, 9.2)" do
  path = File.expand_path("../../docs/design-system.md", __dir__)
  doc = File.exist?(path) ? File.read(path) : ""

  it "exists" do
    expect(File).to exist(path)
  end

  it "has the six parts the screens build to (AC-9.1)" do
    [ "## Palette", "## Power colors", "## Type", "## Units and supply centers", "## Helpers", "## Component catalog" ].each do |heading|
      expect(doc).to include(heading)
    end
  end

  it "names every color token with its hex value on the same line (AC-9.2)" do
    Stylesheets.color_tokens.each do |name, hex|
      line = doc.lines.find { |l| l.include?("`#{name}`") && l.downcase.include?(hex.downcase) }
      expect(line).not_to be_nil, "#{name} #{hex} is not on one line of docs/design-system.md"
    end
  end

  it "says the power values are fixed and that no edition was consulted (AC-4.6)" do
    expect(doc).to match(/fixed/i)
    expect(doc).to match(/no edition/i)
  end
end

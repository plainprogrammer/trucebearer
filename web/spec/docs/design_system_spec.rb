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
    expect(doc).to include("decision 42")
    expect(doc).to match(/fixed/i)
    expect(doc).to include("sampled, traced or looked up")
    expect(doc).to match(/no edition was consulted/i)
  end

  it "lists the four components of Issue 21 as built, with their classes and helpers (AC-9.6)" do
    %w[.join-code .qr-card .power-tile .host-section].each do |klass|
      line = doc.lines.find { |l| l.include?("`#{klass}`") && l.include?("#21") && l.match?(/built/i) }
      expect(line).not_to be_nil, "no catalog line names #{klass} with #21 and built"
    end
    %w[join_code_text qr_card power_tiles].each { |helper| expect(doc).to include(helper) }
  end

  it "lists the three components of Issue 22 as built, with their classes and partials (spec 022 AC-8.5)" do
    %w[.phase-header .banner .confirm].each do |klass|
      line = doc.lines.find { |l| l.include?("`#{klass}`") && l.include?("#22") && l.match?(/built/i) }
      expect(line).not_to be_nil, "no catalog line names #{klass} with #22 and built"
    end
    %w[phases/_header shared/_banner shared/_confirm].each { |partial| expect(doc).to include(partial) }
  end

  it "lists the parts of Issue 23 as built, with their classes and partials (spec 023 AC-6.5)" do
    %w[.unit-row .picker .submit-bar].each do |klass|
      line = doc.lines.find { |l| l.include?("`#{klass}`") && l.include?("#23") && l.match?(/built/i) }
      expect(line).not_to be_nil, "no catalog line names #{klass} with #23 and built"
    end
    expect(doc.lines.find { |l| l.include?("`.picker__draft`") }).not_to be_nil
    expect(doc.lines.find { |l| l.include?("`.save-status`") }).not_to be_nil
    %w[seat_orders/_unit_row order_pickers/_draft seat_orders/_submit_bar shared/_save_status].each { |partial| expect(doc).to include(partial) }
  end

  it "lists the seat status of Issue 24 as built, with its class, helper and partials (spec 024 AC-8.1)" do
    line = doc.lines.find { |l| l.include?("`.seat-status`") && l.include?("#24") && l.match?(/built/i) }

    expect(line).not_to be_nil, "no catalog line names .seat-status with #24 and built"
    expect(line).to include("seat_status").and include("shared/_seat_status").and include("phases/_status")
  end
end

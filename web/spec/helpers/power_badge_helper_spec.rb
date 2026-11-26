require "rails_helper"

RSpec.describe PowerBadgeHelper, type: :helper do
  names = {
    "austria" => "Austria", "england" => "England", "france" => "France", "germany" => "Germany",
    "italy" => "Italy", "russia" => "Russia", "turkey" => "Turkey"
  }

  names.each do |id, name|
    it "prints the name of #{id} as the badge text (AC-4.3)" do
      html = Nokogiri::HTML5.fragment(helper.power_badge(id))
      badge = html.at_css("span.power-badge.power-badge--#{id}")
      expect(badge.text).to eq(name)
    end
  end

  it "accepts a symbol or a string" do
    expect(helper.power_badge(:england)).to eq(helper.power_badge("england"))
  end

  it "raises ArgumentError for an unknown identifier, nil, or an empty string" do
    [ :wales, "wales", nil, "" ].each do |bad|
      expect { helper.power_badge(bad) }.to raise_error(ArgumentError)
    end
  end
end

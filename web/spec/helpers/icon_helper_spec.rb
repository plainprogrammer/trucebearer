require "rails_helper"

RSpec.describe IconHelper, type: :helper do
  it "draws an army as an inline svg labelled with its type and power (AC-7.1)" do
    svg = Nokogiri::HTML5.fragment(helper.unit_icon(:austria, :army)).at_css("svg")
    expect(svg).not_to be_nil
    expect(svg["role"]).to eq("img")
    expect(svg["aria-label"]).to eq("Army, Austria")
  end

  it "raises ArgumentError for a type that is not army or fleet (AC-7.3)" do
    expect { helper.unit_icon(:austria, :submarine) }.to raise_error(ArgumentError)
  end
end

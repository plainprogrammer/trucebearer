require "rails_helper"

RSpec.describe JoinCodeHelper, type: :helper do
  it "shows the code in two groups of three, in mono type (AC-3.1)" do
    html = Nokogiri::HTML5.fragment(helper.join_code_text("ABCDEF"))
    element = html.at_css("p.join-code.mono")

    expect(element.text).to eq("ABC DEF")
    expect(element.css(".join-code__group").map(&:text)).to eq(%w[ABC DEF])
  end
end

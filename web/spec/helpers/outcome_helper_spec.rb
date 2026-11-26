require "rails_helper"

# Spec 025 D6: one table of words of our own for what became of an order.
RSpec.describe OutcomeHelper, type: :helper do
  it "maps exactly the nine documented symbols and the dislodged flag" do
    expect(OutcomeHelper::OUTCOME_WORDS.keys).to match_array(%w[void held no_route bounced succeeded unmatched cut disrupted given dislodged])
  end

  it "words each one (AC-1.4)" do
    words = { "succeeded" => "Succeeded", "bounced" => "Bounced", "no_route" => "No route", "held" => "Held", "given" => "Given",
              "cut" => "Support cut", "unmatched" => "Not used", "disrupted" => "Convoy disrupted",
              "void" => "Not a legal order", "dislodged" => "Dislodged" }

    words.each { |kind, text| expect(helper.outcome_words(kind)).to eq(text) }
  end

  it "fails loudly for a symbol the table lacks" do
    expect { helper.outcome_words("exploded") }.to raise_error(KeyError)
  end

  it "shows Dislodged first and drops a Held tag beside it" do
    row = Struct.new(:result, :dislodged)

    expect(helper.outcome_tags(row.new("held", true))).to eq(%w[dislodged])
    expect(helper.outcome_tags(row.new("bounced", true))).to eq(%w[dislodged bounced])
    expect(helper.outcome_tags(row.new("disrupted", true))).to eq(%w[dislodged disrupted])
    expect(helper.outcome_tags(row.new("succeeded", false))).to eq(%w[succeeded])
  end
end

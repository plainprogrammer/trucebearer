require "rails_helper"

RSpec.describe RulesEngine do
  let(:start) { RulesEngine.starting_position }

  it "gives the classic starting position, with 22 units (AC-2.1)" do
    expect([ start.season, start.year, start.phase ]).to eq([ :spring, 1901, :movement ])
    expect(start.units.size).to eq(22)
  end

  it "checks England's hold in London as legal (AC-2.2)" do
    order = RulesEngine.load_order({ "format" => 1, "type" => "hold", "power" => "england", "at" => "lon" })
    result = RulesEngine.check(start, order)
    expect(result.legal).to be(true)
    expect(result.reasons).to eq([])
  end
end

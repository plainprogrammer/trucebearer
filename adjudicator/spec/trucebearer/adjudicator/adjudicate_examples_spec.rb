# frozen_string_literal: true

require "trucebearer/adjudicator"
require_relative "../../support/board"

# The first spec of the feature: the contract's adjudication example (AC-1.1).
RSpec.describe "TA.adjudicate: the examples of docs/interface.md" do
  let(:start) { TA::Map.classic.starting_position }

  it "adjudicates England's London to the North Sea and Germany's Kiel to Holland (AC-1.1)" do
    orders = [O::Move.new(power: :england, at: :lon, destination: L.new(province: :nth)),
              O::Move.new(power: :germany, at: :kie, destination: L.new(province: :hol))]
    result = TA.adjudicate(start, orders)
    expect(result.outcomes.first(2).map(&:result)).to eq(%i[succeeded succeeded])
    implied = result.outcomes.reject(&:submitted)
    expect(implied.size).to eq(20)
    expect(implied.map(&:order)).to all(be_a(O::Hold))
    expect(implied.map(&:result)).to all(eq(:held))
    expect(result.paradox).to be(false)
    expect(result.position.phase).to eq(:retreat)
    expect(result.position.dislodged_units).to eq([])
    expect(result.position.standoffs).to eq([])
    expect(result.outcomes.drop(2).first(3).map { _1.order.at }).to eq(%i[ank ber bre])
    provinces = result.position.units.map { _1.location.province }
    expect(provinces).to include(:nth, :hol)
    expect(provinces).not_to include(:lon, :kie)
    expect(result.position.ownership).to eq(start.ownership)
  end
end

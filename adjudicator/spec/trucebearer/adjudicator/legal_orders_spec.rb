# frozen_string_literal: true

require "trucebearer/adjudicator"
require_relative "../../support/board"

# TA.legal_orders: the list of the legal orders of one unit (Stories 1 to 4 of spec 012).
# The first example of docs/interface.md `## Legal orders` is the first spec of the feature.
RSpec.describe "TA.legal_orders" do
  let(:start) { TA::Map.classic.starting_position }
  let(:london_fleet) { Board.unit(:england, :fleet, "lon") }

  describe "the first example (AC-1.1, AC-1.2)" do
    it "starts with the hold, then the moves to eng and nth, for England's fleet in London" do
      expect(TA.legal_orders(start, london_fleet).first(3)).to eq(
        [O::Hold.new(power: :england, at: :lon),
         O::Move.new(power: :england, at: :lon, destination: L.new(province: :eng)),
         O::Move.new(power: :england, at: :lon, destination: L.new(province: :nth))]
      )
    end

    it "is empty for a French fleet in London, where no such unit stands" do
      expect(TA.legal_orders(start, Board.unit(:france, :fleet, "lon"))).to eq([])
    end
  end
end

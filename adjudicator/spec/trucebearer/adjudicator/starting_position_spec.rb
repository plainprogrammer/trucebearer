# frozen_string_literal: true

require "json"
require "trucebearer/adjudicator"
require_relative "../../support/board"

RSpec.describe "Map#starting_position" do
  it "round-trips through JSON, with 22 units and 22 owned centers (AC-6.5)" do
    start = TA::Map.classic.starting_position
    rebuilt = TA::Position.from_h(JSON.parse(JSON.generate(start.to_h)))
    expect(rebuilt).to eq(start)
    expect(rebuilt.units.size).to eq(22)
    expect(rebuilt.ownership.size).to eq(22)
  end
end

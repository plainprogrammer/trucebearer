require "rails_helper"
require_relative "../support/rules_helpers"

# Spec 022 D3, FR-8: the app's own rule for the phase that follows a reveal. It is the playtest's own rule, not the gem's.
RSpec.describe RulesEngine, ".next_movement_position" do
  include RulesHelpers

  # A retreat position as the gem returns one: a Turkish army in SER that dislodged an Austrian army, and GAL left empty by a standoff.
  def retreat_hash(season:, year: 1901)
    {
      "format" => 1, "map" => "classic", "season" => season, "year" => year, "phase" => "retreat",
      "units" => [ unit_hash(:turkey, :army, :ser), unit_hash(:russia, :army, :war) ],
      "ownership" => { "ser" => "austria", "war" => "russia" },
      "dislodged_units" => [ { "unit" => unit_hash(:austria, :army, :ser), "attacker_from" => "bul", "by_convoy" => false } ],
      "standoffs" => [ "gal" ]
    }
  end

  def next_from(hash) = RulesEngine.next_movement_position(RulesEngine.load_position(hash))

  it "turns spring into fall of the same year (AC-5.1)" do
    after = next_from(retreat_hash(season: "spring", year: 1901))

    expect([ after.season, after.year, after.phase ]).to eq([ :fall, 1901, :movement ])
  end

  it "turns fall into spring of the following year (AC-5.1)" do
    after = next_from(retreat_hash(season: "fall", year: 1901))

    expect([ after.season, after.year, after.phase ]).to eq([ :spring, 1902, :movement ])
  end

  it "keeps the units and the ownership, and drops the dislodged units and the standoffs (AC-5.3)" do
    before = RulesEngine.load_position(retreat_hash(season: "spring"))
    after = RulesEngine.next_movement_position(before)

    expect(after.units).to eq(before.units)
    expect(after.ownership).to eq(before.ownership)
    expect(after.dislodged_units).to be_empty
    expect(after.standoffs).to be_empty
    expect(before.dislodged_units.size).to eq(1) # the input is not changed
  end

  it "builds a movement position the gem accepts back, through its hash form" do
    after = next_from(retreat_hash(season: "spring"))

    expect(RulesEngine.load_position(after.to_h)).to eq(after)
  end

  it "follows the engine's result for a real spring phase (AC-5.2)" do
    start = RulesEngine.starting_position
    result = RulesEngine.adjudicate(start, [ move(:england, :lon, :nth) ])

    after = RulesEngine.next_movement_position(result.position)

    expect([ after.season, after.year, after.phase ]).to eq([ :fall, 1901, :movement ])
    expect(after.units.map { |unit| unit.location.province }).to include(:nth)
    expect(after.units.map { |unit| unit.location.province }).not_to include(:lon)
    expect(after.ownership).to eq(start.ownership)
    expect(after.standoffs).to be_empty
  end

  it "refuses a position that is not a retreat position, without naming any order (AC-5.6)" do
    expect { RulesEngine.next_movement_position(RulesEngine.starting_position) }
      .to raise_error(RulesEngine::InvalidInput, /retreat position, got .*movement/)
    expect { RulesEngine.next_movement_position(nil) }.to raise_error(RulesEngine::InvalidInput)
  end
end

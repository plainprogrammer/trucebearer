# frozen_string_literal: true

require "json"
require "trucebearer/adjudicator"
require_relative "../../support/board"

# Every Ruby example under `## Adjudicating a movement phase`, `### TA::Outcome` and
# `### TA::Adjudication` of docs/interface.md, with the same expected values (AC-1.1 to
# AC-1.3). The first example is the first spec of the feature. The two examples that need
# a working convoy are pending until #15.
RSpec.describe "TA.adjudicate: the examples of docs/interface.md" do
  let(:start) { TA::Map.classic.starting_position }

  # The position `ln` of docs/interface.md `## Legal orders`.
  let(:ln) do
    TA::Position.new(map: "classic", season: :spring, year: 1901, phase: :movement, ownership: {},
                     dislodged_units: [], standoffs: [],
                     units: [TA::Unit.new(power: :england, type: :army, location: L.new(province: :lon)),
                             TA::Unit.new(power: :england, type: :fleet, location: L.new(province: :nth))])
  end

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

  it "bounces two armies that move into Galicia and leaves it a standoff" do
    bounce = [O::Move.new(power: :russia, at: :war, destination: L.new(province: :gal)),
              O::Move.new(power: :austria, at: :vie, destination: L.new(province: :gal))]
    result = TA.adjudicate(start, bounce)
    expect(result.outcomes.first(2).map(&:result)).to eq(%i[bounced bounced])
    expect(result.position.standoffs).to eq([:gal])
  end

  it "raises for two orders of one power for one province, and for a retreat position" do
    expect { TA.adjudicate(start, [O::Hold.new(power: :england, at: :lon), O::Hold.new(power: :england, at: :lon)]) }
      .to raise_error(TA::InvalidInput)
    retreat = TA.adjudicate(start, []).position
    expect { TA.adjudicate(retreat, []) }.to raise_error(TA::InvalidInput)
  end

  it "voids an order from a power that doesn't own the unit, and holds the unit" do
    result = TA.adjudicate(start, [O::Hold.new(power: :france, at: :lon)])
    expect(result.outcomes.first.result).to eq(:void)
    expect(result.outcomes.find { _1.order.at == :lon && !_1.submitted }.result).to eq(:held)
  end

  it "sends an army by land when no convoy is ordered (the by_land example)" do
    by_land = TA.adjudicate(ln, [O::Move.new(power: :england, at: :lon, destination: L.new(province: :yor))])
    expect(by_land.outcomes.map(&:result)).to eq(%i[succeeded held])
  end

  it "dislodges a holding army with a supported move (the Vienna example)" do
    vienna = TA::Position.new(map: "classic", season: :spring, year: 1901, phase: :movement, ownership: {},
                              dislodged_units: [], standoffs: [],
                              units: [TA::Unit.new(power: :austria, type: :army, location: L.new(province: :vie)),
                                      TA::Unit.new(power: :germany, type: :army, location: L.new(province: :boh)),
                                      TA::Unit.new(power: :germany, type: :army, location: L.new(province: :tyr))])
    result = TA.adjudicate(vienna, [O::Hold.new(power: :austria, at: :vie),
                                    O::Move.new(power: :germany, at: :boh, destination: L.new(province: :vie)),
                                    O::SupportMove.new(power: :germany, at: :tyr, from: :boh, to: :vie)])
    expect([result.outcomes.first.result, result.outcomes.first.dislodged]).to eq([:held, true])
    expect(result.position.dislodged_units).to eq(
      [TA::DislodgedUnit.new(unit: TA::Unit.new(power: :austria, type: :army, location: L.new(province: :vie)),
                             attacker_from: :boh, by_convoy: false)]
    )
    expect(result.position.units.find { _1.location.province == :vie }.power).to eq(:germany)
  end

  it "gives the Outcome example's hash form" do
    outcome = TA::Outcome.new(order: O::Hold.new(power: :england, at: :lon), result: :held, submitted: false, dislodged: false)
    expect(outcome.to_h).to eq(
      "order" => { "format" => 1, "type" => "hold", "power" => "england", "at" => "lon" },
      "result" => "held", "submitted" => false, "dislodged" => false
    )
  end

  it "gives the Adjudication example's hash form" do
    pos = TA::Position.new(map: "classic", season: :spring, year: 1901, phase: :movement,
                           units: [TA::Unit.new(power: :england, type: :fleet, location: L.new(province: :lon))],
                           ownership: { lon: :england }, dislodged_units: [], standoffs: [])
    adjudication = TA.adjudicate(pos, [O::Hold.new(power: :england, at: :lon)])
    expect(adjudication.to_h).to eq(
      "format" => 1,
      "outcomes" => [{ "order" => { "format" => 1, "type" => "hold", "power" => "england", "at" => "lon" },
                       "result" => "held", "submitted" => true, "dislodged" => false }],
      "paradox" => false,
      "position" => { "format" => 1, "map" => "classic", "season" => "spring", "year" => 1901, "phase" => "retreat",
                      "units" => [{ "power" => "england", "type" => "fleet", "location" => { "province" => "lon", "coast" => nil } }],
                      "ownership" => { "lon" => "england" }, "dislodged_units" => [], "standoffs" => [] }
    )
    expect(TA::Adjudication.from_h(JSON.parse(JSON.generate(adjudication.to_h)))).to eq(adjudication)
  end

  # AC-1.3: needs a working convoy, which arrives with #15. These run and fail as expected;
  # when #15 makes one pass, RSpec flags it until the `pending` is removed.
  it "sends an army by sea when a fleet convoys it (the by_sea example)" do
    pending "convoys: #15"
    by_sea = TA.adjudicate(ln, [O::Move.new(power: :england, at: :lon, destination: L.new(province: :yor)),
                                O::Convoy.new(power: :england, at: :nth, from: :lon, to: :yor)])
    expect(by_sea.outcomes.map(&:result)).to eq(%i[succeeded given])
  end

  it "flags the convoy paradox of the paradox_pos example" do
    pending "convoys: #15"
    paradox_pos = TA::Position.new(map: "classic", season: :spring, year: 1901, phase: :movement, ownership: {},
                                   dislodged_units: [], standoffs: [],
                                   units: [TA::Unit.new(power: :england, type: :fleet, location: L.new(province: :lon)),
                                           TA::Unit.new(power: :england, type: :fleet, location: L.new(province: :wal)),
                                           TA::Unit.new(power: :france, type: :army, location: L.new(province: :bre)),
                                           TA::Unit.new(power: :france, type: :fleet, location: L.new(province: :eng))])
    result = TA.adjudicate(paradox_pos, [
      O::Move.new(power: :england, at: :wal, destination: L.new(province: :eng)),
      O::SupportMove.new(power: :england, at: :lon, from: :wal, to: :eng),
      O::Move.new(power: :france, at: :bre, destination: L.new(province: :lon)),
      O::Convoy.new(power: :france, at: :eng, from: :bre, to: :lon)
    ])
    expect(result.paradox).to be(true)
  end

  describe "the impossible outcomes and adjudications of the contract" do
    let(:hold) { O::Hold.new(power: :england, at: :lon) }
    let(:pos) do
      TA::Position.new(map: "classic", season: :spring, year: 1901, phase: :movement,
                       units: [TA::Unit.new(power: :england, type: :fleet, location: L.new(province: :lon))],
                       ownership: { lon: :england }, dislodged_units: [], standoffs: [])
    end

    def held(power, at, submitted) = TA::Outcome.new(order: O::Hold.new(power: power, at: at), result: :held, submitted: submitted, dislodged: false)

    it "refuses the impossible outcomes of ### Impossible objects" do
      expect { TA::Outcome.new(order: hold, result: :bounced, submitted: true, dislodged: false) }.to raise_error(TA::InvalidInput)
      expect { TA::Outcome.new(order: hold, result: :void, submitted: true, dislodged: true) }.to raise_error(TA::InvalidInput)
      expect { TA::Outcome.new(order: hold, result: :void, submitted: false, dislodged: false) }.to raise_error(TA::InvalidInput)
      move = O::Move.new(power: :england, at: :lon, destination: L.new(province: :nth))
      expect { TA::Outcome.new(order: move, result: :succeeded, submitted: true, dislodged: true) }.to raise_error(TA::InvalidInput)
    end

    it "refuses the impossible adjudications of ### Impossible objects" do
      expect { TA::Adjudication.new(outcomes: [held(:france, :bre, false), held(:england, :lon, true)], paradox: false, position: pos) }
        .to raise_error(TA::InvalidInput)
      expect { TA::Adjudication.new(outcomes: [held(:france, :bre, false), held(:england, :bel, false)], paradox: false, position: pos) }
        .to raise_error(TA::InvalidInput)
      expect { TA::Adjudication.new(outcomes: [held(:england, :lon, true), held(:england, :lon, true)], paradox: false, position: pos) }
        .to raise_error(TA::InvalidInput)
    end
  end
end

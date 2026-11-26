# frozen_string_literal: true

require "json"
require "trucebearer/adjudicator"
require_relative "../../support/board"

# Every Ruby example in docs/interface.md that is about the value objects built by
# issue #10 (Location, Unit, DislodgedUnit, Position, Order and its six classes,
# Canonical order, Impossible objects, Map#starting_position, and the from_h examples
# under Errors), run as a spec. Each example is built as the document builds it.
#
# Excluded, because they belong to later issues (AC-7.3):
#   - both TA::CheckResult examples, and the three CheckResult lines at the end of
#     "Impossible objects" (#11);
#   - the TA::Outcome and TA::Adjudication examples (#14);
#   - the TA.check, TA.legal_orders and TA.adjudicate calls in their own sections.
RSpec.describe "docs/interface.md examples" do
  describe "TA::Location, TA::Unit and TA::DislodgedUnit" do
    it "gives the hash forms the document shows" do
      expect(L.new(province: :spa, coast: :nc).to_h).to eq("province" => "spa", "coast" => "nc")
      expect(L.new(province: :bud).to_h).to eq("province" => "bud", "coast" => nil)
      expect(TA::Unit.new(power: :russia, type: :fleet, location: L.new(province: :stp, coast: :sc)).to_h)
        .to eq("power" => "russia", "type" => "fleet", "location" => { "province" => "stp", "coast" => "sc" })
      expect(TA::DislodgedUnit.new(
        unit: TA::Unit.new(power: :austria, type: :army, location: L.new(province: :ser)),
        attacker_from: :bul, by_convoy: false
      ).to_h).to eq("unit" => { "power" => "austria", "type" => "army", "location" => { "province" => "ser", "coast" => nil } },
                    "attacker_from" => "bul", "by_convoy" => false)
    end
  end

  describe "TA::Position, Canonical order and the Errors examples" do
    let(:army) { TA::Unit.new(power: :austria, type: :army, location: L.new(province: :bud)) }
    let(:fleet) { TA::Unit.new(power: :russia, type: :fleet, location: L.new(province: :stp, coast: :sc)) }
    let(:spring) { { map: "classic", season: :spring, year: 1901, phase: :movement, dislodged_units: [], standoffs: [] } }
    let(:a) { TA::Position.new(**spring, units: [army, fleet], ownership: { bud: :austria, stp: :russia }) }
    let(:b) { TA::Position.new(**spring, units: [fleet, army], ownership: { stp: :russia, bud: :austria }) }

    it "gives the position hash and round trip of the TA::Position example" do
      position = TA::Position.new(
        map: "classic", season: :spring, year: 1901, phase: :movement,
        units: [TA::Unit.new(power: :austria, type: :army, location: L.new(province: :bud)),
                TA::Unit.new(power: :russia, type: :fleet, location: L.new(province: :stp, coast: :sc))],
        ownership: { bud: :austria, stp: :russia },
        dislodged_units: [], standoffs: []
      )
      expect(position.to_h).to eq(
        "format" => 1, "map" => "classic", "season" => "spring", "year" => 1901, "phase" => "movement",
        "units" => [{ "power" => "austria", "type" => "army", "location" => { "province" => "bud", "coast" => nil } },
                    { "power" => "russia", "type" => "fleet", "location" => { "province" => "stp", "coast" => "sc" } }],
        "ownership" => { "bud" => "austria", "stp" => "russia" },
        "dislodged_units" => [], "standoffs" => []
      )
      expect(TA::Position.from_h(JSON.parse(JSON.generate(position.to_h))) == position).to be(true)
    end

    it "gives the Canonical order results" do
      expect(a == b).to be(true)
      expect(a.to_h == b.to_h).to be(true)
      expect(b.units.map { _1.location.province }).to eq(%i[bud stp])
      expect(b.to_h["ownership"].keys).to eq(%w[bud stp])
    end

    it "raises for each impossible object the document lists" do
      two_in_bur = [TA::Unit.new(power: :france, type: :army, location: L.new(province: :bur)),
                    TA::Unit.new(power: :germany, type: :army, location: L.new(province: :bur))]
      expect { TA::Position.new(**spring, ownership: {}, units: two_in_bur) }.to raise_error(TA::InvalidInput)
      expect { TA::Unit.new(power: :germany, type: :fleet, location: L.new(province: :mun)) }.to raise_error(TA::InvalidInput)
      expect { TA::Unit.new(power: :england, type: :army, location: L.new(province: :nth)) }.to raise_error(TA::InvalidInput)
      expect { TA::Unit.new(power: :france, type: :army, location: L.new(province: :spa, coast: :nc)) }.to raise_error(TA::InvalidInput)
      expect { TA::Unit.new(power: :france, type: :fleet, location: L.new(province: :spa)) }.to raise_error(TA::InvalidInput)
      expect { L.new(province: :par, coast: :nc) }.to raise_error(TA::InvalidInput)
      expect { L.new(province: :bul, coast: :nc) }.to raise_error(TA::InvalidInput)
      expect { L.new(province: :xyz) }.to raise_error(TA::InvalidInput)
      expect { TA::Position.from_h(JSON.parse(JSON.generate(a.to_h)).merge("map" => "modern")) }.to raise_error(TA::InvalidInput)
      expect { TA::Position.new(**spring, units: [army], ownership: { bur: :france }) }.to raise_error(TA::InvalidInput)
      expect { TA::Position.new(**spring.merge(standoffs: [:bur]), units: [army], ownership: {}) }.to raise_error(TA::InvalidInput)
      expect do
        TA::Position.new(**spring.merge(dislodged_units: [TA::DislodgedUnit.new(unit: fleet, attacker_from: :fin, by_convoy: false)]),
                         units: [army], ownership: {})
      end.to raise_error(TA::InvalidInput)
    end
  end

  describe "TA::Order and its six classes, and the format examples" do
    it "gives the examples of the Value objects introduction and the Errors section" do
      expect { O.from_h({ "type" => "hold", "power" => "england", "at" => "lon" }) }.to raise_error(TA::InvalidInput, /"format"/)
      expect { O.from_h({ "format" => 2, "type" => "hold", "power" => "england", "at" => "lon" }) }.to raise_error(TA::InvalidInput, /unknown format 2/)
      expect { O.from_h({ "format" => 1, "type" => "hold", "power" => "england" }) }.to raise_error(TA::InvalidInput, /"at"/)
      expect { O.from_h({ "format" => 1, "type" => "hold", "power" => "england", "at" => "xyz" }) }.to raise_error(TA::InvalidInput, /"xyz"/)
      expect do
        O.from_h({ "format" => 1, "type" => "hold", "power" => "england", "at" => { "province" => "spa", "coast" => "nc" } })
      end.to raise_error(TA::InvalidInput, /#{Regexp.escape({ "province" => "spa", "coast" => "nc" }.inspect)}/)
    end

    it "gives the TA::Order examples" do
      expect(O.from_h({ "format" => 1, "type" => "hold", "power" => "england", "at" => "lon" }))
        .to eq(O::Hold.new(power: :england, at: :lon))
      expect(O.from_h({ "format" => 1, "type" => "hold", "power" => "england", "at" => "lon" }).inspect)
        .to eq("#<data Trucebearer::Adjudicator::Order::Hold power=:england, at=:lon>")
      expect { O::Move.from_h({ "format" => 1, "type" => "hold", "power" => "england", "at" => "lon" }) }.to raise_error(TA::InvalidInput)
      expect(O::Hold.new(power: :england, at: :lon).to_h).to eq({ "format" => 1, "type" => "hold", "power" => "england", "at" => "lon" })
      expect(O::Move.new(power: :france, at: :mao, destination: L.new(province: :spa, coast: :nc)).to_h)
        .to eq({ "format" => 1, "type" => "move", "power" => "france", "at" => "mao", "destination" => { "province" => "spa", "coast" => "nc" } })
      expect(O::MoveViaConvoy.new(power: :england, at: :lon, to: :wal).to_h)
        .to eq({ "format" => 1, "type" => "move_via_convoy", "power" => "england", "at" => "lon", "to" => "wal" })
      expect(O::SupportHold.new(power: :germany, at: :mun, target: :ber).to_h)
        .to eq({ "format" => 1, "type" => "support_hold", "power" => "germany", "at" => "mun", "target" => "ber" })
      expect(O::SupportMove.new(power: :france, at: :por, from: :mao, to: :spa).to_h)
        .to eq({ "format" => 1, "type" => "support_move", "power" => "france", "at" => "por", "from" => "mao", "to" => "spa" })
      expect(O::Convoy.new(power: :england, at: :nth, from: :lon, to: :nwy).to_h)
        .to eq({ "format" => 1, "type" => "convoy", "power" => "england", "at" => "nth", "from" => "lon", "to" => "nwy" })
    end
  end

  describe "Map#starting_position and the year example" do
    it "gives the values of the Map section (overview block and subsection)" do
      map = TA::Map.classic
      start = map.starting_position
      expect([start.season, start.year, start.phase]).to eq([:spring, 1901, :movement])
      expect(start.units.size).to eq(22)
      expect(start.ownership.size).to eq(22)
      expect(start.ownership[:lon]).to eq(:england)
      expect(start.ownership.key?(:bel)).to be(false)
    end

    it "raises for the year example under Errors" do
      start = TA::Map.classic.starting_position
      expect { TA::Position.from_h(start.to_h.merge("year" => "1901")) }.to raise_error(TA::InvalidInput, /"1901"/)
    end
  end

  describe "the Impossible objects list names the two stricter rules (AC-8.7)" do
    let(:interface) { File.read(File.expand_path("../../../docs/interface.md", __dir__)) }
    let(:impossible) { interface[/^### Impossible objects\n(.*?)^## Checking an order/m, 1] }

    it "lists the same standoff province twice, and two dislodged units in one province" do
      expect(impossible).to include("standoffs: [:bur, :bur]")
      expect(impossible).to include("Two dislodged units in one province")
    end

    it "raises for both examples" do
      army = Board.army
      fleet = Board.fleet
      spring = Board.spring
      expect { TA::Position.new(**spring.merge(phase: :retreat, standoffs: [:bur, :bur]), units: [army], ownership: {}) }.to raise_error(TA::InvalidInput)
      expect do
        TA::Position.new(**spring.merge(phase: :retreat, dislodged_units: [fleet, fleet].map { TA::DislodgedUnit.new(unit: _1, attacker_from: :fin, by_convoy: false) }),
                         units: [army], ownership: {})
      end.to raise_error(TA::InvalidInput)
    end
  end

  describe "constructions in the excluded sections that need only these objects (AC-7.5)" do
    # Every unit and order those sections build, so that #11 and #14 can use the examples as they stand.
    unit = ->(power, type, province, coast = nil) { TA::Unit.new(power: power, type: type, location: L.new(province: province, coast: coast)) }
    move = ->(power, at, to, coast = nil) { O::Move.new(power: power, at: at, destination: L.new(province: to, coast: coast)) }
    base = { map: "classic", season: :spring, year: 1901, phase: :movement, ownership: {}, dislodged_units: [], standoffs: [] }

    it "builds the positions" do
      start = TA::Map.classic.starting_position
      expect(TA::Position.from_h(start.to_h.merge("phase" => "retreat")).phase).to eq(:retreat) # retreat
      at_sea = TA::Position.new(**base, units: [unit.call(:france, :fleet, :mao), unit.call(:france, :fleet, :gol)])
      ln = TA::Position.new(**base, units: [unit.call(:england, :army, :lon), unit.call(:england, :fleet, :nth)])
      pos = TA::Position.new(map: "classic", season: :spring, year: 1901, phase: :movement,
                             units: [unit.call(:england, :fleet, :lon)], ownership: { lon: :england }, dislodged_units: [], standoffs: [])
      vienna = TA::Position.new(**base, units: [unit.call(:austria, :army, :vie), unit.call(:germany, :army, :boh), unit.call(:germany, :army, :tyr)])
      paradox_pos = TA::Position.new(**base, units: [unit.call(:england, :fleet, :lon), unit.call(:england, :fleet, :wal),
                                                     unit.call(:france, :army, :bre), unit.call(:france, :fleet, :eng)])
      expect([at_sea, ln, pos, vienna, paradox_pos].map { _1.units.size }).to eq([2, 2, 1, 3, 4])
    end

    it "builds the units used with legal orders" do
      [unit.call(:england, :fleet, :lon), unit.call(:france, :fleet, :lon), unit.call(:austria, :army, :vie),
       unit.call(:france, :fleet, :mao), unit.call(:england, :army, :lon)].each { |built| expect(built).to be_frozen }
      expect(TA::DislodgedUnit.new(unit: unit.call(:austria, :army, :vie), attacker_from: :boh, by_convoy: false)).to be_frozen
    end

    it "builds the orders used with checking, legal orders and adjudication" do
      orders = [
        O::Hold.new(power: :england, at: :lon), O::Hold.new(power: :france, at: :lon), O::Hold.new(power: :england, at: :wal),
        O::Hold.new(power: :austria, at: :vie),
        move.call(:england, :lon, :bel), move.call(:russia, :sev, :rum), move.call(:france, :mar, :spa, :nc),
        move.call(:france, :mao, :spa), move.call(:france, :gol, :spa, :nc), move.call(:england, :lon, :eng),
        move.call(:england, :lon, :nth), move.call(:germany, :kie, :hol), move.call(:russia, :war, :gal),
        move.call(:austria, :vie, :gal), move.call(:england, :lon, :yor), move.call(:england, :wal, :eng),
        move.call(:france, :bre, :lon), move.call(:germany, :boh, :vie),
        O::MoveViaConvoy.new(power: :england, at: :lvp, to: :wal),
        O::SupportMove.new(power: :austria, at: :vie, from: :war, to: :gal),
        O::SupportMove.new(power: :england, at: :lon, from: :wal, to: :eng),
        O::SupportMove.new(power: :germany, at: :tyr, from: :boh, to: :vie),
        O::SupportHold.new(power: :germany, at: :mun, target: :ber), O::SupportHold.new(power: :germany, at: :mun, target: :sil),
        O::Convoy.new(power: :england, at: :lon, from: :lvp, to: :bel), O::Convoy.new(power: :england, at: :nth, from: :lon, to: :yor),
        O::Convoy.new(power: :france, at: :eng, from: :bre, to: :lon)
      ]
      expect(orders.size).to eq(27)
      orders.each { |order| expect(O.from_h(JSON.parse(JSON.generate(order.to_h)))).to eq(order) }
    end
  end
end

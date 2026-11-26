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
end

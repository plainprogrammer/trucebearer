# frozen_string_literal: true

require "json"
require "trucebearer/adjudicator"
require_relative "../../support/board"

RSpec.describe Trucebearer::Adjudicator::Position do
  let(:army) { Board.army }
  let(:fleet) { Board.fleet }
  let(:fields) { Board.spring.merge(units: [army, fleet], ownership: { bud: :austria, stp: :russia }) }
  let(:position) { described_class.new(**fields) }
  let(:valid_hash) { position.to_h }

  def refuse(message = nil, **changes)
    expect { described_class.new(**fields.merge(changes)) }.to raise_error(TA::InvalidInput, message || //)
  end

  describe ".new" do
    it "freezes the object and its fields, and copies what it is given (AC-2.1)" do
      units = [fleet, army]
      ownership = { stp: :russia, bud: :austria }
      map = +"classic"
      built = described_class.new(**fields.merge(units: units, ownership: ownership, map: map))
      expect(built).to be_frozen
      expect([built.map, built.units, built.ownership, built.dislodged_units, built.standoffs]).to all(be_frozen)
      expect([units, ownership, map].map(&:frozen?)).to eq([false, false, false])
      units << army
      ownership[:ber] = :germany
      map << "x"
      expect(built).to eq(position)
      expect(built.map).to eq("classic")
    end

    it "keeps the eight fields, in the order the interface gives them" do
      expect(described_class.members).to eq(%i[map season year phase units ownership dislodged_units standoffs])
    end

    it "is equal, with the same hash, to a position with the same contents (AC-2.3)" do
      a = described_class.new(**Board.spring, units: [army, fleet], ownership: { bud: :austria, stp: :russia })
      b = described_class.new(**Board.spring, units: [fleet, army], ownership: { stp: :russia, bud: :austria })
      expect([a == b, a.eql?(b), a.hash == b.hash, a.to_h == b.to_h]).to eq([true, true, true, true])
      expect(b.units.map { _1.location.province }).to eq(%i[bud stp])
      expect(b.ownership.keys).to eq(%i[bud stp])
      expect(b.to_h["ownership"].keys).to eq(%w[bud stp])
    end

    it "sorts units and dislodged units by province, and standoffs by identifier (AC-2.4)" do
      spa = TA::Unit.new(power: :france, type: :fleet, location: L.new(province: :spa, coast: :sc))
      stp = TA::Unit.new(power: :russia, type: :army, location: L.new(province: :stp))
      d_stp = TA::DislodgedUnit.new(unit: stp, attacker_from: :fin, by_convoy: false)
      d_spa = TA::DislodgedUnit.new(unit: spa, attacker_from: :mar, by_convoy: true)
      built = described_class.new(**fields.merge(phase: :retreat, units: [stp, spa], dislodged_units: [d_stp, d_spa], standoffs: %i[tyr bur ruh]))
      expect(built.units).to eq([spa, stp])
      expect(built.dislodged_units).to eq([d_spa, d_stp])
      expect(built.standoffs).to eq(%i[bur ruh tyr])
      expect(described_class.from_h(built.to_h).units).to eq([spa, stp])
    end

    it "sorts the ownership it holds, as to_h writes it (AC-2.10)" do
      built = described_class.new(**fields.merge(ownership: { stp: :russia, bud: :austria, ank: :turkey }))
      expect(built.ownership.keys).to eq(%i[ank bud stp])
    end

    it "rejects a bad map, season, phase or year, naming the value (AC-2.6)" do
      refuse(/:classic/, map: :classic)
      refuse(/"modern"/, map: "modern")
      refuse(/"spring"/, season: "spring")
      refuse(/:summer/, season: :summer)
      refuse(/:build/, phase: :build)
      ["1901", 1901.0, nil].each { |bad| refuse(/#{Regexp.escape(bad.inspect)}/, year: bad) }
    end

    it "rejects a list field of the wrong kind (AC-2.6)" do
      refuse(/"units"/, units: "none")
      refuse(/\{"power"/, units: [army.to_h])
      refuse(/"dislodged_units"/, dislodged_units: nil)
      refuse(/"x"/, dislodged_units: ["x"])
      refuse(/1/, standoffs: [1])
      refuse(/"standoffs"/, standoffs: "bur")
      refuse(/"bur"/, standoffs: ["bur"])
      refuse(/:xyz/, standoffs: [:xyz])
      refuse(/"ownership"/, ownership: [])
    end

    it "rejects bad ownership keys and values (AC-2.7)" do
      refuse(/"bud"/, ownership: { "bud" => :austria })
      refuse(/:xyz/, ownership: { xyz: :austria })
      refuse(/"austria"/, ownership: { bud: "austria" })
      refuse(/nil/, ownership: { bel: nil })
      refuse(/:atlantis/, ownership: { bud: :atlantis })
    end

    it "raises ArgumentError for a missing or unknown keyword (AC-1.10)" do
      expect { described_class.new(**fields.reject { |k, _| k == :standoffs }) }.to raise_error(ArgumentError)
      expect { described_class.new(**fields.reject { |k, _| k == :dislodged_units }) }.to raise_error(ArgumentError)
      expect { described_class.new(**fields.merge(extra: 1)) }.to raise_error(ArgumentError)
    end
  end

  describe "#to_h" do
    it "gives the hash of the interface example, in its key order (AC-2.2)" do
      expect(valid_hash).to eq(
        "format" => 1, "map" => "classic", "season" => "spring", "year" => 1901, "phase" => "movement",
        "units" => [{ "power" => "austria", "type" => "army", "location" => { "province" => "bud", "coast" => nil } },
                    { "power" => "russia", "type" => "fleet", "location" => { "province" => "stp", "coast" => "sc" } }],
        "ownership" => { "bud" => "austria", "stp" => "russia" },
        "dislodged_units" => [], "standoffs" => []
      )
      expect(valid_hash.keys).to eq(%w[format map season year phase units ownership dislodged_units standoffs])
      expect(described_class.from_h(JSON.parse(JSON.generate(valid_hash)))).to eq(position)
    end

    it "writes only plain data, with string keys all the way down (AC-4.3)" do
      plain = lambda do |value|
        case value
        when Hash then value.all? { |k, v| k.is_a?(String) && plain.call(v) }
        when Array then value.all? { plain.call(_1) }
        else [String, Integer, true, false, nil].any? { |type| type === value }
        end
      end
      expect(plain.call(valid_hash)).to be(true)
      expect(valid_hash["units"].first).not_to have_key("format")
    end
  end

  describe ".from_h" do
    let(:retreat_fields) do
      d_army = TA::DislodgedUnit.new(unit: TA::Unit.new(power: :austria, type: :army, location: L.new(province: :ser)), attacker_from: :bul, by_convoy: false)
      d_fleet = TA::DislodgedUnit.new(unit: TA::Unit.new(power: :england, type: :fleet, location: L.new(province: :nth)), attacker_from: :nwy, by_convoy: true)
      Board.spring.merge(phase: :retreat, units: [army], ownership: { bud: :austria },
                         dislodged_units: [d_army, d_fleet], standoffs: %i[bur tyr])
    end

    it "round-trips positions of every phase through JSON (AC-2.5)" do
      empty = described_class.new(**Board.spring, units: [], ownership: {})
      fall = described_class.new(**Board.spring.merge(season: :fall, phase: :adjustment), units: [army], ownership: { bud: :austria, vie: :austria })
      [position, described_class.new(**retreat_fields), fall, empty].each do |built|
        expect(described_class.from_h(JSON.parse(JSON.generate(built.to_h)))).to eq(built)
      end
    end

    it "refuses a bad shape, naming the key or value (AC-2.8)" do
      bad = lambda do |changes, pattern|
        expect { described_class.from_h(valid_hash.merge(changes)) }.to raise_error(TA::InvalidInput, pattern)
      end
      bad.call({ "season" => :spring }, /:spring/)
      bad.call({ "year" => "1901" }, /"1901"/)
      bad.call({ "year" => 1901.5 }, /1901\.5/)
      bad.call({ "units" => "none" }, /"none"/)
      bad.call({ "dislodged_units" => {} }, /\{\}/)
      bad.call({ "standoffs" => "bur" }, /"bur"/)
      bad.call({ "units" => ["bud"] }, /"bud"/)
      bad.call({ "units" => [valid_hash["units"].first.reject { |k, _| k == "type" }] }, /"type"/)
      bad.call({ "units" => [valid_hash["units"].first.merge("extra" => 1)] }, /"extra"/)
      bad.call({ "units" => [valid_hash["units"].first.merge("format" => 1)] }, /"format"/)
      bad.call({ "units" => [valid_hash["units"].first.merge("location" => { "province" => "bud", "coast" => nil, "format" => 1 })] }, /"format"/)
      bad.call({ "standoffs" => [:bur] }, /:bur/)
      bad.call({ "standoffs" => [1] }, /1/)
      bad.call({ "dislodged_units" => ["x"] }, /"x"/)
      bad.call({ "ownership" => [] }, /\[\]/)
      bad.call({ "ownership" => { bud: "austria" } }, /:bud/)
      bad.call({ "ownership" => { "bud" => :austria } }, /:austria/)
      bad.call({ "ownership" => { "bud" => nil } }, /nil/)
      bad.call({ "map" => :classic }, /:classic/)
      expect { described_class.from_h(valid_hash.reject { |k, _| k == "year" }) }.to raise_error(TA::InvalidInput, /"year"/)
      expect { described_class.from_h(valid_hash.merge("extra" => 1)) }.to raise_error(TA::InvalidInput, /"extra"/)
      expect { described_class.from_h(valid_hash.transform_keys(&:to_sym)) }.to raise_error(TA::InvalidInput, /"format"/)
      expect { described_class.from_h("position") }.to raise_error(TA::InvalidInput, /"position"/)
    end

    it "checks the format first, and never accepts a hash for its format alone (AC-4.2, AC-4.5)" do
      expect { described_class.from_h(valid_hash.reject { |k, _| k == "format" }) }.to raise_error(TA::InvalidInput, /"format"/)
      [2, 0, "1", 1.0, nil].each do |bad|
        expect { described_class.from_h(valid_hash.merge("format" => bad)) }.to raise_error(TA::InvalidInput, /#{Regexp.escape(bad.inspect)}/)
      end
      expect { described_class.from_h(valid_hash.merge("year" => "1901")) }.to raise_error(TA::InvalidInput)
    end

    it "leaves its argument alone, accepts a frozen one, and holds no reference to it (AC-2.9)" do
      parsed = JSON.parse(JSON.generate(valid_hash))
      before = Marshal.load(Marshal.dump(parsed))
      built = described_class.from_h(parsed)
      expect(parsed).to eq(before)
      parsed["units"] << {}
      parsed["ownership"]["ber"] = "germany"
      parsed["map"] << "x"
      expect(built).to eq(position)
      expect(described_class.from_h(Ractor.make_shareable(JSON.parse(JSON.generate(valid_hash))))).to eq(position)
    end
  end

  describe "impossible positions (Story 5)" do
    it "refuses two units in one province, naming it, and lets a dislodged unit share one (AC-5.1)" do
      bur = ->(power) { TA::Unit.new(power: power, type: :army, location: L.new(province: :bur)) }
      refuse(/:bur/, units: [bur.call(:france), bur.call(:germany)], ownership: {})
      stp = [TA::Unit.new(power: :russia, type: :army, location: L.new(province: :stp)), fleet]
      refuse(/:stp/, units: stp, ownership: {})
      dislodged = TA::DislodgedUnit.new(unit: army, attacker_from: :boh, by_convoy: false)
      expect(described_class.new(**fields.merge(phase: :retreat, dislodged_units: [dislodged]))).to be_a(described_class)
    end

    it "refuses a map other than classic, from new and from from_h (AC-5.5)" do
      refuse(/"modern"/, map: "modern")
      expect { described_class.from_h(valid_hash.merge("map" => "modern")) }.to raise_error(TA::InvalidInput, /"modern"/)
    end

    it "refuses ownership of every province that is not a supply center, and accepts every supply center (AC-5.6)" do
      not_centers = Board.provinces - TA::Map.classic.supply_centers
      expect(not_centers.size).to eq(41)
      not_centers.each { |id| refuse(/#{id.inspect}/, ownership: { id => :france }) }
      expect(TA::Map.classic.supply_centers.size).to eq(34)
      TA::Map.classic.supply_centers.each do |id|
        expect(described_class.new(**fields.merge(ownership: { id => :france }))).to be_a(described_class)
      end
    end

    it "refuses standoffs and dislodged units in a movement phase, and allows them later (AC-5.7)" do
      refuse(/:movement/, standoffs: [:bur])
      dislodged = TA::DislodgedUnit.new(unit: fleet, attacker_from: :fin, by_convoy: false)
      refuse(/:movement/, dislodged_units: [dislodged], units: [army])
      %i[retreat adjustment].each do |phase|
        expect(described_class.new(**fields.merge(phase: phase, standoffs: [:bur], dislodged_units: [dislodged], units: [army]))).to be_a(described_class)
      end
    end

    it "refuses an unknown identifier anywhere one is accepted (AC-5.8)" do
      refuse(/:xyz/, standoffs: [:xyz])
      refuse(/:xyz/, ownership: { xyz: :austria })
      refuse(/:xyz/, phase: :retreat, standoffs: [:xyz])
      refuse(/:atlantis/, ownership: { bud: :atlantis })
    end

    it "refuses a repeated standoff, and two dislodged units in one province (AC-5.9)" do
      refuse(/:bur/, phase: :retreat, standoffs: %i[bur bur])
      first = TA::DislodgedUnit.new(unit: fleet, attacker_from: :fin, by_convoy: false)
      second = TA::DislodgedUnit.new(unit: fleet, attacker_from: :nwy, by_convoy: false)
      refuse(/:stp/, phase: :retreat, dislodged_units: [first, second])
    end

    it "refuses each impossible position written as a hash (AC-5.10)" do
      dup_unit = valid_hash["units"].first
      cases = {
        "two units in one province" => valid_hash.merge("units" => [dup_unit, dup_unit]),
        "a province that is not a supply center" => valid_hash.merge("ownership" => { "bur" => "france" }),
        "a standoff in a movement phase" => valid_hash.merge("standoffs" => ["bur"]),
        "a repeated standoff" => valid_hash.merge("phase" => "retreat", "standoffs" => %w[bur bur]),
        "an unknown power" => valid_hash.merge("ownership" => { "bud" => "atlantis" }),
        "a dislodged unit in a movement phase" => valid_hash.merge("dislodged_units" => [{ "unit" => fleet.to_h, "attacker_from" => "fin", "by_convoy" => false }]),
        "an unknown attacker_from" => valid_hash.merge("phase" => "retreat", "dislodged_units" => [{ "unit" => fleet.to_h, "attacker_from" => "xyz", "by_convoy" => false }])
      }
      cases.each do |name, hash|
        expect { described_class.from_h(hash) }.to raise_error(TA::InvalidInput), name
      end
      two = { "unit" => fleet.to_h, "attacker_from" => "fin", "by_convoy" => false }
      expect { described_class.from_h(valid_hash.merge("phase" => "retreat", "dislodged_units" => [two, two.merge("attacker_from" => "nwy")])) }
        .to raise_error(TA::InvalidInput, /:stp/)
    end

    it "refuses an impossible change made with #with, and sorts a valid one (AC-5.11, AC-5.12)" do
      with_standoff = described_class.new(**fields.merge(phase: :retreat, standoffs: [:bur]))
      expect { with_standoff.with(phase: :movement) }.to raise_error(TA::InvalidInput, /:movement/)
      units = [fleet, army]
      swapped = position.with(units: units)
      expect(swapped).to eq(position)
      expect(swapped).to be_frozen
      expect(swapped.units).to be_frozen
      expect(swapped.units.map { _1.location.province }).to eq(%i[bud stp])
      expect(units).not_to be_frozen
      expect(units).to eq([fleet, army])
    end
  end
end

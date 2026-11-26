# frozen_string_literal: true

require "json"
require "trucebearer/adjudicator"
require_relative "../../support/board"

RSpec.describe Trucebearer::Adjudicator::Unit do
  let(:unit) { described_class.new(power: :russia, type: :fleet, location: L.new(province: :stp, coast: :sc)) }

  describe ".new" do
    it "keeps the fields, is frozen, and equals a unit with the same contents (AC-1.1)" do
      expect([unit.power, unit.type, unit.location]).to eq([:russia, :fleet, L.new(province: :stp, coast: :sc)])
      expect(unit).to be_frozen
      twin = described_class.new(power: :russia, type: :fleet, location: L.new(province: :stp, coast: :sc))
      expect([unit == twin, unit.eql?(twin), unit.hash == twin.hash]).to eq([true, true, true])
      expect(unit).not_to eq(described_class.new(power: :russia, type: :army, location: L.new(province: :stp)))
    end

    it "rejects a bad power, type or location, naming the value (AC-1.4)" do
      loc = L.new(province: :par)
      expect { described_class.new(power: "russia", type: :army, location: loc) }.to raise_error(TA::InvalidInput, /"russia"/)
      expect { described_class.new(power: :atlantis, type: :army, location: loc) }.to raise_error(TA::InvalidInput, /:atlantis/)
      expect { described_class.new(power: :france, type: "army", location: loc) }.to raise_error(TA::InvalidInput, /"army"/)
      expect { described_class.new(power: :france, type: :ship, location: loc) }.to raise_error(TA::InvalidInput, /:ship/)
      [{ "province" => "par", "coast" => nil }, :par, nil].each do |bad|
        expect { described_class.new(power: :france, type: :army, location: bad) }.to raise_error(TA::InvalidInput, /#{Regexp.escape(bad.inspect)}/)
      end
    end

    it "raises ArgumentError, not InvalidInput, for a missing or unknown keyword (AC-1.10)" do
      expect { described_class.new(power: :france, type: :army) }.to raise_error(ArgumentError)
      expect { described_class.new(power: :france, type: :army, location: L.new(province: :par), extra: 1) }.to raise_error(ArgumentError)
      expect { L.new }.to raise_error(ArgumentError) # the #9 behavior, pinned (AC-1.10)
    end
  end

  describe "placement (AC-5.2 to AC-5.4)" do
    it "refuses a fleet in every inland province and an army in every sea province" do
      Board.inland.each do |id|
        expect { described_class.new(power: :germany, type: :fleet, location: L.new(province: id)) }
          .to raise_error(TA::InvalidInput, /#{id.inspect}/)
      end
      Board.sea.each do |id|
        expect { described_class.new(power: :england, type: :army, location: L.new(province: id)) }
          .to raise_error(TA::InvalidInput, /#{id.inspect}/)
      end
    end

    it "refuses an army that names a coast, for all six split coasts" do
      Board.split.each do |province|
        province.coasts.each do |coast|
          expect { described_class.new(power: :france, type: :army, location: L.new(province: province.id, coast: coast)) }
            .to raise_error(TA::InvalidInput, /#{province.id.inspect}.*#{coast.inspect}/m)
        end
      end
    end

    it "refuses a fleet on a split-coast province with no coast, and accepts one with a coast" do
      Board.split.each do |province|
        expect { described_class.new(power: :france, type: :fleet, location: L.new(province: province.id)) }
          .to raise_error(TA::InvalidInput, /#{province.id.inspect}/)
        province.coasts.each do |coast|
          expect(described_class.new(power: :france, type: :fleet, location: L.new(province: province.id, coast: coast))).to be_a(described_class)
        end
      end
    end

    it "refuses an impossible change made with #with (AC-5.11)" do
      army = described_class.new(power: :germany, type: :army, location: L.new(province: :mun))
      expect { army.with(type: :fleet) }.to raise_error(TA::InvalidInput, /:mun/)
      expect { army.with(power: :xyz) }.to raise_error(TA::InvalidInput, /:xyz/)
    end
  end

  describe "#to_h (AC-1.2)" do
    it "gives string keys and no format" do
      expect(unit.to_h).to eq("power" => "russia", "type" => "fleet", "location" => { "province" => "stp", "coast" => "sc" })
      expect(unit.to_h.keys).to eq(%w[power type location])
    end
  end

  describe ".from_h" do
    let(:valid) { unit.to_h }

    it "round-trips all 840 valid units through JSON (AC-1.3)" do
      count = 0
      Board.powers.each do |power|
        Board.army_provinces.each do |id|
          army = described_class.new(power: power, type: :army, location: L.new(province: id))
          expect(described_class.from_h(JSON.parse(JSON.generate(army.to_h)))).to eq(army)
          count += 1
        end
        Board.fleet_locations.each do |location|
          fleet = described_class.new(power: power, type: :fleet, location: location)
          expect(described_class.from_h(JSON.parse(JSON.generate(fleet.to_h)))).to eq(fleet)
          count += 1
        end
      end
      expect(count).to eq(840)
    end

    it "rejects a bad shape, naming the key or value (AC-1.5)" do
      expect { described_class.from_h(valid.merge("power" => :russia)) }.to raise_error(TA::InvalidInput, /:russia/)
      expect { described_class.from_h(valid.merge("power" => "atlantis")) }.to raise_error(TA::InvalidInput, /"atlantis"/)
      expect { described_class.from_h(valid.merge("type" => "ship")) }.to raise_error(TA::InvalidInput, /"ship"/)
      expect { described_class.from_h(valid.merge("location" => "stp")) }.to raise_error(TA::InvalidInput, /"stp"/)
      expect { described_class.from_h(valid.merge("location" => valid["location"].merge("format" => 1))) }.to raise_error(TA::InvalidInput, /"format"/)
      expect { described_class.from_h(valid.reject { |k, _| k == "type" }) }.to raise_error(TA::InvalidInput, /"type"/)
      expect { described_class.from_h(valid.merge("extra" => 1)) }.to raise_error(TA::InvalidInput, /"extra"/)
      expect { described_class.from_h(valid.transform_keys(&:to_sym)) }.to raise_error(TA::InvalidInput, /"power"/)
      expect { described_class.from_h([valid]) }.to raise_error(TA::InvalidInput, /\[\{/)
    end

    it "does not change the hash it is given, and accepts a frozen one (AC-2.9)" do
      frozen = Ractor.make_shareable(JSON.parse(JSON.generate(valid)))
      before = Marshal.load(Marshal.dump(frozen))
      expect(described_class.from_h(frozen)).to eq(unit)
      expect(frozen).to eq(before)
      parsed = JSON.parse(JSON.generate(valid))
      built = described_class.from_h(parsed)
      parsed["power"] << "x"
      parsed["location"]["province"] << "x"
      expect(built).to eq(unit)
    end

    it "refuses an impossible unit written as a hash (AC-5.10)" do
      expect { described_class.from_h("power" => "germany", "type" => "fleet", "location" => { "province" => "mun", "coast" => nil }) }.to raise_error(TA::InvalidInput, /:mun/)
      expect { described_class.from_h("power" => "france", "type" => "fleet", "location" => { "province" => "spa", "coast" => nil }) }.to raise_error(TA::InvalidInput, /:spa/)
      expect { described_class.from_h("power" => "england", "type" => "army", "location" => { "province" => "nth", "coast" => nil }) }.to raise_error(TA::InvalidInput, /:nth/)
      expect { described_class.from_h("power" => "france", "type" => "army", "location" => { "province" => "spa", "coast" => "nc" }) }.to raise_error(TA::InvalidInput, /:spa/)
    end
  end
end

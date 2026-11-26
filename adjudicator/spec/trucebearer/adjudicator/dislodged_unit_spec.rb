# frozen_string_literal: true

require "json"
require "trucebearer/adjudicator"
require_relative "../../support/board"

RSpec.describe Trucebearer::Adjudicator::DislodgedUnit do
  let(:serbian_army) { TA::Unit.new(power: :austria, type: :army, location: L.new(province: :ser)) }
  let(:dislodged) { described_class.new(unit: serbian_army, attacker_from: :bul, by_convoy: false) }

  it "keeps its fields, is frozen, and equals one with the same contents (AC-1.6)" do
    expect([dislodged.unit, dislodged.attacker_from, dislodged.by_convoy]).to eq([serbian_army, :bul, false])
    expect(dislodged).to be_frozen
    expect(dislodged).to eq(described_class.new(unit: serbian_army, attacker_from: :bul, by_convoy: false))
    expect(dislodged.hash).to eq(described_class.new(unit: serbian_army, attacker_from: :bul, by_convoy: false).hash)
  end

  it "gives the hash form of the interface example, with no format (AC-1.6)" do
    expect(dislodged.to_h).to eq(
      "unit" => { "power" => "austria", "type" => "army", "location" => { "province" => "ser", "coast" => nil } },
      "attacker_from" => "bul", "by_convoy" => false
    )
    expect(dislodged.to_h.keys).to eq(%w[unit attacker_from by_convoy])
  end

  it "round-trips for both by_convoy values and an attacker from every province (AC-1.7)" do
    Board.provinces.each do |from|
      [true, false].each do |convoy|
        built = described_class.new(unit: serbian_army, attacker_from: from, by_convoy: convoy)
        expect(described_class.from_h(JSON.parse(JSON.generate(built.to_h)))).to eq(built)
      end
    end
  end

  it "rejects a bad unit, attacker or by_convoy, naming the value (AC-1.8)" do
    expect { described_class.new(unit: { "power" => "austria" }, attacker_from: :bul, by_convoy: false) }.to raise_error(TA::InvalidInput, /austria/)
    ["bul", L.new(province: :bul), nil, :xyz].each do |bad|
      expect { described_class.new(unit: serbian_army, attacker_from: bad, by_convoy: false) }
        .to raise_error(TA::InvalidInput, /#{Regexp.escape(bad.inspect)}/)
    end
    [nil, "false", 0].each do |bad|
      expect { described_class.new(unit: serbian_army, attacker_from: :bul, by_convoy: bad) }
        .to raise_error(TA::InvalidInput, /#{Regexp.escape(bad.inspect)}/)
    end
  end

  it "rejects a bad hash, naming the key or value (AC-1.9)" do
    valid = dislodged.to_h
    expect { described_class.from_h(valid.merge("attacker_from" => :bul)) }.to raise_error(TA::InvalidInput, /:bul/)
    expect { described_class.from_h(valid.merge("attacker_from" => { "province" => "spa", "coast" => "nc" })) }.to raise_error(TA::InvalidInput, /"coast" => "nc"/)
    expect { described_class.from_h(valid.merge("by_convoy" => "true")) }.to raise_error(TA::InvalidInput, /"true"/)
    expect { described_class.from_h(valid.merge("attacker_from" => "xyz")) }.to raise_error(TA::InvalidInput, /"xyz"/)
    expect { described_class.from_h(valid.merge("unit" => { "power" => "austria" })) }.to raise_error(TA::InvalidInput, /"type"/)
    expect { described_class.from_h(valid.reject { |k, _| k == "by_convoy" }) }.to raise_error(TA::InvalidInput, /"by_convoy"/)
    expect { described_class.from_h(valid.merge("extra" => 1)) }.to raise_error(TA::InvalidInput, /"extra"/)
    expect { described_class.from_h("nope") }.to raise_error(TA::InvalidInput, /"nope"/)
  end

  it "raises ArgumentError for a missing keyword (AC-1.10)" do
    expect { described_class.new(unit: serbian_army, attacker_from: :bul) }.to raise_error(ArgumentError)
  end

  it "leaves the hash it is given alone, accepts a frozen one, and holds no reference to it (AC-2.9)" do
    parsed = JSON.parse(JSON.generate(dislodged.to_h))
    before = Marshal.load(Marshal.dump(parsed))
    built = described_class.from_h(parsed)
    expect(parsed).to eq(before)
    parsed["unit"]["power"] << "x"
    expect(built).to eq(dislodged)
    expect(described_class.from_h(Ractor.make_shareable(JSON.parse(JSON.generate(dislodged.to_h))))).to eq(dislodged)
  end
end

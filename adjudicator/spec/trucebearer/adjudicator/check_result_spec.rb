# frozen_string_literal: true

require "json"
require "trucebearer/adjudicator"
require_relative "../../support/board"

RSpec.describe TA::CheckResult do
  let(:illegal) { described_class.new(legal: false, reasons: [:foreign_unit]) }
  let(:legal) { described_class.new(legal: true, reasons: []) }

  def refused(message_part = nil, &block)
    expect(&block).to raise_error(TA::InvalidInput, /#{Regexp.escape(message_part.to_s)}/)
  end

  describe "new" do
    it "builds frozen results with a frozen reasons list (AC-1.1)" do
      expect(legal).to be_frozen
      expect(illegal).to be_frozen
      expect(illegal.reasons).to be_frozen
      expect(legal.reasons).to eq([])
      expect(illegal.legal).to be(false)
    end

    it "makes equal results equal, with the same hash (AC-1.1)" do
      again = described_class.new(legal: false, reasons: [:foreign_unit])
      expect(again).to eq(illegal)
      expect(again).to eql(illegal)
      expect(again.hash).to eq(illegal.hash)
      expect(illegal).not_to eq(described_class.new(legal: false, reasons: [:no_unit]))
    end

    it "copies the reasons it is given (AC-1.1)" do
      given = [:no_unit]
      result = described_class.new(legal: false, reasons: given)
      expect(given).not_to be_frozen
      given << :own_province
      expect(result.reasons).to eq([:no_unit])
    end

    it "has the 17 reasons of the interface table, in its order" do
      expect(described_class::REASONS.size).to eq(17)
      expect(described_class::REASONS).to eq(
        %i[wrong_phase no_such_unit foreign_unit own_province not_reachable coast_not_allowed coast_required
           coast_unreachable not_army not_adjacent no_convoy_route same_province no_unit move_impossible
           not_fleet_at_sea bad_endpoints not_on_chain]
      )
    end

    it "refuses a legal flag that is not true or false, naming the value (AC-1.5)" do
      [nil, "true", 1].each do |bad|
        refused(bad.inspect) { described_class.new(legal: bad, reasons: []) }
      end
    end

    it "refuses reasons that are not an Array, naming the value (AC-1.5)" do
      refused(":no_unit") { described_class.new(legal: false, reasons: :no_unit) }
      refused("nil") { described_class.new(legal: false, reasons: nil) }
    end

    it "refuses a reason that is a string or an unknown symbol, naming it (AC-1.5)" do
      refused('"own_province"') { described_class.new(legal: false, reasons: ["own_province"]) }
      refused(":bogus") { described_class.new(legal: false, reasons: [:bogus]) }
    end

    it "refuses the three impossible results of the interface (AC-1.4)" do
      refused(":own_province") { described_class.new(legal: true, reasons: [:own_province]) }
      refused("[]") { described_class.new(legal: false, reasons: []) }
      refused(":not_reachable") { described_class.new(legal: false, reasons: %i[own_province not_reachable]) }
    end

    it "raises Ruby's ArgumentError for a missing or unknown keyword (AC-1.8)" do
      expect { described_class.new(legal: true) }.to raise_error(ArgumentError)
      expect { described_class.new(reasons: []) }.to raise_error(ArgumentError)
      expect { described_class.new(legal: true, reasons: [], extra: 1) }.to raise_error(ArgumentError)
    end
  end

  describe "to_h" do
    it "gives the hash forms of the interface, keys in order (AC-1.2)" do
      expect(illegal.to_h).to eq("format" => 1, "legal" => false, "reasons" => ["foreign_unit"])
      expect(legal.to_h).to eq("format" => 1, "legal" => true, "reasons" => [])
      expect(illegal.to_h.keys).to eq(%w[format legal reasons])
    end
  end

  describe "round trip" do
    let(:all) do
      [legal] + described_class::REASONS.map { |reason| described_class.new(legal: false, reasons: [reason]) }
    end

    it "rebuilds an equal object for a legal result and each of the 17 reasons (AC-1.3)" do
      expect(all.size).to eq(18)
      all.each do |result|
        expect(described_class.from_h(JSON.parse(JSON.generate(result.to_h)))).to eq(result)
      end
    end
  end

  describe "from_h" do
    let(:good) { { "format" => 1, "legal" => false, "reasons" => ["no_unit"] } }

    it "refuses the three impossible results as hashes (AC-1.4)" do
      [{ "legal" => true, "reasons" => ["own_province"] },
       { "legal" => false, "reasons" => [] },
       { "legal" => false, "reasons" => %w[own_province not_reachable] }].each do |fields|
        expect { described_class.from_h({ "format" => 1 }.merge(fields)) }.to raise_error(TA::InvalidInput)
      end
    end

    it "refuses a missing key, an unknown key, symbol keys and a non-hash (AC-1.6)" do
      refused('"legal"') { described_class.from_h(good.reject { |key, _| key == "legal" }) }
      refused('"reasons"') { described_class.from_h(good.reject { |key, _| key == "reasons" }) }
      refused('"extra"') { described_class.from_h(good.merge("extra" => 1)) }
      expect { described_class.from_h(good.transform_keys(&:to_sym)) }.to raise_error(TA::InvalidInput)
      refused("nil") { described_class.from_h(nil) }
      refused("[]") { described_class.from_h([]) }
    end

    it "refuses a missing or unknown format (AC-1.6)" do
      refused('"format"') { described_class.from_h(good.reject { |key, _| key == "format" }) }
      refused("2") { described_class.from_h(good.merge("format" => 2)) }
      refused("1.0") { described_class.from_h(good.merge("format" => 1.0)) }
    end

    it "refuses wrong types and unknown reasons (AC-1.6)" do
      refused('"yes"') { described_class.from_h(good.merge("legal" => "yes")) }
      refused('"no_unit"') { described_class.from_h(good.merge("reasons" => "no_unit")) }
      refused(":no_unit") { described_class.from_h(good.merge("reasons" => [:no_unit])) }
      refused('"bogus"') { described_class.from_h(good.merge("reasons" => ["bogus"])) }
    end

    it "leaves its argument unchanged and accepts a frozen one (AC-1.7)" do
      hash = { "format" => 1, "legal" => false, "reasons" => ["no_unit"] }
      before = Marshal.load(Marshal.dump(hash))
      refused_hash = good.merge("legal" => "yes", "reasons" => ["no_unit"])
      refused_before = Marshal.load(Marshal.dump(refused_hash))
      expect { described_class.from_h(refused_hash) }.to raise_error(TA::InvalidInput)
      expect(refused_hash).to eq(refused_before)
      result = described_class.from_h(hash)
      expect(hash).to eq(before)
      hash["reasons"] << "own_province"
      expect(result.reasons).to eq([:no_unit])
      frozen = { "format" => 1, "legal" => false, "reasons" => ["no_unit"].freeze }.freeze
      expect(described_class.from_h(frozen)).to eq(result)
      expect { described_class.from_h(good.merge("legal" => "yes")) }.to raise_error(TA::InvalidInput)
    end
  end
end

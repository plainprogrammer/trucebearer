# frozen_string_literal: true

require "json"
require "trucebearer/adjudicator"
require_relative "../../support/board"

# Every Ruby example in docs/interface.md under "### TA::CheckResult" and under
# "## Checking an order", and the three CheckResult lines at the end of "Impossible
# objects", run as a spec (AC-9.1).
RSpec.describe "docs/interface.md examples: checking" do
  def result(legal, reasons) = TA::CheckResult.new(legal: legal, reasons: reasons)

  describe "### TA::CheckResult" do
    it "gives the hash forms the document shows" do
      expect(TA::CheckResult.new(legal: false, reasons: [:foreign_unit]).to_h)
        .to eq("format" => 1, "legal" => false, "reasons" => ["foreign_unit"])
      expect(TA::CheckResult.new(legal: true, reasons: []).to_h).to eq("format" => 1, "legal" => true, "reasons" => [])
    end
  end

  describe "### Impossible objects: a check result whose legal flag and reasons disagree" do
    it "raises InvalidInput for each of the three lines" do
      expect { TA::CheckResult.new(legal: true, reasons: [:own_province]) }.to raise_error(TA::InvalidInput)
      expect { TA::CheckResult.new(legal: false, reasons: []) }.to raise_error(TA::InvalidInput)
      expect { TA::CheckResult.new(legal: false, reasons: [:own_province, :not_reachable]) }.to raise_error(TA::InvalidInput)
    end
  end

  describe "## Checking an order" do
    let(:start) { TA::Map.classic.starting_position }
    let(:at_sea) do
      TA::Position.new(map: "classic", season: :spring, year: 1901, phase: :movement, ownership: {},
                       dislodged_units: [], standoffs: [],
                       units: [TA::Unit.new(power: :france, type: :fleet, location: L.new(province: :mao)),
                               TA::Unit.new(power: :france, type: :fleet, location: L.new(province: :gol))])
    end

    it "gives every result the document shows" do
      expect(TA.check(start, O::Hold.new(power: :england, at: :lon))).to eq(result(true, []))
      expect(TA.check(start, O::Hold.new(power: :france, at: :lon))).to eq(result(false, [:foreign_unit]))
      expect(TA.check(start, O::Move.new(power: :england, at: :lon, destination: L.new(province: :bel))))
        .to eq(result(false, [:not_reachable]))
      expect(TA.check(start, O::Move.new(power: :russia, at: :sev, destination: L.new(province: :rum))))
        .to eq(result(true, []))
      expect(TA.check(start, O::Move.new(power: :france, at: :mar, destination: L.new(province: :spa, coast: :nc))))
        .to eq(result(false, [:coast_not_allowed]))
      expect(TA.check(start, O::MoveViaConvoy.new(power: :england, at: :lvp, to: :wal)))
        .to eq(result(false, [:no_convoy_route]))
      expect(TA.check(start, O::SupportMove.new(power: :austria, at: :vie, from: :war, to: :gal)))
        .to eq(result(true, []))
      expect(TA.check(at_sea, O::Move.new(power: :france, at: :mao, destination: L.new(province: :spa))))
        .to eq(result(false, [:coast_required]))
      expect(TA.check(at_sea, O::Move.new(power: :france, at: :gol, destination: L.new(province: :spa, coast: :nc))))
        .to eq(result(false, [:coast_unreachable]))
      retreat = TA::Position.from_h(start.to_h.merge("phase" => "retreat"))
      expect(TA.check(retreat, O::Hold.new(power: :england, at: :lon))).to eq(result(false, [:wrong_phase]))
      expect(TA.check(start, O::Hold.new(power: :england, at: :wal))).to eq(result(false, [:no_such_unit]))
      expect(TA.check(start, O::SupportHold.new(power: :germany, at: :mun, target: :ber))).to eq(result(true, []))
      expect(TA.check(start, O::SupportHold.new(power: :germany, at: :mun, target: :sil))).to eq(result(false, [:no_unit]))
      expect(TA.check(start, O::Convoy.new(power: :england, at: :lon, from: :lvp, to: :bel)))
        .to eq(result(false, [:not_fleet_at_sea]))
    end

    it "gives results with the inspect form the document shows" do
      expect(TA.check(start, O::Hold.new(power: :england, at: :lon)).inspect)
        .to eq("#<data Trucebearer::Adjudicator::CheckResult legal=true, reasons=[]>")
      expect(TA.check(start, O::Hold.new(power: :france, at: :lon)).inspect)
        .to eq("#<data Trucebearer::Adjudicator::CheckResult legal=false, reasons=[:foreign_unit]>")
    end

    it "round-trips the result through JSON" do
      checked = TA.check(start, O::Hold.new(power: :france, at: :lon))
      expect(TA::CheckResult.from_h(JSON.parse(JSON.generate(checked.to_h)))).to eq(checked)
    end
  end
end

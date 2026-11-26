# frozen_string_literal: true

require "trucebearer/adjudicator"
require_relative "../../support/board"
require_relative "../../support/reasons_table"

# TA.check for convoys (Story 6).
RSpec.describe "TA.check: convoys" do
  def u(power, type, at) = Board.unit(power, type, at)

  def convoy(power, at, from, to) = O::Convoy.new(power: power, at: at, from: from, to: to)

  def verdict(position, order) = Board.verdict(position, order)

  let(:start) { TA::Map.classic.starting_position }
  # England's army in London, fleets in the North Sea and the Channel, and a coastal fleet in Wales.
  let(:c) do
    Board.position(u(:england, :army, "lon"), u(:england, :fleet, "nth"), u(:england, :fleet, "eng"), u(:england, :fleet, "wal"))
  end

  it "gives :not_fleet_at_sea for the interface example (AC-6.1)" do
    expect(verdict(start, convoy(:england, :lon, :lvp, :bel))).to eq([:not_fleet_at_sea])
  end

  it "is legal for a fleet on a minimal chain, whoever owns the army and the fleets (AC-6.2)" do
    expect(verdict(c, convoy(:england, :nth, :lon, :nwy))).to eq([])
    foreign = Board.position(u(:germany, :army, "lon"), u(:england, :fleet, "nth"))
    expect(verdict(foreign, convoy(:england, :nth, :lon, :nwy))).to eq([])
  end

  it "gives one reason for each condition (AC-6.3)" do
    expect(verdict(c, convoy(:england, :lon, :lon, :nwy))).to eq([:not_fleet_at_sea])
    expect(verdict(c, convoy(:england, :wal, :lon, :nwy))).to eq([:not_fleet_at_sea])
    expect(verdict(c, convoy(:england, :nth, :lon, :lon))).to eq([:bad_endpoints])
    expect(verdict(c, convoy(:england, :nth, :lon, :nth))).to eq([:bad_endpoints])
    expect(verdict(c, convoy(:england, :nth, :bur, :nwy))).to eq([:bad_endpoints])
    expect(verdict(c, convoy(:england, :nth, :yor, :nwy))).to eq([:no_unit])
    expect(verdict(c, convoy(:england, :nth, :wal, :nwy))).to eq([:no_unit])
    expect(verdict(c, convoy(:england, :eng, :lon, :nwy))).to eq([:not_on_chain])
  end

  it "shows a fleet bypassed by a shorter chain is refused, as in 6.G.19 (AC-6.4)" do
    g19 = Board.position(u(:france, :army, "mar"), u(:france, :fleet, "wes"), u(:italy, :fleet, "gol"), u(:italy, :army, "spa"))
    expect(verdict(g19, convoy(:france, :wes, :mar, :spa))).to eq([:not_on_chain])
    expect(verdict(g19, convoy(:italy, :gol, :mar, :spa))).to eq([])
  end

  it "shows a sea fleet touching a chain fleet but neither end is refused, as in 6.F.12 (AC-6.4)" do
    shape = Board.position(u(:england, :army, "lon"), u(:england, :fleet, "eng"), u(:england, :fleet, "iri"), u(:england, :fleet, "nth"))
    expect(verdict(shape, convoy(:england, :iri, :lon, :bel))).to eq([:not_on_chain])
  end

  it "makes both fleets of a chain of two legal (AC-6.4)" do
    two = Board.position(u(:england, :army, "lon"), u(:england, :fleet, "eng"), u(:france, :fleet, "mao"))
    expect(verdict(two, convoy(:england, :eng, :lon, :por))).to eq([])
    expect(verdict(two, convoy(:france, :mao, :lon, :por))).to eq([])
  end

  it "ignores coasts at both ends (AC-6.5, 6.B.18, 6.B.19)" do
    from_bulgaria = Board.position(u(:turkey, :army, "bul"), u(:turkey, :fleet, "bla"))
    expect(verdict(from_bulgaria, convoy(:turkey, :bla, :bul, :sev))).to eq([])
    to_spain = Board.position(u(:italy, :army, "tus"), u(:italy, :fleet, "gol"))
    expect(verdict(to_spain, convoy(:italy, :gol, :tus, :spa))).to eq([])
  end

  # AC-6.6: every pair can fail together. Each uses the position `c`.
  describe "precedence (AC-6.6)" do
    it "not_fleet_at_sea before bad_endpoints" do
      expect_precedence("Convoy", :not_fleet_at_sea, :bad_endpoints, c,
                        convoy(:england, :lon, :lon, :lon), convoy(:england, :nth, :lon, :lon))
    end

    it "not_fleet_at_sea before no_unit" do
      expect_precedence("Convoy", :not_fleet_at_sea, :no_unit, c,
                        convoy(:england, :wal, :yor, :nwy), convoy(:england, :nth, :yor, :nwy))
    end

    it "not_fleet_at_sea before not_on_chain" do
      expect_precedence("Convoy", :not_fleet_at_sea, :not_on_chain, c,
                        convoy(:england, :wal, :lon, :nwy), convoy(:england, :eng, :lon, :nwy))
    end

    it "bad_endpoints before no_unit" do
      expect_precedence("Convoy", :bad_endpoints, :no_unit, c,
                        convoy(:england, :nth, :iri, :nwy), convoy(:england, :nth, :yor, :nwy))
    end

    it "bad_endpoints before not_on_chain" do
      expect_precedence("Convoy", :bad_endpoints, :not_on_chain, c,
                        convoy(:england, :eng, :lon, :lon), convoy(:england, :eng, :lon, :nwy))
    end

    it "no_unit before not_on_chain" do
      expect_precedence("Convoy", :no_unit, :not_on_chain, c,
                        convoy(:england, :eng, :yor, :nwy), convoy(:england, :eng, :lon, :nwy))
    end
  end
end

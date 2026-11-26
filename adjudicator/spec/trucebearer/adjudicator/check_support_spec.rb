# frozen_string_literal: true

require "trucebearer/adjudicator"
require_relative "../../support/board"
require_relative "../../support/reasons_table"

# TA.check for supports (Story 5).
RSpec.describe "TA.check: supports" do
  def u(power, type, at) = Board.unit(power, type, at)

  def hold_support(power, at, target) = O::SupportHold.new(power: power, at: at, target: target)

  def move_support(power, at, from, to) = O::SupportMove.new(power: power, at: at, from: from, to: to)

  def verdict(position, order) = Board.verdict(position, order)

  let(:start) { TA::Map.classic.starting_position }

  describe "SupportHold" do
    it "gives the interface examples' results (AC-5.1)" do
      expect(verdict(start, hold_support(:germany, :mun, :ber))).to eq([])
      expect(verdict(start, hold_support(:germany, :mun, :sil))).to eq([:no_unit])
    end

    it "is legal for a unit the supporter can reach, whoever owns it (AC-5.2)" do
      expect(verdict(start, hold_support(:italy, :ven, :tri))).to eq([])
    end

    it "gives one reason for each condition (AC-5.2)" do
      expect(verdict(start, hold_support(:germany, :mun, :mun))).to eq([:own_province])
      expect(verdict(start, hold_support(:germany, :mun, :sil))).to eq([:no_unit])
      expect(verdict(start, hold_support(:germany, :mun, :vie))).to eq([:not_reachable])
    end

    describe "precedence (AC-5.7)" do
      let(:position) { Board.position(u(:england, :fleet, "lon"), u(:england, :army, "bel")) }

      it "own_province before not_reachable" do
        expect_precedence("SupportHold", :own_province, :not_reachable, position,
                          hold_support(:england, :lon, :lon), hold_support(:england, :lon, :bel))
      end

      it "no_unit before not_reachable" do
        expect_precedence("SupportHold", :no_unit, :not_reachable, position,
                          hold_support(:england, :lon, :hol), hold_support(:england, :lon, :bel))
      end

      it "never reports own_province together with no_unit: the supporter stands in its own province" do
        expect(verdict(position, hold_support(:england, :lon, :lon))).to eq([:own_province])
      end
    end
  end

  describe "SupportMove" do
    it "is legal for Austria supporting a Russian army, as in the interface (AC-5.1)" do
      expect(verdict(start, move_support(:austria, :vie, :war, :gal))).to eq([])
    end

    it "gives one reason for each condition (AC-5.3)" do
      expect(verdict(start, move_support(:austria, :vie, :vie, :gal))).to eq([:own_province])
      expect(verdict(start, move_support(:austria, :vie, :war, :vie))).to eq([:own_province])
      expect(verdict(start, move_support(:austria, :vie, :war, :war))).to eq([:same_province])
      expect(verdict(start, move_support(:austria, :vie, :sil, :gal))).to eq([:no_unit])
      expect(verdict(start, move_support(:austria, :vie, :war, :ukr))).to eq([:not_reachable])
    end

    it "judges a fleet supporter's reach from the coast it stands on (AC-5.3, 6.B.5)" do
      position = Board.position(u(:france, :fleet, "mar"), u(:france, :fleet, "spa/nc"))
      expect(verdict(position, move_support(:france, :spa, :mar, :gol))).to eq([:not_reachable])
      south = Board.position(u(:france, :fleet, "mar"), u(:france, :fleet, "spa/sc"))
      expect(verdict(south, move_support(:france, :spa, :mar, :gol))).to eq([])
    end

    it "is :move_impossible when the supported unit couldn't move there itself (AC-5.4)" do
      two_armies = Board.position(u(:england, :army, "lon"), u(:england, :army, "bel"))
      expect(verdict(two_armies, move_support(:england, :lon, :bel, :yor))).to eq([:move_impossible])
      supported_fleet = Board.position(u(:italy, :army, "tus"), u(:italy, :fleet, "rom"))
      expect(verdict(supported_fleet, move_support(:italy, :tus, :rom, :ven))).to eq([:move_impossible])
      fleets = Board.position(u(:france, :fleet, "wes"), u(:france, :fleet, "gas"))
      expect(verdict(fleets, move_support(:france, :wes, :gas, :spa))).to eq([])
    end

    it "is legal for a coast the supporter can't reach itself, whatever coast the supported fleet is on (AC-5.4, 6.B.4, 6.B.17)" do
      expect(verdict(Board.position(u(:france, :fleet, "mar"), u(:france, :fleet, "gas")),
                     move_support(:france, :mar, :gas, :spa))).to eq([])
      expect(verdict(Board.position(u(:italy, :fleet, "wes"), u(:france, :fleet, "spa/nc")),
                     move_support(:italy, :wes, :spa, :mao))).to eq([])
    end

    it "judges the supported army's convoy chain without the supporter's fleet (AC-5.5, 6.D.31)" do
      shaped = Board.position(u(:austria, :army, "rum"), u(:turkey, :fleet, "bla"))
      expect(verdict(shaped, move_support(:turkey, :bla, :rum, :arm))).to eq([:move_impossible])
      other = Board.position(u(:austria, :army, "rum"), u(:turkey, :fleet, "bla"), u(:turkey, :army, "ank"))
      expect(verdict(other, move_support(:turkey, :ank, :rum, :arm))).to eq([])
    end

    it "treats a support for a foreign unit like any other, and names no coast (AC-5.6)" do
      expect(verdict(start, move_support(:austria, :vie, :war, :gal))).to eq([])
      expect(O::SupportMove.members).to eq(%i[power at from to])
    end

    # AC-5.7: nine pairs can fail together. The tenth, no_unit with move_impossible, never
    # does, because an empty origin has no unit to judge.
    describe "precedence (AC-5.7)" do
      let(:lon_bel) { Board.position(u(:england, :army, "lon"), u(:england, :army, "bel")) }
      let(:lon_bel_hol) { Board.position(u(:england, :army, "lon"), u(:england, :army, "bel"), u(:england, :army, "hol")) }

      it "own_province before same_province" do
        expect_precedence("SupportMove", :own_province, :same_province, lon_bel,
                          move_support(:england, :lon, :lon, :lon), move_support(:england, :lon, :bel, :bel))
      end

      it "own_province before no_unit" do
        expect_precedence("SupportMove", :own_province, :no_unit, lon_bel,
                          move_support(:england, :lon, :wal, :lon), move_support(:england, :lon, :wal, :yor))
      end

      it "own_province before not_reachable" do
        expect_precedence("SupportMove", :own_province, :not_reachable, lon_bel,
                          move_support(:england, :lon, :bel, :lon), move_support(:england, :lon, :bel, :hol))
      end

      it "own_province before move_impossible" do
        expect_precedence("SupportMove", :own_province, :move_impossible, lon_bel,
                          move_support(:england, :lon, :bel, :lon), move_support(:england, :lon, :bel, :yor))
      end

      it "same_province before no_unit" do
        expect_precedence("SupportMove", :same_province, :no_unit, lon_bel,
                          move_support(:england, :lon, :wal, :wal), move_support(:england, :lon, :wal, :yor))
      end

      it "same_province before not_reachable" do
        expect_precedence("SupportMove", :same_province, :not_reachable, lon_bel_hol,
                          move_support(:england, :lon, :hol, :hol), move_support(:england, :lon, :bel, :hol))
      end

      it "same_province before move_impossible" do
        position = Board.position(u(:england, :army, "lon"), u(:england, :army, "wal"), u(:england, :army, "bel"))
        expect_precedence("SupportMove", :same_province, :move_impossible, position,
                          move_support(:england, :lon, :wal, :wal), move_support(:england, :lon, :bel, :yor))
      end

      it "no_unit before not_reachable" do
        expect_precedence("SupportMove", :no_unit, :not_reachable, lon_bel,
                          move_support(:england, :lon, :wal, :hol), move_support(:england, :lon, :bel, :hol))
      end

      it "not_reachable before move_impossible" do
        position = Board.position(u(:england, :army, "lon"), u(:england, :army, "bel"))
        expect_precedence("SupportMove", :not_reachable, :move_impossible, position,
                          move_support(:england, :lon, :bel, :den), move_support(:england, :lon, :bel, :yor))
      end

      it "never reports no_unit together with move_impossible: an empty origin has no unit to judge" do
        expect(verdict(lon_bel, move_support(:england, :lon, :wal, :yor))).to eq([:no_unit])
      end
    end
  end
end

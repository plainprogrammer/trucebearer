# frozen_string_literal: true

require "trucebearer/adjudicator"
require_relative "../../support/board"
require_relative "../../support/reasons_table"

# TA.check for moves (Story 3) and moves by convoy (Story 4).
RSpec.describe "TA.check: moves and moves by convoy" do
  def u(power, type, at) = Board.unit(power, type, at)

  def move(power, at, to) = O::Move.new(power: power, at: at, destination: Board.loc(to))

  def via(power, at, to) = O::MoveViaConvoy.new(power: power, at: at, to: to)

  def verdict(position, order) = Board.verdict(position, order)

  let(:start) { TA::Map.classic.starting_position }
  let(:ln) { Board.position(u(:england, :army, "lon"), u(:england, :fleet, "nth")) }

  describe "Move" do
    it "gives the interface examples' results (AC-3.1)" do
      expect(verdict(start, move(:russia, :sev, "rum"))).to eq([])
      expect(verdict(start, move(:england, :lon, "bel"))).to eq([:not_reachable])
      expect(verdict(start, move(:france, :mar, "spa/nc"))).to eq([:coast_not_allowed])
    end

    it "allows a move the unit can reach (AC-3.2)" do
      expect(verdict(Board.position(u(:france, :army, "par")), move(:france, :par, "bur"))).to eq([])
      expect(verdict(Board.position(u(:england, :fleet, "nth")), move(:england, :nth, "eng"))).to eq([])
      expect(verdict(Board.position(u(:france, :fleet, "por")), move(:france, :por, "mao"))).to eq([])
      expect(verdict(Board.position(u(:england, :fleet, "lon")), move(:england, :lon, "eng"))).to eq([])
    end

    it "allows a fleet to name a coast it can reach (AC-3.2)" do
      at_sea = Board.position(u(:france, :fleet, "mao"))
      expect(verdict(at_sea, move(:france, :mao, "spa/nc"))).to eq([])
      expect(verdict(at_sea, move(:france, :mao, "spa/sc"))).to eq([])
      expect(verdict(Board.position(u(:france, :fleet, "gas")), move(:france, :gas, "spa/nc"))).to eq([])
    end

    it "allows an army to go by a convoy chain it can't walk (AC-3.2)" do
      expect(verdict(ln, move(:england, :lon, "nwy"))).to eq([])
      two = Board.position(u(:england, :army, "lon"), u(:england, :fleet, "eng"), u(:france, :fleet, "mao"))
      expect(verdict(two, move(:england, :lon, "por"))).to eq([])
    end

    it "gives :own_province for the unit's own province (AC-3.3)" do
      expect(verdict(Board.position(u(:france, :army, "par")), move(:france, :par, "par"))).to eq([:own_province])
      expect(verdict(Board.position(u(:england, :fleet, "lon")), move(:england, :lon, "lon"))).to eq([:own_province])
      crawl = Board.position(u(:france, :fleet, "spa/nc"))
      expect(verdict(crawl, move(:france, :spa, "spa/sc"))).to eq([:own_province])
    end

    it "gives :not_reachable for what the unit can't reach (AC-3.4)" do
      expect(verdict(Board.position(u(:england, :army, "lvp")), move(:england, :lvp, "iri"))).to eq([:not_reachable])
      expect(verdict(Board.position(u(:england, :army, "lon")), move(:england, :lon, "bel"))).to eq([:not_reachable])
      expect(verdict(Board.position(u(:germany, :fleet, "kie")), move(:germany, :kie, "mun"))).to eq([:not_reachable])
      expect(verdict(Board.position(u(:england, :fleet, "nth")), move(:england, :nth, "pic"))).to eq([:not_reachable])
    end

    it "never lets a fleet go by a convoy chain (AC-3.4, 6.A.7)" do
      with_chain = Board.position(u(:england, :fleet, "lon"), u(:england, :fleet, "nth"))
      expect(verdict(with_chain, move(:england, :lon, "nwy"))).to eq([:not_reachable])
    end

    it "judges a fleet from its own coast (AC-3.4, 6.B.11)" do
      north = Board.position(u(:france, :fleet, "spa/nc"))
      expect(verdict(north, move(:france, :spa, "gol"))).to eq([:not_reachable])
      south = Board.position(u(:france, :fleet, "spa/sc"))
      expect(verdict(south, move(:france, :spa, "gol"))).to eq([])
    end

    it "gives :coast_not_allowed for an army's move that names a coast (AC-3.5)" do
      expect(verdict(Board.position(u(:france, :army, "gas")), move(:france, :gas, "spa/nc"))).to eq([:coast_not_allowed])
      by_chain = Board.position(u(:italy, :army, "tus"), u(:italy, :fleet, "gol"))
      expect(verdict(by_chain, move(:italy, :tus, "spa/sc"))).to eq([:coast_not_allowed])
    end

    it "gives :coast_required for a fleet's move to split coasts with no coast named (AC-3.6)" do
      expect(verdict(Board.position(u(:france, :fleet, "por")), move(:france, :por, "spa"))).to eq([:coast_required])
      expect(verdict(Board.position(u(:france, :fleet, "gas")), move(:france, :gas, "spa"))).to eq([:coast_required])
    end

    it "gives :coast_unreachable for a coast the fleet can't reach, and never corrects it (AC-3.7)" do
      expect(verdict(Board.position(u(:france, :fleet, "gas")), move(:france, :gas, "spa/sc"))).to eq([:coast_unreachable])
      expect(verdict(Board.position(u(:france, :fleet, "gol")), move(:france, :gol, "spa/nc"))).to eq([:coast_unreachable])
    end

    it "judges each unit type by its own adjacency (AC-3.9)" do
      expect(verdict(Board.position(u(:italy, :army, "rom")), move(:italy, :rom, "ven"))).to eq([])
      expect(verdict(Board.position(u(:italy, :fleet, "rom")), move(:italy, :rom, "ven"))).to eq([:not_reachable])
      expect(verdict(Board.position(u(:england, :fleet, "lon")), move(:england, :lon, "nth"))).to eq([])
      expect(verdict(Board.position(u(:england, :army, "lon")), move(:england, :lon, "nth"))).to eq([:not_reachable])
    end

    # AC-3.8: seven pairs can fail together. Each is pinned with an order that fails both
    # conditions, and an order that fails only the second.
    describe "precedence (AC-3.8)" do
      it "own_province before not_reachable" do
        expect_precedence("Move", :own_province, :not_reachable, Board.position(u(:england, :fleet, "lon")),
                          move(:england, :lon, "lon"), move(:england, :lon, "bel"))
      end

      it "own_province before coast_not_allowed" do
        position = Board.position(u(:france, :army, "spa"), u(:france, :army, "gas"))
        expect_precedence("Move", :own_province, :coast_not_allowed, position,
                          move(:france, :spa, "spa/nc"), move(:france, :gas, "spa/nc"))
      end

      it "own_province before coast_required" do
        position = Board.position(u(:france, :fleet, "spa/nc"), u(:france, :fleet, "por"))
        expect_precedence("Move", :own_province, :coast_required, position,
                          move(:france, :spa, "spa"), move(:france, :por, "spa"))
      end

      it "own_province before coast_unreachable" do
        position = Board.position(u(:france, :fleet, "spa/nc"), u(:france, :fleet, "gas"))
        expect_precedence("Move", :own_province, :coast_unreachable, position,
                          move(:france, :spa, "spa/sc"), move(:france, :gas, "spa/sc"))
      end

      it "not_reachable before coast_not_allowed" do
        position = Board.position(u(:france, :army, "par"), u(:france, :army, "gas"))
        expect_precedence("Move", :not_reachable, :coast_not_allowed, position,
                          move(:france, :par, "spa/nc"), move(:france, :gas, "spa/nc"))
      end

      it "not_reachable before coast_required" do
        position = Board.position(u(:england, :fleet, "lon"), u(:france, :fleet, "por"))
        expect_precedence("Move", :not_reachable, :coast_required, position,
                          move(:england, :lon, "spa"), move(:france, :por, "spa"))
      end

      it "not_reachable before coast_unreachable" do
        position = Board.position(u(:england, :fleet, "lon"), u(:france, :fleet, "gas"))
        expect_precedence("Move", :not_reachable, :coast_unreachable, position,
                          move(:england, :lon, "spa/nc"), move(:france, :gas, "spa/sc"))
      end

      it "never reports two of the three coast reasons together (AC-3.8)" do
        # An army has no :coast_required or :coast_unreachable, and a fleet no :coast_not_allowed.
        army_naming = Board.position(u(:france, :army, "gas"))
        expect(verdict(army_naming, move(:france, :gas, "spa/sc"))).to eq([:coast_not_allowed])
        fleet_without = Board.position(u(:france, :fleet, "gas"))
        expect(verdict(fleet_without, move(:france, :gas, "spa"))).to eq([:coast_required])
        fleet_naming = Board.position(u(:france, :fleet, "gas"))
        expect(verdict(fleet_naming, move(:france, :gas, "spa/sc"))).to eq([:coast_unreachable])
      end
    end
  end

  describe "MoveViaConvoy" do
    it "gives :no_convoy_route for the interface example (AC-4.1)" do
      expect(verdict(start, via(:england, :lvp, :wal))).to eq([:no_convoy_route])
    end

    it "is legal for an army that could walk there, with a chain (AC-4.2)" do
      expect(verdict(ln, via(:england, :lon, :yor))).to eq([])
    end

    it "gives one reason for each condition (AC-4.3)" do
      expect(verdict(Board.position(u(:england, :fleet, "lon"), u(:england, :fleet, "nth")), via(:england, :lon, :wal)))
        .to eq([:not_army])
      expect(verdict(ln, via(:england, :lon, :lon))).to eq([:own_province])
      expect(verdict(ln, via(:england, :lon, :nwy))).to eq([:not_adjacent])
      expect(verdict(Board.position(u(:england, :army, "lon")), via(:england, :lon, :wal))).to eq([:no_convoy_route])
    end

    describe "precedence (AC-4.4)" do
      def position_for(*units) = Board.position(*units)

      it "not_army before own_province" do
        expect_precedence("MoveViaConvoy", :not_army, :own_province,
                          position_for(u(:england, :fleet, "lon"), u(:england, :army, "lvp")),
                          via(:england, :lon, :lon), via(:england, :lvp, :lvp))
      end

      it "not_army before not_adjacent" do
        expect_precedence("MoveViaConvoy", :not_army, :not_adjacent,
                          position_for(u(:england, :fleet, "lon"), u(:england, :army, "lvp")),
                          via(:england, :lon, :bel), via(:england, :lvp, :bel))
      end

      it "not_army before no_convoy_route" do
        expect_precedence("MoveViaConvoy", :not_army, :no_convoy_route,
                          position_for(u(:england, :fleet, "lvp"), u(:england, :army, "lon")),
                          via(:england, :lvp, :wal), via(:england, :lon, :wal))
      end

      it "own_province before not_adjacent" do
        expect_precedence("MoveViaConvoy", :own_province, :not_adjacent,
                          position_for(u(:england, :army, "lon"), u(:england, :army, "lvp")),
                          via(:england, :lon, :lon), via(:england, :lvp, :bel))
      end

      it "own_province before no_convoy_route" do
        expect_precedence("MoveViaConvoy", :own_province, :no_convoy_route,
                          position_for(u(:england, :army, "lon"), u(:england, :army, "lvp")),
                          via(:england, :lon, :lon), via(:england, :lvp, :wal))
      end

      it "not_adjacent before no_convoy_route" do
        expect_precedence("MoveViaConvoy", :not_adjacent, :no_convoy_route,
                          position_for(u(:england, :army, "lon"), u(:england, :army, "lvp")),
                          via(:england, :lon, :bel), via(:england, :lvp, :wal))
      end
    end
  end
end

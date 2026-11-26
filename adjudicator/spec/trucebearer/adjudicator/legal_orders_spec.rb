# frozen_string_literal: true

require "trucebearer/adjudicator"
require_relative "../../support/board"
require_relative "../../support/legal_positions"

# TA.legal_orders: the list of the legal orders of one unit (Stories 1 to 4 of spec 012).
# The first example of docs/interface.md `## Legal orders` is the first spec of the feature.
RSpec.describe "TA.legal_orders" do
  let(:start) { TA::Map.classic.starting_position }
  let(:london_fleet) { Board.unit(:england, :fleet, "lon") }

  describe "the first example (AC-1.1, AC-1.2)" do
    it "starts with the hold, then the moves to eng and nth, for England's fleet in London" do
      expect(TA.legal_orders(start, london_fleet).first(3)).to eq(
        [O::Hold.new(power: :england, at: :lon),
         O::Move.new(power: :england, at: :lon, destination: L.new(province: :eng)),
         O::Move.new(power: :england, at: :lon, destination: L.new(province: :nth))]
      )
    end

    it "is empty for a French fleet in London, where no such unit stands" do
      expect(TA.legal_orders(start, Board.unit(:france, :fleet, "lon"))).to eq([])
    end
  end

  # An independent source of truth for fleet moves: the map's own adjacency.
  def fleet_destinations(unit)
    Board.fleet_locations.select do |place|
      place.province != unit.location.province && TA::Map.classic.adjacent?(:fleet, unit.location, place)
    end.sort_by { |place| [place.province.to_s, place.coast.to_s] }
  end

  def moves_of(list) = list.grep(O::Move)

  describe "the shape of the list (AC-1.3, AC-3.1)" do
    it "starts with the unit's hold and names the unit's owner and province in every order" do
      LegalPositions.start.units.each do |unit|
        list = TA.legal_orders(LegalPositions.start, unit)
        expect(list.first).to eq(O::Hold.new(power: unit.power, at: unit.location.province))
        expect(list.map(&:power).uniq).to eq([unit.power])
        expect(list.map(&:at).uniq).to eq([unit.location.province])
      end
    end

    it "returns an array the caller owns: not frozen, and changing it changes nothing later" do
      list = TA.legal_orders(start, london_fleet)
      expect(list).not_to be_frozen
      list.clear
      expect(TA.legal_orders(start, london_fleet)).not_to be_empty
    end
  end

  describe "an empty list, never an exception (AC-2.1, AC-2.2)" do
    it "is empty in the retreat phase and in the adjustment phase, for a unit that is on the board" do
      unit = Board.unit(:england, :army, "lon")
      %i[retreat adjustment].each do |phase|
        expect(TA.legal_orders(Board.position(unit, phase: phase), unit)).to eq([])
      end
    end

    it "is empty for a unit that is not on the board" do
      position = Board.position(Board.unit(:england, :fleet, "lon"), Board.unit(:russia, :fleet, "stp/sc"))
      expect(TA.legal_orders(position, Board.unit(:england, :fleet, "wal"))).to eq([])      # nothing there
      expect(TA.legal_orders(position, Board.unit(:france, :fleet, "lon"))).to eq([])       # another power
      expect(TA.legal_orders(position, Board.unit(:england, :army, "lon"))).to eq([])       # another type
      expect(TA.legal_orders(position, Board.unit(:russia, :fleet, "stp/nc"))).to eq([])    # the other coast
    end
  end

  describe "arguments of the wrong class (AC-2.3)" do
    it "raises InvalidInput naming the argument, for a position that is not a position" do
      [nil, start.to_h, :start, london_fleet].each do |bad|
        expect { TA.legal_orders(bad, london_fleet) }
          .to raise_error(TA::InvalidInput, /#{Regexp.escape(bad.inspect)}/)
      end
    end

    it "raises InvalidInput naming the argument, for a unit that is not a unit" do
      [nil, london_fleet.to_h, :lon, O::Hold.new(power: :england, at: :lon)].each do |bad|
        expect { TA.legal_orders(start, bad) }
          .to raise_error(TA::InvalidInput, /#{Regexp.escape(bad.inspect)}/)
      end
    end
  end

  describe "what is in the list" do
    it "includes supports nobody has ordered, for any power's unit (AC-3.2)" do
      vie = Board.unit(:austria, :army, "vie")
      list = TA.legal_orders(start, vie)
      expect(list).to include(O::SupportMove.new(power: :austria, at: :vie, from: :war, to: :gal))
      expect(list.grep(O::SupportHold).map(&:target)).to eq(%i[bud tri])
    end

    it "gives one move for each coast a fleet can reach, and none without a coast (AC-3.3)" do
      spa = ->(position, unit) { moves_of(TA.legal_orders(position, unit)).select { _1.destination.province == :spa } }
      expect(spa.(LegalPositions.at_sea, Board.unit(:france, :fleet, "mao")).map { _1.destination.coast }).to eq(%i[nc sc])
      expect(spa.(LegalPositions.at_sea, Board.unit(:france, :fleet, "gol")).map { _1.destination.coast }).to eq([:sc])
      gascony = Board.unit(:france, :fleet, "gas")
      expect(spa.(Board.position(gascony), gascony).map { _1.destination.coast }).to eq([:nc])
    end

    it "judges a fleet's moves from the coast it stands on, and never lists its own province (AC-3.4)" do
      [Board.unit(:russia, :fleet, "stp/sc"), Board.unit(:russia, :fleet, "stp/nc"),
       Board.unit(:france, :fleet, "spa/nc"), Board.unit(:france, :fleet, "spa/sc"),
       Board.unit(:turkey, :fleet, "bul/ec"), Board.unit(:turkey, :fleet, "bul/sc")].each do |unit|
        destinations = moves_of(TA.legal_orders(Board.position(unit), unit)).map(&:destination)
        expect(destinations).to eq(fleet_destinations(unit))
        expect(destinations.map(&:province)).not_to include(unit.location.province)
      end
    end

    it "gives an army one move via convoy only where it can also walk, and a plain move wherever a chain reaches (AC-3.5)" do
      army = Board.unit(:england, :army, "lon")
      list = TA.legal_orders(LegalPositions.ln, army)
      expect(list.grep(O::MoveViaConvoy).map(&:to)).to eq([:yor])
      expect(moves_of(list).map { _1.destination.province }).to eq(%i[bel den edi hol nwy wal yor])
      expect(moves_of(list).map { _1.destination.coast }.uniq).to eq([nil])
    end

    it "gives a fleet no move via convoy and no move a chain alone could make, and an inland army none (AC-3.6)" do
      nth = Board.unit(:england, :fleet, "nth")
      list = TA.legal_orders(LegalPositions.ln, nth)
      expect(list.grep(O::MoveViaConvoy)).to eq([])
      expect(moves_of(list).map(&:destination)).to eq(fleet_destinations(nth))

      munich = Board.unit(:germany, :army, "mun")
      by_land = TA::Map.classic.provinces.map(&:id).select do |id|
        id != :mun && TA::Map.classic.adjacent?(:army, L.new(province: :mun), L.new(province: id))
      end
      with_fleet = Board.position(munich, Board.unit(:england, :fleet, "nth"))
      expect(moves_of(TA.legal_orders(with_fleet, munich)).map { _1.destination.province }).to eq(by_land.sort_by(&:to_s))
    end

    it "gives a convoy exactly to the fleets on a minimal chain (AC-3.7)" do
      bypassed = LegalPositions.bypassed
      expect(TA.legal_orders(bypassed, Board.unit(:italy, :fleet, "gol")))
        .to include(O::Convoy.new(power: :italy, at: :gol, from: :mar, to: :spa))
      expect(TA.legal_orders(bypassed, Board.unit(:france, :fleet, "wes")))
        .not_to include(O::Convoy.new(power: :france, at: :wes, from: :mar, to: :spa))

      two = LegalPositions.two_fleet_chain
      expect(TA.legal_orders(two, Board.unit(:england, :fleet, "eng")))
        .to include(O::Convoy.new(power: :england, at: :eng, from: :lon, to: :por))
      expect(TA.legal_orders(two, Board.unit(:france, :fleet, "mao")))
        .to include(O::Convoy.new(power: :france, at: :mao, from: :lon, to: :por))

      shape = LegalPositions.no_chain_through
      expect(TA.legal_orders(shape, Board.unit(:england, :fleet, "iri")))
        .not_to include(O::Convoy.new(power: :england, at: :iri, from: :lon, to: :bel))
    end

    it "depends on the position alone, and changes neither argument (AC-3.8)" do
      ln = LegalPositions.ln
      reversed = TA::Position.new(map: "classic", season: :spring, year: 1901, phase: :movement, ownership: {},
                                  dislodged_units: [], standoffs: [], units: ln.units.reverse)
      army = Board.unit(:england, :army, "lon")
      before = [ln.to_h, army.to_h]
      expect(TA.legal_orders(reversed, army)).to eq(TA.legal_orders(ln, army))
      expect([ln.to_h, army.to_h]).to eq(before)
    end

    it "gives a lone unit its hold and its moves only (AC-3.9)" do
      lone = Board.unit(:france, :fleet, "mao")
      list = TA.legal_orders(Board.position(lone), lone)
      expect(list.map(&:class).uniq).to eq([O::Hold, O::Move])
      expect(list.size).to eq(1 + fleet_destinations(lone).size)
    end
  end

  describe "the order of the list (AC-4.1 to AC-4.4)" do
    def groups = [O::Hold, O::Move, O::MoveViaConvoy, O::SupportHold, O::SupportMove, O::Convoy]

    def sort_key(order)
      case order
      when O::Hold then []
      when O::Move then [order.destination.province.to_s, order.destination.coast.to_s]
      when O::MoveViaConvoy then [order.to.to_s]
      when O::SupportHold then [order.target.to_s]
      when O::SupportMove then [order.from.to_s, order.to.to_s]
      when O::Convoy then [order.from.to_s, order.to.to_s]
      end
    end

    def lists
      [LegalPositions.start, LegalPositions.ln, LegalPositions.at_sea, LegalPositions.north_coasts,
       LegalPositions.south_coasts].flat_map do |position|
        position.units.map { |unit| [position, TA.legal_orders(position, unit)] }
      end
    end

    it "puts the six groups in the contract's order, none interleaved (AC-4.1)" do
      lists.each do |_, list|
        ranks = list.map { |order| groups.index(order.class) }
        expect(ranks).to eq(ranks.sort)
      end
    end

    it "sorts each group as the contract says (AC-4.2)" do
      lists.each do |_, list|
        list.group_by(&:class).each_value do |group|
          expect(group.map { sort_key(_1) }).to eq(group.map { sort_key(_1) }.sort)
        end
      end
    end

    it "gives the same list on every call and from a rebuilt position, with no duplicate (AC-4.3, AC-4.4)" do
      lists.each do |position, list|
        unit = position.units.find { |candidate| candidate.location.province == list.first.at }
        rebuilt = TA::Position.from_h(position.to_h)
        expect(TA.legal_orders(position, unit)).to eq(list)
        expect(TA.legal_orders(rebuilt, unit)).to eq(list)
        expect(list.uniq.size).to eq(list.size)
      end
    end
  end

  describe "the public surface (AC-7.5)" do
    it "adds only legal_orders, and keeps the generator private" do
      expect(TA.singleton_methods(false)).to contain_exactly(:check, :legal_orders)
      expect(TA.constants).to contain_exactly(:CheckResult, :DislodgedUnit, :InvalidInput, :Location, :Map,
                                              :Order, :Position, :Unit, :VERSION)
      expect { TA::LegalOrders }.to raise_error(NameError, /private constant/)
    end
  end
end

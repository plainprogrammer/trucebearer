# frozen_string_literal: true

require "trucebearer/adjudicator"
require_relative "../../support/board"
require_relative "../../support/reasons_table"

RSpec.describe "TA.check: the reasons table" do
  def u(power, type, at) = Board.unit(power, type, at)

  let(:start) { TA::Map.classic.starting_position }

  # One position and one order for each of the 17 reasons (AC-7.1).
  let(:examples) do
    lon_bel = Board.position(u(:england, :army, "lon"), u(:england, :army, "bel"))
    convoys = Board.position(u(:england, :army, "lon"), u(:england, :fleet, "nth"), u(:england, :fleet, "eng"))
    {
      wrong_phase: [TA::Position.from_h(start.to_h.merge("phase" => "retreat")), O::Hold.new(power: :england, at: :lon)],
      no_such_unit: [start, O::Hold.new(power: :england, at: :wal)],
      foreign_unit: [start, O::Hold.new(power: :france, at: :lon)],
      own_province: [start, O::Move.new(power: :england, at: :lon, destination: L.new(province: :lon))],
      not_reachable: [start, O::Move.new(power: :england, at: :lon, destination: L.new(province: :bel))],
      coast_not_allowed: [start, O::Move.new(power: :france, at: :mar, destination: L.new(province: :spa, coast: :nc))],
      coast_required: [Board.position(u(:france, :fleet, "por")), O::Move.new(power: :france, at: :por, destination: L.new(province: :spa))],
      coast_unreachable: [Board.position(u(:france, :fleet, "gol")),
                          O::Move.new(power: :france, at: :gol, destination: L.new(province: :spa, coast: :nc))],
      not_army: [Board.position(u(:england, :fleet, "lon")), O::MoveViaConvoy.new(power: :england, at: :lon, to: :wal)],
      not_adjacent: [Board.position(u(:england, :army, "lon")), O::MoveViaConvoy.new(power: :england, at: :lon, to: :bel)],
      no_convoy_route: [start, O::MoveViaConvoy.new(power: :england, at: :lvp, to: :wal)],
      same_province: [lon_bel, O::SupportMove.new(power: :england, at: :lon, from: :bel, to: :bel)],
      no_unit: [start, O::SupportHold.new(power: :germany, at: :mun, target: :sil)],
      move_impossible: [lon_bel, O::SupportMove.new(power: :england, at: :lon, from: :bel, to: :yor)],
      not_fleet_at_sea: [start, O::Convoy.new(power: :england, at: :lon, from: :lvp, to: :bel)],
      bad_endpoints: [convoys, O::Convoy.new(power: :england, at: :nth, from: :lon, to: :lon)],
      not_on_chain: [convoys, O::Convoy.new(power: :england, at: :eng, from: :lon, to: :nwy)]
    }
  end

  it "has the 17 reasons of the document's table, and the code accepts exactly those (AC-7.1)" do
    expect(ReasonsTable.all.size).to eq(17)
    expect(ReasonsTable.all).to match_array(TA::CheckResult::REASONS)
  end

  it "returns each of the 17 reasons for its own example (AC-7.1)" do
    expect(examples.keys).to match_array(ReasonsTable.all)
    examples.each do |reason, (position, order)|
      expect(Board.verdict(position, order)).to eq([reason]), "expected #{reason}"
    end
  end

  it "reads the rows of the document in the order the code follows (AC-7.3)" do
    expect(ReasonsTable.row("every order, checked first")).to eq(%i[wrong_phase no_such_unit foreign_unit])
    expect(ReasonsTable.row("Move")).to eq(%i[own_province not_reachable coast_not_allowed coast_required coast_unreachable])
    expect(ReasonsTable.row("MoveViaConvoy")).to eq(%i[not_army own_province not_adjacent no_convoy_route])
    expect(ReasonsTable.row("SupportHold")).to eq(%i[own_province no_unit not_reachable])
    expect(ReasonsTable.row("SupportMove")).to eq(%i[own_province same_province no_unit not_reachable move_impossible])
    expect(ReasonsTable.row("Convoy")).to eq(%i[not_fleet_at_sea bad_endpoints no_unit not_on_chain])
  end

  describe "the sweep (AC-7.2)" do
    let(:at_sea) do
      Board.position(u(:france, :fleet, "mao"), u(:france, :fleet, "gol"), u(:england, :fleet, "nth"),
                     u(:england, :army, "lon"), u(:russia, :fleet, "stp/sc"), u(:france, :fleet, "spa/nc"),
                     u(:turkey, :fleet, "bul/ec"), u(:italy, :army, "tus"), u(:germany, :fleet, "kie"))
    end
    # The other three split coasts, so units stand on all six.
    let(:other_coasts) do
      Board.position(u(:russia, :fleet, "stp/nc"), u(:france, :fleet, "spa/sc"), u(:turkey, :fleet, "bul/sc"),
                     u(:italy, :fleet, "ion"), u(:austria, :army, "tri"))
    end

    def all_orders(power, at, provinces)
      locations = Board.locations
      orders = [O::Hold.new(power: power, at: at)]
      orders += locations.map { |location| O::Move.new(power: power, at: at, destination: location) }
      orders += provinces.flat_map do |to|
        [O::MoveViaConvoy.new(power: power, at: at, to: to), O::SupportHold.new(power: power, at: at, target: to)]
      end
      orders + provinces.product(provinces).flat_map do |from, to|
        [O::SupportMove.new(power: power, at: at, from: from, to: to), O::Convoy.new(power: power, at: at, from: from, to: to)]
      end
    end

    it "never raises, and every result agrees with itself, for every order of every unit" do
      provinces = Board.provinces
      [start, at_sea, other_coasts].each do |position|
        position.units.each do |unit|
          [unit.power, :turkey == unit.power ? :austria : :turkey].each do |power|
            all_orders(power, unit.location.province, provinces).each do |order|
              result = TA.check(position, order)
              expect(result).to be_a(TA::CheckResult)
              expect(result.reasons.size).to eq(result.legal ? 0 : 1)
            end
          end
        end
      end
    end
  end
end

# frozen_string_literal: true

require "trucebearer/adjudicator"
require_relative "../../support/board"
require_relative "../../support/reasons_table"

# TA.check: what every order needs (Story 2). The first example is the first spec
# of the feature: the starting position, England's hold and France's hold.
RSpec.describe "TA.check" do
  let(:start) { TA::Map.classic.starting_position }

  it "gives England's hold at London no reasons, and France's hold for the same unit one" do
    expect(TA.check(start, O::Hold.new(power: :england, at: :lon)))
      .to eq(TA::CheckResult.new(legal: true, reasons: []))
    expect(TA.check(start, O::Hold.new(power: :france, at: :lon)))
      .to eq(TA::CheckResult.new(legal: false, reasons: [:foreign_unit]))
  end

  let(:retreat) { TA::Position.from_h(start.to_h.merge("phase" => "retreat")) }
  let(:adjustment) { TA::Position.from_h(start.to_h.merge("phase" => "adjustment")) }

  # One order of each of the six types for England's fleet in London, given by `power`.
  def orders_for_london(power)
    [O::Hold.new(power: power, at: :lon),
     O::Move.new(power: power, at: :lon, destination: L.new(province: :bel)),
     O::MoveViaConvoy.new(power: power, at: :lon, to: :wal),
     O::SupportHold.new(power: power, at: :lon, target: :wal),
     O::SupportMove.new(power: power, at: :lon, from: :lon, to: :wal),
     O::Convoy.new(power: power, at: :lon, from: :lvp, to: :bel)]
  end

  it "answers a legal order with legal true and no reasons (AC-2.5)" do
    result = TA.check(start, O::Hold.new(power: :england, at: :lon))
    expect([result.legal, result.reasons]).to eq([true, []])
  end

  it "makes a hold legal for every unit of a movement position (AC-2.5)" do
    start.units.each do |unit|
      order = O::Hold.new(power: unit.power, at: unit.location.province)
      expect(Board.verdict(start, order)).to eq([])
    end
  end

  it "gives :wrong_phase and nothing else outside the movement phase, for every order (AC-2.2)" do
    [retreat, adjustment].each do |position|
      orders_for_london(:england).each { |order| expect(Board.verdict(position, order)).to eq([:wrong_phase]) }
      orders_for_london(:france).each { |order| expect(Board.verdict(position, order)).to eq([:wrong_phase]) }
      empty = O::Hold.new(power: :england, at: :wal)
      expect(Board.verdict(position, empty)).to eq([:wrong_phase])
    end
  end

  it "gives :no_such_unit when no unit stands in the at province, for every order type (AC-2.3)" do
    nobody = [O::Hold.new(power: :england, at: :wal),
              O::Move.new(power: :england, at: :wal, destination: L.new(province: :lon)),
              O::MoveViaConvoy.new(power: :england, at: :wal, to: :lon),
              O::SupportHold.new(power: :england, at: :wal, target: :wal),
              O::SupportMove.new(power: :england, at: :wal, from: :wal, to: :wal),
              O::Convoy.new(power: :england, at: :wal, from: :wal, to: :wal)]
    nobody.each { |order| expect(Board.verdict(start, order)).to eq([:no_such_unit]) }
  end

  it "gives :foreign_unit for another power's unit, for every order type (AC-2.4)" do
    orders_for_london(:france).each { |order| expect(Board.verdict(start, order)).to eq([:foreign_unit]) }
  end

  it "checks the phase first, then the unit, then its owner (AC-2.2 to AC-2.4)" do
    expect(Board.verdict(retreat, O::Hold.new(power: :france, at: :wal))).to eq([:wrong_phase])
    expect(Board.verdict(start, O::Hold.new(power: :france, at: :wal))).to eq([:no_such_unit])
    expect(Board.verdict(start, O::Hold.new(power: :france, at: :lon))).to eq([:foreign_unit])
  end

  it "reads the position and the order alone, and changes neither (AC-2.6)" do
    order = O::SupportMove.new(power: :austria, at: :vie, from: :war, to: :gal)
    before = [start.to_h, order.to_h]
    first = TA.check(start, order)
    expect(TA.check(start, order)).to eq(first)
    expect([start.to_h, order.to_h]).to eq(before)
    unowned = start.with(ownership: {})
    expect(TA.check(unowned, order)).to eq(first)
  end

  it "judges a support for a foreign unit like one for the supporter's own (AC-2.6)" do
    order = O::SupportHold.new(power: :italy, at: :ven, target: :tri)
    foreign = Board.position(Board.unit(:italy, :army, "ven"), Board.unit(:austria, :army, "tri"))
    own = Board.position(Board.unit(:italy, :army, "ven"), Board.unit(:italy, :army, "tri"))
    expect(TA.check(foreign, order)).to eq(TA.check(own, order))
    expect(Board.verdict(foreign, order)).to eq([])
  end

  it "raises InvalidInput, naming the argument, for something that isn't a position or an order (AC-2.7)" do
    order = O::Hold.new(power: :england, at: :lon)
    [nil, start.to_h, :start].each do |bad|
      expect { TA.check(bad, order) }.to raise_error(TA::InvalidInput, /#{Regexp.escape(bad.inspect)}/)
    end
    [nil, order.to_h, :hold, TA::Unit.new(power: :england, type: :fleet, location: L.new(province: :lon))].each do |bad|
      expect { TA.check(start, bad) }.to raise_error(TA::InvalidInput, /#{Regexp.escape(bad.inspect)}/)
    end
  end
end

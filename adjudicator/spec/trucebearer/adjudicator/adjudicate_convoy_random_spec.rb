# frozen_string_literal: true

require "trucebearer/adjudicator"
require_relative "../../support/random_convoy_boards"
require_relative "../../support/reference"

# Convoys on seeded random boards (spec 015, Story 8). Small boards are checked against the
# brute-force reference of spec/support/reference.rb, which says whether a board holds a paradox
# and what every result must be; large boards are checked for validity, and, when no paradox
# is flagged, for being a consistent result.
RSpec.describe "TA.adjudicate on random boards with convoys" do
  small = Array.new(500) { |index| [index, Random.new(15_000 + index)] }.map do |index, rng|
    position, orders = RandomConvoyBoards.board(rng)
    [index, position, orders, TA.adjudicate(position, orders)]
  end
  large = Array.new(150) { |index| [index, Random.new(34_000 + index)] }.map do |index, rng|
    position, orders = RandomConvoyBoards.board(rng, size: rng.rand(13..34))
    [index, position, orders, TA.adjudicate(position, orders)]
  end

  def outcome_for(adjudication, entry)
    adjudication.outcomes.find { |o| o.order == entry.order && o.submitted } ||
      adjudication.outcomes.find { |o| o.order.at == entry.province && !o.submitted }
  end

  def placed_once(position, adjudication)
    after = adjudication.position
    (after.units + after.dislodged_units.map(&:unit)).map { |unit| [unit.power, unit.type] }.tally ==
      position.units.map { |unit| [unit.power, unit.type] }.tally
  end

  def no_self_dislodgement(position, adjudication)
    adjudication.position.dislodged_units.none? do |entry|
      position.units.find { |unit| unit.location.province == entry.attacker_from }.power == entry.unit.power
    end
  end

  it "adjudicates every board, builds a valid position, keeps every unit once and dislodges no unit of its own power (AC-8.2)" do
    (small + large).each do |index, position, orders, adjudication|
      expect(adjudication).to be_a(TA::Adjudication), "board #{index}"
      expect(adjudication.outcomes.size).to be >= orders.size
      expect(placed_once(position, adjudication)).to be(true), "board #{index}"
      expect(no_self_dislodgement(position, adjudication)).to be(true), "board #{index}"
    end
  end

  it "sets the flag exactly when the reference finds none or more than one result, and gives the reference's results otherwise (AC-8.3)" do
    small.each do |index, position, orders, adjudication|
      entries = Reference.entries(position, orders)
      solutions = Reference.solutions(entries)
      expect(adjudication.paradox).to be(solutions.size != 1), "board #{index}"
      next if adjudication.paradox

      wanted = Reference.results(entries, solutions.first)
      entries.each do |entry|
        outcome = outcome_for(adjudication, entry)
        expect([outcome.result, outcome.dislodged]).to eq(wanted.fetch(entry)), "board #{index}, unit at #{entry.province}"
      end
    end
  end

  it "holds each hard shape in at least 20 small boards, counted from the orders and the reference (AC-8.1)" do
    counts = Hash.new(0)
    small.each do |_, position, orders, adjudication|
      entries = Reference.entries(position, orders)
      counts[:convoyed] += 1 if entries.any? { |entry| entry.move? && Reference.convoy?(entry, entries) }
      counts[:carrier_dislodged] += 1 if adjudication.outcomes.any? { |o| o.order.is_a?(O::Convoy) && o.result == :disrupted }
      counts[:swap_by_convoy] += 1 if Reference.circles(entries).any? { |circle| circle.size == 2 }
      counts[:circle_with_convoy] += 1 if Reference.circles(entries).any? { |circle| circle.size >= 3 && circle.any? { |move| Reference.convoy?(move, entries) } }
      counts[:paradox] += 1 if Reference.paradox?(entries)
      counts[:convoyed_no_paradox] += 1 if entries.any? { |entry| entry.move? && Reference.convoy?(entry, entries) } && !Reference.paradox?(entries)
    end
    expect(counts.values_at(:convoyed, :carrier_dislodged, :swap_by_convoy, :circle_with_convoy, :paradox, :convoyed_no_paradox).min).to be >= 20,
           counts.inspect
  end

  it "gives a result that is consistent with the conditions on every large board with no paradox flagged (AC-8.2)" do
    large.each do |index, position, orders, adjudication|
      entries = Reference.entries(position, orders)
      if adjudication.paradox
        expect(entries.any? { |entry| entry.move? && Reference.convoy?(entry, entries) }).to be(true), "board #{index}"
        next
      end

      success = entries.select(&:move?).to_h { |entry| [entry, outcome_for(adjudication, entry).result == :succeeded] }
      expect(Reference.consistent?(entries, success)).to be(true), "board #{index}"
      wanted = Reference.results(entries, success)
      entries.each do |entry|
        outcome = outcome_for(adjudication, entry)
        expect([outcome.result, outcome.dislodged]).to eq(wanted.fetch(entry)), "board #{index}, unit at #{entry.province}"
      end
    end
  end

  it "sets the flag only where a move goes by convoy (AC-8.4)" do
    (small + large).select { |*, adjudication| adjudication.paradox }.each do |index, position, orders, _|
      entries = Reference.entries(position, orders)
      expect(entries.any? { |entry| entry.move? && Reference.convoy?(entry, entries) }).to be(true), "board #{index}"
    end
  end

  it "gives the same flag, a valid position and, with no paradox, the same results for shuffled orders (AC-8.6)" do
    key = lambda do |adjudication|
      adjudication.outcomes.to_h { |o| [o.order, [o.result, o.submitted, o.dislodged]] }
    end
    (small + large).each_with_index do |(index, position, orders, adjudication), number|
      shuffled = TA.adjudicate(position, orders.shuffle(random: Random.new(number)))
      expect(shuffled.paradox).to be(adjudication.paradox), "board #{index}"
      expect(placed_once(position, shuffled)).to be(true), "board #{index}"
      expect([key.call(shuffled), shuffled.position]).to eq([key.call(adjudication), adjudication.position]) unless adjudication.paradox
    end
  end

  it "adjudicates a position of 34 units with convoys in under a second (AC-8.5)" do
    position, orders = RandomConvoyBoards.board(Random.new(34), size: 34)
    expect(position.units.size).to eq(34)
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    TA.adjudicate(position, orders)
    expect(Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).to be < 1.0
  end
end

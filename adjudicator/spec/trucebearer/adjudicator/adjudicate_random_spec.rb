# frozen_string_literal: true

require "trucebearer/adjudicator"
require_relative "../../support/random_boards"
require_relative "../../support/conditions"

# Correctness beyond the DATC (Story 12): seeded random boards, with the hard shapes built in on
# purpose. Every board is adjudicated, and the result has to satisfy the conditions of the DATC,
# re-stated in spec/support/conditions.rb (AC-12.1 to AC-12.5).
RSpec.describe "TA.adjudicate on random boards" do
  per_shape = { plain: 120, circle: 40, pure_circle: 40, head_to_head: 40, supporter_attacked: 40, beleaguered: 40 }.freeze

  boards = per_shape.flat_map do |shape, count|
    rng = Random.new(shape.to_s.sum * 1_000 + 14)
    Array.new(count) { |index| [shape, index, *RandomBoards.board(rng, shape)] }
  end
  results = boards.map { |shape, index, position, orders| [shape, index, position, orders, TA.adjudicate(position, orders)] }

  it "adjudicates every board, builds a valid position, and keeps every unit once (AC-12.1)" do
    expect(boards.size).to eq(320)
    expect(boards.map { |_, _, position, _| position.units.size }.max).to be <= 34
    results.each do |shape, index, position, orders, adjudication|
      expect(adjudication).to be_a(TA::Adjudication), "#{shape} board #{index}"
      expect(adjudication.outcomes.size).to be >= orders.size
      moved = adjudication.position.units.size + adjudication.position.dislodged_units.size
      expect(moved).to eq(position.units.size), "#{shape} board #{index}"
    end
  end

  it "holds each hard shape in at least 20 boards, found from the orders and not from the generator (AC-12.1)" do
    counts = Hash.new(0)
    results.each do |_, _, position, orders, _|
      counts[:circle] += 1 if RandomBoards.circle?(orders)
      counts[:head_to_head] += 1 if RandomBoards.head_to_head?(orders)
      counts[:supporter_attacked] += 1 if RandomBoards.supporter_attacked?(orders)
      counts[:beleaguered] += 1 if RandomBoards.beleaguered?(position, orders)
    end
    expect(counts.values_at(:circle, :head_to_head, :supporter_attacked, :beleaguered).min).to be >= 20, counts.inspect
  end

  it "never sets the paradox flag: without a convoy no move can wait on a route (AC-12.2)" do
    expect(results.map { |*, adjudication| adjudication.paradox }).to all(be(false))
  end

  it "satisfies the conditions of the DATC on every board (AC-12.3)" do
    results.each do |shape, index, position, _, adjudication|
      expect(Conditions.violations(position, adjudication)).to eq([]), "#{shape} board #{index}"
    end
  end

  it "moves every unit of a circle that nothing else touches (AC-12.3)" do
    results.select { |shape, *| shape == :pure_circle }.each do |_, index, position, orders, adjudication|
      expect(orders.size).to be >= 3
      expect(adjudication.outcomes.map(&:result)).to all(eq(:succeeded)), "pure circle board #{index}"
      expect(adjudication.position.units.size).to eq(position.units.size)
    end
  end

  it "gives the same results when the orders are shuffled (AC-12.4)" do
    key = lambda do |adjudication|
      [adjudication.outcomes.to_h { |outcome| [outcome.order, [outcome.result, outcome.submitted, outcome.dislodged]] },
       adjudication.position, adjudication.paradox]
    end
    results.each_with_index do |(shape, index, position, orders, adjudication), number|
      shuffled = TA.adjudicate(position, orders.shuffle(random: Random.new(number)))
      expect(key.call(shuffled)).to eq(key.call(adjudication)), "#{shape} board #{index}"
    end
  end

  it "adjudicates a position of 34 units in under a second (AC-12.5)" do
    rng = Random.new(34)
    position, orders = RandomBoards.board(rng, :plain, size: 34)
    expect(position.units.size).to eq(34)
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    TA.adjudicate(position, orders)
    expect(Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).to be < 1.0
  end
end

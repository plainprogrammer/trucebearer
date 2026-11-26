# frozen_string_literal: true

require "trucebearer/adjudicator"
require_relative "../../support/board"
require_relative "../../support/legal_positions"

# TA.legal_orders is fast enough to call for every unit on each page load (Story 6).
# The targets are in spec 012 (22 starting units under 100 ms, a 34-unit mid-game board
# under 250 ms, the stress position under 1 s). The ceilings here are far above them so a
# slow CI machine can't fail the spec; the ratio check is what notices a fall back to
# filtering every candidate through TA.check. If the ratio check ever flakes, drop it and keep
# the ceilings.
RSpec.describe "TA.legal_orders speed" do
  def seconds
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    yield
    Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
  end

  def median(values) = values.sort[values.size / 2]

  def list_every_unit(position) = position.units.map { |unit| TA.legal_orders(position, unit) }

  # Approach A: every candidate of the whole candidate space, through TA.check.
  def filter_every_candidate(position)
    position.units.map { |unit| LegalPositions.candidates(unit).select { |order| TA.check(position, order).legal } }
  end

  it "lists the 22 units of the starting position in under a second (AC-6.1)" do
    start = LegalPositions.start
    list_every_unit(start) # warm-up, not timed
    expect(median(Array.new(3) { seconds { list_every_unit(start) } })).to be < 1.0
  end

  it "lists the 39 units of the stress position in under five seconds (AC-6.2)" do
    stress = LegalPositions.stress
    list_every_unit(stress)
    expect(median(Array.new(3) { seconds { list_every_unit(stress) } })).to be < 5.0
  end

  it "is at least ten times faster than filtering every candidate, with the same orders (AC-6.3)" do
    start = LegalPositions.start
    list_every_unit(start)
    filter_every_candidate(start)
    listed = nil
    filtered = nil
    fast = median(Array.new(5) { seconds { listed = list_every_unit(start) } })
    slow = median(Array.new(3) { seconds { filtered = filter_every_candidate(start) } })

    expect(slow).to be >= 10 * fast
    expect(listed.zip(filtered).all? { |a, b| a.sort_by(&:inspect) == b.sort_by(&:inspect) }).to be(true)
  end
end

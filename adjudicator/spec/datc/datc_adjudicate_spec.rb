# frozen_string_literal: true

require "trucebearer/adjudicator"
require_relative "../support/datc"

# Adjudicates every DATC fixture that has an `after:` (Story 11), and keeps the set of those
# fixtures exactly Datc::ADJUDICATED (AC-11.2). The expectation is read from the fixture
# alone (Datc.expected_outcomes), so it doesn't depend on the engine. See spec 014, "DATC
# cases", for what is encoded, what is left out and why.
RSpec.describe "DATC fixtures: adjudication" do
  cases = Datc.load_all.select(&:after)

  # Every order of every case, adjudicated in any order. A case of up to five orders is tried
  # in every order; the others in a few shuffles (AC-9.1).
  def outcomes_by_order(adjudication)
    adjudication.outcomes.to_h { |outcome| [outcome.order, [outcome.result, outcome.submitted, outcome.dislodged]] }
  end

  cases.each do |kase|
    describe kase.id do
      let(:orders) { kase.entries.map(&:order) }
      let(:adjudication) { TA.adjudicate(kase.position, orders) }
      let(:expected) { Datc.expected_outcomes(kase) }

      kase.entries.each_with_index do |entry, index|
        it "gives order #{index + 1} (#{entry.order.class.name.split("::").last} at #{entry.order.at}) the result #{entry.result}" do
          outcome = adjudication.outcomes[index]
          expect([outcome.order, outcome.result, outcome.dislodged, outcome.submitted])
            .to eq([entry.order, entry.result, entry.dislodged, true])
        end
      end

      it "gives the implied holds, last and sorted by province, and no outcome besides" do
        expect(adjudication.outcomes).to eq(expected)
      end

      it "gives the position after the moves, with no paradox" do
        expect(adjudication.position).to eq(kase.after)
        expect(adjudication.paradox).to be(false)
      end

      it "gives the same results for the orders given in any order (AC-9.1)" do
        baseline = [outcomes_by_order(adjudication), adjudication.position, adjudication.paradox]
        arrangements = orders.size <= 5 ? orders.permutation.to_a : Array.new(6) { |seed| orders.shuffle(random: Random.new(seed)) }
        arrangements.each do |arranged|
          other = TA.adjudicate(kase.position, arranged)
          expect([outcomes_by_order(other), other.position, other.paradox]).to eq(baseline)
        end
      end
    end
  end
end

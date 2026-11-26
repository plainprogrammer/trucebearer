# frozen_string_literal: true

require "trucebearer/adjudicator"
require_relative "../support/datc"

# Adjudicates every DATC fixture that has an `after:` (Story 11), and keeps the set of those
# fixtures exactly Datc::ADJUDICATED (AC-11.2). The expectation is read from the fixture
# alone (Datc.expected_outcomes), so it doesn't depend on the engine. See spec 014, "DATC
# cases", for what is encoded, what is left out and why.
RSpec.describe "DATC fixtures: adjudication" do
  cases = Datc.load_all.select(&:after)

  it "has an after: in exactly the encoded files, and in none of the cases left out (AC-11.2)" do
    expect(Datc::ADJUDICATED.size).to eq(80)
    expect(cases.map(&:id).sort).to eq(Datc::ADJUDICATED)
    without = Datc.load_all.reject(&:after).map(&:id)
    expect(without).to eq(Datc::CHECKING_ONLY)
    left_out = %w[6.B.9 6.B.14 6.C.4 6.C.5 6.C.6 6.C.7 6.D.6 6.D.16 6.E.11 6.F.12 6.G.7]
    expect(cases.map(&:id) & left_out).to eq([])
  end

  it "marks only 6.B.2 and 6.B.12 as departures, and their results are the strict ones (AC-8.4)" do
    expect(cases.select(&:departure).map(&:id).sort).to eq(%w[6.B.12 6.B.2])
    %w[6.B.2 6.B.12].each do |id|
      kase = cases.find { _1.id == id }
      expect(kase.entries.map(&:result)).to eq([:void])
      expect(kase.after.units).to eq(kase.position.units)
    end
  end

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

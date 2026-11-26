# frozen_string_literal: true

require "trucebearer/adjudicator"
require_relative "../support/datc"

# Adjudicates every DATC fixture that has an `after:` (Story 11), and keeps the set of those
# fixtures exactly Datc::ADJUDICATED (AC-11.2). The expectation is read from the fixture
# alone (Datc.expected_outcomes), so it doesn't depend on the engine. See spec 014 and spec
# 015, "DATC cases", for what is encoded, what is left out and why. The convoy paradoxes that
# wait for #39 (Datc::PARADOX_PENDING) are only tested for the flag and a valid position.
RSpec.describe "DATC fixtures: adjudication" do
  cases = Datc.load_all.select(&:after)

  it "has an after: in exactly the encoded files, and in none of the cases left out (AC-11.2)" do
    expect(Datc::ADJUDICATED.size).to eq(126)
    expect(cases.map(&:id).sort).to eq(Datc::ADJUDICATED)
    without = Datc.load_all.reject(&:after).map(&:id)
    expect(without).to eq(Datc::PARADOX_PENDING)
    expect(Datc.load_all.select(&:paradox).map(&:id)).to eq(Datc::PARADOX_PENDING)
    left_out = %w[6.B.9 6.B.14]
    expect(cases.map(&:id) & left_out).to eq([])
  end

  it "marks only 6.B.2 and 6.B.12 as departures, and their results are the strict ones (AC-11.3)" do
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

  # The convoy paradoxes of the contract's list. Their result is unspecified until 0.3 (#39),
  # so each is tested for what the contract promises: the flag is set, nothing raises, the
  # position is valid and every unit is in it once (AC-6.2, AC-6.7 of spec 015).
  Datc.load_all.select(&:paradox).each do |kase|
    describe "#{kase.id} (convoy paradox, result pending: #39)" do
      let(:orders) { kase.entries.map(&:order) }
      let(:units_in_place) { kase.position.units.map { |unit| [unit.power, unit.type] }.tally }

      def kept_once(adjudication)
        position = adjudication.position
        (position.units + position.dislodged_units.map(&:unit)).map { |unit| [unit.power, unit.type] }.tally
      end

      def implied_holds(kase)
        legal = kase.entries.select { |entry| entry.expected.legal }.map(&:order)
        kase.position.units.count { |unit| legal.none? { |order| order.at == unit.location.province && order.power == unit.power } }
      end

      it "sets the paradox flag, builds a valid position and keeps every unit once" do
        adjudication = TA.adjudicate(kase.position, orders)
        expect(adjudication.paradox).to be(true)
        expect(adjudication.position).to be_a(TA::Position)
        expect(adjudication.position.phase).to eq(:retreat)
        expect(kept_once(adjudication)).to eq(units_in_place)
        expect(adjudication.outcomes.size).to eq(orders.size + implied_holds(kase))
      end

      it "gives the same flag and a valid position for the orders in any order" do
        arrangements = Array.new(6) { |seed| orders.shuffle(random: Random.new(seed)) }
        arrangements.each do |arranged|
          other = TA.adjudicate(kase.position, arranged)
          expect(other.paradox).to be(true)
          expect(kept_once(other)).to eq(units_in_place)
          expect(other.outcomes.size).to eq(orders.size + implied_holds(kase))
        end
      end

      it "gives the preferred result of the DATC" do
        skip "paradox resolution: #39"
      end
    end
  end
end

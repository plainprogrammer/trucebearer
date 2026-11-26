# frozen_string_literal: true

require "trucebearer/adjudicator"
require_relative "../support/datc"
require_relative "../support/reference"

# The reference of the conditions (spec/support/reference.rb) run over every DATC fixture: the
# adjudicated cases have exactly one consistent result, and it is the one the fixture records;
# the convoy paradoxes that wait for #39 have none or more than one (AC-6.3 of spec 015). The
# reference is written from the contract and the DATC, apart from the resolver, so this checks
# the fixtures' results and the resolver's flag without either vouching for the other.
RSpec.describe "DATC fixtures: the reference of the conditions" do
  Datc.load_all.each do |kase|
    describe kase.id do
      let(:entries) { Reference.entries(kase.position, kase.entries.map(&:order)) }
      let(:solutions) { Reference.solutions(entries) }

      if kase.paradox
        it "has no consistent result, or more than one" do
          expect([0, 2]).to include(solutions.size)
        end
      else
        it "has one consistent result, and the fixture records it" do
          expect(solutions.size).to eq(1)
          wanted = Reference.results(entries, solutions.first)
          kase.entries.each do |fixture|
            if fixture.expected.legal
              entry = entries.find { |candidate| candidate.order == fixture.order }
              expect(wanted.fetch(entry)).to eq([fixture.result, fixture.dislodged]), "order at #{fixture.order.at}"
            else
              expect(fixture.result).to eq(:void)
            end
          end
          recorded = kase.after.dislodged_units.to_h { |lost| [lost.unit.location.province, [lost.attacker_from, lost.by_convoy]] }
          expect(Reference.attackers(entries, solutions.first)).to eq(recorded)
        end
      end
    end
  end

  # The two named ways a paradox shows (AC-5.3): two consistent results, and none.
  it "finds two results for the simplest paradox (the paradox_pos example) and none for the betrayal case" do
    units = [Board.unit(:england, :fleet, "lon"), Board.unit(:england, :fleet, "wal"),
             Board.unit(:france, :army, "bre"), Board.unit(:france, :fleet, "eng")]
    orders = [O::Move.new(power: :england, at: :wal, destination: L.new(province: :eng)),
              O::SupportMove.new(power: :england, at: :lon, from: :wal, to: :eng),
              O::Move.new(power: :france, at: :bre, destination: L.new(province: :lon)),
              O::Convoy.new(power: :france, at: :eng, from: :bre, to: :lon)]
    expect(Reference.solutions(Reference.entries(Board.position(*units), orders)).size).to eq(2)
    betrayal = Datc.load_all.find { |kase| kase.id == "6.F.18" }
    expect(Reference.solutions(Reference.entries(betrayal.position, betrayal.entries.map(&:order))).size).to eq(0)
  end
end

# frozen_string_literal: true

require "trucebearer/adjudicator"
require_relative "../../support/board"
require_relative "../../support/legal_positions"

# TA.legal_orders and TA.check say the same thing (Story 5). For every unit of every
# sampled position, every listed order passes TA.check (AC-5.1), and every order of the
# unit's whole candidate space that passes TA.check is listed (AC-5.2). The candidate space
# is built here, not by the generator, so a narrowing that is too tight can't hide.
# It takes about 12 seconds in all, so it is tagged :slow. The tag only names it: .rspec has no
# filter and CI runs `bundle exec rspec`, so it runs in CI with everything else.
RSpec.describe "TA.legal_orders agrees with TA.check", :slow do
  it "builds a candidate space of 11,482 orders for a unit" do
    expect(LegalPositions.candidates(Board.unit(:england, :fleet, "lon")).size).to eq(11_482)
  end

  LegalPositions.samples.each do |name, position|
    it "agrees in both directions for every unit of #{name}" do
      aggregate_failures do
        position.units.each do |unit|
          listed = TA.legal_orders(position, unit)
          passing = LegalPositions.candidates(unit).select { |order| TA.check(position, order).legal }

          extra = listed - passing
          missing = passing - listed
          expect(extra).to eq([]), "#{unit.inspect}: listed but refused by TA.check, e.g. #{extra.first(3).inspect}"
          expect(missing).to eq([]), "#{unit.inspect}: legal but not listed, e.g. #{missing.first(3).inspect}"
          expect(listed.size).to eq(listed.uniq.size), "#{unit.inspect}: the list holds a duplicate"
        end
      end
    end
  end

  %i[retreat adjustment].each do |phase|
    it "agrees, with both sides empty, in the #{phase} phase" do
      position = TA::Position.from_h(LegalPositions.start.to_h.merge("phase" => phase.to_s))
      position.units.first(2).each do |unit|
        expect(TA.legal_orders(position, unit)).to eq([])
        expect(LegalPositions.candidates(unit).count { |order| TA.check(position, order).legal }).to eq(0)
      end
    end
  end
end

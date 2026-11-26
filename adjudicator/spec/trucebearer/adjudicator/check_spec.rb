# frozen_string_literal: true

require "trucebearer/adjudicator"
require_relative "../../support/board"

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
end

# frozen_string_literal: true

require "json"
require "trucebearer/adjudicator"
require_relative "../../support/board"

# Every Ruby example in docs/interface.md that is about the value objects built by
# issue #10 (Location, Unit, DislodgedUnit, Position, Order and its six classes,
# Canonical order, Impossible objects, Map#starting_position, and the from_h examples
# under Errors), run as a spec. Each example is built as the document builds it.
#
# Excluded, because they belong to later issues (AC-7.3):
#   - both TA::CheckResult examples, and the three CheckResult lines at the end of
#     "Impossible objects" (#11);
#   - the TA::Outcome and TA::Adjudication examples (#14);
#   - the TA.check, TA.legal_orders and TA.adjudicate calls in their own sections.
RSpec.describe "docs/interface.md examples" do
  describe "TA::Location, TA::Unit and TA::DislodgedUnit" do
    it "gives the hash forms the document shows" do
      expect(L.new(province: :spa, coast: :nc).to_h).to eq("province" => "spa", "coast" => "nc")
      expect(L.new(province: :bud).to_h).to eq("province" => "bud", "coast" => nil)
      expect(TA::Unit.new(power: :russia, type: :fleet, location: L.new(province: :stp, coast: :sc)).to_h)
        .to eq("power" => "russia", "type" => "fleet", "location" => { "province" => "stp", "coast" => "sc" })
      expect(TA::DislodgedUnit.new(
        unit: TA::Unit.new(power: :austria, type: :army, location: L.new(province: :ser)),
        attacker_from: :bul, by_convoy: false
      ).to_h).to eq("unit" => { "power" => "austria", "type" => "army", "location" => { "province" => "ser", "coast" => nil } },
                    "attacker_from" => "bul", "by_convoy" => false)
    end
  end
end

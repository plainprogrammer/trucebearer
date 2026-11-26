require "rails_helper"
require_relative "../support/rules_helpers"

# Spec 027 D7, AC-7.13: a revealed phase's position is what it was adjudicated from, so it can't change.
RSpec.describe Phase, "position guard" do
  include RulesHelpers

  let(:game) { Game.start!(power: "england").game }
  let(:other) { RulesEngine.set_date(RulesEngine.starting_position, season: "fall", year: 1902) }

  it "lets an open phase's position change" do
    phase = game.current_phase

    expect(phase.update(position: other)).to be(true)
  end

  it "refuses a changed position once the phase is revealed, and still lets the reveal itself through" do
    phase = game.current_phase
    phase.reveal!

    phase.reload
    expect(phase.update(position: other)).to be(false)
    expect(phase.errors[:position]).to be_present
    expect(phase.reload.update(updated_at: Time.current)).to be(true) # a save that leaves the position alone is fine
  end
end

require "rails_helper"
require_relative "../support/rules_helpers"

# Spec 026 D11 and Story 11: Game#host_history, the host page's one list, and its order.
RSpec.describe Game, "#host_history" do
  include RulesHelpers
  include ActiveSupport::Testing::TimeHelpers

  let(:started) { Game.start!(power: "england") }
  let(:game) { started.game }
  let(:phase) { game.current_phase }
  let!(:france) { game.take_seat!("france").first }

  let(:add_army) { { "action" => "unit_added", "power" => "france", "type" => "army", "province" => "bur", "coast" => nil } }

  def summary = game.host_history.map { |entry| [ entry.kind, entry.phase.number ] }

  it "lists a phase's reissue, step-in and edit, then its reveal, then the next phase's rows, at one instant (AC-11.2)" do
    now = Time.current.change(usec: 0)
    travel_to(now) do
      game.edit_position!(1, add_army)
      StepIn.record!(phase: phase, seat: france)
      game.reissue_seat!(france)
      phase.reload.reveal!
      game.reissue_seat!(france)
      game.edit_position!(2, add_army.merge("province" => "gas"))
    end

    expect(summary).to eq([ [ :reissue, 1 ], [ :step_in, 1 ], [ :position_edit, 1 ], [ :reveal, 1 ], [ :reissue, 2 ], [ :position_edit, 2 ] ])
    expect(game.seat_history.map(&:kind)).to eq(%i[reissue reissue step_in position_edit position_edit]) # no reveal, and the old order
  end

  it "orders rows by their own times first" do
    travel_to(Time.utc(2026, 11, 26, 20, 40)) { game.reissue_seat!(france) }
    travel_to(Time.utc(2026, 11, 26, 20, 41)) { StepIn.record!(phase: phase, seat: france) }
    travel_to(Time.utc(2026, 11, 26, 20, 42)) { phase.reload.reveal! }
    travel_to(Time.utc(2026, 11, 26, 20, 43)) { game.reissue_seat!(france) }

    expect(summary).to eq([ [ :reissue, 1 ], [ :step_in, 1 ], [ :reveal, 1 ], [ :reissue, 2 ] ])
  end

  it "gives a reveal entry its phase's title data: kind, phase, the time of the reveal and an id" do
    travel_to(Time.utc(2026, 11, 26, 20, 42)) { phase.reload.reveal! }
    entry = game.host_history.first

    expect(entry.kind).to eq(:reveal)
    expect(entry.phase).to eq(Phase.find(entry.id))
    expect(entry.created_at).to eq(Time.utc(2026, 11, 26, 20, 42))
  end

  it "never lists the open phase as a reveal, whatever it holds (AC-11.5)" do
    france.save_orders!(phase, { "par" => json_of(rules_order(:hold, :france, :par)) }, submit: true)

    expect(game.host_history).to be_empty
    phase.reload.reveal!
    game.current_phase.then { |open| france.save_orders!(open, { "par" => json_of(rules_order(:hold, :france, :par)) }, submit: true) }

    expect(game.host_history.select { |entry| entry.kind == :reveal }.map { |entry| entry.phase.number }).to eq([ 1 ])
  end
end

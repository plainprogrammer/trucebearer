require "rails_helper"
require_relative "../support/rules_helpers"

# Spec 022 D2, AC-2.10, AC-6.5, AC-7.7: a saved order, its storage form, and its refusal to change after the reveal.
RSpec.describe SavedOrder do
  include RulesHelpers

  let(:game) { Game.start!(power: "england").game }
  let(:seat) { game.seats.first }
  let(:phase) { game.current_phase }
  let(:hold) { rules_order(:hold, :england, :lon) }

  def reveal_directly(phase)
    phase.update_columns(adjudication: RulesEngine.adjudicate(RulesEngine.starting_position, []), revealed_at: Time.current)
  end

  it "reads back equal to what was saved, stored as the hash form with its format (AC-2.10)" do
    SavedOrder.create!(phase: phase, seat: seat, province: "lon", content: hold)

    expect(SavedOrder.last.content).to eq(hold)
    raw = SavedOrder.connection.select_value("SELECT content FROM saved_orders")
    expect(JSON.parse(raw)).to eq({ "format" => 1, "type" => "hold", "power" => "england", "at" => "lon" })
  end

  it "keeps one order per unit in a phase for a seat" do
    SavedOrder.create!(phase: phase, seat: seat, province: "lon", content: hold)

    expect { SavedOrder.create!(phase: phase, seat: seat, province: "lon", content: hold) }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it "hides its content from inspect, and shows nothing of the order (AC-7.7)" do
    order = SavedOrder.new(phase: phase, seat: seat, province: "lon", content: hold)

    expect(order.inspect).to include("content: [FILTERED]")
    expect(order.inspect).not_to include("hold")
  end

  describe "after the reveal (AC-6.5)" do
    it "refuses to create an order, or a submission, for a revealed phase" do
      reveal_directly(phase)
      phase.reload

      expect { SavedOrder.create!(phase: phase, seat: seat, province: "lon", content: hold) }.to raise_error(ActiveRecord::RecordInvalid)
      expect { Submission.create!(phase: phase, seat: seat) }.to raise_error(ActiveRecord::RecordInvalid)
    end

    it "refuses to destroy a submission made before the reveal" do
      submission = Submission.create!(phase: phase, seat: seat)
      reveal_directly(phase)

      expect { submission.reload.destroy! }.to raise_error(ActiveRecord::RecordNotDestroyed)
      expect(Submission.count).to eq(1)
    end

    it "refuses to destroy or change an order saved before the reveal" do
      order = SavedOrder.create!(phase: phase, seat: seat, province: "lon", content: hold)
      reveal_directly(phase)

      expect { order.reload.destroy! }.to raise_error(ActiveRecord::RecordNotDestroyed)
      expect { order.reload.update!(content: rules_order(:hold, :england, :lon)) }.to raise_error(ActiveRecord::RecordInvalid)
      expect(SavedOrder.count).to eq(1)
    end
  end
end

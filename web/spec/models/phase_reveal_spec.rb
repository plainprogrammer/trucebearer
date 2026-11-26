require "rails_helper"
require_relative "../support/rules_helpers"

# Spec 022 FR-7, FR-8: Phase#reveal!, with one connection and no HTTP. The concurrent cases are in phase_concurrency_spec.
RSpec.describe Phase, "#reveal!" do
  include RulesHelpers

  let(:game) { Game.start!(power: "england").game }
  let(:england) { game.seats.find_by(power: "england") }
  let(:france) { game.take_seat!("france").first }
  let(:phase) { game.current_phase }
  let(:calls) { [] }

  def spy_on_adjudicate
    allow(RulesEngine).to receive(:adjudicate).and_wrap_original do |original, *args|
      calls << args
      original.call(*args)
    end
  end

  describe "the reveal (AC-4.5 to AC-4.8)" do
    before do
      england.save_orders!(phase, { "lon" => json_of(move(:england, :lon, :nth)) }, submit: true)
      france.save_orders!(phase, { "par" => json_of(rules_order(:hold, :france, :par)) }) # saved, never submitted
      spy_on_adjudicate
    end

    it "adjudicates once, with the position and every seat's orders listed by power and then province (AC-4.6, AC-4.7)" do
      result = phase.reveal!

      expect(result).to eq(Phase::Reveal.new(status: :revealed))
      expect(calls.size).to eq(1)
      position, orders = calls.first
      expect(position).to eq(RulesEngine.starting_position)
      expect(orders).to eq([ move(:england, :lon, :nth), rules_order(:hold, :france, :par) ])
    end

    it "stores the adjudication and the revealed time, and every unit without an order is an implied hold (AC-4.5, AC-4.6)" do
      phase.reveal!

      stored = Phase.find(phase.id)
      expect(stored.revealed_at).to be_present
      expect(stored).not_to be_open
      outcomes = stored.adjudication.outcomes
      expect(outcomes.count(&:submitted)).to eq(2)
      expect(outcomes.reject(&:submitted).size).to eq(20)
      expect(outcomes.first.result).to eq(:succeeded)
      expect(stored.adjudication.position.phase).to eq(:retreat)
    end

    it "opens the next phase, number 2, with the next movement position (AC-4.5, AC-5.2)" do
      phase.reveal!

      upcoming = game.current_phase
      expect(upcoming.number).to eq(2)
      expect(upcoming).to be_open
      expect(upcoming.position).to eq(RulesEngine.next_movement_position(Phase.find(phase.id).adjudication.position))
      expect(upcoming.title).to eq("Fall 1901 · Movement")
      expect(game.history.map(&:number)).to eq([ 1 ])
    end

    it "does nothing the second time: no adjudication, no phase, the same answer for a retry (AC-4.8)" do
      phase.reveal!

      again = Phase.find(phase.id).reveal!

      expect(again).to eq(Phase::Reveal.new(status: :already))
      expect(calls.size).to eq(1)
      expect(game.phases.count).to eq(2)
    end

    it "updates the object it was called on, so the caller sees the reveal" do
      phase.reveal!

      expect(phase).not_to be_open
      expect(phase.adjudication).to be_present
    end
  end

  describe "when it fails (AC-4.10, D8)" do
    def expect_untouched
      stored = Phase.find(phase.id)
      expect(stored).to be_open
      expect(stored.adjudication).to be_nil
      expect(game.phases.count).to eq(1)
    end

    it "rolls back when the gem refuses the adjudication" do
      allow(RulesEngine).to receive(:adjudicate).and_raise(RulesEngine::InvalidInput, "no good")

      expect { phase.reveal! }.to raise_error(RulesEngine::InvalidInput)
      expect_untouched
    end

    it "rolls back when the next position cannot be built, and does not hide the error" do
      allow(RulesEngine).to receive(:next_movement_position).and_raise(RuntimeError, "boom")

      expect { phase.reveal! }.to raise_error(RuntimeError, "boom")
      expect_untouched
    end

    it "rolls back when storing the next phase fails" do
      phase # the game and its first phase are made before the stub
      allow_any_instance_of(Phase).to receive(:save!).and_raise(ActiveRecord::StatementInvalid, "disk") # the next phase is the only one saved

      expect { phase.reveal! }.to raise_error(ActiveRecord::StatementInvalid)
      expect_untouched
    end

    it "raises Conflict and rolls back when the conditional write finds the phase already revealed (the backstop of D8)" do
      real = RulesEngine.adjudicate(RulesEngine.starting_position, [])
      id = phase.id
      allow(RulesEngine).to receive(:adjudicate).and_wrap_original do |original, *args|
        Phase.where(id: id).update_all(adjudication: real, revealed_at: Time.current) # another writer got in
        original.call(*args)
      end

      expect { phase.reveal! }.to raise_error(Phase::Conflict)
      expect_untouched
    end
  end

  describe "a run of reveals (AC-5.1, AC-5.5)" do
    it "goes spring, fall, spring, fall, and every phase is a movement phase" do
      4.times { game.current_phase.reveal! }

      expect(game.phases.map(&:title)).to eq([ "Spring 1901 · Movement", "Fall 1901 · Movement", "Spring 1902 · Movement",
                                               "Fall 1902 · Movement", "Spring 1903 · Movement" ])
      expect(game.phases.map { |p| p.position.phase }.uniq).to eq([ :movement ])
      expect(game.phases.map(&:number)).to eq([ 1, 2, 3, 4, 5 ])
      expect(game.phases.where(revealed_at: nil).count).to eq(1)
    end
  end
end

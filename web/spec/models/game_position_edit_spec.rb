require "rails_helper"
require_relative "../support/rules_helpers"

# Spec 027 Stories 5 and 6: Game#edit_position!, what it clears, what it records and what it tells the status stream.
RSpec.describe Game, "#edit_position!" do
  include RulesHelpers
  include ActiveSupport::Testing::TimeHelpers

  let(:started) { Game.start!(power: "england") }
  let(:game) { started.game }
  let(:phase) { game.current_phase }
  let!(:england) { game.seats.find_by(power: "england") }
  let!(:france) { game.take_seat!("france").first }
  let!(:germany) { game.take_seat!("germany").first }

  ADD = { "action" => "unit_added", "power" => "france", "type" => "army", "province" => "bur", "coast" => nil }.freeze
  MOVE = { "action" => "unit_moved", "from" => "par", "to" => "bur", "to_coast" => nil }.freeze
  REMOVE = { "action" => "unit_removed", "province" => "par" }.freeze
  OWNER = { "action" => "owner_set", "center" => "bel", "to" => "germany" }.freeze
  DATE = { "action" => "date_set", "to_season" => "fall", "to_year" => 1901 }.freeze

  # England and France have orders, Germany too; England and France have submitted.
  def order_everyone
    england.save_orders!(phase, { "lon" => json_of(rules_order(:hold, :england, :lon)) }, submit: true)
    france.save_orders!(phase, { "par" => json_of(rules_order(:hold, :france, :par)) }, submit: true)
    germany.save_orders!(phase, { "ber" => json_of(rules_order(:hold, :germany, :ber)) })
  end

  def counts = [ SavedOrder.where(phase_id: phase.id).count, Submission.where(phase_id: phase.id).count ]

  describe "an edit that moves units" do
    { "adds" => ADD, "moves" => MOVE, "removes" => REMOVE }.each do |name, intent|
      it "#{name} a unit and clears every seat's orders and submissions (AC-5.1)" do
        order_everyone
        expect(counts).to eq([ 3, 2 ])

        row = game.edit_position!(1, intent)

        expect(row).to be_a(PositionEdit).and be_persisted
        expect(counts).to eq([ 0, 0 ])
        expect(phase.reload.position).not_to eq(RulesEngine.starting_position)
      end
    end

    it "leaves a revealed phase's orders alone (AC-5.1)" do
      order_everyone
      phase.reveal!
      next_phase = game.current_phase
      france.save_orders!(next_phase, { "par" => json_of(rules_order(:hold, :france, :par)) })

      game.edit_position!(2, ADD)

      expect(SavedOrder.where(phase_id: phase.id).count).to eq(3)
      expect(SavedOrder.where(phase_id: next_phase.id).count).to eq(0)
    end
  end

  describe "an edit that keeps orders" do
    { "an owner edit" => OWNER, "a date edit" => DATE }.each do |name, intent|
      it "keeps every order and submission after #{name} (AC-5.2)" do
        order_everyone

        game.edit_position!(1, intent)

        expect(counts).to eq([ 3, 2 ])
      end
    end
  end

  describe "a refused edit" do
    it "clears nothing and writes no record, whether the engine or the no-change rule refused it (AC-5.3, AC-6.1)" do
      order_everyone

      expect { game.edit_position!(1, ADD.merge("type" => "fleet")) }.to raise_error(RulesEngine::EditRefused) { |e| expect(e.reason).to eq(:fleet_inland) }
      expect { game.edit_position!(1, OWNER.merge("center" => "lon", "to" => "england")) }
        .to raise_error(RulesEngine::EditRefused) { |e| expect(e.reason).to eq(:no_change) }
      expect { game.edit_position!(1, DATE.merge("to_season" => "spring")) }.to raise_error(RulesEngine::EditRefused) { |e| expect(e.reason).to eq(:no_change) }

      expect(counts).to eq([ 3, 2 ])
      expect(PositionEdit.count).to eq(0)
    end

    it "refuses a move to where the unit already is (AC-2.3)" do
      expect { game.edit_position!(1, { "action" => "unit_moved", "from" => "par", "to" => "par", "to_coast" => nil }) }
        .to raise_error(RulesEngine::EditRefused) { |e| expect(e.reason).to eq(:no_change) }
      expect(PositionEdit.count).to eq(0)
    end
  end

  describe "the record" do
    it "writes exactly one row for each successful edit, with the phase and the detail (AC-6.1)" do
      [ ADD, OWNER, DATE ].each { |intent| game.edit_position!(1, intent) }

      expect(PositionEdit.order(:id).map { |row| row.detail["action"] }).to eq(%w[unit_added owner_set date_set])
      expect(PositionEdit.pluck(:phase_id).uniq).to eq([ phase.id ])
    end

    it "rolls the whole edit back when the record can't be written (AC-5.4)" do
      order_everyone
      allow(PositionEdit).to receive(:create!).and_raise(ActiveRecord::RecordInvalid)

      expect { game.edit_position!(1, ADD) }.to raise_error(ActiveRecord::RecordInvalid)

      expect(phase.reload.position).to eq(RulesEngine.starting_position)
      expect(counts).to eq([ 3, 2 ])
    end
  end

  describe "the status stream" do
    before { allow(game).to receive(:broadcast_seat_status) }

    it "is told once when a submission was withdrawn (AC-5.5)" do
      order_everyone
      allow(game).to receive(:broadcast_seat_status)

      game.edit_position!(1, ADD)

      expect(game).to have_received(:broadcast_seat_status).once
    end

    it "is not told when nothing was withdrawn, or when the edit keeps orders (AC-5.5)" do
      game.edit_position!(1, ADD.merge("province" => "tyr"))
      order_everyone
      game.edit_position!(1, OWNER)

      expect(game).not_to have_received(:broadcast_seat_status)
    end

    it "stands when the cable raises (AC-5.5)" do
      order_everyone
      RSpec::Mocks.space.proxy_for(game).reset
      allow(Turbo::StreamsChannel).to receive(:broadcast_update_to).and_raise(StandardError)

      expect { game.edit_position!(1, ADD) }.not_to raise_error
      expect(PositionEdit.count).to eq(1)
    end
  end

  describe "a phase that was revealed (AC-7.11)" do
    it "raises Phase::Revealed for the number of a revealed phase and writes nothing" do
      phase.reveal!
      before = game.current_phase.position

      expect { game.edit_position!(1, ADD) }.to raise_error(Phase::Revealed)

      expect(game.current_phase.reload.position).to eq(before)
      expect(PositionEdit.count).to eq(0)
    end
  end

  describe "the history" do
    it "lists reissues, step-ins and edits together, oldest first, with a reissue before a step-in before an edit at one instant (AC-6.2)" do
      now = Time.current.change(usec: 0)
      travel_to(now) do
        row = game.edit_position!(1, ADD)
        StepIn.record!(phase: phase, seat: france)
        game.reissue_seat!(france)
        expect(game.seat_history.map(&:kind)).to eq(%i[reissue step_in position_edit])
        expect(game.seat_history.last).to eq(row)
      end
      travel_to(now + 1.minute) { game.edit_position!(1, OWNER) }
      expect(game.seat_history.map(&:kind)).to eq(%i[reissue step_in position_edit position_edit])
    end

    it "keeps an edit made in a phase that was revealed since" do
      game.edit_position!(1, ADD)
      phase.reveal!

      expect(game.seat_history.map(&:kind)).to eq([ :position_edit ])
    end
  end

  describe "#board_cleared_at" do
    it "is the time of the latest edit that moved units, or nil" do
      expect(game.board_cleared_at(phase)).to be_nil

      first = Time.current.change(usec: 0)
      travel_to(first) { game.edit_position!(1, OWNER) }
      expect(game.board_cleared_at(phase)).to be_nil

      travel_to(first + 1.minute) { game.edit_position!(1, ADD) }
      travel_to(first + 2.minutes) { game.edit_position!(1, DATE) }
      expect(game.board_cleared_at(phase)).to eq(first + 1.minute)

      travel_to(first + 3.minutes) { game.edit_position!(1, REMOVE) }
      expect(game.board_cleared_at(phase)).to eq(first + 3.minutes)
    end
  end
end

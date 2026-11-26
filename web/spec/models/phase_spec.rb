require "rails_helper"

RSpec.describe Phase do
  let(:started) { Game.start!(power: "england") }
  let(:game) { started.game }

  # A real adjudication, to make a phase look revealed without any reveal code (the reveal itself is tested elsewhere).
  def adjudication = RulesEngine.adjudicate(RulesEngine.starting_position, [])

  def reveal_directly(phase)
    phase.update_columns(adjudication: adjudication, revealed_at: Time.current)
  end

  describe "a new game (AC-1.1)" do
    it "has exactly one open phase with the starting position" do
      expect(game.phases.count).to eq(1)
      phase = game.current_phase
      expect(phase.number).to eq(1)
      expect(phase.position).to eq(RulesEngine.starting_position)
      expect(phase).to be_open
      expect(phase.title).to eq("Spring 1901 · Movement")
    end
  end

  describe "what the database refuses (AC-1.3)" do
    it "refuses a second open phase for a game" do
      expect { game.phases.create!(number: 2, position: RulesEngine.starting_position) }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "refuses a repeated number" do
      reveal_directly(game.current_phase)
      expect { game.phases.create!(number: 1, position: RulesEngine.starting_position) }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "refuses a revealed time without an adjudication" do
      expect { game.current_phase.update_columns(revealed_at: Time.current) }.to raise_error(ActiveRecord::CheckViolation)
    end

    it "refuses an adjudication without a revealed time" do
      phase = game.current_phase
      expect { phase.update_columns(adjudication: adjudication) }.to raise_error(ActiveRecord::CheckViolation)
    end
  end

  describe "the current phase and the history (AC-1.4)" do
    it "lists revealed phases oldest first and returns the open phase that follows" do
      first = game.current_phase
      reveal_directly(first)
      second = game.phases.create!(number: 2, position: RulesEngine.starting_position)
      reveal_directly(second)
      third = game.phases.create!(number: 3, position: RulesEngine.starting_position)

      expect(game.history.map(&:number)).to eq([ 1, 2 ])
      expect(game.current_phase).to eq(third)
    end
  end

  describe "#pending (AC-4.1, AC-4.13)" do
    it "names every power, and says which have a seat" do
      pending = game.current_phase.pending

      expect(pending.map(&:power)).to eq(RulesEngine.powers.map { |power| power.id.to_s })
      expect(pending.select(&:seated).map(&:power)).to eq([ "england" ])
    end

    it "leaves out a power whose seat has submitted" do
      france, = game.take_seat!("france")
      phase = game.current_phase
      Submission.create!(phase: phase, seat: france)

      expect(phase.pending.map(&:power)).not_to include("france")
      expect(phase.pending.map(&:power)).to include("england")
    end
  end

  describe "#seat_statuses (spec 024 FR-1)" do
    let(:phase) { game.current_phase }

    it "gives seven statuses in the gem's power order, none submitted at the start" do
      statuses = phase.seat_statuses

      expect(statuses.map(&:power)).to eq(RulesEngine.powers.map { |power| power.id.to_s })
      expect(statuses.size).to eq(7)
      expect(statuses.map(&:submitted)).to all(be(false))
    end

    it "marks a seat that has submitted, and a power nobody holds is not submitted" do
      Submission.create!(phase: phase, seat: game.seats.find_by(power: "england"))

      by_power = phase.seat_statuses.to_h { |status| [ status.power, status.submitted ] }
      expect(by_power["england"]).to be(true)
      expect(by_power.except("england").values).to all(be(false))
    end

    it "reads seats and submissions only, never an order" do
      source = File.read(Rails.root.join("app/models/phase.rb"))[/def seat_statuses.*?\n  end\n/m]

      expect(source).to be_present
      expect(source).not_to match(/saved_orders?|SavedOrder|orders_for/i)
    end
  end
end

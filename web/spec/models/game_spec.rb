require "rails_helper"

RSpec.describe Game do
  include ActiveSupport::Testing::TimeHelpers

  describe ".start!" do
    it "makes one game and one seat for the host's power" do
      expect { Game.start!(power: "france") }.to change(Game, :count).by(1).and change(Seat, :count).by(1)
      expect(Seat.last.power).to eq("france")
    end

    it "stores digests and never a token (AC-2.4, AC-4.4)" do
      started = Game.start!(power: "england")
      stored = [ Game, Seat ].flat_map { |model| model.pluck(*model.column_names) }.flatten.map(&:to_s)

      expect(stored).not_to include(started.host_token, started.seat_token)
      expect(started.game.host_token_digest).to eq(Token.digest(started.host_token))
      expect(started.game.seats.first.token_digest).to eq(Token.digest(started.seat_token))
    end

    it "gives the game a 12-character public id and a code of the right shape" do
      game = Game.start!(power: "england").game
      expect(game.public_id).to match(/\A[A-Za-z0-9]{12}\z/)
      expect(game.join_code).to match(JoinCode::SHAPE)
      expect(game).to be_open
    end

    it "tries another code when an open game already holds it (AC-3.6)" do
      allow(JoinCode).to receive(:generate).and_return("ACDEFG", "ACDEFG", "HJKMNP")
      first = Game.start!(power: "england").game
      second = Game.start!(power: "france").game

      expect([ first.join_code, second.join_code ]).to eq(%w[ACDEFG HJKMNP])
    end

    it "lets a new game take the code of a closed game (AC-3.7)" do
      allow(JoinCode).to receive(:generate).and_return("ACDEFG")
      first = Game.start!(power: "england").game
      first.close_joining!

      expect(Game.start!(power: "france").game.join_code).to eq("ACDEFG")
    end

    it "gives up after five clashes and leaves no game behind" do
      allow(JoinCode).to receive(:generate).and_return("ACDEFG")
      Game.start!(power: "england")

      expect { Game.start!(power: "france") }.to raise_error(ActiveRecord::RecordNotUnique)
      expect([ Game.count, Seat.count ]).to eq([ 1, 1 ])
      expect(JoinCode).to have_received(:generate).exactly(1 + Game::CODE_TRIES).times
    end
  end

  it "has an index that refuses two open games with one code" do
    first = Game.start!(power: "england").game

    expect { Game.create!(public_id: "zzzzzzzzzzzz", host_token_digest: "d", join_code: first.join_code) }
      .to raise_error(ActiveRecord::RecordNotUnique)
  end

  describe ".open_by_code" do
    let!(:game) { Game.start!(power: "england").game }

    it "finds the open game by a forgivingly typed code" do
      typed = " #{game.join_code[0, 3].downcase}-#{game.join_code[3, 3]} "
      expect(Game.open_by_code(typed)).to eq(game)
    end

    it "gives nil for an unknown, closed or malformed code" do
      unknown = (%w[ACDEFG HJKMNP] - [ game.join_code ]).first
      expect(Game.open_by_code(unknown)).to be_nil
      expect(Game.open_by_code("nope")).to be_nil
      expect(Game.open_by_code(nil)).to be_nil

      game.close_joining!
      expect(Game.open_by_code(game.join_code)).to be_nil
    end
  end

  describe "#take_seat!" do
    let!(:game) { Game.start!(power: "england").game }

    it "creates a seat and returns a token that seat_for finds" do
      seat, token = game.take_seat!("france")

      expect(seat.power).to eq("france")
      expect(game.seat_for(token)).to eq(seat)
      expect(game.seat_for(Token.generate)).to be_nil
    end

    it "raises SeatTaken for a power already held" do
      expect { game.take_seat!("england") }.to raise_error(Game::SeatTaken)
    end

    it "raises SeatTaken when the check was bypassed and the insert ran second (AC-4.6)" do
      game.take_seat!("france")
      expect { game.seats.create!(power: "france", token_digest: Token.digest("other")) }.to raise_error(ActiveRecord::RecordNotUnique)
      expect { game.take_seat!("france") }.to raise_error(Game::SeatTaken)
    end

    it "raises NotOpen after joining closed" do
      game.close_joining!
      expect { game.take_seat!("france") }.to raise_error(Game::NotOpen)
      expect(game.seats.count).to eq(1)
    end

    it "checks the database, not the loaded record, for whether joining is open" do
      stale = Game.find(game.id)
      game.close_joining!
      expect { stale.take_seat!("france") }.to raise_error(Game::NotOpen)
    end
  end

  describe "#reissue_seat!" do
    it "makes the old token fail and the new one pass" do
      started = Game.start!(power: "england")
      game = started.game
      seat = game.seat_for(started.seat_token)

      new_token = game.reissue_seat!(seat)

      expect(game.reload.seat_for(started.seat_token)).to be_nil
      expect(game.seat_for(new_token)).to eq(seat)
    end
  end

  describe "#close_joining!" do
    it "keeps the first time when called twice" do
      game = Game.start!(power: "england").game
      game.close_joining!
      first = game.joining_closed_at

      travel(1.hour) { game.close_joining! }

      expect(game.reload.joining_closed_at).to eq(first)
      expect(game).not_to be_open
    end
  end

  describe "#host_token?" do
    it "matches only the host token" do
      started = Game.start!(power: "england")
      expect(started.game.host_token?(started.host_token)).to be(true)
      expect(started.game.host_token?(started.seat_token)).to be(false)
      expect(started.game.host_token?(nil)).to be(false)
    end
  end

  describe "the host's seat and the step-in history (spec 026)" do
    it "names the seat made with the game as the host's own, whoever joins later (D5)" do
      game = described_class.start!(power: "germany").game
      game.take_seat!("england")
      game.take_seat!("france")

      expect(game.host_seat.power).to eq("germany")
    end

    it "lists this game's step-ins oldest first and no other game's (D1)" do
      game = described_class.start!(power: "germany").game
      other = described_class.start!(power: "germany").game
      first = StepIn.record!(phase: game.current_phase, seat: game.take_seat!("england").first)
      StepIn.record!(phase: other.current_phase, seat: other.take_seat!("england").first)
      second = StepIn.record!(phase: game.current_phase, seat: game.seats.find_by(power: "england"))

      expect(game.step_in_history.to_a).to eq([ first, second ])
    end
  end
end

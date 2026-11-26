require "rails_helper"

# Spec 026 D1, D2: the record is append-only, and it is active only while the phase is open and for 30 minutes.
RSpec.describe StepIn do
  include ActiveSupport::Testing::TimeHelpers

  let(:game) { Game.start!(power: "germany").game }
  let(:france) { game.take_seat!("france").first }
  let(:phase) { game.current_phase }

  it "writes one row with the phase and the seat" do
    row = described_class.record!(phase: phase, seat: france)

    expect(row).to be_persisted
    expect([ row.phase, row.seat ]).to eq([ phase, france ])
    expect(row.created_at).to be_within(5.seconds).of(Time.current)
  end

  it "refuses a seat of another game" do
    other = Game.start!(power: "england").game.seats.first

    expect { described_class.record!(phase: phase, seat: other) }.to raise_error(ActiveRecord::RecordInvalid)
  end

  it "can't be changed or deleted (AC-2.7)" do
    row = described_class.record!(phase: phase, seat: france)

    expect { row.update!(seat: game.seats.first) }.to raise_error(ActiveRecord::ReadOnlyRecord)
    expect { row.destroy }.to raise_error(ActiveRecord::ReadOnlyRecord)
    expect(described_class.count).to eq(1)
  end

  it "has no column that could hold an order or a count" do
    expect(described_class.column_names).to match_array(%w[id phase_id seat_id created_at])
  end

  describe "#active?" do
    let!(:row) { described_class.record!(phase: phase, seat: france) }

    it "is active at 29 minutes and not at 31 (AC-5.2)" do
      travel(29.minutes) { expect(row.active?).to be(true) }
      travel(31.minutes) { expect(row.active?).to be(false) }
    end

    it "ends when the phase is revealed (AC-5.1)" do
      phase.reveal!

      expect(row.active?).to be(false)
    end
  end
end

require "rails_helper"
require_relative "../support/rules_helpers"

# Spec 022 D8, AC-4.9, AC-6.4: two requests at once, on two real database connections.
#
# The examples switch the fixture transaction off (with it on, both threads would share one connection and never wait),
# so they clean up after themselves. The interleaving is forced, not hoped for: the reveal is held inside
# RulesEngine.adjudicate, the second request starts while it is held, and only then is the first let go.
RSpec.describe Phase, "under concurrent requests" do
  include RulesHelpers

  self.use_transactional_tests = false

  after { [ Submission, SavedOrder, Phase, Seat, Game ].each(&:delete_all) }

  # Runs the block on its own thread and its own connection. The thread's value is the block's value, or the error it raised.
  def in_thread
    Thread.new do
      ActiveRecord::Base.connection_pool.with_connection { yield }
    rescue StandardError => error
      error
    end
  end

  # Holds the first call of RulesEngine.adjudicate until gate gets a value. Reports when it was reached on `entered`.
  def hold_adjudication(entered:, gate:, calls:)
    allow(RulesEngine).to receive(:adjudicate).and_wrap_original do |original, *args|
      calls << 1
      entered << true
      gate.pop(timeout: 10)
      original.call(*args)
    end
  end

  let(:game) { Game.start!(power: "england").game }
  let(:england) { game.seats.find_by(power: "england") }
  let(:phase_id) { game.current_phase.id }

  it "starts every write transaction by taking the database's write lock (D8)" do
    held = Queue.new
    release = Queue.new
    holder = in_thread do
      Game.transaction do
        Game.connection.select_value("SELECT 1") # Rails opens a transaction lazily, so the first statement is what takes the lock
        held << true
        release.pop(timeout: 10)
      end
    end
    held.pop(timeout: 10)

    outcome = in_thread do
      Game.connection.raw_connection.busy_handler_timeout = 200 # not busy_timeout=, which would hold Ruby's global lock while it waits
      begin
        Game.transaction { Game.connection.select_value("SELECT 1") }
      rescue StandardError => error
        error
      ensure
        # Rails may have replaced the connection after the failure, so the current one is put back, not the one captured earlier.
        current = Game.connection.raw_connection
        current.busy_handler_timeout = 5000 unless current.closed?
      end
    end.value

    expect(outcome).to be_a(StandardError)
    expect(outcome.message).to match(/locked|busy/i)
  ensure
    release << true
    holder.join
  end

  it "adjudicates once when two reveals of the same phase arrive together (AC-4.9)" do
    entered = Queue.new
    gate = Queue.new
    calls = []
    hold_adjudication(entered: entered, gate: gate, calls: calls)
    id = phase_id

    first = in_thread { Phase.find(id).reveal! }
    expect(entered.pop(timeout: 10)).to be(true) # the first reveal is inside the adjudication, holding the lock
    second = in_thread { Phase.find(id).reveal! }
    sleep 0.3
    expect(second).to be_alive # it is waiting for the lock, not running

    gate << true
    results = [ first.value, second.value ]

    expect(results).to eq([ Phase::Reveal.new(status: :revealed), Phase::Reveal.new(status: :already) ])
    expect(calls.size).to eq(1)
    expect(Phase.where(game_id: game.id).order(:number).pluck(:number, :revealed_at).map { |number, at| [ number, at.nil? ] })
      .to eq([ [ 1, false ], [ 2, true ] ])
  ensure
    gate << true
  end

  it "refuses a save that was waiting for the lock when the reveal committed, and stores nothing (AC-6.4)" do
    entered = Queue.new
    gate = Queue.new
    calls = []
    hold_adjudication(entered: entered, gate: gate, calls: calls)
    id = phase_id
    seat = england

    reveal = in_thread { Phase.find(id).reveal! }
    expect(entered.pop(timeout: 10)).to be(true)
    save = in_thread { seat.save_orders!(Phase.find(id), { "lon" => json_of(rules_order(:hold, :england, :lon)) }, submit: true) }
    sleep 0.3
    expect(save).to be_alive

    gate << true

    expect(reveal.value).to eq(Phase::Reveal.new(status: :revealed))
    expect(save.value).to be_a(Phase::Revealed)
    expect(SavedOrder.count).to eq(0)
    expect(Submission.count).to eq(0)
  ensure
    gate << true
  end

  it "includes a save that finished before the reveal: the stored orders equal the orders adjudicated (AC-6.4)" do
    order = move(:england, :lon, :nth)
    saved = in_thread { england.save_orders!(Phase.find(phase_id), { "lon" => json_of(order) }) }.value
    expect(saved).to eq(Seat::Saved.new(changed: true, submitted: false))

    in_thread { Phase.find(phase_id).reveal! }.value

    adjudicated = Phase.find(phase_id).adjudication.outcomes.select(&:submitted).map(&:order)
    expect(adjudicated).to eq(SavedOrder.all.map(&:content))
    expect(adjudicated).to eq([ order ])
  end
end

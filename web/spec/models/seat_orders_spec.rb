require "rails_helper"
require_relative "../support/rules_helpers"

# Spec 022 FR-2, FR-3, FR-5, D4: the rules for saving orders and submitting, with no HTTP.
# England starts with a fleet in LON, a fleet in EDI and an army in LVP.
RSpec.describe Seat, "saving orders" do
  include RulesHelpers

  let(:game) { Game.start!(power: "england").game }
  let(:seat) { game.seats.find_by(power: "england") }
  let(:phase) { game.current_phase }
  let(:hold_lon) { rules_order(:hold, :england, :lon) }
  let(:nth_from_lon) { move(:england, :lon, :nth) }
  let(:yor_from_lvp) { move(:england, :lvp, :yor) }

  def save(entries, submit: false) = seat.save_orders!(phase, entries, submit: submit)

  def refusal_of(entries)
    save(entries)
    raise "no refusal"
  rescue Seat::Refusal => error
    error.message
  end

  describe "saving (AC-2.1, AC-2.10)" do
    it "stores one order per unit with the seat and the phase, and says it changed" do
      result = save({ "lon" => json_of(nth_from_lon), "lvp" => json_of(yor_from_lvp) })

      expect(result).to eq(Seat::Saved.new(changed: true, submitted: false))
      expect(seat.orders_for(phase)).to eq({ "lon" => nth_from_lon, "lvp" => yor_from_lvp })
      expect(SavedOrder.where(seat_id: seat.id, phase_id: phase.id).pluck(:province)).to match_array(%w[lon lvp])
    end
  end

  describe "what is refused, in the order the rules check it (FR-2)" do
    it "refuses a key that is not a province, without echoing it (AC-2.5)" do
      expect(refusal_of({ "xyz" => json_of(hold_lon) })).to eq("That order couldn't be read.")
      expect(refusal_of({ "../x" => json_of(hold_lon) })).to eq("That order couldn't be read.")
    end

    it "refuses a province where the seat has no unit, whether empty or held by another power (AC-2.2)" do
      expect(refusal_of({ "par" => json_of(rules_order(:hold, :france, :par)) })).to eq("You have no unit in PAR.")
      expect(refusal_of({ "bel" => json_of(rules_order(:hold, :england, :bel)) })).to eq("You have no unit in BEL.")
    end

    it "checks the unit before it reads the order" do
      expect(refusal_of({ "par" => "not json at all" })).to eq("You have no unit in PAR.")
    end

    it "refuses text that is not an order (AC-2.5)" do
      [ "not json", "[]", "7", "null", "{}", '{"format":1,"type":"hold","power":"england"}',
        '{"format":2,"type":"hold","power":"england","at":"lon"}' ].each do |text|
        expect(refusal_of({ "lon" => text })).to eq("That order couldn't be read."), text
      end
    end

    it "refuses an order posted under one province that names another (AC-2.6)" do
      expect(refusal_of({ "lon" => json_of(rules_order(:hold, :england, :edi)) })).to eq("That order couldn't be read.")
    end

    it "refuses an order in another power's name, even for England's own unit (AC-2.3)" do
      expect(refusal_of({ "lon" => json_of(rules_order(:hold, :france, :lon)) })).to eq("That order isn't for your power.")
    end

    it "refuses an illegal order with the reason in words, naming the unit (AC-2.4)" do
      expect(refusal_of({ "lon" => json_of(move(:england, :lon, :bel)) })).to eq("The fleet in LON can't reach there.")
      expect(refusal_of({ "lvp" => json_of(move(:england, :lvp, :lvp)) })).to eq("The army in LVP can't be ordered to its own province.")
    end

    it "stores nothing when any one entry is refused (all or nothing)" do
      expect { save({ "lon" => json_of(nth_from_lon), "lvp" => json_of(move(:england, :lvp, :par)) }) }.to raise_error(Seat::Refusal)

      expect(SavedOrder.count).to eq(0)
    end
  end

  describe "the sentences (FR-5)" do
    it "has one for every reason the gem reports, each reading as a sentence about the unit" do
      reasons = %i[wrong_phase no_such_unit foreign_unit own_province not_reachable coast_not_allowed coast_required
                   coast_unreachable not_army not_adjacent no_convoy_route same_province no_unit move_impossible
                   not_fleet_at_sea bad_endpoints not_on_chain]
      expect(Seat::REASONS.keys).to match_array(reasons)

      reasons.each do |reason|
        sentence = format(Seat::REASONS.fetch(reason), unit: "the army in LON", Unit: "The army in LON")
        expect(sentence).to match(/\A[A-Z].*\.\z/), "#{reason}: #{sentence}"
        expect(sentence).not_to include("%{"), reason.to_s
        expect(sentence).to include("army in LON") unless reason == :wrong_phase
      end
    end

    it "falls back to a plain sentence for a reason it does not know" do
      allow(RulesEngine).to receive(:check).and_return(Struct.new(:legal, :reasons).new(false, [ :something_new ]))

      expect(refusal_of({ "lon" => json_of(hold_lon) })).to eq("That order isn't legal.")
    end
  end

  describe "changing orders (AC-2.7 to AC-2.9)" do
    before { save({ "lon" => json_of(nth_from_lon), "lvp" => json_of(yor_from_lvp) }) }

    it "clears an order with a blank value, and says it changed" do
      expect(save({ "lon" => "" }).changed).to be(true)

      expect(seat.orders_for(phase).keys).to eq([ "lvp" ])
    end

    it "says nothing changed when a blank clears nothing" do
      expect(save({ "edi" => "" }).changed).to be(false)
    end

    it "replaces an order, so the unit still has exactly one" do
      eng = move(:england, :lon, :eng)
      save({ "lon" => json_of(eng) })

      expect(seat.orders_for(phase)["lon"]).to eq(eng)
      expect(SavedOrder.where(seat_id: seat.id, province: "lon").count).to eq(1)
    end

    it "leaves the units that were not named alone (a partial update)" do
      save({ "lon" => json_of(hold_lon) })

      expect(seat.orders_for(phase)["lvp"]).to eq(yor_from_lvp)
    end

    it "says nothing changed when the same order is saved again" do
      expect(save({ "lon" => json_of(nth_from_lon) }).changed).to be(false)
    end
  end

  describe "submitting (AC-3.1 to AC-3.5)" do
    it "records a submission, with orders or with none" do
      expect(save({}, submit: true)).to eq(Seat::Saved.new(changed: false, submitted: true))
      expect(seat.submitted?(phase)).to be(true)
    end

    it "saves the orders first, then records the submission" do
      save({ "lon" => json_of(hold_lon) }, submit: true)

      expect(seat.orders_for(phase).keys).to eq([ "lon" ])
      expect(seat.submitted?(phase)).to be(true)
    end

    it "puts a submitted seat back to not submitted when an order changes or is cleared (AC-3.2)" do
      save({ "lon" => json_of(hold_lon) }, submit: true)

      expect(save({ "lon" => json_of(nth_from_lon) }).submitted).to be(false)
      save({}, submit: true)
      expect(save({ "lon" => "" }).submitted).to be(false)
      expect(seat.submitted?(phase)).to be(false)
    end

    it "keeps the submission when nothing changes (AC-3.3)" do
      save({ "lon" => json_of(hold_lon) }, submit: true)

      expect(save({ "lon" => json_of(hold_lon) })).to eq(Seat::Saved.new(changed: false, submitted: true))
    end

    it "records one submission however often it is sent (AC-3.4)" do
      2.times { save({}, submit: true) }

      expect(Submission.where(seat_id: seat.id).count).to eq(1)
    end

    it "records nothing when an order in the same request is refused (AC-3.5)" do
      expect { save({ "lon" => json_of(move(:england, :lon, :bel)) }, submit: true) }.to raise_error(Seat::Refusal)

      expect(seat.submitted?(phase)).to be(false)
      expect(SavedOrder.count).to eq(0)
    end

    it "never locks: a submitted seat can keep editing (AC-3.6)" do
      save({}, submit: true)

      expect { save({ "lon" => json_of(hold_lon) }) }.not_to raise_error
    end
  end

  describe "when the phase is no longer open (FR-6)" do
    it "refuses, and stores nothing" do
      phase.update_columns(adjudication: RulesEngine.adjudicate(RulesEngine.starting_position, []), revealed_at: Time.current)

      expect { save({ "lon" => json_of(hold_lon) }, submit: true) }.to raise_error(Phase::Revealed)

      expect(SavedOrder.count).to eq(0)
      expect(Submission.count).to eq(0)
    end
  end

  describe "when the seat was reissued while the save was running (FR-2, D9)" do
    it "refuses with Stale and stores nothing" do
      stale = Seat.find(seat.id)
      Seat.find(seat.id).update!(token_digest: Token.digest(Token.generate))

      expect { stale.save_orders!(phase, { "lon" => json_of(hold_lon) }) }.to raise_error(Seat::Stale)
      expect(SavedOrder.count).to eq(0)
    end
  end

  describe "#clear_orders!" do
    it "deletes the seat's orders and its submission for the phase, and no one else's" do
      other, = game.take_seat!("france")
      save({ "lon" => json_of(hold_lon) }, submit: true)
      other.save_orders!(phase, { "par" => json_of(rules_order(:hold, :france, :par)) }, submit: true)

      seat.clear_orders!(phase)

      expect(seat.orders_for(phase)).to be_empty
      expect(seat.submitted?(phase)).to be(false)
      expect(other.orders_for(phase).keys).to eq([ "par" ])
      expect(other.submitted?(phase)).to be(true)
    end
  end
end

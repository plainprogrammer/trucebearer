require "rails_helper"

# Spec 024 D1, D3, D7: when the status stream is told, what it is told, and what a failure does.
RSpec.describe "Seat status broadcast" do
  let(:game) { Game.start!(power: "england").game }
  let(:seat) { game.seats.find_by(power: "england") }
  let(:phase) { game.current_phase }
  let(:stream) { "seat_status:#{game.public_id}" }

  # What Action Cable's test adapter kept for a stream, JSON-decoded (it stores the string JSON-encoded).
  def payloads = ActionCable.server.pubsub.broadcasts(stream).map { |raw| JSON.parse(raw) }

  def state_of(payload, power) = Nokogiri::HTML5.fragment(payload).at_css("[data-power='#{power}'] .seat-status__state").text

  def hold_lon = { "lon" => JSON.generate({ "format" => 1, "type" => "hold", "power" => "england", "at" => "lon" }) }

  it "sends one broadcast to the game's status stream when England submits, and England's row says Submitted" do
    seat.save_orders!(phase, {}, submit: true)

    expect(payloads.size).to eq(1)
    row = Nokogiri::HTML5.fragment(payloads.first).at_css("[data-power='england']")
    expect(row[:class]).to include("seat-status__row")
    expect(row.at_css(".seat-status__state").text).to eq("Submitted")
  end

  it "sends nothing for a save that does not submit (AC-3.3)" do
    seat.save_orders!(phase, hold_lon)

    expect(payloads).to be_empty
  end

  it "sends one broadcast when a submitted seat changes an order, and England's row then says Not submitted (AC-2.3)" do
    seat.save_orders!(phase, {}, submit: true)
    seat.save_orders!(phase, hold_lon)

    expect(payloads.size).to eq(2)
    expect(state_of(payloads.last, "england")).to eq("Not submitted")
  end

  it "sends nothing when an edit and a re-submit end where they began (D3, AC-3.3)" do
    seat.save_orders!(phase, {}, submit: true)
    seat.save_orders!(phase, hold_lon, submit: true)

    expect(payloads.size).to eq(1)
  end

  it "sends nothing when the save is refused, stale or on a revealed phase (AC-2.6)" do
    expect { seat.save_orders!(phase, { "par" => "{}" }, submit: true) }.to raise_error(Seat::Refusal)
    stale = Seat.find(seat.id) # a second copy of the seat, loaded before the host reissues it
    game.reissue_seat!(seat) # a seat that had not submitted: no message, and the copy's digest is now stale
    expect { stale.save_orders!(phase, {}, submit: true) }.to raise_error(Seat::Stale)
    expect(payloads).to be_empty

    revealed = game.current_phase
    revealed.reveal!
    ActionCable.server.pubsub.clear_messages(stream) # the reveal's own message is not under test here
    expect { game.seats.find_by(power: "england").save_orders!(revealed, {}, submit: true) }.to raise_error(Phase::Revealed)
    expect(payloads).to be_empty
  end

  it "keeps the save, and its answer, when the cable call raises, and logs only the exception's class (D7, AC-5.4)" do
    allow(Turbo::StreamsChannel).to receive(:broadcast_update_to).and_raise(IOError, "secret detail")
    allow(Rails.logger).to receive(:warn)

    expect(seat.save_orders!(phase, {}, submit: true)).to eq(Seat::Saved.new(changed: false, submitted: true))
    expect(seat.submitted?(phase)).to be(true)
    expect(Rails.logger).to have_received(:warn).with("seat status broadcast failed: IOError")
  end

  it "does not hide a template that raises (D7)" do
    allow(ApplicationController).to receive(:render).and_raise(RuntimeError, "boom")

    expect { seat.save_orders!(phase, {}, submit: true) }.to raise_error(RuntimeError, "boom")
  end

  it "sends one broadcast when the host reissues a submitted seat (AC-2.4), and none for a seat that had not submitted" do
    seat.save_orders!(phase, {}, submit: true)
    game.reissue_seat!(seat)
    expect(payloads.size).to eq(2)
    expect(state_of(payloads.last, "england")).to eq("Not submitted")

    france = game.take_seat!("france").first
    game.reissue_seat!(france)
    expect(payloads.size).to eq(2)
  end

  it "sends one broadcast at a reveal, all seven Not submitted, and none for a reveal that finds the phase done (AC-2.5)" do
    seat.save_orders!(phase, {}, submit: true)
    expect(phase.reveal!.status).to eq(:revealed)

    expect(payloads.size).to eq(2)
    states = Nokogiri::HTML5.fragment(payloads.last).css(".seat-status__state").map(&:text)
    expect(states).to eq([ "Not submitted" ] * 7)
    expect(Phase.find(phase.id).reveal!.status).to eq(:already)
    expect(payloads.size).to eq(2)
  end
end

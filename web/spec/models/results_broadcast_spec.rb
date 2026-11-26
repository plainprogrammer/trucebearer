require "rails_helper"
require_relative "../support/rules_helpers"

# Spec 025 Story 4: the one message the reveal sends carries nothing, and nothing else is ever sent on the results stream.
RSpec.describe "The results broadcast" do
  include RulesHelpers

  let(:game) { Game.start!(power: "england").game }
  let(:england) { game.seats.find_by(power: "england") }

  def raw(game) = ActionCable.server.pubsub.broadcasts("results:#{game.public_id}")

  it "sends nothing for saves, submits, edits and a reissue (AC-4.1)" do
    phase = game.current_phase
    england.save_orders!(phase, { "lon" => json_of(move(:england, :lon, :nth)) }, submit: true)
    england.save_orders!(phase, { "lon" => json_of(move(:england, :lon, :eng)) })
    game.reissue_seat!(england)

    expect(raw(game)).to be_empty
  end

  it "sends exactly one message when the reveal reveals, and none for a repeat or a refused reveal (AC-4.1)" do
    phase = game.current_phase
    phase.reveal!
    expect(raw(game).size).to eq(1)

    phase.reveal! # already revealed
    expect(raw(game).size).to eq(1)

    other = Game.start!(power: "england").game
    allow(RulesEngine).to receive(:adjudicate).and_raise(RulesEngine::InvalidInput, "refused")
    expect { other.current_phase.reveal! }.to raise_error(RulesEngine::InvalidInput)
    expect(raw(other)).to be_empty
  end

  it "is one element with one attribute, no child and no text, and equal for a game with orders and one without (AC-4.2)" do
    quiet = Game.start!(power: "england").game
    busy = game
    busy.seats.find_by(power: "england").save_orders!(busy.current_phase, { "lon" => json_of(move(:england, :lon, :nth)), "edi" => json_of(move(:england, :edi, :nwg)) }, submit: true)
    busy.take_seat!("france").first.save_orders!(busy.current_phase, { "par" => json_of(move(:france, :par, :bur)) }, submit: true)
    busy.take_seat!("germany").first.save_orders!(busy.current_phase, { "kie" => json_of(move(:germany, :kie, :hol)) })
    [ quiet, busy ].each { |g| g.current_phase.reveal! }

    decoded = [ quiet, busy ].map { |g| JSON.parse(raw(g).first) } # the adapter keeps the raw string, JSON-encoded
    fragment = Nokogiri::HTML5.fragment(decoded.first)
    element = fragment.children.first

    expect(decoded.uniq.size).to eq(1)
    expect(fragment.children.size).to eq(1)
    expect(element.name).to eq("turbo-stream")
    expect(element.attributes.keys).to eq([ "action" ])
    expect(element["action"]).to eq("refresh")
    expect(element.children.to_a).to be_empty
    expect(decoded.first).not_to match(/england|lon|nth|\d/i)
  end

  it "keeps the reveal when the cable raises, and logs only the class (AC-4.5)" do
    allow(Turbo::StreamsChannel).to receive(:broadcast_stream_to).and_raise(RuntimeError, "secret detail")
    allow(Rails.logger).to receive(:warn)

    game.current_phase.reveal!

    expect(game.phases.count).to eq(2)
    expect(game.history.count).to eq(1)
    expect(Rails.logger).to have_received(:warn).with("results broadcast failed: RuntimeError")
    expect(Rails.logger).not_to have_received(:warn).with(/secret detail/)
  end

  it "is on a stream of its own: not the status stream, and never another game's (AC-4.4)" do
    other = Game.start!(power: "england").game
    game.current_phase.reveal!

    expect(raw(other)).to be_empty
    expect(ActionCable.server.pubsub.broadcasts("seat_status:#{game.public_id}").map { |message| JSON.parse(message) }).to all(include("seat-status"))
    expect(ActionCable.server.pubsub.broadcasts("seat_status:#{game.public_id}").map { |message| JSON.parse(message) }).to all(satisfy { |m| !m.include?("refresh") })
    expect(raw(game).map { |message| JSON.parse(message) }).to all(satisfy { |m| !m.include?("seat-status") })
  end
end

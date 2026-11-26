require "rails_helper"

# Spec 024 D4, D10: the signed name is the capability. SeatStatusChannel verifies it (through Turbo's own parent), accepts only the
# game's status stream, and sends the current snapshot as the subscriber arrives (AC-4.3, AC-9.1, AC-9.2).
RSpec.describe SeatStatusChannel, type: :channel do
  let(:game) { Game.start!(power: "england").game }
  let(:other) { Game.start!(power: "france").game }

  def signed(*streamables) = Turbo::StreamsChannel.signed_stream_name(streamables)

  def rows(message) = Nokogiri::HTML5.fragment(message).css("li.seat-status__row").to_h { |li| [ li["data-power"], li.at_css(".seat-status__state").text ] }

  before { stub_connection }

  it "transmits one snapshot on subscribing, and England's row reads Submitted when England has submitted (AC-9.1)" do
    game.seats.find_by(power: "england").save_orders!(game.current_phase, {}, submit: true)
    subscribe(signed_stream_name: signed(:seat_status, game.public_id))

    expect(subscription).to be_confirmed
    expect(subscription).to have_stream_from("seat_status:#{game.public_id}")
    expect(transmissions.size).to eq(1)
    expect(rows(transmissions.first).size).to eq(7)
    expect(rows(transmissions.first)).to include("england" => "Submitted", "france" => "Not submitted")
  end

  it "transmits one more when a client resubscribes, and all seven read Not submitted when nobody has submitted (AC-9.1)" do
    subscribe(signed_stream_name: signed(:seat_status, game.public_id))
    subscribe(signed_stream_name: signed(:seat_status, game.public_id))

    expect(transmissions.size).to eq(2)
    expect(rows(transmissions.last).values.uniq).to eq([ "Not submitted" ])
  end

  it "confirms a subscription with the game's signed status name and streams from the status stream (AC-4.3)" do
    subscribe(signed_stream_name: signed(:seat_status, game.public_id))

    expect(subscription).to be_confirmed
    expect(subscription).to have_stream_from("seat_status:#{game.public_id}")
  end

  it "rejects an unsigned name, a name signed with another key, and no name (AC-4.3)" do
    subscribe(signed_stream_name: "seat_status:#{game.public_id}")
    expect(subscription).to be_rejected

    forged = ActiveSupport::MessageVerifier.new("another key", serializer: JSON).generate("seat_status:#{game.public_id}")
    subscribe(signed_stream_name: forged)
    expect(subscription).to be_rejected

    subscribe
    expect(subscription).to be_rejected
    expect(transmissions).to be_empty
  end

  {
    "the game's general stream" => ->(game) { [ game ] },
    "the results stream" => ->(game) { [ :results, game.public_id, 1 ] },
    "a game that does not exist" => ->(_game) { [ :seat_status, "AAAAAAAAAAAA" ] },
    "an id with a suffix" => ->(game) { [ :seat_status, "#{game.public_id}:x" ] },
    "a short id" => ->(game) { [ :seat_status, game.public_id[0, 11] ] }
  }.each do |label, streamables|
    it "rejects a verified name for #{label}, and transmits nothing (AC-9.2)" do
      subscribe(signed_stream_name: signed(*streamables.call(game)))

      expect(subscription).to be_rejected
      expect(transmissions).to be_empty
    end
  end

  it "rejects a verified name with a trailing newline, and values that are not strings (AC-9.2)" do
    [ "seat_status:#{game.public_id}\n", [ "seat_status:#{game.public_id}" ], { "a" => 1 }, 42 ].each do |value|
      subscribe(signed_stream_name: Turbo.signed_stream_verifier.generate(value))

      expect(subscription).to be_rejected, value.inspect
    end
    expect(transmissions).to be_empty
  end

  it "hears nothing of another game's status, or of a broadcast to the game itself (AC-4.4)" do
    subscribe(signed_stream_name: signed(:seat_status, game.public_id))
    other.broadcast_seat_status
    Turbo::StreamsChannel.broadcast_update_to(game, target: "x", content: "y")

    expect(ActionCable.server.pubsub.broadcasts("seat_status:#{game.public_id}")).to be_empty
    expect(subscription.streams).to eq([ "seat_status:#{game.public_id}" ])
  end
end

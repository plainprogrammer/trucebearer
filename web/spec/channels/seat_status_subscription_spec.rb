require "rails_helper"

# Spec 024 D4: the signed name is the capability. Turbo's own channel verifies it; nothing here adds a rule of ours.
RSpec.describe Turbo::StreamsChannel, type: :channel do
  let(:game) { Game.start!(power: "england").game }
  let(:other) { Game.start!(power: "france").game }

  def signed(*streamables) = Turbo::StreamsChannel.signed_stream_name(streamables)

  before { stub_connection }

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
  end

  it "hears nothing of another game's status, or of a broadcast to the game itself (AC-4.4)" do
    subscribe(signed_stream_name: signed(:seat_status, game.public_id))
    other.broadcast_seat_status
    Turbo::StreamsChannel.broadcast_update_to(game, target: "x", content: "y")

    expect(ActionCable.server.pubsub.broadcasts("seat_status:#{game.public_id}")).to be_empty
    expect(subscription.streams).to eq([ "seat_status:#{game.public_id}" ])
  end
end

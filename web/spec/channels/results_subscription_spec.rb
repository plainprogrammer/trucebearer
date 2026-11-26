require "rails_helper"

# Spec 024 D10, AC-9.2, AC-9.4: the results name carries the phase the page was drawn for. ResultsChannel streams the game's results
# stream, and sends the reveal's own refresh to a subscriber whose phase has been revealed since.
RSpec.describe ResultsChannel, type: :channel do
  let(:game) { Game.start!(power: "england").game }

  def signed(*streamables) = Turbo::StreamsChannel.signed_stream_name(streamables)

  before { stub_connection }

  it "streams from the game's results stream and transmits nothing for an open phase (AC-9.4)" do
    subscribe(signed_stream_name: signed(:results, game.public_id, 1))

    expect(subscription).to be_confirmed
    expect(subscription).to have_stream_from("results:#{game.public_id}")
    expect(transmissions).to be_empty
  end

  it "transmits the reveal's own refresh to a page drawn for a phase that has been revealed since, and nothing for the open phase (AC-9.4)" do
    game.current_phase.reveal!
    broadcast = JSON.parse(ActionCable.server.pubsub.broadcasts("results:#{game.public_id}").last)
    subscribe(signed_stream_name: signed(:results, game.public_id, 1))

    expect(transmissions.map(&:to_str)).to eq([ broadcast ])
    expect(broadcast).to eq(%(<turbo-stream action="refresh"></turbo-stream>))
    expect(subscription).to have_stream_from("results:#{game.public_id}")

    subscribe(signed_stream_name: signed(:results, game.public_id, 2)) # the open phase: nothing more
    expect(transmissions.size).to eq(1)
  end

  it "is the same message a reveal broadcasts: one element with the one attribute action (AC-9.4, spec 025 AC-4.2)" do
    expect(game.results_refresh_message).to eq(%(<turbo-stream action="refresh"></turbo-stream>))
    expect(Nokogiri::HTML5.fragment(game.results_refresh_message).children.first.attributes.keys).to eq([ "action" ])
  end

  {
    "the status name" => ->(g) { [ :seat_status, g.public_id ] },
    "the game's general stream" => ->(g) { [ g ] },
    "no phase number" => ->(g) { [ :results, g.public_id ] },
    "a leading zero" => ->(g) { [ :results, g.public_id, "01" ] },
    "zero" => ->(g) { [ :results, g.public_id, 0 ] },
    "a suffix on the number" => ->(g) { [ :results, g.public_id, "1x" ] },
    "two numbers" => ->(g) { [ :results, g.public_id, 1, 2 ] },
    "a phase that does not exist" => ->(g) { [ :results, g.public_id, 9 ] },
    "a number beyond the integer range" => ->(g) { [ :results, g.public_id, "99999999999999999999" ] },
    "a game that does not exist" => ->(_g) { [ :results, "AAAAAAAAAAAA", 1 ] },
    "an id with a suffix" => ->(g) { [ :results, "#{g.public_id}x", 1 ] }
  }.each do |label, streamables|
    it "rejects a verified name with #{label}, and transmits nothing (AC-9.2)" do
      game.current_phase.reveal! # so that a loose reading of the name would find a revealed phase to refresh
      subscribe(signed_stream_name: signed(*streamables.call(game)))

      expect(subscription).to be_rejected
      expect(transmissions).to be_empty
    end
  end

  it "rejects an unsigned name, another key's name, no name, a trailing newline and values that are not strings (AC-9.2)" do
    forged = ActiveSupport::MessageVerifier.new("another key", serializer: JSON).generate("results:#{game.public_id}:1")
    [ "results:#{game.public_id}:1", forged, nil ].each do |name|
      name ? subscribe(signed_stream_name: name) : subscribe
      expect(subscription).to be_rejected
    end

    [ "results:#{game.public_id}:1\n", [ "results:#{game.public_id}:1" ], { "a" => 1 }, 42 ].each do |value|
      subscribe(signed_stream_name: Turbo.signed_stream_verifier.generate(value))
      expect(subscription).to be_rejected, value.inspect
    end
    expect(transmissions).to be_empty
  end
end

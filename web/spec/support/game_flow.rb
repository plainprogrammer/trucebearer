# Helpers for request specs that need a game: creating one the way a host does, and comparing stranger responses
# (spec 021, ACs 1.8, 2.x, 5.x). Each helper works on an explicit integration session, so cookies never leak between phones.
module GameFlow
  PASSPHRASE = "open sesame".freeze
  MISSING_ID = "zzzzzzzzzzzz".freeze

  Created = Struct.new(:game, :host_token, :session)

  # Posts the new-game form in a fresh session and follows the redirect, which is the one page that shows the host link.
  # Returns the game, the host token read from that page, and the session (which holds the host and seat cookies).
  def create_game(power: "england", host: nil, https: false)
    session = open_session
    session.host!(host) if host
    session.https! if https
    session.post "/games", params: { passphrase: PASSPHRASE, power: power }
    session.follow_redirect!
    link = Nokogiri::HTML5(session.response.body).at_css("#host-link")["value"]
    Created.new(Game.order(:id).last, link[/token=([^&]+)/, 1], session)
  end

  def with_passphrase
    original = ENV["TRUCEBEARER_PASSPHRASE"]
    ENV["TRUCEBEARER_PASSPHRASE"] = PASSPHRASE
    yield
  ensure
    ENV["TRUCEBEARER_PASSPHRASE"] = original
  end

  # The conditions of AC-5.5, for one path suffix ("" for the player's page, "/host" for the host page). Each maps to the
  # comparable response for a game that exists and for one that does not. The fourth condition is the host page only.
  def stranger_responses(created, suffix:)
    game = created.game
    pairs = {
      "no cookie" => [ open_session, open_session ],
      "a junk cookie named for the id" => [ junk_session(game.public_id), junk_session(MISSING_ID) ],
      "a valid cookie of another game" => [ create_game.session ] * 2
    }
    pairs["the seat cookie on a host page"] = [ seat_only_session(created) ] * 2 if suffix == "/host"

    pairs.transform_values do |(for_existing, for_missing)|
      for_existing.get "/games/#{game.public_id}#{suffix}"
      existing = comparable(for_existing.response, game.public_id)
      for_missing.get "/games/#{MISSING_ID}#{suffix}"
      [ existing, comparable(for_missing.response, MISSING_ID) ]
    end
  end

  def junk_session(id)
    open_session.tap { |session| %w[host seat].each { |kind| session.cookies["#{kind}_#{id}"] = "junk" } }
  end

  # The host's own phone with the host cookie taken away, so only the seat cookie is left. It is the same phone for both
  # requests, so both carry the same cookie. It changes the creator's session.
  def seat_only_session(created)
    created.session.tap { |session| session.cookies.delete("host_#{created.game.public_id}") }
  end
end

RSpec.configure { |config| config.include GameFlow, type: :request }

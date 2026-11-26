# Which routes can show what about orders (spec 022 FR-9). Every route the app answers is classified here; the secrecy spec
# fails on a route that is not, so a later Issue that adds a page (#24 and its streams, #25 and its results) must say what
# the new page can show. `shows: :own` means a seat's own orders to that seat and no one else; `:none` means no order data at all.
# `sweep` gives the path the invariance sweep requests for a readable GET; `fresh` means each request is made in a session of its
# own, because the route sets a cookie.
module SecrecyRoutes
  Context = Struct.new(:id, :code, :host_token, :france_token, keyword_init: true)

  APP = {
    "GET /up" => { shows: :none, sweep: ->(_c) { "/up" }, why: "health check" },
    "GET /" => { shows: :none, sweep: ->(_c) { "/" }, why: "home page" },
    "GET /styleguide" => { shows: :none, sweep: ->(_c) { "/styleguide" }, why: "static samples" },
    "GET /games/new" => { shows: :none, sweep: ->(_c) { "/games/new" }, why: "a form" },
    "POST /games" => { shows: :none, why: "creates a game, redirects to the host page" },
    "GET /join" => { shows: :none, sweep: ->(_c) { "/join" }, why: "a form" },
    "POST /join" => { shows: :none, why: "looks a code up" },
    "GET /join/:code" => { shows: :none, sweep: ->(c) { "/join/#{c.code}" }, why: "open powers only" },
    "POST /join/:code/seat" => { shows: :none, why: "takes a power" },
    "GET /games/:public_id" => { shows: :own, sweep: ->(c) { "/games/#{c.id}" }, why: "the seat's own state and count, never an order" },
    "GET /games/:public_id/host" => { shows: :none, sweep: ->(c) { "/games/#{c.id}/host" }, why: "phase header, history, dislodged units" },
    "GET /games/:public_id/host-link" => { shows: :none, fresh: true, sweep: ->(c) { "/games/#{c.id}/host-link?token=#{c.host_token}" }, why: "sets a cookie and redirects" },
    "GET /games/:public_id/seat-link" => { shows: :none, fresh: true, sweep: ->(c) { "/games/#{c.id}/seat-link?token=#{c.france_token}" }, why: "sets a cookie and redirects" },
    "GET /games/:public_id/host/close" => { shows: :none, sweep: ->(c) { "/games/#{c.id}/host/close" }, why: "a confirmation page" },
    "POST /games/:public_id/host/close" => { shows: :none, why: "closes joining" },
    "GET /games/:public_id/host/seats/:power/reissue" => { shows: :none, sweep: ->(c) { "/games/#{c.id}/host/seats/england/reissue" }, why: "a confirmation page; the reissue itself deletes the seat's saved orders (D9)" },
    "POST /games/:public_id/host/seats/:power/reissue" => { shows: :none, why: "replaces the token and deletes the seat's saved orders for the open phase" },
    "GET /games/:public_id/host/seats/:power/qr" => { shows: :none, sweep: ->(c) { "/games/#{c.id}/host/seats/england/qr" }, why: "a one-time code; without the flash it redirects" },
    "GET /games/:public_id/phases/:number/orders" => { shows: :own, sweep: ->(c) { "/games/#{c.id}/phases/1/orders" }, why: "the seat's own orders" },
    "PUT /games/:public_id/phases/:number/orders" => { shows: :own, why: "saves the seat's own orders; the reply and the redirect show only its own" },
    "GET /games/:public_id/host/phases/:number/reveal" => { shows: :none, sweep: ->(c) { "/games/#{c.id}/host/phases/1/reveal" }, why: "names the powers that have not submitted" },
    "POST /games/:public_id/host/phases/:number/reveal" => { shows: :none, why: "reveals; redirects to the host page" }
  }.freeze

  # Routes the framework engines add. They hold no game data and no model attaches to a game.
  FRAMEWORK = [
    [ %r{\A(?:GET|POST|PUT|PATCH|DELETE) /rails/(?:action_mailbox|active_storage|conductor|info|mailers)(?:/|\z)}, "Action Mailbox, Active Storage, mailer previews and info pages: no game data" ],
    [ %r{\AGET /(?:recede|resume|refresh)_historical_location\z}, "Turbo's historical-location routes: empty pages" ],
    [ /\AMOUNT \/cable\z/, "no channel exists yet; #24 adds the first stream and must classify it" ]
  ].freeze

  def self.key_for(route) = "#{route.verb.presence || 'MOUNT'} #{route.path.spec.to_s.sub('(.:format)', '')}"

  def self.classified?(key) = APP.key?(key) || FRAMEWORK.any? { |pattern, _why| key.match?(pattern) }

  # The GET routes the sweep requests, as { key => entry }.
  def self.readable = APP.select { |_key, entry| entry[:sweep] }
end

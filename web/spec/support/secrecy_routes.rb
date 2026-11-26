# Which routes can show what about orders (spec 022 FR-9). Every route the app answers is classified here; the secrecy spec
# fails on a route that is not, so a later Issue that adds a page (#25 and its results) must say what
# the new page can show. `shows: :own` means a seat's own orders to that seat and no one else; `:stepped_in` means one seat's orders to the host, only inside a recorded
# step-in into that seat (spec 026); `:none` means no order data at all.
# `sweep` gives the path the invariance sweep requests for a readable GET; `fresh` means each request is made in a session of its
# own, because the route sets a cookie.
module SecrecyRoutes
  # open: the open phase's number; revealed: the revealed phase's, when a sweep also asks for it (spec 025).
  Context = Struct.new(:id, :code, :host_token, :france_token, :open, :revealed, keyword_init: true) do
    def initialize(open: 1, revealed: nil, **rest) = super(open: open, revealed: revealed, **rest)
  end

  APP = {
    "GET /up" => { shows: :none, revealed: :none, sweep: ->(_c) { "/up" }, why: "health check" },
    "GET /" => { shows: :none, revealed: :none, sweep: ->(_c) { "/" }, why: "home page" },
    "GET /styleguide" => { shows: :none, revealed: :none, sweep: ->(_c) { "/styleguide" }, why: "static samples" },
    "GET /games/new" => { shows: :none, revealed: :none, sweep: ->(_c) { "/games/new" }, why: "a form" },
    "POST /games" => { shows: :none, revealed: :none, why: "creates a game, redirects to the host page" },
    "GET /join" => { shows: :none, revealed: :none, sweep: ->(_c) { "/join" }, why: "a form" },
    "POST /join" => { shows: :none, revealed: :none, why: "looks a code up" },
    "GET /join/:code" => { shows: :none, revealed: :none, sweep: ->(c) { "/join/#{c.code}" }, why: "open powers only" },
    "POST /join/:code/seat" => { shows: :none, revealed: :none, why: "takes a power" },
    "GET /games/:public_id" => { shows: :own, revealed: :all, sweep: ->(c) { "/games/#{c.id}" }, why: "the seat's own count, never an order of the open phase; the status list of the seven powers (spec 024); every power's orders of the latest revealed phase (spec 025); the notice that the host changed the board, a time only (spec 027 D3)" },
    "GET /games/:public_id/host" => { shows: :none, revealed: :all, sweep: ->(c) { "/games/#{c.id}/host" }, why: "phase header, history, the seat history of step-ins, reissues and board edits (spec 026 D10, spec 027 D4), the reading view of the latest revealed phase with its dislodged units (spec 025), the status list of the seven powers (spec 024)" },
    "GET /games/:public_id/host-link" => { shows: :none, revealed: :none, fresh: true, sweep: ->(c) { "/games/#{c.id}/host-link?token=#{c.host_token}" }, why: "sets a cookie and redirects" },
    "GET /games/:public_id/seat-link" => { shows: :none, revealed: :none, fresh: true, sweep: ->(c) { "/games/#{c.id}/seat-link?token=#{c.france_token}" }, why: "sets a cookie and redirects; a host browser is redirected to the step-in confirmation instead and stores nothing (spec 026 D5)" },
    "GET /games/:public_id/host/close" => { shows: :none, revealed: :none, sweep: ->(c) { "/games/#{c.id}/host/close" }, why: "a confirmation page" },
    "POST /games/:public_id/host/close" => { shows: :none, revealed: :none, why: "closes joining" },
    "GET /games/:public_id/host/seats/:power/reissue" => { shows: :none, revealed: :none, sweep: ->(c) { "/games/#{c.id}/host/seats/england/reissue" }, why: "a confirmation page; the reissue itself deletes the seat's saved orders (D9)" },
    "POST /games/:public_id/host/seats/:power/reissue" => { shows: :none, revealed: :none, why: "replaces the token, deletes the seat's saved orders for the open phase, and writes a reissues row (spec 026 D10)" },
    "GET /games/:public_id/host/seats/:power/qr" => { shows: :none, revealed: :none, sweep: ->(c) { "/games/#{c.id}/host/seats/england/qr" }, why: "a one-time code; without the flash it redirects" },
    "GET /games/:public_id/host/seats/:power/phases/:number/step-in" => { shows: :none, revealed: :none, sweep: ->(c) { "/games/#{c.id}/host/seats/england/phases/#{c.open}/step-in" }, why: "a confirmation page; it shows no order and writes nothing (spec 026)" },
    "POST /games/:public_id/host/seats/:power/phases/:number/step-in" => { shows: :none, revealed: :none, why: "records the step-in, sets a cookie that names the row, redirects" },
    "DELETE /games/:public_id/host/seats/:power/step-in" => { shows: :none, revealed: :none, why: "deletes the cookie and redirects" },
    "GET /games/:public_id/phases/:number/orders" => { shows: :own, revealed: :none, numbered: true, sweep: ->(c) { "/games/#{c.id}/phases/#{c.open}/orders" }, why: "the seat's own orders; the notice that the host changed the board, a time only (spec 027 D3)" },
    "GET /games/:public_id/phases/:number/orders/:province" => {
      shows: :own, revealed: :none, numbered: true,
      sweep: ->(c) { { "lon" => "/games/#{c.id}/phases/#{c.open}/orders/lon?draft%5Bkind%5D=support&draft%5Btarget%5D=edi",
                       "par" => "/games/#{c.id}/phases/#{c.open}/orders/par?draft%5Bkind%5D=support&draft%5Btarget%5D=bre" } },
      why: "the seat's own picker steps; a province that is not the viewer's unit is the stranger page"
    },
    "PUT /games/:public_id/phases/:number/orders" => { shows: :own, revealed: :none, why: "saves the seat's own orders; the reply and the redirect show only its own" },
    "GET /games/:public_id/host/seats/:power/phases/:number/orders" => {
      shows: :stepped_in, revealed: :none, numbered: true,
      sweep: ->(c) { { "england" => "/games/#{c.id}/host/seats/england/phases/#{c.open}/orders", "france" => "/games/#{c.id}/host/seats/france/phases/#{c.open}/orders" } },
      why: "one seat's own orders, to the host, only inside a recorded step-in into that seat (spec 026)"
    },
    "PUT /games/:public_id/host/seats/:power/phases/:number/orders" => { shows: :stepped_in, revealed: :none, why: "saves one seat's orders for the host inside a step-in; the reply shows only that seat" },
    "GET /games/:public_id/host/seats/:power/phases/:number/orders/:province" => {
      shows: :stepped_in, revealed: :none, numbered: true,
      sweep: ->(c) { { "england lon" => "/games/#{c.id}/host/seats/england/phases/#{c.open}/orders/lon?draft%5Bkind%5D=support&draft%5Btarget%5D=edi",
                       "france par" => "/games/#{c.id}/host/seats/france/phases/#{c.open}/orders/par?draft%5Bkind%5D=support&draft%5Btarget%5D=bre" } },
      why: "one seat's picker steps for the host inside a step-in into that seat"
    },
    "GET /games/:public_id/phases/:number/results" => { shows: :none, revealed: :all, numbered: true, sweep: ->(c) { "/games/#{c.id}/phases/#{c.open}/results" }, why: "every power's orders of a revealed phase, to a seat; the open phase is the stranger page (spec 025)" },
    "GET /games/:public_id/host/phases/:number/results" => { shows: :none, revealed: :all, numbered: true, sweep: ->(c) { "/games/#{c.id}/host/phases/#{c.open}/results" }, why: "the reading view of a revealed phase, to the host; the open phase is the stranger page (spec 025)" },
    "GET /games/:public_id/host/phases/:number/reveal" => { shows: :none, revealed: :none, sweep: ->(c) { "/games/#{c.id}/host/phases/#{c.open}/reveal" }, why: "names the powers that have not submitted" },
    "POST /games/:public_id/host/phases/:number/reveal" => { shows: :none, revealed: :none, why: "reveals; redirects to the host page" },
    # The host's position editor (spec 027). None is `numbered`: for a revealed number each answers a redirect with a flash that a sweep can't compare.
    "GET /games/:public_id/host/phases/:number/position" => { shows: :none, revealed: :none, sweep: ->(c) { "/games/#{c.id}/host/phases/#{c.open}/position" }, why: "the board: the units and supply-center owners of the open phase, never an order (spec 027)" },
    "GET /games/:public_id/host/phases/:number/position/units/new" => { shows: :none, revealed: :none, sweep: ->(c) { "/games/#{c.id}/host/phases/#{c.open}/position/units/new" }, why: "a form (spec 027)" },
    "POST /games/:public_id/host/phases/:number/position/units" => { shows: :none, revealed: :none, why: "adds a unit; clears every seat's saved orders without showing any (spec 027 D3)" },
    "GET /games/:public_id/host/phases/:number/position/units/:province" => { shows: :none, revealed: :none, sweep: ->(c) { "/games/#{c.id}/host/phases/#{c.open}/position/units/ber" }, why: "a unit's page (the sweep's host plays Germany, which holds Berlin); never an order (spec 027)" },
    "PATCH /games/:public_id/host/phases/:number/position/units/:province" => { shows: :none, revealed: :none, why: "moves a unit; clears every seat's saved orders without showing any (spec 027 D3)" },
    "DELETE /games/:public_id/host/phases/:number/position/units/:province" => { shows: :none, revealed: :none, why: "removes a unit; clears every seat's saved orders without showing any (spec 027 D3)" },
    "GET /games/:public_id/host/phases/:number/position/owners" => { shows: :none, revealed: :none, sweep: ->(c) { "/games/#{c.id}/host/phases/#{c.open}/position/owners" }, why: "a form (spec 027)" },
    "PUT /games/:public_id/host/phases/:number/position/owners" => { shows: :none, revealed: :none, why: "sets a supply center's owner; keeps every saved order (spec 027 D3)" },
    "GET /games/:public_id/host/phases/:number/position/date" => { shows: :none, revealed: :none, sweep: ->(c) { "/games/#{c.id}/host/phases/#{c.open}/position/date" }, why: "a form (spec 027)" },
    "PUT /games/:public_id/host/phases/:number/position/date" => { shows: :none, revealed: :none, why: "sets the season and year; keeps every saved order (spec 027 D3)" },
    "MOUNT /cable" => { shows: :none, revealed: :none, why: "two streams, each behind a signed name that only pages behind a seat or the host cookie carry: the seven submitted states (spec 024), and a contentless refresh when a phase is revealed (spec 025)" }
  }.freeze

  # Routes the framework engines add. They hold no game data and no model attaches to a game.
  FRAMEWORK = [
    [ %r{\A(?:GET|POST|PUT|PATCH|DELETE) /rails/(?:action_mailbox|active_storage|conductor|info|mailers)(?:/|\z)}, "Action Mailbox, Active Storage, mailer previews and info pages: no game data" ],
    [ %r{\AGET /(?:recede|resume|refresh)_historical_location\z}, "Turbo's historical-location routes: empty pages" ]
  ].freeze

  def self.key_for(route) = "#{route.verb.presence || 'MOUNT'} #{route.path.spec.to_s.sub('(.:format)', '')}"

  def self.classified?(key) = APP.key?(key) || FRAMEWORK.any? { |pattern, _why| key.match?(pattern) }

  # The GET routes the sweep requests, as { key => entry }. An entry's `sweep` is a path, or a Hash of { label => path } when one
  # route needs several pages swept (the picker's own units, each with a deep draft; spec 023 AC-5.2).
  def self.readable = APP.select { |_key, entry| entry[:sweep] }

  # Every page the sweep requests, as { label => { path:, entry: } }.
  def self.sweeps(context)
    passes = [ [ context, "" ] ]
    # The revealed number, for the numbered routes (spec 025). The two confirmations are left out: for a revealed phase each answers with a redirect
    # and a flash banner that the next request would show, which a sweep cannot compare (spec 022 AC-4.11 and spec 026 AC-1.7 test those redirects).
    passes << [ context.dup.tap { |c| c.open = c.revealed }, " (revealed)" ] if context.revealed
    passes.flat_map do |ctx, suffix|
      readable.select { |_key, entry| suffix.empty? || entry[:numbered] }.flat_map do |key, entry|
        result = entry[:sweep].call(ctx)
        if result.is_a?(Hash) then result.map { |name, path| [ "#{key} [#{name}]#{suffix}", { path: path, entry: entry } ] }
        else [ [ "#{key}#{suffix}", { path: result, entry: entry } ] ]
        end
      end
    end.to_h
  end
end

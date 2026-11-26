# Plan 028: Resume a game in a later session

**Spec:** `web/docs/specs/028-resume-game/spec.md` (v1.0.3, approved at Gate A)
**Branch:** `web/28-resume-game`

## Global Constraints

- Web side only. Nothing under `adjudicator/`, `.github/` or the root files changes (`git diff --name-only main...HEAD` lists only `web/` paths).
- Test first, RSpec. Every phase begins with a spec seen failing, and the failing spec is committed before the code that fixes it.
- No new dependency, no new route, no migration, no JavaScript. `GameAccess` is not edited.
- The host page, the seat page and the channels are not edited (#112 and #105 work there). The only edited views are `home/index`, the stranger page and the style guide.
- Words on screen: no rulebook text; "Diplomacy" appears nowhere.
- Commit messages are plain imperative sentences ending with `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`. One git operation per shell call. No force-push; `main` comes in by merge.
- Stylesheet budget: 29,963 of 32,768 bytes in total; `.game-card` plus its sample stay within 2,800 bytes, `styleguide.css` gains nothing. Measure again after any merge of `main`.
- Run from `web/`.

## Goal

The home page lists, as `.game-card` links, the games whose host or seat cookies verify for this browser, and nothing else; a lost seat is explained by one static line; the host link goes to the host's seat when the browser holds it; and the whole is proved by request specs, the secrecy sweep, and a system spec at 360 pixels.

## Gates checked

- **Simplicity:** three parts: one concern (`ResumableGames`), one partial with one helper (`home/_game_card`, `GameCardsHelper`), one static partial (`shared/_lost_seat`). A one-line change to `HostLinksController`. No model change, no query object, no service.
- **Anti-abstraction:** the concern calls `host?`, `seat_of` and `own_seat_target` of `GameAccess` and `Game#host_seat`; it does not wrap them. The card receives a `Data` entry, not a presenter chain.
- **Integration-first:** Phase 1 is the failing request spec written first; the secrecy proof (Phase 3) is written before the cap and shape rules it exercises are finished.

## Files

| Create | Responsibility |
|---|---|
| `app/controllers/concerns/resumable_games.rb` | cookie names, the cap, verification, the phases query, the entries (D2, D3) |
| `app/helpers/game_cards_helper.rb` | `game_started(game)` (D4) |
| `app/views/home/_game_card.html.erb` | the `.game-card` (D3, D9) |
| `app/views/shared/_lost_seat.html.erb` | the static line (D6) |
| `spec/requests/resume_game_spec.rb` | Stories 1, 2, 4, 5: the first test and the card, host, line and host-link examples |
| `spec/requests/resume_secrecy_spec.rb` | Story 3 |
| `spec/system/resume_game_spec.rb` | Stories 6, 7: the three parts, 360 pixels, screenshots |
| `docs/specs/028-resume-game/screens/*.png` | the screenshots |

| Change | What |
|---|---|
| `app/controllers/home_controller.rb` | include the concern, `no_store`, `@games` |
| `app/views/home/index.html.erb` | the "Your games" section and the line |
| `app/views/strangers/show.html.erb` | the line |
| `app/controllers/host_links_controller.rb` | the redirect goes to `own_seat_target(game)` |
| `app/assets/stylesheets/components.css` | `.game-cards`, `.game-card` |
| `app/views/styleguide/show.html.erb`, `app/helpers/styleguide_helper.rb` | the `game-card` section and its sample data |
| `spec/support/secrecy_routes.rb`, `spec/requests/order_secrecy_spec.rb` | the `why` of `GET /`, the sweep part (AC-3.9) |
| `spec/requests/styleguide_spec.rb`, `spec/docs/design_system_spec.rb`, `spec/docs/spec_amendments_spec.rb` | components list, catalog line, amendment rows |
| `docs/design-system.md`, `README.md`, specs 021 and 022 | the documents (Story 8) |

## Phase 1: The first test (red)

**Implements:** Story 1. **Satisfies:** AC-1.1. **Files:** `spec/requests/resume_game_spec.rb`. **Interfaces:** none yet.

```ruby
require "rails_helper"

# Spec 028 Story 1: a phone that holds a seat is led back to its game from the home page, and a phone with no cookie sees no game.
RSpec.describe "Resuming a game", type: :request do
  let(:started) { Game.start!(power: "england") }
  let(:game) { started.game }
  let(:id) { game.public_id }
  let(:england_phone) do
    open_session.tap { |phone| phone.get "/games/#{id}/seat-link", params: { token: started.seat_token } } # the seat cookie, and no other
  end

  def cards(phone) = Nokogiri::HTML5(phone.response.body).css("a.game-card")

  it "leads England's phone to the game's current phase and shows a phone with no cookie no game (AC-1.1)" do
    england_phone.get "/"

    expect(england_phone.response).to have_http_status(:ok)
    expect(cards(england_phone).size).to eq(1)
    card = cards(england_phone).first
    expect(card["href"]).to eq("/games/#{id}")
    expect(card.text.squish).to include(game.current_phase.title).and include("England")

    england_phone.get card["href"]
    expect(england_phone.response).to have_http_status(:ok)
    expect(england_phone.response.body).to include(game.current_phase.title)

    nobody = open_session
    nobody.get "/"
    expect(nobody.response).to have_http_status(:ok)
    expect(cards(nobody)).to be_empty
    expect(nobody.response.body).not_to include("Your games")
    expect(nobody.response.body).not_to include(id)
  end
end
```

**Verify:** `bundle exec rspec spec/requests/resume_game_spec.rb` fails on `expect(cards(england_phone).size).to eq(1)` (got 0). Commit the failing spec with the plan: "Add the first failing spec for resuming a game".

## Phase 2: The cards (green, then the card rules)

**Implements:** FR-1, FR-2, D2, D3, D4, D7. **Satisfies:** AC-1.1 to AC-1.6, AC-2.1 to AC-2.5. **Files:** `app/controllers/concerns/resumable_games.rb`, `app/controllers/home_controller.rb`, `app/helpers/game_cards_helper.rb`, `app/views/home/_game_card.html.erb`, `app/views/home/index.html.erb`, `spec/requests/resume_game_spec.rb`. **Interfaces:** `resumable_games` returns `[ResumableGames::Entry]`; `Entry = Data.define(:game, :phase, :power, :host, :href)`; the partial takes `entry:`; `game_started(game)` returns a `<time>` tag.

Test first: add these examples to `spec/requests/resume_game_spec.rb` (each seen failing before the code):

```ruby
  def card_text(phone, index = 0) = cards(phone)[index].text.squish

  it "sends no-store and sets or deletes no game cookie (AC-1.6)" do
    england_phone.get "/"
    expect(england_phone.response.headers["Cache-Control"]).to include("no-store")
    expect(cookie_lines(england_phone.response).grep(/\A(?:host|seat|step_in)_/)).to be_empty

    nobody = open_session
    nobody.get "/"
    expect(nobody.response.headers["Cache-Control"]).to include("no-store")
    expect(cookie_lines(nobody.response).grep(/\A(?:host|seat|step_in)_/)).to be_empty
  end

  it "keeps the intro, then the cards, then the two buttons (AC-1.5)" do
    england_phone.get "/"
    main = Nokogiri::HTML5(england_phone.response.body).at_css("main")

    expect(main.at_css("h1").text).to eq("Trucebearer")
    expect(main.at_css("p").text).to eq("Enter secret orders on your phone and have each turn adjudicated.")
    order = main.css("h2, a.game-card, a.button").map { |node| node.name == "h2" ? "h2" : node["class"].split.first }
    expect(order).to eq(%w[h2 game-card button button])
    expect(main.css("a.button").map(&:text)).to eq([ "Create a game", "Join a game" ])
    expect(main.at_css("h2").text).to eq("Your games")
  end

  it "shows the new open phase after a reveal, with the same link (AC-1.3)" do
    england_phone.get "/"
    before = card_text(england_phone)
    game.current_phase.reveal!

    england_phone.get "/"
    expect(cards(england_phone).first["href"]).to eq("/games/#{id}")
    expect(card_text(england_phone)).not_to eq(before)
    expect(card_text(england_phone)).to include(game.reload.current_phase.title)
  end

  it "lists two games newest first, each with its own phase and power (AC-1.4)" do
    older = started
    older.game.update_columns(created_at: 3.days.ago)
    newer = Game.start!(power: "france")
    phone = open_session
    phone.get "/games/#{older.game.public_id}/seat-link", params: { token: older.seat_token }
    phone.get "/games/#{newer.game.public_id}/seat-link", params: { token: newer.seat_token }

    phone.get "/"

    expect(cards(phone).map { |card| card["href"] }).to eq([ "/games/#{newer.game.public_id}", "/games/#{older.game.public_id}" ])
    expect(card_text(phone, 0)).to include("France")
    expect(card_text(phone, 1)).to include("England")
  end

  describe "the host (D3, AC-2.1 to AC-2.5)" do
    let(:host_token) { started.host_token }

    def holder(*links)
      open_session.tap do |phone|
        links.each { |path, token| phone.get "/games/#{id}/#{path}", params: { token: token } }
      end
    end

    it "links a host with its own seat to the seat page, with the badge and the words (AC-2.1)" do
      phone = holder([ "host-link", host_token ], [ "seat-link", started.seat_token ])
      phone.get "/"

      expect(cards(phone).first["href"]).to eq("/games/#{id}")
      expect(card_text(phone)).to include("England").and include("You host this game")
    end

    it "links a host with no seat to the host page, with no badge (AC-2.2)" do
      phone = holder([ "host-link", host_token ])
      phone.get "/"

      expect(cards(phone).first["href"]).to eq("/games/#{id}/host")
      expect(card_text(phone)).to include("You host this game")
      expect(cards(phone).first.at_css(".power-badge")).to be_nil
    end

    it "treats a foreign seat cookie as no seat and deletes nothing (AC-2.3)" do
      _france, token = game.take_seat!("france")
      phone = holder([ "seat-link", token ], [ "host-link", host_token ])
      phone.get "/"

      expect(cards(phone).first["href"]).to eq("/games/#{id}/host")
      expect(cards(phone).first.at_css(".power-badge")).to be_nil
      expect(cookie_lines(phone.response).grep(/\Aseat_/)).to be_empty
      expect(phone.cookies["seat_#{id}"]).to be_present
    end

    it "does not call the holder of the host's own seat the host when the host cookie is gone (AC-2.4)" do
      phone = holder([ "seat-link", started.seat_token ])
      phone.get "/"

      expect(cards(phone).first["href"]).to eq("/games/#{id}")
      expect(card_text(phone)).not_to include("You host this game")
    end

    it "gives each game its own card by the table (AC-2.5)" do
      other = Game.start!(power: "france")
      phone = holder([ "host-link", host_token ], [ "seat-link", started.seat_token ])
      phone.get "/games/#{other.game.public_id}/seat-link", params: { token: other.seat_token }
      phone.get "/"

      hrefs = cards(phone).to_h { |card| [ card["href"], card.text.squish ] }
      expect(hrefs.keys).to match_array([ "/games/#{id}", "/games/#{other.game.public_id}" ])
      expect(hrefs["/games/#{id}"]).to include("You host this game")
      expect(hrefs["/games/#{other.game.public_id}"]).not_to include("You host this game")
    end
  end
```

Code. The concern (the cap and the shape rule are final here; Phase 3 proves them):

```ruby
# The games this browser can resume, read from its cookies (spec 028 D2, D3). A cookie is only a claim: a game is listed only when
# the same signed-cookie and digest checks every game page uses accept it, and nothing is read about a game before that.
module ResumableGames
  extend ActiveSupport::Concern

  LIMIT = 40 # distinct ids examined, in the order the request sent them (D2)
  NAME = /\A(?:host|seat)_(.+)\z/

  Entry = Data.define(:game, :phase, :power, :host, :href)

  private

  def resumable_games
    ids = request.cookies.keys.filter_map { |name| name[NAME, 1] }.select { |id| id.match?(GameAccess::PUBLIC_ID_SHAPE) }.uniq.first(LIMIT)
    return [] if ids.empty?

    held = Game.includes(:seats).where(public_id: ids).filter_map do |game|
      host = host?(game)
      seat = seat_of(game)
      [ game, host, seat ] if host || seat
    end
    return [] if held.empty?

    phases = Phase.where(game_id: held.map { |game, *| game.id }, revealed_at: nil).index_by(&:game_id)
    held.sort_by { |game, *| [ -game.created_at.to_f, -game.id ] }.filter_map do |game, host, seat|
      phase = phases[game.id]
      next unless phase # a game with no open phase is dropped, never an error

      own = host ? (seat if seat == game.host_seat) : seat
      Entry.new(game: game, phase: phase, power: own&.power, host: host,
                href: host ? own_seat_target(game) : game_path(game.public_id))
    end
  end
end
```

```ruby
class HomeController < ApplicationController
  include ResumableGames

  def index
    no_store # the page varies with the cookies (spec 028 D7)
    @games = resumable_games
  end
end
```

```ruby
# The date a game started, as the table reads it (spec 028 D4): in the zone StepInsHelper#table_zone names.
module GameCardsHelper
  def game_started(game)
    tag.time(game.created_at.in_time_zone(table_zone).strftime("%-d %b %Y"), datetime: game.created_at.utc.iso8601)
  end
end
```

```erb
<%# The game card (spec 028 D3, D9): one link to a game. locals: entry (game, phase, power, host, href) %>
<%= link_to entry.href, class: "game-card" do %>
  <p class="game-card__title">Started <%= game_started(entry.game) %></p>
  <%= render "phases/header", phase: entry.phase, power: entry.power if entry.power %>
  <%= render "phases/header", phase: entry.phase unless entry.power %>
  <% if entry.host %><p class="game-card__note">You host this game</p><% end %>
<% end %>
```

(The two header lines keep the partial's own `local_assigns[:power]` test honest: it is never passed a nil power.)

```erb
<% content_for :title, "Trucebearer" %>

<div class="stack">
  <h1>Trucebearer</h1>
  <p>Enter secret orders on your phone and have each turn adjudicated.</p>
  <% if @games.any? %>
    <section class="stack" aria-labelledby="your-games">
      <h2 id="your-games">Your games</h2>
      <ul class="game-cards">
        <% @games.each do |entry| %>
          <li><%= render "home/game_card", entry: entry %></li>
        <% end %>
      </ul>
    </section>
  <% end %>
  <%= link_to "Create a game", new_game_path, class: "button" %>
  <%= link_to "Join a game", join_path, class: "button button--secondary" %>
</div>
```

(`.game-cards` has no rule yet; Phase 6 adds it. The line of D6 is Phase 4.)

**Verify:** `bundle exec rspec spec/requests/resume_game_spec.rb spec/requests/root_spec.rb` passes. Commit "Show a browser's games as cards on the home page".

## Phase 3: The secrecy proof

**Implements:** FR-1, D2, D8. **Satisfies:** AC-3.1 to AC-3.12. **Files:** `spec/requests/resume_secrecy_spec.rb`, `spec/support/secrecy_routes.rb`, `spec/requests/order_secrecy_spec.rb`. **Interfaces:** none new.

Test first: `spec/requests/resume_secrecy_spec.rb`, written whole before any change to the concern (the concern from Phase 2 already meets most of it; each example that passes at once is checked by breaking the concern briefly, as noted in the verify step).

```ruby
require "rails_helper"

# Spec 028 Story 3: a browser's home page names its own games and nothing about any other (D2, D8).
RSpec.describe "What the home page shows each browser", type: :request do
  # Three games, each with its own powers, its own start day and its own phase title, so a leak of any one of them can be seen.
  let!(:a) { Game.start!(power: "england") }
  let!(:b) { Game.start!(power: "france") }
  let!(:c) { Game.start!(power: "germany") }
  let(:games) { { a: a.game, b: b.game, c: c.game } }

  before do
    a.game.update_columns(created_at: Time.utc(2026, 3, 3, 12))
    b.game.update_columns(created_at: Time.utc(2026, 4, 4, 12))
    c.game.update_columns(created_at: Time.utc(2026, 5, 5, 12))
    b.game.edit_position!(1, { "action" => "date_set", "to_season" => "fall", "to_year" => 1902 })
    c.game.edit_position!(1, { "action" => "date_set", "to_season" => "spring", "to_year" => 1903 })
  end

  def phone(*links)
    open_session.tap { |session| links.each { |game, kind, token| session.get "/games/#{game.public_id}/#{kind}-link", params: { token: token } } }
  end

  def hrefs(phone) = Nokogiri::HTML5(phone.response.body).css("a.game-card").map { |card| card["href"] }

  # The raw text of a signed cookie value, as the app would have written it.
  def signed(name, value)
    request = ActionDispatch::Request.new(Rails.application.env_config.dup)
    request.cookie_jar.signed[name] = value
    request.cookie_jar[name]
  end

  it "lists exactly a browser's own games and nothing of the others (AC-3.1, AC-3.2)" do
    only_a = phone([ a.game, "seat", a.seat_token ])
    b_and_c = phone([ b.game, "seat", b.seat_token ], [ c.game, "host", c.host_token ])
    nobody = open_session
    junk = open_session.tap { |s| games.each_value { |g| %w[host seat].each { |kind| s.cookies["#{kind}_#{g.public_id}"] = "junk" } } }
    [ only_a, b_and_c, nobody, junk ].each { |s| s.get "/" }

    expect(hrefs(only_a)).to eq([ "/games/#{a.game.public_id}" ])
    expect(hrefs(b_and_c)).to eq([ "/games/#{c.game.public_id}/host", "/games/#{b.game.public_id}" ])
    expect(hrefs(nobody)).to be_empty
    expect(hrefs(junk)).to be_empty

    others = lambda do |phone, hidden|
      body = phone.response.body
      hidden.flat_map { |g| [ g.public_id, g.join_code, g.created_at.strftime("%-d %b %Y"), g.current_phase.title ] }.each do |text|
        expect(body).not_to include(text)
      end
    end
    others.call(only_a, [ b.game, c.game ])
    others.call(b_and_c, [ a.game ])
    others.call(nobody, games.values)
    others.call(junk, games.values)
    [ only_a, b_and_c, nobody, junk ].each do |s|
      games.each_value { |g| expect(s.response.body).not_to include(g.join_code) } # no join code at all
    end
    expect(nobody.response.body).not_to match(/England|France|Germany/)
  end

  it "lists no game for a cookie that does not verify (AC-3.3)" do
    id_a = a.game.public_id
    id_b = b.game.public_id
    sets = {
      "B's raw seat value under A's name (fails at the signature)" => ->(s) { s.cookies["seat_#{id_a}"] = phone([ b.game, "seat", b.seat_token ]).cookies["seat_#{id_b}"] },
      "a value signed under A's name that holds B's seat token (fails at the digest)" => ->(s) { s.cookies["seat_#{id_a}"] = signed("seat_#{id_a}", b.seat_token) },
      "a host cookie that holds A's seat token" => ->(s) { s.cookies["host_#{id_a}"] = signed("host_#{id_a}", a.seat_token) },
      "an unsigned value" => ->(s) { s.cookies["seat_#{id_a}"] = a.seat_token },
      "a tampered signed value" => ->(s) { s.cookies["seat_#{id_a}"] = signed("seat_#{id_a}", a.seat_token).sub(/.\z/) { |ch| ch == "a" ? "b" : "a" } },
      "a game that does not exist" => ->(s) { s.cookies["seat_zzzzzzzzzzzz"] = signed("seat_zzzzzzzzzzzz", a.seat_token) }
    }
    sets.each do |label, build|
      session = open_session.tap(&build)
      session.get "/"

      expect(session.response).to have_http_status(:ok), label
      expect(hrefs(session)).to be_empty, label
    end

    control = open_session.tap { |s| s.cookies["seat_#{id_a}"] = signed("seat_#{id_a}", a.seat_token) }
    control.get "/"
    expect(hrefs(control)).to eq([ "/games/#{id_a}" ]), "the helper must produce a cookie the app accepts"
  end

  it "answers junk for an existing game, junk for a missing one and no cookie with the same page (AC-3.4)" do
    normalize = ->(session) { comparable(session.response, a.game.public_id).tap { |r| r[1] = r[1].gsub(/(name="csrf-token" content=")[^"]*/, '\1TOKEN') } }
    existing = open_session.tap { |s| %w[host seat].each { |kind| s.cookies["#{kind}_#{a.game.public_id}"] = "junk" } }
    missing = open_session.tap { |s| %w[host seat].each { |kind| s.cookies["#{kind}_zzzzzzzzzzzz"] = "junk" } }
    none = open_session
    [ existing, missing, none ].each { |s| s.get "/" }

    expect(normalize.call(existing)).to eq(normalize.call(none))
    expect(normalize.call(missing)).to eq(normalize.call(none))
  end

  it "ignores names that are not game cookies (AC-3.5)" do
    id = a.game.public_id
    token = phone([ a.game, "seat", a.seat_token ]).cookies["seat_#{id}"]
    names = [ "seat_short", "host_#{'a' * 13}", "seat_#{id}x", "step_in_#{id}", "seat_#{id}.x", "seat_#{id}/x", "other_#{id}" ]
    header = names.map { |name| "#{name}=#{token}" }.join("; ")
    session = open_session
    session.get "/", headers: { "HTTP_COOKIE" => header }

    expect(session.response).to have_http_status(:ok)
    expect(hrefs(session)).to be_empty
  end

  it "examines the first 40 ids in request order and no more (AC-3.6)" do
    id = a.game.public_id
    token = phone([ a.game, "seat", a.seat_token ]).cookies["seat_#{id}"]
    filler = Array.new(40) { |i| "seat_#{format('%012d', i)}=junk" }
    session = open_session
    session.get "/", headers: { "HTTP_COOKIE" => (filler + [ "seat_#{id}=#{token}" ]).join("; ") }

    expect(session.response).to have_http_status(:ok)
    expect(hrefs(session)).to be_empty # the 41st id is not looked up

    session.get "/", headers: { "HTTP_COOKIE" => ([ "seat_#{id}=#{token}" ] + filler.first(39)).join("; ") }
    expect(hrefs(session)).to eq([ "/games/#{id}" ])
  end

  it "makes at most three queries on games, seats and phases, whatever the cookies (AC-3.7)" do
    id = a.game.public_id
    token = phone([ a.game, "seat", a.seat_token ]).cookies["seat_#{id}"]
    filler = Array.new(59) { |i| "seat_#{format('%012d', i)}=junk" }
    [ [], [ "seat_#{id}=#{token}" ], [ "seat_#{id}=#{token}" ] + filler ].each do |cookies|
      queries = []
      counter = ->(*, payload) { queries << payload[:sql] if payload[:sql].match?(/FROM "(?:games|seats|phases)"/) && payload[:name] != "SCHEMA" }
      session = open_session
      ActiveSupport::Notifications.subscribed(counter, "sql.active_record") do
        session.get "/", headers: { "HTTP_COOKIE" => cookies.join("; ") }
      end

      expect(queries.size).to be <= 3, queries.join("\n")
    end
  end

  it "stops listing a seat when the host reissues it, and lists it again for the new phone (AC-3.8)" do
    old_phone = phone([ b.game, "seat", b.seat_token ])
    old_phone.get "/"
    expect(hrefs(old_phone)).to eq([ "/games/#{b.game.public_id}" ])

    token = b.game.reissue_seat!(b.game.seat_for(b.seat_token))
    old_phone.get "/"
    expect(hrefs(old_phone)).to be_empty

    new_phone = phone([ b.game, "seat", token ])
    new_phone.get "/"
    expect(hrefs(new_phone)).to eq([ "/games/#{b.game.public_id}" ])
  end

  it "keeps the home page free of any order, count or submitted state (AC-3.12)" do
    scanned = %w[app/controllers/concerns/resumable_games.rb app/views/home/_game_card.html.erb app/views/home/index.html.erb
                 app/helpers/game_cards_helper.rb]
    source = scanned.map { |path| File.read(Rails.root.join(path)) }.join("\n")

    %w[saved_orders SavedOrder Submission submitted? ordered_count orders_for].each do |word|
      expect(source).not_to include(word), "#{word} must not appear in the home page's source"
    end
  end
end
```

Then the route table and the sweep (AC-3.9 to AC-3.11). In `spec/support/secrecy_routes.rb` replace the `GET /` entry's `why`:

```ruby
    "GET /" => { shows: :none, revealed: :none, sweep: ->(_c) { "/" }, why: "home page; lists the games the request's own verified cookies belong to, each as the game's start date, its open phase's title and the viewer's power, never an order, a count or a submitted state (spec 028)" },
```

In `spec/requests/order_secrecy_spec.rb`, inside `describe "the sweep"`, after the example "has a position edit in the host page's history ...":

```ruby
    it "lists on the home page exactly what each viewer's cookies verify for (spec 028 AC-3.9)" do
      viewers
      home = lambda do |name, session|
        session.cookies["seat_#{id}"] = @wearing_france_cookie if name == "the host, with France's seat cookie"
        session.get "/"
        Nokogiri::HTML5(session.response.body).css("a.game-card").map { |card| [ card["href"], card.text.squish ] }
      end
      listed = viewers.to_h { |name, session| [ name, home.call(name, session) ] }

      expect(listed["another seat"].map(&:first)).to eq([ "/games/#{id}" ])
      expect(listed["another seat"].first.last).to include("France").and not_include("You host this game")
      expect(listed["the host, with a seat of its own"].map(&:first)).to eq([ "/games/#{id}" ])
      expect(listed["the host, with a seat of its own"].first.last).to include("Germany").and include("You host this game")
      expect(listed["the host, with no seat"].map(&:first)).to eq([ "/games/#{id}/host" ])
      expect(listed["a stranger"]).to be_empty
      expect(listed["the host, with France's seat cookie"].map(&:first)).to eq([ "/games/#{id}/host" ])
      expect(listed["the host, stepped into France"].map(&:first)).to eq([ "/games/#{id}/host" ])
    end
```

The same edit adds `RSpec::Matchers.define_negated_matcher :not_include, :include` above the `RSpec.describe` of `order_secrecy_spec.rb`.

The sweep already requests `/` as every viewer before and after England's orders (AC-3.10), and the route-table examples already cover AC-3.11; both are run, not rewritten.

**Verify:** `bundle exec rspec spec/requests/resume_secrecy_spec.rb spec/requests/order_secrecy_spec.rb` passes. To prove the examples can fail, in a scratch edit (reverted before the commit) change `host?(game)` to `true` in the concern and see AC-3.1 and AC-3.3 fail; change `.first(LIMIT)` to `.first(60)` and see AC-3.6 fail. Commit "Prove that the home page shows a browser only its own games".

## Phase 4: The lost-seat line

**Implements:** FR-3, D6. **Satisfies:** AC-4.1 to AC-4.4. **Files:** `app/views/shared/_lost_seat.html.erb`, `app/views/home/index.html.erb`, `app/views/strangers/show.html.erb`, `spec/requests/resume_game_spec.rb`. **Interfaces:** the partial has no locals.

Test first (added to `spec/requests/resume_game_spec.rb`):

```ruby
  describe "the lost-seat line (D6)" do
    let(:line) { "Lost your seat? Ask the host for a new QR code." }

    def occurrences(phone) = phone.response.body.scan(line).size

    it "is on the home page once, below the buttons, for everyone (AC-4.1, AC-4.4)" do
      [ open_session, england_phone ].each do |phone|
        phone.get "/"
        main = Nokogiri::HTML5(phone.response.body).at_css("main")
        expect(occurrences(phone)).to eq(1)
        expect(main.css("a.button, p").map(&:text).last).to eq(line)
        expect(main.css("p").find { |p| p.text == line }.css("a")).to be_empty
      end
    end

    it "is on the stranger page once, and the stranger responses stay identical (AC-4.2)" do
      phone = open_session
      phone.get "/games/#{id}"
      expect(phone.response).to have_http_status(:not_found)
      expect(occurrences(phone)).to eq(1)

      existing, missing = [ id, GameFlow::MISSING_ID ].map do |game_id|
        open_session.tap { |s| s.get "/games/#{game_id}" }.then { |s| comparable(s.response, game_id) }
      end
      expect(existing).to eq(missing)
    end

    it "gives a reissued seat back to its replacement phone and not to the old one (AC-4.3)" do
      old_phone = england_phone
      token = game.reissue_seat!(game.seat_for(started.seat_token))
      new_phone = open_session
      new_phone.get "/games/#{id}/seat-link", params: { token: token }

      expect(new_phone.response.location).to eq("http://www.example.com/games/#{id}")
      new_phone.get "/"
      expect(cards(new_phone).map { |card| card["href"] }).to eq([ "/games/#{id}" ])
      old_phone.get "/games/#{id}"
      expect(old_phone.response).to have_http_status(:not_found)
      old_phone.get "/"
      expect(cards(old_phone)).to be_empty
    end
  end
```

Code:

```erb
<%# The one line for a player whose cookie is gone (spec 028 D6). The same words for everyone, so it says nothing about any game. %>
<p class="text-muted">Lost your seat? Ask the host for a new QR code.</p>
```

In `home/index.html.erb`, after the two buttons: `<%= render "shared/lost_seat" %>`. In `strangers/show.html.erb`, after the home page link: `<%= render "shared/lost_seat" %>`.

**Verify:** `bundle exec rspec spec/requests/resume_game_spec.rb spec/requests/host_spec.rb spec/requests/player_spec.rb spec/requests/joining_spec.rb` passes (the stranger checks of specs 021 and 026 still hold). Commit "Tell a player with no seat to ask the host for a new QR code".

## Phase 5: The host link goes to the host's seat

**Implements:** FR-4, D5. **Satisfies:** AC-5.1 to AC-5.4. **Files:** `app/controllers/host_links_controller.rb`, `spec/requests/resume_game_spec.rb`. **Interfaces:** none new.

Test first (added to `spec/requests/resume_game_spec.rb`):

```ruby
  describe "the host link (D5)" do
    let(:host_token) { started.host_token }

    it "sends a fresh browser to the host page (AC-5.1)" do
      phone = open_session
      phone.get "/games/#{id}/host-link", params: { token: host_token }

      expect(phone.response.location).to eq("http://www.example.com/games/#{id}/host")
      expect(phone.response.headers["Referrer-Policy"]).to eq("no-referrer")
    end

    it "sends a browser that holds the host's own seat to the seat page, which has the host controls (AC-5.2)" do
      phone = open_session
      phone.get "/games/#{id}/seat-link", params: { token: started.seat_token }
      phone.get "/games/#{id}/host-link", params: { token: host_token }

      expect(phone.response.location).to eq("http://www.example.com/games/#{id}")
      phone.get "/games/#{id}"
      expect(Nokogiri::HTML5(phone.response.body).at_css("a[href='/games/#{id}/host']").text).to eq("Host controls")
    end

    it "sends a browser that holds another seat to the host page (AC-5.3)" do
      _france, token = game.take_seat!("france")
      phone = open_session
      phone.get "/games/#{id}/seat-link", params: { token: token }
      phone.get "/games/#{id}/host-link", params: { token: host_token }

      expect(phone.response.location).to eq("http://www.example.com/games/#{id}/host")
    end

    it "leaves a wrong token as the stranger page (AC-5.4)" do
      phone = england_phone
      phone.get "/games/#{id}/host-link", params: { token: Token.generate }

      expect(phone.response).to have_http_status(:not_found)
      expect(cookie_lines(phone.response).grep(/\A(?:host|seat)_/)).to be_empty
    end
  end
```

Code, in `HostLinksController#show` (the only change):

```ruby
    remember(:host, game, params[:token])
    redirect_to own_seat_target(game) # the seat page when this browser holds the host's own seat, else the host page (spec 028 D5)
```

`own_seat_target(game)` returns a path; `redirect_to` of a path answers the full URL, as before.

**Verify:** `bundle exec rspec spec/requests/resume_game_spec.rb spec/requests/host_spec.rb spec/requests/step_in_reissue_spec.rb spec/requests/order_secrecy_spec.rb` passes (the existing examples open the host link in a fresh session or after a foreign seat link, and both still go to the host page). Commit "Send the host link to the host's own seat when the browser holds it".

## Phase 6: The `.game-card` component and the style guide

**Implements:** D9. **Satisfies:** AC-8.1 to AC-8.3. **Files:** `app/assets/stylesheets/components.css`, `app/views/styleguide/show.html.erb`, `app/helpers/styleguide_helper.rb`, `docs/design-system.md`, `spec/requests/styleguide_spec.rb`, `spec/docs/design_system_spec.rb`. **Interfaces:** `StyleguideHelper::SAMPLE_ENTRIES` is three `ResumableGames::Entry`-shaped values for the sample.

Test first:

1. In `spec/requests/styleguide_spec.rb` add `game-card` to `components` (line 5), and an example:

```ruby
    it "shows the game card in its three forms (spec 028 AC-8.1)" do
      cards = page.css("section[data-component=game-card] a.game-card")

      expect(cards.size).to eq(3)
      expect(cards.map { |card| card.text.squish }.join(" ")).to include("You host this game")
      expect(cards.count { |card| card.at_css(".power-badge") }).to eq(2)
    end
```

2. In `spec/docs/design_system_spec.rb`:

```ruby
  it "lists the game card of Issue 28 as built, with its class, partial and words (spec 028 AC-8.2)" do
    line = doc.lines.find { |l| l.include?("`.game-card`") && l.include?("#28") && l.match?(/built/i) }

    expect(line).not_to be_nil, "no catalog line names .game-card with #28 and built"
    expect(line).to include("home/_game_card").and include("game_started").and include("Start date, phase header, your power")
  end
```

3. The budget is already checked by `stylesheet_rules_spec.rb` (32 KB, 6 KB); add to `spec/styles/stylesheet_rules_spec.rb`:

```ruby
  it "keeps the game card within its 2,800 bytes (spec 028 AC-8.3)" do
    css = Stylesheets.read(File.join(Stylesheets::DIR, "components.css"))
    block = css[/\/\* ---- Game card \(#28\).*?(?=\n  \/\* ----|\z)/m].to_s

    expect(block).not_to be_empty
    expect(block.bytesize).to be <= 2800
  end
```

Seen failing, then code. In `components.css`, after the phase header rules:

```css
  /* ---- Game card (#28): one link to a game: the start date, the phase header, and the viewer's badge ---- */
  .game-cards {
    display: flex;
    flex-direction: column;
    gap: var(--space-3);
    margin: 0;
    padding: 0;
    list-style: none;
  }

  a.game-card {
    display: flex;
    flex-direction: column;
    gap: var(--space-2);
    min-height: var(--tap-min);
    padding: var(--space-3) var(--space-4);
    background: var(--color-surface);
    border: var(--border-width) solid var(--color-border);
    border-radius: var(--radius);
    color: var(--color-text);
    text-decoration: none;
    touch-action: manipulation;
  }

  a.game-card:visited {
    color: var(--color-text);
  }

  .game-card__title {
    margin: 0;
    font-weight: var(--weight-strong);
  }

  .game-card__note {
    margin: 0;
    color: var(--color-text-muted);
  }

  @media (hover: hover) {
    a.game-card:hover {
      background: var(--color-page);
    }
  }

  a.game-card:active {
    background: var(--color-page);
    box-shadow: inset 0 0 0 var(--border-width) var(--color-border);
  }
```

In `styleguide_helper.rb` (the sample needs no database):

```ruby
  SAMPLE_CARD_GAME = Struct.new(:created_at).new(Time.utc(2026, 11, 21, 12)).freeze
  SAMPLE_ENTRIES = [
    ResumableGames::Entry.new(game: SAMPLE_CARD_GAME, phase: nil, power: "england", host: false, href: "#"),
    ResumableGames::Entry.new(game: SAMPLE_CARD_GAME, phase: nil, power: "germany", host: true, href: "#"),
    ResumableGames::Entry.new(game: SAMPLE_CARD_GAME, phase: nil, power: nil, host: true, href: "#")
  ].freeze
```

The sample's phase is built in the view from `Phase.new(position: RulesEngine.starting_position)`, as the phase-header sample does, and passed with `entry.with(phase: sample_phase)`. In `styleguide/show.html.erb`, after the `phase-header` section:

```erb
  <section data-component="game-card" class="stack" aria-labelledby="sg-game-card">
    <h2 id="sg-game-card">Game card</h2>
    <p>One link to a game on the home page: when it started, the open phase, and your power. A host sees the words "You host this game"; a host with no seat has no badge.</p>
    <ul class="game-cards">
      <% StyleguideHelper::SAMPLE_ENTRIES.each do |entry| %>
        <li><%= render "home/game_card", entry: entry.with(phase: sample_phase) %></li>
      <% end %>
    </ul>
  </section>
```

(`sample_phase` is the local the phase-header section above it sets in the same template; `href: "#"` keeps the sample inert.) In `docs/design-system.md`, the catalog row:

```
| Game card | `.game-card` (partial `home/_game_card`, helper `game_started`) | #28 (built) | One link to a game on the home page: the start date, the phase header with your power badge, and "You host this game" for a host. Start date, phase header, your power |
```

**Verify:** `bundle exec rspec spec/requests/styleguide_spec.rb spec/docs spec/styles spec/system/styleguide_layout_spec.rb` passes, and `wc -c app/assets/stylesheets/*.css` totals at most 32,768. Commit "Build the game card and add it to the style guide".

## Phase 7: The system spec and the screenshots

**Implements:** Stories 6 and 7. **Satisfies:** AC-6.1 to AC-6.4, AC-7.1 to AC-7.4. **Files:** `spec/system/resume_game_spec.rb`, `docs/specs/028-resume-game/screens/*.png`. **Interfaces:** none.

Test first. The spec is the deliverable. The cards, the line and the link already exist, so it is seen failing by breaking one thing at a time in a scratch edit (the card's `href`, then the line, then the host-link redirect) and reverting each before the commit:

```ruby
require "rails_helper"

# Spec 028 Stories 6 and 7: leaving and resuming in real browsers, at 360 pixels. SCREENSHOTS=<dir> also writes the screenshots of AC-6.4.
RSpec.describe "Resuming a game", type: :system do
  around do |example|
    original = ENV["TRUCEBEARER_PASSPHRASE"]
    ENV["TRUCEBEARER_PASSPHRASE"] = "open sesame"
    example.run
  ensure
    ENV["TRUCEBEARER_PASSPHRASE"] = original
  end

  def screenshot(name)
    dir = ENV["SCREENSHOTS"]
    page.save_screenshot(File.join(dir, "#{name}.png")) if dir
  end

  # What a real browser does when it restarts: cookies with no expiry (Rails' session cookie, a step-in) go; the persistent ones stay.
  def end_browser_session
    manager = page.driver.browser.manage
    manager.all_cookies.select { |cookie| cookie[:expires].nil? }.each { |cookie| manager.delete_cookie(cookie[:name]) }
  end

  def no_sideways_scroll
    widths = evaluate_script("({ scroll: document.documentElement.scrollWidth, client: document.documentElement.clientWidth })")
    expect(widths["scroll"]).to be <= widths["client"]
  end

  def cards_at_least_44
    small = evaluate_script(<<~JS)
      Array.from(document.querySelectorAll("a.game-card")).filter((el) => {
        const r = el.getBoundingClientRect(); return r.height < 43.5 || r.width < 43.5;
      }).length
    JS
    expect(small).to eq(0)
  end

  def create_game_and_join_as_france
    visit "/games/new"
    fill_in "Passphrase", with: "open sesame"
    click_button "England"
    host_link = find("#host-link").value
    join_code = find(".join-code").text.delete(" ")
    using_session(:player) do
      visit "/join"
      fill_in "Game code", with: join_code
      click_button "Join"
      click_button "France"
      expect(page).to have_css("h1", text: "You hold France")
    end
    [ host_link, join_code ]
  end

  it "brings a player back to the current phase after the browser was closed (AC-7.1, AC-7.2)" do
    host_link = nil
    with_viewport(360) { host_link, = create_game_and_join_as_france }
    game = Game.order(:id).last
    first_title = game.current_phase.title

    using_session(:player) do
      with_viewport(360) do
        end_browser_session
        visit "/"
        expect(page).to have_css("a.game-card", count: 1)
        expect(page).to have_css("a.game-card", text: first_title)
        no_sideways_scroll
        cards_at_least_44
        click_link(class: "game-card")
        expect(page).to have_css("h1", text: "You hold France")
      end
    end

    game.current_phase.reveal!

    using_session(:player) do
      with_viewport(360) do
        end_browser_session
        visit "/"
        expect(page).to have_css("a.game-card", text: game.reload.current_phase.title)
        click_link(class: "game-card")
        expect(page).to have_css("h1", text: "You hold France")
        expect(page).to have_text(game.current_phase.title)
      end
    end
  end

  it "opens the host link in a fresh browser, and the host can take the seat back by reissuing it (AC-7.3)" do
    host_link = nil
    with_viewport(360) { host_link, = create_game_and_join_as_france }
    id = Game.order(:id).last.public_id

    using_session(:spare) do
      with_viewport(360) do
        visit host_link
        expect(page).to have_link("Reveal orders")
        visit "/"
        expect(page).to have_css("a.game-card[href='/games/#{id}/host']", text: "You host this game")

        visit "/games/#{id}/host"
        find("a[href$='/host/seats/england/reissue']").click
        click_button "Reissue seat"
        seat_link = find(".qr-card__link").text
        visit seat_link
        expect(page).to have_css("h1", text: "You hold England")
        expect(page).to have_link("Host controls")
        visit "/"
        expect(page).to have_css("a.game-card[href='/games/#{id}']")
      end
    end
  end

  it "tells a player whose cookie is gone what to do, and the reissued seat brings them back (AC-7.4)" do
    with_viewport(360) { create_game_and_join_as_france }
    id = Game.order(:id).last.public_id
    seat_link = nil

    using_session(:lost) do
      with_viewport(360) do
        visit "/"
        expect(page).to have_no_css("a.game-card")
        expect(page).to have_text("Lost your seat? Ask the host for a new QR code.")
        no_sideways_scroll
      end
    end

    with_viewport(360) do
      visit "/games/#{id}/host"
      find("a[href$='/host/seats/france/reissue']").click
      click_button "Reissue seat"
      seat_link = find(".qr-card__link").text
    end

    using_session(:lost) do
      with_viewport(360) do
        visit seat_link
        expect(page).to have_css("h1", text: "You hold France")
        visit "/"
        expect(page).to have_css("a.game-card[href='/games/#{id}']")
      end
    end
  end

  it "draws three cards, the empty home page and the stranger page at 360 pixels (AC-6.1 to AC-6.4)" do
    seat_game = Game.start!(power: "england")
    france, france_token = seat_game.game.take_seat!("france")
    host_with_seat = Game.start!(power: "germany")
    host_only = Game.start!(power: "russia")
    expect(france).to be_present

    with_viewport(360) do
      visit "/"
      expect(page).to have_no_css("a.game-card")
      expect(page).to have_text("Lost your seat? Ask the host for a new QR code.")
      no_sideways_scroll
      screenshot("01-home-empty")

      visit "/games/#{seat_game.game.public_id}/seat-link?token=#{france_token}"
      visit "/games/#{host_with_seat.game.public_id}/host-link?token=#{host_with_seat.host_token}"
      visit "/games/#{host_with_seat.game.public_id}/seat-link?token=#{host_with_seat.seat_token}"
      visit "/games/#{host_only.game.public_id}/host-link?token=#{host_only.host_token}"
      visit "/"

      expect(page).to have_css("a.game-card", count: 3)
      no_sideways_scroll
      cards_at_least_44
      overlap = evaluate_script("Array.from(document.querySelectorAll('.game-card .phase-header')).filter((h) => { const b = h.querySelector('.power-badge'); return b && b.getBoundingClientRect().left < h.querySelector('.phase-header__title').getBoundingClientRect().right - 0.5; }).length")
      expect(overlap).to eq(0)
      below = evaluate_script("document.querySelector('a.button').getBoundingClientRect().top >= Array.from(document.querySelectorAll('a.game-card')).pop().getBoundingClientRect().bottom")
      expect(below).to be(true)
      screenshot("02-home-three-cards")

      visit "/games/zzzzzzzzzzzz"
      expect(page).to have_text("Lost your seat? Ask the host for a new QR code.")
      no_sideways_scroll
      screenshot("03-stranger")
    end
  end
end
```

**Verify:** `bundle exec rspec spec/system/resume_game_spec.rb` passes; then `mkdir -p docs/specs/028-resume-game/screens && SCREENSHOTS=$PWD/docs/specs/028-resume-game/screens bundle exec rspec spec/system/resume_game_spec.rb` writes `01-home-empty.png`, `02-home-three-cards.png` and `03-stranger.png`. The screenshots are looked at, not assumed. Commit "Cover leaving and resuming a game in real browsers, with screenshots".

## Phase 8: The documents and the whole proof

**Implements:** D10. **Satisfies:** AC-8.4 to AC-8.6. **Files:** `docs/specs/021-create-game-join-qr/spec.md`, `docs/specs/022-phase-lifecycle/spec.md`, `README.md`, `spec/docs/spec_amendments_spec.rb`, `docs/specs/028-resume-game/spec.md`.

Test first, in `spec/docs/spec_amendments_spec.rb`:

```ruby
  # The row that mentions spec 028, its version, and the spec's version line, which a later amendment may have moved on.
  def resume_row(path)
    spec = File.read(File.expand_path("../../docs/specs/#{path}/spec.md", __dir__))
    row = spec.lines.find { |line| line.start_with?("| ") && line.include?("spec 028") }
    expect(row).not_to be_nil
    version = row[/\A\| (\d+\.\d+\.\d+) \|/, 1]
    expect(Gem::Version.new(spec[/\*\*Version:\*\* (\d+\.\d+\.\d+)/, 1])).to be >= Gem::Version.new(version)
    [ spec, row ]
  end

  it "records spec 028's changes to spec 021 in its changelog (spec 028 AC-8.5)" do
    _, row = resume_row("021-create-game-join-qr")

    expect(row).to include("AC-2.1").and include("home page").and include("stranger page")
  end

  it "records spec 028's change to spec 022's route table in its changelog (spec 028 AC-8.6)" do
    spec, row = resume_row("022-phase-lifecycle")

    expect(row).to include("FR-9").and include("GET /")
    expect(spec).to include("Lists the games the request's cookies verify for")
    expect(spec).not_to include("`GET /up`, `GET /`, `GET /styleguide` | No. Static, no game data")
  end

  it "has a README section for coming back to a game (spec 028 AC-8.4)" do
    readme = File.read(File.expand_path("../../README.md", __dir__))
    section = readme[/## Coming back to a game.*?(?=\n## |\z)/m].to_s

    expect(section).to include("signed").and include("reissu").and include("TRUCEBEARER_TIME_ZONE")
  end
```

Then the edits. Spec 021: version `1.4.0` to `1.5.0`, `Last Updated` unchanged (same day), a changelog row above 1.4.0:

```
| 1.5.0 | 2026-11-26 | Amended by spec 028 (resuming a game, #28).<br>• **AC-2.1:** the redirect after a verified host link goes to the seat page when the browser holds the host's own seat, and to the host page otherwise (spec 028 D5).<br>• The URL table's `/` row: after its existing text it lists the games the browser's cookies verify for, then the two buttons, then the lost-seat line (spec 028 D1, D6).<br>• The stranger page also holds the line "Lost your seat? Ask the host for a new QR code." It is part of the one answer every request gets (D4, AC-5.5 still hold). |
```

and AC-2.1's text gets "(and, since spec 028, to `/games/<id>` when the browser holds the host's own seat)" after "redirects to `/games/<id>/host`"; the `/` row of the URL table reads "The home page: its existing text, the games this browser's cookies verify for, then two buttons: \"Create a game\" and \"Join a game\"" . Spec 022: version `1.7.0` to `1.8.0`, a row above 1.7.0:

```
| 1.8.0 | 2026-11-26 | Amended by spec 028 (resuming a game, #28). **FR-9:** the route table's row for `GET /` no longer says "no game data": it lists the games the request's cookies verify for, each as a start date, an open phase's title and the viewer's power, and never an order, a count or a submitted state. The sweep and `spec/requests/resume_secrecy_spec.rb` prove it. |
```

and that table row becomes two rows: `` `GET /up`, `GET /styleguide` `` "No. Static, no game data", and `` `GET /` `` "No order. Lists the games the request's cookies verify for (spec 028)". If either spec has moved on by the time this phase runs, the row takes the next free minor and the amendment spec's regexes still match, because they read the row by text. `README.md` gets, after "The position editor":

```
## Coming back to a game

Open the home page on the phone that played before. It lists the games that phone belongs to as cards (the date the game started, the open phase, and your power), and each card opens that game's current phase. The page reads only the signed `host_` and `seat_` cookies that verify, makes no card for any other, and sets or removes no cookie. A host who opens the host link on a phone that holds the host's own seat lands on that seat; on a phone with no seat the link lands on the host page, and the host takes the seat back by reissuing it, which clears that seat's saved orders for the open phase. A player whose cookie is gone asks the host for a new QR code. The card's date is shown in the zone `TRUCEBEARER_TIME_ZONE` names (UTC when unset).
```

Spec 028 itself: the changelog gets a row 1.0.4 "Implemented", only if the work deviated; otherwise unchanged.

**Whole proof (run, with the output read, before the pull request):**

```
bundle exec rspec
bin/brakeman -q --no-pager
bin/rubocop
git diff --name-only main...HEAD
```

Expected: rspec passes with 0 failures (system specs included); Brakeman 0 warnings; RuboCop 0 offenses; the diff lists only `web/` paths. Commit "Amend specs 021 and 022 and write the README section for resuming a game".

## Spec coverage

| Spec | Phase |
|---|---|
| FR-1 | 2, 3 |
| FR-2 | 2, 6 |
| FR-3 | 4 |
| FR-4 | 5 |
| Story 1 (AC-1.1 to 1.6) | 1, 2 |
| Story 2 (AC-2.1 to 2.5) | 2 |
| Story 3 (AC-3.1 to 3.12) | 3 |
| Story 4 (AC-4.1 to 4.4) | 4, 7 |
| Story 5 (AC-5.1 to 5.4) | 5 |
| Story 6 (AC-6.1 to 6.4) | 7 |
| Story 7 (AC-7.1 to 7.4) | 7 |
| Story 8 (AC-8.1 to 8.6) | 6, 8 |
| D1 to D10 | 2 (D1 to D4, D7), 3 (D8), 4 (D6), 5 (D5), 6 (D9), 8 (D10) |

## Known limits and follow-ups

- #120: the host page's "Your own seat" link leads a browser with no seat to the stranger page. Not touched here.
- #121: an optional game name at creation (D4).

# Plan 021: Create a game and join it by QR code

**Spec:** `web/docs/specs/021-create-game-join-qr/spec.md` v1.2.1 (Approved at Gate A)
**Issue:** #21 · **Branch:** `web/21-create-game-join-qr` · **Plan version:** 1.2.0 (after the second Opus review; see the tables at the end)

## Goal

Build games and seats as the spec says: create with the instance passphrase, a host link and host cookie, a QR code and a six-character code, joining by code or QR with a power picked, closing joining, reissuing a seat, rate limits, and the four components on `/styleguide`. All work is under `web/`. Every phase is test first (RSpec), ends with its own specs green, and is one commit. Commit messages are plain imperative sentences ending with `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`.

## Decisions the plan adds (each is traceable to the spec)

- **Names.** Models `Game`, `Seat`; plain modules `Token`, `JoinCode`, `Passphrase`. Controllers: `GamesController` (new, create, show), `HostsController` (show), `HostLinksController`, `SeatLinksController`, `ClosingsController`, `ReissuesController` (show, create, qr), `JoinsController` (index, create, show), `JoinSeatsController` (create), The stranger page and the 429 page are templates (`strangers/show`, `strangers/too_many`) rendered by the concern, not controllers.
- **One concern, `GameAccess`**, holds cookie writing, cookie verification, the stranger response and the rate-limit helpers. It is included by every controller above. It is not a service object (Anti-Abstraction Gate: three small modules, one concern, two models).
- **No uniqueness validation on `Seat`.** The unique index is the only arbiter of "taken" (FR-7). A POST never trusts the page it came from, so two posts in sequence are the same case as two at once (AC-4.6).
- **Route names.** The join page's route is `join_game` (`join_game_url(code)`), so it cannot be confused with the `join_code_text` helper.
- **Screenshots** for the pull request are made by a throwaway spec kept in the scratchpad, not committed. The PNGs are committed under `web/docs/specs/021-create-game-join-qr/screens/` so the PR body can link them (they are docs: CC BY-SA 4.0 under the root licence map).

## Gates checked

- **Simplicity:** two models, three plain modules, one concern, nine small controllers, six helper methods, one gem.
- **Anti-abstraction:** no service objects, no policy classes, no base controller for hosts: `require_host` is a method of the concern.
- **Integration-first:** Phase 1 writes the request spec the brief names first and drives it green with real routes and a real database.

## Phase 1: The first request spec, the tables, tokens, codes and creating a game

**Implements:** FR-2 (tokens, cookies), FR-3 (code), FR-5 (passphrase), FR-9 (tables), FR-12 (`RulesEngine.powers`, test cache store, cache-clear hook, log filter).
**Satisfies:** AC-1.1 to AC-1.7, AC-3.4 to AC-3.7, AC-2.4, AC-8.1, AC-11.2 (host and seat cookies), AC-11.3.
**Files:**
- Create `spec/requests/games_spec.rb` (the first test), `spec/models/token_spec.rb`, `spec/models/join_code_spec.rb`, `spec/models/game_spec.rb`, `spec/models/seat_spec.rb`, `spec/models/passphrase_spec.rb`, `spec/config/cache_store_spec.rb`.
- Create `db/migrate/<ts>_create_games_and_seats.rb` (and `db/schema.rb`, which the migration writes), `app/models/{token,join_code,passphrase,game,seat}.rb`, `app/controllers/concerns/game_access.rb`, `app/controllers/games_controller.rb`, `app/views/games/{new,turned_off}.html.erb`, `app/views/strangers/{show,too_many}.html.erb`, `app/helpers/power_tiles_helper.rb`, `spec/support/responses.rb`.
- Change `config/routes.rb`, `config/environments/test.rb`, `config/initializers/filter_parameter_logging.rb`, `spec/rails_helper.rb` (also requires `support/responses`), `app/models/rules_engine.rb`, `spec/models/rules_engine_spec.rb`, `app/controllers/application_controller.rb`.

### 1a. Write the first test (red)

First `spec/support/responses.rb`, loaded from `spec/rails_helper.rb` with `require_relative "support/responses"` (the rails_helper does not load `spec/support` by itself). Rack 3 hands several cookies back as an Array of lines with lower-case attribute names, so every cookie check goes through these helpers and matches attributes without regard to case:

```ruby
# Request-spec helpers for reading cookies and for comparing two responses (spec 021, ACs 5.x).
module ResponseHelpers
  def cookie_lines(response) = Array(response.headers["Set-Cookie"]).flat_map { |header| header.to_s.split("\n") }

  def cookie_line(response, name) = cookie_lines(response).find { |line| line.start_with?("#{name}=") }

  # What the stranger ACs compare: status, body, four headers, and the host_ and seat_ cookie lines. The game id in a
  # cookie name is replaced by ID, and the session cookie is left out (its value differs on every response).
  def comparable(response, id)
    cookies = cookie_lines(response).grep(/\A(?:host|seat)_/).map { |line| line.sub(id, "ID").sub(/=[^;]*/, "=VALUE") }.sort
    headers = %w[Content-Type Cache-Control Referrer-Policy].map { |name| response.headers[name] }
    [ response.status, response.body.gsub(/\s+/, " "), headers, cookies ]
  end
end

RSpec.configure { |config| config.include ResponseHelpers, type: :request }
```

(`comparable` keeps the cookie's attributes after `=VALUE`, so a deletion (`expires=Thu, 01 Jan 1970`) and a set differ, as they should.)

`spec/requests/games_spec.rb`. Before any code exists it fails with `NameError: uninitialized constant Game` from its `change` blocks (a missing route alone would answer 404, not raise). Both examples are red for that reason, and green only when the whole of Phase 1 is in.

```ruby
require "rails_helper"

RSpec.describe "Creating a game", type: :request do
  around do |example|
    original = ENV["TRUCEBEARER_PASSPHRASE"]
    ENV["TRUCEBEARER_PASSPHRASE"] = "open sesame"
    example.run
  ensure
    ENV["TRUCEBEARER_PASSPHRASE"] = original
  end

  it "refuses a wrong passphrase and creates no game (AC-1.3)" do
    expect { post "/games", params: { passphrase: "wrong", power: "england" } }.not_to change { [ Game.count, Seat.count ] }

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("That passphrase isn&#39;t right.")
    expect(cookie_lines(response).grep(/\A(?:host|seat)_/)).to be_empty
  end

  it "creates a game and sets the host cookie with the right passphrase (AC-1.2)" do
    expect { post "/games", params: { passphrase: "open sesame", power: "england" } }
      .to change(Game, :count).by(1).and change(Seat, :count).by(1)

    game = Game.last
    expect(response).to redirect_to("/games/#{game.public_id}/host")
    expect(cookie_line(response, "host_#{game.public_id}")).to be_present
    expect(cookie_line(response, "seat_#{game.public_id}")).to be_present
  end
end
```

Run `bundle exec rspec spec/requests/games_spec.rb` and watch it fail with the `NameError` for `Game` (1a above). Commit the failing spec on its own ("Add the failing request spec for creating a game").

### 1b. Plain-Ruby units (red, then green)

`app/models/token.rb`:

```ruby
# Random tokens and their digests (spec D2). A token is 24 bytes from SecureRandom, 192 bits.
# Only the SHA-256 digest is ever stored. Both sides of a comparison are digests, so they have one
# length and secure_compare does not leak one.
module Token
  BYTES = 24

  def self.generate = SecureRandom.urlsafe_base64(BYTES)

  def self.digest(value) = OpenSSL::Digest::SHA256.hexdigest(value.to_s)

  def self.match?(token, stored_digest)
    ActiveSupport::SecurityUtils.secure_compare(digest(token), stored_digest.to_s)
  end
end
```

`app/models/join_code.rb`:

```ruby
# The six-character code (spec FR-3). 22 characters with no look-alikes: none of 0 O Q 1 I L 2 Z 5 S 8 B U V.
module JoinCode
  ALPHABET = %w[A C D E F G H J K M N P R T W X Y 3 4 6 7 9].freeze
  LENGTH = 6
  SHAPE = /\A[#{ALPHABET.join}]{#{LENGTH}}\z/

  def self.generate = Array.new(LENGTH) { ALPHABET[SecureRandom.random_number(ALPHABET.size)] }.join

  # Upper-cased, spaces and hyphens removed. Nothing is converted into another character.
  # Returns nil for anything that is not a code.
  def self.normalize(input)
    code = input.to_s.upcase.delete(" \t-")
    code if code.match?(SHAPE)
  end

  def self.groups(code) = [ code[0, 3], code[3, 3] ]
end
```

`app/models/passphrase.rb`:

```ruby
# The instance passphrase (spec FR-5, D3). It lives in the environment, never on screen.
module Passphrase
  ENV_NAME = "TRUCEBEARER_PASSPHRASE"

  def self.expected = ENV[ENV_NAME].to_s

  def self.configured? = expected.present?

  # Both sides are digested first, so the time does not depend on the guess's length or how much of it is right.
  # A missing guess is the digest of an empty string and goes through the same comparison.
  def self.correct?(guess)
    ActiveSupport::SecurityUtils.secure_compare(Token.digest(guess), Token.digest(expected))
  end
end
```

`app/models/rules_engine.rb` gains one reader, inside `class << self`, beside `starting_position`:

```ruby
    # The map's powers, each with an id (a symbol) and a name. The one place a power list comes from (spec 021 FR-12).
    def powers = TA::Map.classic.powers
```

`spec/models/rules_engine_spec.rb` gains: `RulesEngine.powers.map(&:id)` equals the seven symbols; each `name` is the capitalized id; and `PowerBadgeHelper::POWER_NAMES == RulesEngine.powers.to_h { |p| [p.id.to_s, p.name] }` (the drift guard).

Specs (each written before its module, shown red first; each file starts with `require "rails_helper"`):

```ruby
# spec/models/token_spec.rb
RSpec.describe Token do
  it "makes 24 random bytes as 32 URL-safe characters, never the same twice" do
    tokens = Array.new(50) { Token.generate }
    expect(tokens.uniq.size).to eq(50)
    expect(tokens).to all(match(/\A[A-Za-z0-9_-]{32}\z/))
  end

  it "digests to 64 hex characters and matches only its own token" do
    token = Token.generate
    digest = Token.digest(token)
    expect(digest).to match(/\A\h{64}\z/)
    expect(Token.match?(token, digest)).to be(true)
    expect(Token.match?(Token.generate, digest)).to be(false)
    expect(Token.match?(nil, digest)).to be(false)
    expect(Token.match?(token, nil)).to be(false)
  end

  it "compares with secure_compare on two digests" do
    allow(ActiveSupport::SecurityUtils).to receive(:secure_compare).and_call_original
    Token.match?("a", Token.digest("b"))
    expect(ActiveSupport::SecurityUtils).to have_received(:secure_compare).with(Token.digest("a"), Token.digest("b"))
  end
end

# spec/models/join_code_spec.rb  (AC-3.4, 3.5, 4.2)
RSpec.describe JoinCode do
  it "has 22 characters and none of the look-alikes" do
    expect(JoinCode::ALPHABET.size).to eq(22)
    expect(JoinCode::ALPHABET & %w[0 O Q 1 I L 2 Z 5 S 8 B U V]).to be_empty
  end

  it "makes six-character codes from the alphabet" do
    codes = Array.new(1000) { JoinCode.generate }
    expect(codes).to all(match(JoinCode::SHAPE))
  end

  it "takes every character from SecureRandom" do
    allow(SecureRandom).to receive(:random_number).with(22).and_return(0)
    expect(JoinCode.generate).to eq("AAAAAA")
  end

  it "reads a typed code forgivingly and never converts one character into another" do
    expect(JoinCode.normalize(" abc-def ")).to eq("ABCDEF")
    expect(JoinCode.normalize("abc def")).to eq("ABCDEF")
    expect(JoinCode.normalize("ABCDE0")).to be_nil   # zero is not in the alphabet, and is not turned into O
    expect(JoinCode.normalize("ABCDE")).to be_nil
    expect(JoinCode.normalize("ABCDEFG")).to be_nil
    expect(JoinCode.normalize("AB.DEF")).to be_nil
    expect(JoinCode.normalize(nil)).to be_nil
  end
end

# spec/models/passphrase_spec.rb  (AC-1.7, 1.6)
RSpec.describe Passphrase do
  around do |example|
    original = ENV[Passphrase::ENV_NAME]
    example.run
  ensure
    ENV[Passphrase::ENV_NAME] = original
  end

  it "is not configured when unset or blank" do
    ENV[Passphrase::ENV_NAME] = nil
    expect(Passphrase.configured?).to be(false)
    ENV[Passphrase::ENV_NAME] = "  "
    expect(Passphrase.configured?).to be(false)
  end

  it "compares digests with secure_compare, a missing guess included" do
    ENV[Passphrase::ENV_NAME] = "open sesame"
    allow(ActiveSupport::SecurityUtils).to receive(:secure_compare).and_call_original
    expect(Passphrase.correct?(nil)).to be(false)
    expect(ActiveSupport::SecurityUtils).to have_received(:secure_compare).with(Token.digest(""), Token.digest("open sesame"))
    expect(Passphrase.correct?("open sesame")).to be(true)
    expect(Passphrase.correct?("Open sesame")).to be(false)
    expect(Passphrase.correct?("open sesame ")).to be(false)
  end
end
```

### 1c. The tables

`db/migrate/<timestamp>_create_games_and_seats.rb` (made with `bin/rails g migration CreateGamesAndSeats`, then written out):

```ruby
class CreateGamesAndSeats < ActiveRecord::Migration[8.1]
  def change
    create_table :games do |t|
      t.string :public_id, null: false
      t.string :host_token_digest, null: false
      t.string :join_code, null: false, limit: 6
      t.datetime :joining_closed_at
      t.timestamps
    end
    add_index :games, :public_id, unique: true
    add_index :games, :host_token_digest, unique: true
    # Unique only while joining is open: a closed game frees its code (spec FR-3).
    add_index :games, :join_code, unique: true, where: "joining_closed_at IS NULL", name: "index_games_on_join_code_while_open"

    create_table :seats do |t|
      t.references :game, null: false, foreign_key: true, index: false
      t.string :power, null: false
      t.string :token_digest, null: false
      t.timestamps
    end
    add_index :seats, [ :game_id, :power ], unique: true
    add_index :seats, :token_digest, unique: true
  end
end
```

`app/models/seat.rb`:

```ruby
# One power held by one phone. The token is never kept, only its digest (spec D2).
class Seat < ApplicationRecord
  belongs_to :game

  # Uniqueness is the database's job: the index on [game_id, power] is the only arbiter of "taken".
  validates :power, inclusion: { in: ->(_seat) { RulesEngine.powers.map { |power| power.id.to_s } } }
end
```

`app/models/game.rb`:

```ruby
class Game < ApplicationRecord
  has_many :seats, dependent: :destroy

  class SeatTaken < StandardError; end
  class NotOpen < StandardError; end

  Started = Data.define(:game, :host_token, :seat_token)

  CODE_TRIES = 5

  # Makes a game and the host's seat in one step. A clash on the join code (or the public id) is retried (spec FR-3).
  def self.start!(power:)
    tries = 0
    begin
      transaction(requires_new: true) do
        host_token = Token.generate
        seat_token = Token.generate
        game = create!(public_id: SecureRandom.alphanumeric(12), host_token_digest: Token.digest(host_token),
                       join_code: JoinCode.generate)
        game.seats.create!(power: power, token_digest: Token.digest(seat_token))
        Started.new(game: game, host_token: host_token, seat_token: seat_token)
      end
    rescue ActiveRecord::RecordNotUnique
      tries += 1
      retry if tries < CODE_TRIES
      raise
    end
  end

  # The one open game that holds this code, or nil. Unknown, closed and malformed codes are all nil (spec D4).
  def self.open_by_code(input)
    code = JoinCode.normalize(input)
    code && where(joining_closed_at: nil).find_by(join_code: code)
  end

  def open? = joining_closed_at.nil?

  def close_joining!
    update!(joining_closed_at: Time.current) if open?
  end

  def host_token?(token) = Token.match?(token, host_token_digest)

  # Compares against every seat (seven at most) and never looks one up by digest (spec FR-2).
  def seat_for(token)
    seats.to_a.select { |seat| Token.match?(token, seat.token_digest) }.first
  end

  # Takes a power for a new phone. Returns [seat, token]. Joining is checked inside the transaction (spec FR-7).
  def take_seat!(power)
    token = Token.generate
    seat = transaction do
      raise NotOpen unless Game.where(id: id, joining_closed_at: nil).exists?

      seats.create!(power: power, token_digest: Token.digest(token))
    end
    [ seat, token ]
  rescue ActiveRecord::RecordNotUnique
    raise SeatTaken
  end

  # Replaces the seat's digest. The old token stops working with this write. Returns the new token.
  def reissue_seat!(seat)
    token = Token.generate
    seat.update!(token_digest: Token.digest(token))
    token
  end
end
```

`spec/models/game_spec.rb` (red first) covers: `start!` creates one game and one seat for that power, the stored digests are not the tokens (no column of either table contains either token: `[Game, Seat].flat_map { |m| m.pluck(*m.column_names) }.flatten.map(&:to_s)` excludes both tokens; AC-2.4, 4.4); the join code retry (`allow(JoinCode).to receive(:generate).and_return("ACDEFG", "ACDEFG", "HJKMNP")` makes the second game's code `HJKMNP`; AC-3.6); a closed game frees its code (close the first, then `allow(JoinCode).to receive(:generate).and_return("ACDEFG")` and `start!` succeeds with the same code; AC-3.7); the partial index refuses two open games with one code (`expect { Game.create!(public_id: "zzzzzzzzzzzz", host_token_digest: "d", join_code: first.join_code) }.to raise_error(ActiveRecord::RecordNotUnique)`); after five clashes `start!` raises `RecordNotUnique`; `open_by_code` returns the open game for `"acd-efg"` and nil for an unknown, closed and malformed code; `take_seat!` creates a seat and returns a token that `seat_for` finds, raises `SeatTaken` for a power already held (the race case: the second insert runs after the first) and `NotOpen` after `close_joining!`; `reissue_seat!` makes the old token fail `seat_for` and the new one pass; `close_joining!` twice leaves the first time. `spec/models/seat_spec.rb`: an unknown power (`"narnia"`) is invalid; the seven ids are valid.

### 1d. The concern, the controller, the page, the config

`app/controllers/concerns/game_access.rb` (the helpers every later phase uses):

```ruby
# Cookies, verification, the stranger response and the rate-limit helpers for every game page (spec FR-2, FR-6, FR-8).
module GameAccess
  extend ActiveSupport::Concern

  KINDS = %i[host seat].freeze
  TOO_MANY = "Too many tries. Wait a few minutes and try again."

  private

  def cookie_name(kind, public_id) = "#{kind}_#{public_id}"

  # Signed, permanent, httponly and lax. Secure when force_ssl is on, which production sets (spec FR-2, AC-11.4).
  def remember(kind, game, token)
    cookies.signed.permanent[cookie_name(kind, game.public_id)] =
      { value: token, httponly: true, same_site: :lax, secure: Rails.configuration.force_ssl ? true : false }
  end

  def find_game = Game.find_by(public_id: params[:public_id])

  def host?(game)
    token = cookies.signed[cookie_name(:host, game.public_id)]
    token.present? && game.host_token?(token)
  end

  def seat_of(game)
    token = cookies.signed[cookie_name(:seat, game.public_id)]
    token.present? ? game.seat_for(token) : nil
  end

  # The one answer for every request that has no right to a page (spec D4, FR-6). A presented cookie is deleted only
  # when it fails verification for that id; an unknown game counts as a failure. A cookie that verifies is kept.
  PUBLIC_ID_SHAPE = /\A[A-Za-z0-9]{12}\z/

  def stranger!(game = nil)
    public_id = params[:public_id].to_s
    KINDS.each do |kind|
      # A path id that is not a public id never names a cookie of ours, and Rack refuses odd cookie names.
      next unless public_id.match?(PUBLIC_ID_SHAPE)

      name = cookie_name(kind, public_id)
      next if cookies[name].nil?

      valid = game && (kind == :host ? host?(game) : seat_of(game))
      cookies.delete(name) unless valid
    end
    render "strangers/show", status: :not_found
  end

  def require_host
    @game = find_game
    stranger!(@game) unless @game && host?(@game)
  end

  def too_many_tries = render("strangers/too_many", status: :too_many_requests)

  # IPv4 by address, IPv6 by its first 64 bits (spec FR-8).
  def client_key
    address = IPAddr.new(request.remote_ip)
    address.ipv6? ? address.mask(64).to_s : address.to_s
  rescue IPAddr::InvalidAddressError
    request.remote_ip.to_s
  end
end
```

`app/controllers/application_controller.rb`: add `include GameAccess` under the existing lines.

`app/controllers/games_controller.rb` (create and new now; `show` in Phase 2):

```ruby
class GamesController < ApplicationController
  rate_limit to: 10, within: 5.minutes, scope: :games_create, by: -> { client_key }, with: -> { too_many_tries }, only: :create
  before_action :require_passphrase_set, only: %i[new create]

  def new; end

  def create
    # The comparison always runs, so a missing guess takes the same path (spec AC-1.7).
    return form_error("That passphrase isn't right.") unless Passphrase.correct?(params[:passphrase])

    power = RulesEngine.powers.find { |candidate| candidate.id.to_s == params[:power].to_s }
    return form_error("Pick one of the seven powers.") unless power

    started = Game.start!(power: power.id.to_s)
    remember(:host, started.game, started.host_token)
    remember(:seat, started.game, started.seat_token)
    flash[:host_token] = started.host_token
    redirect_to game_host_path(started.game.public_id)
  end

  private

  def require_passphrase_set
    return if Passphrase.configured?

    Rails.logger.warn("#{Passphrase::ENV_NAME} is not set: creating games is refused")
    render "games/turned_off", status: :forbidden
  end

  def form_error(message)
    @error = message
    render :new, status: :unprocessable_content
  end
end
```

Views: `games/new.html.erb` (title "Create a game", one `h1`, an error paragraph with `role="alert"` when `@error`, `form_with url: games_path` holding a `.field` whose `label` reads "Passphrase" and whose input is `type="text"`, `name="passphrase"`, `autocomplete="off"`, `autocapitalize="off"` and has no `value`, so a wrong guess is never echoed back (spec FR-5); then `<%= power_tiles %>` inside the form); `games/turned_off.html.erb` (an `h1` that is the sentence "Creating games is turned off on this instance. Ask whoever runs it." and a link home with `class="button button--secondary"`); `strangers/show.html.erb` (`<h1>We can't find that page.</h1>` and a link home with `class="button button--secondary"`); `strangers/too_many.html.erb` (one `h1` that is the sentence "Too many tries. Wait a few minutes and try again." and nothing else in `main`, so the sentence is the only text besides the page's header, AC-8.8).

`app/helpers/power_tiles_helper.rb`:

```ruby
module PowerTilesHelper
  # Seven tiles. An open tile is a submit button named power, a taken tile is a plain div that says "Taken".
  # Each shows the power's badge, so its name is always text (spec AC-9.3). Names come through RulesEngine.
  def power_tiles(taken: [])
    items = RulesEngine.powers.map do |power|
      id = power.id.to_s
      if taken.include?(id)
        tag.li(tag.div(safe_join([ power_badge(id), tag.span("Taken") ]), class: "power-tile power-tile--taken"))
      else
        tag.li(tag.button(power_badge(id), type: "submit", name: "power", value: id, class: "power-tile"))
      end
    end
    tag.ul(safe_join(items), class: "power-tiles")
  end

  # A power's name as the rules engine reports it (spec FR-7).
  def power_name(id) = RulesEngine.powers.find { |power| power.id.to_s == id.to_s }&.name
end
```

Routes (`config/routes.rb`), above `root`, with the two segment rules from the spec's URL table:

```ruby
  get "games/new", to: "games#new", as: :new_game
  post "games", to: "games#create"

  scope "games/:public_id", constraints: { public_id: %r{[^/]+} }, format: false do
    get "/", to: "games#show", as: :game
    get "host", to: "hosts#show", as: :game_host
    get "host-link", to: "host_links#show", as: :game_host_link
    get "seat-link", to: "seat_links#show", as: :game_seat_link
    get "host/close", to: "closings#show", as: :game_close
    post "host/close", to: "closings#create"
    get "host/seats/:power/reissue", to: "reissues#show", as: :game_reissue
    post "host/seats/:power/reissue", to: "reissues#create"
    get "host/seats/:power/qr", to: "reissues#qr", as: :game_seat_qr
  end

  get "join", to: "joins#index", as: :join
  post "join", to: "joins#create"
  get "join/:code", to: "joins#show", as: :join_game, constraints: { code: %r{[^/]+} }, format: false
  post "join/:code/seat", to: "join_seats#create", as: :join_seat, constraints: { code: %r{[^/]+} }, format: false
```

(The controllers other than `GamesController` arrive in Phases 2 to 4. `rails routes` is checked after each phase.)

Config:
- `config/environments/test.rb`: replace `config.cache_store = :null_store` with `config.cache_store = :memory_store` and a comment saying `rate_limit` does nothing on the null store.
- `spec/rails_helper.rb`: inside `RSpec.configure`, `config.include ActiveSupport::Testing::TimeHelpers, type: :request` and
  ```ruby
  # One process and one address serve the whole suite, so every request and system example starts with empty rate-limit buckets.
  config.before(:each, type: :request) { Rails.cache.clear }
  config.before(:each, type: :system) { Rails.cache.clear }
  ```
- `config/initializers/filter_parameter_logging.rb`: add `:passphrase` to the list (`:passw` does not match it). The join code lives in the path and is not secret enough to filter, so only `:passphrase` is added. A spec reads `Rails.application.config.filter_parameters` and filters `{ passphrase: "x", token: "y" }` to `[FILTERED]` both (`ActiveSupport::ParameterFilter`).
- `spec/config/cache_store_spec.rb` (AC-8.1): `expect(Rails.cache).not_to be_a(ActiveSupport::Cache::NullStore)`, and `expect(ActionController::Base.cache_store).not_to be_a(ActiveSupport::Cache::NullStore)` (the store `rate_limit` binds at class load).

### 1e. More request examples in `games_spec.rb` (red first, then green)

Written before the controller code in 1d, in the same file as 1a: AC-1.1 (`GET /games/new` shows a passphrase field and seven `button.power-tile` with the seven names, no game exists); AC-1.4 (a table of guesses: `""`, missing, one short `"open sesam"`, one long `"open sesamee"`, a case change `"Open sesame"` each give 422, the same message, and a body equal to the body for `"wrong"`); AC-1.5 (right passphrase, power `""`, missing, `"narnia"` give 422 "Pick one of the seven powers." and no game); AC-1.6 (`ENV[...] = nil` and `"  "`: `GET /games/new` and `POST /games` give 403, the text "Creating games is turned off on this instance. Ask whoever runs it.", no `name="passphrase"` field, no game, and `expect(Rails.logger).to receive(:warn).with(/TRUCEBEARER_PASSPHRASE/)`); AC-1.7 (`allow(ActiveSupport::SecurityUtils).to receive(:secure_compare).and_call_original`, then a post makes it receive two 64-character digests; and with `Rails.logger.broadcast_to(Logger.new(io))` for the example (removed in `ensure`; `ActionController::LogSubscriber` logs through the broadcast logger, not through a swapped-in object) the log `io` contains `[FILTERED]` for the passphrase and does not contain `open sesame`); AC-11.2 (stub `allow(Rails.configuration).to receive(:force_ssl).and_return(true)`, `https!`, post; then the `host_` and `seat_` lines (from `cookie_line`) match `/;\s*httponly/i`, `/;\s*samesite=lax/i` and `/;\s*secure/i`; with it stubbed `false` they match the first two and not the third; the session cookie line (the flash writes it after a successful post, so it must be present) matches the first two); AC-11.3 (the raw `host_<id>` value is not the host token, and `ActionDispatch::Cookies::CookieJar.build(request, cookies.to_hash).signed["host_#{game.public_id}"]` verifies; since the host token is only on the next page, the example reads the seat token the same way and checks `Token.match?(that, seat.token_digest)`).

**Verify Phase 1:** `bundle exec rspec spec/requests/games_spec.rb spec/models spec/config` green, then the whole suite green (the layout, styleguide and words specs read new files: `words_spec` forbids the trademarked name in new files, and nothing here contains it). Run `bin/rails db:migrate` and commit `db/schema.rb`. Commits: one for the red spec, then one per green step ("Add tokens, join codes and the passphrase", "Add the games and seats tables", "Create a game with the instance passphrase").

## Phase 2: The host page, the host link, the QR code and the stranger page

**Implements:** FR-1 (pages), FR-4 (QR), FR-6 (strangers), FR-12 (production SSL config is Phase 6).
**Satisfies:** AC-1.8, AC-2.1 to AC-2.5, AC-3.1 to AC-3.3, AC-3.8, AC-5.5, AC-4.10 (the player's page), AC-11.2 for the flash cookie.
**Files:**
- Create `spec/requests/host_spec.rb`, `spec/helpers/qr_helper_spec.rb`, `spec/helpers/join_code_helper_spec.rb`, `app/helpers/{qr,join_code}_helper.rb`, `app/controllers/{hosts,host_links,seat_links}_controller.rb` (seat links are used in Phase 4 but share the stranger tests here, so the controller is made now), `app/views/hosts/show.html.erb`, `app/views/games/show.html.erb`.
- Change `Gemfile`, `Gemfile.lock`, `app/controllers/games_controller.rb`, `config/routes.rb` (already added), `app/views/layouts/application.html.erb` (one `<p role="status">` for `flash[:notice]` at the top of `main`, so every page reads the flash and a token left in it is dropped), `spec/rails_helper.rb` (already requires `support/responses`), `app/views/home/index.html.erb`, `spec/requests/root_spec.rb`.

### 2a. The dependency

`bundle add rqrcode` (pins `~> 3.2`), then `bundle install`; the lockfile gains `rqrcode 3.2.0`, `rqrcode_core 2.1.0`, `chunky_png 1.4.0` and nothing else (the diff of `Gemfile.lock` is checked: three gems and the `rqrcode` line under DEPENDENCIES, plus checksums if the lockfile carries them). The Gemfile line is `gem "rqrcode"` with a comment naming the reason (server-side inline SVG QR code, spec 021 FR-11).

### 2b. The helpers (red first)

`app/helpers/qr_helper.rb`:

```ruby
module QrHelper
  # The QR code as one inline SVG made on the server (spec FR-4). The gem writes an XML prolog and a fill attribute;
  # both are removed, so the stylesheet colors the code from the text token. The viewBox carries a four-module quiet zone.
  def qr_code_svg(url, label)
    svg = RQRCode::QRCode.new(url, level: :m).as_svg(
      offset: 4, module_size: 1, use_path: true, viewbox: true, standalone: true,
      svg_attributes: { role: "img", "aria-label": label, class: "qr-card__code" }
    )
    svg.sub(/<\?xml[^>]*\?>/, "").sub(/ fill="[^"]*"/, "").html_safe
  rescue RQRCodeCore::QRCodeRunTimeError => error
    Rails.logger.error("QR code could not be made: #{error.message}")
    nil
  end

  # The card: the code, a caption slot (the join code or a power badge), and the link as text under it.
  def qr_card(url, label:, caption: nil)
    tag.div(class: "qr-card") do
      safe_join([ qr_code_svg(url, label), (tag.div(caption, class: "qr-card__caption") if caption),
                  tag.p(url, class: "qr-card__link") ].compact)
    end
  end
end
```

`app/helpers/join_code_helper.rb`:

```ruby
module JoinCodeHelper
  # Six characters in two groups of three, in mono type. The element holds the text, so it can be selected and read aloud.
  def join_code_text(code)
    first, second = JoinCode.groups(code)
    tag.p(safe_join([ tag.span(first, class: "join-code__group"), " ", tag.span(second, class: "join-code__group") ]),
          class: "join-code mono")
  end
end
```

Specs: `qr_helper_spec.rb` (AC-3.8 pieces): the output starts with `<svg`, has `role="img"` and the label, has no `fill=`, no `style=`, no `<?xml`, one `<path`, a `viewBox` whose side equals the module count plus 8 (`RQRCode::QRCode.new(url, level: :m).modules.size + 8`), and equals the helper's output for the same URL but differs for another URL (so the SVG encodes the URL; this is how AC-3.2 is proved without a decoder). `join_code_helper_spec.rb`: `join_code_text("ABCDEF")` gives `<p class="join-code mono">` with text `ABC DEF`.

### 2c. Controllers and views

`HostsController`:

```ruby
class HostsController < ApplicationController
  before_action :require_host

  def show
    @host_token = flash[:host_token]
    @seats = @game.seats.index_by(&:power)
    return unless @host_token

    no_store # ActionController's own: Cache-Control no-store. The one page that shows the host link (spec D6)
  end
end
```

`hosts/show.html.erb` (abridged to its structure; every class exists in the catalog or in Phase 5's CSS):

```erb
<% content_for :title, "Your game" %>
<% content_for :head, tag.meta(name: "turbo-cache-control", content: "no-cache") if @host_token %>

<div class="stack">
  <h1>Your game</h1>

  <% if @host_token %>
    <div class="field">
      <label class="field__label" for="host-link">Your host link</label>
      <input class="control" id="host-link" type="text" readonly value="<%= game_host_link_url(@game.public_id, token: @host_token) %>">
      <span class="field__hint">Keep it private. Anyone who has it controls this game.</span>
    </div>
  <% end %>

  <section class="host-section stack" aria-labelledby="host-heading">
    <h2 id="host-heading">Host</h2>
    <% if @game.open? %>
      <%= qr_card(join_game_url(@game.join_code), label: "QR code to join the game", caption: join_code_text(@game.join_code)) %>
      <p>Joining is open. Players scan the code or type it at <strong><%= join_url %></strong>.</p>
      <%= link_to "Close joining", game_close_path(@game.public_id), class: "button button--secondary" %>
    <% else %>
      <p>Joining is closed.</p>
    <% end %>

    <h3>Seats</h3>
    <ul class="list">
      <% RulesEngine.powers.each do |power| %>
        <% id = power.id.to_s %>
        <li>
          <% if @seats[id] %>
            <%= link_to safe_join([ power_badge(id), tag.span("Reissue seat") ]), game_reissue_path(@game.public_id, id), class: "list__row" %>
          <% else %>
            <div class="list__row"><%= power_badge(id) %> <span>Open</span></div>
          <% end %>
        </li>
      <% end %>
    </ul>
  </section>

  <%= link_to "Your own seat", game_path(@game.public_id), class: "button button--secondary" %>
</div>
```

`GamesController#show` (player's page) and its view `games/show.html.erb`:

```ruby
  def show
    @game = find_game
    @seat = @game && seat_of(@game)
    return stranger!(@game) unless @seat

    @host = host?(@game)
  end
```

```erb
<% content_for :title, "Your seat" %>
<div class="stack">
  <h1>You hold <%= power_name(@seat.power) %></h1>
  <p><%= power_badge(@seat.power) %></p>
  <p>The host will start the game. Keep this page.</p>
  <% if @host %>
    <section class="host-section stack" aria-labelledby="host-link-heading">
      <h2 id="host-link-heading">Host</h2>
      <%= link_to "Host controls", game_host_path(@game.public_id), class: "button" %>
    </section>
  <% end %>
</div>
```

(`games/show` writes its `h1` as `You hold <%= power_name(@seat.power) %>`, and `reissues/show` its heading as `Reissue <%= power_name(@seat.power) %>`; both names come through `RulesEngine`.)

`HostLinksController` and `SeatLinksController`:

```ruby
class HostLinksController < ApplicationController
  # Declared before the rate limit, so a 429 carries it too, and every outcome looks alike (spec D4).
  before_action { response.set_header("Referrer-Policy", "no-referrer") }
  rate_limit to: 20, within: 1.minute, scope: :links, by: -> { client_key }, with: -> { too_many_tries }

  def show
    game = find_game
    return stranger!(game) unless game&.host_token?(params[:token])

    remember(:host, game, params[:token])
    redirect_to game_host_path(game.public_id)
  end
end

class SeatLinksController < ApplicationController
  before_action { response.set_header("Referrer-Policy", "no-referrer") }
  rate_limit to: 20, within: 1.minute, scope: :links, by: -> { client_key }, with: -> { too_many_tries }

  def show
    game = find_game
    return stranger!(game) unless game&.seat_for(params[:token])

    remember(:seat, game, params[:token])
    redirect_to game_path(game.public_id)
  end
end
```

`app/views/home/index.html.erb` keeps its `h1` and first `p`, and adds under them `<%= link_to "Create a game", new_game_path, class: "button" %>` and `<%= link_to "Join a game", join_path, class: "button button--secondary" %>` (`root_spec` still reads `h1` and the first `main p`; a new example checks the two links).

### 2d. Request specs (red first)

`spec/requests/host_spec.rb`, with `create_game` as a helper that posts the form and returns `[game, host_token]` by reading the host link from the redirect target's page:

- AC-1.8: after `post /games`, `follow_redirect!`; the page has `input#host-link` whose value is `http://www.example.com/games/<id>/host-link?token=<32 chars>`; the response has `Cache-Control: no-store` and `meta[name=turbo-cache-control][content=no-cache]`; a second `get` of the same URL shows no `#host-link`, and the body does not contain the token read from the first load.
- AC-2.1: open the link in a new session (`open_session`, so no cookies): it redirects to `/games/<id>/host`, sets `host_<id>`, has `Referrer-Policy: no-referrer`; following it shows `.host-section` and not the token.
- AC-2.2, 5.6: for `host-link` and for `seat-link` alike, a wrong token, an empty token, a missing token and an unknown game each give the stranger page (404, `We can't find that page.`) with no `host_` or `seat_` `Set-Cookie` value, and `Referrer-Policy: no-referrer`.
- AC-2.3: the host page for a phone with the cookie shows `.host-section`; for a phone without, with a cookie for another game, and with the seat cookie only, the stranger page.
- AC-2.5: a phone with a valid host cookie and valid seat cookie requests a wrong-token `host-link`, a wrong-token `seat-link`, and `/games/<id>/host` carrying the seat cookie only after the host cookie is removed; both cookies still verify afterwards (read with `host?`-equivalent: `GET /games/<id>/host` still gives 200 and `GET /games/<id>` still gives 200).
- AC-5.5: the sameness table. For each of four conditions (no cookie; a junk cookie named for the id in the path; a valid cookie of another game; the existing game's own valid seat cookie sent on the host page, which both requests carry) it requests, for each of `/games/<id>` and `/games/<id>/host`, the existing game's path and a missing game's path, and compares status, normalized body, and the headers `Content-Type`, `Cache-Control`, `Referrer-Policy` and the `host_`/`seat_` `Set-Cookie` lines with the id replaced by `ID`. A small helper `comparable(response, id)` in `spec/support/responses.rb` returns that tuple.
- AC-3.1 to 3.3: the host page has `.qr-card svg[role=img]`, `.join-code` text `ABC DEF` for the game's code, and `.qr-card__link` text `https://play.example.org/join/<code>` when requested with `headers: { "HOST" => "play.example.org" }` after `https!`; the svg equals `qr_code_svg(that url, "QR code to join the game")` (rendered through `ApplicationController.helpers`); with another host name (and `http`) it follows the request and differs; with a port (`"HOST" => "play.example.org:8443"`) the URL includes the port.
- AC-3.8: the page has no `img`, no `script` outside the importmap tags, no `fill`/`style` attribute in the `svg`, and every `src`/`href` on the page is relative or the page's own host (the QR card's link text is text, not a `href`).
- AC-4.10: a phone with a valid seat sees `/games/<id>` with its badge name and no other seat's details; a stranger sees the stranger page.
- Home: `GET /` has the two links, and `root_spec` is unchanged for the `h1` and first paragraph.

**Verify Phase 2:** `bundle exec rspec spec/requests spec/helpers spec/models` green and `bin/rubocop` clean. Commits: "Add rqrcode and the QR and join-code helpers", "Show the host page and open host links", "Show the player's page and open seat links".

## Phase 3: Joining by code or QR

**Implements:** FR-1 (join pages), FR-6, FR-7.
**Satisfies:** AC-4.1 to AC-4.9, AC-4.11, AC-5.1 to AC-5.4, AC-6.3.
**Files:**
- Create `spec/requests/joining_spec.rb`, `app/controllers/{joins,join_seats}_controller.rb`, `app/views/joins/{index,show}.html.erb`.
- Change `app/helpers/power_tiles_helper.rb` (no change; it already takes `taken:`).

```ruby
class JoinsController < ApplicationController
  NOT_OPEN = "That code doesn't match a game that is open for joining."

  rate_limit to: 30, within: 1.minute, scope: :join_lookup, name: "lookup", by: -> { client_key },
             with: -> { too_many_tries }, only: %i[create show]

  def index; end

  def create
    game = Game.open_by_code(params[:code])
    return not_open(:unprocessable_content) unless game

    redirect_to join_game_path(game.join_code)
  end

  def show
    @game = Game.open_by_code(params[:code])
    return not_open(:not_found) unless @game
    return redirect_to(game_path(@game.public_id)) if seat_of(@game)

    @taken = @game.seats.map(&:power)
  end

  private

  # One page and one message for an unknown code, a closed game's code and a malformed one (spec D4). It never echoes the code.
  def not_open(status)
    @error = NOT_OPEN
    render :index, status: status
  end
end
```

```ruby
class JoinSeatsController < ApplicationController
  rate_limit to: 30, within: 1.minute, scope: :join_seat, by: -> { client_key }, with: -> { too_many_tries }

  def create
    game = Game.open_by_code(params[:code])
    return not_open unless game
    return redirect_to(game_path(game.public_id)) if seat_of(game)

    power = RulesEngine.powers.find { |candidate| candidate.id.to_s == params[:power].to_s }
    return tiles_error(game, "Pick one of the seven powers.") unless power

    _seat, token = game.take_seat!(power.id.to_s)
    remember(:seat, game, token)
    redirect_to game_path(game.public_id)
  rescue Game::SeatTaken
    tiles_error(game, "#{power.name} has been taken. Pick another.")
  rescue Game::NotOpen
    not_open
  end

  private

  def not_open
    @error = JoinsController::NOT_OPEN
    render "joins/index", status: :unprocessable_content
  end

  def tiles_error(game, message)
    @game = game
    @taken = game.seats.reload.map(&:power)
    @error = message
    render "joins/show", status: :unprocessable_content
  end
end
```

Views. `joins/index.html.erb`: title "Join a game", `h1`, an error paragraph (`role="alert"`) when `@error`, and `form_with url: join_path` holding a `.field` for `code` (`autocomplete="off"`, `autocapitalize="characters"`, `inputmode="text"`, class `control mono`) and a `.button`. `joins/show.html.erb`: title "Pick a power", `h1`, the error paragraph, a sentence "Every seat is taken." when `@taken.size == RulesEngine.powers.size`, and `form_with url: join_seat_path(@game.join_code)` holding `<%= power_tiles(taken: @taken) %>`.

`spec/requests/joining_spec.rb` (red first; `open_game` helper makes a game through `Game.start!`):

- AC-4.1: `GET /join/<code>` has seven `.power-tile`, the host's power as `.power-tile--taken` with text `Taken` and not a `button` or `a`, six `button.power-tile` named by power.
- AC-4.2: posting `abc-def`, `acd efg` lower case, and ` ACDEFG ` to `/join` redirects to `/join/ACDEFG`.
- AC-4.3, 4.4: posting an open power creates one seat, sets `seat_<id>` (signed, value not the token), redirects to `/games/<id>`; the seat's stored digest is the digest of the token the verified cookie holds; no column holds the token.
- AC-4.5, 4.7: a taken power gives 422, the tiles again, "England has been taken. Pick another.", no seat, no `seat_` cookie; an unknown (`"narnia"`) or missing power gives 422 and "Pick one of the seven powers.".
- AC-4.6: two posts of one power in a row from two sessions create one seat; the second gets the AC-4.5 response. (No page is consulted by the POST, so this order is the race; `Game#take_seat!` is also exercised directly in `game_spec`.)
- AC-4.8: a phone holding a seat gets a redirect to `/games/<id>` from `GET /join/<code>` and from `POST /join/<code>/seat`, no second seat, cookie unchanged.
- AC-4.9: with seven seats made, the page has seven taken tiles and "Every seat is taken."
- AC-4.11: `close_joining!` after the page loaded (before the post); the post creates no seat and returns the AC-5.1 response.
- AC-5.1 to 5.4: for an unknown code, a closed game's code and each malformed code (`"ABCDE"`, `"ABCDEFG"`, `"AB!DEF"`, `"AB.DEF"`, `"AB%20DEF"` where `%20` decodes to a space and so is a valid code only if the rest fits; the example uses `"ABC%20DE"`), the three routes (`POST /join`, `GET /join/<code>`, `POST /join/<code>/seat`) answer 422, 404 and 422, the body does not contain the code, and the comparable tuple (status, normalized body, `Content-Type`, `Cache-Control`, `Referrer-Policy`, `host_`/`seat_` `Set-Cookie` lines) is equal for unknown and closed on each route, and the message equals `JoinsController::NOT_OPEN`.
- AC-6.3: after closing, seats already held still open `/games/<id>` (200).

**Verify Phase 3:** `bundle exec rspec spec/requests/joining_spec.rb` and the full request suite green. Commits: "Join a game by code", "Take a power from the join page".

## Phase 4: Close joining and reissue a seat

**Implements:** FR-1, FR-2, FR-7, D6, D7.
**Satisfies:** AC-6.1 to AC-6.5, AC-7.1 to AC-7.10.
**Files:**
- Create `spec/requests/closing_spec.rb`, `spec/requests/reissue_spec.rb`, `app/controllers/{closings,reissues}_controller.rb`, `app/views/closings/show.html.erb`, `app/views/reissues/{show,qr}.html.erb`.

```ruby
class ClosingsController < ApplicationController
  before_action :require_host

  def show; end

  def create
    @game.close_joining! # does nothing when it is already closed (AC-6.5)
    redirect_to game_host_path(@game.public_id)
  end
end
```

```ruby
class ReissuesController < ApplicationController
  before_action :require_host
  before_action :find_seat

  def show; end

  def create
    flash[:seat_token] = @game.reissue_seat!(@seat)
    redirect_to game_seat_qr_path(@game.public_id, @seat.power)
  end

  # The new code, shown once (spec D6). A reload finds no token and goes back to the host page.
  def qr
    @token = flash[:seat_token]
    return redirect_to(game_host_path(@game.public_id), notice: "That QR code is shown once. Reissue the seat to make a new one.") unless @token

    no_store
  end

  private

  def find_seat
    @seat = @game.seats.find_by(power: params[:power])
    stranger!(@game) unless @seat
  end
end
```

Views use `.stack`, `.button`, `.button--danger`, `.button--secondary` and `button_to`. `closings/show` (title "Close joining"): `h1`, "Closing cannot be undone. The players who joined keep their seats. Nobody new can join with the code.", `button_to "Close joining", game_close_path(@game.public_id), class: "button button--danger"`, a "Back" link to the host page (`class="button button--secondary"`). `reissues/show` (title "Reissue a seat"): `h1` "Reissue <power name>", "The phone that holds this seat loses it at once. Show the new QR code to the player who takes it over.", `button_to "Reissue seat", game_reissue_path(@game.public_id, @seat.power), class: "button button--danger"`, a "Back" link (`class="button button--secondary"`). `reissues/qr` (title "New seat code"; `turbo-cache-control` meta): `qr_card(game_seat_link_url(@game.public_id, token: @token), label: "QR code for this seat", caption: power_badge(@seat.power))` and the sentence "Scan this once. It cannot be shown again."

Specs (red first), in `closing_spec.rb`: AC-6.1 (the page says "cannot be undone", has a danger button posting to the same path, and a link back); AC-6.2 (post closes, redirects to the host page, which says "Joining is closed." and has no `.qr-card` and no `.join-code`); AC-6.4 (a request without the host cookie, with a seat cookie only, shows the stranger page and `joining_closed_at` stays nil, for both GET and POST); AC-6.5 (a second post changes nothing: `updated_at` and `joining_closed_at` are the same). `reissue_spec.rb`: AC-7.1 (the host page lists seven rows: taken ones link to `/games/<id>/host/seats/<power>/reissue`, open ones say "Open"); AC-7.2 (the confirm page says the old phone loses the seat at once); AC-7.3 (post replaces `token_digest` and redirects to `/qr`); AC-7.4 (the qr page after the redirect has the card with the power badge, `.qr-card__link` equal to `http://www.example.com/games/<id>/seat-link?token=<32 chars>`, the svg equals `qr_code_svg` of that URL, `Cache-Control: no-store`, the turbo meta; a second GET redirects to the host page whose `[role=status]` says "shown once"); AC-7.5 (the old seat cookie, sent after the reissue, gets the stranger page and a deletion `Set-Cookie` for `seat_<id>`; the same session's host cookie is untouched); AC-7.6 (a fresh session opens the new link: sets `seat_<id>`, redirects to `/games/<id>`, whose `h1` names the power); AC-7.7 (the old token in a seat link gives the stranger page and sets no `seat_` value); AC-7.8 (a power with no seat, and `"narnia"`: both the GET and the POST give the stranger page and nothing changes); AC-7.9 (without the host cookie both give the stranger page and the digest is unchanged); AC-7.10 (the host reissues their own power; the host's old seat cookie then fails).

**Verify Phase 4:** the request suite green. Commits: "Close joining after a confirmation page", "Reissue a seat with a new QR code".

## Phase 5: Rate limits, forgery protection and the response headers

**Implements:** FR-8, FR-2 (headers), NFR Security.
**Satisfies:** AC-8.2 to AC-8.10, AC-11.1.
**Files:** Create `spec/requests/rate_limits_spec.rb`, `spec/requests/forgery_spec.rb`. Production code for the limits was written with each controller (Phases 1 to 3), so this phase is specs only, plus any fix they expose. Each example is red before its `rate_limit` line is kept (the line is removed, the example watched failing, then restored).

`rate_limits_spec.rb` (the cache is cleared before every request spec by the Phase 1 hook):

```ruby
RSpec.describe "Rate limits", type: :request do
  around do |example|
    original = ENV["TRUCEBEARER_PASSPHRASE"]
    example.run
  ensure
    ENV["TRUCEBEARER_PASSPHRASE"] = original
  end

  let(:code) { Game.start!(power: "england").game.join_code }
  let(:one_address) { { "REMOTE_ADDR" => "203.0.113.7" } }
  let(:other_address) { { "REMOTE_ADDR" => "203.0.113.8" } }

  def limited? = response.status == 429 && response.body.include?("Too many tries. Wait a few minutes and try again.")

  it "limits code lookup to 30 a minute per address, the form and the page together (AC-8.2, 8.3)" do
    15.times { post "/join", params: { code: "ZZZZZZ" }, headers: one_address }
    15.times { get "/join/#{code}", headers: one_address }
    expect(response.status).to eq(200)

    get "/join/#{code}", headers: one_address
    expect(limited?).to be(true)

    get "/join/#{code}", headers: other_address
    expect(response).to have_http_status(:ok)
  end

  it "limits taking a power to 30 a minute (AC-8.4)" do
    30.times { post "/join/#{code}/seat", params: { power: "narnia" }, headers: one_address }
    post "/join/#{code}/seat", params: { power: "france" }, headers: one_address
    expect(limited?).to be(true)
  end

  it "limits creating a game to 10 in five minutes, even with the right passphrase (AC-8.5)" do
    ENV["TRUCEBEARER_PASSPHRASE"] = "open sesame"
    10.times { post "/games", params: { passphrase: "wrong", power: "england" }, headers: one_address }
    expect { post "/games", params: { passphrase: "open sesame", power: "england" }, headers: one_address }.not_to change(Game, :count)
    expect(limited?).to be(true)
  end

  it "limits host links and seat links together to 20 a minute (AC-8.6)" do
    10.times { get "/games/x/host-link", params: { token: "t" }, headers: one_address }
    10.times { get "/games/x/seat-link", params: { token: "t" }, headers: one_address }
    get "/games/x/host-link", params: { token: "t" }, headers: one_address
    expect(limited?).to be(true)
  end

  it "answers normally again after the window (AC-8.7)" do
    31.times { get "/join/#{code}", headers: one_address }
    expect(limited?).to be(true)
    travel 61.seconds
    get "/join/#{code}", headers: one_address
    expect(response).to have_http_status(:ok)
  end

  it "answers every bucket with the same status and body (AC-8.8)" do
    ENV["TRUCEBEARER_PASSPHRASE"] = "open sesame"
    responses = []
    11.times { post "/games", params: { passphrase: "x", power: "england" }, headers: one_address }
    responses << [ response.status, response.body ]
    31.times { get "/join/#{code}", headers: { "REMOTE_ADDR" => "203.0.113.20" } }
    responses << [ response.status, response.body ]
    31.times { post "/join/#{code}/seat", params: { power: "narnia" }, headers: { "REMOTE_ADDR" => "203.0.113.21" } }
    responses << [ response.status, response.body ]
    21.times { get "/games/x/host-link", params: { token: "t" }, headers: { "REMOTE_ADDR" => "203.0.113.22" } }
    responses << [ response.status, response.body ]

    expect(responses.map(&:first)).to all(eq(429))
    expect(responses.map { |_status, body| body.gsub(/\s+/, " ") }.uniq.size).to eq(1)
    expect(Nokogiri::HTML5(responses.first.last).at_css("main").text.strip).to eq("Too many tries. Wait a few minutes and try again.")
  end

  it "shares one bucket across an IPv6 /64 and keeps an IPv4 address apart (AC-8.9)" do
    15.times { get "/join/#{code}", headers: { "REMOTE_ADDR" => "2001:db8:0:1::1" } }
    15.times { get "/join/#{code}", headers: { "REMOTE_ADDR" => "2001:db8:0:1::2" } }
    get "/join/#{code}", headers: { "REMOTE_ADDR" => "2001:db8:0:1::3" }
    expect(limited?).to be(true)

    get "/join/#{code}", headers: { "REMOTE_ADDR" => "2001:db8:0:2::1" } # another /64
    expect(response).to have_http_status(:ok)
    get "/join/#{code}", headers: one_address
    expect(response).to have_http_status(:ok)
  end

  it "chooses the bucket by the client behind a private proxy (AC-8.10)" do
    behind = ->(client) { { "REMOTE_ADDR" => "10.0.0.5", "HTTP_X_FORWARDED_FOR" => client } }
    31.times { get "/join/#{code}", headers: behind.call("198.51.100.9") }
    expect(limited?).to be(true)

    get "/join/#{code}", headers: behind.call("198.51.100.10")
    expect(response).to have_http_status(:ok)
  end
end
```

`forgery_spec.rb` (AC-11.1): an `around` block sets `ActionController::Base.allow_forgery_protection = true` and restores it; then `POST /games`, `POST /join`, `POST /join/<code>/seat`, `POST /games/<id>/host/close` and `POST /games/<id>/host/seats/<power>/reissue` without a token each raise `ActionController::InvalidAuthenticityToken` or answer 422, and change nothing (`Game.count`, `Seat.count`, `joining_closed_at` and the seat digest are the same). A header example (in `host_spec`) already covers `Cache-Control` and `Referrer-Policy`.

**Verify Phase 5:** `bundle exec rspec spec/requests` green. Commit: "Test the rate limits and forgery protection".

## Phase 6: The four components, the style guide, the design-system page and the pairs

**Implements:** FR-10, FR-12 (docs, README, deploy, production).
**Satisfies:** AC-9.1 to AC-9.8 (the geometry ACs are proved in Phase 7), AC-11.4.
**Files:**
- Change `app/assets/stylesheets/components.css`, `app/assets/stylesheets/application.css` (the index comment), `app/views/styleguide/show.html.erb`, `app/helpers/styleguide_helper.rb`, `spec/support/stylesheets.rb` (`Contrast::DOCUMENTED_PAIRS`), `spec/requests/styleguide_spec.rb`, `spec/docs/design_system_spec.rb`, `spec/styles/stylesheet_rules_spec.rb` (no change unless the budget fails), `docs/design-system.md`, `README.md`, `config/deploy.yml`, `.kamal/secrets`, `config/environments/production.rb`, `spec/config/production_config_spec.rb` (create).

### 6a. Styles (red first: the style guide spec expects the four sections)

In `components.css`, before the "Reduced motion" block, tokens only:

```css
  /* ---- Join code: made by join_code_text. Mono, two groups of three ---- */
  .join-code {
    margin: 0;
    font-size: var(--text-2xl);
    line-height: var(--leading-tight);
    letter-spacing: 0.08em;
    text-align: center;
  }

  /* ---- QR card: the code on white, with a caption (join code or power badge) and the link as text ---- */
  .qr-card {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: var(--space-3);
    padding: var(--space-4);
    background: var(--color-surface);
    border: var(--border-width) solid var(--color-border);
    border-radius: var(--radius);
    color: var(--color-text);
  }

  .qr-card__code {
    width: 100%;
    max-width: 18rem;
    height: auto;
    fill: currentColor;
  }

  .qr-card__caption { text-align: center; }

  .qr-card__link {
    margin: 0;
    font-size: var(--text-sm);
    overflow-wrap: anywhere;
    text-align: center;
  }

  /* ---- Power tiles: seven in a grid, each with the power's badge. A taken tile says "Taken" and is not a control ---- */
  .power-tiles {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(9rem, 1fr));
    gap: var(--space-2);
    margin: 0;
    padding: 0;
    list-style: none;
  }

  .power-tile {
    display: flex;
    flex-direction: column;
    align-items: flex-start;
    justify-content: center;
    gap: var(--space-1);
    width: 100%;
    min-height: calc(var(--tap-min) * 1.5);
    padding: var(--space-3);
    border: var(--border-width) solid var(--color-border);
    border-radius: var(--radius);
    background: var(--color-surface);
    color: var(--color-text);
    font: inherit;
    text-align: start;
    cursor: pointer;
    touch-action: manipulation;
  }

  button.power-tile:active {
    background: var(--color-page);
    box-shadow: inset 0 0 0 var(--border-width) var(--color-border);
  }

  @media (hover: hover) {
    button.power-tile:hover { background: var(--color-page); }
  }

  .power-tile--taken {
    border-style: dashed;
    color: var(--color-text-muted);
    cursor: default;
  }

  /* ---- Host section: the host's controls, apart from a player's own content ---- */
  .host-section {
    padding: var(--space-4);
    background: var(--color-ice-pale);
    border-radius: var(--radius);
  }
```

Budget check (an example in this phase, before moving on): `wc -c app/assets/stylesheets/*.css` totals at most 24,576 bytes and `styleguide.css` stays at 3,716. The estimate is about 2,100 bytes for the block above (limit 3,550). If it does not fit, stop and `ask` before touching any limit, as the spec says.

### 6b. The style guide

Four sections are added to `show.html.erb`, after `mono-text`, each `section data-component="…" class="stack" aria-labelledby="…"` with an `h2`, and no inline style:

```erb
  <section data-component="join-code" class="stack" aria-labelledby="sg-join-code">
    <h2 id="sg-join-code">Join code</h2>
    <p>Six characters in two groups of three, in mono type.</p>
    <%= join_code_text("ACDEFG") %>
  </section>

  <section data-component="qr-card" class="stack" aria-labelledby="sg-qr-card">
    <h2 id="sg-qr-card">QR card</h2>
    <p>The code on white, with a caption under it. For a game the caption is its join code; for a seat it is the power's badge.</p>
    <%= qr_card("https://example.org/join/ACDEFG", label: "Example QR code", caption: join_code_text("ACDEFG")) %>
    <%= qr_card("https://example.org/games/abc/seat-link?token=example", label: "Example seat QR code", caption: power_badge(:italy)) %>
  </section>

  <section data-component="power-tile" class="stack" aria-labelledby="sg-power-tile">
    <h2 id="sg-power-tile">Power tiles</h2>
    <p>An open tile is a button. A taken tile says "Taken" and is not a control.</p>
    <%= power_tiles(taken: %w[austria italy]) %>
  </section>

  <section data-component="host-section" class="stack" aria-labelledby="sg-host-section">
    <h2 id="sg-host-section">Host section</h2>
    <div class="host-section stack">
      <h3>Host</h3>
      <p>The host's controls sit on a pale ground, apart from a player's own screen.</p>
      <a class="button" href="#sg-host-section">A host action</a>
      <a class="button button--secondary" href="#sg-host-section">Another action</a>
      <a class="button button--danger" href="#sg-host-section">A destructive action</a>
      <p><a href="#sg-host-section">A link on the ground</a></p>
    </div>
  </section>
```

`spec/requests/styleguide_spec.rb`: the existing example "shows seven power badges" counts every `.power-badge` on the page, and the new sections add more, so it is scoped to `section[data-component=power-badge] .power-badge` (and its token-name read stays as it is). The `components` list gains `join-code qr-card power-tile host-section` (AC-9.1), the old comment about 31 pairs is dropped (the count is `Contrast::DOCUMENTED_PAIRS.size`), and new examples check AC-9.3 (open tiles and taken tiles each show a power name; taken tiles contain "Taken" and are `div`s, not buttons) and that the existing no-inline-style example still passes.

### 6c. The `ice-pale` pairs

Add to `Contrast::DOCUMENTED_PAIRS` in `spec/support/stylesheets.rb` and, in the same order, to `StyleguideHelper::PAIRS` (the styleguide spec asserts the two are equal): `["primary","ice-pale",3.0]`, `["primary-pressed","ice-pale",3.0]`, `["border","ice-pale",3.0]`, `["danger","ice-pale",3.0]`, `["danger-pressed","ice-pale",3.0]`, `["focus","ice-pale",3.0]`, `["link","ice-pale",4.5]`, `["link-visited","ice-pale",4.5]`. (The `PAIRS` strings are `"3"` and `"4.5"` as in the helper.) `docs/design-system.md`: the "Documented pairs" table gains the rows `` `primary`, `primary-pressed`, `border`, `danger`, `danger-pressed` against `ice-pale` | 3 ``, `` `focus` against `ice-pale` | 3 `` (merged into the existing focus row) and `` `link` and `link-visited` on `ice-pale` | 4.5 `` (merged into the link row); the palette row for `--color-ice-pale` says "the host section" is now built; the catalog rows for the four components say "#21 (built)" with the final class names (`.join-code`, `.qr-card` with `__code`, `__caption`, `__link`, `.power-tiles`, `.power-tile` with `--taken`, `.host-section`) and the helper names (`join_code_text`, `qr_card`, `power_tiles`). If a computed ratio is under its minimum, stop and raise it with the numbers; no color value is changed. `spec/docs/design_system_spec.rb` gains an example (AC-9.6): for each of `.join-code`, `.qr-card`, `.power-tile` and `.host-section` there is a catalog line that names the class and says `#21` and "built", and the four helper names `join_code_text`, `qr_card`, `power_tiles` appear in the document.

### 6d. Production config, deploy, README

- `config/environments/production.rb`: uncomment `config.assume_ssl = true`. **Pending the maintainer:** uncomment `config.force_ssl = true` and `config.ssl_options = { redirect: { exclude: ->(request) { request.path == "/up" } } }`. If the maintainer declines `force_ssl`, only `assume_ssl` is set and `GameAccess#remember` takes `secure: Rails.env.production?` in place of `Rails.configuration.force_ssl`; the AC-11.2 examples then stub `Rails.env`, and the force-ssl lines of `production_config_spec` are dropped.
- `spec/config/production_config_spec.rb` (AC-11.4): reads `config/environments/production.rb` as text, strips comments, and expects `config.assume_ssl = true` (and, pending, `config.force_ssl = true` and an `ssl_options` redirect excluding `/up`); and an example wraps `Rails.application` in `ActionDispatch::SSL.new(app)` makes an `https` request that is a correct `POST /games` (the flash write is what sets the session cookie in test), and expects every `Set-Cookie` line of the response, the session cookie included, to include `secure`.
- `config/deploy.yml`: `env.secret` gains `- TRUCEBEARER_PASSPHRASE`. `.kamal/secrets`: add `TRUCEBEARER_PASSPHRASE=$TRUCEBEARER_PASSPHRASE` (read from the deploy machine's environment; no value in the file).
- `README.md`: a short section "Playtest access": what `TRUCEBEARER_PASSPHRASE` is, that creating games is refused (403) when it is unset or blank, that host and seat links carry a token in the query string which proxy and tunnel logs and browser history may keep, and that the host token cannot be rotated.

**Verify Phase 6:** `bundle exec rspec` (non-system and system) green, `wc -c` budget printed in the commit message of the CSS commit, `bin/rubocop` clean. Commits: "Build the join code, QR card, power tile and host section", "Add the four components to the style guide", "Document the ice-pale pairs and the new components", "Turn on assume_ssl, document the passphrase and list it for deploy".

## Phase 7: System specs at 360 pixels

**Implements:** Story 9 (geometry), Story 10.
**Satisfies:** AC-9.2, AC-9.7, AC-9.8, AC-10.1 to AC-10.4.
**Files:** Create `spec/system/create_and_join_spec.rb`, `spec/system/screens_layout_spec.rb`. Change `spec/system/styleguide_layout_spec.rb` (the tappable list and three examples).

`styleguide_layout_spec.rb`: `tappable` gains `".power-tile:not(.power-tile--taken)"`. Two new examples at 360 pixels:

- AC-9.7: every `.join-code` has the class `mono`; its computed font size is at least that of a probe element given `font-size: var(--text-2xl)` (the probe is created in the page with `document.createElement` and a class from `.sg-type-step--2xl`, which the style guide already has); it fits (`scrollWidth <= clientWidth`) and is one line (`getBoundingClientRect().height < 1.5 * parseFloat(getComputedStyle(el).lineHeight)`, the computed line height being in pixels).
- AC-9.3: `.power-tile--taken` has a computed `border-top-style` of `dashed`, a `background-color` of `rgb(255, 255, 255)` and the same computed `color` as an element with the `text-muted` class; an open `button.power-tile` has `solid`.
- AC-9.8: each `.qr-card` has a computed `background-color` of `rgb(255, 255, 255)` (the `surface` token); for each `.qr-card__code`, `getBoundingClientRect().width >= 200`; and the quiet zone, in modules, is at least 4 on every side: with `scale = svg.getBoundingClientRect().width / svg.viewBox.baseVal.width` and `path.getBoundingClientRect()`, `(path.left - svg.left) / scale >= 4 - 0.05`, the same for the top, and `(svg.right - path.right) / scale` and `(svg.bottom - path.bottom) / scale` at least `4 - 0.05`.

`create_and_join_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe "Creating a game and joining it", type: :system do
  around do |example|
    original = ENV["TRUCEBEARER_PASSPHRASE"]
    ENV["TRUCEBEARER_PASSPHRASE"] = "open sesame"
    example.run
  ensure
    ENV["TRUCEBEARER_PASSPHRASE"] = original
  end

  def no_sideways_scroll
    widths = evaluate_script("({ scroll: document.documentElement.scrollWidth, client: document.documentElement.clientWidth })")
    expect(widths["scroll"]).to be <= widths["client"]
  end

  it "lets a host create a game at 360 pixels and a second phone join it by code (AC-10.1 to 10.4)" do
    join_code = nil

    with_viewport(360) do
      visit "/games/new"
      no_sideways_scroll
      fill_in "Passphrase", with: "open sesame"
      click_button "England"

      expect(page).to have_css(".qr-card svg[role=img]")
      expect(page).to have_css("#host-link")
      join_code = find(".join-code").text.delete(" ")
      expect(join_code).to match(JoinCode::SHAPE)
      no_sideways_scroll
    end

    using_session(:player) do
      with_viewport(360) do
        visit "/join"
        no_sideways_scroll
        fill_in "Game code", with: join_code.downcase
        click_button "Join"

        expect(page).to have_css(".power-tile--taken", text: "England")
        expect(page).to have_css("button.power-tile", count: 6)
        no_sideways_scroll
        click_button "France"

        expect(page).to have_css("h1", text: "You hold France")
        no_sideways_scroll
      end
    end

    with_viewport(360) do
      visit current_path # the host reloads
      expect(page).to have_css(".list__row", text: "Reissue seat", count: 2)
      expect(page).to have_css(".list__row", text: "Open", count: 5)

      click_link "Close joining"
      click_button "Close joining"
      expect(page).to have_text("Joining is closed.")
      no_sideways_scroll
    end

    using_session(:third) do
      with_viewport(360) do
        visit "/join"
        fill_in "Game code", with: join_code
        click_button "Join"

        expect(page).to have_text("That code doesn't match a game that is open for joining.")
        no_sideways_scroll
      end
    end
  end

  it "reissues a seat and the old phone loses it (AC-7.5, 7.6)" do
    join_code = nil
    seat_link = nil

    with_viewport(360) do
      visit "/games/new"
      fill_in "Passphrase", with: "open sesame"
      click_button "England"
      join_code = find(".join-code").text.delete(" ")
    end

    using_session(:player) do
      with_viewport(360) do
        visit "/join"
        fill_in "Game code", with: join_code
        click_button "Join"
        click_button "France"
        expect(page).to have_css("h1", text: "You hold France")
      end
    end

    with_viewport(360) do
      visit current_path
      find("a.list__row", text: "France").click
      click_button "Reissue seat"
      expect(page).to have_css(".qr-card__link")
      seat_link = find(".qr-card__link").text
    end

    using_session(:replacement) do
      with_viewport(360) do
        visit seat_link
        expect(page).to have_css("h1", text: "You hold France")
      end
    end

    using_session(:player) do
      with_viewport(360) do
        page.refresh
        expect(page).to have_text("We can't find that page.")
      end
    end
  end
end
```

(The fields have the labels "Passphrase" and "Game code"; the buttons are "Join" and the tile names. The host's `current_path` is the host page because the redirect landed there.) Every screen the host and players pass through is measured for sideways scroll at 360.

`spec/system/screens_layout_spec.rb` covers every screen the feature adds, at 360 and 768 (AC-9.2, 10.4). It makes a game with `Game.start!`. Screens a signed-out phone sees are visited first, in a fresh session, and each visit asserts it reached the screen (the named element or text below); then the browser is signed in by visiting a host link and a seat link, and the signed-in screens follow. For each visit it first asserts `have_css("h1")`, then checks `scrollWidth <= clientWidth` and that every tappable control in `main` is at least 44 by 44 (half a pixel of tolerance, as in the style guide spec). Tappable means `a:not(p a), button, input:not([type=hidden]), select, .power-tile:not(.power-tile--taken)`; a link inside a paragraph is running text and exempt, as in the existing spec, and every other link on these screens is a `.button` or a `.list__row`. Signed out: `/`, `/games/new`, `/games/new` with the variable unset (text "turned off"), `/join`, `/join/<code>` (`button.power-tile` present), `/join/ZZZZZZ` (the not-open text), `/games/<id>` and `/games/<id>/host` (each with the text "We can't find that page."), and the 429 page (31 quick visits to `/join/<code>`). Signed in: `/games/<id>` (`h1` "You hold"), `/games/<id>/host`, `/games/<id>/host/close`, `/games/<id>/host/seats/<power>/reissue`, and `/games/<id>/host/seats/<power>/qr` reached by posting the reissue form (the page is shown once).

**Verify Phase 7:** `bundle exec rspec spec/system` green (needs Chrome), then the whole suite. Commit: "Test creating and joining a game in a real browser".

## Phase 8: Checks, screenshots and the pull request

**Implements:** the Proof list of the task, FR-11.
**Files:** `docs/specs/021-create-game-join-qr/screens/*.png` (committed), no code.

1. From `web/`: `bundle exec rspec` (system specs included), `bin/rubocop`, `bin/brakeman` (no warning, none ignored), `bundle exec bundler-audit check` (if the audit database is reachable; reported otherwise).
2. `git diff --name-only main...HEAD` lists only paths under `web/`.
3. `bundle exec rspec spec/styles/stylesheet_rules_spec.rb` shows the 24 KB and 4 KB limits met; the totals are copied into the pull request.
4. Screenshots at 360 pixels, made by a scratchpad spec (`with_viewport(360)`, `page.save_screenshot`, one per screen): home, new game, creation refused (variable unset), host page (with the host link), host page after closing, join code form, join with a taken power, the player's page, close confirmation, reissue confirmation, the reissued QR page, the stranger page, the 429 page, and the four components on `/styleguide`. They are committed under `screens/`.
5. Open the draft pull request from the template: "Closes #21", the reason for `rqrcode` and its two dependencies, the spec's Gate A record, the implementation review (Opus, read-only) and how each finding was handled, the owed list (remote_ip behind kamal-proxy and the tunnel, to #30; `force_ssl` and `config.hosts` for the maintainer; reopening joining; the token-in-query-string note) and the screenshots. It ends with "🤖 Generated with [Claude Code](https://claude.com/claude-code)".

## Coverage of the spec

| Spec | Phase |
|---|---|
| Story 1, FR-5 | 1 |
| Story 2, FR-6 | 2 |
| Story 3, FR-3, FR-4 | 1 (code), 2 (QR, page) |
| Story 4 | 3 |
| Story 5 | 2 (games, hosts, links), 3 (codes) |
| Story 6 | 4 |
| Story 7 | 4 |
| Story 8, FR-8 | 3 (limits written with the controllers), 5 (specs) |
| Story 9, FR-10 | 6 (markup, CSS, pairs), 7 (geometry) |
| Story 10 | 7 |
| Story 11, FR-2 | 1 (cookies), 5 (forgery), 6 (production) |
| FR-9 | 1 |
| FR-11 | 2a, 8 |
| FR-12 | 1 (RulesEngine, cache store, hook, filter), 6 (production, docs, deploy) |

## Risks and how the plan answers them

- **The stylesheet budget** (3,550 bytes free, 380 in `styleguide.css`): measured in Phase 6a before moving on, with an `ask` if it fails.
- **`rate_limit` binds its store at class load**: the test store is `:memory_store` from the start and a spec pins it (Phase 1d); every request and system example clears it.
- **Contrast on `ice-pale`**: eight pairs computed by the contrast spec, which stops the phase if one fails.
- **`force_ssl` pending the maintainer**: Phase 6d carries both paths; only that step changes.
- **A request-spec limitation**: concurrency is simulated by order, because the POST consults no earlier page; the database index is the arbiter, and `game_spec` tests it directly.

## Changes after the Opus plan review (round 1)

| Finding | Change |
|---|---|
| B1 Set-Cookie is an Array with lower-case attributes | `spec/support/responses.rb` (`cookie_lines`, `cookie_line`, `comparable`) and case-insensitive attribute matches |
| B2 `secure_compare` expectation too strict | `allow(...).and_call_original` then `have_received` |
| B3 styleguide badge count | The existing example is scoped to its own section |
| B4 log check could pass for nothing | `Rails.logger.broadcast_to`, and `[FILTERED]` must be in the captured log |
| NB1 to NB13 | `RQRCodeCore::QRCodeRunTimeError`; the support file is required; Phase 1a's stated failure reason; `turned_off` in the file list; `power_name` defined and used; one notice slot in the layout; `Referrer-Policy` declared before `rate_limit`; cookie deletion only for a 12-character id; AC-5.5 setup written out; the passphrase field's label and no echo; the AC-1.8 token check; Rails' own `no_store`; `require "rails_helper"` in each spec |
| Coverage gaps | AC-9.2 and 10.4: `screens_layout_spec.rb` at 360 and 768 over every new screen; AC-9.3: computed style of the taken tile; AC-9.6: an example on the design-system page; AC-9.8: the card's white ground; AC-8.8: the 429 page's `h1` is the sentence; AC-5.6: seat-link cases |
| NB14 (trailer name) | Not changed: this session's attribution line is "Claude Sonnet 5.5" |

## Changes after the Opus plan review (round 2)

| Finding | Change |
|---|---|
| B1 plain links cannot reach 44 by 44 | Standalone links (the stranger page's, the turned-off page's, "Back", "Your own seat") are `.button button--secondary`; links inside paragraphs are exempt, as in the existing spec |
| B2 cookie state hid two screens | Signed-out screens are visited first, each asserting it was reached, then the browser signs in |
| NB1 to NB9 | One-line check on the pixel line height; the session cookie must be present; the taken tile's white ground; the named page for the SSL middleware example; the passphrase restored in an `around` hook; every bucket's status collected; the Phase 1 sentence; `_seat`; the flash note goes in the PR |
| Gap: AC-5.5 `/games/<id>` | The sameness table runs on both paths |

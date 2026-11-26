# Plan 026: The host steps into another seat

Spec: `spec.md` v1.0.2 (Approved at Gate A; amended to v1.1.0 for #104, see the last section). Branch `web/26-step-in`. Everything here is under `web/`.

Version 1.0.1 of this plan follows the first Opus review: the suite stays green between phases (the route table, the `reveal_post_spec` route list, the reissue and host specs' list selectors, the missing-callback setting), the sweep's two new viewers are built so they can't undo themselves, no live time is drawn on a swept page, and the 409 page has no bar.

## Goal

Build the step-in in six phases, each ending with a green suite. Every phase starts with a request, model or system spec that is red for the right reason, then the code that turns it green. No new CSS, no JavaScript, no new gem: the pages are `.confirm`, `.banner`, `.button`, `.list`, `.host-section` and `.stack`.

## Gates checked

- **Simplicity (three components):** one table and model (`StepIn`), one controller (`StepInsController`), one concern's worth of access code (added to `GameAccess`). The order screen and pickers are the existing controllers.
- **Anti-abstraction:** no service object, no policy class. `StepIn#active?` is the one place the rule of D2 lives. The two path helpers exist because the views need them.
- **Integration first:** Phase 1 writes the first request spec (the confirmation page) and the route table; Phase 5 re-proves secrecy end to end.
- **One side:** only `web/`. The only non-code files are in `web/docs/` and `web/README.md` and `web/config/deploy.yml`.

## Decisions the plan adds (each traceable to the spec)

- **P1. The migration is `20261126140500_create_step_ins.rb`.** Its timestamp is later than spec 022's, and distinct from whatever #24 picks; `db/schema.rb` conflicts on merge are resolved by keeping both tables and the later version (D1).
- **P2. `Game#host_seat` is `seats.min_by(&:id)`** (the loaded association, no new query when seats are already loaded) (D5).
- **P3. `@step_in` and `@stepped_in_page` are the two request flags.** `@step_in` is the active row, set by `require_host`, `require_seat` and `games#show` for a verified host (D7). `@stepped_in_page` is true only when the page is a seat-scoped stepped-in URL (D4). Both are nil on any stranger page, because `stranger!` clears them (AC-3.8).
- **P4. The signed cookie's value is the row's integer id.** A cookie carried over from another cookie name fails Rails's signature check, because a signed cookie's verification is bound to its name. A correctly signed cookie that names a row of another game is caught by the explicit game check in `active_step_in`; AC-5.3 tests the two separately.

## Phase 1: The first test, the table, the model and the confirmation page

**Implements:** FR-1; D1, D9, D8's route. **Satisfies:** AC-1.1 to AC-1.5, AC-1.7, AC-2.7.
**Files:** create `spec/requests/step_in_confirm_spec.rb`, `db/migrate/20261126140500_create_step_ins.rb`, `app/models/step_in.rb`, `app/controllers/step_ins_controller.rb`, `app/views/step_ins/show.html.erb`, `spec/models/step_in_spec.rb`; change `config/routes.rb`, `spec/support/secrecy_routes.rb`, `spec/requests/reveal_post_spec.rb`, `app/models/game.rb`, `app/models/seat.rb`, `db/schema.rb` (generated), `spec/models/game_spec.rb`.

### 1a. The first test (red). It fails until the route exists

`spec/requests/step_in_confirm_spec.rb`:

```ruby
require "rails_helper"

# Spec 026 Story 1: the host asks to step into France's seat and gets a confirmation that names France. Nothing is recorded until
# the host confirms.
RSpec.describe "The step-in confirmation", type: :request do
  around { |example| with_passphrase { example.run } }

  let(:created) { create_game(power: "germany") } # the host holds Germany
  let(:game) { created.game }
  let(:id) { game.public_id }
  let!(:france) { game.take_seat!("france").first }
  let(:path) { "/games/#{id}/host/seats/france/phases/1/step-in" }
  let(:host) { created.session }

  def page = Nokogiri::HTML5(host.response.body)

  it "names France on a .confirm page and records nothing (AC-1.1)" do
    host.get path

    expect(host.response).to have_http_status(:ok)
    expect(page.at_css(".confirm h1").text).to include("France")
    expect(page.at_css(".confirm button").text).to eq("Step into France")
    expect(StepIn.count).to eq(0)
    expect(cookie_lines(host.response).grep(/step_in_/)).to be_empty
  end
end
```

Run it: it fails with a routing error (404, no route), which is the right reason. The rest of this file is written red in step 1d.

### 1b. The migration and the model

```ruby
class CreateStepIns < ActiveRecord::Migration[8.1]
  def change
    create_table :step_ins do |t|
      t.references :phase, null: false, foreign_key: true
      t.references :seat, null: false, foreign_key: true
      t.datetime :created_at, null: false
    end
  end
end
```

`app/models/step_in.rb`:

```ruby
# One time the host confirmed entering another seat for a phase (spec 026 D1). The row is the record, and it is also what the
# step-in cookie names (D2). It never changes and is never deleted. It holds no order and no count of orders.
class StepIn < ApplicationRecord
  LIFETIME = 30.minutes

  belongs_to :phase
  belongs_to :seat

  validate { errors.add(:seat, "is not in this game") unless seat && phase && seat.game_id == phase.game_id }

  # A written row can't be changed or removed: update and destroy raise ActiveRecord::ReadOnlyRecord.
  def readonly? = persisted? || super

  def self.record!(phase:, seat:) = create!(phase: phase, seat: seat)

  # Active while the phase is still open (read from the database, so a reveal ends it at once) and for LIFETIME after entering (D2).
  def active? = created_at > LIFETIME.ago && Phase.open?(phase_id)
end
```

`Seat` gets `has_many :step_ins` and, for the owner's notice (D6):

```ruby
  has_many :step_ins # a host's entries into this seat (spec 026); the rows hold no order

  # When the host entered this seat in the phase, oldest first (spec 026 D6). Times only: no order, no count of orders.
  def step_in_times(phase) = step_ins.where(phase_id: phase.id).order(:id).pluck(:created_at)
```

`Game` gets:

```ruby
  # The host's own seat: the lowest id. Game.start! makes it in the game's own transaction and no path deletes a seat (spec 026 D5).
  def host_seat = seats.min_by(&:id)

  # Every step-in of this game, oldest first, for the host page (spec 026 D6). Read through the phases, never through an association
  # that reaches saved orders.
  def step_in_history = StepIn.joins(:phase).where(phases: { game_id: id }).includes(:phase, :seat).order(:id)
```

`bin/rails db:migrate` regenerates `db/schema.rb`.

### 1c. The route, controller and page

`config/routes.rb`, inside the `scope "games/:public_id"` block, right after the `host/seats/:power/qr` route (not at the end of the block, where #24 will add its own):

```ruby
    # Stepping into another seat (spec 026). The confirmation and the record carry the phase number, as the reveal does (D9).
    get "host/seats/:power/phases/:number/step-in", to: "step_ins#show", as: :game_step_in, constraints: { number: %r{[^/]+} }
    post "host/seats/:power/phases/:number/step-in", to: "step_ins#create", as: nil, constraints: { number: %r{[^/]+} }
    delete "host/seats/:power/step-in", to: "step_ins#destroy", as: :game_leave_step_in
```

`app/controllers/step_ins_controller.rb` (Phase 1 has `show`; `create` and `destroy` arrive in Phase 2):

```ruby
# The host's confirmation page for stepping into a seat, the record, and leaving (spec 026 D9, D2).
class StepInsController < ApplicationController
  before_action :require_host
  # `only:` names actions that exist: the test environment raises on a callback for a missing action. Phase 2 adds create.
  before_action :find_seat, only: :show
  before_action :find_phase_or_redirect, only: :show

  def show; end

  private

  # A seat the game has that is not the host's own. Anything else is the stranger response (AC-1.5).
  def find_seat
    @seat = @game.seats.find_by(power: params[:power])
    stranger!(@game) unless @seat && @seat != @game.host_seat
  end

  # A later, unknown or malformed number is a stranger; a revealed one goes to the open phase's confirmation (AC-1.7).
  def find_phase_or_redirect
    @phase = find_phase(@game)
    current = @game.current_phase
    return stranger!(@game) unless @phase && @phase.number <= current.number
    return if @phase.open?

    flash[:banner] = { "kind" => "info", "text" => "That phase was already revealed. Check the new phase and confirm again." }
    redirect_to game_step_in_path(@game.public_id, @seat.power, current.number), status: :see_other
  end
end
```

`app/views/step_ins/show.html.erb`:

```erb
<% name = power_name(@seat.power) %>
<% content_for :title, "Step into #{name}" %>

<%= render layout: "shared/confirm", locals: { title: "Step into #{name}'s seat", confirm_label: "Step into #{name}", danger: true,
      confirm_path: game_step_in_path(@game.public_id, @seat.power, @phase.number), cancel_path: game_host_path(@game.public_id) } do %>
  <p>You will be able to see and change <%= name %>'s orders for <%= @phase.title %>.</p>
  <p>This is recorded in the game. <%= name %> will see that the host entered their orders, and the time you confirmed.</p>
  <p>It ends when you tap Leave, when you reveal the phase, or after 30 minutes. Your own seat stays your main screen.</p>
<% end %>
```

The page draws no clock: the confirmation is swept for every host viewer, and a changing time would make the sweep's snapshots differ.

### 1d. More specs in this phase (red first, then green)

In `spec/requests/step_in_confirm_spec.rb`: AC-1.2 (danger variant `.button--danger`, names the phase "Spring 1901", says "recorded", "30 minutes", shows no order: seed France with a saved order and assert its JSON and "Hold" are absent); AC-1.3 (the Back link goes to `/games/:id/host`, and a GET writes nothing); AC-1.4 for GET (a seat phone, a stranger, and another game's host each get the stranger page, using `comparable(response, id)` against a missing id; the POST cases are added in Phase 2 with the action); AC-1.5 (the host's own power `germany`, an empty power `italy`, and `nope` are the stranger response); AC-1.7 for GET (after `game.current_phase.reveal!`, GET `.../phases/1/step-in` redirects 303 to `.../phases/2/step-in` with the banner, `StepIn.count` is 0; `.../phases/9/step-in` and `.../phases/01/step-in` are strangers; the POST case moves to Phase 2).

`spec/models/step_in_spec.rb` (it includes `ActiveSupport::Testing::TimeHelpers`, which `rails_helper` gives request specs only): `record!` writes one row with the phase and seat; a seat of another game is invalid; `update` and `destroy` raise `ActiveRecord::ReadOnlyRecord`; `active?` is true at 29 minutes, false at 31 (`travel`), false once `phase.reveal!` ran. `spec/models/game_spec.rb`: `host_seat` is the seat made with the game even after `take_seat!` of two more; `step_in_history` lists the game's rows oldest first and none of another game's.

**Keeping the suite green in this phase.** Adding routes fails two existing specs, so both change here:
- `spec/support/secrecy_routes.rb` gets the three new routes (`GET` and `POST` step-in, `DELETE` step-in) as `shows: :none`, the GET with the sweep path `"/games/#{c.id}/host/seats/england/phases/1/step-in"`.
- `spec/requests/reveal_post_spec.rb:136-144` ("no undo") lists exactly the routes whose path contains "phases". Its `match_array` gains `GET` and `POST /games/:public_id/host/seats/:power/phases/:number/step-in`, and the commit message and the PR say so.

**Verify:** `bundle exec rspec spec/requests/step_in_confirm_spec.rb spec/models/step_in_spec.rb spec/models/game_spec.rb spec/requests/reveal_post_spec.rb spec/requests/order_secrecy_spec.rb` is green; then the whole suite.

## Phase 2: The record, the cookie, and acting as the seat

**Implements:** FR-1, FR-2, D2, D3, D4, D7. **Satisfies:** AC-2.1 to AC-2.6, AC-3.1 to AC-3.8, AC-4.1 to AC-4.6, AC-5.1 to AC-5.4.
**Files:** create `spec/requests/step_in_spec.rb`, `app/views/step_ins/_bar.html.erb`; change `app/controllers/concerns/game_access.rb`, `app/controllers/concerns/order_screen.rb`, `app/controllers/step_ins_controller.rb`, `spec/support/secrecy_routes.rb`, `spec/requests/reveal_post_spec.rb`, `spec/requests/step_in_confirm_spec.rb`, `app/controllers/seat_orders_controller.rb`, `app/controllers/order_pickers_controller.rb`, `app/controllers/games_controller.rb`, `config/routes.rb`, `app/views/layouts/application.html.erb`, `app/views/seat_orders/show.html.erb`, `_submit_bar.html.erb`, `_unit_row.html.erb`, `revealed.html.erb`, `app/views/order_pickers/show.html.erb`.

### 2a. Tests first (red): `spec/requests/step_in_spec.rb`

A game where the host holds Germany; England and France hold seats; France has saved orders (`france.save_orders!(phase, "par" => hold)`). Helpers: `confirm(power = "france")` posts `/games/:id/host/seats/#{power}/phases/1/step-in` on the host session; `orders_path(power) = "/games/#{id}/host/seats/#{power}/phases/1/orders"`.

- AC-2.1: `expect { confirm }.to change(StepIn, :count).by(1)`; the row's seat is France's and phase is the open one; the response is a 303 to `orders_path("france")`; the `Set-Cookie` line for `step_in_<id>` matches `/httponly/i`, `/samesite=lax/i` and has no `expires` (Rack writes the attribute names in lower case, so the match ignores case, as `games_spec` does).
- AC-2.2: before confirming, GET the screen, `/orders/par`, and PUT the endpoint on `orders_path("france")` each give the stranger page (`comparable` against a game that doesn't exist) with no `Hold` or `Army in Paris` in the body and `StepIn.count` unchanged.
- AC-2.3: after confirming, the screen shows France's `.unit-row`s with "Army in Paris (PAR) Hold".
- AC-2.4: the cookie line contains neither the France token nor the France seat's `token_digest`; France's phone (`open_session` with the seat link) still gets 200 on its own screen and saves an order.
- AC-2.5: two confirmations make two rows.
- AC-2.6: confirm France, then England: France's URL is a stranger, England's works.
- AC-3.1 and 3.2: the screen, a picker step, the host's own seat page, the host page, the reveal confirmation, the close page and the reissue page each have a `.banner--warning` containing "France"; the stepped-in pages read "Acting as France" and the others "Still stepped into France's seat." with a link whose `href` is France's orders; each has a button "Leave France's seat" (a form with `_method=delete`).
- AC-3.3: before confirming and after Leave, no page has `.banner--warning` with "stepped" or "Acting".
- AC-3.5: Leave redirects 303 to `/games/:id`, a second Leave does too, France's URL is a stranger after it, and a non-host's Leave is a stranger.
- AC-3.6: the host's own `/phases/1/orders` shows Germany's units, also with `?power=france`.
- AC-3.8: with a step-in active, `/games/:id/phases/1/orders/xyz` and `/games/:id/phases/9/orders` are byte for byte the stranger page of a host with no step-in (`comparable`), with no `step_in_` cookie line; after the reveal the 409 page of a stale number has no bar.
- AC-3.9: covered in Phase 3. The POST cases of AC-1.4 (a seat phone, a stranger, another game's host) and AC-1.7 (a revealed number redirects 303 and writes nothing) are added to `step_in_confirm_spec.rb` here, with `create`.
- AC-4.1: through the stepped-in picker (`PUT orders_path("france")` with `orders[par]=...`) France's `orders_for` changes and France's phone shows it; the redirect is to `orders_path("france")`.
- AC-4.2: another power's unit, an illegal order, unreadable text: 422 with the spec 022 sentence and nothing stored.
- AC-4.3: `submit=1` marks France submitted; a later changed pick clears it.
- AC-4.5: with France's step-in, `PUT orders_path("england")` is a stranger and England's orders are unchanged.
- AC-4.6: the stepped-in screen's `h1` is "France's orders", the submit bar's link reads "Your own seat", the picker links and forms are all under `/host/seats/france/`; the own screen's `h1` is "Your orders".
- AC-5.1: after `game.current_phase.reveal!`, France's URL is a stranger and no page has the bar.
- AC-5.2: `travel 29.minutes` works, `travel 31.minutes` is a stranger and has no bar.
- AC-5.3: a garbage cookie value; the cookie of another game's step-in copied to this game's cookie name (it fails the signature, because signed cookies are bound to their name); a row of France's step-in used on England's URL; `StepIn.delete_all` after confirming; and a step-in cookie sent by a session that has lost its host cookie: each is a stranger on a stepped-in URL. The explicit game check (`row.phase.game_id == game.id`) is exercised separately, with a correctly signed cookie for this game whose value is a row of another game: the example runs on a host-only session (the host link opened alone) so that `stranger!` has no real seat cookie to delete, and stubs the signed jar for the request, `allow_any_instance_of(ActionDispatch::Cookies::CookieJar).to receive(:signed).and_return("host_#{id}" => created.host_token, "step_in_#{id}" => other_game_row.id)`, and expects the stranger response.
- AC-3.7: the host's own seat page shows no host controls (no "Reveal orders"), the "Host controls" link sits in a `.host-section`, and after Leave the host lands on `/games/:id`.
- AC-8.6 (headers): the stepped-in screen and a picker step carry `Cache-Control` containing `no-store`, `Referrer-Policy: no-referrer` and the `turbo-cache-control` meta.
- AC-3.8 (the 409): the step-in is made in phase 2 (reveal phase 1 first, then confirm for phase 2); `GET /games/:id/host/seats/france/phases/1/orders` is then the 409 page, has no bar, and its "Go to the current phase" link goes to phase 2 of the stepped-in screen.
- AC-5.4: after the reveal, the new phase's orders URL is a stranger until a new confirmation, which is a new row for phase 2.

All of these fail with routing errors or 404 until 2b to 2e.

### 2b. The access code: `app/controllers/concerns/game_access.rb`

Add (all private, with the two path helpers exposed as helpers):

```ruby
  included { helper_method :orders_path_for, :picker_path_for, :own_seat_target }

  def step_in_cookie_name(public_id) = "step_in_#{public_id}"

  # Signed, httponly, lax, and no expiry: a session cookie. The value is the row's id and nothing else (spec 026 D2).
  def remember_step_in(game, row)
    cookies.signed[step_in_cookie_name(game.public_id)] =
      { value: row.id, httponly: true, same_site: :lax, secure: !!(Rails.configuration.force_ssl || Rails.env.production?) }
  end

  # The active step-in of this request, or nil: the host cookie is valid, the cookie verifies and names a row, the row is of this
  # game and still active (spec 026 D2). Never raises, never sets or deletes the cookie.
  def active_step_in(game)
    return nil unless host?(game)

    id = cookies.signed[step_in_cookie_name(game.public_id)]
    row = id.is_a?(Integer) ? StepIn.includes(:phase, :seat).find_by(id: id) : nil
    row if row && row.phase.game_id == game.id && row.seat.game_id == game.id && row.active?
  end

  # Sets @step_in for the bar (spec 026 D7) for a verified host.
  def load_step_in(game) = (@step_in = active_step_in(game))

  # The seat of a stepped-in URL: the host's active step-in is for this power, or nil (D2, D4).
  def stepped_in_seat(game, power)
    row = active_step_in(game)
    return nil unless row && row.seat.power == power

    @step_in = row
    @stepped_in_page = true
    row.seat
  end

  # Where "your own seat" is: the seat page, or the host page when this browser holds no seat of its own (D7).
  def own_seat_target(game = @game) = seat_of(game) ? game_path(game.public_id) : game_host_path(game.public_id)

  def orders_path_for(number)
    return game_seat_orders_path(@game.public_id, number) unless @stepped_in_page

    game_step_in_orders_path(@game.public_id, @seat.power, number)
  end

  def picker_path_for(number, province, **query)
    return game_order_picker_path(@game.public_id, number, province, **query) unless @stepped_in_page

    game_step_in_picker_path(@game.public_id, @seat.power, number, province, **query)
  end
```

`@seat` is the stepped-in seat on a stepped-in page, so these helpers don't need `@step_in`. `app/controllers/concerns/order_screen.rb` changes one line so the 409 page never carries the bar (D7, AC-3.8), while its link still follows the stepped-in URLs:

```ruby
  def render_revealed
    @step_in = nil # a refusal page has no bar (spec 026 D7)
    render("seat_orders/revealed", status: :conflict)
  end
```

`GameAccess` currently has no `included` block and `ApplicationController` includes it; `helper_method` is called from the `included` block, which is valid for an `ActiveSupport::Concern`.

Change `require_host` to set the bar flag and `stranger!` to clear it:

```ruby
  def require_host
    @game = find_game
    return stranger!(@game) unless @game && host?(@game)

    load_step_in(@game)
  end
```

and as the first line of `stranger!`: `@step_in = @stepped_in_page = nil`.

Change `require_seat` to resolve a stepped-in URL (D4). It reads the path parameter, never the query:

```ruby
  def require_seat
    @game = find_game
    power = request.path_parameters[:power]
    @seat = @game && (power ? stepped_in_seat(@game, power) : seat_of(@game))
    stranger!(@game) unless @seat
  end
```

(Phase 3 adds the host-cookie-plus-another-seat redirect to the own-seat branch.)

### 2c. The controller actions: `app/controllers/step_ins_controller.rb`

```ruby
  def create
    row = StepIn.record!(phase: @phase, seat: @seat) # written before the redirect, so before any page shows an order (AC-2.1)
    remember_step_in(@game, row)
    redirect_to game_step_in_orders_path(@game.public_id, @seat.power, @phase.number), status: :see_other
  end

  # Leaving ends this browser's step-in. It always redirects, so a repeat is harmless (AC-3.5).
  def destroy
    cookies.delete(step_in_cookie_name(@game.public_id))
    redirect_to own_seat_target(@game), status: :see_other
  end
```

The two before-actions change from `only: :show` to `only: %i[show create]` in this step.

### 2d. Reuse of the order controllers (D4): the seat-scoped routes

`config/routes.rb`, in the same block:

```ruby
    get "host/seats/:power/phases/:number/orders", to: "seat_orders#show", as: :game_step_in_orders, constraints: { number: %r{[^/]+} }
    put "host/seats/:power/phases/:number/orders", to: "seat_orders#update", constraints: { number: %r{[^/]+} }
    get "host/seats/:power/phases/:number/orders/:province", to: "order_pickers#show", as: :game_step_in_picker,
                                                             constraints: { number: %r{[^/]+}, province: %r{[^/]+} }
```

`SeatOrdersController#update`: `redirect_to orders_path_for(@phase.number), status: :see_other`. `OrderPickersController#show`: `redirect_to picker_path_for(@phase.number, @province), status: :see_other unless @step`. Both controllers call `require_seat` as today, so a stepped-in URL resolves through 2b and everything after it is the unchanged code: `@seat.save_orders!` is still the only writer (`seat_write_scan_spec` is untouched and must stay green).

Views, exact replacements:

- `seat_orders/_unit_row.html.erb`: `game_order_picker_path(game.public_id, phase.number, province)` becomes `picker_path_for(phase.number, province)`.
- `seat_orders/_submit_bar.html.erb`: `form_with url: orders_path_for(phase.number), method: :put`, and the link becomes `<% if @stepped_in_page %><%= link_to "Your own seat", own_seat_target(game), class: "button button--secondary" %><% else %>…"Back to your seat", game_path(game.public_id)…<% end %>`.
- `seat_orders/show.html.erb`: `<h1><%= @stepped_in_page ? "#{power_name(@seat.power)}'s orders" : "Your orders" %></h1>`, and `content_for :title` the same.
- `seat_orders/revealed.html.erb`: the link uses `orders_path_for(@game.current_phase.number)`.
- `order_pickers/show.html.erb`: the three `game_seat_orders_path` and two `game_order_picker_path` calls become `orders_path_for(@phase.number)` and `picker_path_for(@phase.number, @province, draft: …)`.

`spec/support/secrecy_routes.rb` gets the three stepped-in order routes now, so the suite stays green (their entries are the ones in Phase 5a; Phase 5 adds the sweep viewers, not the rows). `spec/requests/reveal_post_spec.rb`'s route list gains the three stepped-in order routes too (`GET` and `PUT` orders, `GET` picker).

`app/views/layouts/application.html.erb`: the first line inside `<main>`: `<%= render "step_ins/bar", step_in: @step_in if @step_in %>`.

`app/views/step_ins/_bar.html.erb`:

```erb
<%# The step-in bar (spec 026 D7): a banner and the way back, from existing components. locals: step_in. @stepped_in_page says which text. %>
<% name = power_name(step_in.seat.power) %>
<div class="stack">
  <% if @stepped_in_page %>
    <%= render "shared/banner", kind: "warning", text: "Acting as #{name}. What you save here is #{name}'s, and #{name} is told." %>
  <% else %>
    <%= render "shared/banner", kind: "warning", text: "Still stepped into #{name}'s seat." %>
    <%= link_to "#{name}'s orders", game_step_in_orders_path(@game.public_id, step_in.seat.power, step_in.phase.number), class: "button" %>
  <% end %>
  <%= button_to "Leave #{name}'s seat", game_leave_step_in_path(@game.public_id, step_in.seat.power), method: :delete,
                class: "button button--secondary" %>
</div>
```

`GamesController#show` calls `load_step_in(@game)` after it verifies the seat (a host only; `load_step_in` returns nil without the host cookie).

**Verify:** `bundle exec rspec spec/requests/step_in_spec.rb spec/requests/step_in_confirm_spec.rb`, then the whole suite (the existing order specs prove the helpers changed nothing for the own URLs).

## Phase 3: The reissue gap and the host page's entry list

**Implements:** FR-3, D5, D8. **Satisfies:** AC-1.6, AC-3.9, AC-7.1 to AC-7.7.
**Files:** create `spec/requests/step_in_reissue_spec.rb`, `app/views/step_ins/_entry.html.erb`; change `spec/requests/reissue_spec.rb`, `spec/requests/host_spec.rb` and `spec/requests/phase_pages_spec.rb` (selectors only), `app/controllers/seat_links_controller.rb`, `app/controllers/concerns/game_access.rb`, `app/controllers/games_controller.rb`, `app/views/hosts/show.html.erb`, `app/views/reissues/show.html.erb`.

### 3a. Tests first (red): `spec/requests/step_in_reissue_spec.rb`

Setup as `reissue_clears_orders_spec`: the host holds Germany; France holds a seat with a saved order; `reissue_and_link("france")` reissues on the host session and returns the link from the QR page.

- AC-7.1: the host session opens France's new link: 302 to `/games/:id/host/seats/france/phases/1/step-in`; `host.cookies["seat_<id>"]` is unchanged (still the host's own seat token), no new `seat_` `Set-Cookie`; `StepIn.count` 0; the host's own seat page still works; following the redirect shows the confirmation and no France order.
- AC-7.2: confirming is an ordinary step-in (a row, the cookie, the bar), and the France phone, opening the same link in a clean session, sees "The host entered your orders" (checked in Phase 4); the link's token never appears in any cookie of the host session.
- AC-7.3: the host reissues Germany and opens that link on the host session: 302 to `/games/:id`, `seat_<id>` replaced, no step-in.
- AC-7.4: a clean session opens a reissued link: seat cookie set, redirect to `/games/:id`.
- AC-7.5: a session with the host cookie and France's seat cookie (clean session: seat link first, then `/host-link`) opens `/games/:id`, `/games/:id/phases/1/orders`, `/orders/par` and PUTs the endpoint. The first redirect deletes the seat cookie, so the example saves the raw `seat_<id>` cookie value after setup and puts it back in the jar before each request (`session.cookies["seat_#{id}"] = saved`); the first request also asserts the deletion. Each request redirects (302) to France's confirmation for phase 1, deletes the `seat_<id>` cookie in the same response, shows no France order, saves nothing and writes no row; after confirming it is an ordinary step-in.
- AC-7.6: a wrong, old or malformed token gives the same stranger response with and without the host cookie.
- AC-7.7: the reissue confirmation page says the orders are deleted and that opening the new link on the host's own phone counts as stepping in.
- AC-3.9: a session with only the host cookie and no seat (the host link opened on a second phone) steps into France; Leave redirects to `/games/:id/host`, and so does the submit bar's own-seat link (its `href` is the host page).
- AC-1.6: the host page has "Step into a seat" with a row for France and England and none for Germany (the host's own), each linking to its confirmation for the open phase, and no order, count or submitted state in it.

### 3b. The code

`GameAccess`:

```ruby
  # A browser that holds the host cookie and a seat other than the host's own is not that seat: it is sent to that seat's step-in
  # confirmation, and the foreign seat cookie goes (spec 026 D5). True when it redirected.
  def send_to_step_in(game, seat)
    return false unless host?(game) && seat != game.host_seat

    cookies.delete(cookie_name(:seat, game.public_id))
    redirect_to game_step_in_path(game.public_id, seat.power, game.current_phase.number)
    true
  end
```

`require_seat` (own-URL branch), replacing Phase 2's:

```ruby
  def require_seat
    @game = find_game
    power = request.path_parameters[:power]
    @seat = @game && (power ? stepped_in_seat(@game, power) : seat_of(@game))
    return stranger!(@game) unless @seat
    return if power

    return if send_to_step_in(@game, @seat)
    load_step_in(@game)
  end
```

with `performed?`-safe flow: after `send_to_step_in` redirects, the before-action chain stops because a redirect has rendered (`before_action` halts when `performed?`), so `find_phase_or_stranger` does not run.

`GamesController#show`:

```ruby
    @seat = @game && seat_of(@game)
    return stranger!(@game) unless @seat
    return if send_to_step_in(@game, @seat)

    load_step_in(@game)
    @host = host?(@game)
```

`SeatLinksController#show`:

```ruby
  def show
    game = find_game
    seat = game&.seat_for(params[:token])
    return stranger!(game) unless seat
    # A host browser never takes another seat's token (spec 026 D5): the link leads to the confirmation, and nothing is stored.
    return redirect_to(game_step_in_path(game.public_id, seat.power, game.current_phase.number)) if host?(game) && seat != game.host_seat

    remember(:seat, game, params[:token])
    redirect_to game_path(game.public_id)
  end
```

`app/views/step_ins/_entry.html.erb`:

```erb
<%# The host page's way in (spec 026 D8): one row for each held seat but the host's own. No order, count or submitted state. locals: game, seats (by power), phase %>
<% others = seats.values.reject { |seat| seat == game.host_seat } %>
<% if others.any? %>
  <h3>Step into a seat</h3>
  <p>Enter orders for a player who can't. It is recorded, and that player is told.</p>
  <ul class="list" data-step-in-entry>
    <% others.each do |seat| %>
      <li><%= link_to safe_join([ power_badge(seat.power), tag.span("Step in") ]), game_step_in_path(game.public_id, seat.power, phase.number), class: "list__row" %></li>
    <% end %>
  </ul>
<% end %>
```

`app/views/hosts/show.html.erb`: one line at the end of the `.host-section`, after the Seats `</ul>`: `<%= render "step_ins/entry", game: @game, seats: @seats, phase: @phase %>`. `app/views/reissues/show.html.erb`: add `<p>If you open the new link on your own phone, that counts as stepping into this seat: you will be asked to confirm, and it is recorded.</p>`.

**Existing specs that read the host page's lists.** `spec/requests/reissue_spec.rb` (lines 29 to 38) counts `.host-section ul.list > li` and the reissue links, and the entry list is a second `ul.list` in that section. The entry list carries `data-step-in-entry`, and those selectors become `.host-section ul.list:not([data-step-in-entry])` (the test changes, not #24's markup). `phase_pages_spec.rb:75` counts the same list (7 rows) and gets the same selector; `host_spec.rb:219` is checked for the same pattern.

**Verify:** the new spec, `spec/requests/reissue*_spec.rb`, `host_spec.rb`, `player_spec.rb`, `order_screen_spec.rb`, `games_spec.rb` stay green.

## Phase 4: The owner's notice, the history and the time

**Implements:** D6, FR-4. **Satisfies:** AC-6.1 to AC-6.6, AC-7.2's notice.
**Files:** create `spec/requests/step_in_notices_spec.rb`, `spec/helpers/step_ins_helper_spec.rb`, `app/helpers/step_ins_helper.rb`, `app/views/step_ins/_notices.html.erb`, `app/views/step_ins/_history.html.erb`; change `app/views/games/show.html.erb`, `app/views/seat_orders/show.html.erb`, `app/views/hosts/show.html.erb`.

### 4a. Tests first (red)

`spec/helpers/step_ins_helper_spec.rb`: `table_time(Time.utc(2026, 11, 26, 20, 42))` is `<time datetime="2026-11-26T20:42:00Z">8:42 PM UTC</time>` with the variable unset; `3:42 PM EST` with `TRUCEBEARER_TIME_ZONE=America/New_York` (set and restored in an `around`); `Not/AZone` and blank give UTC; `Europe/London` in June gives the zone's abbreviation.

`spec/requests/step_in_notices_spec.rb`:
- AC-6.1 and 6.2: after the host steps into France (time frozen at 20:42 UTC), France's phone gets one `.banner--warning` on `/games/:id` and on `/games/:id/phases/1/orders` reading "The host entered your orders at 8:42 PM UTC." with `<time datetime="2026-11-26T20:42:00Z">`; a second step-in at 21:05 makes the one banner read "…at 8:42 PM UTC, 9:05 PM UTC.".
- AC-6.3: the stepped-in host's own view of France's screen has no such banner; England's seat page and screen have none; no page of England's names France or the host's entering.
- AC-6.4: after a reveal France's pages have no banner, and the host page's "Step-ins" list shows one row with "Spring 1901 · Movement", France's badge and "8:42 PM UTC".
- AC-6.6: the list has no `select`, no "ordered", no digit-of-digit count.

### 4b. The code

`app/helpers/step_ins_helper.rb`:

```ruby
# The time of a step-in as the table reads it (spec 026 D6): the 12-hour clock with the zone's abbreviation, in the zone named by
# TRUCEBEARER_TIME_ZONE, or UTC. It is read each time a page is drawn, so nothing is fixed at boot.
module StepInsHelper
  ZONE_VARIABLE = "TRUCEBEARER_TIME_ZONE".freeze

  def table_zone = ActiveSupport::TimeZone[ENV[ZONE_VARIABLE].to_s] || ActiveSupport::TimeZone["UTC"]

  def table_time(time)
    tag.time(time.in_time_zone(table_zone).strftime("%-l:%M %p %Z"), datetime: time.utc.iso8601)
  end
end
```

`app/views/step_ins/_notices.html.erb`:

```erb
<%# The owner's notice (spec 026 D6): one banner listing the open phase's step-ins into this seat. locals: seat, phase %>
<% times = seat.step_in_times(phase) %>
<% if times.any? %>
  <%= render "shared/banner", kind: "warning", text: safe_join([ "The host entered your orders at ", safe_join(times.map { |time| table_time(time) }, ", "), "." ]) %>
<% end %>
```

`app/views/step_ins/_history.html.erb` (reads through the game; one section; its own partial):

```erb
<%# The game's step-ins, oldest first (spec 026 D6). Times, powers and phases only. locals: game %>
<% entries = game.step_in_history.to_a %>
<section class="stack" aria-labelledby="step-ins-heading" data-step-ins>
  <h2 id="step-ins-heading">Step-ins</h2>
  <% if entries.empty? %>
    <p>The host has not stepped into a seat.</p>
  <% else %>
    <ul class="list">
      <% entries.each do |entry| %>
        <li><div class="list__row"><span class="mono"><%= entry.phase.title %></span> <%= power_badge(entry.seat.power) %> <span class="text-muted"><%= table_time(entry.created_at) %></span></div></li>
      <% end %>
    </ul>
  <% end %>
</section>
```

Render lines: `hosts/show` after the history `</section>`: `<%= render "step_ins/history", game: @game %>`; `games/show` after the "Enter orders" link: `<%= render "step_ins/notices", seat: @seat, phase: @phase %>`; `seat_orders/show` after the phase header: `<%= render "step_ins/notices", seat: @seat, phase: @phase unless @stepped_in_page %>`. The confirmation page (`step_ins/show`) keeps its time-free sentence from Phase 1: it is swept for every host viewer, so it draws no clock.

**Verify:** the two new specs plus the full request suite (the existing host-page secrecy checks must stay green: no `ordered`, no `select`).

## Phase 5: Secrecy: the route table, the sweep and the scans

**Implements:** FR-5, D3, D4, D5. **Satisfies:** AC-8.1 to AC-8.8.
**Files:** change `spec/support/secrecy_routes.rb`, `spec/support/responses.rb`, `spec/requests/order_secrecy_spec.rb`, `spec/requests/forgery_spec.rb`; create `spec/models/step_in_boundary_spec.rb`; keep `spec/models/seat_write_scan_spec.rb` and `spec/models/saved_order_boundary_spec.rb` unchanged.

### 5a. The classification, in code (the rows were added in Phases 1 and 2 so the suite stayed green; Phase 5 completes them: the `:stepped_in` assertion, the seat-link entry's `why`, the sweep viewers and the examples)

`spec/support/secrecy_routes.rb`, `APP` entries (the paths are for England, France is added by the Hash form):

```ruby
    "GET /games/:public_id/host/seats/:power/phases/:number/step-in" => { shows: :none, sweep: ->(c) { "/games/#{c.id}/host/seats/england/phases/1/step-in" }, why: "a confirmation page; it shows no order and writes nothing (spec 026)" },
    "POST /games/:public_id/host/seats/:power/phases/:number/step-in" => { shows: :none, why: "records the step-in, sets a cookie of the row's id, redirects" },
    "DELETE /games/:public_id/host/seats/:power/step-in" => { shows: :none, why: "deletes the cookie and redirects" },
    "GET /games/:public_id/host/seats/:power/phases/:number/orders" => {
      shows: :stepped_in,
      sweep: ->(c) { { "england" => "/games/#{c.id}/host/seats/england/phases/1/orders", "france" => "/games/#{c.id}/host/seats/france/phases/1/orders" } },
      why: "one seat's own orders, to the host, only inside a recorded step-in into that seat (spec 026)"
    },
    "PUT /games/:public_id/host/seats/:power/phases/:number/orders" => { shows: :stepped_in, why: "saves one seat's orders for the host inside a step-in; the reply shows only that seat" },
    "GET /games/:public_id/host/seats/:power/phases/:number/orders/:province" => {
      shows: :stepped_in,
      sweep: ->(c) { { "england lon" => "/games/#{c.id}/host/seats/england/phases/1/orders/lon?draft%5Bkind%5D=support&draft%5Btarget%5D=edi",
                       "france par" => "/games/#{c.id}/host/seats/france/phases/1/orders/par?draft%5Bkind%5D=support&draft%5Btarget%5D=bre" } },
      why: "one seat's picker steps for the host inside a step-in into that seat"
    },
```

The `GET /games/:public_id/seat-link` entry's `why` becomes "sets a cookie and redirects; a host browser is redirected to the step-in confirmation instead (spec 026 D5)". Its sweep stays `fresh`.

### 5b. `spec/requests/order_secrecy_spec.rb`

- The "marks as showing orders only…" example keeps its four-route `:own` assertion as is and gains a second one: the `:stepped_in` keys are exactly the three stepped-in order routes (AC-8.1).
- `viewers` gains two sessions, each built when the viewers are set up (before the baseline): `"the host, with France's seat cookie"` (a session that opens France's seat link, then the host link) and `"the host, stepped into France"` (its own session: host link, then the step-in confirmation for France, so the banner and the cookie are the same in every snapshot). The first of these undoes itself: its first own-seat request deletes the `seat_<id>` cookie (spec 026 D5). So the sweep restores it: a `restored` hash maps each such session to its saved raw cookie, and `snapshot` puts it back in the jar before every request (`session.cookies["seat_#{id}"] = value`); without that the next snapshot would see a host with no seat and the comparison would fail for the wrong reason. The `host_without_seat` session in the existing `let` stays.
- The example "answers the same whether England has submitted or not" (`order_secrecy_spec.rb:188-190`) excepts the reveal page for `hosts`; both new viewers hold the host cookie and see the pending list, so both join `hosts`.
- The baseline example gains positive controls: the stepped-in host's France screen is 200 and England's is 404; the host with France's cookie is redirected (302) on the own-seat routes; the host without a step-in gets 404 on both of England's stepped-in routes (AC-8.2).
- New example (AC-8.3): the host steps into England; England's screen shows England's `.unit-row__order` text (positive control), France's URLs are 404 and carry no France order, and the host's own seat page, host page and reveal page are the same before and after England's orders change.
- New example (AC-8.4, recorded before shown): a log of every request the host makes in order (the confirmation GET, the screen GET before confirming, the confirming POST, the screen GET after), each entry saying whether an `INSERT INTO "step_ins"` ran during the request (a `sql.active_record` subscriber) and whether the response body contains France's order text. The example asserts that no entry with the order text comes before the entry with the INSERT, and that the entry with the INSERT is the confirming POST (whose redirect body carries no order).
- New example (AC-8.5): the host page, the reveal page and the confirmation page for the host stepped into France contain no France order JSON or count.

### 5c. The rest

`spec/support/responses.rb`: `comparable` greps `/\A(?:host|seat|step_in)_/` (AC-8.8). `spec/requests/forgery_spec.rb`: France takes a seat first (`game.take_seat!("france")`), `state` gains `StepIn.count`, and two examples use `post_without_token`: the confirmation POST and the Leave `DELETE` (verb `:delete`) are refused without a token and the state is unchanged; a control posts the confirmation with the forgery check off and sees `StepIn.count` rise by one, so the refusal is not just a missing route. `spec/models/step_in_boundary_spec.rb`:

```ruby
require "spec_helper"

# Spec 026 AC-8.6: who may name the step-in record. A text scan is a tripwire, not a proof.
RSpec.describe "The step-in boundary" do
  root = File.expand_path("../..", __dir__)
  files = Dir.glob(File.join(root, "{app,lib,db}/**/*")).select { |path| File.file?(path) && !path.end_with?(".enc") }
  naming = files.select { |path| File.binread(path).force_encoding("UTF-8").scrub.match?(/\bStepIn\b/) }.map { |path| path.delete_prefix("#{root}/") }

  it "names the StepIn constant only in its own files, the access code and the schema" do
    allowed = %w[app/models/step_in.rb app/models/game.rb app/controllers/step_ins_controller.rb app/controllers/concerns/game_access.rb db/schema.rb]
    outside = naming.reject { |path| allowed.include?(path) || path.match?(%r{\Adb/migrate/\d+_create_step_ins\.rb\z}) }

    expect(outside).to be_empty, "names StepIn outside the boundary: #{outside.join(', ')}"
    expect(naming).to include("app/models/step_in.rb", "app/controllers/step_ins_controller.rb")
  end
end
```

(`CreateStepIns` in the migration does not match `\bStepIn\b`, so the migration needs no entry; the schema has no such constant either, so `db/schema.rb` stays in the list harmlessly.) `seat_write_scan_spec` and `saved_order_boundary_spec` are run, not edited: AC-4.4.

**Verify:** `bundle exec rspec spec/requests/order_secrecy_spec.rb spec/requests/forgery_spec.rb spec/models`, then the whole suite.

## Phase 6: 360 pixels, screenshots, the documents, and the proof

**Implements:** NFR layout, D6's configuration. **Satisfies:** AC-9.1, AC-9.2.
**Files:** create `spec/system/step_in_screens_spec.rb`, `docs/specs/026-step-in/screens/*.png`; change `README.md`, `config/deploy.yml`, `docs/design-system.md`, `docs/specs/021-create-game-join-qr/spec.md` (changelog row), `docs/specs/022-phase-lifecycle/spec.md` (changelog row), `spec/system/screens_layout_spec.rb` (only if it lists screens).

### 6a. The system spec (red first: the pages don't exist in a browser check until the previous phases are done, so it is written against the finished pages and run last)

`spec/system/step_in_screens_spec.rb`, modelled on `order_pickers_spec.rb` (`with_viewport(360)` is shared; `measure_step` and `screenshot` are local `def`s there, so this spec defines its own copies, with `SCREENSHOTS` as the output directory): start a game as the host (Germany) with `Game.start!`, take France, give France an order, visit the host link and the seat link to sign the browser in as the host. At 360 pixels:

1. the host page with the "Step into a seat" list (`01-host-step-in-list`);
2. the confirmation page (`02-confirmation`), then tap "Step into France";
3. the stepped-in order screen with the bar, and its Leave button within the first screen height (`03-stepped-in-orders`);
4. the host's own seat page while stepped in (`04-still-stepped-in`);
5. Leave, then a second browser session as France's player (the France seat link in a new Capybara session) shows the notice on the seat page (`05-owner-notice`).

Each page: no sideways scroll, no control under 44 by 44 (`measure_step`), and for page 3 `getBoundingClientRect` of the Leave button has `bottom <= window.innerHeight` (AC-9.1). `SCREENSHOTS=docs/specs/026-step-in/screens bundle exec rspec spec/system/step_in_screens_spec.rb` writes the five images.

### 6b. Configuration and documents

- `README.md`, "Playtest access" section: a paragraph for `TRUCEBEARER_TIME_ZONE` (a Rails zone name such as `America/New_York`; the step-in notice shows the time in it; unset or unknown means UTC; the abbreviation is always shown).
- `config/deploy.yml`, `env.clear`: `TRUCEBEARER_TIME_ZONE: UTC` with a comment "the table's time zone for step-in notices, for example America/New_York".
- `docs/design-system.md`: the Banner row's note keeps "Acting as Italy" and adds "(#26 built: the step-in bar, `step_ins/_bar`)"; the Confirmation page row adds "#26 uses it, danger variant". No new component row (nothing new is built).
- `docs/specs/021-create-game-join-qr/spec.md`: a changelog row "Amended by spec 026: a host cookie opening another seat's link is sent to the step-in confirmation and no seat cookie is stored (026 D5)". `docs/specs/022-phase-lifecycle/spec.md`: a changelog row "D9's open question is closed by spec 026".

### 6c. The proof (from `web/`)

```
bundle exec rspec                       # all, system specs included
bin/brakeman --no-pager -q              # clean
bin/rubocop                             # clean
git diff --name-only main...HEAD        # every path starts with web/
```

Then the implementation review (Opus, read-only), its findings recorded in the pull request, `sdd-superpowers:session-wrap`, push (draft PR), the `Web specs` job green, `gh pr ready`, `gh pr edit --add-assignee @me`.

## Coverage of the spec

| Spec item | Phase |
|---|---|
| Story 1 (AC-1.1 to 1.7) | 1 (1.6 in 3) |
| Story 2 (AC-2.1 to 2.7) | 1 (2.7), 2 |
| Story 3 (AC-3.1 to 3.9) | 2 (3.9 in 3) |
| Story 4 (AC-4.1 to 4.6) | 2 |
| Story 5 (AC-5.1 to 5.4) | 2 |
| Story 6 (AC-6.1 to 6.6) | 4 |
| Story 7 (AC-7.1 to 7.7) | 3 (7.2's notice in 4) |
| Story 8 (AC-8.1 to 8.8) | 5 (8.6's headers in 2) |
| Story 9 (AC-9.1, 9.2) | 6 |
| FR-1 / FR-2 / FR-3 / FR-4 / FR-5 | 1 / 2 / 3 / 4 / 5 |
| D6 configuration (README, `deploy.yml`) | 6 |

## Risks the plan names

- **`db/schema.rb` and routes will conflict with #24 on merge.** Mitigation: the migration timestamp is distinct; routes are added in one contiguous block; `hosts/show` gets two one-line renders in places #24 is unlikely to edit (the end of `.host-section`, after the history section). When the coordinator says `main` moved, merge `origin/main`, keep both tables, and re-run the suite.
- **The resolver's host-cookie rule could break an existing spec** that gives a host session a seat other than the first. Mitigation: Phase 3 runs the whole suite; the sweep's own host viewer holds the first seat (the one `create_game` makes).
- **`readonly?` on `StepIn`** makes `update_columns` and `touch` raise too. Intended; specs that need time travel use `travel`, never an update.
- **`helper_method` inside the existing `GameAccess` concern.** `GameAccess` has no `included` block today; Phase 2 adds one. If `helper_method` is unavailable in a plain concern include order, the same two helpers move to `ApplicationController` with no change to callers.
- **A cookie value of the wrong type.** `active_step_in` accepts only an Integer from the signed cookie, so a signed string or hash is ignored (AC-5.3).

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 1.0.1 | 2026-11-26 | Changed after the first Opus review: `create` and the callbacks' `only:` arrive together; the route-table rows and the `reveal_post_spec` list are updated in the phase that adds the routes; the host page's lists get a data attribute and two specs' selectors change; no clock on the swept confirmation page; the sweep's seat-cookie viewer is restored before every request and both new viewers join the `hosts` exception; the 409 page clears the bar; helpers use `@seat`; test additions for AC-3.7, AC-8.6, AC-3.8, the explicit game check, the forgery control and the SQL-ordered record test |
| 1.0.0 | 2026-11-26 | First draft |

---

# Amendment 1.1.0: record seat reissues (Issue #104)

Spec: `spec.md` v1.1.0 (Approved at Gate A for #104; D10, Story 10 AC-10.1 to AC-10.8, and the changes to AC-6.4, AC-6.6, AC-8.5, AC-8.6, AC-9.1). Spec 021 v1.4.0 (AC-7.11, AC-7.12). Branch `web/104-reissue-history`. Everything here is under `web/`.

## Goal

Every reissue writes one append-only `reissues` row in the reissue's own transaction, and the host page's history ("Seat history") shows step-ins and reissues together, oldest first. Test first: the request spec of 1a is written and seen red before any code. Three phases, each ending green. No new route, no new CSS, no JavaScript, no gem.

## Gates checked

- **Simplicity:** one new table and model (`Reissue`), two small methods on `Game`, one partial rewritten. No controller, no route, no service object.
- **Anti-abstraction:** `Reissue` and `StepIn` share a shape but no base class or concern: the two have different rules (a step-in has a cookie and `active?`, a reissue has neither) and a shared parent would be the `kind`-filter risk the spec rejects (D10). Each defines `kind` itself; the partial never names either constant.
- **Integration first:** the request spec (1a) goes through the real `POST .../reissue` and `GET .../host`.
- **One side:** only `web/`.

## Decisions the plan adds (each traceable to the spec)

- **A1. Migration `20261126150000_create_reissues.rb`**, later than `20261126140500`; `db/schema.rb` is regenerated by running it (D10).
- **A2. `Game#reissue_seat!` keeps its shape.** The block's last value stays `clear_orders!`'s result; `Reissue.record!` goes before it, so `withdrew` is unchanged and spec 024's broadcast rule holds (D10, AC-10.2).
- **A3. `Game#seat_history` sorts by `[created_at, kind rank, id]`** with a reissue ranked 0 and a step-in 1 (D10 tie-break). `created_at` has sub-second precision in SQLite, so the tie-break matters only under `travel_to`, which freezes time and so is how the spec tests it.
- **A4. The section's hook is `data-seat-history`**, its heading id `seat-history-heading`, its empty text "Nothing has happened to a seat yet." The existing `step_in_notices_spec` examples follow (D10).
- **A5. Scan pattern:** `/\bReissue(?:\.|::|\s*<)/` in a new example of `spec/models/step_in_boundary_spec.rb`. It does not match "Reissue seat" or `ReissuesController`, so only `app/models/reissue.rb` and `app/models/game.rb` may name the constant (AC-10.7). The migration and schema never match it (`CreateReissues`, `"reissues"`).

## Phase 1: the first test, the table, the model and the write

**Implements:** D10 (the table, the model, the write). **Satisfies:** AC-10.2, AC-10.3, AC-10.5, spec 021 AC-7.11.
**Files:** create `spec/requests/reissue_history_spec.rb`, `db/migrate/20261126150000_create_reissues.rb`, `app/models/reissue.rb`, `spec/models/reissue_spec.rb`; change `app/models/step_in.rb`, `app/models/game.rb`, `db/schema.rb`, `spec/models/game_spec.rb`, `spec/requests/forgery_spec.rb`

### 1a. The first test (red). It fails until the row and the history exist

`spec/requests/reissue_history_spec.rb`:

```ruby
require "rails_helper"
require_relative "../support/rules_helpers"

# Spec 026 D10 and Story 10: every reissue leaves a row, and the host page's history shows it with a time and no order.
RSpec.describe "The reissue history", type: :request do
  include RulesHelpers

  around { |example| with_passphrase { example.run } }

  let(:created) { create_game(power: "germany") }
  let(:game) { created.game }
  let(:id) { game.public_id }
  let(:host) { created.session }
  let!(:france_and_token) { game.take_seat!("france") }
  let(:france) { france_and_token.first }

  def page = Nokogiri::HTML5(host.response.body)

  def reissue(power) = host.post("/games/#{id}/host/seats/#{power}/reissue")

  def history = page.at_css("[data-seat-history]")

  # Reissues, follows the redirect to the one-time QR page, and returns the new token the new phone would scan.
  def reissue_and_read_token(power)
    reissue(power)
    host.follow_redirect!
    page.at_css(".qr-card__link").text[/token=(.+)\z/, 1]
  end

  it "shows France's reissue on the host page with the phase and the time, and no order (AC-10.1)" do
    france.save_orders!(game.current_phase, { "par" => json_of(rules_order(:hold, :france, :par)) }, submit: true)
    travel_to(Time.utc(2026, 11, 26, 20, 40)) { reissue("france") }
    host.get "/games/#{id}/host"

    expect(history).not_to be_nil # red for the right reason: the section is not on the page yet
    expect(history.css("li").map { |row| row.text.squish }).to eq([ "#{game.current_phase.title} France seat reissued 8:40 PM UTC" ])
    expect(history.at_css("time")["datetime"]).to eq("2026-11-26T20:40:00Z")
    expect(history.css("select, option, a")).to be_empty
    expect(history.text).not_to match(/\bHold\b|\bPAR\b|ordered|Submitted|\d of \d|token/)
  end
end
```

Run it: `bundle exec rspec spec/requests/reissue_history_spec.rb`. It must fail on its first assertion, `history` being nil because `[data-seat-history]` is not on the page, not because of a typo. It stays uncommitted until Phase 2 turns it green.

### 1b. The model spec (red), then the migration and the model

`spec/models/reissue_spec.rb`:

```ruby
require "rails_helper"

# Spec 026 D10, AC-10.5: the record is append-only and holds no order.
RSpec.describe Reissue do
  let(:game) { Game.start!(power: "germany").game }
  let(:france) { game.take_seat!("france").first }
  let(:phase) { game.current_phase }

  it "writes one row with the phase and the seat" do
    row = described_class.record!(phase: phase, seat: france)

    expect(row).to be_persisted
    expect([ row.phase, row.seat ]).to eq([ phase, france ])
    expect(row.created_at).to be_within(5.seconds).of(Time.current)
    expect(row.kind).to eq(:reissue)
  end

  it "refuses a seat of another game" do
    other = Game.start!(power: "england").game.seats.first

    expect { described_class.record!(phase: phase, seat: other) }.to raise_error(ActiveRecord::RecordInvalid)
  end

  it "can't be changed or deleted" do
    row = described_class.record!(phase: phase, seat: france)

    expect { row.update!(seat: game.seats.first) }.to raise_error(ActiveRecord::ReadOnlyRecord)
    expect { row.destroy }.to raise_error(ActiveRecord::ReadOnlyRecord)
    expect(described_class.count).to eq(1)
  end

  it "has no column that could hold an order or a count" do
    expect(described_class.column_names).to match_array(%w[id phase_id seat_id created_at])
  end
end
```

`db/migrate/20261126150000_create_reissues.rb`:

```ruby
# One row each time the host reissues a seat (spec 026 D10). Append-only: the model refuses update and destroy.
class CreateReissues < ActiveRecord::Migration[8.1]
  def change
    create_table :reissues do |t|
      t.references :phase, null: false, foreign_key: true
      t.references :seat, null: false, foreign_key: true
      t.datetime :created_at, null: false
    end
  end
end
```

`app/models/reissue.rb`:

```ruby
# One time the host reissued a seat, in the phase that was open (spec 026 D10). It never changes and is never deleted. It holds no
# order, no count of orders, and nothing about the token.
class Reissue < ApplicationRecord
  belongs_to :phase
  belongs_to :seat

  validate { errors.add(:seat, "is not in this game") unless seat && phase && seat.game_id == phase.game_id }

  # A written row can't be changed or removed: update and destroy raise ActiveRecord::ReadOnlyRecord.
  def readonly? = persisted? || super

  def self.record!(phase:, seat:) = create!(phase: phase, seat: seat)

  def kind = :reissue
end
```

`app/models/step_in.rb` gets one line (additive; nothing else in the class changes):

```ruby
  def kind = :step_in
```

Then `bin/rails db:migrate` (it rewrites `db/schema.rb` to version `2026_11_26_150000` with the `reissues` table and its two foreign keys), and `RAILS_ENV=test bin/rails db:schema:load` if the test database needs it.

### 1c. The write, test first

Add to the existing `describe "#reissue_seat!"` at `spec/models/game_spec.rb:114` (use its `let`s; add a `let!(:france)` only if it has none), these examples:

```ruby
      it "writes one reissues row for the open phase and the seat, one for each reissue (AC-10.2)" do
        game.reissue_seat!(france)
        game.reissue_seat!(france)

        expect(Reissue.where(seat: france, phase: game.current_phase).count).to eq(2)
      end

      it "writes a row for the host's own seat too (AC-10.3)" do
        game.reissue_seat!(game.host_seat)

        expect(Reissue.where(seat: game.host_seat).count).to eq(1)
      end

      it "leaves the old token and no row when the row can't be written (AC-10.2)" do
        digest = france.token_digest
        allow(Reissue).to receive(:record!).and_raise(ActiveRecord::RecordInvalid)

        expect { game.reissue_seat!(france) }.to raise_error(ActiveRecord::RecordInvalid)
        expect(france.reload.token_digest).to eq(digest)
        expect(Reissue.count).to eq(0)
      end
```

Run it red, then change `Game#reissue_seat!` in `app/models/game.rb` (the lines inside the transaction):

```ruby
    withdrew = transaction do
      phase = phases.lock.find_by!(revealed_at: nil) # read under the lock, so a reveal can't slip in between
      seat.update!(token_digest: Token.digest(token))
      withdrawn = seat.clear_orders!(phase)
      Reissue.record!(phase: phase, seat: seat) # spec 026 D10: the reissue and its record stand or fall together
      withdrawn # the block's value, as before: whether a submission was removed (spec 024 D3)
    end
```

In `spec/requests/forgery_spec.rb` the `state` helper (line 17) gets `Reissue.count` appended, so the existing no-token reissue example proves a refused reissue writes no row (AC-10.2); it is red-then-green with the model, since `Reissue` does not exist before 1b.

The broadcast example at `spec/models/seat_status_broadcast_spec.rb:76` (one broadcast for a submitted seat, none for an unsubmitted one) already runs through this method and is the proof of AC-10.2's no-broadcast rule; it must stay green unchanged.

**Check:** `bundle exec rspec --exclude-pattern spec/requests/reissue_history_spec.rb --exclude-pattern 'spec/system/**/*_spec.rb'` green (the reissue, forgery and clears-orders request specs and the model specs all exercise the changed method). `spec/requests/reissue_history_spec.rb` is still red, by design. **Commit:** "Record each seat reissue in a reissues table" (the migration, model, schema, `Game`, `StepIn#kind` and the model specs; not the request spec).

## Phase 2: the history lists both, oldest first

**Implements:** D10 (reads, the partial). **Satisfies:** AC-10.1, AC-10.4, AC-10.8, AC-6.4, AC-6.6.
**Files:** change `app/models/game.rb`, `app/views/step_ins/_history.html.erb`, `app/helpers/step_ins_helper.rb` (header comment only: "a step-in or a reissue"), `spec/models/game_spec.rb`, `spec/requests/reissue_history_spec.rb`, `spec/requests/step_in_notices_spec.rb`

### 2a. Tests (red)

In `spec/models/game_spec.rb`, next to the existing `step_in_history` example:

```ruby
    it "lists this game's reissues and no other game's, and merges them with the step-ins, oldest first, a reissue before a step-in at the same instant (D10)" do
      game = described_class.start!(power: "germany").game
      other = described_class.start!(power: "germany").game
      england = game.take_seat!("england").first
      other_england = other.take_seat!("england").first
      step_in = reissue = later = nil
      travel_to(Time.utc(2026, 11, 26, 20, 0)) do
        step_in = StepIn.record!(phase: game.current_phase, seat: england)
        reissue = Reissue.record!(phase: game.current_phase, seat: england)
        Reissue.record!(phase: other.current_phase, seat: other_england)
      end
      travel_to(Time.utc(2026, 11, 26, 21, 0)) { later = Reissue.record!(phase: game.current_phase, seat: england) }

      expect(game.reissue_history.to_a).to eq([ reissue, later ])
      expect(game.seat_history).to eq([ reissue, step_in, later ])
    end
```

Add to `spec/requests/reissue_history_spec.rb`, inside the describe:

```ruby
  it "carries no token or link of the reissue in the history (AC-10.6)" do
    token = reissue_and_read_token("france")
    host.get "/games/#{id}/host"

    expect(token).to be_present
    expect(history.to_html).not_to include(token)
  end

  it "lists a step-in and reissues together in time order, and keeps an earlier phase's rows after its reveal (AC-10.4)" do
    game.take_seat!("england")
    first_title = game.current_phase.title
    travel_to(Time.utc(2026, 11, 26, 20, 30)) { host.post "/games/#{id}/host/seats/england/phases/1/step-in" }
    travel_to(Time.utc(2026, 11, 26, 20, 40)) { reissue("france") }
    game.current_phase.reveal!
    second_title = game.current_phase.title
    travel_to(Time.utc(2026, 11, 26, 22, 0)) { reissue("england") }
    host.get "/games/#{id}/host"

    expect(history.css("li").map { |row| row.text.squish }).to eq([
      "#{first_title} England stepped in 8:30 PM UTC",
      "#{first_title} France seat reissued 8:40 PM UTC",
      "#{second_title} England seat reissued 10:00 PM UTC"
    ])
  end

  it "reads with the table's time zone (AC-6.5)" do
    travel_to(Time.utc(2026, 11, 26, 20, 40)) { reissue("france") }
    original = ENV["TRUCEBEARER_TIME_ZONE"]
    begin
      ENV["TRUCEBEARER_TIME_ZONE"] = "America/New_York"
      host.get "/games/#{id}/host"
    ensure
      ENV["TRUCEBEARER_TIME_ZONE"] = original
    end

    expect(history.text).to include("3:40 PM EST")
  end

  it "says so when nothing has happened (AC-6.4)" do
    host.get "/games/#{id}/host"

    expect(history.text).to include("Nothing has happened to a seat yet.")
  end

  it "writes no row for a reissue that is refused (AC-10.2)" do
    stranger = open_session
    stranger.post "/games/#{id}/host/seats/france/reissue"
    france_phone = open_session
    france_phone.get "/games/#{id}/seat-link", params: { token: france_and_token.last }
    france_phone.post "/games/#{id}/host/seats/france/reissue" # a seat's own phone is not the host's
    host.post "/games/#{id}/host/seats/england/reissue" # no seat is held by England
    host.post "/games/#{id}/host/seats/nowhere/reissue"

    expect(Reissue.count).to eq(0)
  end

  it "adds nothing to any seat's own pages, and shows the history only to the host (AC-10.8, spec 021 AC-7.12)" do
    england_token = game.take_seat!("england").last
    france_token = reissue_and_read_token("france")
    phones = [ france_token, england_token ].map do |token|
      open_session.tap { |phone| phone.get "/games/#{id}/seat-link", params: { token: token } }
    end

    phones.each do |phone|
      [ "/games/#{id}", "/games/#{id}/phases/1/orders" ].each do |path|
        phone.get path
        doc = Nokogiri::HTML5(phone.response.body)
        expect(doc.css(".banner--warning").map(&:text).join).not_to match(/reissue/i), path
        expect(phone.response.body).not_to match(/reissued|Seat history/), path
      end
    end
  end
```

(The example sets and restores the variable by hand, as `spec/helpers/step_ins_helper_spec.rb` does for AC-6.5; no gem is added.)

Update `spec/requests/step_in_notices_spec.rb` (the three examples at lines 74-106): `[data-step-ins]` becomes `[data-seat-history]`; the row becomes `"Spring 1901 · Movement France stepped in 8:42 PM UTC"`; the empty text becomes "Nothing has happened to a seat yet."

### 2b. The reads and the partial

`app/models/game.rb`, under `step_in_history`:

```ruby
  # Every reissue of this game, oldest first (spec 026 D10). Read through the phases, as the step-ins are.
  def reissue_history = Reissue.joins(:phase).where(phases: { game_id: id }).includes(:phase, :seat).order(:id)

  # The step-ins and the reissues together, oldest first; at the same instant a reissue comes before a step-in (D10).
  def seat_history
    (reissue_history.to_a + step_in_history.to_a).sort_by { |entry| [ entry.created_at, entry.kind == :reissue ? 0 : 1, entry.id ] }
  end
```

`app/views/step_ins/_history.html.erb`:

```erb
<%# The game's seat history: each step-in and each reissue, oldest first (spec 026 D6, D10). Phases, powers and times only. locals: game %>
<% entries = game.seat_history %>
<section class="stack" aria-labelledby="seat-history-heading" data-seat-history>
  <h2 id="seat-history-heading">Seat history</h2>
  <% if entries.empty? %>
    <p>Nothing has happened to a seat yet.</p>
  <% else %>
    <ul class="list">
      <% entries.each do |entry| %>
        <li><div class="list__row"><span class="mono"><%= entry.phase.title %></span> <%= power_badge(entry.seat.power) %> <span><%= entry.kind == :reissue ? "seat reissued" : "stepped in" %></span> <span class="text-muted"><%= table_time(entry.created_at) %></span></div></li>
      <% end %>
    </ul>
  <% end %>
</section>
```

`hosts/show` is not touched (it already renders `step_ins/history`).

**Check:** `bundle exec rspec spec/requests/reissue_history_spec.rb spec/requests/step_in_notices_spec.rb spec/models/game_spec.rb` green; then `bundle exec rspec` (the whole suite, minus the system specs if Chrome is slow) green. **Commit:** "Show reissues and step-ins together in the seat history".

## Phase 3: secrecy, the layout and the record

**Implements:** FR-5, D10 boundary. **Satisfies:** AC-8.5, AC-8.6, AC-9.1, AC-10.6, AC-10.7, spec 021 AC-7.12.
**Files:** change `spec/models/step_in_boundary_spec.rb`, `spec/requests/order_secrecy_spec.rb`, `spec/support/secrecy_routes.rb`, `spec/system/step_in_screens_spec.rb`, `docs/specs/026-step-in/screens/` (new `06-seat-history.png`), `docs/specs/026-step-in/plan.md` (this section)

### 3a. The scan (a guard, with a control)

Add to `spec/models/step_in_boundary_spec.rb` (the `files` list is the same):

```ruby
  reissue_pattern = /\bReissue(?:\.|::|\s*<)/

  it "names the Reissue constant only in its own file and Game (AC-10.7, a guard: it passes as soon as Phase 1 is in)" do
    reissue_users = files.select { |path| File.binread(path).force_encoding("UTF-8").scrub.match?(reissue_pattern) }.map { |path| path.delete_prefix("#{root}/") }

    expect(reissue_users).to match_array(%w[app/models/reissue.rb app/models/game.rb])
  end

  it "matches a use of the constant and not the word in text or a controller's name (a control for the guard)" do
    expect("Reissue.record!(phase: phase)").to match(reissue_pattern)
    expect("class Reissue < ApplicationRecord").to match(reissue_pattern)
    expect("Reissue seat").not_to match(reissue_pattern)
    expect("class ReissuesController < ApplicationController").not_to match(reissue_pattern)
  end

  it "holds no saved-orders association and no through association for reissues (AC-10.7)" do
    expect(File.read(File.join(root, "app/models/reissue.rb"))).not_to match(/saved_order|SavedOrder|orders_for/i)
    expect(File.read(File.join(root, "app/models/game.rb"))).not_to match(/through:\s*:?reissues/)
    readers = Dir.glob(File.join(root, "app/{views,controllers,helpers}/**/*")).select { |path| File.file?(path) && File.read(path).match?(/\breissues\b/) }

    expect(readers).to be_empty, "reads the reissues table outside the boundary: #{readers.join(', ')}"
  end
```

(Today no file under `app/views`, `app/controllers` or `app/helpers` contains the lowercase plural word `reissues`; `ReissuesController` is capitalized and `reissues/show` is a view path, which `render` calls do not spell out. The routes file is outside the scan.)

### 3b. The sweep gets a reissue row and a step-in row before its baseline (AC-10.6)

In `spec/requests/order_secrecy_spec.rb`, the England seat is made and reissued once, before any viewer session opens (the `viewers` are lazy and are opened later; England's orders only vary after), and its phone uses the new token:

```ruby
    let!(:england_seat_and_token) do
      seat, = game.take_seat!("england")
      [ seat, game.reissue_seat!(seat) ] # a reissue row is in the history before the baseline (spec 026 AC-10.6)
    end
```

The `stepped_in` viewer already writes a step-in row before the first snapshot. The existing comparison then proves the host page (history included) is identical whatever England ordered, for every viewer. Add one positive control in the sweep's describe, so the sweep can't be comparing a page with no history in it:

```ruby
    it "has a reissue row and a step-in row in the host page the sweep compares (AC-10.6)" do
      viewers
      created.session.get "/games/#{id}/host"
      history = Nokogiri::HTML5(created.session.response.body).at_css("[data-seat-history]")

      expect(history.css("li").map { |row| row.text.squish }.join(" ")).to include("seat reissued").and include("stepped in")
    end
```

`spec/support/secrecy_routes.rb`: the `POST .../reissue` entry's `why` becomes "replaces the token, deletes the seat's saved orders for the open phase, and writes a `reissues` row (spec 026 D10)"; the `GET .../host` entry's `why` adds "the seat history (spec 026 D10)". No route is added or reclassified.

### 3c. The 360-pixel system spec and the screenshot (AC-9.1)

Add an example to `spec/system/step_in_screens_spec.rb`:

```ruby
  it "shows the seat history with a step-in row and a reissue row at 360 pixels (AC-9.1)" do
    started = Game.start!(power: "germany")
    game = started.game
    id = game.public_id
    france, = game.take_seat!("france")
    StepIn.record!(phase: game.current_phase, seat: france)
    game.reissue_seat!(france)

    with_viewport(360) do
      visit "/games/#{id}/host-link?token=#{started.host_token}"
      visit "/games/#{id}/host"
      expect(page).to have_css("[data-seat-history] li", count: 2)
      expect(page).to have_css("[data-seat-history]", text: "seat reissued")
      measure("the host page with the seat history")
      execute_script("document.querySelector('[data-seat-history]').scrollIntoView({ block: 'center' })")
      screenshot("06-seat-history")
    end
  end
```

Run once with `SCREENSHOTS=docs/specs/026-step-in/screens bundle exec rspec spec/system/step_in_screens_spec.rb` and look at the image.

### 3d. The plan and the record

This section is appended to `docs/specs/026-step-in/plan.md` (the plan's header line gains "v1.1.0 amended for #104"). If the implementation review finds a spec point to fix, the spec gets a patch row first.

## Proof (from `web/`)

| Done when (Issue #104) | Proof |
|---|---|
| Each reissue adds an append-only row (power, phase, time) | `spec/models/reissue_spec.rb`, `game_spec.rb` "#reissue_seat!" (AC-10.2, 10.3, 10.5) |
| The host page's history shows both, in time order | `spec/requests/reissue_history_spec.rb` (AC-10.1, 10.4), the first test of 1a |
| The specs prove a row is written and that no order ever appears | the same request spec's "no order" assertions, the sweep's host page with both rows (AC-10.6), the scan (AC-10.7) |
| Whole app | `bundle exec rspec` green; `bin/brakeman` and `bin/rubocop` clean; the `Web specs` job green; `git diff --name-only main...HEAD` lists only paths under `web/` |

## Self-review

- **Spec coverage:** AC-10.1 to 10.8 map to 1a, 1c, 2a, 3a, 3b; AC-6.4 and 6.6 to 2a; AC-8.5 to 3b; AC-8.6 to 3a; AC-9.1 to 3c; spec 021 AC-7.11 and 7.12 to 1c and the "adds nothing to a seat's pages" example of 2a.
- **Types:** `Reissue.record!(phase:, seat:)`, `kind` (`:reissue`/`:step_in`), `Game#reissue_history`, `Game#seat_history` are named the same in every phase.
- **Placeholder scan:** none. Every step has its code.

---

# Amendment 1.3.0 (#112): one History on the host page

Spec: `spec.md` v1.3.0, D11 and Story 11 (Gate A approved with specs 025 1.2.0 and 027 1.0.6). Branch `web/112-one-history`. Everything is under `web/`. No migration, route or controller action changes.

## Gates checked

- **Order rule:** sort key is `[time, phase number, kind rank, id]`, with reissue 0, step-in 1, position edit 2, reveal 3 (D11). A reveal's time is the phase's `revealed_at`.
- **Secrecy:** a reveal row holds a title, a time and a link to the existing host results route, for revealed phases only (`Game#history`). The open phase is never a reveal row. `host_history` is read only by the history partial.
- **Seat page** and `results/_section`'s seat behaviour are untouched; the host page passes `earlier: []`.
- **Parallel work:** #105 may edit the host page's results section. The only line this plan edits there is the `earlier:` argument of the one `render` of `results/_section` in `hosts/show.html.erb`; the removed "Revealed phases" block and the partial are elsewhere.

## Files

Create: `spec/requests/host_history_spec.rb` (the first test), `spec/models/game_host_history_spec.rb`.
Change: `app/models/game.rb` (`Game::RevealEntry`, `Game#host_history`; `SEAT_HISTORY_ORDER` gains `reveal: 3`), `app/views/step_ins/_history.html.erb`, `app/views/hosts/show.html.erb` (delete the "Revealed phases" section; `earlier: []`), `app/controllers/hosts_controller.rb` (drop `@earlier`, keep the latest phase local), `README.md` (line 19: "History list"), `spec/support/secrecy_routes.rb` (the host page's `why`), and these specs, which name the old lists: `spec/requests/phase_pages_spec.rb` (`[data-history]`), `spec/requests/reveal_post_spec.rb` (`[data-history]`), `spec/requests/step_in_notices_spec.rb` (line 89's empty text; and the AC-6.4 example at 82-83 reveals outside `travel_to` and expects one row, so it reveals under `travel_to` at 8:43 PM UTC and expects the step-in row then the reveal row), `spec/requests/position_notice_spec.rb` (line 105's "Seat history" heading, line 114's empty text), `spec/requests/reissue_history_spec.rb` (line 83's empty text; AC-10.4's exact rows gain `"#{first_title} revealed 9:00 PM UTC"` third, with the reveal made under `travel_to` at 9:00 PM UTC; AC-10.8 asserts no `[data-seat-history]` on the seat pages), `spec/requests/host_results_spec.rb` (line 86 reads `section[data-results] ul.list a`: it asserts the results section has no `ul.list` and that `[data-seat-history] a` has the two results hrefs), `spec/requests/results_spec.rb` (AC-1.7 host half, new AC-6.4 example), `spec/models/step_in_boundary_spec.rb` (readers pattern gains `host_history`; `RevealEntry` scan), `spec/requests/order_secrecy_spec.rb` (a reveal-row control in the "after one reveal" context), `spec/system/step_in_screens_spec.rb` (History with four kinds at 360 pixels; retakes `docs/specs/026-step-in/screens/06-seat-history.png`), `spec/system/position_editor_screens_spec.rb` (the "History" wording; retakes `docs/specs/027-position-editor/screens/07-host-history.png`), and the plan changelogs of 025 and 027 (one line each).

## Phase A: the first test, then the model

1. **A1. The first test (red).** `spec/requests/host_history_spec.rb`, AC-11.1. A game with the host's seat as Germany, and France's and England's seats taken. Under `travel_to`: France reissued at 8:40 PM UTC, the host stepped into England at 8:41, and the phase revealed through `POST /games/:id/host/phases/1/reveal` at 8:42. The host page then has exactly one `[data-seat-history]` whose `h2` reads "History", whose `li` texts are, in order, "Spring 1901 · Movement France seat reissued 8:40 PM UTC", "Spring 1901 · Movement England stepped in 8:41 PM UTC", "Spring 1901 · Movement revealed 8:42 PM UTC", and the page has no "Earlier results", "Revealed phases" or "Seat history" text and no `[data-history]`. The row list is asserted first, so the first failure shows the missing reveal row. The same file holds the examples of AC-11.3 (the reveal row is an `a[href="/games/:id/host/phases/1/results"]` with `time[datetime]` and no `.outcome-tag`, `.result-row` or order text, and that page is 200 for the host) and the three page states of AC-11.5 (the sentence alone; the sentence above one reissue row; one reveal row and no sentence), each red now. It fails today for the right reason: there are two lists, and the reveal is not in the one that is labelled.
2. **A2. Model specs (red).** `spec/models/game_host_history_spec.rb`: AC-11.2 (one frozen instant made with `Time.current.change(usec: 0)`, as `game_position_edit_spec` does: phase 1's reissue, step-in, position edit and reveal, and phase 2's reissue and position edit sort as the spec says; `seat_history` unchanged; phase 2's rows come from `game.reissue_seat!` and `game.edit_position!(2, ...)` after the reveal), AC-11.5's model example (the open phase is never a reveal entry, with saved orders and a submission in it), and the entry's interface (`kind`, `phase`, `created_at`, `id`). They fail with `NoMethodError`.
3. **A3. Build** `Game::RevealEntry` (a `Data.define(:phase)` with `kind` `:reveal`, `created_at` `phase.revealed_at`, `id` `phase.id`) and `Game#host_history`: `(seat_history + history.map { RevealEntry.new(phase: _1) }).sort_by { |e| [ e.created_at, e.phase.number, SEAT_HISTORY_ORDER.fetch(e.kind), e.id ] }`. `seat_history` is not changed. `bundle exec rspec spec/models/game_host_history_spec.rb spec/models/game_spec.rb spec/models/game_position_edit_spec.rb` passes.

## Phase B: the view, the page and the specs that name the old lists

1. **B1. The partial.** `step_ins/_history` reads `game.host_history`. Heading "History", id `history-heading`, hook `data-seat-history`. When no entry has `kind == :reveal`, a `<p>No phase has been revealed yet.</p>` comes first. Then, only when there is at least one entry, the list: a reveal is `<li>` holding `link_to(game_host_results_path(game.public_id, entry.phase.number), class: "list__row") { title in .mono, "revealed", table_time in .text-muted }`; the other three rows are as they are. With no entry the section is the sentence alone (no empty `ul`). The partial names no model constant.
2. **B2. The host page.** Delete the "Revealed phases" section from `hosts/show.html.erb`; pass `earlier: []` to the one `render` of `results/_section`; `HostsController#show` loses `@earlier` and `@history` (a local finds the latest: `@game.history.order(:number).last`, as `Game#history` has no explicit order). The history partial stays where it is rendered.
3. **B3. Fix the specs that fail** because they name the old lists (the list above), reading each failure, then run `bundle exec rspec spec/requests spec/models spec/views` and `spec/docs` until green. Add the AC-6.4 example to `results_spec.rb` (two reveals: the host page has no "Earlier results", two reveal links that return 200; the seat page still has the list).
4. **B4. Secrecy.** `step_in_boundary_spec.rb`: `host_history` joins the readers pattern, the constant `RevealEntry` (pattern `/\bRevealEntry\b/`) is named only in `game.rb`, where it is written bare inside `Game`. `secrecy_routes.rb`: the host page's `why` mentions the reveal rows. `order_secrecy_spec.rb`: in "after one reveal (spec 025)", a control example, after calling `viewers` first (as the AC-10.6 example does, so the step-in row exists), that the host page's `[data-seat-history]` holds a reveal row, a reissue row, a step-in row and a position edit row; that context's setup already makes all four, with the reveal's `revealed_at` written once before any snapshot, so the compared snapshots agree. The sweep passes unchanged otherwise.

## Phase C: 360 pixels, screenshots, documents and proof

1. `step_in_screens_spec.rb`: the host page at 360 pixels with a reveal, a step-in, a reissue and a board change (AC-11.8): no sideways scroll, every link at least 44 pixels high (the existing `measure`), a long board-change row wraps; retake `06-seat-history.png` with `SCREENSHOTS=docs/specs/026-step-in/screens bundle exec rspec spec/system/step_in_screens_spec.rb`. `position_editor_screens_spec.rb`: wording, retake `07-host-history.png` with `SCREENSHOTS=docs/specs/027-position-editor/screens bundle exec rspec spec/system/position_editor_screens_spec.rb` (the other screenshots of that folder are rewritten with the same pixels; only the two files that changed are kept in the commit).
2. `README.md` line 19; the plan changelogs of 025 and 027; this plan's changelog.
3. **Proof (from `web/`):** `bundle exec rspec` (system specs included); `bin/brakeman`; `bin/rubocop`; the `Web specs` job green on the pull request; `git diff --name-only main...HEAD` lists only paths under `web/`; the 360-pixel screenshot.

| Done when (Issue #112) | Proof |
|---|---|
| One history section, in time order, with clear labels | `host_history_spec.rb` (AC-11.1, AC-11.3, AC-11.5's page states; spec 027's AC-6.2 is AC-11.2), `game_host_history_spec.rb` (AC-11.2), `results_spec.rb` (AC-6.4), `step_in_screens_spec.rb` (AC-11.8) |
| Nothing in it shows an open phase's orders; sweeps and scans pass | `order_secrecy_spec.rb` (AC-11.6), `step_in_boundary_spec.rb` (AC-11.7), `game_host_history_spec.rb` (AC-11.5) |
| Specs 025 and 026 amended, a changelog row each (and 027) | the three changelog rows; `spec/docs/spec_amendments_spec.rb` |

## Risks

- A request spec that asserts an exact row list in a game that has since gained a reveal (AC-10.4 above). Fixed by making the reveal happen under `travel_to`.
- `hosts/show.html.erb` may also change under #105. The edits here are one deleted block and one argument; if `main` moves, merge it and re-run.
- The seat page's results section must not change: `results_partials_spec` and the seat half of `results_spec` guard it.

## Plan changelog

| Version | Change |
|---|---|
| 1.3.0 | Plan for the 1.3.0 amendment (#112), for Gate B |
| 1.3.1 | After the Opus review (4 blocking, 9 non-blocking, all taken; round 1 of 2): AC-11.3 and AC-11.5's page states get tests; five more specs are named with the right fixes (`step_in_notices`, `host_results`, `position_notice`, `reissue_history` line 83, AC-10.4's reveal time); the partial draws no empty list; the scan pattern is `\bRevealEntry\b`; the controller's latest phase is ordered; the screenshot commands are spelled out |

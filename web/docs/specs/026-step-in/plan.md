# Plan 026: The host steps into another seat

Spec: `spec.md` v1.0.2 (Approved at Gate A). Branch `web/26-step-in`. Everything here is under `web/`.

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

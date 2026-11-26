# Plan 022: The phase lifecycle, open until the host reveals

**Spec:** `web/docs/specs/022-phase-lifecycle/spec.md` v1.2.0 (Approved at Gate A)
**Issue:** #22 · **Branch:** `web/22-phase-lifecycle` · **Plan version:** 1.1.1 (after two Opus review rounds; see the changelog at the end)

## Goal

Build phases, saved orders, submissions, the host-only atomic reveal with its confirmation page, the next movement phase, refusals after the reveal, and order secrecy, as the spec says, with the three components `.phase-header`, `.banner` and `.confirm` on `/styleguide`. All work is under `web/`. Each phase is test first (RSpec), ends with its own specs green, and is one commit. Commit messages are plain imperative sentences ending with the `Co-Authored-By:` line the implementing session is given. Every `RulesEngine` call stays in `app/models/rules_engine.rb`; no other file names a gem class (the boundary spec stays green).

## Decisions the plan adds (each is traceable to the spec)

- **Names.** Models `Phase`, `SavedOrder`, `Submission`. Controllers `SeatOrdersController` (show, update) and `RevealsController` (show, create). Partials `phases/_header`, `shared/_banner`, `shared/_confirm`. Helper `OrderLabelHelper`. No service objects: the reveal is `Phase#reveal!`, saving is `Seat#save_orders!`.
- **The reveal's result** is a `Data` value, `Phase::Reveal = Data.define(:status)` with `:revealed` or `:already`. A transaction block is never left with `return` (its outcome would depend on the Rails version); the block's value carries the answer.
- **Phase order.** 1 tables and the first test; 2 the components; 3 the phase on the seat and host pages; 4 the saving rules (model); 5 the orders page and endpoint; 6 reissue clears orders (right after saving exists, so the hole of D9 is never open in a commit that can save); 7 the reveal (two commits: the reveal, then its concurrency specs); 8 secrecy; 9 phone width, screenshots, proof.
- **Refusals are exceptions with a sentence.** `Seat::Refusal < StandardError` (message is the sentence shown to the player), `Phase::Revealed` (the phase is no longer open), `Phase::Conflict` (the conditional write changed no row; the backstop of D8), `Seat::Stale` (the seat's token digest changed under a save, D9).
- **Order text in a label comes from the hash form.** `OrderLabelHelper` reads `order.to_h` (`"type"`, `"destination"`, ...), so no view or helper names a gem class.
- **Stand-in untouched.** `RulesEngine.adjudicate` stays the stand-in. The additions to `rules_engine.rb` are `province?` (Phase 4) and `next_movement_position` (Phase 7), both outside the stand-in block; the second carries a comment saying it is the app's playtest rule (spec D3).
- **Flash banner.** Controllers set `flash[:banner] = { "kind" => "info", "text" => "..." }`; the layout renders it through `shared/_banner`. The layout's existing `flash[:notice]` line is left as it is.
- **Number matching.** `GameAccess#find_phase` matches `\A[1-9][0-9]*\z` and then looks the number up in the game; anything else is nil and the caller gives the stranger response.
- **Screenshots** for the pull request come from a throwaway system spec kept in the scratchpad (not committed). The PNGs go in `web/docs/specs/022-phase-lifecycle/screens/` (docs, CC BY-SA 4.0 under the root licence map).

## Gates checked

- **Simplicity:** three models, two controllers, three partials, one helper, one migration.
- **Anti-abstraction:** no policy or service classes; `require_seat` and `find_phase` are two small methods of the existing `GameAccess` concern.
- **Integration-first:** Phase 1 starts from the request spec the brief names, against real routes and the real database.

## Phase 1: The first request spec, the tables, and the confirmation page

**Implements:** FR-1, FR-7 (the page), D1, D2. **Satisfies:** AC-1.1 to AC-1.4, AC-4.1 to AC-4.4 (the `GET` side), AC-4.11 (the `GET` side), AC-4.13.
**Files:**
- Create `spec/requests/reveal_spec.rb`, `spec/models/phase_spec.rb`, `db/migrate/20261126120000_create_phases_saved_orders_and_submissions.rb` (and `db/schema.rb`, written by the migration), `app/models/{phase,saved_order,submission}.rb`, `app/controllers/reveals_controller.rb`, `app/views/reveals/show.html.erb`, `app/views/shared/_confirm.html.erb`.
- Change `app/models/game.rb`, `app/models/seat.rb`, `app/controllers/concerns/game_access.rb`, `config/routes.rb`.

### 1a. The first test (red). It fails until phases exist

```ruby
# spec/requests/reveal_spec.rb
require "rails_helper"

RSpec.describe "The reveal confirmation page", type: :request do
  around { |example| with_passphrase { example.run } }

  it "shows a new game's spring 1901 movement phase, open, and names every power that has not submitted (AC-1.1, AC-1.2)" do
    created = create_game(power: "england")
    game = created.game

    expect(game.phases.count).to eq(1)
    phase = game.current_phase
    expect([ phase.number, phase.position.season, phase.position.year, phase.position.phase ]).to eq([ 1, :spring, 1901, :movement ])
    expect(phase.position).to eq(RulesEngine.starting_position)
    expect(phase.adjudication).to be_nil
    expect(phase.revealed_at).to be_nil

    created.session.get "/games/#{game.public_id}/host/phases/1/reveal"

    expect(created.session.response).to have_http_status(:ok)
    page = Nokogiri::HTML5(created.session.response.body)
    rows = page.css(".list__row")
    expect(rows.size).to eq(7)
    RulesEngine.powers.each { |power| expect(rows.map(&:text).join(" ")).to include(power.name) }
    england = rows.find { |row| row.text.include?("England") }
    expect(england.text).not_to include("no one has joined")
    expect(rows.count { |row| row.text.include?("no one has joined") }).to eq(6)
    expect(page.text).to match(/their unordered units will hold/i)
    expect(page.at_css(".confirm")).to be_present
  end
end
```

Run `bundle exec rspec spec/requests/reveal_spec.rb`. It fails: no `phases`, no route.

### 1b. The migration

```ruby
class CreatePhasesSavedOrdersAndSubmissions < ActiveRecord::Migration[8.1]
  def change
    create_table :phases do |t|
      t.references :game, null: false, foreign_key: true
      t.integer :number, null: false
      t.text :position, null: false
      t.text :adjudication
      t.datetime :revealed_at
      t.timestamps
      t.index %i[game_id number], unique: true
      t.index :game_id, unique: true, where: "revealed_at IS NULL", name: "index_phases_on_game_id_while_open"
      t.check_constraint "(revealed_at IS NULL) = (adjudication IS NULL)", name: "phases_reveal_is_all_or_nothing"
    end

    create_table :saved_orders do |t|
      t.references :phase, null: false, foreign_key: true
      t.references :seat, null: false, foreign_key: true
      t.string :province, null: false
      t.text :content, null: false
      t.timestamps
      t.index %i[phase_id seat_id province], unique: true
    end

    create_table :submissions do |t|
      t.references :phase, null: false, foreign_key: true
      t.references :seat, null: false, foreign_key: true
      t.datetime :created_at, null: false
      t.index %i[phase_id seat_id], unique: true
    end
  end
end
```

Run `bin/rails db:migrate` and `RAILS_ENV=test bin/rails db:schema:load`.

### 1c. Models and the game's hooks

```ruby
# app/models/phase.rb
class Phase < ApplicationRecord
  belongs_to :game
  has_many :submissions, dependent: :destroy # submitted or not is the only per-seat fact the host may read

  attribute :position, RulesObjectType.position
  attribute :adjudication, RulesObjectType.adjudication

  Pending = Data.define(:power, :seated)

  def open? = revealed_at.nil?

  # "Spring 1901 · Movement". Capitals are drawn by the stylesheet.
  def title = "#{position.season.to_s.capitalize} #{position.year} · #{position.phase.to_s.capitalize}"

  # Every power that has not submitted, each with whether anyone holds its seat (AC-4.1, AC-4.13).
  def pending
    seats = game.seats.index_by(&:power)
    done = submissions.pluck(:seat_id).to_set
    RulesEngine.powers.filter_map do |power|
      seat = seats[power.id.to_s]
      Pending.new(power: power.id.to_s, seated: !seat.nil?) unless seat && done.include?(seat.id)
    end
  end
end
```

```ruby
# app/models/saved_order.rb (the only model that names the table; Phase and Seat use it, nothing else does)
class SavedOrder < ApplicationRecord
  self.filter_attributes += [ :content ]

  belongs_to :phase
  belongs_to :seat

  attribute :content, RulesObjectType.order
end
```

```ruby
# app/models/submission.rb
class Submission < ApplicationRecord
  belongs_to :phase
  belongs_to :seat
end
```

In `game.rb`: `has_many :phases, -> { order(:number) }, dependent: :destroy` (declared after `has_many :seats`; no destroy path for a game exists today, and a game with a revealed phase could not be destroyed anyway, because a saved order of a revealed phase refuses to be destroyed (AC-6.5)), `def current_phase = phases.find_by(revealed_at: nil)`, `def history = phases.where.not(revealed_at: nil)`, and in `start!` after the seat is created: `game.phases.create!(number: 1, position: RulesEngine.starting_position)`.

In `seat.rb`: `has_many :saved_orders, dependent: :destroy` and `has_many :submissions, dependent: :destroy`.

### 1d. The route, the access helpers, the controller and the page

In `config/routes.rb`, inside the `games/:public_id` scope:

```ruby
get "host/phases/:number/reveal", to: "reveals#show", as: :game_reveal, constraints: { number: %r{[^/]+} }
```

(The segment constraint is the one spec 021 gave `public_id`: without it Rails' default stops at a dot, and `/phases/1.5/reveal` would get the framework's 404 and not the stranger page. The reveal's `post` route is added in Phase 7, with its action.)

In `GameAccess` add:

```ruby
# A phase number is digits with no leading zero. Anything else, or a number the game doesn't have, is nil (spec URLs).
def find_phase(game)
  number = params[:number].to_s
  number.match?(/\A[1-9][0-9]*\z/) ? game.phases.find_by(number: number.to_i) : nil
end

def require_seat
  @game = find_game
  @seat = @game && seat_of(@game)
  stranger!(@game) unless @seat
end
```

```ruby
# app/controllers/reveals_controller.rb
class RevealsController < ApplicationController
  before_action :require_host
  before_action :find_open_or_redirect

  def show
    @pending = @phase.pending
  end

  private

  # A later or unknown number is the stranger response. A revealed phase is not an error for the host (AC-4.11).
  def find_open_or_redirect
    @phase = find_phase(@game)
    return stranger!(@game) unless @phase && @phase.number <= @game.current_phase.number
    return if @phase.open?

    flash[:banner] = { "kind" => "info", "text" => "That phase was already revealed." }
    redirect_to game_host_path(@game.public_id), status: :see_other
  end
end
```

`app/views/shared/_confirm.html.erb` (a layout partial, used as `render layout: "shared/confirm", locals: {...} do ... end`):

```erb
<%# locals: title, confirm_label, confirm_path (nil draws a plain button, for the style guide), cancel_path,
    danger (default false), cancel_label (default "Back"), heading (default "h1"; the style guide passes "h2") %>
<% danger = local_assigns.fetch(:danger, false) %>
<div class="confirm stack">
  <%= content_tag local_assigns.fetch(:heading, "h1"), title %>
  <div class="confirm__body stack"><%= yield %></div>
  <div class="confirm__actions">
    <% variant = danger ? "button button--danger" : "button" %>
    <% if confirm_path %>
      <%= button_to confirm_label, confirm_path, class: variant %>
    <% else %>
      <button type="button" class="<%= variant %>"><%= confirm_label %></button>
    <% end %>
    <%= link_to local_assigns.fetch(:cancel_label, "Back"), cancel_path, class: "button button--secondary" %>
  </div>
</div>
```

`app/views/reveals/show.html.erb`:

```erb
<% content_for :title, "Reveal #{@phase.title}" %>
<%# The POST route arrives in Phase 7; until then the button's path is the page's own path. %>
<%= render layout: "shared/confirm", locals: { title: "Reveal #{@phase.title}?", confirm_label: "Reveal orders",
      confirm_path: game_reveal_path(@game.public_id, @phase.number), cancel_path: game_host_path(@game.public_id) } do %>
  <p>Orders for <%= @phase.title %> are locked and adjudicated. This cannot be undone.</p>
  <% if @pending.empty? %>
    <p>Every power has submitted.</p>
  <% else %>
    <p>These powers have not submitted:</p>
    <ul class="list">
      <% @pending.each do |entry| %>
        <li><div class="list__row"><%= power_badge(entry.power) %> <% unless entry.seated %><span class="text-muted">no one has joined</span><% end %></div></li>
      <% end %>
    </ul>
    <p>Their unordered units will hold.</p>
  <% end %>
<% end %>
```

(The power badge carries the power's name, so "names every power" holds in text.)

### 1e. More specs in this phase (written red first, then green)

- `spec/models/phase_spec.rb`: AC-1.1 (`Game.start!` gives one open phase with the starting position); AC-1.3 (each case asserts the specific error and is built to trip only its own constraint: a second open phase for a game raises `ActiveRecord::RecordNotUnique` on the partial index; a repeated number among revealed phases raises `RecordNotUnique` on the number index; `revealed_at` without `adjudication`, and `adjudication` without `revealed_at`, each raise `ActiveRecord::CheckViolation`, set with `insert_all`/`update_columns` on a phase that is already revealed or already open so no index is involved); AC-1.4 (`history` is revealed phases oldest first, `current_phase` the open one; set up with `update_columns` using a real adjudication from `RulesEngine.adjudicate(RulesEngine.starting_position, [])`); `pending` lists seated and unseated powers (AC-4.13), and drops a power whose seat has a submission (AC-4.1).
- `spec/requests/reveal_spec.rb` more examples: AC-4.1 (England and France submitted: the page's rows are the other five and not England or France; the sentence "their unordered units will hold" appears); AC-4.2 (all seven submitted, built with `Submission.create!`: "Every power has submitted." and no "will hold"); AC-4.3 (a `.confirm` with a `form` posting to the reveal path, a cancel link to the host page, no `dialog` element, and `Phase.count`, `Submission.count` unchanged after the `GET`); AC-4.4 (a seat-only session, no cookie and another game's host cookie each get `stranger_page?` status 404 with the body of spec 021's stranger page, for `GET`); AC-4.11 (`/phases/2/reveal`, `/phases/01/reveal`, `/phases/1abc/reveal`, `/phases/1.5/reveal` and `/phases/0/reveal` are the stranger response; a revealed phase 1 redirects to the host page with the already-revealed banner in the flash).

**Verify:** `bundle exec rspec spec/requests/reveal_spec.rb spec/models/phase_spec.rb spec/models/game_spec.rb spec/models/seat_spec.rb` green, and the existing suite still passes. Commit: "Add phases and the reveal confirmation page".

## Phase 2: The three components, the stylesheet caps, and the confirm pages of spec 021

**Implements:** FR-10, D7 of spec 021, the caps of changelog 1.2.0. **Satisfies:** AC-8.1 to AC-8.6.
**Files:**
- Create `app/views/phases/_header.html.erb`, `app/views/shared/_banner.html.erb`, `spec/requests/components_spec.rb`.
- Change `app/assets/stylesheets/components.css`, `app/assets/stylesheets/application.css` (the comment that lists the components), `app/assets/stylesheets/styleguide.css`, `app/views/styleguide/show.html.erb`, `app/views/layouts/application.html.erb`, `app/views/closings/show.html.erb`, `app/views/reissues/show.html.erb`, `spec/styles/stylesheet_rules_spec.rb`, `spec/requests/styleguide_spec.rb`, `spec/system/styleguide_layout_spec.rb`, `spec/docs/design_system_spec.rb`, `docs/design-system.md`.

### 2a. Tests first (red)

- `spec/styles/stylesheet_rules_spec.rb`: change the weight example to `<= 32 * 1024` total and `<= 6 * 1024` for `styleguide.css`, with the example's name saying 32 KB and 6 KB. It stays green (it only loosens), so it is the first edit, and the later examples cover the new CSS.
- `spec/requests/styleguide_spec.rb`: add `phase-header banner confirm` to the `components` array. It fails: the page has no such sections.
- `spec/requests/components_spec.rb` (new): renders the partials through the style guide and through real pages (it also asserts the style guide still has exactly one `h1`):
  - `.banner`: each of `info`, `warning`, `danger` renders one element with `banner banner--<kind>`; `warning` text starts "Warning:", `danger` starts "Error:", `info` has no prefix (AC-8.2).
  - A scan: no file under `app/views` except `shared/_banner.html.erb` contains `class="banner` or `banner--` (AC-8.2).
  - `.confirm`: the close-joining and reissue pages (host session) have one `.confirm` with a `.button--danger` form button and a `.button--secondary` cancel link, and no `dialog` (AC-8.3; the reissue page's saved-orders sentence is Phase 6's, AC-7.11).
  - The layout renders `flash[:banner]` through the partial: use the already-revealed redirect from Phase 1 (`reveals#show` on a revealed phase) and assert the host page has one `.banner--info` with "That phase was already revealed."
- `spec/docs/design_system_spec.rb`: a new example like the #21 one: for `.phase-header`, `.banner` and `.confirm`, one catalog line names the class with `#22` and `built` (AC-8.5). Fails until the document changes.
- `spec/system/styleguide_layout_spec.rb`: a `describe` for the three components at 360 pixels (AC-8.1, AC-8.4): `.phase-header__title` has computed `text-transform: uppercase` and a font family that includes `Plex Mono` (the computed value starts with a quote); the power badge in a `.phase-header` sits to the right of the title (its `left` is greater than the title's `right`); nothing scrolls sideways; every `.confirm .button` is at least 44 by 44. The tap-size selector list of the existing examples already covers `.button`.

### 2b. The partials and the CSS

```erb
<%# app/views/phases/_header.html.erb: locals phase, power (optional) %>
<div class="phase-header">
  <p class="phase-header__title mono"><%= phase.title %></p>
  <%= power_badge(power) if local_assigns[:power] %>
</div>
```

```erb
<%# app/views/shared/_banner.html.erb: locals kind ("info", "warning" or "danger"), text. The one place a banner is written. %>
<% lead = { "warning" => "Warning: ", "danger" => "Error: " }.fetch(kind.to_s, "") %>
<p class="banner banner--<%= kind %>" role="<%= kind.to_s == "info" ? "status" : "alert" %>"><%= lead %><%= text %></p>
```

In the layout, inside `<main>` before the `flash[:notice]` line:

```erb
<% if flash[:banner].is_a?(Hash) %><%= render "shared/banner", kind: flash[:banner]["kind"], text: flash[:banner]["text"] %><% end %>
```

CSS added to `components.css` (tokens only; every pair already documented):

```css
  /* ---- Phase header (#22): season, year and phase type in mono capitals, the viewer's badge at the end ---- */
  .phase-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: var(--space-3);
  }

  /* The title wraps inside its own box so the badge stays at the end of the row at 360 pixels. */
  .phase-header__title {
    flex: 1;
    min-width: 0;
    margin: 0;
    font-size: var(--text-base);
    letter-spacing: 0.08em;
    text-transform: uppercase;
  }

  .phase-header .power-badge {
    flex: none;
  }

  /* ---- Banner (#22): one sentence on its own ground. Words carry the kind; the edge is a second cue ---- */
  .banner {
    margin: 0;
    padding: var(--space-3) var(--space-4);
    border: var(--border-width) solid var(--color-border);
    border-radius: var(--radius);
    background: var(--color-surface);
    color: var(--color-text);
  }

  .banner--info {
    background: var(--color-ice-pale);
  }

  .banner--danger {
    border-color: var(--color-danger);
  }

  /* ---- Confirmation page (#22): a full page, never a modal ---- */
  .confirm__actions {
    display: flex;
    flex-wrap: wrap;
    gap: var(--space-3);
  }
```

`.mono` already supplies the font; if the existing `.mono` rule sets no size, the header's size is set above. The existing `.stack` spaces `.confirm`'s children.

### 2c. The style guide, the document, the two older pages

- `app/views/styleguide/show.html.erb`: three sections, each `<section data-component="..." class="stack" aria-labelledby="...">`: `phase-header` (the partial for a phase built in memory with `Phase.new(position: RulesEngine.starting_position)`, once with a power and once without), `banner` (the partial three times), `confirm` (the layout partial with `confirm_path: nil`, `cancel_path: "#sg-confirm"` and `heading: "h2"`, so the page keeps its one `h1`; once plain and once with `danger: true`). The sections add no `.sg-` rule unless a check needs one; `styleguide.css` stays within 6,144 bytes.
- `docs/design-system.md`: change the catalog rows for the three components to "Built by #22 (built)" with the partial names (`phases/_header`, `shared/_banner`, `shared/_confirm`), the `--info`, `--warning`, `--danger` words and the lead words. The page does not state the stylesheet caps, so nothing else changes there.
- `app/views/closings/show.html.erb` and `app/views/reissues/show.html.erb` use the confirm partial with `danger: true`, with their words unchanged: titles "Close joining" and "Reissue <Power>" (the `h1`, as `closing_spec` and `reissue_spec` assert), confirm labels "Close joining" and "Reissue seat", the back link labelled "Back", and the existing sentences ("Closing cannot be undone.", "The phone that holds this seat loses it at once."). The reissue page's extra sentence about saved orders comes in Phase 6, with the deletion.

**Verify:** `bundle exec rspec spec/requests spec/styles spec/docs spec/system/styleguide_layout_spec.rb spec/system/screens_layout_spec.rb` green. Commit: "Add the phase header, banner and confirm components and raise the stylesheet caps".

## Phase 3: The seat page and the host page show the phase

**Implements:** FR-1 (display), the seat page text (spec 021 AC-4.10 as amended). **Satisfies:** AC-1.5 (without the orders link, which Phase 5 adds with its route), AC-1.6.
**Files:** `spec/requests/player_spec.rb` (change), `spec/requests/phase_pages_spec.rb` (new), `app/views/games/show.html.erb`, `app/views/hosts/show.html.erb`, `app/controllers/games_controller.rb`, `app/controllers/hosts_controller.rb`.

### 3a. Tests first (red)

- `spec/requests/player_spec.rb`, the AC-4.10 example: the sentence becomes `"Keep this page. The host reveals each phase when the table is ready."`.
- `spec/requests/phase_pages_spec.rb` (new):
  - AC-1.5: the seat page has one `.phase-header` whose title text is "Spring 1901 · Movement", containing `.power-badge--england`; it shows "Not submitted" and no other seat's name.
  - AC-1.6: the host page has a `.phase-header` (no badge), a link to `/games/<id>/host/phases/1/reveal` labelled "Reveal orders", and the sentence "No phase has been revealed yet."; after revealing phase 1 (the example sets the revealed phase up with `update_columns`, a real adjudication from `RulesEngine.adjudicate(RulesEngine.starting_position, [])` and a second phase, as `phase_spec` does, so it needs no reveal code) the host page lists "Spring 1901 · Movement" under "Revealed phases".
  - The seat page and the host page of a game keep the existing `title` and h1 text.

### 3b. Implementation

`GamesController#show`: `@phase = @game.current_phase`. `HostsController#show`: `@phase = @game.current_phase`, `@history = @game.history.to_a`. In `games/show.html.erb`, remove the separate badge paragraph and the old sentence, and render `phases/_header` with `power: @seat.power`, the state line (`@seat.submitted?(@phase) ? "Submitted" : "Not submitted"`), and the new sentence. (The "Enter orders" link and the count line come in Phase 5.) In `hosts/show.html.erb`, render the header at the top, put a `.button` link "Reveal orders" in the host section, and add a "Revealed phases" list (or the "No phase has been revealed yet." sentence) after the host section, outside it and outside any `ul.list` inside it, so the seat-list assertions of `host_spec` and `reissue_spec` still count seven rows.

`Seat#submitted?(phase)` is added here: `submissions.exists?(phase_id: phase.id)`.

**Verify:** `bundle exec rspec spec/requests` green. Commit: "Show the current phase on the seat page and the host page".

## Phase 4: The saving rules (the model)

**Implements:** FR-2 (the rules), FR-3, FR-5, D4. **Satisfies:** AC-2.2 to AC-2.10 and AC-3.1 to AC-3.5 as rules of the model (their 422 statuses are tested in Phase 5), AC-6.5, AC-7.7 (the filters).
**Files:**
- Create `spec/models/saved_order_spec.rb`, `spec/models/seat_orders_spec.rb`.
- Change `app/models/seat.rb`, `app/models/saved_order.rb`, `app/models/submission.rb`, `app/models/phase.rb`, `app/models/rules_engine.rb`, `spec/models/rules_engine_spec.rb`, `spec/support/rules_helpers.rb`, `config/initializers/filter_parameter_logging.rb`, `spec/config/filter_parameters_spec.rb`.

### 4a. Tests first (red)

- `spec/models/saved_order_spec.rb`: AC-2.10 (a saved order reads back equal, and the raw column text parses to a hash with `"format" => 1`); AC-6.5 (creating or destroying a saved order, or creating a submission, for a revealed phase raises `ActiveRecord::RecordInvalid` or `ActiveRecord::RecordNotDestroyed`; the phase is made revealed with `update_columns` and a real adjudication); `SavedOrder#inspect` shows `content: [FILTERED]` and none of the order's JSON text (the `province` column is not secret and stays visible).
- `spec/models/rules_engine_spec.rb`: `RulesEngine.province?` is true for `"lon"` and `:lon`, false for `"xyz"`, `""` and `nil`.
- `spec/models/seat_orders_spec.rb` (the rules, with no HTTP; `require_relative "../support/rules_helpers"` and `include RulesHelpers`): `seat.save_orders!(phase, { "lon" => json_of(order) }, submit: false)` and the refusals of FR-2 in its precedence order, each asserting the exact sentence and that nothing was stored: a three-letter key that is not a province (`"xyz"`: `"That order couldn't be read."`), a province where the seat has no unit (`"You have no unit in PAR."`), text that is not JSON, JSON that is not a hash, a malformed order (`load_order` raises), `at` differing from the key, the order's `power` another power's (`"That order isn't for your power."`), an illegal move (the reason's sentence, which names the unit by type and province, such as `"The fleet in LON can't reach there."`). Also: every reason in the interface's list of 17 has a sentence in `Seat::REASONS`, and one example renders all 17 with a sample unit and checks each reads as a sentence (starts with a capital, ends with a full stop, no leftover `%{`, and the sample unit's "army in LON" appears in all but `wrong_phase`); an unknown reason gets `"That order isn't legal."`. Then AC-2.7 (blank clears), 2.8 (replace), 2.9 (partial update leaves the others), 3.1 to 3.5 (submit records a submission; a real change removes it; no change leaves it; submit twice is one row; a refusal with `submit: true` records nothing), AC-3.2's clear after submit, and `Seat::Stale` (the digest is changed through another instance of the seat, then `save_orders!` raises and stores nothing). Helper builders come from `spec/support/rules_helpers.rb`, extended with `json_of(order) = JSON.generate(order.to_h)`.
- `spec/config/filter_parameters_spec.rb`: `orders` filters to `[FILTERED]` (AC-7.7).

### 4b. The model code

```ruby
# app/models/saved_order.rb (additions)
validate :phase_open
before_destroy { throw :abort unless phase.open? }

private

def phase_open = errors.add(:phase, "is no longer open") unless phase.open?
```

```ruby
# app/models/submission.rb (addition)
validate { errors.add(:phase, "is no longer open") unless phase.open? }
```

```ruby
# app/models/phase.rb (additions)
class Revealed < StandardError; end   # the phase is no longer open
class Conflict < StandardError; end   # the conditional write of the reveal changed no row (D8, a backstop)
```

```ruby
# app/models/seat.rb (additions)
class Refusal < StandardError; end   # the message is the sentence the player sees
class Stale < StandardError; end     # the seat's token digest changed while a save was running (D9)

# %{unit} is "the army in LON" and %{Unit} is "The army in LON": the unit's type and province (FR-5).
REASONS = {
  wrong_phase: "Orders can only be given in a movement phase.", no_such_unit: "%{Unit} isn't on the board.",
  foreign_unit: "%{Unit} isn't yours.", own_province: "%{Unit} can't be ordered to its own province.",
  not_reachable: "%{Unit} can't reach there.", coast_not_allowed: "%{Unit} can't name a coast.",
  coast_required: "%{Unit} must name a coast to move there.", coast_unreachable: "%{Unit} can't reach that coast.",
  not_army: "%{Unit} can't move by convoy; only an army can.", not_adjacent: "%{Unit} can't reach there by land.",
  no_convoy_route: "There is no convoy route for %{unit}.", same_province: "A support by %{unit} can't start and end in the same province.",
  no_unit: "There is no suitable unit for %{unit} to support or convoy.", move_impossible: "%{Unit} can't support that move: the unit there couldn't make it.",
  not_fleet_at_sea: "%{Unit} isn't a fleet at sea, so it can't convoy.", bad_endpoints: "%{Unit} can't convoy between those provinces.",
  not_on_chain: "%{Unit} isn't part of a convoy route for that move."
}.freeze
GENERIC = "That order isn't legal.".freeze
UNREADABLE = "That order couldn't be read.".freeze
Saved = Data.define(:changed, :submitted)

# This seat's own orders for a phase: { "lon" => order }. The only way anything outside Phase and Seat reads saved orders.
def orders_for(phase) = saved_orders.where(phase_id: phase.id).to_h { |row| [ row.province, row.content ] }

def submitted?(phase) = submissions.exists?(phase_id: phase.id)

# entries: { province => the order's JSON text, or blank to clear }. All or nothing (spec FR-2).
def save_orders!(phase, entries, submit: false)
  Phase.transaction do
    phase.lock!
    raise Phase::Revealed unless phase.open?
    raise Stale unless Seat.exists?(id: id, token_digest: token_digest)

    parsed = entries.to_h { |province, text| [ province.to_s, text.to_s.strip.empty? ? nil : read_order(phase, province.to_s, text.to_s) ] }
    stored = orders_for(phase)
    changed = false
    parsed.each do |province, order|
      if order.nil?
        changed |= saved_orders.where(phase_id: phase.id, province: province).destroy_all.any?
      elsif stored[province] != order
        row = saved_orders.find_or_initialize_by(phase_id: phase.id, province: province)
        row.content = order
        row.save!
        changed = true
      end
    end
    submissions.where(phase_id: phase.id).destroy_all if changed
    submissions.find_or_create_by!(phase_id: phase.id) if submit
    Saved.new(changed: changed, submitted: submitted?(phase))
  end
end

# Deletes this seat's saved orders and its submission for the phase (a reissue, D9). The caller holds the phase lock.
def clear_orders!(phase)
  saved_orders.where(phase_id: phase.id).destroy_all
  submissions.where(phase_id: phase.id).destroy_all
end

private

# The refusals in the order of FR-2: unit, readable, `at`, power, check. Messages never carry what was sent.
def read_order(phase, province, text)
  raise Refusal, UNREADABLE unless province.match?(/\A[a-z]{3}\z/) && RulesEngine.province?(province)
  unit = phase.position.units.find { |candidate| candidate.location.province.to_s == province && candidate.power.to_s == power }
  raise Refusal, "You have no unit in #{province.upcase}." unless unit

  order = begin
    RulesEngine.load_order(JSON.parse(text))
  rescue JSON::ParserError, RulesEngine::InvalidInput
    raise Refusal, UNREADABLE
  end
  raise Refusal, UNREADABLE unless order && order.at.to_s == province
  raise Refusal, "That order isn't for your power." unless order.power.to_s == power

  check = RulesEngine.check(phase.position, order)
  raise Refusal, format(REASONS.fetch(check.reasons.first, GENERIC), unit: "the #{unit.type} in #{province.upcase}", Unit: "The #{unit.type} in #{province.upcase}") unless check.legal

  order
end
```

`JSON.parse(text)` returning a non-Hash makes `RulesEngine.load_order` raise `InvalidInput` (it only accepts a hash, an order or nil), so an array or a number is "couldn't be read". A `nil` result (`"null"` text) makes `order` nil, which `raise Refusal, UNREADABLE unless order` catches.

```ruby
# app/models/rules_engine.rb: added to `class << self`, above `private`
def province?(id) = TA::Map.classic.provinces.any? { |province| province.id.to_s == id.to_s }
```

`config/initializers/filter_parameter_logging.rb`: add `:orders` to the list. In `saved_order.rb` the filter is `self.filter_attributes += [ :content ]` (the `+=` keeps the filters the app already has).

**Verify:** `bundle exec rspec spec/models spec/config` green. Commit: "Add the rules for saving orders and submitting".

## Phase 5: The orders page and the endpoint

**Implements:** FR-2 (the endpoint), FR-4, D5. **Satisfies:** AC-1.5 (the orders link), AC-2.1, AC-2.11, AC-2.12, AC-3.1, AC-3.6, AC-7.4, AC-7.6, AC-7.7 (the flash).
**Files:**
- Create `spec/requests/orders_spec.rb`, `spec/helpers/order_label_helper_spec.rb`, `app/controllers/seat_orders_controller.rb`, `app/views/seat_orders/{show,revealed}.html.erb`, `app/helpers/order_label_helper.rb`.
- Change `config/routes.rb`, `app/views/games/show.html.erb`, `spec/requests/phase_pages_spec.rb`, `spec/requests/forgery_spec.rb`.

### 5a. Tests first (red)

- `spec/requests/orders_spec.rb`: the request side, with `create_game(power: "england")` as England's phone: AC-2.1 (PUT with the legal order for each unit: 303 to the orders page, one `SavedOrder` per unit with that seat and phase, a `.banner--info` "Orders saved."); AC-2.11 (the orders page has one `select` per England unit, each with the option "No order (holds)" first, the options of `RulesEngine.legal_orders` for that unit, the stored one `selected`, and no unit of another power); AC-2.12 (no cookie; the host cookie only; a seat cookie of another game: `GET` and `PUT` give the stranger response and store nothing; `/phases/1.5/orders`, `/phases/01/orders` and `/phases/2/orders` are the stranger response); AC-3.1 (`submit=1`, banner "Submitted."); AC-3.6 (a submitted seat's next edit is accepted); AC-7.6 (the orders page and the PUT's redirect have `Cache-Control` containing `no-store`; the orders page has the Turbo no-cache meta); 422 pages for the refusals show the sentence in a `.banner--danger` and the stored orders unchanged; the response for a non-hash `orders` is 422; AC-7.7 (the flash after a save holds only the banner's kind and text: `session`-readable text contains no province or order JSON beyond the words "Orders saved.").
- `spec/requests/phase_pages_spec.rb` (Phase 3's file, extended): the seat page has a link to `/games/<id>/phases/1/orders` and "0 of 3 units ordered" for England (three units), then "2 of 3 units ordered" after two orders are saved, and the page contains no order label.
- `spec/requests/forgery_spec.rb`: with forgery protection switched on, `PUT /games/<id>/phases/1/orders` without the token is refused and stores nothing (the reveal's `POST` is added in Phase 7).
- `spec/helpers/order_label_helper_spec.rb`: the seven labels of D5 (`"Hold"`, `"Move to BEL"`, `"Move to SPA (north coast)"`, `"Move to BEL by convoy"`, `"Support hold in BER"`, `"Support BUR to MUN"`, `"Convoy LON to NWY"`), built from hash forms through `rules_order`.

### 5b. Routes, controller, views

```ruby
# config/routes.rb, in the games scope
get "phases/:number/orders", to: "seat_orders#show", as: :game_seat_orders, constraints: { number: %r{[^/]+} }
put "phases/:number/orders", to: "seat_orders#update", constraints: { number: %r{[^/]+} }
```

```ruby
# app/controllers/seat_orders_controller.rb
class SeatOrdersController < ApplicationController
  before_action :require_seat
  before_action :find_phase_or_stranger
  before_action { no_store } # a page or a redirect about a seat's own orders is never cached (AC-7.6). It runs after require_seat, so a stranger page carries no such header, which is right: it has nothing to cache.

  def show
    return render_revealed unless @phase.open?
  end

  def update
    return render_revealed unless @phase.open?

    entries = order_entries
    return refuse(Seat::UNREADABLE) unless entries

    result = @seat.save_orders!(@phase, entries, submit: params[:submit] == "1")
    flash[:banner] = { "kind" => "info", "text" => result.submitted ? "Submitted." : "Orders saved." }
    redirect_to game_seat_orders_path(@game.public_id, @phase.number), status: :see_other
  rescue Seat::Refusal => error then refuse(error.message)
  rescue Phase::Revealed then render_revealed
  rescue Seat::Stale then stranger!(@game)
  end

  private

  def find_phase_or_stranger
    @phase = find_phase(@game)
    stranger!(@game) unless @phase && @phase.number <= @game.current_phase.number
  end

  # nil when `orders` is present and is not a hash of text (AC-2.5); {} when it is absent (a submit alone, FR-2).
  def order_entries
    raw = params[:orders]
    return {} if raw.nil?
    return nil unless raw.respond_to?(:to_unsafe_h)

    hash = raw.to_unsafe_h
    hash.values.all? { |value| value.is_a?(String) } ? hash : nil
  end

  def refuse(sentence)
    @refusal = sentence
    render :show, status: :unprocessable_content
  end

  def render_revealed
    render :revealed, status: :conflict
  end
end
```

`app/views/seat_orders/show.html.erb`: `content_for :title, "Your orders"`, the Turbo no-cache meta, `render "phases/header", phase: @phase, power: @seat.power`, `@refusal` as a `danger` banner, the state line ("Submitted" or "Not submitted") and "n of m units ordered" (the seat's own count), then:

```erb
<%= form_with url: game_seat_orders_path(@game.public_id, @phase.number), method: :put, id: "orders-form", class: "stack" do %>
  <% @units.each do |unit| %>
    <% province = unit.location.province.to_s %>
    <div class="field">
      <label class="field__label" for="order-<%= province %>">
        <%= unit_icon(unit.power, unit.type, size: 32, decorative: true) %>
        <%= unit.type.to_s.capitalize %> in <span class="mono"><%= province.upcase %></span>
      </label>
      <select class="control" id="order-<%= province %>" name="orders[<%= province %>]">
        <option value="">No order (holds)</option>
        <% RulesEngine.legal_orders(@phase.position, unit).each do |order| %>
          <option value="<%= JSON.generate(order.to_h) %>"<%= " selected" if @stored[province] == order %>><%= order_label(order) %></option>
        <% end %>
      </select>
    </div>
  <% end %>
<% end %>
<% content_for :actions do %>
  <%= button_tag "Save orders", type: "submit", form: "orders-form", class: "button button--secondary" %>
  <%= button_tag "Save and submit", type: "submit", name: "submit", value: "1", form: "orders-form", class: "button" %>
<% end %>
```

The controller's `show` (and `refuse`) set `@units` (the seat's units in the phase's position, sorted by province) and `@stored = @seat.orders_for(@phase)` through a private `load_page` called from both. `app/views/seat_orders/revealed.html.erb`: the header, a `danger` banner "The host has already revealed this phase. Your orders were not saved.", and a `.button` link to the current phase's orders page (`@game.current_phase.number`). Note the `GET` of a revealed phase shows the same page (AC-6.3); its sentence is acceptable because no write happened (AC-6.1 requires the exact sentence for the write, and the same text is the clearest for the read).

```ruby
# app/helpers/order_label_helper.rb: reads the hash form, so it names no gem class
module OrderLabelHelper
  COASTS = { "nc" => "north coast", "sc" => "south coast", "ec" => "east coast" }.freeze

  def order_label(order)
    h = order.to_h
    case h["type"]
    when "hold" then "Hold"
    when "move"
      coast = h["destination"]["coast"]
      "Move to #{h["destination"]["province"].upcase}#{" (#{COASTS.fetch(coast)})" if coast}"
    when "move_via_convoy" then "Move to #{h["to"].upcase} by convoy"
    when "support_hold" then "Support hold in #{h["target"].upcase}"
    when "support_move" then "Support #{h["from"].upcase} to #{h["to"].upcase}"
    when "convoy" then "Convoy #{h["from"].upcase} to #{h["to"].upcase}"
    end
  end
end
```

In `games/show.html.erb` (Phase 3's page) add a `.button` link "Enter orders" (`game_seat_orders_path(@game.public_id, @phase.number)`) and the line "n of m units ordered": n is `@seat.orders_for(@phase).size`, m the count of the seat's units in `@phase.position.units`. It is the seat's own count and shows no order content (FR-9).

**Verify:** `bundle exec rspec spec/models spec/requests spec/helpers spec/config` green. Commit: "Add the orders page and the endpoint for saving orders".

## Phase 6: Reissuing a seat clears its orders

**Implements:** D9, FR-9 (the reissue row). **Satisfies:** AC-7.10, AC-7.11 (the deletion).
**Files:** Create `spec/requests/reissue_clears_orders_spec.rb`. Change `app/models/game.rb`, `app/views/reissues/show.html.erb`, `spec/models/game_spec.rb` (if an example asserts the digest-only transaction). It comes right after saving exists, so the hole of D9 is never open in a commit that can save orders.

### 6a. Test first (red)

- `spec/requests/reissue_clears_orders_spec.rb`: England saves orders and submits; the host reissues England (`POST /games/<id>/host/seats/england/reissue`); `SavedOrder.where(seat_id:)` and `Submission.where(seat_id:)` are empty for phase 1; France's orders and submission are untouched; the new phone, opening the new seat link, sees the orders page with every select on "No order (holds)" and "Not submitted"; a phase already revealed keeps its saved orders (set up by revealing phase 1 with orders, then reissuing, then asserting phase 1's rows are still there); and the host, opening the new link on its own phone, sees an empty orders page (the hole of D9 is shut). A revealed phase is set up with `update_columns` and a real adjudication, so this phase needs no reveal code. The reissue page (host session) has a `.confirm` whose text says the seat's saved orders for this phase are deleted with it (AC-7.11), added to `reissues/show.html.erb` here.

### 6b. The code

```ruby
# app/models/game.rb
# Replaces the seat's digest and, with it, that seat's saved orders and submission for the open phase (spec 022 D9).
# The phase lock comes first, as in a save, so a save from the old phone cannot slip in between.
def reissue_seat!(seat)
  token = Token.generate
  transaction do
    phase = current_phase
    phase.lock!
    seat.update!(token_digest: Token.digest(token))
    seat.clear_orders!(phase)
  end
  token
end
```

**Verify:** `bundle exec rspec spec/requests spec/models` green (the 021 reissue examples included). Commit: "Clear a seat's saved orders when the host reissues it".

## Phase 7: The reveal, the next phase and the refusals after it

**Implements:** FR-6, FR-7, FR-8, D3, D7, D8. **Satisfies:** AC-4.5 to AC-4.12, AC-5.1 to AC-5.7, AC-6.1 to AC-6.4, AC-1.6 (history).
**Files:**
- Create `spec/models/rules_engine_next_phase_spec.rb`, `spec/models/phase_reveal_spec.rb`, `spec/models/phase_concurrency_spec.rb`, `spec/requests/reveal_post_spec.rb`, `app/views/reveals/failed.html.erb`.
- Change `app/models/rules_engine.rb`, `app/models/phase.rb`, `app/controllers/reveals_controller.rb`, `config/routes.rb`, `spec/requests/forgery_spec.rb`, `app/controllers/hosts_controller.rb`, `app/views/hosts/show.html.erb`, `spec/models/rules_engine_boundary_spec.rb` (only if its list of files needs the new method named; it should not).

### 7a. Tests first (red)

- `spec/models/rules_engine_next_phase_spec.rb` (AC-5.1 to AC-5.3, AC-5.6): from a hand-built retreat position (`rules_position(..., phase: "retreat", standoffs: [...])` plus dislodged units via a full hash through `RulesEngine.load_position`): spring becomes fall of the same year, fall becomes spring of the next, phase `:movement`, units as given, ownership equal, standoffs and dislodged units empty; given a movement position, `RulesEngine::InvalidInput`; the message names no order. A second example runs the stand-in on the starting position with one move and checks the next position is movement with the moved unit (AC-5.2).
- `spec/models/phase_reveal_spec.rb` (AC-4.5 to AC-4.8, AC-4.10, AC-5.5): reveal a phase with saved orders from two seats (one submitted, one not, AC-4.7): `RulesEngine.adjudicate` (spied with `and_wrap_original`) is called once with the position and the orders listed by power and then province (AC-4.6), the adjudication is stored and loads, `revealed_at` is set, the next phase has number 2, is open, and its position is the next movement position; every unit without an order is an outcome with `submitted: false`; calling `reveal!` again returns `Phase::Reveal.new(:already)`, calls `adjudicate` no more, and adds no phase (AC-4.8); `adjudicate` raising `RulesEngine::InvalidInput` raises out of `reveal!` and leaves the phase open, with no adjudication and one phase (AC-4.10); the next-position build raising `RuntimeError` does the same rollback; the backstop (a stub of `adjudicate` that marks the phase revealed on the same connection, then the conditional write finds no row) raises `Phase::Conflict` and rolls back both (D8); no retreat or adjustment phase after three reveals in a row: every phase's position is movement and the seasons run spring, fall, spring (AC-5.1, 5.5).
- `spec/models/phase_concurrency_spec.rb`, its own commit. The describe block says `self.use_transactional_tests = false` (the metadata form `use_transactional_tests: false` is ignored by rspec-rails, and with the fixture transaction on, both threads would share one connection and never wait). An `after` deletes `Submission`, `SavedOrder`, `Phase`, `Seat`, `Game` in that order, and an `ensure` in each example releases the gate and joins the threads, so a failure cannot leave a thread holding the database lock. Each thread works inside `ActiveRecord::Base.connection_pool.with_connection`. Examples:
  - The write lock (D8): thread A runs `Game.transaction { Game.connection.select_value("SELECT 1"); held << true; release.pop }` (the statement matters: Rails starts a transaction lazily, so an empty block sends no `BEGIN`), and thread B, after `held.pop`, sets its own connection's `raw_connection.busy_handler_timeout = 200` (not `busy_timeout=`: Rails configures the connection with the Ruby-level handler, which lets other threads run while it waits, and `busy_timeout=` would replace it with SQLite's C-level wait that holds Ruby's global lock and would hang the main thread), runs the same transaction with the same first statement, and is expected to raise an error whose message matches `/locked|busy/i`; B's `ensure` sets `busy_handler_timeout` back to 5000. This proves immediate mode (a deferred transaction takes no lock at `BEGIN` and the statement alone would not block).
  - AC-4.9: `allow(RulesEngine).to receive(:adjudicate).and_wrap_original { |original, *args| entered << true; gate.pop; original.call(*args) }`; thread A `Phase.find(id).reveal!`; main waits on `entered.pop`; thread B starts the same call; `sleep 0.2; expect(thread_b).to be_alive`; `gate << true`; join both (each in `ActiveRecord::Base.connection_pool.with_connection`); expect statuses `[:revealed, :already]` in start order, `adjudicate` received once, `Phase.where(game_id:).count == 2`.
  - AC-6.4, the save loses: the same hold, with B calling `seat.save_orders!` for a legal hold; after release B raises `Phase::Revealed`, and `SavedOrder.count == 0`. The save wins: A saves first and completes; the reveal's adjudication outcomes with `submitted: true` equal the stored orders.
- `spec/requests/reveal_post_spec.rb`: AC-4.4 for `POST` (a seat session and a stranger get the stranger response and the phase is unchanged); AC-4.5 (host confirms: 303 or 302 to the host page, and the host page then shows a `.banner--info` "Spring 1901 · Movement was revealed. It is now Fall 1901 · Movement."); AC-4.8 (two POSTs in a row: the second redirects with "That phase was already revealed." and `Phase.count` stays 2); AC-4.10 (`adjudicate` stubbed to raise `RulesEngine::InvalidInput, "secret order text"`: status 422, the body has "Nothing was changed. The phase is still open." and not "secret order text", the log (captured with a `StringIO` logger) has no "secret order text", the phase is still open); AC-4.11 (a later or malformed number is the stranger response for `POST`); AC-4.12 (the route table has no route containing `reopen`, `undo`, or a `DELETE` or `PUT` under `phases/:number` other than the orders one); AC-6.1 to AC-6.3 (England loads the orders page, the host reveals, England's `PUT` returns 409 with the sentence and a link to phase 2, stores nothing, with `submit=1` stores no submission, and `GET` of phase 1's orders page returns the same 409); AC-5.4 (with `adjudicate` stubbed to return a hand-built adjudication that has a dislodged Austrian army in `ser`, the host page shows one `.banner--warning` with "Warning: Austria's army in SER was dislodged. Settle it by hand.", and nothing when the phase before had none); AC-1.6 (history after a reveal).

### 7b. The code

The reveal's `post` route, added to `config/routes.rb` beside the `get` of Phase 1, with the same segment constraint:

```ruby
post "host/phases/:number/reveal", to: "reveals#create", as: nil, constraints: { number: %r{[^/]+} }
```

(`as: nil` because the `get` already names `game_reveal`, whose path is the same.) `spec/requests/forgery_spec.rb` gains the example: `POST` to the reveal without the token is refused and the phase is unchanged.

```ruby
# app/models/rules_engine.rb: added to `class << self`, above `private`, outside the stand-in
# The playtest's own rule for the phase that follows a reveal (spec 022 D3), not part of the stand-in: it stays after
# #29 until 1.0 uses what gem 0.3.0 works out. Dislodged units leave the board, standoffs are cleared, ownership is kept.
def next_movement_position(position)
  unless position.is_a?(TA::Position) && position.phase == :retreat
    raise InvalidInput, "the next phase is built from a retreat position, got #{position.class} in #{position.respond_to?(:phase) ? position.phase.inspect : "no phase"}"
  end

  season, year = position.season == :spring ? [ :fall, position.year ] : [ :spring, position.year + 1 ]
  TA::Position.new(map: position.map, season: season, year: year, phase: :movement, units: position.units,
                   ownership: position.ownership, dislodged_units: [], standoffs: [])
end
```

```ruby
# app/models/phase.rb (addition)
Reveal = Data.define(:status) # :revealed, or :already when an earlier request did it

# The reveal (spec FR-7, D8). The transaction's first statement is the lock. Callers rescue RulesEngine::InvalidInput.
def reveal!
  status = transaction do
    lock!
    next :already unless open?

    orders = SavedOrder.joins(:seat).where(phase_id: id).order("seats.power", :province).map(&:content)
    result = RulesEngine.adjudicate(position, orders)
    upcoming = RulesEngine.next_movement_position(result.position)
    changed = Phase.where(id: id, revealed_at: nil).update_all(adjudication: result, revealed_at: Time.current)
    raise Conflict unless changed == 1

    game.phases.create!(number: number + 1, position: upcoming)
    :revealed
  end
  reload
  Reveal.new(status: status)
end
```

`update_all(adjudication: result)` serializes through the attribute type: Rails' `_substitute_values` casts each value with `model.type_for_attribute(name).cast(value)` and binds it, so `RulesObjectType#cast` accepts the gem object and `serialize` writes the JSON (read in `activerecord-8.1.4.1/lib/active_record/relation.rb`). The "stored adjudication loads" example of `phase_reveal_spec.rb` still proves it.

```ruby
# app/controllers/reveals_controller.rb (addition)
def create
  result = @phase.reveal!
  flash[:banner] =
    if result.status == :revealed
      next_phase = @game.current_phase
      { "kind" => "info", "text" => "#{@phase.title} was revealed. It is now #{next_phase.title}." }
    else
      { "kind" => "info", "text" => "That phase was already revealed." }
    end
  redirect_to game_host_path(@game.public_id), status: :see_other
rescue RulesEngine::InvalidInput => error
  Rails.logger.warn("reveal failed: #{error.class}") # the message can hold an order, so it is never logged (AC-4.10)
  render :failed, status: :unprocessable_content
end
```

`reveals/failed.html.erb`: the phase header, a `danger` banner "Nothing was changed. The phase is still open.", and a `.button` link back to the host page. `HostsController#show` adds `@dislodged = @game.history.last&.adjudication&.position&.dislodged_units || []`, and the host view renders, for each, `render "shared/banner", kind: "warning", text: "#{power_name(u.unit.power)}'s #{u.unit.type} in #{u.unit.location.province.to_s.upcase} was dislodged. Settle it by hand."`. (The banner partial adds the "Warning: " lead.)

**Verify:** `bundle exec rspec spec/models spec/requests` green, including the concurrency spec run five times in a row (`for i in 1 2 3 4 5; do bundle exec rspec spec/models/phase_concurrency_spec.rb || break; done`). Commits: "Add the atomic reveal and the next movement phase" (everything but the concurrency spec), then "Test the reveal and saving under concurrent requests" (`phase_concurrency_spec.rb`, which needs no code change).

## Phase 8: Secrecy: the route table, the invariance sweep and the source scan

**Implements:** FR-9, D6. **Satisfies:** AC-7.1 to AC-7.3, AC-7.5, AC-7.7 (the model half), AC-7.8, AC-7.9.
**Files:** Create `spec/requests/order_secrecy_spec.rb`, `spec/support/secrecy_routes.rb`, `spec/models/saved_order_boundary_spec.rb`. Change `spec/rails_helper.rb` (one `require_relative`), `spec/config/production_config_spec.rb`, and the spec files that use `RulesHelpers` (it is not auto-included: each spec that builds rules objects does `require_relative "../support/rules_helpers"` and `include RulesHelpers`).

### 8a. The classification, in code (`spec/support/secrecy_routes.rb`)

`SecrecyRoutes::TABLE` is a hash from `"VERB /path"`, built as `"#{route.verb.presence || 'MOUNT'} #{route.path.spec.to_s.sub('(.:format)', '')}"` (the Action Cable mount is an internal route entry with an empty verb, so it appears as `MOUNT /cable`) to `{ shows: :none | :own, sweep: ->(ctx) { path } or nil, why: "..." }`. It holds every row of FR-9: the app's own routes by name; every route under `/rails/` (Action Mailbox, Active Storage), the three Turbo historical-location routes, and `MOUNT /cable` classified by prefix with `shows: :none` and the reason "framework route with no game data" (for `/cable`: "no channel exists yet; #24 classifies its first stream"); `GET /games/:public_id`, `GET` and `PUT /games/:public_id/phases/:number/orders` as `shows: :own`. `sweep` gives the path to request for each readable `GET`: for `host-link` and `seat-link` it adds a token the setup holds and each request is made in a fresh session of its own (the link sets a cookie, which must not turn the stranger or France into England or the host for the routes that follow), with a token that is not England's; for `qr` it is requested with no flash (a redirect that does not depend on orders). `GET /styleguide` is classified and swept.

### 8b. The specs (red first for AC-7.1 by deleting a row, then restoring it)

- **AC-7.1:** `Rails.application.routes.routes` rendered as `"VERB path"` equals, as a set, the table's keys (no unclassified route, no row for a route that doesn't exist). The failure message names the route.
- **AC-7.2:** a setup with the host on Germany (`create_game(power: "germany")`), England taken with `game.take_seat!("england")` (a session through its seat link), France likewise, and four viewers other than England: France's seat, the host with its own Germany seat, the host with the seat cookie deleted (`seat_only_session`'s mirror), and a stranger. For each state of England's orders (none, one unit, all units, a different set), set the orders with `england.save_orders!`, `Rails.cache.clear`, then for every viewer and every swept `GET` route record `comparable(response, id)` (status, normalized body, `Content-Type`, `Cache-Control`, `Referrer-Policy`, the `host_` and `seat_` cookie lines; the normalization removes the `csrf-token` meta, hidden `authenticity_token` values and the `nonce` attributes). The four states must give equal records for each viewer and route. A second pair compares England submitted and not submitted with the same orders, for every route except `GET .../host/phases/1/reveal` (the one sanctioned difference, asserted separately: the host's confirmation page lists England as pending only when it is not submitted).
- **AC-7.3:** with every viewer's response to England's `PUT`, to France's `PUT` for an England province (`"You have no unit in XXX."`), to the refusals and to the stranger pages: none of England's order JSON (`json_of(order)`), none of its label (`order_label`), and no response to anyone but England contains England's own count line ("n of 3 units ordered" with England's n; the sweep of AC-7.2 covers every other page).
- **AC-7.5:** the host page, the confirmation page and the reveal's redirect target (host session) contain no `select`, no `option`, no match for `/\bordered\b/` (the word "unordered" is allowed on the confirmation page), and none of England's labels, with England holding orders.
- **AC-7.9:** after revealing, no swept page for any viewer includes an `option[selected]` or the words "Succeeded", "Bounced" or "Held" (the outcome words), and phase 1's orders page is the 409 refusal page (the new phase's orders page legitimately lists every legal order as options, so labels are not searched for).
- `spec/models/saved_order_boundary_spec.rb` (AC-7.8, a text scan in the style of the gem-boundary spec): over `app/`, `lib/` and `db/`, `SavedOrder` and `saved_orders` appear only in `app/models/saved_order.rb`, `app/models/seat.rb`, `app/models/phase.rb`, the migration and `schema.rb`; `has_many :saved_orders` appears in `seat.rb` only; no `through:` association reaches `saved_orders` from `game.rb` or `phase.rb`; and `phase.rb` has exactly one match of `/SavedOrder|saved_orders?/`, in `reveal!`; its comments avoid the name.

- `spec/config/production_config_spec.rb`: a new example reads the production environment file and asserts the log level defaults to `info`. This is a stated limit, not a proof of secrecy: Rails logs the bind values of SQL at `debug` through the global inspection filter, which a model's own `filter_attributes` does not reach, so a saved order's `content` can appear in a debug-level SQL log (development and test, and production only if `RAILS_LOG_LEVEL=debug` is set). The default of `info` keeps it out, and the limit is written in the pull request.

**Verify:** `bundle exec rspec spec/requests/order_secrecy_spec.rb spec/models/saved_order_boundary_spec.rb spec/config` green, and the whole suite. Commit: "Prove order secrecy with a route table, a sweep and a source scan".

## Phase 9: Phone-width system specs, screenshots, the document, and the proof

**Implements:** the Issue's design lines, NFR layout. **Satisfies:** AC-8.1, AC-8.3, AC-8.4 (in a browser), the Done-when proof list.
**Files:** Create `spec/system/phase_screens_spec.rb`, `web/docs/specs/022-phase-lifecycle/screens/*.png`. Change `spec/system/create_and_join_spec.rb` only if it asserts the old seat-page sentence.

- `spec/system/phase_screens_spec.rb`: in `with_viewport(360)` and again at 768, for the seat page, the orders page (England's three units in a new game), the host page, the reveal confirmation page, the refusal page and the reveal-failed page (reached by stubbing): no sideways scroll, every tappable control at least 44 by 44, the sticky `.app-actions` holds "Save orders" and "Save and submit", and the confirmation page has its confirm and cancel controls (the same measuring helpers as `screens_layout_spec.rb`). One example drives the whole round in the browser: two seats save, one submits, the host opens the confirmation page and sees the other power named, confirms, and the host page shows the banner.
- Screenshots (not committed as a spec): a throwaway spec in the scratchpad visits the same screens at 360 pixels and saves PNGs to `docs/specs/022-phase-lifecycle/screens/`; the PR body links them.
- Proof, from `web/`: `bundle exec rspec` (all, system included), `bin/brakeman`, `bin/rubocop`; `git diff --name-only main...HEAD` lists only paths under `web/`; the `Web specs` job is green after the push.
- Reviews and the end of the run (outside the plan's code): the Opus implementation review recorded in the PR description; `session-wrap`; the draft PR from `.github/pull_request_template.md`.

Commit: "Add phone-width system specs and the screenshots for the phase screens".

## Coverage of the spec

| Spec | Phase |
|---|---|
| FR-1 Phases | 1, 3 |
| FR-2 Saving orders | 4 (rules), 5 (endpoint) |
| FR-3 Submissions | 4 |
| FR-4 The orders page | 5, 9 |
| FR-5 The saving rule | 4 |
| FR-6 Refusal after the reveal | 4 (model guard), 7 |
| FR-7 The reveal | 1 (page), 7 |
| FR-8 The next phase | 7 |
| FR-9 Order secrecy | 4 (filters), 5 (headers), 6, 8 |
| FR-10 The three components | 2 |
| D9 reissue | 6 |
| Stylesheet caps (changelog 1.2.0) | 2 |
| Specs 020 and 021 amended | done at Gate A; 2, 3 and 6 change the specs that assert them |

## Risks the plan names

- **`update_all` and the attribute type** (Phase 7): read in Rails' source and proven by the stored-adjudication example.
- **The concurrency specs depend on SQLite's busy timeout** (5 seconds) and on a `sleep 0.2` to observe the second thread waiting. They are run five times in a row in Phase 7.
- **The stylesheet caps**: Phase 2's rules fit in well under 1.5 KB; the caps are raised first so the check cannot fail on size.
- **The invariance sweep's normalization** (CSRF tokens, nonces) may need one more token pattern when it first runs; each pattern added is listed in the spec's comment.
- **Order text in a debug SQL log** (Phase 8): a stated limit, with a spec on the default log level.
- **Existing specs touched:** `player_spec` (the seat-page sentence), `closing_spec` and `reissue_spec` (they keep their words, through the confirm partial's locals), `styleguide_spec` (three more components), `stylesheet_rules_spec` (the caps), `host_spec` and `reissue_spec` (seven seat rows, kept by placing the history list outside the host section).

## Changelog

| Version | Change |
|---------|--------|
| 1.1.1 | After the second Opus round: the concurrency spec lowers `busy_handler_timeout` (not `busy_timeout`, which would hang the main thread); refusal sentences read correctly with `%{unit}` and `%{Unit}` and one spec renders all 17; AC-7.3's count check is exact; stale cross-references fixed; the concurrency specs get their own commit |
| 1.1.0 | After the first Opus review.<br>• Phase 4 is split into the saving rules (the model) and the orders page and endpoint (Phase 5); the reissue phase moves up to 6, the reveal is 7 (its concurrency specs a second commit), secrecy 8, phone width and proof 9.<br>• The concurrency specs set `self.use_transactional_tests = false`, take the lock with a first statement, restore the busy timeout, and release the gate in an `ensure`.<br>• The confirm partial takes `cancel_label` (default "Back"), keeps the old pages' words and takes a `heading` local so `/styleguide` keeps one `h1`.<br>• The route table builds keys with `MOUNT` for `/cable`. The phase routes carry a segment constraint. The phase header does not wrap. `RulesEngine.province?` gives AC-2.5's sentence. Refusal sentences name the unit. `SavedOrder` filters with `+=`. The secrecy specs' false positives are fixed. A test for `Seat::Stale` and two CSRF examples are added. The SQL debug-log limit is stated.<br>• Smaller: the reissue page sentence moves to Phase 6, the seat-page link and count to Phase 5, the reveal `POST` route to Phase 7, redirects use 303 |
| 1.0.0 | First draft |

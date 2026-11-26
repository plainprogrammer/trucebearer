# Plan 023: Enter movement orders with pickers

**Spec:** `web/docs/specs/023-order-pickers/spec.md` v1.0.2 (Approved at Gate A)
**Issue:** #23 · **Branch:** `web/23-order-pickers` · **Plan version:** 1.0.0

## Goal

Replace spec 022's plain orders form with the order screen (a unit list and a submit bar) and the picker steps, as the spec says. Every choice comes from `RulesEngine.legal_orders`; every pick is one `PUT` to the existing endpoint (`Seat#save_orders!`). All work is under `web/`. Each phase is test first (RSpec), ends with its own specs green, and is one commit. Commit messages are plain imperative sentences ending with the `Co-Authored-By:` line. Every gem call stays in `app/models/rules_engine.rb`.

## Decisions the plan adds (each traceable to the spec)

- **The draft has three keys, not five.** `draft[kind]`, `draft[target]`, `draft[to]`. The spec's `draft[coast]` and `draft[via]` are not needed: the coast step and the by-land-or-convoy step are reached from `kind=move&to=<province>` (a destination with several orders is exactly one of the two), and their choices are the final saves, not drafts. Spec changelog 1.0.3 records this (Phase 9).
- **The sweep's deep pages use `lvp`, not `lon`.** England's fleet in London has no support orders at the start, so a deep draft cannot be built on it. Liverpool's army can support the fleet in Edinburgh: `/orders/lvp?draft[kind]=support&draft[target]=edi`. France's own deep page is `/orders/par?draft[kind]=support&draft[target]=bre`. Recorded in changelog 1.0.3.
- **A hold-only or move-only support** cannot be found in a real position (any unit a supporter can reach also has a move the supporter can reach, and the reverse needs a distant origin). AC-2.10's crawler walks real positions (both a move-only branch, Austria's VIE for WAR, and the both-branch, England's LVP for EDI); the two single-branch cases are covered in `order_choices_spec.rb` with `RulesEngine.legal_orders` stubbed to a hand-written list. Recorded in changelog 1.0.3.
- **Names.** `OrderChoices` (model, plain Ruby), `OrderPickersController#show`, concern `OrderScreen` (the phase lookup and the revealed page that `SeatOrdersController` and `OrderPickersController` share), helper methods `province_label` and `order_words` (replacing `order_label`), partials `seat_orders/_unit_row`, `seat_orders/_submit_bar`, `shared/_save_status`, `order_pickers/_choice`, `order_pickers/_draft`.
- **A choice** is `OrderChoices::Choice = Data.define(:words, :province, :note, :draft, :save)`: `draft` is the query for a link, `save` is the text a form posts (an order's JSON, or `""` for "No order"). Exactly one of the two is set. A step is `Step = Data.define(:title, :trail, :choices, :back)`.
- **The list stops calling the gem for choices.** The order screen needs the position's units, the seat's own stored orders, and province names; `legal_orders` is called only by the picker.
- **No new JavaScript, no frames, no new gem or pin.**

## Gates checked

- **Simplicity:** one model (`OrderChoices`), one controller, one concern, five partials, three small helper changes, one route.
- **Anti-abstraction:** no service objects, no presenters; `OrderChoices` is a plain class with one public entry point (`step`).
- **Integration-first:** Phase 3 starts from the request spec the brief names, against the real routes and database.

## Phase 1: `RulesEngine` knows province names and army adjacency

**Implements:** FR-3 (the two methods). **Satisfies:** the boundary of spec 019.
**Files:** change `app/models/rules_engine.rb`, `spec/models/rules_engine_spec.rb`.

Test first:

```ruby
# spec/models/rules_engine_spec.rb (added)
describe ".province_name" do
  it "gives the full name of a province, by symbol or string" do
    expect(RulesEngine.province_name("lvp")).to eq("Liverpool")
    expect(RulesEngine.province_name(:stp)).to eq("St Petersburg")
  end

  it "raises the gem's invalid-input error for an unknown province" do
    expect { RulesEngine.province_name("xxx") }.to raise_error(RulesEngine::InvalidInput)
  end
end

describe ".army_adjacent?" do
  it "is true when an army could walk from one province to the other and false when it could not" do
    expect(RulesEngine.army_adjacent?("lon", "yor")).to be(true)
    expect(RulesEngine.army_adjacent?("lon", "nwy")).to be(false)
  end
end
```

Then:

```ruby
# app/models/rules_engine.rb (inside the class << self block, after province?)
# The full name of a province ("Liverpool"), for labels (spec 023 FR-3).
def province_name(id) = TA::Map.classic.province(id.to_sym).name

# Whether an army could walk between two provinces: used to say a plain move of an army "needs a convoy" (spec 023 D3).
def army_adjacent?(from, to)
  TA::Map.classic.adjacent?(:army, TA::Location.new(province: from.to_sym), TA::Location.new(province: to.to_sym))
end
```

**Verify:** `bundle exec rspec spec/models/rules_engine_spec.rb spec/models/rules_engine_boundary_spec.rb`. **Commit:** "Let RulesEngine name provinces and test army adjacency".

## Phase 2: Words for provinces and orders

**Implements:** FR-3. **Satisfies:** AC-1.2, AC-1.3, AC-1.9 (the words).
**Files:** change `app/helpers/order_label_helper.rb`, `spec/helpers/order_label_helper_spec.rb`.

Test first (replaces the old `order_label` examples):

```ruby
# spec/helpers/order_label_helper_spec.rb
RSpec.describe OrderLabelHelper, type: :helper do
  include RulesHelpers
  let(:position) do
    rules_position(units: [ [ :england, :army, :lon ], [ :england, :fleet, :nth ], [ :france, :fleet, :mao ], [ :france, :army, :bre ] ])
  end

  def unit_at(province) = position.units.find { |u| u.location.province.to_s == province }

  it "writes a province as its full name with the abbreviation in the mono face" do
    html = helper.province_label("lvp")
    expect(html).to eq('Liverpool (<span class="mono">LVP</span>)')
    expect(html).to be_html_safe
  end

  it "reads orders in words, full names first" do
    words = ->(order, province) { Nokogiri::HTML5.fragment(helper.order_words(order, unit_at(province))).text }
    expect(words.(rules_order(:hold, :england, :lon), "lon")).to eq("Hold")
    expect(words.(move(:england, :nth, :nwg), "nth")).to eq("Move to Norwegian Sea (NWG)")
    expect(words.(move(:france, :mao, :spa, :nc), "mao")).to eq("Move to Spain (SPA), north coast")
    expect(words.(rules_order(:move_via_convoy, :england, :lon, to: "yor"), "lon")).to eq("Move to Yorkshire (YOR) by convoy")
    expect(words.(rules_order(:support_hold, :france, :bre, target: "mao"), "bre")).to eq("Support hold in Mid-Atlantic Ocean (MAO)")
    expect(words.(rules_order(:support_move, :england, :lon, from: "nth", to: "yor"), "lon")).to eq("Support North Sea (NTH) to Yorkshire (YOR)")
    expect(words.(rules_order(:convoy, :england, :nth, from: "lon", to: "nwy"), "nth")).to eq("Convoy London (LON) to Norway (NWY)")
  end

  it "marks only an army's plain move to a province it cannot walk to (AC-1.9)" do
    words = ->(order, province) { Nokogiri::HTML5.fragment(helper.order_words(order, unit_at(province))).text }
    expect(words.(move(:england, :lon, :nwy), "lon")).to eq("Move to Norway (NWY), needs a convoy")
    expect(words.(move(:england, :lon, :yor), "lon")).to eq("Move to Yorkshire (YOR)")
    expect(words.(move(:england, :nth, :nwy), "nth")).to eq("Move to Norway (NWY)") # a fleet
  end
end
```

Then:

```ruby
# app/helpers/order_label_helper.rb
# Words for provinces and orders on the order screen and the picker (spec 023 FR-3). It reads an order's hash form and the unit
# it is for, so it names no gem class.
module OrderLabelHelper
  COASTS = { "nc" => "north coast", "sc" => "south coast", "ec" => "east coast" }.freeze

  # "Liverpool (LVP)", the abbreviation in the mono face.
  def province_label(id)
    id = id.to_s
    safe_join([ RulesEngine.province_name(id), " (", tag.span(id.upcase, class: "mono"), ")" ])
  end

  def order_words(order, unit)
    h = order.to_h
    case h["type"]
    when "hold" then "Hold"
    when "move" then move_words(h, unit)
    when "move_via_convoy" then safe_join([ "Move to ", province_label(h["to"]), " by convoy" ])
    when "support_hold" then safe_join([ "Support hold in ", province_label(h["target"]) ])
    when "support_move" then safe_join([ "Support ", province_label(h["from"]), " to ", province_label(h["to"]) ])
    when "convoy" then safe_join([ "Convoy ", province_label(h["from"]), " to ", province_label(h["to"]) ])
    end
  end

  private

  def move_words(h, unit)
    destination = h["destination"]
    parts = [ "Move to ", province_label(destination["province"]) ]
    parts << ", #{COASTS.fetch(destination["coast"])}" if destination["coast"]
    parts << ", needs a convoy" if unit.type == :army && !RulesEngine.army_adjacent?(h["at"], destination["province"])
    safe_join(parts)
  end
end
```

(`order_label` is removed; its only users are the plain form's view, replaced in Phase 3.)

**Verify:** `bundle exec rspec spec/helpers`. **Commit:** "Write orders and provinces in words with full names".

## Phase 3: The first test, and the order screen (the plain form goes)

**Implements:** FR-1, FR-4, FR-5, FR-6 (list parts), D4, D6, D9. **Satisfies:** AC-1.1 to AC-1.9, AC-3.2, AC-3.4, AC-4.1 to AC-4.6 (list and submit bar), AC-8.2.
**Files:**
- Create `spec/requests/order_screen_spec.rb`, `app/controllers/concerns/order_screen.rb`, `app/views/seat_orders/_unit_row.html.erb`, `app/views/seat_orders/_submit_bar.html.erb`, `app/views/shared/_save_status.html.erb`.
- Change `app/controllers/seat_orders_controller.rb`, `app/views/seat_orders/show.html.erb`, `app/assets/stylesheets/components.css` (`.unit-row`, `.submit-bar`, `.save-status`), `spec/requests/orders_spec.rb`, `spec/system/phase_screens_spec.rb`, `spec/requests/order_secrecy_spec.rb` (the label checks), and any other spec that fails because the plain form is gone (the full suite tells; the list is `orders_spec`, `phase_pages_spec`, `reissue_clears_orders_spec`, `reveal_post_spec`, `system/screens_layout_spec` as of now).

### 3a. The first test (red). It fails until the screen exists

```ruby
# spec/requests/order_screen_spec.rb
require "rails_helper"
require_relative "../support/rules_helpers"

# Spec 023 Story 1 and 4 over HTTP: the order screen. England starts with a fleet in EDI, a fleet in LON and an army in LVP.
RSpec.describe "The order screen", type: :request do
  include RulesHelpers

  around { |example| with_passphrase { example.run } }

  let(:created) { create_game(power: "england") }
  let(:game) { created.game }
  let(:id) { game.public_id }
  let(:england) { game.seats.find_by(power: "england") }
  let(:phase) { game.current_phase }
  let(:phone) { created.session }

  def page = Nokogiri::HTML5(phone.response.body)

  def rows = page.css(".unit-row").map { |row| row.text.squish }

  it "lists England's three units with 'holds', and the submit bar says '0 of 3 ordered' (AC-1.1)" do
    phone.get "/games/#{id}/phases/1/orders"

    expect(phone.response).to have_http_status(:ok)
    expect(rows).to eq([ "Fleet in Edinburgh (EDI) holds", "Fleet in London (LON) holds", "Army in Liverpool (LVP) holds" ])
    expect(page.at_css(".app-actions .submit-bar").text.squish).to include("0 of 3 ordered")
    expect(page.at_css(".save-status").text.squish).to start_with("Saved")
  end
end
```

Run it: it fails (the page has selects and no `.unit-row`). This is the first commit's red state; it is committed together with the green code in 3b.

### 3b. The controller, the concern, the views, the styles

```ruby
# app/controllers/concerns/order_screen.rb
# What the orders endpoint, the order screen and the picker share (spec 023 FR-1, FR-2): the phase lookup and the revealed page.
module OrderScreen
  extend ActiveSupport::Concern

  private

  # A phase of this game that exists and is not later than the open one. Anything else is the stranger response.
  def find_phase_or_stranger
    @phase = find_phase(@game)
    stranger!(@game) unless @phase && @phase.number <= @game.current_phase.number
  end

  def render_revealed = render("seat_orders/revealed", status: :conflict)

  # A page about a seat's own orders is never cached and never leaks its address (spec 022 AC-7.6, spec 023 AC-3.7).
  def own_orders_headers
    no_store
    response.set_header("Referrer-Policy", "no-referrer")
  end
end
```

```ruby
# app/controllers/seat_orders_controller.rb (changed parts)
class SeatOrdersController < ApplicationController
  include OrderScreen
  before_action :require_seat
  before_action :find_phase_or_stranger
  before_action :own_orders_headers

  def show
    return render_revealed unless @phase.open?

    load_page
  end

  def update
    return render_revealed unless @phase.open?

    entries = order_entries
    return refuse(Seat::UNREADABLE) unless entries

    result = @seat.save_orders!(@phase, entries, submit: params[:submit] == "1")
    flash[:banner] = { "kind" => "info", "text" => "Submitted." } if params[:submit] == "1" && result.submitted
    redirect_to game_seat_orders_path(@game.public_id, @phase.number), status: :see_other
  rescue Seat::Refusal => error
    refuse(error.message)
  rescue Phase::Revealed
    render_revealed
  rescue Seat::Stale
    @game.seats.reset
    stranger!(@game)
  end

  private

  # (order_entries unchanged)

  def load_page
    @units = @phase.position.units.select { |unit| unit.power.to_s == @seat.power }.sort_by { |unit| unit.location.province.to_s }
    @stored = @seat.orders_for(@phase)
    @submitted = @seat.submitted?(@phase)
  end

  def refuse(sentence)
    @refusal = sentence
    load_page
    render :show, status: :unprocessable_content
  end
end
```

```erb
<%# app/views/seat_orders/show.html.erb %>
<% content_for :title, "Your orders" %>
<% content_for :head, tag.meta(name: "turbo-cache-control", content: "no-cache") %>

<div class="stack">
  <h1>Your orders</h1>
  <%= render "phases/header", phase: @phase, power: @seat.power %>
  <% if @refusal %><%= render "shared/banner", kind: "danger", text: @refusal %><% end %>
  <p>Tap a unit to give it an order. A unit with no order holds.</p>
  <ul class="list">
    <% @units.each do |unit| %>
      <%= render "seat_orders/unit_row", unit: unit, order: @stored[unit.location.province.to_s], game: @game, phase: @phase %>
    <% end %>
  </ul>
</div>

<% content_for :actions do %>
  <%= render "seat_orders/submit_bar", game: @game, phase: @phase, submitted: @submitted, ordered: @stored.size, total: @units.size,
                                       state: @refusal ? :not_saved : :saved %>
<% end %>
```

```erb
<%# app/views/seat_orders/_unit_row.html.erb  locals: unit, order (or nil), game, phase %>
<% province = unit.location.province.to_s %>
<li>
  <%= link_to game_order_picker_path(game.public_id, phase.number, province), class: "list__row unit-row" do %>
    <%= unit_icon(unit.power, unit.type, size: 32, decorative: true) %>
    <span class="unit-row__body">
      <span class="unit-row__unit"><%= unit.type.to_s.capitalize %> in <%= province_label(province) %></span>
      <span class="unit-row__order<%= " unit-row__order--none" unless order %>"><%= order ? order_words(order, unit) : "holds" %></span>
    </span>
  <% end %>
</li>
```

```erb
<%# app/views/seat_orders/_submit_bar.html.erb  locals: game, phase, submitted, ordered, total, state %>
<div class="submit-bar">
  <%= render "shared/save_status", state: state %>
  <% if submitted %>
    <p class="submit-bar__state">Submitted · <%= ordered %> of <%= total %> ordered</p>
    <%= link_to "Back to your seat", game_path(game.public_id), class: "button button--secondary" %>
  <% else %>
    <p class="submit-bar__state">Not submitted</p>
    <%= form_with url: game_seat_orders_path(game.public_id, phase.number), method: :put do %>
      <%= button_tag type: "submit", name: "submit", value: "1", class: "button submit-bar__button" do %>
        Submit orders <span class="submit-bar__count"><%= ordered %> of <%= total %> ordered</span>
      <% end %>
    <% end %>
  <% end %>
</div>
```

```erb
<%# app/views/shared/_save_status.html.erb  locals: state (:saved, :saves_on_pick or :not_saved). Two spans, so CSS can show
    "Saving…" while Turbo submits a form and plain text is always real text (spec 023 D6). %>
<% rest = { saved: "Saved", saves_on_pick: "Saves when you pick", not_saved: "Not saved" }.fetch(state) %>
<p class="save-status" role="status"><span class="save-status__rest"><%= rest %></span><span class="save-status__saving">Saving…</span></p>
```

The picker route name used above (`game_order_picker_path`) is added in Phase 5; in Phase 3 the route is added with a stub `order_pickers#show` that raises `NotImplementedError`-free `head :not_implemented`, replaced in Phase 5. (A route is needed for the rows' links; the stub is never in a green commit's behavior.)

```css
/* components.css (added, inside the existing layer; tokens only) */
.unit-row { gap: var(--space-3); }
.unit-row__body { display: flex; flex: 1; flex-direction: column; min-width: 0; }
.unit-row__order { color: var(--color-text-muted); overflow-wrap: anywhere; }
.unit-row::after {
  content: ""; flex: none; inline-size: 0.6rem; block-size: 0.6rem;
  border: solid currentcolor; border-width: 2px 2px 0 0; transform: rotate(45deg);
}
.submit-bar { display: flex; flex: 1 1 100%; flex-wrap: wrap; align-items: center; gap: var(--space-2) var(--space-3); }
.submit-bar form { display: contents; }
.submit-bar__state { flex: 1 1 auto; margin: 0; }
.submit-bar__count { display: block; font-size: var(--text-base); }
.save-status { flex: 1 1 100%; margin: 0; color: var(--color-text-muted); }
.save-status__saving { display: none; }
.app:has(form[aria-busy="true"]) .save-status__rest { display: none; }
.app:has(form[aria-busy="true"]) .save-status__saving { display: inline; }
```

(The exact rules are tuned against the layout specs of Phase 8; the stylesheet-rules spec decides what is allowed, and the byte budget is checked at the end of this phase.)

### 3c. Rewrite the specs that asserted the plain form (AC-8.2)

`orders_spec.rb` "the page": replace the select/option examples with examples on `.unit-row`s (stored order shown as words, seat state in the bar, no `<select>`); `order_secrecy_spec.rb`: replace `option[selected]` checks with "the body contains none of France's order JSON or `Move to` text of England's labels" and `"3 of 3 units ordered"` with `"3 of 3 ordered"`; `phase_screens_spec.rb`: the sticky-area assertion becomes the submit bar's button text. Endpoint examples (saving, refusals, submit, partial update) stay as they are.

**Verify:** `bundle exec rspec` (the whole suite, system specs included), then `wc -c app/assets/stylesheets/*.css` (total ≤ 32,768, `styleguide.css` ≤ 6,144). **Commit:** "Replace the plain orders form with the order screen".

## Phase 4: `OrderChoices`, and the crawler that proves it

**Implements:** FR-2, D1, D3. **Satisfies:** AC-2.1, AC-2.4 to AC-2.10 (model level), AC-2.14 (trail and back).
**Files:** create `app/models/order_choices.rb`, `spec/models/order_choices_spec.rb`.

Test first:

```ruby
# spec/models/order_choices_spec.rb
require "rails_helper"
require_relative "../support/rules_helpers"

RSpec.describe OrderChoices do
  include RulesHelpers

  POSITIONS = {
    "the starting position" => -> { RulesEngine.starting_position },
    "fleets at sea, armies on the coast, a split coast" => lambda { |h|
      h.rules_position(units: [ [ :france, :fleet, :mao ], [ :france, :fleet, :gol ], [ :france, :army, :gas ], [ :france, :army, :mar ],
                                [ :england, :fleet, :eng ] ])
    },
    "an army with a land route and a convoy chain" => lambda { |h|
      h.rules_position(units: [ [ :england, :army, :lon ], [ :england, :fleet, :nth ], [ :germany, :fleet, :hel ] ])
    },
    "Austria supports a move from far away" => lambda { |h|
      h.rules_position(units: [ [ :austria, :army, :vie ], [ :russia, :army, :war ], [ :austria, :army, :bud ] ])
    }
  }.freeze

  # Every save a chain of picks can reach, found by following each step's own choices (AC-2.10).
  def saves_reachable(choices, draft = {})
    step = choices.step(draft)
    raise "no step for #{draft.inspect}" unless step

    step.choices.flat_map do |choice|
      choice.save ? [ choice.save ] : saves_reachable(choices, choice.draft)
    end
  end

  POSITIONS.each do |name, build|
    it "reaches exactly the legal orders of every unit, none missing, none extra, none twice: #{name} (AC-2.10)" do
      position = build.arity.zero? ? build.call : build.call(self)
      position.units.each do |unit|
        choices = OrderChoices.new(position, unit, ordered: true)
        legal = RulesEngine.legal_orders(position, unit).map { |order| JSON.generate(order.to_h) }
        reached = saves_reachable(choices).reject(&:empty?) # "" is "No order (holds)", not an order

        expect(reached).to match_array(legal), "#{unit.type} in #{unit.location.province}"
      end
    end
  end

  # (plus examples for: the action step's kinds and "No order" only when ordered (AC-2.1); destinations once each in legal_orders
  # order (AC-2.4); a split-coast destination links to its coast step and a one-coast one saves (AC-2.5); "By land"/"By convoy"
  # (AC-2.6); an army reachable only by convoy is marked and saves the plain move (AC-2.7); the support units, hold first (AC-2.8);
  # the convoy armies and destinations (AC-2.9); a draft that names no legal choice, a complete draft and an unknown key give nil
  # (AC-2.11); the trail and the back draft (AC-2.14); and the two single-branch supports, with RulesEngine.legal_orders stubbed
  # to a hold-only list and a move-only list.)
end
```

Then the model. Key shape (the full file is written test by test; each example above is one red-green step):

```ruby
# app/models/order_choices.rb
# What one unit can be told to do, as the picker's steps (spec 023 D1, D3, FR-2). Every choice is made from
# RulesEngine.legal_orders; the model reads each order's hash form and names no gem class. step(draft) says which page the
# draft leads to, or nil when the draft names no legal choice (the caller sends the player back to step 1).
class OrderChoices
  DRAFT_KEYS = %w[kind target to].freeze
  COAST_WORDS = { "nc" => "North coast", "sc" => "South coast", "ec" => "East coast" }.freeze

  Trail = Data.define(:words, :province)
  Choice = Data.define(:words, :province, :note, :draft, :save)
  Step = Data.define(:title, :trail, :choices, :back)

  # ordered: whether the seat has a saved order for this unit (it decides whether "No order (holds)" is offered).
  def initialize(position, unit, ordered:)
    @position = position
    @unit = unit
    @province = unit.location.province.to_s
    @ordered = ordered
    @orders = RulesEngine.legal_orders(position, unit).map { |order| [ order, order.to_h ] }
  end

  def step(draft)
    return action_step if draft.empty?
    return nil unless draft.keys.all? { |k| DRAFT_KEYS.include?(k) } && draft.values.all?(String)

    case draft["kind"]
    when "move" then move_step(draft)
    when "support" then support_step(draft)
    when "convoy" then convoy_step(draft)
    end
  end

  private

  def of_type(*types) = @orders.select { |_, h| types.include?(h["type"]) }

  def save_of(order) = JSON.generate(order.to_h)

  def action_step
    choices = [ Choice.new("Hold", nil, nil, nil, save_of(@orders.find { |_, h| h["type"] == "hold" }.first)) ]
    { "move" => %w[move move_via_convoy], "support" => %w[support_hold support_move], "convoy" => %w[convoy] }.each do |kind, types|
      choices << Choice.new(kind.capitalize, nil, nil, { "kind" => kind }, nil) if of_type(*types).any?
    end
    choices << Choice.new("No order (holds)", nil, nil, nil, "") if @ordered
    Step.new("What should it do?", [], choices, nil)
  end

  # Moves, grouped by destination province in the order the gem lists them. One order: a button that saves. Several (the coasts of
  # a split-coast province, or by land and by convoy): a link to the step that asks which (D3).
  def destinations = of_type("move", "move_via_convoy").group_by { |_, h| h["type"] == "move" ? h["destination"]["province"] : h["to"] }

  def move_step(draft)
    case draft.keys.sort
    when %w[kind] then destinations_step
    when %w[kind to] then which_way_step(draft["to"])
    end
  end

  def destinations_step
    choices = destinations.map do |province, entries|
      if entries.one?
        Choice.new(nil, province, needs_convoy?(province, entries.first.last) ? "needs a convoy" : nil, nil, save_of(entries.first.first))
      else
        Choice.new(nil, province, nil, { "kind" => "move", "to" => province }, nil)
      end
    end
    Step.new("Move where?", [ Trail.new("Move", nil) ], choices, {})
  end

  def needs_convoy?(province, hash) = @unit.type == :army && hash["type"] == "move" && !RulesEngine.army_adjacent?(@province, province)

  def which_way_step(province)
    entries = destinations[province]
    return nil unless entries && entries.size > 1

    by_convoy = entries.any? { |_, h| h["type"] == "move_via_convoy" }
    choices = entries.map do |order, h|
      words = h["type"] == "move_via_convoy" ? "By convoy" : (h["destination"]["coast"] ? coast_words(h["destination"]["coast"]) : "By land")
      Choice.new(words, nil, nil, nil, save_of(order))
    end
    Step.new(by_convoy ? "How does it get there?" : "Which coast?", [ Trail.new("Move to", province) ], choices, { "kind" => "move" })
  end

  def coast_words(coast) = "#{COAST_WORDS.fetch(coast)} (#{coast.upcase})"

  # support_step(draft) and convoy_step(draft) follow the same pattern: keys %w[kind] list the supported units (or convoyable
  # armies) as links, keys %w[kind target] list "Hold in place" then the destinations (or the convoy's destinations) as saves, and
  # any other key set, a target not in the list, or a complete draft gives nil.
end
```

The two methods elided in the comment are written in full in the implementation, each driven by its own red example from the list above; their only data sources are `of_type("support_hold", "support_move")` and `of_type("convoy")`, read through `h["target"]`, `h["from"]` and `h["to"]`.

**Verify:** `bundle exec rspec spec/models/order_choices_spec.rb` and the boundary spec (the model names no gem class). **Commit:** "Group a unit's legal orders into the picker's steps".

## Phase 5: The picker pages and the route

**Implements:** FR-2 (the page), FR-7, D2, D5, D6. **Satisfies:** AC-2.1 to AC-2.15, AC-3.1, AC-3.3, AC-3.5, AC-3.7, AC-6.2.
**Files:**
- Create `app/controllers/order_pickers_controller.rb`, `app/views/order_pickers/show.html.erb`, `_choice.html.erb`, `_draft.html.erb`, `spec/requests/order_pickers_spec.rb`.
- Change `config/routes.rb`, `config/initializers/filter_parameter_logging.rb`, `spec/config/filter_parameters_spec.rb`, `app/assets/stylesheets/components.css` (`.picker`, `.picker__draft`).

Test first (`spec/requests/order_pickers_spec.rb`, request specs against the real routes; each example is one red-green step):

```ruby
RSpec.describe "The picker steps", type: :request do
  include RulesHelpers
  around { |example| with_passphrase { example.run } }
  let(:created) { create_game(power: "england") }
  let(:id) { created.game.public_id }
  let(:phone) { created.session }
  let(:picker) { "/games/#{id}/phases/1/orders/lvp" }
  def page = Nokogiri::HTML5(phone.response.body)

  it "offers Hold, Move and Support to the army in Liverpool, and no Convoy (AC-2.1)" do
    phone.get picker
    expect(phone.response).to have_http_status(:ok)
    expect(page.css(".picker .list .list__row").map { |r| r.text.squish }).to eq(%w[Hold Move Support])
    expect(page.at_css(".picker__draft").text).to include("Army in Liverpool (LVP)")
  end

  it "saves a hold with one PUT and lands on the screen (AC-2.2)" do
    phone.get picker
    form = page.at_css(".picker form")
    phone.put "/games/#{id}/phases/1/orders", params: { orders: { "lvp" => form.at_css("input[name='orders[lvp]']")["value"] } }
    expect(phone.response).to have_http_status(:see_other)
    phone.follow_redirect!
    expect(page.at_css(".unit-row:last-child, li:last-child .unit-row").text).to include("Hold")
  end

  it "walks a whole order with only the page's own links and forms: no script is needed (AC-3.5)" do
    phone.get "/games/#{id}/phases/1/orders"
    phone.get page.at_xpath("//a[contains(., 'Army in Liverpool')]")["href"]
    phone.get page.at_xpath("//a[normalize-space()='Move']")["href"]
    form = page.css(".picker form").find { |f| f.text.include?("Wales") }
    phone.post form["action"], params: Rack::Utils.parse_nested_query(URI.encode_www_form(form.css("input").to_h { |i| [ i["name"], i["value"] ] }))
    # (the real example submits the form's fields exactly as a browser would, including _method and authenticity_token)
    expect(phone.response).to have_http_status(:see_other)
  end

  it "sends a draft that names no legal choice back to step 1, without echoing it (AC-2.11)"
  it "gives the stranger response for another power's province, and 409 for a revealed phase (AC-2.12, AC-2.13)"
  it "carries no-store, no-referrer and no script (AC-2.15, AC-3.5, AC-3.7)"
  it "keeps draft out of the logged request line (AC-3.7)" do
    request = ActionDispatch::Request.new(Rack::MockRequest.env_for("/x?draft%5Bto%5D=bel"))
    expect(request.filtered_path).not_to include("bel")
  end
end
```

The pending examples above are written in full as the phase proceeds (none is left `pending` at the commit). Then the code:

```ruby
# config/routes.rb (added after the existing orders routes, inside the games scope)
get "phases/:number/orders/:province", to: "order_pickers#show", as: :game_order_picker,
    constraints: { number: %r{[^/]+}, province: %r{[^/]+} }
```

```ruby
# config/initializers/filter_parameter_logging.rb: add :draft to the list (the unfinished order in the query, spec 023 D2)
```

```ruby
# app/controllers/order_pickers_controller.rb
# One picker step for one of the seat's units (spec 023 D1, D2, FR-2). A GET never writes: the last pick is a form that PUTs to the
# orders endpoint.
class OrderPickersController < ApplicationController
  include OrderScreen
  before_action :require_seat
  before_action :find_phase_or_stranger
  before_action :own_orders_headers

  def show
    return render_revealed unless @phase.open?

    province = params[:province].to_s
    @unit = @phase.position.units.find { |u| u.power.to_s == @seat.power && u.location.province.to_s == province }
    return stranger!(@game) unless @unit

    choices = OrderChoices.new(@phase.position, @unit, ordered: @seat.orders_for(@phase).key?(province))
    draft = draft_param
    @step = draft && choices.step(draft)
    return redirect_to(game_order_picker_path(@game.public_id, @phase.number, province), status: :see_other) unless @step

    @province = province
  end

  private

  # {} when absent, the string-keyed hash when it is one, nil when it is anything else (a string, an array).
  def draft_param
    raw = params[:draft]
    return {} if raw.nil?

    raw.respond_to?(:to_unsafe_h) ? raw.to_unsafe_h : nil
  end
end
```

```erb
<%# app/views/order_pickers/show.html.erb %>
<% content_for :title, @step.title %>
<% content_for :head, tag.meta(name: "turbo-cache-control", content: "no-cache") %>

<div class="stack picker">
  <h1><%= @step.title %></h1>
  <%= render "phases/header", phase: @phase, power: @seat.power %>
  <%= render "order_pickers/draft", unit: @unit, trail: @step.trail %>
  <ul class="list">
    <% @step.choices.each do |choice| %>
      <li>
        <% if choice.save %>
          <%= form_with url: game_seat_orders_path(@game.public_id, @phase.number), method: :put do %>
            <%= hidden_field_tag "orders[#{@province}]", choice.save, id: nil %>
            <%= button_tag type: "submit", class: "list__row" do %><%= render "order_pickers/choice", choice: choice %><% end %>
          <% end %>
        <% else %>
          <%= link_to game_order_picker_path(@game.public_id, @phase.number, @province, draft: choice.draft), class: "list__row" do %>
            <%= render "order_pickers/choice", choice: choice %>
          <% end %>
        <% end %>
      </li>
    <% end %>
  </ul>
</div>

<% content_for :actions do %>
  <%= render "shared/save_status", state: :saves_on_pick %>
  <% back = @step.back ? game_order_picker_path(@game.public_id, @phase.number, @province, draft: @step.back) : game_seat_orders_path(@game.public_id, @phase.number) %>
  <%= link_to "Back", back, class: "button button--secondary" %>
<% end %>
```

```erb
<%# app/views/order_pickers/_choice.html.erb  locals: choice. Words, the province in full with its abbreviation, then a short note. %>
<span class="picker__choice"><%= choice.words %> <%= province_label(choice.province) if choice.province %></span>
<% if choice.note %><span class="picker__note"><%= choice.note %></span><% end %>
```

```erb
<%# app/views/order_pickers/_draft.html.erb  locals: unit, trail. The order so far, in words. %>
<div class="picker__draft">
  <p class="picker__unit"><%= unit_icon(unit.power, unit.type, size: 32, decorative: true) %>
    <%= unit.type.to_s.capitalize %> in <%= province_label(unit.location.province) %></p>
  <% if trail.any? %>
    <p class="picker__trail"><%= safe_join(trail.map { |t| safe_join([ t.words, (province_label(t.province) if t.province) ].compact, " ") }, " → ") %></p>
  <% end %>
</div>
```

```css
/* components.css (added) */
.picker { gap: var(--space-4); }
.picker__draft { padding: var(--space-3) var(--space-4); background: var(--color-ice-pale); border-radius: var(--radius); }
.picker__draft p { margin: 0; }
.picker__choice { flex: 1; overflow-wrap: anywhere; }
.picker__note { color: var(--color-text-muted); }
```

(The choice for a "support which unit" row shows `words` "Army in", the province, and the power's name as `note`: `OrderChoices` fills it from `RulesEngine.powers`.)

**Verify:** `bundle exec rspec spec/requests spec/models spec/config spec/helpers`, then the stylesheet byte count. **Commit:** "Add the picker steps for entering orders".

## Phase 6: Secrecy: classify, sweep, scan

**Implements:** FR-8. **Satisfies:** AC-5.1 to AC-5.6.
**Files:** change `spec/support/secrecy_routes.rb`, `spec/requests/order_secrecy_spec.rb`.

Test first (these examples fail until the support file is changed):

```ruby
# spec/requests/order_secrecy_spec.rb (changed examples)
it "marks as showing orders only the seat page, the orders page, the picker and the endpoint" do
  showing = SecrecyRoutes::APP.select { |_key, entry| entry[:shows] == :own }.keys
  expect(showing).to match_array([ "GET /games/:public_id", "GET /games/:public_id/phases/:number/orders",
                                   "GET /games/:public_id/phases/:number/orders/:province",
                                   "PUT /games/:public_id/phases/:number/orders" ])
end

it "gives the sweep real pages to compare: France reaches its own deep picker step, England reaches its own (AC-5.2)" do
  set_orders(:none)
  expect(status.call("another seat", "GET /games/:public_id/phases/:number/orders/:province [par]")).to eq(200)
  england_phone.get "/games/#{id}/phases/1/orders/lvp?draft%5Bkind%5D=support&draft%5Btarget%5D=edi"
  expect(england_phone.response).to have_http_status(:ok)
end

it "shows England's orders nowhere on a picker page of France's, or in England's list for France's saved orders (AC-5.3)" do
  # France saves orders England's units cannot reach; England walks every step of every unit; none of France's order JSON or counts appears
end
```

```ruby
# spec/support/secrecy_routes.rb (changed)
# A route's `sweep` is a path, or a Hash of { label => path } when one route needs several pages to be swept (the picker's own
# units, each with a deep draft).
"GET /games/:public_id/phases/:number/orders/:province" => {
  shows: :own,
  sweep: ->(c) { { "lvp" => "/games/#{c.id}/phases/1/orders/lvp?draft%5Bkind%5D=support&draft%5Btarget%5D=edi",
                   "par" => "/games/#{c.id}/phases/1/orders/par?draft%5Bkind%5D=support&draft%5Btarget%5D=bre" } },
  why: "the seat's own picker steps; a province that is not the viewer's unit is the stranger page"
},

# Every page the sweep requests, as { label => { path:, entry: } }.
def self.sweeps(context)
  readable.flat_map do |key, entry|
    result = entry[:sweep].call(context)
    result.is_a?(Hash) ? result.map { |name, path| [ "#{key} [#{name}]", { path: path, entry: entry } ] } : [ [ key, { path: result, entry: entry } ] ]
  end.to_h
end
```

The sweep's `snapshot` loops over `SecrecyRoutes.sweeps(context)` instead of `readable`, its size check compares to `sweeps(context).size`, and the status lookups use the new labels. The "never carries England's orders" example also requests the new route for every viewer. The saved-orders source scan (`saved_order_boundary_spec.rb`) is untouched and must stay green: the picker names neither `SavedOrder` nor `saved_orders` (it uses `Seat#orders_for`).

**Verify:** `bundle exec rspec spec/requests/order_secrecy_spec.rb spec/models/saved_order_boundary_spec.rb`. **Commit:** "Classify and sweep the picker routes for secrecy".

## Phase 7: The parts in the style guide and the catalog

**Implements:** FR-6. **Satisfies:** AC-6.1 to AC-6.6.
**Files:** change `app/views/styleguide/show.html.erb`, `web/docs/design-system.md`, `app/assets/stylesheets/styleguide.css` if a sample needs layout, `spec/requests/styleguide_spec.rb`, `spec/system/styleguide_layout_spec.rb`, `spec/docs/design_system_spec.rb` if it names the catalog lines.

Test first: the style-guide request spec asserts a `[data-component="unit-row"]`, `[data-component="picker"]` and `[data-component="submit-bar"]` section; the layout spec (existing, already looping over sections) passes at 360 and 768; the design-system spec asserts the three catalog lines say "#23 (built)" with partial names. The sections reuse the real partials with sample data (a unit row with an order, a unit row that holds, a picker draft with choices, the submit bar in each of its states: not submitted, submitted, "Saved", "Saves when you pick", "Not saved"). The "Saving…" state is shown with a sample whose wrapper carries `aria-busy` on a dummy form.

```ruby
# spec/requests/styleguide_spec.rb (added)
it "has the unit row, picker and submit bar sections (AC-6.4)" do
  get "/styleguide"
  page = Nokogiri::HTML5(response.body)
  %w[unit-row picker submit-bar].each { |name| expect(page.at_css("[data-component='#{name}']")).to be_present, name }
end
```

**Verify:** `bundle exec rspec spec/requests/styleguide_spec.rb spec/system/styleguide_layout_spec.rb spec/docs spec/styles` and the byte count (≤ 32,768 total, `styleguide.css` ≤ 6,144; if it does not fit, stop and `ask`). **Commit:** "Add the order screen parts to the style guide".

## Phase 8: System specs at 360 pixels: the walk-through, the other steps, the status

**Implements:** D6, D7. **Satisfies:** AC-3.6, AC-4.6, AC-6.1, AC-7.1 to AC-7.4.
**Files:** create `spec/system/order_pickers_spec.rb`; change `spec/system/phase_screens_spec.rb` if it still names the old buttons.

```ruby
# spec/system/order_pickers_spec.rb
require "rails_helper"
require_relative "../support/rules_helpers"

# Spec 023 Story 7: five units, a full set of orders, 360 pixels wide, within 18 taps and 45 seconds (D7).
RSpec.describe "Entering orders with the pickers", type: :system do
  include RulesHelpers

  MAX_TAPS = 18
  MAX_SECONDS = 45

  def tap_on(text)
    @taps += 1
    click_on text
  end

  def screenshot(name)
    dir = ENV["SCREENSHOTS"]
    page.save_screenshot(File.join(dir, "#{name}.png")) if dir
  end

  def measure_step(label)
    widths = evaluate_script("({ scroll: document.documentElement.scrollWidth, client: document.documentElement.clientWidth })")
    expect(widths["scroll"]).to be <= widths["client"], "#{label} scrolls sideways"
    small = evaluate_script(<<~JS)
      Array.from(document.querySelectorAll(":is(main, .app-actions) :is(a:not(p a), button, input:not([type=hidden]))")).filter((el) => {
        const r = el.getBoundingClientRect(); return r.width < 43.5 || r.height < 43.5;
      }).map((el) => el.className || el.tagName)
    JS
    expect(small).to be_empty, "#{label}: controls under 44 by 44: #{small.join(', ')}"
  end

  it "enters orders for five units and submits in at most 18 taps and 45 seconds (AC-7.1, AC-7.2)" do
    started = Game.start!(power: "england")
    game = started.game
    game.current_phase.update_columns(position: rules_position(units: [
      [ :england, :army, :lvp ], [ :england, :fleet, :edi ], [ :england, :fleet, :lon ], [ :england, :army, :yor ], [ :england, :fleet, :mao ]
    ]).then { |position| RulesObjectType.position.serialize(position) })
    id = game.public_id
    @taps = 0

    with_viewport(360) do
      visit "/games/#{id}/seat-link?token=#{started.seat_token}"
      started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      visit "/games/#{id}/phases/1/orders"
      expect(page).to have_css(".unit-row", count: 5)
      measure_step("the list")

      tap_on "Fleet in Edinburgh"; tap_on "Move"; tap_on "Norwegian Sea"                        # 3
      tap_on "Fleet in London"; tap_on "Move"; tap_on "English Channel"                          # 3
      tap_on "Army in Yorkshire"; tap_on "Hold"                                                  # 2
      tap_on "Army in Liverpool"; tap_on "Support"; tap_on "Fleet in Edinburgh"; tap_on "Move to Clyde" # 4
      tap_on "Fleet in Mid-Atlantic Ocean"; tap_on "Move"; tap_on "Spain"; tap_on "North coast"  # 4
      expect(page).to have_css(".submit-bar", text: "5 of 5 ordered")
      tap_on "Submit orders"                                                                     # 1

      expect(page).to have_css(".banner--info", text: "Submitted.")
      elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at
      expect(@taps).to be <= MAX_TAPS
      expect(elapsed).to be <= MAX_SECONDS
      expect(game.seats.find_by(power: "england").orders_for(game.current_phase).size).to eq(5)
      expect(game.seats.find_by(power: "england").submitted?(game.current_phase)).to be(true)
    end
  end

  # + the coast step and the by-land-or-convoy step (AC-7.3), "Saving…" while a form carries aria-busy (AC-3.6), the measure_step
  #   checks on every step page, and a screenshot of each step when SCREENSHOTS is set (AC-7.4).
end
```

(The exact link texts are tuned to the pages' real text as the spec is run; the assertions on taps, time and stored orders do not change.)

**Verify:** `bundle exec rspec spec/system` (twice, to see the time is stable); `SCREENSHOTS=<dir> bundle exec rspec spec/system/order_pickers_spec.rb` produces the 360-pixel PNGs, copied to `web/docs/specs/023-order-pickers/screens/` for the pull request. **Commit:** "Walk a five-unit set of orders at phone width".

## Phase 9: Amend the specs, prove, and open the pull request

**Implements:** AC-8.1. **Files:** change `web/docs/specs/022-phase-lifecycle/spec.md` and `web/docs/specs/023-order-pickers/spec.md`; add `web/docs/specs/023-order-pickers/screens/*.png`.

- Spec 022 changelog row 1.3.0 as AC-8.1 words it. Its Version line becomes 1.3.0.
- Spec 023 changelog row 1.0.3: the draft has three keys (D2); the sweep's deep pages are `lvp` and `par` (AC-5.2); the single-branch supports are covered with stubbed legal orders (AC-2.10); the walk's final count and timings if they changed.
- Run, from `web/`: `bundle exec rspec` (all, system specs included), `bin/brakeman`, `bin/rubocop`, `git diff --name-only main...HEAD` (only `web/` paths), `wc -c app/assets/stylesheets/*.css`.
- Implementation review by a read-only Opus subagent; its findings and how each was handled go in the pull request description.
- Push, open the draft pull request from the template ("Closes #23", screenshots at 360 pixels of each step, the draft-in-the-query limit stated, the 22 amendment noted), wait for the `Web specs` job to go green, then `gh pr ready` and assign.

**Commit:** "Amend spec 022 for the pickers and record the plan's changes".

## Coverage check (every spec item has a phase)

| Spec | Phase |
|---|---|
| FR-1, AC-1.x | 3 (AC-1.9 words: 2) |
| FR-2, AC-2.x | 4 (model), 5 (pages) |
| FR-3 | 1, 2 |
| FR-4, AC-3.x | 3, 5, 8 |
| FR-5, AC-4.x | 3 |
| FR-6, AC-6.x | 3, 5 (CSS), 7 |
| FR-7 | 5 |
| FR-8, AC-5.x | 5 (headers, filter), 6 |
| AC-7.x | 8 |
| AC-8.x | 3 (specs), 9 (amendments) |

## Changelog

| Version | Date | Change |
|---|---|---|
| 1.0.0 | 2026-11-26 | First draft |

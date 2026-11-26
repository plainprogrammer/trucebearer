# Plan 023: Enter movement orders with pickers

**Spec:** `web/docs/specs/023-order-pickers/spec.md` v1.0.3 (Approved at Gate A; 1.0.3 is the three-key draft refinement the plan found)
**Issue:** #23 · **Branch:** `web/23-order-pickers` · **Plan version:** 1.2.0 (after two Opus reviews; see the changelog at the end)

## Goal

Replace spec 022's plain orders form with the order screen (a unit list and a submit bar) and the picker steps, as the spec says. Every choice comes from `RulesEngine.legal_orders`; every pick is one `PUT` to the existing endpoint (`Seat#save_orders!`). All work is under `web/`. Each phase is test first (RSpec), ends with its own specs green (the whole suite, not only the new examples), and is one commit. Commit messages are plain imperative sentences ending with the `Co-Authored-By:` line. Every gem call stays in `app/models/rules_engine.rb`.

**The first test.** Before Phase 1, the brief's request spec (`spec/requests/order_screen_spec.rb`, 5a) is written and run once to see it fail. It is kept in the scratchpad, outside `spec/`, until Phase 5 copies it in and makes it pass, so the whole suite is green in every commit and the first test is still the first one written.

## Decisions the plan adds (each traceable to the spec)

- **The draft has three keys:** `draft[kind]`, `draft[target]`, `draft[to]` (spec 1.0.3). The coast step and the by-land-or-convoy step are reached from `kind=move&to=<province>`; their choices are the final saves.
- **Order of phases.** Words, then the choices model, then the picker pages (the route, its classification, the sweep, the log filter and the scan in one commit, so no commit has an unclassified route), then the order screen that replaces the plain form, then the style guide, the system specs, and the amendments. The plain form keeps working until Phase 5.
- **The sweep's deep pages:** `/orders/lon?draft[kind]=support&draft[target]=edi` (England's London fleet can support the Edinburgh fleet to NTH or YOR) and `/orders/par?draft[kind]=support&draft[target]=bre` for France.
- **Both single-branch supports exist in real positions,** so no stub is needed: a fleet in ION with an army in TUN gives a support to hold only (the fleet cannot reach NAF, the army's only land move), and Austria's VIE with Russia's WAR gives a support to move only (WAR is not adjacent). Both are crawler positions (AC-2.10).
- **Names.** `OrderChoices` (model, plain Ruby); `OrderPickersController#show`; concern `OrderScreen` (the phase lookup, the revealed page and the no-store and no-referrer headers that `SeatOrdersController` and `OrderPickersController` share); helper methods `province_label` and `order_words` (`order_label` is removed in Phase 5); partials `seat_orders/_unit_row`, `seat_orders/_submit_bar`, `shared/_save_status`, `order_pickers/_choice`, `order_pickers/_draft`.
- **A choice** is `OrderChoices::Choice = Data.define(:words, :province, :note, :draft, :save)`: `draft` is the query for a link, `save` the text a form posts (an order's JSON, or `""` for "No order"); exactly one is set. A step is `Step = Data.define(:title, :trail, :choices, :back)`; `back` is `nil` for step 1 (it goes back to the order screen), otherwise the draft of the step before (`{}` is step 1).
- **The list stops calling the gem for choices.** The order screen reads the position's units, the seat's own stored orders and province names; `legal_orders` is called only by the picker.
- **No new JavaScript, no frames, no new gem or pin.** Test constants live in `let`s or local methods, not top-level constants.

## Gates checked

- **Simplicity:** one model, one controller, one concern, five partials, helper changes, one route.
- **Anti-abstraction:** no service objects or presenters; `OrderChoices` has one public entry point (`step`).
- **Integration-first:** the first test is a request spec against the real routes and database; the picker is proved by a crawler over real pages (Phase 4).

## Phase 1: `RulesEngine` knows province names and army adjacency

**Implements:** FR-3 (the two methods). **Files:** change `app/models/rules_engine.rb`, `spec/models/rules_engine_spec.rb`.

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
# app/models/rules_engine.rb (inside class << self, after province?)
# The full name of a province ("Liverpool"), for labels (spec 023 FR-3).
def province_name(id) = TA::Map.classic.province(id.to_sym).name

# Whether an army could walk between two provinces; it says a plain move of an army "needs a convoy" (spec 023 D3).
def army_adjacent?(from, to)
  TA::Map.classic.adjacent?(:army, TA::Location.new(province: from.to_sym), TA::Location.new(province: to.to_sym))
end
```

**Verify:** `bundle exec rspec spec/models` (the boundary spec included). **Commit:** "Let RulesEngine name provinces and test army adjacency".

## Phase 2: Words for provinces and orders

**Implements:** FR-3. **Satisfies:** the words of AC-1.2, AC-1.3, AC-1.9. **Files:** change `app/helpers/order_label_helper.rb`, `spec/helpers/order_label_helper_spec.rb`.

`order_label` stays in this phase (the plain form's view still uses it); Phase 5 removes it with the form. New examples are added beside the old ones:

```ruby
# spec/helpers/order_label_helper_spec.rb (added)
describe "province_label and order_words" do
  include RulesHelpers
  let(:position) do
    rules_position(units: [ [ :england, :army, :lon ], [ :england, :fleet, :nth ], [ :france, :fleet, :mao ], [ :france, :army, :bre ] ])
  end

  def unit_at(province) = position.units.find { |u| u.location.province.to_s == province }

  def words(order, province) = Nokogiri::HTML5.fragment(helper.order_words(order, unit_at(province))).text

  it "writes a province as its full name with the abbreviation in the mono face" do
    html = helper.province_label("lvp")
    expect(html).to eq('Liverpool (<span class="mono">LVP</span>)')
    expect(html).to be_html_safe
  end

  it "reads orders in words, full names first" do
    expect(words(rules_order(:hold, :england, :lon), "lon")).to eq("Hold")
    expect(words(move(:england, :nth, :nwg), "nth")).to eq("Move to Norwegian Sea (NWG)")
    expect(words(move(:france, :mao, :spa, :nc), "mao")).to eq("Move to Spain (SPA), north coast")
    expect(words(rules_order(:move_via_convoy, :england, :lon, to: "yor"), "lon")).to eq("Move to Yorkshire (YOR) by convoy")
    expect(words(rules_order(:support_hold, :france, :bre, target: "mao"), "bre")).to eq("Support hold in Mid-Atlantic Ocean (MAO)")
    expect(words(rules_order(:support_move, :england, :lon, from: "nth", to: "yor"), "lon")).to eq("Support North Sea (NTH) to Yorkshire (YOR)")
    expect(words(rules_order(:convoy, :england, :nth, from: "lon", to: "nwy"), "nth")).to eq("Convoy London (LON) to Norway (NWY)")
  end

  it "marks only an army's plain move to a province it cannot walk to (AC-1.9)" do
    expect(words(move(:england, :lon, :nwy), "lon")).to eq("Move to Norway (NWY), needs a convoy")
    expect(words(move(:england, :lon, :yor), "lon")).to eq("Move to Yorkshire (YOR)")
    expect(words(move(:england, :nth, :nwy), "nth")).to eq("Move to Norway (NWY)") # a fleet
  end
end
```

Then, added to the helper (the old `order_label` stays):

```ruby
# app/helpers/order_label_helper.rb (added)
# "Liverpool (LVP)", the abbreviation in the mono face (spec 023 FR-3).
def province_label(id)
  id = id.to_s
  safe_join([ RulesEngine.province_name(id), " (", tag.span(id.upcase, class: "mono"), ")" ])
end

# An order in words with full names. It reads the hash form and the unit it is for, so it names no gem class.
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
```

**Verify:** `bundle exec rspec spec/helpers`. **Commit:** "Write orders and provinces in words with full names".

## Phase 3: `OrderChoices`, and the crawler that proves it

**Implements:** FR-2, D1, D3. **Satisfies:** AC-2.1, AC-2.4 to AC-2.11 (model level), AC-2.14 (trail, back). **Files:** create `app/models/order_choices.rb`, `spec/models/order_choices_spec.rb`.

Test first. Each named example below is one red-green step, written out before its code:

```ruby
# spec/models/order_choices_spec.rb
require "rails_helper"
require_relative "../support/rules_helpers"

RSpec.describe OrderChoices do
  include RulesHelpers

  def positions
    {
      "the starting position" => RulesEngine.starting_position,
      "fleets at sea, armies on the coast, a split coast" => rules_position(units: [
        [ :france, :fleet, :mao ], [ :france, :fleet, :gol ], [ :france, :army, :gas ], [ :france, :army, :mar ], [ :england, :fleet, :eng ] ]),
      "an army with a land route and a convoy chain" => rules_position(units: [
        [ :england, :army, :lon ], [ :england, :fleet, :nth ], [ :germany, :fleet, :hel ] ]),
      "a support to move only (VIE for WAR is not adjacent)" => rules_position(units: [
        [ :austria, :army, :vie ], [ :russia, :army, :war ], [ :austria, :army, :bud ] ]),
      "a support to hold only (a fleet in ION, an army in TUN)" => rules_position(units: [ [ :italy, :fleet, :ion ], [ :italy, :army, :tun ] ])
    }
  end

  # Every save a chain of picks can reach, found by following each step's own choices.
  def saves_reachable(choices, draft = {})
    step = choices.step(draft)
    raise "no step for #{draft.inspect}" unless step

    step.choices.flat_map { |choice| choice.save ? [ choice.save ] : saves_reachable(choices, choice.draft) }
  end

  it "reaches exactly the legal orders of every unit, none missing, none extra, none twice (AC-2.10)" do
    positions.each do |name, position|
      position.units.each do |unit|
        choices = OrderChoices.new(position, unit, ordered: true)
        legal = RulesEngine.legal_orders(position, unit).map { |order| JSON.generate(order.to_h) }

        expect(saves_reachable(choices).reject(&:empty?)).to match_array(legal), "#{name}: #{unit.type} in #{unit.location.province}"
      end
    end
  end

  it "offers Hold always, a kind only when the unit has such a legal order, and No order only when ordered (AC-2.1)" do
    start = RulesEngine.starting_position
    army = start.units.find { |u| u.location.province == :lvp }
    words = ->(ordered) { OrderChoices.new(start, army, ordered: ordered).step({}).choices.map(&:words) }

    expect(words.(false)).to eq([ "Hold", "Move", "Support" ])
    expect(words.(true)).to eq([ "Hold", "Move", "Support", "No order (holds)" ])
    expect(OrderChoices.new(start, army, ordered: true).step({}).choices.last.save).to eq("")
  end

  def unit_in(position, province) = position.units.find { |u| u.location.province == province.to_sym }

  def choices_for(position, province, ordered: false) = OrderChoices.new(position, unit_in(position, province), ordered: ordered)

  def legal_hashes(position, province) = RulesEngine.legal_orders(position, unit_in(position, province)).map(&:to_h)

  let(:start) { RulesEngine.starting_position }
  let(:sea) { rules_position(units: [ [ :france, :fleet, :mao ], [ :france, :fleet, :gol ] ]) }
  let(:ln) { rules_position(units: [ [ :england, :army, :lon ], [ :england, :fleet, :nth ] ]) }

  it "lists each destination once, in the gem's order, and saves a destination that has one order (AC-2.4)" do
    step = choices_for(start, :lon).step("kind" => "move")
    expected = legal_hashes(start, :lon).select { |h| h["type"] == "move" }.map { |h| h["destination"]["province"] }.uniq

    expect(step.title).to eq("Move where?")
    expect(step.choices.map(&:province)).to eq(expected)
    expect(step.choices).to all(satisfy { |choice| choice.save && choice.draft.nil? })
  end

  it "links a split-coast destination to its coast step, which lists the coasts the gem offered (AC-2.5)" do
    spain = choices_for(sea, :mao).step("kind" => "move").choices.find { |c| c.province == "spa" }
    expect(spain.draft).to eq("kind" => "move", "to" => "spa")
    expect(spain.save).to be_nil

    coast = choices_for(sea, :mao).step(spain.draft)
    expect(coast.title).to eq("Which coast?")
    expect(coast.choices.map(&:words)).to eq([ "North coast (NC)", "South coast (SC)" ])
    expect(coast.choices.map { |c| JSON.parse(c.save)["destination"]["coast"] }).to eq(%w[nc sc])
  end

  it "notes the coast on a destination with one reachable coast, and saves from the row (spec D3)" do
    spain = choices_for(sea, :gol).step("kind" => "move").choices.find { |c| c.province == "spa" }

    expect(spain.note).to eq("south coast")
    expect(JSON.parse(spain.save)["destination"]["coast"]).to eq("sc")
    expect(spain.draft).to be_nil
  end

  it "links a destination with a plain and a convoy move to 'By land' and 'By convoy' (AC-2.6)" do
    yorkshire = choices_for(ln, :lon).step("kind" => "move").choices.find { |c| c.province == "yor" }
    expect(yorkshire.draft).to eq("kind" => "move", "to" => "yor")

    how = choices_for(ln, :lon).step(yorkshire.draft)
    expect(how.title).to eq("How does it get there?")
    expect(how.choices.map(&:words)).to eq([ "By land", "By convoy" ])
    expect(how.choices.map { |c| JSON.parse(c.save)["type"] }).to eq(%w[move move_via_convoy])
  end

  it "marks an army's convoy-only destination 'needs a convoy' and saves the plain move (AC-2.7)" do
    norway = choices_for(ln, :lon).step("kind" => "move").choices.find { |c| c.province == "nwy" }

    expect(norway.note).to eq("needs a convoy")
    expect(JSON.parse(norway.save)).to include("type" => "move", "at" => "lon")
  end

  it "lists the supported units once, then 'Hold in place' first, then each destination (AC-2.8)" do
    list = choices_for(start, :lvp).step("kind" => "support")
    edinburgh = list.choices.find { |c| c.province == "edi" }
    expect(list.choices.map(&:province)).to eq(list.choices.map(&:province).uniq)
    expect([ edinburgh.words, edinburgh.note ]).to eq([ "Fleet in", "England" ])

    how = choices_for(start, :lvp).step(edinburgh.draft)
    moves = legal_hashes(start, :lvp).select { |h| h["type"] == "support_move" && h["from"] == "edi" }.map { |h| h["to"] }
    expect(how.title).to eq("Support it how?")
    expect(how.choices.map(&:words)).to eq([ "Hold in place" ] + [ "Move to" ] * moves.size)
    expect(how.choices.drop(1).map(&:province)).to eq(moves)
  end

  it "lists the convoyable armies once, then their destinations (AC-2.9)" do
    armies = choices_for(ln, :nth).step("kind" => "convoy")
    london = armies.choices.first
    expect(armies.choices.map(&:province)).to eq([ "lon" ])
    expect([ london.words, london.note ]).to eq([ "Army in", "England" ])

    where = choices_for(ln, :nth).step(london.draft)
    expected = legal_hashes(ln, :nth).select { |h| h["type"] == "convoy" && h["from"] == "lon" }.map { |h| h["to"] }
    expect(where.title).to eq("Convoy it where?")
    expect(where.choices.map(&:province)).to eq(expected)
  end

  it "gives nil for a draft that names no legal choice: unknown kind or key, a kind with no orders, a bad target or destination, a complete draft, a non-String (AC-2.11)" do
    choices = choices_for(start, :lvp)
    [ { "kind" => "teleport" }, { "kind" => "move", "to" => "xyz" }, { "kind" => "support", "target" => "zzz" },
      { "kind" => "convoy" }, { "bad" => "1" }, { "kind" => 1 }, { "to" => "cly" }, { "kind" => "move", "to" => "cly" } ].each do |draft|
      expect(choices.step(draft)).to be_nil, draft.inspect
    end
  end

  it "gives the trail and the back draft of each step: nil for step 1, {} for a kind alone, the kind's draft for the second step (AC-2.14)" do
    choices = choices_for(start, :lvp)
    expect(choices.step({}).back).to be_nil
    expect(choices.step("kind" => "move").back).to eq({})
    expect(choices.step("kind" => "move").trail.map(&:words)).to eq([ "Move" ])
    how = choices.step("kind" => "support", "target" => "edi")
    expect(how.back).to eq("kind" => "support")
    expect(how.trail.map { |t| [ t.words, t.province ] }).to eq([ [ "Support", nil ], [ "Fleet in", "edi" ] ])
  end
end
```

Each example is run red before the code for it is written. (The `positions` method also lists VIE/WAR and ION/TUN, which the crawler covers.)

The model:

```ruby
# app/models/order_choices.rb
# What one unit can be told to do, as the picker's steps (spec 023 D1, D3, FR-2). Every choice is made from RulesEngine.legal_orders;
# the model reads each order's hash form and names no gem class. step(draft) says which page the draft leads to, or nil when it names
# no legal choice (the caller sends the player back to step 1).
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

  # draft: a Hash of Strings. Returns a Step, or nil.
  def step(draft)
    return action_step if draft.empty?
    return nil unless draft.keys.all? { |key| DRAFT_KEYS.include?(key) } && draft.values.all?(String)

    case draft["kind"]
    when "move" then move_step(draft)
    when "support" then support_step(draft)
    when "convoy" then convoy_step(draft)
    end
  end

  private

  def of_type(*types) = @orders.select { |_, h| types.include?(h["type"]) }

  def save_of(order) = JSON.generate(order.to_h)

  # A step with nothing to choose is no step (a kind the unit has no orders for).
  def build(title, trail, choices, back) = (Step.new(title, trail, choices, back) if choices.any?)

  def action_step
    hold = @orders.find { |_, h| h["type"] == "hold" }.first
    choices = [ Choice.new("Hold", nil, nil, nil, save_of(hold)) ]
    { "move" => %w[move move_via_convoy], "support" => %w[support_hold support_move], "convoy" => %w[convoy] }.each do |kind, types|
      choices << Choice.new(kind.capitalize, nil, nil, { "kind" => kind }, nil) if of_type(*types).any?
    end
    choices << Choice.new("No order (holds)", nil, nil, nil, "") if @ordered
    Step.new("What should it do?", [], choices, nil)
  end

  # ---- Move: moves grouped by destination province, in the order the gem lists them (D3)
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
        order, h = entries.first
        Choice.new(nil, province, move_note(province, h), nil, save_of(order))
      else
        Choice.new(nil, province, nil, { "kind" => "move", "to" => province }, nil)
      end
    end
    build("Move where?", [ Trail.new("Move", nil) ], choices, {})
  end

  # "needs a convoy" for an army's plain move to a province it cannot walk to; the coast for a fleet's single-coast move.
  def move_note(province, hash)
    return COAST_WORDS.fetch(hash["destination"]["coast"]).downcase if hash["type"] == "move" && hash["destination"]["coast"]

    "needs a convoy" if @unit.type == :army && hash["type"] == "move" && !RulesEngine.army_adjacent?(@province, province)
  end

  def which_way_step(province)
    entries = destinations[province]
    return nil unless entries && entries.size > 1

    choices = entries.map do |order, h|
      words = if h["type"] == "move_via_convoy" then "By convoy"
      elsif h["destination"]["coast"] then "#{COAST_WORDS.fetch(h["destination"]["coast"])} (#{h["destination"]["coast"].upcase})"
      else "By land"
      end
      Choice.new(words, nil, nil, nil, save_of(order))
    end
    title = entries.any? { |_, h| h["type"] == "move_via_convoy" } ? "How does it get there?" : "Which coast?"
    build(title, [ Trail.new("Move to", province) ], choices, { "kind" => "move" })
  end

  # ---- Support: the supported unit, then "Hold in place" or a destination
  def supports = of_type("support_hold", "support_move")

  def supported_provinces = supports.map { |_, h| h["type"] == "support_hold" ? h["target"] : h["from"] }.uniq

  def support_step(draft)
    case draft.keys.sort
    when %w[kind] then build("Support which unit?", [ Trail.new("Support", nil) ], unit_choices("support", supported_provinces), {})
    when %w[kind target] then support_how_step(draft["target"])
    end
  end

  def support_how_step(target)
    return nil unless supported_provinces.include?(target)

    choices = supports.filter_map do |order, h|
      if h["type"] == "support_hold" && h["target"] == target then Choice.new("Hold in place", nil, nil, nil, save_of(order))
      elsif h["type"] == "support_move" && h["from"] == target then Choice.new("Move to", h["to"], nil, nil, save_of(order))
      end
    end
    build("Support it how?", [ Trail.new("Support", nil), unit_trail(target) ], choices, { "kind" => "support" })
  end

  # ---- Convoy: the army, then its destination
  def convoys = of_type("convoy")

  def convoyed_provinces = convoys.map { |_, h| h["from"] }.uniq

  def convoy_step(draft)
    case draft.keys.sort
    when %w[kind] then build("Convoy which army?", [ Trail.new("Convoy", nil) ], unit_choices("convoy", convoyed_provinces), {})
    when %w[kind target] then convoy_where_step(draft["target"])
    end
  end

  def convoy_where_step(target)
    return nil unless convoyed_provinces.include?(target)

    choices = convoys.filter_map { |order, h| Choice.new("To", h["to"], nil, nil, save_of(order)) if h["from"] == target }
    build("Convoy it where?", [ Trail.new("Convoy", nil), unit_trail(target) ], choices, { "kind" => "convoy" })
  end

  # ---- Units standing on the board: public, from the position
  def unit_at(province) = @position.units.find { |u| u.location.province.to_s == province }

  def unit_choices(kind, provinces)
    provinces.map do |province|
      unit = unit_at(province)
      Choice.new("#{unit.type.to_s.capitalize} in", province, power_name(unit.power), { "kind" => kind, "target" => province }, nil)
    end
  end

  def unit_trail(province) = Trail.new("#{unit_at(province).type.to_s.capitalize} in", province)

  def power_name(id) = RulesEngine.powers.find { |power| power.id.to_s == id.to_s }.name
end
```

**Verify:** `bundle exec rspec spec/models` (the boundary spec too: the model names no gem class). **Commit:** "Group a unit's legal orders into the picker's steps".

## Phase 4: The picker pages, with the route, its secrecy classification, the sweep and the log filter

**Implements:** FR-2 (the page), FR-7, FR-8, D2, D5. **Satisfies:** AC-2.1 to AC-2.15, AC-3.1, AC-3.3, AC-3.5, AC-3.7, AC-5.1 to AC-5.6, AC-6.2.
**Files:**
- Create `app/controllers/order_pickers_controller.rb`, `app/controllers/concerns/order_screen.rb`, `app/views/order_pickers/{show,_choice,_draft}.html.erb`, `spec/requests/order_pickers_spec.rb`, `spec/models/seat_write_scan_spec.rb`.
- Change `config/routes.rb`, `config/initializers/filter_parameter_logging.rb`, `spec/config/filter_parameters_spec.rb`, `app/controllers/seat_orders_controller.rb` (uses the concern), `app/assets/stylesheets/components.css` (`.picker`, `.picker__draft`), `spec/support/secrecy_routes.rb`, `spec/requests/order_secrecy_spec.rb`, `spec/requests/reveal_post_spec.rb` (the phase-routes list gains the new route).

All of this is one commit because a route exists only with its classification (the route-table spec fails otherwise).

### 4a. Tests first

```ruby
# spec/requests/order_pickers_spec.rb
require "rails_helper"
require_relative "../support/rules_helpers"

RSpec.describe "The picker steps", type: :request do
  include RulesHelpers
  around { |example| with_passphrase { example.run } }

  let(:created) { create_game(power: "england") }
  let(:id) { created.game.public_id }
  let(:phone) { created.session }
  let(:base) { "/games/#{id}/phases/1/orders" }
  def page = Nokogiri::HTML5(phone.response.body)
  def choices = page.css(".picker .list li")

  it "offers Hold, Move and Support to the army in Liverpool, and no Convoy; the draft names the unit (AC-2.1, AC-2.14)" do
    phone.get "#{base}/lvp"
    expect(phone.response).to have_http_status(:ok)
    expect(choices.map { |li| li.text.squish }).to eq(%w[Hold Move Support])
    expect(page.at_css(".picker__draft").text.squish).to include("Army in Liverpool (LVP)")
    expect(page.at_css(".app-actions a").text).to eq("Back")
  end

  it "saves a hold with the form's own fields, one PUT, then lands on the screen (AC-2.2, AC-3.1)" do
    phone.get "#{base}/lvp"
    form = choices.first.at_css("form")
    expect(form["action"]).to eq(base)
    phone.put form["action"], params: { orders: { "lvp" => form.at_css("input[name='orders[lvp]']")["value"] } }
    expect(phone.response).to have_http_status(:see_other)
    expect(created.game.seats.find_by(power: "england").orders_for(created.game.current_phase).keys).to eq([ "lvp" ])
  end

  # AC-2.10 over real pages: follow the page's own links, read the forms' fields, compare to the gem's legal orders.
  def crawl(path, province, found = [])
    phone.get path
    expect(phone.response).to have_http_status(:ok), path
    choices.each do |li|
      if (form = li.at_css("form"))
        found << form.at_css("input[name='orders[#{province}]']")["value"]
      else
        crawl(li.at_css("a")["href"], province, found)
      end
    end
    found
  end

  it "reaches exactly the legal orders of England's three units through the page's own links and forms (AC-2.10, AC-3.5)" do
    position = created.game.current_phase.position
    position.units.select { |u| u.power == :england }.each do |unit|
      province = unit.location.province.to_s
      legal = RulesEngine.legal_orders(position, unit).map { |order| JSON.generate(order.to_h) }
      expect(crawl("#{base}/#{province}", province).reject(&:empty?)).to match_array(legal), province
    end
  end

  it "has no script, handler or data-action in any step, and no new import-map pin (AC-3.5)" do
    phone.get "#{base}/lvp?draft%5Bkind%5D=move"
    body = page.at_css("body")
    expect(body.css("script")).to be_empty
    expect(phone.response.body).not_to match(/\sonclick=|\sonsubmit=|data-action=/)
    expect(Rails.application.importmap.packages.keys).to match_array(%w[application @hotwired/turbo-rails @hotwired/stimulus @hotwired/stimulus-loading])
  end

  it "sends a draft that names no legal choice, or a whole order, back to step 1 and echoes nothing (AC-2.11)" do
    [ "draft%5Bkind%5D=teleport", "draft%5Bkind%5D=move&draft%5Bto%5D=xyz", "draft%5Bkind%5D=support&draft%5Btarget%5D=zzz",
      "draft%5Bkind%5D=convoy", "draft%5Bbad%5D=1", "draft=text", "draft%5B%5D=a", "draft%5Bkind%5D%5B%5D=move" ].each do |query|
      phone.get "#{base}/lvp?#{query}"
      expect(phone.response).to have_http_status(:see_other), query
      expect(phone.response.location).to end_with("#{base}/lvp")
      expect(phone.response.body).not_to include("xyz")
    end
  end

  it "gives the stranger response for a province that is not the seat's unit and for a phase that is not reachable (AC-2.12, AC-2.13)" do
    [ "par", "xyz", "LVP" ].each do |province|
      phone.get "#{base}/#{province}"
      expect(phone.response).to have_http_status(:not_found), province
    end
    phone.get "/games/#{id}/phases/2/orders/lvp"
    expect(phone.response).to have_http_status(:not_found)
    expect(SavedOrder.count).to eq(0)
  end

  it "gives the 409 page for a revealed phase (AC-2.13)" do
    created.session.post "/games/#{id}/host/phases/1/reveal"
    phone.get "#{base}/lvp"
    expect(phone.response).to have_http_status(:conflict)
  end

  it "carries no-store, the Turbo no-cache meta and no-referrer (AC-2.15, AC-3.7)" do
    phone.get "#{base}/lvp"
    expect(phone.response.headers["Cache-Control"]).to include("no-store")
    expect(phone.response.headers["Referrer-Policy"]).to eq("no-referrer")
    expect(page.at_css("meta[name='turbo-cache-control'][content='no-cache']")).to be_present
    expect(page.css("a[href]").map { |a| a["href"] }).to all(start_with("/")) # no link off the app
  end

  it "keeps a draft out of the logged request line, percent-encoded brackets included (AC-3.7)" do
    env = Rack::MockRequest.env_for("/x?draft%5Bto%5D=bel&draft%5Bkind%5D=move")
    request = ActionDispatch::Request.new(Rails.application.env_config.merge(env))
    expect(request.filtered_path).not_to include("bel")
    expect(request.filtered_path).not_to include("move")
  end

  it "has no other write to saved orders than the orders endpoint and the reissue (AC-3.1)" do
    callers = Dir.glob(Rails.root.join("app/**/*.rb")).select { |f| File.read(f).include?("save_orders!") }.map { |f| File.basename(f) }
    expect(callers).to match_array(%w[seat.rb seat_orders_controller.rb])
  end
end
```

(That last example lives in `spec/models/seat_write_scan_spec.rb`, beside `saved_order_boundary_spec.rb`, since it scans `app/`; it is shown here with the rest of the picker's examples for reading.)

```ruby
# spec/requests/order_secrecy_spec.rb (changed examples)
it "marks as showing orders only the seat page, the orders page, the picker and the endpoint (AC-5.1)" do
  showing = SecrecyRoutes::APP.select { |_key, entry| entry[:shows] == :own }.keys
  expect(showing).to match_array([ "GET /games/:public_id", "GET /games/:public_id/phases/:number/orders",
                                   "GET /games/:public_id/phases/:number/orders/:province", "PUT /games/:public_id/phases/:number/orders" ])
end

# in the sweep describe, after the existing baseline checks (AC-5.2): real pages, so the sweep cannot pass by comparing 404s
it "sweeps real picker pages: France reaches its own deep step, England its own (AC-5.2)" do
  set_orders(:none)
  baseline = snapshot
  label = "GET /games/:public_id/phases/:number/orders/:province"
  expect(baseline.fetch("another seat").fetch("#{label} [par]").first).to eq(200)
  expect(baseline.fetch("another seat").fetch("#{label} [lon]").first).to eq(404) # London is England's, not France's
  england_phone.get "/games/#{id}/phases/1/orders/lon?draft%5Bkind%5D=support&draft%5Btarget%5D=edi"
  expect(england_phone.response).to have_http_status(:ok)
end

# AC-5.3: France's orders never appear on England's pages, England walking every step of every unit
it "shows England no order of France's on any picker page, nor a count of them (AC-5.3)" do
  france_seat = game.seats.find_by(power: "france")
  france_seat.save_orders!(phase, { "par" => json_of(move(:france, :par, :bur)), "mar" => json_of(rules_order(:hold, :france, :mar)) })
  england_phone.get "/games/#{id}/phases/1/orders/lon"
  pages = [ england_phone.response.body ]
  %w[lon edi lvp].each do |province|
    [ "", "?draft%5Bkind%5D=move", "?draft%5Bkind%5D=support", "?draft%5Bkind%5D=support&draft%5Btarget%5D=edi" ].each do |query|
      england_phone.get "/games/#{id}/phases/1/orders/#{province}#{query}"
      pages << england_phone.response.body if england_phone.response.status == 200
    end
  end
  france_json = france_seat.orders_for(phase).values.map { |o| ERB::Util.html_escape(json_of(o)) }
  pages.each do |body|
    france_json.each { |text| expect(body).not_to include(text) }
    expect(body).not_to include("2 of 3 ordered")
    expect(body).not_to include("Move to Burgundy (BUR)") # France's order in words
  end
end
```

The "never carries England's orders" example gains the new route's pages for every viewer (it already iterates `snapshot`); its `option[selected]` check stays harmless until Phase 5 rewrites it.

```ruby
# spec/support/secrecy_routes.rb (changed)
"GET /games/:public_id/phases/:number/orders/:province" => {
  shows: :own,
  sweep: ->(c) { { "lon" => "/games/#{c.id}/phases/1/orders/lon?draft%5Bkind%5D=support&draft%5Btarget%5D=edi",
                   "par" => "/games/#{c.id}/phases/1/orders/par?draft%5Bkind%5D=support&draft%5Btarget%5D=bre" } },
  why: "the seat's own picker steps; a province that is not the viewer's unit is the stranger page"
},

# A route's `sweep` is a path, or a Hash of { label => path } when one route needs several pages swept.
# Every page the sweep requests, as { label => { path:, entry: } }.
def self.sweeps(context)
  readable.flat_map do |key, entry|
    result = entry[:sweep].call(context)
    if result.is_a?(Hash) then result.map { |name, path| [ "#{key} [#{name}]", { path: path, entry: entry } ] }
    else [ [ key, { path: result, entry: entry } ] ]
    end
  end.to_h
end
```

In `order_secrecy_spec.rb`, `snapshot` loops `SecrecyRoutes.sweeps(context)` (`requester.get item[:path]`, `requester = item[:entry][:fresh] ? open_session : session`), and the size check compares with `SecrecyRoutes.sweeps(context).size`.

`spec/requests/reveal_post_spec.rb` ("no undo") gains `[ "GET", "/games/:public_id/phases/:number/orders/:province" ]` in its list.

`spec/config/filter_parameters_spec.rb` gains: `ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters).filter("draft" => { "to" => "bel" })` is `{ "draft" => "[FILTERED]" }` and an unrelated `public_id` parameter is untouched.

### 4b. The code

```ruby
# app/controllers/concerns/order_screen.rb
# What the orders endpoint, the order screen and the picker share (spec 023 FR-1, FR-2).
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

`SeatOrdersController` includes `OrderScreen`, uses `before_action :own_orders_headers` in place of its `no_store` block, and drops its own `find_phase_or_stranger` and `render_revealed` (Phase 5 changes the rest of that controller).

```ruby
# config/routes.rb (added after the orders routes, inside the games scope)
get "phases/:number/orders/:province", to: "order_pickers#show", as: :game_order_picker,
    constraints: { number: %r{[^/]+}, province: %r{[^/]+} }
```

`:draft` is added to `config/initializers/filter_parameter_logging.rb`.

```ruby
# app/controllers/order_pickers_controller.rb
# One picker step for one of the seat's units (spec 023 D1, D2, FR-2). A GET never writes: the last pick is a form that PUTs to the
# orders endpoint.
# The headers run before the unit check, so the stranger page of a wrong province carries them too; it shows every seat the same
# thing, so nothing leaks.
class OrderPickersController < ApplicationController
  include OrderScreen
  before_action :require_seat
  before_action :find_phase_or_stranger
  before_action :own_orders_headers

  def show
    return render_revealed unless @phase.open?

    @province = params[:province].to_s
    @unit = @phase.position.units.find { |u| u.power.to_s == @seat.power && u.location.province.to_s == @province }
    return stranger!(@game) unless @unit

    draft = draft_param
    @step = draft && OrderChoices.new(@phase.position, @unit, ordered: @seat.orders_for(@phase).key?(@province)).step(draft)
    redirect_to game_order_picker_path(@game.public_id, @phase.number, @province), status: :see_other unless @step
  end

  private

  # {} when absent, the String-keyed hash when it is one, nil when it is anything else (a string, an array).
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
            <%= button_tag type: "submit", name: nil, class: "list__row" do %><%= render "order_pickers/choice", choice: choice %><% end %>
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

`shared/_save_status` is created here (it is also used by Phase 5):

```erb
<%# app/views/shared/_save_status.html.erb  locals: state (:saved, :saves_on_pick or :not_saved), saving (optional, the style guide's static sample).
    Two spans, so CSS can show "Saving…" while Turbo submits a form and the text is always real text (spec 023 D6). %>
<% rest = { saved: "Saved", saves_on_pick: "Saves when you pick", not_saved: "Not saved" }.fetch(state) %>
<p class="save-status<%= " save-status--saving" if local_assigns[:saving] %>" role="status"><span class="save-status__rest"><%= rest %></span><span class="save-status__saving">Saving…</span></p>
```

```erb
<%# app/views/order_pickers/_choice.html.erb  locals: choice %>
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
/* components.css (added; tokens only; inside the existing layer) */
.picker { gap: var(--space-4); }
.picker__draft { padding: var(--space-3) var(--space-4); background: var(--color-ice-pale); border-radius: var(--radius); }
.picker__draft p { margin: 0; }
.picker__choice { flex: 1; overflow-wrap: anywhere; }
.picker__note { color: var(--color-text-muted); }
.save-status { flex: 1 1 100%; margin: 0; color: var(--color-text-muted); }
.save-status__saving { display: none; }
.app:has(form[aria-busy="true"]) .save-status__rest, .save-status--saving .save-status__rest { display: none; }
.app:has(form[aria-busy="true"]) .save-status__saving, .save-status--saving .save-status__saving { display: inline; }
```

(`.save-status` rules are first needed here, by the picker pages; `.submit-bar` and `.unit-row` come with Phase 5. The `--saving` modifier is the style guide's static "Saving…" sample, so a busy dummy form never flips the real statuses.)

**Verify:** `bundle exec rspec` (the whole suite: the plain form still works, and every route is classified), `wc -c app/assets/stylesheets/*.css`. **Commit:** "Add the picker steps for entering orders".

## Phase 5: The order screen replaces the plain form

**Implements:** FR-1, FR-4, FR-5, FR-6 (list parts), D4, D6, D9. **Satisfies:** AC-1.1 to AC-1.9, AC-3.2, AC-3.4, AC-4.1 to AC-4.6, AC-8.2.
**Files:**
- Create `spec/requests/order_screen_spec.rb` (the first test, 5a, copied in from the scratchpad), `app/views/seat_orders/_unit_row.html.erb`, `app/views/seat_orders/_submit_bar.html.erb`.
- Change `app/controllers/seat_orders_controller.rb`, `app/views/seat_orders/show.html.erb`, `app/helpers/order_label_helper.rb` (remove `order_label`), `spec/helpers/order_label_helper_spec.rb` (remove its `order_label` examples), `app/assets/stylesheets/components.css`.
- Rewrite these existing specs, which assert what D4 removes (each rewrite is named; none is deleted without an equivalent, AC-8.2):
  - `spec/requests/orders_spec.rb`: the whole "the page" describe (the select and option examples, the `Fleet in EDI` label check, the line-65 "1 of 3 units ordered" check and the two-button D5 example at lines 68-75) becomes examples on `.unit-row`s and the submit bar, each with an equivalent; lines 90-91 ("Orders saved." banner and "3 of 3 units ordered") become "no banner, `.save-status` reads Saved, the bar says 3 of 3 ordered"; line 123 (the flash holds only kind and text) moves to a submit (`submit: "1"`, banner "Submitted."); line 134 (`select` count after a 422) becomes `.unit-row` count and `.save-status` reading "Not saved".
  - `spec/requests/reissue_clears_orders_spec.rb` lines 51-53 and 62: `select/option[selected]` becomes "every `.unit-row` reads holds" and "the bar says Not submitted and 0 of 3 ordered".
  - `spec/system/phase_screens_spec.rb`: the select and its two buttons (`select "Move to NTH"`, "Save and submit", the sticky buttons list) become the submit bar's single button ("Submit orders"); an order for the walk is saved by a direct `save_orders!` call in setup, since the picker's own walk is Phase 7's.
  - `spec/requests/order_secrecy_spec.rb`: `option[selected]` checks become "no `.unit-row__order` that reads an order" and the label checks use the new words ("Move to North Sea (NTH)", "3 of 3 ordered"); the host's no-order checks (`select, option` empty) stay.

### 5a. The first test (written before Phase 1 and run red, kept in the scratchpad until this phase; committed here)

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
  let(:path) { "/games/#{id}/phases/1/orders" }

  def page = Nokogiri::HTML5(phone.response.body)

  # The unit icon's tag holds the power's initial as text, so rows are read from their body.
  def rows = page.css(".unit-row__body").map { |row| row.text.squish }

  it "lists England's three units with 'holds', and the submit bar says '0 of 3 ordered' (AC-1.1)" do
    phone.get path

    expect(phone.response).to have_http_status(:ok)
    expect(rows).to eq([ "Fleet in Edinburgh (EDI) holds", "Fleet in London (LON) holds", "Army in Liverpool (LVP) holds" ])
    expect(page.at_css(".app-actions .submit-bar").text.squish).to include("0 of 3 ordered")
    expect(page.at_css(".save-status__rest").text).to eq("Saved")
  end

  it "reads a stored order in words, counts a hold, and links each row to its step 1 (AC-1.2, AC-1.3, AC-1.4)" do
    england.save_orders!(phase, { "lon" => json_of(move(:england, :lon, :nth)), "lvp" => json_of(rules_order(:hold, :england, :lvp)) })
    phone.get path

    expect(rows).to eq([ "Fleet in Edinburgh (EDI) holds", "Fleet in London (LON) Move to North Sea (NTH)", "Army in Liverpool (LVP) Hold" ])
    expect(page.at_css(".app-actions .submit-bar").text.squish).to include("2 of 3 ordered")
    expect(page.css("a.unit-row").map { |a| a["href"] }).to eq(%w[edi lon lvp].map { |p| "#{path}/#{p}" })
    expect(page.css("select, option")).to be_empty # AC-1.6
    expect(page.text).not_to include("units ordered")
  end

  it "says Not submitted with the Submit button, then Submitted without it, and a changed order brings the button back (AC-4.1 to AC-4.4)" do
    phone.get path
    expect(page.at_css(".submit-bar__state").text).to eq("Not submitted")
    phone.put path, params: { submit: "1" } # 0 orders may submit
    phone.follow_redirect!
    expect(page.css(".banner--info").map(&:text)).to eq([ "Submitted." ])
    expect(page.at_css(".submit-bar__state").text).to eq("Submitted · 0 of 3 ordered")
    expect(page.at_css(".submit-bar button")).to be_nil
    expect(page.at_css(".submit-bar a").text).to eq("Back to your seat")

    phone.put path, params: { orders: { "lon" => json_of(move(:england, :lon, :nth)) } } # a change un-submits (spec 022 AC-3.2)
    phone.follow_redirect!
    expect(page.at_css(".submit-bar__state").text).to eq("Not submitted")
    expect(page.at_css(".submit-bar button").text.squish).to eq("Submit orders 1 of 3 ordered")
    expect(page.css(".banner")).to be_empty # no "Orders saved." banner (D4)
  end

  it "reads Not saved on the answer to a refused save, and stays on the screen (AC-1.8, AC-3.2, AC-4.5)" do
    phone.put path, params: { orders: { "lon" => json_of(move(:england, :lon, :bel)) } }

    expect(phone.response).to have_http_status(:unprocessable_content)
    expect(page.at_css(".save-status__rest").text).to eq("Not saved")
    expect(page.css(".banner--danger").size).to eq(1)
    expect(page.css(".unit-row").size).to eq(3)
  end

  it "reads plainly for a fleet's move and an army's walkable move, and marks a convoy-only one (AC-1.9)" do
    game.current_phase.update_columns(position: rules_position(units: [ [ :england, :army, :lon ], [ :england, :fleet, :nth ] ]))
    england.save_orders!(phase.reload, { "lon" => json_of(move(:england, :lon, :nwy)), "nth" => json_of(move(:england, :nth, :nwy)) })
    phone.get path

    expect(rows).to eq([ "Army in London (LON) Move to Norway (NWY), needs a convoy", "Fleet in North Sea (NTH) Move to Norway (NWY)" ])
  end

  it "answers a stranger, a host cookie only, and another game's seat with the stranger response (AC-1.7)" do
    host_only = open_session.tap { |session| session.get "/games/#{id}/host-link", params: { token: created.host_token } }
    sessions = { "no cookie" => open_session, "the host cookie only" => host_only, "another game's seat" => create_game.session }
    sessions.each do |name, session|
      session.get path
      expect(session.response).to have_http_status(:not_found), name
    end
  end

  it "walks one order from the list with only the page's own links and forms, no script needed (AC-3.5)" do
    phone.get path
    phone.get page.at_css("a.unit-row[href$='/lon']")["href"]
    phone.get page.css(".picker a.list__row").find { |a| a.text.squish == "Move" }["href"]
    form = page.css(".picker form").find { |f| f.text.include?("North Sea") }
    fields = form.css("input").to_h { |input| [ input["name"], input["value"] ] }
    phone.post form["action"], params: fields # the form's own fields, _method and token included, as a browser would send them
    expect(phone.response).to have_http_status(:see_other)
    phone.follow_redirect!
    expect(rows[1]).to eq("Fleet in London (LON) Move to North Sea (NTH)")
  end

  it "carries the phase header with the power badge and the no-store headers (AC-1.5)" do
    phone.get path
    expect(page.at_css(".phase-header .power-badge--england")).to be_present
    expect(phone.response.headers["Cache-Control"]).to include("no-store")
    expect(page.at_css("meta[name='turbo-cache-control'][content='no-cache']")).to be_present
  end
end
```

Run it first: it fails (the page has selects and no `.unit-row`).

### 5b. The code

```ruby
# app/controllers/seat_orders_controller.rb (changed parts; show, update, refuse and the rescues keep their shape)
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

def load_page
  @units = @phase.position.units.select { |unit| unit.power.to_s == @seat.power }.sort_by { |unit| unit.location.province.to_s }
  @stored = @seat.orders_for(@phase)
  @submitted = @seat.submitted?(@phase)
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

```css
/* components.css (added; tokens only) */
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
.submit-bar__count { display: block; }
```

The old `order_label` and its examples are removed from the helper and its spec in this commit.

**Verify:** `bundle exec rspec` (all, system specs included), `wc -c app/assets/stylesheets/*.css` (total ≤ 32,768, `styleguide.css` ≤ 6,144). **Commit:** "Replace the plain orders form with the order screen".

## Phase 6: The parts in the style guide and the catalog

**Implements:** FR-6. **Satisfies:** AC-6.1 to AC-6.6.
**Files:** change `app/views/styleguide/show.html.erb`, `app/helpers/styleguide_helper.rb` (sample objects), `web/docs/design-system.md`, `spec/requests/styleguide_spec.rb` (its `components` list gains `unit-row picker submit-bar`), `spec/docs/design_system_spec.rb` if it names the catalog lines, `app/assets/stylesheets/styleguide.css` if a sample needs layout.

Test first: the style-guide request spec requires one `[data-component=...]` section for each of the three new names (through its existing `components` list); the layout spec (which loops over the sections) passes at 360 and 768; the design-system spec asserts the three catalog lines say "#23 (built)" with their partial names.

The sections use the real partials with sample objects (`StyleguideHelper::SAMPLE_GAME = Struct.new(:public_id).new("sample")`, `SAMPLE_PHASE = Struct.new(:number).new(1)`, and a unit and an order built from `RulesEngine.starting_position`): a unit row with an order and one that holds; a picker draft with a list of choices (links, and the no-order row); the submit bar not submitted, submitted, and with each `.save-status` text, the "Saving…" one through `saving: true` (the static modifier, so the real statuses on the page are unaffected).

**Verify:** `bundle exec rspec` and the byte count. If the caps do not fit, stop and `ask`. **Commit:** "Add the order screen parts to the style guide".

## Phase 7: System specs at 360 pixels: the walk-through, the other steps, the status

**Implements:** D6, D7. **Satisfies:** AC-3.6, AC-4.6, AC-6.1, AC-7.1 to AC-7.4. **Files:** create `spec/system/order_pickers_spec.rb`.

```ruby
# spec/system/order_pickers_spec.rb
require "rails_helper"
require_relative "../support/rules_helpers"

# Spec 023 Story 7: five units, a full set of orders, 360 pixels wide, within 18 taps and 45 seconds (D7).
RSpec.describe "Entering orders with the pickers", type: :system do
  include RulesHelpers

  def max_taps = 18

  def max_seconds = 45

  def tap_on(text)
    @taps += 1
    click_on text
  end

  def screenshot(name)
    dir = ENV["SCREENSHOTS"]
    page.save_screenshot(File.join(dir, "#{name}.png")) if dir
  end

  def measure_step(label, width)
    widths = evaluate_script("({ scroll: document.documentElement.scrollWidth, client: document.documentElement.clientWidth })")
    expect(widths["scroll"]).to be <= widths["client"], "#{label} scrolls sideways at #{width}"
    small = evaluate_script(<<~JS)
      Array.from(document.querySelectorAll(":is(main, .app-actions) :is(a:not(p a), button, input:not([type=hidden]))")).filter((el) => {
        const r = el.getBoundingClientRect(); return r.width < 43.5 || r.height < 43.5;
      }).map((el) => el.className || el.tagName)
    JS
    expect(small).to be_empty, "#{label}: controls under 44 by 44: #{small.join(', ')}"
  end

  def start_game_with(units)
    started = Game.start!(power: "england")
    started.game.current_phase.update_columns(position: rules_position(units: units))
    visit "/games/#{started.game.public_id}/seat-link?token=#{started.seat_token}"
    started
  end

  it "enters orders for five units and submits in at most 18 taps and 45 seconds (AC-7.1, AC-7.2)" do
    started = start_game_with([ [ :england, :army, :lvp ], [ :england, :fleet, :edi ], [ :england, :fleet, :lon ],
                                [ :england, :army, :yor ], [ :england, :fleet, :mao ] ])
    game = started.game
    @taps = 0

    with_viewport(360) do
      began = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      visit "/games/#{game.public_id}/phases/1/orders"
      expect(page).to have_css(".unit-row", count: 5)
      measure_step("the list", 360)
      screenshot("01-list")

      tap_on "Fleet in Edinburgh"; tap_on "Move"; tap_on "Norwegian Sea"                                # 3
      tap_on "Fleet in London"; tap_on "Move"; tap_on "English Channel"                                  # 3
      tap_on "Army in Yorkshire"; tap_on "Hold"                                                          # 2
      tap_on "Army in Liverpool"; tap_on "Support"; tap_on "Fleet in Edinburgh"; tap_on "Move to Clyde"  # 4
      tap_on "Fleet in Mid-Atlantic Ocean"; tap_on "Move"; tap_on "Spain"; tap_on "North coast"         # 4
      expect(page).to have_css(".submit-bar", text: "5 of 5 ordered")
      tap_on "Submit orders"                                                                             # 1

      expect(page).to have_css(".banner--info", text: "Submitted.")
      elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - began
      expect(@taps).to be <= max_taps
      expect(elapsed).to be <= max_seconds
      seat = game.seats.find_by(power: "england")
      expect(seat.orders_for(game.current_phase).size).to eq(5)
      expect(seat.submitted?(game.current_phase)).to be(true)
    end
  end

  it "completes a by-land-or-convoy move, a convoy order and the other steps, with no sideways scroll and no small control (AC-7.3, AC-7.4)" do
    started = start_game_with([ [ :england, :army, :lon ], [ :england, :fleet, :nth ], [ :england, :fleet, :mao ] ])
    seat = started.game.seats.find_by(power: "england")
    with_viewport(360) do
      visit "/games/#{started.game.public_id}/phases/1/orders"
      click_on "Army in London"; click_on "Move"
      measure_step("the destinations", 360); screenshot("02-destinations")
      click_on "Yorkshire"                                    # land and convoy both legal: the "How" step
      expect(page).to have_css("h1", text: "How does it get there?")
      measure_step("by land or convoy", 360); screenshot("03-how")
      click_on "By convoy"
      expect(page).to have_css(".unit-row__order", text: "Move to Yorkshire (YOR) by convoy")

      click_on "Fleet in North Sea"; click_on "Convoy"
      measure_step("which army", 360); screenshot("04-convoy-army")
      click_on "Army in London"; measure_step("convoy where", 360); screenshot("05-convoy-where")
      click_on "Yorkshire"

      click_on "Fleet in Mid-Atlantic Ocean"; click_on "Move"; click_on "Spain"
      expect(page).to have_css("h1", text: "Which coast?")
      measure_step("which coast", 360); screenshot("06-coast")
      click_on "South coast"
      expect(seat.orders_for(started.game.current_phase.reload).keys).to match_array(%w[lon nth mao])
      screenshot("07-list-ordered")
    end
  end

  it "shows 'Saving…' while a form is being submitted and the resting text otherwise (AC-3.6)" do
    started = start_game_with(RulesEngine.starting_position.units.select { |u| u.power == :england }.map { |u| [ :england, u.type, u.location.province ] })
    with_viewport(360) do
      visit "/games/#{started.game.public_id}/phases/1/orders"
      expect(page).to have_css(".save-status__rest", text: "Saved")
      execute_script("document.querySelector('.submit-bar form').setAttribute('aria-busy', 'true')")
      expect(page).to have_css(".save-status__saving", text: "Saving…", visible: :visible)
      expect(page).to have_no_css(".save-status__rest", visible: :visible)
      execute_script("document.querySelector('.submit-bar form').removeAttribute('aria-busy')")
      expect(page).to have_css(".save-status__rest", text: "Saved", visible: :visible)
    end
  end
end
```

(The link texts are tuned to the pages' real text as the spec is run; the assertions on taps, time and the stored orders do not change. `click_on "Move"` is unambiguous on the action step, whose rows are Hold, Move, Support; "Move to Clyde" is on the support step, where "Move" is not a row.)

**Verify:** `bundle exec rspec spec/system` twice (to see the timing is stable). `SCREENSHOTS=<dir> bundle exec rspec spec/system/order_pickers_spec.rb` writes the PNGs for the pull request; the screenshots (list, destinations, how, convoy army, convoy where, coast, ordered list, and the submitted bar from the walk) are copied to `web/docs/specs/023-order-pickers/screens/`. **Commit:** "Walk a five-unit set of orders at phone width".

## Phase 8: Amend the specs, prove, and open the pull request

**Implements:** AC-8.1. **Files:** change `web/docs/specs/022-phase-lifecycle/spec.md`, `web/docs/specs/023-order-pickers/spec.md` (and `plan.md`); add `web/docs/specs/023-order-pickers/screens/*.png`.

- Spec 022: Version 1.3.0 and a changelog row as AC-8.1 words it, naming exactly what changed: D5 and FR-4 (the plain form) replaced by spec 023; AC-2.11's select page replaced by spec 023's AC-1.1 to AC-1.9; the "Orders saved." banner of AC-2.1 replaced by `.save-status` reading "Saved" (the endpoint's examples that read the banner or the flash, and the 422 example that counted selects, are rewritten); the "n of m units ordered" line moves into the submit bar; "Submitted" and "Not submitted" are read from the submit bar (AC-3.1, AC-3.2, AC-7.10); labels use full names; its Non-Goal for #23 is met.
- Run, from `web/`: `bundle exec rspec` (all, system specs included), `bin/brakeman`, `bin/rubocop`, `git diff --name-only main...HEAD` (only `web/` paths), `wc -c app/assets/stylesheets/*.css`.
- The read-only Opus implementation review; its findings and how each was handled go in the pull request description.
- Push; open the draft pull request from the template ("Closes #23", the screenshots at 360 pixels of each step, the draft-in-the-query limit stated, the spec 022 amendment noted); wait for the `Web specs` job to be green; `gh pr ready`; assign.

**Commit:** "Amend spec 022 for the pickers".

## Coverage check (every spec item has a phase)

| Spec | Phase |
|---|---|
| FR-1, AC-1.1 to AC-1.9 | 5 (words: 2) |
| FR-2, AC-2.x | 3 (model), 4 (pages, crawler) |
| FR-3 | 1, 2 |
| FR-4, AC-3.x | 4 (AC-3.1, 3.3, 3.5, 3.7), 5 (3.2, 3.4), 7 (3.6) |
| FR-5, AC-4.x | 5 |
| FR-6, AC-6.x | 4 and 5 (CSS), 6 (style guide), 7 (geometry) |
| FR-7 | 4 |
| FR-8, AC-5.x | 4 |
| AC-7.x | 7 |
| AC-8.1 | 8; AC-8.2 | 5 |

## Changelog

| Version | Date | Change |
|---|---|---|
| 1.2.0 | 2026-11-26 | After the second Opus review: the import-map test lists the four real pins; the first test waits in the scratchpad so the suite is green in every commit; AC-3.5 gets a walk from the list, AC-1.7 all three kinds of viewer, AC-5.3 England's pages checked for France's order words, AC-3.7 a no-link-off-the-app check; the button posts no stray field; the AC-3.6 spec visits the screen directly; the rewrite list names the remaining lines of `orders_spec` |
| 1.1.0 | 2026-11-26 | After the first Opus review: picker pages moved before the screen and merged with their route classification so every commit is green; `order_label` is kept until Phase 5; the first test reads `.unit-row__body` (the icon's tag adds text); the walk's position is written as an object; the rewrites of the existing specs are listed by file and line; the style guide's "Saving…" sample uses a static modifier; the model's support and convoy steps, nil rules and back drafts are written out; a request-level crawler is added; the real single-branch positions replace the stubs; the AC-3.7 log test builds a request with the app's filter; the sweep test uses its own snapshot; the one-coast destination notes the coast; spec 1.0.3 records the three-key draft |
| 1.0.0 | 2026-11-26 | First draft |

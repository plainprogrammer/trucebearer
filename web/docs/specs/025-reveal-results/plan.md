# Plan 025: Reveal results to every phone at once

**Spec:** `web/docs/specs/025-reveal-results/spec.md` v1.0.0 (Approved at Gate A)
**Issue:** #25 · **Branch:** `web/25-reveal-results` · **Plan version:** 1.2.0 (after the Opus review and execution: see the changelog at the end; `main` with #104 is merged in)

## Goal

After the host reveals, every phone switches to the results with no tap, and every seat and the host can read every power's orders of the revealed phase with plain-word outcomes; the open phase stays secret. The switch is one contentless Turbo refresh on a stream of its own, `results:<public id>`, sent once from `Phase#reveal!`. Results are drawn only from the stored adjudication's hash form, by a plain Ruby presenter and a handful of partials. Two new routes show one revealed phase (player version, reading view); the seat page and the host page show the latest one; a plain "Earlier results" list links the rest.

**The first test.** Before Phase 1, the brief's request spec is written in the scratchpad (outside `spec/`) and run once to see it fail; Phase 3 copies it into `spec/requests/results_spec.rb` and makes it pass, so every commit is green and the first test is still the first one written.

```ruby
# spec/requests/results_spec.rb (first version)
require "rails_helper"
require Rails.root.join("spec/support/rules_helpers") # an absolute path, so the scratchpad copy runs too

RSpec.describe "Results after the reveal", type: :request do
  include RulesHelpers

  around { |example| with_passphrase { example.run } }

  let!(:created) { create_game(power: "england") }
  let(:game) { created.game }
  let(:id) { game.public_id }
  let!(:france) { game.take_seat!("france") }
  let(:france_phone) do
    open_session.tap { |session| session.get "/games/#{id}/seat-link", params: { token: france.last } }
  end

  it "shows France's seat page England's order and the tag Succeeded once the host has revealed (AC-1.1)" do
    england = game.seats.find_by(power: "england")
    england.save_orders!(game.current_phase, { "lon" => json_of(move(:england, :lon, :nth)) }, submit: true)
    created.session.post "/games/#{id}/host/phases/1/reveal"

    france_phone.get "/games/#{id}"
    page = Nokogiri::HTML5(france_phone.response.body)
    section = page.at_css("section[data-results]")
    row = page.css(".result-group[data-power=england] .result-row").find { |r| r.text.include?("Move to North Sea (NTH)") }

    expect(section).not_to be_nil # fails here, for the right reason, until the results view exists
    expect(section.at_css("h2").text).to include("Spring 1901 · Movement")
    expect(row).not_to be_nil
    expect(row.at_css(".outcome-tag").text).to eq("Succeeded")
  end
end
```

Run once against today's code: it fails at `expect(section).not_to be_nil` (no results section). The stand-in answers England's fleet London to North Sea as `succeeded` (an uncontested legal move).

## Decisions the plan adds (each traceable to the spec)

- **Names.** `PhaseResults` (`app/models/phase_results.rb`, plain Ruby, FR-1); `OutcomeHelper` (`OUTCOME_WORDS`, D6); partials `results/_outcome_tag`, `_row`, `_group`, `_section`, `_practice_note`, `_live` (FR-2, D2); `ResultsController` and `HostResultsController` (FR-3); routes `game_seat_results` and `game_host_results`; `Game#broadcast_results_refresh` (FR-4); `RulesEngine.stand_in?` (D6).
- **Hash form only.** `PhaseResults` reads `phase.adjudication.to_h` and `phase.position.to_h["units"]`; no view reads a gem object. `OrderLabelHelper#order_words` already calls `order.to_h`, so it takes the row's order hash as it is; its `unit` argument is a `PhaseResults::UnitRef` (`type` symbol) or nil, and `move_words` gets a nil guard (`unit&.type`).
- **Banners.** `shared/_banner` gains an optional `marker` local that adds `data-paradox` or `data-dislodged`; its text and classes are unchanged. `HostsController` stops computing `@dislodged` (the section draws the banners from `PhaseResults#banners`, same sentence).
- **`no_store`.** Rails' `no_store` (already used in `hosts_controller`, `reissues_controller` and the `OrderScreen` concern) runs as a `before_action` after the access check on `HostsController`, and inside `GamesController#show` after the stranger/step-in returns, so a stranger or redirect response is unchanged (D9).
- **Sweep.** `SecrecyRoutes::Context` gains `open` (default 1) and `revealed` (default nil). Existing entries keep their labels and use `c.open`. An entry may add `numbered:`, requested only when `c.revealed` is set, labelled `"<key> [revealed]"`. Every entry gets `revealed: :none`, except the four routes of AC-5.1 (`:all`), added by a script in Phase 6.
- **Stylesheet budget.** Today `components.css` is 15,309 bytes and the total 27,019 of 32,768; `styleguide.css` 3,716 of 6,144. No cap is exceeded by the plan's CSS (about 1.9 KB); Phase 2 records the sizes after. Spec 020 has only the total and `styleguide.css` caps (the spec's "components.css within its cap" is read that way).
- **Mono face.** The outcome tag takes the existing `.mono` class on its span; no rule reads `var(--font-mono)` except `.mono` (`spec/styles/font_spec.rb`).
- **#104 is merged in** (`reissues` table, `data-seat-history`, England reissued in the sweep's setup). It changes none of this plan's files in a way that matters: the host page's `step_ins/history` render is now the seat history, which this plan leaves alone; the sweep's `england_seat_and_token` is already a reissue, which world 2 reuses.
- **Spec support.** `spec/support/results_fixtures.rb` starts with `require_relative "rules_helpers"`; the three new spec files that use it start with `require "rails_helper"` and `require_relative "../support/results_fixtures"`.

## Gates checked

- **Simplicity:** one presenter, one helper, six partials, two thin controllers, one broadcast method; no channel, no JavaScript, no migration, no gem.
- **Anti-abstraction:** `Turbo::StreamsChannel.broadcast_refresh_to` and `turbo_stream_from` are used directly; no service object, no view model beyond the presenter's `Data` rows.
- **Integration-first:** the first test goes through the real reveal and real pages; Phase 5 reads the real adapter's raw store; Phase 7 uses two real browsers.

## Phase 1: Words, presenter and fixtures

**Implements:** FR-1, D6 (words), D8 (data). **Satisfies:** AC-1.3 (data), AC-1.4, AC-1.5, AC-1.6 (data), AC-7.2, AC-2.2 (banner data). **Files:** create `app/helpers/outcome_helper.rb`, `app/models/phase_results.rb`, `spec/support/results_fixtures.rb`, `spec/helpers/outcome_helper_spec.rb`, `spec/models/phase_results_spec.rb`; change `app/helpers/order_label_helper.rb`, `app/models/rules_engine.rb`.

Test first. The one fixture builder (AC-2.2, AC-1.4) writes the stored result's hash form and sets both the outcomes' flags and the position's dislodged units:

```ruby
# spec/support/results_fixtures.rb
require_relative "rules_helpers"

module ResultsFixtures
  include RulesHelpers

  # outcomes: [[order_hash, result, submitted, dislodged], ...]; dislodged: [[power, type, province], ...] for the position.
  # Obeys the gem's "Impossible objects" rules: results suit the order class, no dislodged void, submitted before implied
  # holds, implied holds sorted by province. Returns the phase with the result stored, revealed.
  def revealed_phase_with(game, outcomes:, dislodged: [], paradox: false, units: nil)
    phase = game.current_phase
    phase.update_columns(position: units ? rules_position(units: units) : phase.position) if units
    after = phase.position.to_h.merge("phase" => "retreat",
      "dislodged_units" => dislodged.map { |power, type, province| { "unit" => unit_hash(power, type, province), "attacker_from" => "bul", "by_convoy" => false } })
    hash = { "format" => 1, "paradox" => paradox, "position" => after,
             "outcomes" => outcomes.map { |order, result, submitted, flag| { "order" => order, "result" => result.to_s, "submitted" => submitted, "dislodged" => flag } } }
    # one update_columns call sets both columns the check constraint ties together; the column's own type serialises the loaded result
    phase.update_columns(adjudication: RulesEngine.load_adjudication(hash), revealed_at: Time.current)
    game.phases.create!(number: phase.number + 1, position: phase.position)
    phase.reload
  end
end
```

A hand-built result enters through `RulesEngine.load_adjudication`, so a hash the loader refuses fails the fixture, not the page.

```ruby
# spec/helpers/outcome_helper_spec.rb
RSpec.describe OutcomeHelper, type: :helper do
  it "maps exactly the nine documented symbols and the dislodged flag (spec 025 D6)" do
    expect(OutcomeHelper::OUTCOME_WORDS.keys).to match_array(%w[void held no_route bounced succeeded unmatched cut disrupted given dislodged])
  end

  it "words each one (AC-1.4)" do
    words = { "succeeded" => "Succeeded", "bounced" => "Bounced", "no_route" => "No route", "held" => "Held", "given" => "Given",
              "cut" => "Support cut", "unmatched" => "Not used", "disrupted" => "Convoy disrupted",
              "void" => "Not a legal order", "dislodged" => "Dislodged" }
    words.each { |kind, text| expect(helper.outcome_words(kind)).to eq(text) }
  end

  it "shows Dislodged first and drops a Held tag beside it" do
    row = Struct.new(:result, :dislodged)
    expect(helper.outcome_tags(row.new("held", true))).to eq(%w[dislodged])
    expect(helper.outcome_tags(row.new("bounced", true))).to eq(%w[dislodged bounced])
    expect(helper.outcome_tags(row.new("disrupted", true))).to eq(%w[dislodged disrupted])
    expect(helper.outcome_tags(row.new("succeeded", false))).to eq(%w[succeeded])
  end
end
```

```ruby
# spec/models/phase_results_spec.rb (core examples)
RSpec.describe PhaseResults do
  include ResultsFixtures
  let(:game) { Game.start!(power: "england").game }
  let(:hold)  { ->(power, at) { { "format" => 1, "type" => "hold", "power" => power, "at" => at } } }

  it "refuses an open phase" do
    expect { PhaseResults.new(game.current_phase) }.to raise_error(ArgumentError)
  end

  it "groups by power in the gem's order, dislodged rows first, a group with a dislodged unit first in the reading order (D8, AC-1.5)" do
    phase = revealed_phase_with(game,
      outcomes: [[ hold.("england", "lon"), :held, true, false ], [ hold.("france", "par"), :held, true, true ], [ hold.("france", "bre"), :held, false, false ]],
      dislodged: [ [ "france", "army", "par" ] ])
    results = PhaseResults.new(phase)

    expect(results.groups.map(&:power)).to eq(%w[england france])
    expect(results.groups.last.rows.map(&:province)).to eq(%w[par bre])          # the dislodged row first
    expect(results.reading_groups.map(&:power)).to eq(%w[france england])       # a group holding a dislodged unit first
    expect(results.banners.map { |b| [ b.power, b.unit_type, b.province ] }).to eq([ %w[france army par] ])
  end

  it "gives a void order for a unit that is not the power's own no unit, and an implied hold its note's cause (D8, AC-1.3, AC-1.6)" do
    phase = revealed_phase_with(game, outcomes: [[ hold.("france", "lon"), :void, true, false ], [ hold.("england", "lon"), :held, false, false ]])
    rows = PhaseResults.new(phase).groups.flat_map(&:rows)

    expect(rows.find { |r| r.power == "france" }.unit).to be_nil
    expect(rows.find { |r| r.power == "england" }.submitted).to be(false)
  end

  it "reads only the hash form: a hash shaped as the gem's 0.2.0 to_h, and the same hash with every key order reversed, draw the same rows (AC-7.2)" do
    outcomes = [ { "order" => hold.("england", "lon"), "result" => "held", "submitted" => true, "dislodged" => false } ]
    after = game.current_phase.position.to_h.merge("phase" => "retreat")
    documented = { "format" => 1, "outcomes" => outcomes, "paradox" => false, "position" => after }
    reversed = ->(value) { value.is_a?(Hash) ? value.to_a.reverse.to_h { |k, v| [ k, reversed.(v) ] } : (value.is_a?(Array) ? value.map { |v| reversed.(v) } : value) }
    phases = [ documented, reversed.(documented) ].map do |hash|
      game_n = Game.start!(power: "england").game
      phase = game_n.current_phase
      phase.update_columns(adjudication: RulesEngine.load_adjudication(hash), revealed_at: Time.current)
      phase.reload
    end

    expect(PhaseResults.new(phases.first).groups).to eq(PhaseResults.new(phases.last).groups)
    expect(PhaseResults.new(phases.first).groups.first.rows.map(&:province)).to eq(%w[lon])
  end

  it "carries the stored paradox flag" do
    expect(PhaseResults.new(revealed_phase_with(game, outcomes: [], paradox: true)).paradox?).to be(true)
  end
end
```

The rendered examples for AC-1.3 and AC-1.4 are in `spec/views/results_partials_spec.rb` (Phase 2), which uses the same builder.

Implementation:

```ruby
# app/helpers/outcome_helper.rb
# The words of our own for what became of an order (spec 025 D6). Keyed by the gem's documented result symbols as strings (the hash form)
# and "dislodged" for the flag. fetch, so a symbol the table lacks fails loudly in the suite.
module OutcomeHelper
  OUTCOME_WORDS = {
    "succeeded" => "Succeeded", "bounced" => "Bounced", "no_route" => "No route", "held" => "Held", "given" => "Given",
    "cut" => "Support cut", "unmatched" => "Not used", "disrupted" => "Convoy disrupted", "void" => "Not a legal order",
    "dislodged" => "Dislodged"
  }.freeze

  def outcome_words(kind) = OUTCOME_WORDS.fetch(kind.to_s)

  # The tags a row shows, in order: Dislodged first, then its result, except that "Held" beside "Dislodged" reads as a contradiction.
  def outcome_tags(row)
    return [ row.result ] unless row.dislodged

    [ "dislodged", *(row.result == "held" ? [] : [ row.result ]) ]
  end
end
```

```ruby
# app/models/phase_results.rb
# What a revealed phase looks like to a reader (spec 025 FR-1). It reads the stored adjudication's hash form and the phase's
# starting position's hash form only: no gem class, no saved order, no computed outcome.
class PhaseResults
  UnitRef = Data.define(:type)
  Row = Data.define(:order, :power, :province, :unit, :result, :submitted, :dislodged)
  Group = Data.define(:power, :rows) { def dislodged? = rows.any?(&:dislodged) }
  Banner = Data.define(:power, :unit_type, :province)

  attr_reader :phase

  def initialize(phase)
    raise ArgumentError, "results are only for a revealed phase" if phase.open?

    @phase = phase
    @hash = phase.adjudication.to_h
  end

  def paradox? = @hash["paradox"] == true

  # Powers in the gem's order; within a group, dislodged rows first and otherwise the order the result gives.
  def groups
    @groups ||= begin
      by_power = rows.group_by(&:power)
      RulesEngine.powers.map { |power| power.id.to_s }.filter_map do |id|
        list = by_power[id]
        next unless list

        Group.new(power: id, rows: list.each_with_index.sort_by { |row, i| [ row.dislodged ? 0 : 1, i ] }.map(&:first))
      end
    end
  end

  # The host's reading order: groups holding a dislodged unit first (D8).
  def reading_groups = groups.each_with_index.sort_by { |group, i| [ group.dislodged? ? 0 : 1, i ] }.map(&:first)

  # From the stored position's dislodged units, which is the authority for the host's warnings (D8).
  def banners
    @hash.dig("position", "dislodged_units").map do |entry|
      unit = entry.fetch("unit")
      Banner.new(power: unit["power"], unit_type: unit["type"], province: unit.dig("location", "province"))
    end
  end

  private

  def rows
    @rows ||= @hash["outcomes"].map do |outcome|
      order = outcome["order"]
      unit = starting_units[order["at"]]
      ref = unit && unit["power"] == order["power"] ? UnitRef.new(type: unit["type"].to_sym) : nil
      Row.new(order: order, power: order["power"], province: order["at"], unit: ref, result: outcome["result"],
              submitted: outcome["submitted"], dislodged: outcome["dislodged"])
    end
  end

  def starting_units = @starting_units ||= phase.position.to_h["units"].to_h { |u| [ u.dig("location", "province"), u ] }
end
```

```ruby
# app/helpers/order_label_helper.rb: move_words, one changed line (a result row may have no unit)
parts << ", needs a convoy" if unit&.type == :army && !RulesEngine.army_adjacent?(h["at"], destination["province"])
```

```ruby
# app/models/rules_engine.rb, in `class << self`, beside adjudicate
# STAND-IN, until gem 0.2.0 (#29): true while adjudicate is answered by the stand-in, so results views say they are practice
# results (spec 025 D6). #29 deletes this with the stand-in and the note's partial.
def stand_in? = true
```

Run: `bundle exec rspec spec/helpers/outcome_helper_spec.rb spec/models/phase_results_spec.rb spec/models/rules_engine_boundary_spec.rb spec/models/rules_engine_stand_in_spec.rb`. Commit.

## Phase 2: Partials, styles and the style guide

**Implements:** FR-2, D6 (note, paradox), D8 (markup), the design system. **Satisfies:** AC-7.1 (partial), AC-8.1, AC-8.2, AC-8.3, AC-7.3 (words). **Files:** create `app/views/results/_outcome_tag.html.erb`, `_row.html.erb`, `_group.html.erb`, `_section.html.erb`, `_practice_note.html.erb`; change `app/views/shared/_banner.html.erb`, `app/assets/stylesheets/components.css`, `app/views/styleguide/show.html.erb`, `app/helpers/styleguide_helper.rb` (sample data), `web/docs/design-system.md`, `spec/requests/styleguide_spec.rb` (its fixed component list at the top gains `results`), `spec/docs/design_system_spec.rb`; create `spec/views/results_partials_spec.rb`, `spec/styles/results_words_spec.rb`.

Test first:

```ruby
# spec/requests/styleguide_spec.rb (added, in the existing describe)
it "shows results: a player group, a reading group with a dislodged row, every tag once, and the practice note (spec 025 AC-8.1)" do
  section = page.at_css("section[data-component=results]")

  expect(section.css(".result-group").size).to eq(2)
  expect(section.css(".result-group--reading").size).to eq(1)
  expect(section.css(".result-group--reading .result-row--dislodged")).not_to be_empty
  expect(section.css(".outcome-tag").map(&:text).uniq).to include("Succeeded", "Bounced", "Support cut", "Dislodged", "Not a legal order")
  expect(section.at_css(".practice-note")).to be_present
end

# spec/docs/design_system_spec.rb (added)
it "lists the results parts of Issue 25 as built, with their classes and partials (spec 025 AC-8.1)" do
  %w[.result-row .outcome-tag .result-group].each do |klass|
    line = doc.lines.find { |l| l.include?("`#{klass}`") && l.include?("#25") && l.match?(/built/i) }
    expect(line).not_to be_nil, "no catalog line names #{klass} with #25 and built"
  end
  expect(doc).to include("results/_outcome_tag").and include("results/_row").and include("results/_group")
end

# spec/views/results_partials_spec.rb (type: :view, renders results/_section for a PhaseResults built from the one fixture builder)
RSpec.describe "results partials", type: :view do
  include ResultsFixtures
  let(:game) { Game.start!(power: "england").game }
  def order(type, power, at, **rest) = { "format" => 1, "type" => type, "power" => power, "at" => at }.merge(rest.transform_keys(&:to_s))
  def move_to(power, at, to) = order("move", power, at, destination: { "province" => to, "coast" => nil })
  def draw(phase, kind: :seat, banners: false) = Nokogiri::HTML5.fragment(render("results/section", results: PhaseResults.new(phase), kind: kind, game: game, earlier: [], banners: banners, skip: false))

  it "draws one row of every order kind, in words with full names, and 'Order for LON' for a unit that is not the power's own or not on the board (AC-1.3)" do
    phase = revealed_phase_with(game, outcomes: [
      [ order("hold", "england", "edi"), :held, true, false ],
      [ move_to("england", "lon", "nth"), :succeeded, true, false ],
      [ order("move_via_convoy", "england", "lvp", to: "nwy"), :no_route, true, false ],
      [ order("support_move", "england", "lvp", from: "lvp", to: "yor"), :unmatched, true, false ],
      [ order("convoy", "england", "lon", from: "lvp", to: "nwy"), :given, true, false ],
      [ move_to("france", "lon", "eng"), :void, true, false ],
      [ move_to("germany", "ruh", "bel"), :void, true, false ] ])
    rows = draw(phase).css(".result-row").to_h { |row| [ [ row["data-power"], row["data-province"] ], row ] }

    expect(rows[%w[england edi]].text).to include("Hold")
    expect(rows[%w[england lon]].text).to include("Move to North Sea (NTH)")
    expect(rows[%w[england lvp]].text).to include("Move to Norway (NWY) by convoy")
    expect(rows[%w[france lon]].text).to include("Order for London (LON)")        # London holds England's fleet, not France's
    expect(rows[%w[germany ruh]].text).to include("Order for Ruhr (RUH)")          # no unit on the board: a plain move never meets a missing unit type
    expect(rows[%w[france lon]].at_css(".unit-icon")).to be_nil
  end

  it "tags each symbol and the dislodged flag row by row (AC-1.4)" do
    phase = revealed_phase_with(game, dislodged: [ %w[england fleet lon] ], outcomes: [
      [ order("hold", "england", "lon"), :held, true, true ],          # dislodged hold: "Dislodged" alone
      [ move_to("england", "edi", "nwg"), :bounced, true, true ],      # dislodged bounced move: "Dislodged", "Bounced"
      [ order("convoy", "england", "lvp", from: "lvp", to: "nwy"), :disrupted, true, true ],
      [ move_to("france", "par", "bur"), :succeeded, true, false ],
      [ order("support_move", "france", "bre", from: "par", to: "bur"), :cut, true, false ],
      [ order("support_hold", "france", "mar", target: "par"), :given, true, false ],
      [ order("convoy", "germany", "kie", from: "ber", to: "swe"), :unmatched, true, false ],
      [ move_to("germany", "ber", "sil"), :no_route, true, false ],
      [ order("hold", "austria", "vie"), :void, true, false ] ])
    tags = draw(phase).css(".result-row").to_h { |row| [ [ row["data-power"], row["data-province"] ], row.css(".outcome-tag").map(&:text) ] }

    expect(tags[%w[england lon]]).to eq([ "Dislodged" ])
    expect(tags[%w[england edi]]).to eq([ "Dislodged", "Bounced" ])
    expect(tags[%w[england lvp]]).to eq([ "Dislodged", "Convoy disrupted" ])
    expect(tags[%w[france par]]).to eq([ "Succeeded" ])
    expect(tags[%w[france bre]]).to eq([ "Support cut" ])
    expect(tags[%w[france mar]]).to eq([ "Given" ])
    expect(tags[%w[germany kie]]).to eq([ "Not used" ])
    expect(tags[%w[germany ber]]).to eq([ "No route" ])
    expect(tags[%w[austria vie]]).to eq([ "Not a legal order" ])
  end

  it "notes an implied hold's cause, and drops 'so it held' when it was dislodged (AC-1.6)" do
    phase = revealed_phase_with(game, dislodged: [ %w[england fleet lon] ], outcomes: [
      [ order("hold", "england", "lon"), :held, false, true ], [ order("hold", "england", "edi"), :held, false, false ] ])
    notes = draw(phase).css(".result-row").to_h { |row| [ row["data-province"], row.at_css(".result-row__note").text ] }

    expect(notes).to eq("lon" => "No valid order", "edi" => "No valid order, so it held")
  end

  it "shows the paradox banner only when the stored result says so, and the practice note only while the stand-in is in use (AC-7.1, AC-7.4)" do
    clean = revealed_phase_with(game, outcomes: [])
    expect(draw(clean).css("[data-paradox]")).to be_empty
    expect(draw(clean).at_css(".practice-note")).to be_present
    allow(RulesEngine).to receive(:stand_in?).and_return(false)
    expect(draw(clean).at_css(".practice-note")).to be_nil

    odd = revealed_phase_with(Game.start!(power: "england").game, outcomes: [], paradox: true)
    expect(draw(odd).css("[data-paradox].banner--warning").size).to eq(1)
  end

  it "has one banner for each dislodged unit on the latest phase, equal to the Dislodged tags, and none when banners is false (AC-2.2, AC-2.6)" do
    phase = revealed_phase_with(game, dislodged: [ %w[england fleet lon] ], outcomes: [ [ order("hold", "england", "lon"), :held, true, true ] ])
    expect(draw(phase, kind: :host, banners: true).css("[data-dislodged]").size).to eq(draw(phase, kind: :host).css(".outcome-tag--dislodged").size)
    expect(draw(phase, kind: :host, banners: false).css("[data-dislodged]")).to be_empty
  end
end
# spec/styles/results_words_spec.rb
#  - AC-8.2: only app/views/results/_outcome_tag.html.erb contains "outcome-tag" among app/views and app/helpers
#  - AC-7.3 is a request example in spec/requests/results_spec.rb (Phase 3): the rendered seat page, host page and both results pages of a revealed
#    phase hold, case-insensitively, none of official, licensed, authorized, confirmed, verified, final, real results
```

Implementation:

```erb
<%# results/_outcome_tag.html.erb: the only writer of .outcome-tag (spec 025 AC-8.2). locals: kind (a result symbol as text, or "dislodged") %>
<span class="outcome-tag outcome-tag--<%= kind %> mono"><%= outcome_words(kind) %></span>
```

```erb
<%# results/_row.html.erb: one outcome. locals: row (PhaseResults::Row) %>
<li class="result-row<%= " result-row--dislodged" if row.dislodged %>" data-power="<%= row.power %>" data-province="<%= row.province %>">
  <% if row.unit %><%= unit_icon(row.power, row.unit.type, size: 32, decorative: true) %><% end %>
  <span class="result-row__body">
    <span class="result-row__unit"><%= row.unit ? "#{row.unit.type.to_s.capitalize} in " : "Order for " %><%= province_label(row.province) %></span>
    <span class="result-row__order"><%= order_words(row.order, row.unit) %></span>
    <% unless row.submitted %><span class="result-row__note text-muted"><%= row.dislodged ? "No valid order" : "No valid order, so it held" %></span><% end %>
  </span>
  <span class="result-row__tags"><% outcome_tags(row).each do |kind| %><%= render "results/outcome_tag", kind: kind %> <% end %></span>
</li>
```

```erb
<%# results/_group.html.erb: one power. locals: group (PhaseResults::Group), reading (true in the host's reading view) %>
<section class="result-group<%= " result-group--reading" if reading %>" data-power="<%= group.power %>">
  <h3 class="result-group__title"><%= power_badge(group.power) %></h3>
  <ul class="list result-group__rows">
    <%= render partial: "results/row", collection: group.rows, as: :row %>
  </ul>
</section>
```

```erb
<%# results/_section.html.erb: one phase's results for one kind of reader (spec 025 D4, D7, D8).
    locals: results (PhaseResults), kind (:seat or :host), game, earlier (phases, newest first), banners (true on the latest phase, host only), skip (seat page only) %>
<section class="results stack" aria-labelledby="results-heading" data-results data-phase="<%= results.phase.number %>">
  <h2 id="results-heading">Results: <%= results.phase.title %></h2>
  <%= link_to "Skip to orders", "#enter-orders", class: "button button--secondary" if skip %>
  <%= render "shared/banner", kind: "warning", marker: "paradox",
        text: "The rules engine found a convoy paradox in this phase, so these outcomes can't be trusted. Settle this phase by hand." if results.paradox? %>
  <% if banners %>
    <% results.banners.each do |dislodged| %>
      <%= render "shared/banner", kind: "warning", marker: "dislodged",
            text: "#{power_name(dislodged.power)}'s #{dislodged.unit_type} in #{dislodged.province.upcase} was dislodged. Settle it by hand." %>
    <% end %>
  <% end %>
  <%= render "results/practice_note" if RulesEngine.stand_in? %>
  <% (kind == :host ? results.reading_groups : results.groups).each do |group| %>
    <%= render "results/group", group: group, reading: kind == :host %>
  <% end %>
  <% if earlier.any? %>
    <h3>Earlier results</h3>
    <ul class="list">
      <% earlier.each do |past| %>
        <li><%= link_to past.title, (kind == :host ? game_host_results_path(game.public_id, past.number) : game_seat_results_path(game.public_id, past.number)), class: "list__row mono" %></li>
      <% end %>
    </ul>
  <% end %>
</section>
```

`power_name` is the helper the host page already uses. The banner text is the sentence the host page has drawn since spec 022 (the existing examples that read it stay valid).

```erb
<%# results/_practice_note.html.erb: removed by #29 with RulesEngine.stand_in? %>
<p class="practice-note text-muted">Practice results. The rules engine isn't connected yet, so these outcomes are made up and can be wrong. Don't move pieces by them.</p>
```

```erb
<%# shared/_banner.html.erb: one added optional local, marker, written as a data attribute (spec 025 D6, D8) %>
<% lead = { "warning" => "Warning: ", "danger" => "Error: " }.fetch(kind.to_s, "") %>
<p class="banner banner--<%= kind %>" role="<%= kind.to_s == "info" ? "status" : "alert" %>"<%= " data-#{marker}".html_safe if local_assigns[:marker] %>><%= lead %><%= text %></p>
```

(`marker` is only ever a literal from this plan's two call sites; the partial's header comment says so.)

CSS (about 1.9 KB), in `components.css` inside the `components` layer, tokens only, no new token (the danger tone reuses `--color-danger` and its documented surface and ice-pale pairs; the contrast spec already covers them):

```css
/* ---- Results (#25): .result-group of .result-row, each with .outcome-tag words in the mono face ---- */
.result-group__title { margin: 0 0 var(--space-2); font-size: var(--text-base); }
.result-row { display: flex; align-items: flex-start; flex-wrap: wrap; gap: var(--space-3); padding: var(--space-2) var(--space-4); background: var(--color-surface); }
.result-row__body { display: flex; flex: 1; flex-direction: column; min-width: 12rem; overflow-wrap: anywhere; }
.result-row__order { font-weight: var(--weight-strong); }
.result-row__tags { display: flex; flex-wrap: wrap; gap: var(--space-2); }
.outcome-tag { font-size: var(--text-sm); padding: 0 var(--space-2); border: var(--border-width) solid var(--color-border); border-radius: var(--radius); background: var(--color-ice-pale); color: var(--color-text); }
.outcome-tag--dislodged { border-color: var(--color-danger); color: var(--color-danger); background: var(--color-surface); }
.result-group--reading { font-size: var(--text-lg); }
.result-group--reading .result-row { padding-block: var(--space-3); }
.result-group--reading .outcome-tag { font-size: var(--text-base); }
```

The reading group's type size (`--text-lg`, 1.25rem) is larger than the player's (`--text-base`), which Phase 7 measures. If `.list` rows need the `.list > li + li` border, `result-group__rows` is a `.list`, so it has it; `.result-row` is not `.list__row` and is not a control (no 44-pixel minimum).

The style guide gets a `section[data-component=results]` (hand-built sample `PhaseResults::Row` and `Group` values from `StyleguideHelper`, one row per tag, one reading group with a dislodged row, the practice note) and the three catalog rows read "#25 (built)" naming `results/_outcome_tag`, `results/_row`, `results/_group` and `results/_section`. Record `wc -c` of the stylesheets after (expect the total near 28.9 KB of 32 KB).

Run: `bundle exec rspec spec/views spec/styles spec/requests/styleguide_spec.rb spec/docs spec/requests/components_spec.rb`. Commit.

## Phase 3: The results pages, and the seat page and host page sections

**Implements:** D4, D5 (routes), D7, D9, FR-3. **Satisfies:** AC-1.1, AC-1.2, AC-1.7, AC-1.8, AC-1.9, AC-2.1 to AC-2.6, AC-6.1 to AC-6.3, AC-7.1, AC-7.4. **Files:** create `app/controllers/results_controller.rb`, `app/controllers/host_results_controller.rb`, `app/views/results/show.html.erb`, `app/views/host_results/show.html.erb`, `spec/requests/results_spec.rb` (the first test, now in `spec/`), `spec/requests/host_results_spec.rb`; change `config/routes.rb`, `app/controllers/games_controller.rb`, `app/controllers/hosts_controller.rb`, `app/views/games/show.html.erb`, `app/views/hosts/show.html.erb`, `spec/support/secrecy_routes.rb` (the two routes and `Context`'s `open`, as Phase 6 will use them), `spec/requests/order_secrecy_spec.rb` (the old AC-7.9 example, so this phase ends green), `spec/requests/host_spec.rb`, `spec/requests/reveal_post_spec.rb` (its dislodged fixture moves to the one builder), `spec/requests/phase_pages_spec.rb` (where they assert the old shapes).

Test first: the first test (above) is copied into `spec/requests/results_spec.rb` and run to fail, then these join it, each as a request example:

```ruby
# spec/requests/results_spec.rb (added; helpers from ResultsFixtures)
it "serves the player version on its own URL for a revealed phase, with a link back (AC-1.2)"        # 200, groups, no .result-group--reading, a[href="/games/ID"]
it "gives the stranger response for the open phase, a later one, 7, 01, 1.5 and abc (AC-1.8)"          # status and body equal to a stranger's response (comparable)
it "starts the seat page's section with a Skip to orders link that targets #enter-orders (AC-1.9)"
it "has no results section and no Earlier results list before any reveal (AC-1.7)"
it "lists earlier phases newest first with links that return 200, and none with one revealed phase (AC-6.1, AC-6.2)"
it "shows the practice note while stand_in? is true, and none when stubbed false, on all four views (AC-7.1)"
it "shows one paradox banner for a paradox:true result and none otherwise, on all four views (AC-7.4)"
it "uses none of official, licensed, authorized, confirmed, verified, final, real results on the four rendered views (AC-7.3)"
it "gives a seat the seat results route's 404 for the open phase, the host with France's seat cookie a 303, and a stranger the stranger page on both new routes (AC-5.2, world 1)"
# spec/requests/host_results_spec.rb
it "shows the host the reading view on the host page, above the Host section, with .result-group--reading (AC-2.1)"
it "puts one data-dislodged banner for each dislodged unit first in the section, the count equal to the Dislodged tags, groups with one first (AC-2.2)"
it "keeps the host's own seat page on the player version (AC-2.4)"
it "serves the host results page to the host only; a seat, a stranger and a junk cookie get the stranger response (AC-2.3)"
it "shows an earlier phase's Dislodged tags and no data-dislodged banner there (AC-2.6)"
it "shows the host no order of the open phase after a reveal (AC-2.5, spec 022 AC-7.5's assertions)"
```

Routes, controllers and views:

```ruby
# config/routes.rb, inside scope "games/:public_id" next to the phases routes
get "phases/:number/results", to: "results#show", as: :game_seat_results, constraints: { number: %r{[^/]+} }
get "host/phases/:number/results", to: "host_results#show", as: :game_host_results, constraints: { number: %r{[^/]+} }
```

```ruby
# app/controllers/results_controller.rb
# One revealed phase's results for a seat, the player version (spec 025 D4, D5). An open, later or unknown phase is the stranger
# response, and the header is set after that check, so the stranger response is the one everyone gets (D9).
class ResultsController < ApplicationController
  before_action :require_seat
  before_action :find_revealed_or_stranger
  before_action :no_store

  def show
    @results = PhaseResults.new(@phase)
  end

  private

  def find_revealed_or_stranger
    @phase = find_phase(@game)
    stranger!(@game) unless @phase && !@phase.open?
  end
end
# app/controllers/host_results_controller.rb: the same with `before_action :require_host`, and
#   @latest = @phase == @game.history.last
```

```erb
<%# results/show.html.erb %>
<% content_for :title, "Results" %>
<div class="stack">
  <h1>Results</h1>
  <%= render "results/section", results: @results, kind: :seat, game: @game, earlier: [], banners: false, skip: false %>
  <%= link_to "Your seat", game_path(@game.public_id), class: "button button--secondary" %>
</div>
<%# host_results/show.html.erb: the same with kind: :host, banners: @latest, and link_to "Host controls", game_host_path(...) %>
```

`require_seat` runs `send_to_step_in` for the host wearing a foreign seat cookie, so that viewer is sent to the confirmation (303) as on every seat route, which AC-5.2 says. `find_phase` is strict about the number. The results pages carry no live stream (D2).

Seat page and host page:

```ruby
# app/controllers/games_controller.rb, in show, after `@ordered = ...`
no_store # carries the orders of a revealed phase (spec 025 D9), set after the access checks above
latest = @game.history.last
@results = latest && PhaseResults.new(latest)
@earlier = @game.history.reorder(number: :desc).offset(1).to_a
# app/controllers/hosts_controller.rb
before_action :no_store # after require_host; replaces `no_store if @host_token`
# in show, replacing @dislodged:
latest = @history.last
@results = latest && PhaseResults.new(latest)
@earlier = @history.reverse.drop(1)
```

```erb
<%# app/views/games/show.html.erb: directly under the phase header; the Enter orders link gets an id %>
<%= render "results/section", results: @results, kind: :seat, game: @game, earlier: @earlier, banners: false, skip: true if @results %>
<%= link_to "Enter orders", game_seat_orders_path(@game.public_id, @phase.number), class: "button", id: "enter-orders" %>
<%# app/views/hosts/show.html.erb: the three-line banner loop (lines 6-9) is deleted; above the Host section: %>
<%= render "results/section", results: @results, kind: :host, game: @game, earlier: @earlier, banners: true, skip: false if @results %>
```

The edits to `hosts/show.html.erb` are exactly: the banner loop removed, one `render` of the section, and (Phase 5) one `render` of `results/_live`; nothing inside `[data-history]` or `step_ins/_history` changes (AC-6.3, a review check, since Issue #104 edits those). `spec/requests/host_spec.rb:28` ("not no-store without the token") is rewritten to "is always no-store"; the existing dislodged-banner examples in `reveal_post_spec.rb` keep their text and gain `data-dislodged`.

Classification, so the route table stays green in this phase (the full world-2 sweep is Phase 6):

```ruby
# spec/support/secrecy_routes.rb
Context = Struct.new(:id, :code, :host_token, :france_token, :open, :revealed, keyword_init: true) do
  def initialize(open: 1, revealed: nil, **rest) = super(open: open, revealed: revealed, **rest)
end
# two entries in APP (Phase 6 adds `revealed: :all` and `numbered: true` to them):
"GET /games/:public_id/phases/:number/results" => { shows: :none, sweep: ->(c) { "/games/#{c.id}/phases/#{c.open}/results" },
  why: "every power's orders of a revealed phase, to a seat; the open phase is the stranger page (spec 025)" },
"GET /games/:public_id/host/phases/:number/results" => { shows: :none, sweep: ->(c) { "/games/#{c.id}/host/phases/#{c.open}/results" },
  why: "the reading view of a revealed phase, to the host; the open phase is the stranger page (spec 025)" },
```

In world 1 the open phase is phase 1, so both sweep pages are the stranger page for every viewer, as AC-5.2 says. The old AC-7.9 example ("shows nobody an order or an outcome after the reveal", `order_secrecy_spec.rb:~322`) is rewritten to AC-5.7 now: after the reveal a stranger's pages and every page of a viewer with no right hold no `.result-row` and no `.outcome-tag`; the seat page of another seat and the host page hold them; its `england_phone.get orders -> 409` line stays until Phase 4. `reveal_post_spec.rb`'s `stub_result_with_dislodged_unit` is rewritten to call `revealed_phase_with(..., dislodged: [...])`, so its banner count equals its tag count (AC-9.2).

Run: `bundle exec rspec spec/requests`. Commit.

## Phase 4: A revealed phase's order screen and picker redirect to the results

**Implements:** D5. **Satisfies:** AC-3.2 (server half), AC-9.2 (the specs listed). **Files:** change `app/controllers/concerns/order_screen.rb`, `app/controllers/seat_orders_controller.rb`, `app/controllers/order_pickers_controller.rb`, `spec/requests/orders_spec.rb`, `spec/requests/order_pickers_spec.rb`, `spec/requests/reveal_post_spec.rb`, `spec/requests/order_secrecy_spec.rb`, `spec/system/phase_screens_spec.rb`.

Test first (the two existing GET examples are rewritten, each keeping its intent):

```ruby
# spec/requests/orders_spec.rb: replaces "gives the same page for a read, not the form"
it "sends a read of a revealed phase's orders to that phase's results, not the form (spec 025 D5)" do
  phone.get path
  expect(phone.response).to have_http_status(:see_other)
  expect(phone.response.headers["Location"]).to end_with("/games/#{id}/phases/1/results")
end
# spec/requests/order_pickers_spec.rb: replaces "gives the 409 page for a revealed phase (AC-2.13)": the same redirect, and it comes before the province check
#   (a province that is not the seat's unit also redirects once the phase is revealed)
# spec/requests/reveal_post_spec.rb:169: the final GET expects the 303; the PUT example above it still expects 409 and the sentence
# spec/requests/step_in_spec.rb:178 is NOT changed: the stepped-in GET of a revealed phase keeps the 409 (spec 025 D5)
# spec/requests/order_secrecy_spec.rb: the AC-5.7 example's `england_phone.get orders` expects the 303 to /phases/1/results instead of the 409
# spec/system/phase_screens_spec.rb:88: `visit ".../phases/1/orders"` now lands on the results page: expect h1 "Results" and the section
```

Implementation:

```ruby
# app/controllers/concerns/order_screen.rb
# A GET for a revealed phase's own orders URL is sent to the results of that phase (spec 025 D5). A stepped-in URL keeps the 409 page
# (spec 026 AC-3.8), and a PUT keeps it too.
def revealed_get
  return render_revealed if @stepped_in_page

  redirect_to game_seat_results_path(@game.public_id, @phase.number), status: :see_other
end
# SeatOrdersController#show and OrderPickersController#show: `return revealed_get unless @phase.open?` (the picker's line stays before the province lookup)
```

`own_orders_headers` already ran (no-store, no-referrer), so the 303 carries them like the 409 did. Run: `bundle exec rspec spec/requests spec/system/phase_screens_spec.rb`. Commit.

## Phase 5: The refresh broadcast and the pages that subscribe

**Implements:** D1, D2, D3, FR-4. **Satisfies:** AC-3.4, AC-3.5, AC-4.1 to AC-4.6, AC-9.2 (the 024 specs). **Files:** create `app/views/results/_live.html.erb`, `spec/models/results_broadcast_spec.rb`, `spec/models/results_payload_secrecy_spec.rb`; change `app/models/game.rb`, `app/models/phase.rb`, `app/views/games/show.html.erb`, `app/views/hosts/show.html.erb`, `app/views/seat_orders/show.html.erb`, `app/views/order_pickers/show.html.erb`, `spec/models/status_broadcast_scan_spec.rb`, `spec/requests/seat_status_pages_spec.rb`, `spec/requests/order_secrecy_spec.rb` (the signed-name example, rewritten here so this phase ends green), `spec/system/live_status_spec.rb` (waits for both sources by count), `spec/requests/reveal_post_spec.rb` (the request-id example).

Test first:

```ruby
# spec/models/results_broadcast_spec.rb
RSpec.describe "The results broadcast" do
  include RulesHelpers
  let(:game) { Game.start!(power: "england").game }
  let(:england) { game.seats.find_by(power: "england") }
  def raw(game) = ActionCable.server.pubsub.broadcasts("results:#{game.public_id}")

  it "sends nothing for saves, submits, edits and a reissue (AC-4.1)" do
    phase = game.current_phase
    england.save_orders!(phase, { "lon" => json_of(move(:england, :lon, :nth)) }, submit: true)
    england.save_orders!(phase, { "lon" => json_of(move(:england, :lon, :eng)) })
    game.reissue_seat!(england)
    expect(raw(game)).to be_empty
  end

  it "sends exactly one message when the reveal reveals, and none for a repeat or a refused reveal (AC-4.1)" do
    phase = game.current_phase
    phase.reveal!
    expect(raw(game).size).to eq(1)
    phase.reload.reveal! # :already
    expect(raw(game).size).to eq(1)

    other = Game.start!(power: "england").game
    allow(RulesEngine).to receive(:adjudicate).and_raise(RulesEngine::InvalidInput, "refused")
    expect { other.current_phase.reveal! }.to raise_error(RulesEngine::InvalidInput)
    expect(raw(other)).to be_empty
  end

  it "is exactly one attribute, no child and no text, and equal between a game with orders and one without (AC-4.2)" do
    quiet = Game.start!(power: "england").game
    busy = game
    busy.seats.find_by(power: "england").save_orders!(busy.current_phase, { "lon" => json_of(move(:england, :lon, :nth)) }, submit: true)
    [ quiet, busy ].each { |g| g.current_phase.reveal! }

    decoded = [ quiet, busy ].map { |g| JSON.parse(raw(g).first) }
    expect(decoded.uniq.size).to eq(1)
    fragment = Nokogiri::HTML5.fragment(decoded.first)
    element = fragment.children.first
    expect(fragment.children.size).to eq(1)
    expect(element.name).to eq("turbo-stream")
    expect(element.attributes.keys).to eq([ "action" ])
    expect(element["action"]).to eq("refresh")
    expect(element.children.to_a).to be_empty
  end

  it "keeps the reveal when the cable raises, and logs only the class (AC-4.5)" do
    allow(Turbo::StreamsChannel).to receive(:broadcast_refresh_to).and_raise(RuntimeError, "secret detail")
    allow(Rails.logger).to receive(:warn)
    game.current_phase.reveal!
    expect(game.phases.count).to eq(2)
    expect(game.history.count).to eq(1)
    expect(Rails.logger).to have_received(:warn).with("results broadcast failed: RuntimeError")
  end

  it "never reaches the status stream or another game's stream (AC-4.4)" do
    game.current_phase.reveal!
    expect(ActionCable.server.pubsub.broadcasts("seat_status:#{game.public_id}").map { |m| JSON.parse(m) }).to all(include("seat-status"))
    expect(raw(Game.start!(power: "england").game)).to be_empty
  end
end
```

```ruby
# spec/requests/reveal_post_spec.rb (added): the message is one attribute even when the reveal request carries a request id (AC-4.2),
# and the host's response is the same redirect as ever, also when the cable raises (AC-4.5)
it "sends a refresh with no request id although the reveal request carries one, and redirects as usual" do
  created.session.post reveal_path, headers: { "X-Turbo-Request-Id" => "11111111-2222-3333-4444-555555555555" }

  message = JSON.parse(ActionCable.server.pubsub.broadcasts("results:#{id}").first)
  expect(Nokogiri::HTML5.fragment(message).children.first.attributes.keys).to eq([ "action" ])
  expect(created.session.response).to redirect_to("/games/#{id}/host")
end

it "answers the same redirect when the cable raises, and stores the reveal (AC-4.5)" do
  allow(Turbo::StreamsChannel).to receive(:broadcast_refresh_to).and_raise(RuntimeError)
  created.session.post reveal_path

  expect(created.session.response).to redirect_to("/games/#{id}/host")
  expect(game.history.count).to eq(1)
end
```

```ruby
# spec/requests/order_secrecy_spec.rb: the signed-name example, rewritten (AC-3.4, AC-4.3, AC-4.5). Names are verified, never matched as text.
names = lambda do |body|
  Nokogiri::HTML5(body).css("turbo-cable-stream-source").map { |source| Turbo.signed_stream_verifier.verified(source["signed-stream-name"]) }
end
carrying = shot.flat_map { |viewer, routes| routes.filter_map { |key, (_s, body)| [ viewer, key, names.call(body).sort ] if names.call(body).any? } }
status = "seat_status:#{id}"
results = "results:#{id}"
# the seat page holds both names, the own order screen and the own picker only the results name. The host (Germany) has no unit in LON or PAR, so
# both pickers are its stranger page; France's [par] picker is the one picker that carries a name; the stepped-in host's pages carry none
expect(carrying).to match_array([
  [ "another seat", "GET /games/:public_id", [ results, status ].sort ],
  [ "another seat", "GET /games/:public_id/phases/:number/orders", [ results ] ],
  [ "another seat", "GET /games/:public_id/phases/:number/orders/:province [par]", [ results ] ],
  [ "the host, with a seat of its own", "GET /games/:public_id", [ results, status ].sort ],
  [ "the host, with a seat of its own", "GET /games/:public_id/host", [ results, status ].sort ],
  [ "the host, with a seat of its own", "GET /games/:public_id/phases/:number/orders", [ results ] ],
  [ "the host, with no seat", "GET /games/:public_id/host", [ results, status ].sort ],
  [ "the host, with France's seat cookie", "GET /games/:public_id/host", [ results, status ].sort ],
  [ "the host, stepped into France", "GET /games/:public_id/host", [ results, status ].sort ]
])
```

`live_status_spec.rb:43,72` and the other waits on `turbo-cable-stream-source[connected]` become `have_css("turbo-cable-stream-source[connected]", count: 2, visible: :all)` on the seat page and the host page. Scan-spec changes: the AC-2.7b/c examples allow the two method names, require `broadcast_results_refresh` to be named only in `game.rb` (its definition) and in `phase.rb`'s `reveal!` once, and cut both method definitions out of `game.rb` before checking nothing else there broadcasts; the control example list is unchanged (it already catches `broadcasts_to`, `broadcasts_refreshes` and `broadcast_refresh_to`) and gains `"Turbo::StreamsChannel.broadcast_refresh_to(:results, id)"` as a line that must match outside the two methods. `seat_status_pages_spec.rb`'s AC-4.1 example is rewritten to: the seat page and the host page each hold two sources, verified to `seat_status:<id>` and `results:<id>` (never by substring), and no other game's name; the order screen and the picker hold one (`results:<id>`).

Implementation:

```ruby
# app/models/game.rb, beside broadcast_seat_status
# Tells every open seat page, host page, order screen and picker that a phase was revealed, so each reloads itself through its own
# authorized request (spec 025 D1, D3). The message is a refresh with no content and no request id: it carries nothing about any order,
# and the pages' access checks decide what each phone then sees. Only Phase#reveal! calls it. A failed cable call never fails a reveal that
# has already been stored.
def broadcast_results_refresh
  Turbo::StreamsChannel.broadcast_refresh_to(:results, public_id, request_id: nil)
rescue StandardError => error
  Rails.logger.warn("results broadcast failed: #{error.class}")
end
# app/models/phase.rb, in reveal!
if status == :revealed # the new phase has no submissions (spec 024 D3), and every phone reloads (spec 025 D3)
  game.broadcast_seat_status
  game.broadcast_results_refresh
end
```

```erb
<%# results/_live.html.erb: the stream source and the morphed refresh (spec 025 D1, D2). locals: game %>
<% turbo_refreshes_with method: :morph, scroll: :preserve %>
<%= turbo_stream_from :results, game.public_id %>
```

`render "results/live", game: @game` goes in `games/show.html.erb`, `hosts/show.html.erb`, and, as `render "results/live", game: @game unless @stepped_in_page`, in `seat_orders/show.html.erb` and `order_pickers/show.html.erb`. Run: `bundle exec rspec spec/models spec/requests spec/channels spec/system/live_status_spec.rb`. Commit.

## Phase 6: Secrecy classification and the sweep in two worlds

**Implements:** FR-5, D4. **Satisfies:** AC-5.1 to AC-5.7, AC-4.3 and AC-4.5 (the response scan in the second world). **Files:** change `spec/support/secrecy_routes.rb`, `spec/requests/order_secrecy_spec.rb`; create `spec/models/results_boundary_spec.rb`.

Test first (these fail until the classification and the sweep support exist):

```ruby
# spec/requests/order_secrecy_spec.rb (added, in "the route table")
it "marks exactly the seat page, the host page and the two results routes as able to show a revealed phase's orders (AC-5.1)" do
  all = SecrecyRoutes::APP.select { |_key, entry| entry[:revealed] == :all }.keys
  expect(all).to match_array([ "GET /games/:public_id", "GET /games/:public_id/host",
                               "GET /games/:public_id/phases/:number/results", "GET /games/:public_id/host/phases/:number/results" ])
  expect(SecrecyRoutes::APP.reject { |_key, entry| %i[all none].include?(entry[:revealed]) }.keys).to be_empty # every entry says
end

# spec/models/results_boundary_spec.rb (AC-5.6)
RSpec.describe "The results code stays away from saved orders" do
  it "names neither SavedOrder, saved_orders nor orders_for" do
    files = %w[app/models/phase_results.rb app/helpers/outcome_helper.rb app/controllers/results_controller.rb app/controllers/host_results_controller.rb] +
            Dir[Rails.root.join("app/views/{results,host_results}/*").to_s].map { |path| path.delete_prefix("#{Rails.root}/") }
    expect(files.size).to be > 8
    files.each { |path| expect(File.read(Rails.root.join(path))).not_to match(/SavedOrder|saved_orders|orders_for/), path }
  end
end
```

Classification. A script adds `revealed: :none,` after `shows: ...,` on every entry of `APP` that is not one of the four; the four get `revealed: :all`. Every entry whose path carries a phase number gets `numbered: true` (orders, picker, the two stepped-in routes, the step-in confirmation, the reveal confirmation, the two results routes). `sweeps` requests those a second time with the revealed number when the context has one:

```ruby
# spec/support/secrecy_routes.rb
def self.sweeps(context)
  passes = [ [ context, "" ] ]
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
```

The existing numbered entries replace the literal `1` by `#{c.open}`; in world 1 `revealed` is nil, so no label and no expectation changes. `MOUNT /cable`'s `why` names both streams.

The outer `viewers` changes in two places only: the stepped-in session posts `phases/#{open_number}/step-in` (a new outer `let(:open_number) { 1 }`), and the second half of the existing "answers the same whether England has submitted or not" example, from `outside = lambda ...` to the end, moves unchanged into a method `only_status_row_differs(listed, unsubmitted, submitted)` that both worlds call.

World 2:

```ruby
describe "after one reveal (spec 025 Story 5)" do
  let(:open_number) { 2 }
  # Phase 1: England lvp -> yor and France mar -> pie (both uncontested and successful under the stand-in), then the host reveals. The
  # swept picker provinces lon and par stay occupied and England keeps fleets in lon and edi and an army in yor, so no swept page
  # silently becomes a stranger page. `phase` is not touched here: it is memoised later, after the reveal, as phase 2.
  let!(:revealed_phase) do
    first = game.current_phase
    england_seat.save_orders!(first, { "lvp" => json_of(move(:england, :lvp, :yor)) }, submit: true)
    france_seat_and_token.first.save_orders!(first, { "mar" => json_of(move(:france, :mar, :pie)) }, submit: true)
    created.session.post "/games/#{id}/host/phases/1/reveal"
    first.reload
  end
  let(:context) do
    SecrecyRoutes::Context.new(id: id, code: game.join_code, host_token: created.host_token, france_token: france_seat_and_token.last, open: 2, revealed: 1)
  end

  # England's phase-2 orders: moves only (a hold is a word every implied hold in the results shares), each a legal order whose words
  # appear in no phase-1 order.
  ORDERS2 = { none: {}, one: { "lon" => %i[lon nth] },
              all: { "lon" => %i[lon nth], "edi" => %i[edi nwg], "yor" => %i[yor lvp] },
              other: { "lon" => %i[lon eng], "edi" => %i[edi nth], "yor" => %i[yor edi] } }.freeze
  WORDS2 = [ "Move to North Sea (NTH)", "Move to Norwegian Sea (NWG)", "Move to Liverpool (LVP)", "Move to English Channel (ENG)", "Move to Edinburgh (EDI)" ].freeze

  def set_orders2(name, submit: false)
    entries = %w[lon edi yor].to_h { |province| [ province, ORDERS2[name][province] ? json_of(move(:england, *ORDERS2[name][province])) : "" ] }
    england_seat.save_orders!(phase, entries)
    england_seat.save_orders!(phase, {}, submit: true) if submit
  end

  def stream_names(body) = Nokogiri::HTML5(body).css("turbo-cable-stream-source").map { |s| Turbo.signed_stream_verifier.verified(s["signed-stream-name"]) }

  let(:hosts) { [ "the host, with a seat of its own", "the host, with no seat", "the host, with France's seat cookie", "the host, stepped into France" ] }

  it "answers every viewer but England the same whatever England orders in the open phase (AC-5.3)" do
    set_orders2(:none)
    baseline = snapshot
    expect(baseline.values.flat_map(&:keys).uniq.size).to eq(SecrecyRoutes.sweeps(context).size)
    expect(SecrecyRoutes.sweeps(context).keys.grep(/\(revealed\)/)).not_to be_empty # the revealed number is requested too

    %i[one all other none].each do |name|
      set_orders2(name)
      changed = differences(baseline, snapshot)
      expect(changed).to be_empty, "the pages changed when England's phase-2 orders became #{name}: #{changed.join('; ')}"
    end
  end

  it "differs, when England's submitted state flips, only in England's status row and the open number's reveal confirmation (AC-5.3)" do
    set_orders2(:all)
    unsubmitted = snapshot
    set_orders2(:all, submit: true)
    submitted = snapshot
    confirm = "GET /games/:public_id/host/phases/:number/reveal"
    listed = unsubmitted.flat_map do |viewer, routes|
      routes.select { |key, response| [ "GET /games/:public_id", "GET /games/:public_id/host" ].include?(key) && response[1].include?('id="seat-status"') }.keys.map { |key| [ viewer, key ] }
    end
    expect(listed).to include([ "another seat", "GET /games/:public_id" ], [ hosts[0], "GET /games/:public_id/host" ])
    expect(differences(unsubmitted, submitted, except: hosts.map { |host| [ host, confirm ] } + listed)).to be_empty
    only_status_row_differs(listed, unsubmitted, submitted)
  end

  it "gives each viewer the answers of D4 and spec 026 D5, with controls (AC-5.4)" do
    set_orders2(:none)
    shot = snapshot
    status = ->(viewer, label) { shot.fetch(viewer).fetch(label).first }
    seat_results = "GET /games/:public_id/phases/:number/results"
    host_results = "GET /games/:public_id/host/phases/:number/results"
    orders = "GET /games/:public_id/phases/:number/orders"
    picker = "GET /games/:public_id/phases/:number/orders/:province"
    stepped = "GET /games/:public_id/host/seats/:power/phases/:number/orders"

    expect(status.("another seat", "#{seat_results} (revealed)")).to eq(200)
    expect(status.(hosts[0], "#{seat_results} (revealed)")).to eq(200)
    expect(status.(hosts[1], "#{seat_results} (revealed)")).to eq(404)         # the host with no seat holds no seat cookie
    expect(status.(hosts[2], "#{seat_results} (revealed)")).to eq(303)         # sent to the step-in confirmation (spec 026 D5)
    expect(status.("a stranger", "#{seat_results} (revealed)")).to eq(404)
    # The open number has no results page for anyone: the stranger page, or for the host wearing France's seat cookie the step-in redirect.
    [ "another seat", hosts[0], hosts[1], hosts[3], "a stranger" ].each { |viewer| expect(status.(viewer, seat_results)).to eq(404), viewer }
    expect(status.(hosts[2], seat_results)).to eq(303)
    hosts.each { |host| expect(status.(host, "#{host_results} (revealed)")).to eq(200), host }
    [ "another seat", "a stranger" ].each { |viewer| expect(status.(viewer, "#{host_results} (revealed)")).to eq(404), viewer }
    hosts.each { |host| expect(status.(host, host_results)).to eq(404), host } # the open number, the host included: no results page exists for it
    [ "another seat", "a stranger" ].each { |viewer| expect(status.(viewer, host_results)).to eq(404), viewer }
    expect(status.("another seat", orders)).to eq(200)                         # the open phase is the live order screen
    expect(status.("another seat", "#{orders} (revealed)")).to eq(303)         # the revealed one is sent to its results
    expect(status.("another seat", "#{picker} [par]")).to eq(200)              # Paris is still French in phase 2
    expect(status.("another seat", "#{picker} [par] (revealed)")).to eq(303)
    expect(status.(hosts[3], "#{stepped} [france]")).to eq(200)
    expect(status.(hosts[3], "#{stepped} [france] (revealed)")).to eq(409)     # the one GET that keeps the 409
    expect(status.(hosts[3], "#{stepped} [england]")).to eq(404)
    [ hosts[0], hosts[1], "another seat", "a stranger" ].each { |viewer| expect(status.(viewer, "#{stepped} [france]")).to eq(404), viewer }
  end

  it "puts England's phase-1 order in the results and none of its phase-2 orders in any other viewer's rows or pages (AC-5.5)" do
    json = ORDERS2.values_at(:all, :other).flat_map(&:values).map { |at, to| ERB::Util.html_escape(json_of(move(:england, at, to))) }
    [ :all, :other ].each do |name|
      set_orders2(name)
      shot = snapshot
      results = Nokogiri::HTML5(shot.fetch("another seat").fetch("GET /games/:public_id/phases/:number/results (revealed)")[1])
      expect(results.css(".result-row__order").map { |node| node.text.squish }).to include("Move to Yorkshire (YOR)") # the positive control
      shot.each do |viewer, routes|
        routes.each do |label, (_status, body)|
          page = Nokogiri::HTML5(body)
          expect(page.css(".result-row__order, .unit-row__order").map { |node| node.text.squish } & WORDS2).to be_empty, "#{viewer} on #{label}"
          json.each { |text| expect(body).not_to include(text), "#{viewer} on #{label}" }
        end
      end
    end
  end

  it "shows a stranger no result and puts a signed name only on the four pages of AC-3.4 (AC-4.3, AC-4.5)" do
    set_orders2(:none)
    shot = snapshot
    stranger = shot.fetch("a stranger").values.map { |_s, body| body }
    expect(stranger.grep(/result-row|outcome-tag/)).to be_empty
    carrying = shot.flat_map { |viewer, routes| routes.filter_map { |label, (_s, body)| [ viewer, label ] if stream_names(body).any? } }
    allowed = [ "GET /games/:public_id", "GET /games/:public_id/host", "GET /games/:public_id/phases/:number/orders", "GET /games/:public_id/phases/:number/orders/:province [par]" ]

    expect(carrying.map(&:last).uniq - allowed).to be_empty
    expect(carrying.select { |viewer, _| viewer == "a stranger" }).to be_empty
    expect(shot.values.flat_map(&:values).flat_map { |_s, body| stream_names(body) }.uniq).to contain_exactly("seat_status:#{id}", "results:#{id}")
  end
end
```

The old "shows nobody an order or an outcome after the reveal" example was rewritten in Phase 3 to AC-5.7; this phase's world 2 is the full proof.

Run: `bundle exec rspec spec/requests/order_secrecy_spec.rb spec/models/saved_order_boundary_spec.rb spec/models/seat_write_scan_spec.rb spec/models/results_boundary_spec.rb`. Commit.

## Phase 7: Two real browsers

**Implements:** Stories 3 and 8's browser checks. **Satisfies:** AC-3.1, AC-3.2, AC-3.3, AC-2.1 (size), AC-8.4, AC-1.9 (target size). **Files:** create `spec/system/reveal_results_spec.rb`.

Test (it is the first thing run in this phase; Phases 1 to 6 are what make it pass):

```ruby
# spec/system/reveal_results_spec.rb, modelled on spec/system/live_status_spec.rb
require "rails_helper"
require_relative "../support/results_fixtures"

RSpec.describe "Revealing results to every phone", type: :system do
  include ResultsFixtures

  def screenshot(name) = (dir = ENV["SCREENSHOTS"]) && page.save_screenshot(File.join(dir, "#{name}.png"))

  # Waits for every stream source this page has to be subscribed: Turbo sets [connected] once the socket confirms.
  def connected(count) = expect(page).to have_css("turbo-cable-stream-source[connected]", count: count, visible: :all, wait: 5)

  def measure(label) # as live_status_spec does: nothing scrolls sideways, no control under 44 by 44
    widths = evaluate_script("({ scroll: document.documentElement.scrollWidth, client: document.documentElement.clientWidth })")
    expect(widths["scroll"]).to be <= widths["client"], "#{label} scrolls sideways at 360"
    small = evaluate_script(<<~JS)
      Array.from(document.querySelectorAll(":is(main, .app-actions) :is(a:not(p a), button, input:not([type=hidden]))")).filter((el) => {
        const r = el.getBoundingClientRect(); return r.width < 43.5 || r.height < 43.5;
      }).map((el) => el.className || el.tagName)
    JS
    expect(small).to be_empty, "#{label}: controls under 44 by 44: #{small.join(', ')}"
  end

  def font_px(selector) = evaluate_script("parseFloat(getComputedStyle(document.querySelector('#{selector}')).fontSize)")

  let(:started) { Game.start!(power: "germany") }
  let(:game) { started.game }
  let(:id) { game.public_id }
  let!(:england) { game.take_seat!("england") }
  let!(:france) { game.take_seat!("france") }

  before { england.first.save_orders!(game.current_phase, { "lon" => json_of(move(:england, :lon, :nth)) }, submit: true) }

  # The host's own phone, a session with no stream of its own to wait on, reveals through the real confirmation page.
  def host_reveals
    Capybara.using_session(:revealer) do
      with_viewport(360) do
        visit "/games/#{id}/host-link?token=#{started.host_token}"
        click_on "Reveal orders"
        click_button "Reveal orders"
        expect(page).to have_css(".banner--info", text: "was revealed")
      end
    end
  end

  it "moves a second phone and a phone on the order screen to the results when the host reveals (AC-3.1, AC-3.2)" do
    with_viewport(360) do
      visit "/games/#{id}/seat-link?token=#{england.last}"
      visit "/games/#{id}/phases/1/orders"
      connected(1) # the order screen holds the results source only
      Capybara.using_session(:france) do
        with_viewport(360) do
          visit "/games/#{id}/seat-link?token=#{france.last}"
          visit "/games/#{id}"
          connected(2) # the status source and the results source
          expect(page).not_to have_css("section[data-results]")
          host_reveals

          expect(page).to have_css("section[data-results] .result-row", text: "Move to North Sea (NTH)", wait: 5)
          expect(page).to have_css(".phase-header", text: "Fall 1901") # the half-stale header of spec 024 is gone
          expect(page).to have_link("Skip to orders")
          expect(font_px(".result-group")).to be <= 16.5
          measure("France's seat page after the reveal")
          screenshot("01-seat-page-after-reveal")
        end
      end
      expect(page).to have_current_path("/games/#{id}/phases/1/results", wait: 5) # the order screen's refresh met the 303
      expect(page).to have_css("section[data-results] .result-row", text: "Move to North Sea (NTH)")
      measure("England's results page")
      screenshot("02-results-page")
    end
  end

  it "keeps the revealing browser's banner and shows the host the reading view (AC-3.3, AC-2.1)" do
    with_viewport(360) do
      visit "/games/#{id}/host-link?token=#{started.host_token}"
      visit "/games/#{id}/host"
      connected(2)
      click_on "Reveal orders"
      click_button "Reveal orders"
      expect(page).to have_css(".banner--info", text: "was revealed")
      sleep 2 # a real wait: a refresh, had one reached this page, would have landed within it
      expect(page).to have_css(".banner--info", text: "was revealed")
      expect(page).to have_current_path("/games/#{id}/host")
      expect(page).to have_css("section[data-results] .result-group--reading")
      expect(font_px(".result-group--reading")).to be >= 19
      measure("the host page after the reveal")
      screenshot("03-host-page-after-reveal")
    end
  end

  it "still shows the Submitted banner at the top after a submit on a morphing order screen (a side effect of the morph, checked at 360)" do
    with_viewport(360) do
      visit "/games/#{id}/seat-link?token=#{france.last}"
      visit "/games/#{id}/phases/1/orders"
      click_on "Submit orders"
      expect(page).to have_css(".banner--info", text: "Submitted.")
      expect(evaluate_script("document.querySelector('.banner--info').getBoundingClientRect().top >= 0")).to be(true)
    end
  end

  it "writes 360-pixel screenshots of a reveal with a mix of outcomes, a dislodged row and the practice note, only when SCREENSHOTS is set (AC-8.4)" do
    other = Game.start!(power: "england")
    hold = ->(power, at) { { "format" => 1, "type" => "hold", "power" => power, "at" => at } }
    mover = ->(power, at, to) { { "format" => 1, "type" => "move", "power" => power, "at" => at, "destination" => { "province" => to, "coast" => nil } } }
    revealed_phase_with(other.game, dislodged: [ %w[england fleet lon] ], outcomes: [
      [ mover.("england", "edi", "nth"), :succeeded, true, false ], [ mover.("england", "lvp", "yor"), :bounced, true, false ],
      [ hold.("england", "lon"), :held, true, true ], [ mover.("france", "par", "bur"), :succeeded, true, false ],
      [ hold.("france", "bre"), :held, false, false ] ])
    with_viewport(360) do
      visit "/games/#{other.game.public_id}/host-link?token=#{other.host_token}"
      visit "/games/#{other.game.public_id}/host"
      expect(page).to have_css("[data-dislodged]", count: 1)
      screenshot("04-host-reading-view-mix")
      visit "/games/#{other.game.public_id}"
      expect(page).to have_css(".outcome-tag--dislodged")
      expect(page).to have_css(".practice-note")
      screenshot("05-seat-page-mix")
      visit "/games/#{other.game.public_id}/phases/1/results"
      measure("a results page with a dislodged row")
      screenshot("06-results-page-mix")
    end
  end
end
```

Run: `bundle exec rspec spec/system`. Screenshots for the pull request: `SCREENSHOTS=<dir> bundle exec rspec spec/system/reveal_results_spec.rb`. Commit.

## Phase 8: Earlier specs, docs and the final proof

**Implements:** AC-9.1, AC-9.2. **Files:** change `docs/specs/022-phase-lifecycle/spec.md`, `docs/specs/023-order-pickers/spec.md`, `docs/specs/024-live-status/spec.md` (all under `web/`), `spec/docs/spec_amendments_spec.rb`, `README.md` (a short paragraph, if the README has a section on the status stream: the results stream and what a refresh carries); `docs/design-system.md` is done in Phase 2.

Test first:

```ruby
# spec/docs/spec_amendments_spec.rb (added)
it "records spec 025's changes to spec 022 in a 1.5.0 changelog row (spec 025 AC-9.1)" do
  row = File.read(".../022-phase-lifecycle/spec.md").lines.find { |l| l.start_with?("| 1.5.0 |") }
  expect(row).to include("AC-6.3").and include("AC-7.9").and include("FR-9").and include("spec 025")
end
# and the same for 023 (a row naming AC-2.13) and 024 (a row naming AC-2.7, AC-4.1, AC-4.5 and the "half stale" limit)
```

Then the changelog rows are written: 022 1.5.0 (AC-6.3 and FR-6 read as a 303 to the results for a `GET`, the `PUT` unchanged; AC-7.9 replaced by spec 025 Story 5; FR-9's table gains the two routes and the seat and host pages' results; the half-stale limit closed), 023 (AC-2.13 for a `GET`), 024 (AC-2.7 allows `broadcast_results_refresh`; AC-4.1 reads "one status source and one results source"; AC-4.5 reads "the status name only..."; the Known limits' "half stale" is closed by spec 025).

Final proof, from `web/`:

```sh
bundle exec rspec                       # the whole suite, system specs included; record the counts
bin/rubocop
bin/brakeman -q
git diff --name-only main...HEAD        # only paths under web/
wc -c app/assets/stylesheets/*.css      # recorded in the pull request
```

Then the implementation review (an Opus subagent, read-only), the session wrap, the push (a draft pull request following `.github/pull_request_template.md`, "Closes #25"), screenshots at 360 pixels attached, the `Web specs` job green, `gh pr ready`, `gh pr edit --add-assignee @me`, and `worker_done`. When the coordinator says `main` moved (Issue #104 edits `hosts/show.html.erb` and `step_ins/_history.html.erb`), merge `origin/main` keeping both sides.

## Spec coverage

| Spec | Phase |
|---|---|
| FR-1 | 1 |
| FR-2 | 2 |
| FR-3 | 3 (pages), 5 (`_live`) |
| FR-4 | 5 |
| FR-5 | 6 |
| Story 1 (AC-1.1 to 1.9) | 1 (1.3 to 1.6 data), 2 (markup), 3 (pages); AC-1.1 is the first test |
| Story 2 (AC-2.1 to 2.6) | 3; 2.1's size in 7 |
| Story 3 (AC-3.1 to 3.5) | 3.1 to 3.3 in 7, 3.2 server half in 4, 3.4 and 3.5 in 5 |
| Story 4 (AC-4.1 to 4.6) | 5; 4.3's response scan in 6 |
| Story 5 (AC-5.1 to 5.7) | 6 |
| Story 6 (AC-6.1 to 6.3) | 3 |
| Story 7 (AC-7.1 to 7.4) | 2 (7.1 partial, 7.3), 1 (7.2), 3 (7.1 pages, 7.4) |
| Story 8 (AC-8.1 to 8.4) | 2 (8.1 to 8.3), 7 (8.4) |
| Story 9 (AC-9.1, 9.2) | 3 to 6 rewrite the specs as they change, 8 the changelogs |

## Changelog

| Version | Date | Change |
|---|---|---|
| 1.3.0 | 2026-11-26 | Spec 025 1.3.0 (#112): the host page no longer draws "Earlier results"; its earlier phases are reveal rows of the one History list. Phase 3's host half of AC-6.1 and AC-6.3 are read as spec 026 D11 says; the plan for the change is in `026-step-in/plan.md`, "Amendment 1.3.0" |
| 1.2.0 | 2026-11-26 | Recorded while executing (no change of design). Sizes after Phase 2 (AC-8.3): `components.css` 15,309 to 16,690 bytes, total 27,019 to 28,400 of 32,768, `styleguide.css` unchanged at 3,716 of 6,144. The two confirmation pages (reveal and step-in) are not re-requested for the revealed number in the sweep: each answers a revealed phase with a redirect and a flash banner that the next request would show, so a sweep cannot compare them; spec 022 AC-4.11 and spec 026 AC-1.7 test those redirects. `reveal_post_spec.rb`'s dislodged fixture is kept hand-built (it drives the real reveal through a stubbed `adjudicate`) but now sets the position and the outcome's flag together and asserts the banner count equals the tag count. After the Opus implementation review (11 non-blocking findings, all taken): the sweep's first world asserts the results routes' statuses, the host's stranger page is compared byte for byte, the system spec shows a host tab and a picker phone switching and measures the refusal page, the fixture's implied holds are in province order, the page the two key orders draw is compared, the payload fixture has three seats ordering |
| 1.1.0 | 2026-11-26 | After the Opus plan review (5 blocking, 9 non-blocking, all taken): `.outcome-tag` takes `.mono` and no `font-family` (the font spec allows one reader of the token); the two results routes are classified, and the old AC-7.9 example rewritten, in Phase 3, the 303 line in Phase 4 and the signed-name example in Phase 5, so every commit ends green; world 2 gives France `mar -> pie` (Paris stays French), uses legal phase-2 orders, a `numbered` flag instead of per-entry revealed sweeps, and full example bodies; the rendered examples for AC-1.3, AC-1.4, AC-7.3 and AC-4.5, the AC-7.2 body, the system spec bodies and the first test's absolute require are written out; the `reveal_post_spec` dislodged fixture moves to the one builder; live-status waits count both sources; the morph side effect on a submit is checked at 360 pixels. `main` (with #104) merged in |
| 1.0.0 | 2026-11-26 | First plan, for Gate B |

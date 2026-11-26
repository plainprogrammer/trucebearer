# Plan 029: Upgrade to adjudicator-v0.2.0 and retire the stand-in

**Spec:** `web/docs/specs/029-gem-0.2.0/spec.md` (1.0.1, Approved). **Issue:** #29. **Branch:** `web/29-gem-0.2.0`.

## Goal

Move the pin to `adjudicator-v0.2.0`, answer `RulesEngine.adjudicate` and `RulesEngine.load_adjudication` with the gem, delete the stand-in, `RulesEngine.stand_in?` and the practice note, and prove the dislodged banners and the paradox warning on real gem output. The suite is green against the real engine at every commit that ends a phase.

The first test written (spec Story 2, AC-2.1) is `spec/models/phase_reveal_real_engine_spec.rb`: Germany moves Munich to Burgundy with support from Ruhr against France's army holding in Burgundy, and the stored result must dislodge France's army. It fails against the stand-in, which never dislodges.

## Gates checked

- **Simplicity.** One boundary file changes in substance. Everything else is deletion, a one-line pin, a guard, specs and docs. No new class, no new dependency, no new file under `app/`.
- **Anti-abstraction.** No wrapper, flag or adapter chooses between engines. `RulesEngine.adjudicate` calls the gem and nothing else.
- **Integration-first.** The reveal path (`Phase#reveal!` to `RulesObjectType` to the results pages) already exists and is unchanged. Phase 1 proves it against the real engine before any deletion.
- **One side.** Every path below is under `web/`. `git diff --name-only main...HEAD` must list only `web/` paths.
- **Names and words.** No new name contains or echoes the game's trademarked name or its three-letter prefix. No DATC text is copied: the two DATC positions are written as units and orders, with section numbers cited. A spec file may not write the bare token `TA` (the boundary spec scans `spec/`), not even in a comment or an example name.

## Decisions the plan adds (each traceable to the spec)

- **P1. Order of work.** New specs first, red against the stand-in (Phase 1); then the swap (Phase 2); then the deletions, with the guard written first (Phase 3); then the amendments (Phase 4); then screenshots and the full proof (Phase 5). Phase 1 ends red on purpose and is not committed alone as green: its commit is "Add the specs the real engine must pass". Each later phase ends green.
- **P2. The set-up helper** `reveal_position!` goes in `spec/support/results_fixtures.rb` (spec D4, D6). It sets the open phase's position from units, saves each power's orders through its seat (taking the seat when the game has none), and calls `Phase#reveal!`. The two specs that need a real position through `reveal!` share it (AC-2.1, and AC-4.1 with AC-4.2). The rewritten `reveal_post_spec.rb` examples set their own position and orders in `save_dislodging_orders`, because the host must reveal through the POST request.
- **P3. Characterization specs.** AC-4.1 and AC-4.2 describe what the existing views do with real output, so they may already pass once the engine is swapped. They are still written first and run red against the stand-in (it never dislodges and never sets `paradox`), which is their failing evidence.
- **P4. The `stand_in?` method stays until Phase 3**, so the views keep rendering during Phase 2. Phase 3 deletes the method, the partial and the views' use together.

## File map

| File | Change | Phase |
|---|---|---|
| `spec/support/results_fixtures.rb` | add `reveal_position!` | 1 |
| `spec/models/phase_reveal_real_engine_spec.rb` | new (AC-2.1, AC-2.2) | 1 |
| `spec/models/rules_engine_adjudicate_spec.rb` | new (AC-2.3 to AC-2.5); AC-3.2's example added in Phase 3 | 1, 3 |
| `spec/requests/real_results_spec.rb` | new (AC-4.1, AC-4.2) | 1 |
| `spec/requests/reveal_post_spec.rb` | dislodged-units examples on a real position (AC-3.5) | 1 |
| `spec/config/gemfile_pin_spec.rb`, `Gemfile`, `Gemfile.lock` | the tag (AC-1.1, AC-1.2) | 2 |
| `app/models/rules_engine.rb` | the swap (D1); the stand-in block removed | 2, 3 |
| `spec/models/rules_engine_stand_in_spec.rb` | deleted | 2 |
| `spec/models/rules_engine_boundary_spec.rb` | the two new guards (AC-3.1, AC-3.5) | 3 |
| `spec/requests/results_spec.rb`, `spec/views/results_partials_spec.rb`, `spec/requests/styleguide_spec.rb`, `spec/system/reveal_results_spec.rb` | the note is gone (AC-3.3, AC-3.4) | 3 |
| `app/views/results/_practice_note.html.erb` (deleted), `app/views/results/_section.html.erb`, `app/views/styleguide/show.html.erb` | D3 | 3 |
| `AGENTS.md` (web), `docs/design-system.md` | wording | 3 |
| `spec/models/rules_engine_next_phase_spec.rb`, `spec/requests/order_secrecy_spec.rb` | "stand-in" names and comments | 3 |
| `docs/specs/019-…/spec.md`, `022-…/spec.md`, `025-…/spec.md`, `spec/docs/spec_amendments_spec.rb` | AC-5.1 to AC-5.4 | 4 |
| `docs/specs/025-reveal-results/screens/*.png` | regenerated | 5 |

`PhaseResults`, `OutcomeHelper`, `Phase`, `RulesObjectType`, the results controllers and the stylesheets are not edited (AC-4.3).

---

## Phase 1: The specs the real engine must pass (red against the stand-in)

**Implements:** FR-1, FR-2. **Satisfies:** AC-2.1 to AC-2.5, AC-3.5 (the stub half), AC-4.1, AC-4.2. **Files:** the five in the file map for Phase 1.

### The helper

```ruby
# spec/support/results_fixtures.rb, added inside module ResultsFixtures
# Reveals a phase from a position and orders, the way the host would (spec 029 D4): the open phase's position is set from
# units ([[power, type, province], ...]), each power's orders are saved through its seat (the seat is taken when the game has
# none), and Phase#reveal! adjudicates them. orders: [[type, power, at, {extra fields}], ...]. Returns the revealed phase.
def reveal_position!(game, units:, orders:)
  phase = game.current_phase
  phase.update_columns(position: rules_position(units: units))
  phase.reload
  orders.map { |type, power, at, rest| rules_order(type, power, at, **(rest || {})) }
        .group_by { |order| order.to_h["power"] }.each do |power, list|
    seat = game.seats.find_by(power: power) || game.take_seat!(power).first
    seat.save_orders!(phase, list.to_h { |order| [ order.to_h["at"], json_of(order) ] }, submit: true)
  end
  phase.reveal!
  phase.reload
end
```

### The first test (AC-2.1, AC-2.2)

```ruby
# spec/models/phase_reveal_real_engine_spec.rb
require "rails_helper"
require_relative "../support/results_fixtures"

# Spec 029 AC-2.1, AC-2.2: a reveal applies the rules. A supported attack dislodges a holding unit.
RSpec.describe Phase, "#reveal! with the real engine" do
  include ResultsFixtures

  let(:game) { Game.start!(power: "germany").game }
  let(:revealed) do
    reveal_position!(game, units: [ %i[germany army mun], %i[germany army ruh], %i[france army bur] ],
                           orders: [ [ :move, :germany, :mun, { destination: { "province" => "bur", "coast" => nil } } ],
                                     [ :support_move, :germany, :ruh, { from: "mun", to: "bur" } ],
                                     [ :hold, :france, :bur ] ])
  end

  def outcome(power, province) = revealed.adjudication.to_h["outcomes"].find { |o| o["order"]["power"] == power && o["order"]["at"] == province }

  it "dislodges France's army in Burgundy, and says so in the stored result (AC-2.1)" do
    expect(outcome("germany", "mun")["result"]).to eq("succeeded")
    expect(outcome("germany", "ruh")["result"]).to eq("given")
    expect(outcome("france", "bur")).to include("result" => "held", "dislodged" => true)
    position = revealed.adjudication.to_h["position"]
    expect(position["dislodged_units"]).to eq([ { "unit" => unit_hash(:france, :army, :bur), "attacker_from" => "mun", "by_convoy" => false } ])
  end

  it "opens the next phase with Germany in Burgundy and no French unit there (AC-2.1)" do
    revealed
    units = game.current_phase.position.to_h["units"].map { |u| [ u["power"], u.dig("location", "province") ] }
    expect(units).to include([ "germany", "bur" ])
    expect(units).not_to include([ "france", "bur" ])
  end

  it "stores the gem's documented hash form, which loads back to an equal result (AC-2.2)" do
    raw = Phase.connection.select_value("SELECT adjudication FROM phases WHERE id = #{revealed.id}")
    expect(JSON.parse(raw)).to include("format" => 1).and include("outcomes", "paradox", "position")
    expect(Phase.find(revealed.id).adjudication).to eq(revealed.adjudication)
    expect(RulesEngine.load_adjudication(JSON.parse(raw))).to eq(revealed.adjudication)
  end
end
```

`ResultsFixtures` includes `RulesHelpers`, so `rules_position`, `rules_order`, `json_of` and `unit_hash` are in scope.

### The wiring spec (AC-2.3 to AC-2.5, AC-3.2)

```ruby
# spec/models/rules_engine_adjudicate_spec.rb
require "rails_helper"
require_relative "../support/rules_helpers"

# Spec 029: RulesEngine.adjudicate and load_adjudication answer with the gem. It replaces the stand-in's spec.
RSpec.describe "RulesEngine.adjudicate and load_adjudication" do
  include RulesHelpers

  let(:start) { RulesEngine.starting_position }
  let(:result) { RulesEngine.adjudicate(start, [ move(:england, :lon, :nth) ]) }

  describe "load_adjudication (AC-2.3)" do
    it "returns an object as it is, builds one from its hash form, and passes nil" do
      expect(RulesEngine.load_adjudication(result)).to equal(result)
      expect(RulesEngine.load_adjudication(result.to_h)).to eq(result)
      expect(RulesEngine.load_adjudication(nil)).to be_nil
    end

    it "raises InvalidInput for what the gem refuses" do
      good = result.to_h
      void = RulesEngine.adjudicate(start, [ rules_order(:hold, :france, :lon) ]).to_h # England's London: a void order
      void["outcomes"].first["dislodged"] = true # a void order can't be dislodged: an impossible object
      bad = [ good.merge("format" => 2), good.except("format"), good.merge("extra" => 1), good.except("paradox"),
              good.merge("outcomes" => [ good["outcomes"].first.merge("result" => "bogus") ]), void, 42, "x", [] ]
      bad.each { |value| expect { RulesEngine.load_adjudication(value) }.to raise_error(RulesEngine::InvalidInput), value.inspect[0, 60] }
    end
  end

  describe "adjudicate (AC-2.4, AC-2.5)" do
    it "gives the documented result for a legal move" do
      expect(result.outcomes.first.result).to eq(:succeeded)
      expect(result.paradox).to be(false)
      expect(result.position.phase).to eq(:retreat)
    end

    it "raises InvalidInput for a position outside the movement phase, an argument of the wrong class, or two orders for one province" do
      retreat = rules_position(units: [ %i[england fleet lon] ], phase: "retreat")
      expect { RulesEngine.adjudicate(retreat, []) }.to raise_error(RulesEngine::InvalidInput)
      expect { RulesEngine.adjudicate(nil, []) }.to raise_error(RulesEngine::InvalidInput)
      expect { RulesEngine.adjudicate(start, nil) }.to raise_error(RulesEngine::InvalidInput)
      twice = [ rules_order(:hold, :england, :lon), move(:england, :lon, :nth) ]
      expect { RulesEngine.adjudicate(start, twice) }.to raise_error(RulesEngine::InvalidInput)
    end

    it "bounces both armies of a swap with no convoy (the stand-in let both succeed)" do
      swap = [ move(:austria, :vie, :bud), move(:austria, :bud, :vie) ]
      expect(RulesEngine.adjudicate(start, swap).outcomes.first(2).map(&:result)).to eq(%i[bounced bounced])
    end

    it "reports a support for a unit that moves, and a support for a move nobody makes, as unmatched" do
      orders = [ move(:austria, :bud, :ser), rules_order(:support_hold, :austria, :vie, target: "bud") ]
      expect(RulesEngine.adjudicate(start, orders).outcomes.map(&:result).first(2)).to eq(%i[succeeded unmatched])
      nobody = [ rules_order(:support_move, :austria, :vie, from: "bud", to: "gal") ]
      expect(RulesEngine.adjudicate(start, nobody).outcomes.first.result).to eq(:unmatched)
    end
  end
end
```

### The real-position specs (AC-4.1, AC-4.2)

```ruby
# spec/requests/real_results_spec.rb
require "rails_helper"
require_relative "../support/results_fixtures"

# Spec 029 AC-4.1, AC-4.2: the dislodged banners and the paradox warning on real gem output, from two positions of the DATC
# (sections 6.D.9 and 6.F.14), written as data and revealed through the seats.
RSpec.describe "Real results (spec 029 D4)", type: :request do
  include ResultsFixtures

  around { |example| with_passphrase { example.run } }

  def page(session) = Nokogiri::HTML5(session.response.body)

  def tags(page, power, province) = page.css(".result-group[data-power=#{power}] .result-row[data-province=#{province}] .outcome-tag").map(&:text)

  describe "DATC 6.D.9: a dislodged holder and an unmatched support (AC-4.1)" do
    let(:created) { create_game(power: "italy") }
    let(:game) { created.game }
    let(:id) { game.public_id }
    before do
      reveal_position!(game, units: [ %i[italy army ven], %i[italy army tyr], %i[austria army alb], %i[austria army tri] ],
                             orders: [ [ :move, :italy, :ven, { destination: { "province" => "tri", "coast" => nil } } ],
                                       [ :support_move, :italy, :tyr, { from: "ven", to: "tri" } ],
                                       [ :support_move, :austria, :alb, { from: "tri", to: "ser" } ],
                                       [ :hold, :austria, :tri ] ])
    end

    it "gives the host one banner for the dislodged army, equal to the Dislodged tags, with no Held tag on its row" do
      created.session.get "/games/#{id}/host"
      host = page(created.session)

      expect(host.css("[data-dislodged]").map(&:text)).to eq([ "Warning: Austria's army in TRI was dislodged. Settle it by hand." ])
      expect(host.css("[data-dislodged]").size).to eq(host.css(".outcome-tag--dislodged").size)
      expect(host.css("[data-dislodged]").size).to eq(game.history.first.adjudication.position.dislodged_units.size)
      expect(tags(host, "austria", "tri")).to eq([ "Dislodged" ])
      expect(tags(host, "austria", "alb")).to eq([ "Not used" ])
    end

    it "shows a seat the same tags and no banner" do
      created.session.get "/games/#{id}"
      seat = page(created.session)

      expect(tags(seat, "austria", "tri")).to eq([ "Dislodged" ])
      expect(tags(seat, "austria", "alb")).to eq([ "Not used" ])
      expect(seat.css("[data-dislodged]")).to be_empty
    end
  end

  describe "DATC 6.F.14: the simplest convoy paradox (AC-4.2)" do
    let(:created) { create_game(power: "england") }
    let(:game) { created.game }
    let(:id) { game.public_id }
    before do
      reveal_position!(game, units: [ %i[england fleet lon], %i[england fleet wal], %i[france army bre], %i[france fleet eng] ],
                             orders: [ [ :support_move, :england, :lon, { from: "wal", to: "eng" } ],
                                       [ :move, :england, :wal, { destination: { "province" => "eng", "coast" => nil } } ],
                                       [ :move, :france, :bre, { destination: { "province" => "lon", "coast" => nil } } ],
                                       [ :convoy, :france, :eng, { from: "bre", to: "lon" } ] ])
    end

    it "completes the reveal, opens the next phase, and shows one paradox warning on the host page and the seat page" do
      expect(game.history.first.adjudication.to_h["paradox"]).to be(true)
      expect(game.current_phase.number).to eq(2)
      [ "/games/#{id}/host", "/games/#{id}" ].each do |path|
        created.session.get path
        expect(page(created.session).css("section[data-results] [data-paradox]").size).to eq(1), path
      end
    end
  end
end
```

The positions follow the gem's own fixtures at the tag (`git show adjudicator-v0.2.0:adjudicator/spec/datc/6.D.9.yml` and `6.F.14.yml`). No outcome of the paradox phase is asserted (the gem leaves them unspecified while the flag is set).

### The rewritten `reveal_post_spec.rb` examples (AC-3.5)

Replace the helper `stub_result_with_dislodged_unit` (which stubs `adjudicate` with a hand-edited result) by one that sets a real position and saves real orders. The describe block "dislodged units (AC-5.4)" becomes:

```ruby
  describe "dislodged units (AC-5.4)" do
    # A real dislodgement: Germany's supported attack on France's holding army in Burgundy (spec 029 AC-2.1).
    def save_dislodging_orders(phase = game.current_phase)
      phase.update_columns(position: rules_position(units: [ %i[germany army mun], %i[germany army ruh], %i[france army bur] ]))
      germany = game.seats.find_by(power: "germany") || game.take_seat!("germany").first
      germany.save_orders!(phase.reload, { "mun" => json_of(move(:germany, :mun, :bur)),
                                           "ruh" => json_of(rules_order(:support_move, :germany, :ruh, from: "mun", to: "bur")) }, submit: true)
    end

    it "names each on the host page in a warning banner, and keeps them off the board of the next phase" do
      save_dislodging_orders

      host.post reveal_path
      host.get "/games/#{id}/host"

      expect(page.css(".banner--warning").map(&:text)).to eq([ "Warning: France's army in BUR was dislodged. Settle it by hand." ])
      expect(page.css("[data-dislodged]").size).to eq(page.css(".outcome-tag--dislodged").size) # one banner for each Dislodged tag (spec 025 AC-2.2)
      expect(game.current_phase.position.dislodged_units).to be_empty
      expect(game.history.first.adjudication.position.dislodged_units.size).to eq(1)
    end

    it "shows only the latest revealed phase's dislodged units" do
      save_dislodging_orders
      host.post reveal_path
      host.post "/games/#{id}/host/phases/2/reveal"
      host.get "/games/#{id}/host"

      expect(page.css(".banner--warning")).to be_empty
      expect(game.history.map(&:number)).to eq([ 1, 2 ])
    end

    it "shows none when nothing was dislodged" do
      host.post reveal_path
      host.get "/games/#{id}/host"

      expect(page.css(".banner--warning")).to be_empty
    end
  end
```

The France unit needs no seat: an unordered unit holds by an implied hold, which the engine supports. The existing file's `host`, `game`, `id` and `reveal_path` lets are reused.

### Run (the red evidence)

```bash
cd web && bundle exec rspec spec/models/phase_reveal_real_engine_spec.rb spec/models/rules_engine_adjudicate_spec.rb spec/requests/real_results_spec.rb spec/requests/reveal_post_spec.rb
```

**Expect red, for these reasons.** AC-2.1: France's outcome has `dislodged` false, because the stand-in bounces the attack against a holding unit. `rules_engine_adjudicate_spec.rb`: the impossible-object hash loads; the swap succeeds. `real_results_spec.rb`: the Dislodged banner is absent and `paradox` is false. `reveal_post_spec.rb`: no banner for France's army. Record the failure messages in this commit's body. Commit: "Add the specs the real engine must pass".

---

## Phase 2: Move the pin and swap the engine

**Implements:** FR-1, D1. **Satisfies:** AC-1.1, AC-1.2, AC-2.1 to AC-2.5, AC-4.1, AC-4.2. **Files:** `spec/config/gemfile_pin_spec.rb`, `Gemfile`, `Gemfile.lock`, `app/models/rules_engine.rb`, `spec/models/rules_engine_stand_in_spec.rb` (deleted).

### Test first

In `spec/config/gemfile_pin_spec.rb` change `tag: "adjudicator-v0\.1\.0"` to `tag: "adjudicator-v0\.2\.0"` in the first example's regexp. Run `bundle exec rspec spec/config/gemfile_pin_spec.rb`: red (the Gemfile still says v0.1.0).

### Implementation

```ruby
# Gemfile: the one changed word of the gem line
gem "trucebearer-adjudicator", git: "https://github.com/plainprogrammer/trucebearer.git", tag: "adjudicator-v0.2.0", glob: "adjudicator/*.gemspec", require: false
```

Run `bundle install` (the lockfile's git revision and version change to 0.2.0), then `BUNDLE_FROZEN=true bundle install` to prove the frozen install.

```ruby
# app/models/rules_engine.rb, in class << self
def adjudicate(position, orders) = TA.adjudicate(position, orders)

def load_adjudication(value) = coerce(value, "adjudication", TA::Adjudication, ->(h) { TA::Adjudication.from_h(h) })
```

Delete the block from the line `RESULTS = %w[...]` to `private_constant :StandIn, :StandInOutcome, :StandInAdjudication`, which is the stand-in header comment, the key constants, `StandInOutcome`, `StandInAdjudication` and `module StandIn`. Delete `spec/models/rules_engine_stand_in_spec.rb`. Leave `stand_in?` and the comments for Phase 3.

### Verify

```bash
cd web && bundle exec rspec spec/config/gemfile_pin_spec.rb spec/models/phase_reveal_real_engine_spec.rb spec/models/rules_engine_adjudicate_spec.rb spec/requests/real_results_spec.rb spec/requests/reveal_post_spec.rb
bundle exec rspec
```

Expect everything green. The throwaway run before planning showed the rest of the suite (768 examples) passing against the real engine. Commit: "Pin adjudicator-v0.2.0 and adjudicate with the gem".

---

## Phase 3: The stand-in and the practice note leave `app/`

**Implements:** FR-1, FR-2, D3. **Satisfies:** AC-3.1 to AC-3.5. **Files:** the Phase 3 rows of the file map.

### Test first

In `spec/models/rules_engine_boundary_spec.rb`, delete the `stand_in_pattern = ...` assignment (line 15) and the assertion that uses it in the first example (line 40), add ", spec 029 AC-3.1, AC-3.5" to the describe title, and replace the last example with:

```ruby
  # Spec 029 AC-3.1: nothing in the app names the stand-in or its note. Unlike the scan above, this one includes the boundary
  # file. The pattern is case-sensitive and not hyphen-aware on purpose: styleguide_helper.rb has an unrelated "Stand-ins" comment.
  it "names the stand-in nowhere under app, lib, config, db or bin (AC-3.1)" do
    pattern = /StandIn|stand_in|practice[-_]note/
    hits = app_files.select { |p| File.file?(p) && !File.binread(p).include?("\0") }
                    .select { |p| File.binread(p).force_encoding("UTF-8").scrub.match?(pattern) }
    expect(hits.map { |p| p.delete_prefix("#{root}/") }).to be_empty
    expect(File.read(boundary)).not_to match(/stand-in/i)
  end

  # Spec 029 AC-3.5: no stand-in under spec/, and no stub that answers adjudicate with a made-up result. Stubs that raise or
  # wrap the real engine are allowed.
  it "keeps no stand-in and no made-up adjudication under spec (AC-3.5)" do
    expect(File.exist?(File.join(root, "spec/models/rules_engine_stand_in_spec.rb"))).to be(false)
    hits = spec_files.select { |p| File.file?(p) && !File.binread(p).include?("\0") }
                     .select { |p| File.binread(p).force_encoding("UTF-8").scrub.match?(/StandIn|receive\(:adjudicate\)\.and_return/) }
    expect(hits.map { |p| p.delete_prefix("#{root}/") }).to be_empty
  end
```

(`spec_files` already excludes this file, which names those patterns.)

Add to `spec/models/rules_engine_adjudicate_spec.rb`, at the top of the describe, the AC-3.2 example:

```ruby
  it "has no stand_in? any more (AC-3.2)" do
    expect(RulesEngine).not_to respond_to(:stand_in?)
  end
```

In the four results specs change the assertions as follows. Then run them, the AC-3.1 example and the AC-3.2 example: they are red (the method, the partial and the stand-in comments are still there). The AC-3.5 example is a guard that is green from the start, because its stub and spec went in Phases 1 and 2:

- `spec/requests/results_spec.rb` example "shows the practice note while the stand-in is in use…" becomes `it "shows no practice note on any results view (AC-3.3)"` with `each_view { |name, session| expect(page(session).css(".practice-note")).to be_empty, name; expect(page(session).text).not_to include("Practice results"), name }` after `revealed_phase_with(...)` as before, and the `allow(RulesEngine).to receive(:stand_in?)` lines go. The AC-7.3 example's `expect(text).to include("Practice results")` becomes `not_to include`.
- `spec/views/results_partials_spec.rb`: the example becomes `it "shows the paradox banner only when the stored result says so (AC-7.4)"`; delete the `be_present` practice-note check and the `allow(RulesEngine).to receive(:stand_in?)` stub (lines 82-83) and keep the `be_nil` line that follows as the one note assertion.
- `spec/requests/styleguide_spec.rb`: the example name drops "and the practice note" and `expect(section.at_css(".practice-note")).to be_present` becomes `to be_nil` (AC-3.4).
- `spec/system/reveal_results_spec.rb`: the AC-8.4 example name drops "and the practice note", and `expect(page).to have_css(".practice-note")` becomes `expect(page).to have_no_css(".practice-note")`.
- Wording only: `spec/models/rules_engine_next_phase_spec.rb` (header comment "It is not part of the stand-in." becomes "It is the playtest's own rule, not the gem's."; the example "follows the stand-in's result for a real spring phase (AC-5.2)" becomes "follows the engine's result for a real spring phase (AC-5.2)"); `spec/requests/order_secrecy_spec.rb` ("with the stand-in's outcome for it" becomes "with its outcome"; "(both uncontested under the stand-in)" becomes "(both uncontested)").

### Implementation

- `app/models/rules_engine.rb`: delete `stand_in?` and its two-line comment; rewrite the header comment (lines 3-5) to "The one door to the rules engine gem (spec 019). Every call to the gem is made here and nowhere else in the app. Callers get gem objects back, hand hash forms to the loaders, and never name a gem class."; rewrite `next_movement_position`'s comment to open "The playtest's own rule for the phase that follows a reveal (spec 022 D3). It stays until 1.0 uses what gem 0.3.0 works out." and drop its "It is not part of the stand-in:" clause.
- Delete `app/views/results/_practice_note.html.erb`. In `app/views/results/_section.html.erb` delete the line `<%= render "results/practice_note" if RulesEngine.stand_in? %>`. In `app/views/styleguide/show.html.erb` delete the line that renders `results/practice_note` (line 279).
- `AGENTS.md` (web), the gem section: delete the sentence "Until gem 0.2.0, `RulesEngine.adjudicate` is a stand-in whose outcomes are fake."
- `docs/design-system.md`, the Result group row: "for the heading, banners, practice note, groups and the list of earlier results" becomes "for the heading, banners, groups and the list of earlier results".

### Verify

```bash
cd web && bundle exec rspec spec/models/rules_engine_boundary_spec.rb spec/models/rules_engine_adjudicate_spec.rb spec/requests/results_spec.rb spec/views/results_partials_spec.rb spec/requests/styleguide_spec.rb spec/system/reveal_results_spec.rb
bundle exec rspec
```

All green, including AC-3.2. Commit: "Remove the stand-in, stand_in? and the practice note".

---

## Phase 4: Record the changes in specs 019, 022 and 025

**Implements:** Story 5. **Satisfies:** AC-5.1 to AC-5.4. **Files:** `spec/docs/spec_amendments_spec.rb`, `docs/specs/019-adjudicator-boundary/spec.md`, `docs/specs/022-phase-lifecycle/spec.md`, `docs/specs/025-reveal-results/spec.md`.

### Test first

```ruby
# spec/docs/spec_amendments_spec.rb: the existing 022 1.5.0 example loses `expect(spec).to include("**Version:** 1.5.0")`
# (022's version moves on, as the 1.4.0 example's comment says), and these three are added.
  # The row that mentions spec 029, and its version, which must also be the spec's version line (the row is found by text, not by number).
  def amendment_row(path)
    spec = File.read(File.expand_path("../../docs/specs/#{path}/spec.md", __dir__))
    row = spec.lines.find { |line| line.start_with?("| ") && line.include?("spec 029") }
    expect(row).not_to be_nil
    version = row[/\A\| (\d+\.\d+\.\d+) \|/, 1]
    expect(version).not_to be_nil
    expect(spec).to include("**Version:** #{version}")
    [ spec, row, version ]
  end

  it "records spec 029's retirement of the stand-in in spec 019's changelog (spec 029 AC-5.1)" do
    _, row, version = amendment_row("019-adjudicator-boundary")
    expect(version).to eq("1.3.0")
    expect(row).to include("FR-3").and include("AC-5.1").and include("test double").and include("RulesEngine.adjudicate").and include("load_adjudication")
  end

  it "records spec 029's reading of spec 022 in its changelog (spec 029 AC-5.2)" do
    _, row, version = amendment_row("022-phase-lifecycle")
    expect(version).to match(/\A1\.(?:[6-9]|\d{2,})\.0\z/) # the next free minor after 1.5.0
    expect(row).to include("AC-5.2").and include("next_movement_position").and include("real engine")
  end

  it "records spec 029's retirement of the practice note in spec 025's changelog (spec 029 AC-5.3)" do
    _, row, version = amendment_row("025-reveal-results")
    expect(version).to eq("1.1.0")
    expect(row).to include("D6").and include("AC-7.1").and include("AC-7.3").and include("AC-8.1").and include("AC-8.4").and include("stand_in?")
  end
```

Run `bundle exec rspec spec/docs/spec_amendments_spec.rb`: the three new examples are red (no such rows), and the 022 1.5.0 example stays green after its version check goes.

### Implementation

Add one row at the top of each changelog table and move the version line (and `Last Updated`) as stated:

- Spec 019, `**Version:** 1.3.0`: "Amended by spec 029 (gem 0.2.0, #29).<br>• Story 3, FR-3 and AC-3.x (the stand-in adjudicator) and the stand-in half of AC-5.1 are retired: `RulesEngine.adjudicate` calls the gem and `load_adjudication` builds a `TA::Adjudication` with `from_h`. AC-4.4 and AC-5.2 read as the real adjudication result.<br>• The stand-in has no test double (spec 029 D2). `app/models/rules_engine.rb` keeps the four loaders, `check`, `legal_orders` and the rest of the boundary unchanged."
- Spec 022, next free minor after 1.5.0 (1.6.0 unless #27 or #105 took it, in which case the next free): "Amended by spec 029 (gem 0.2.0, #29).<br>• The Non-Goal that keeps the app on gem 0.1.0 and the stand-in, AC-5.2's \"stand-in's result\" and the closing line that #29 changes only `RulesEngine` are read as: adjudication is the real engine, and #29 also edits the views and specs listed in spec 029 D6.<br>• `RulesEngine.next_movement_position` is unchanged and stays until 1.0."
- Spec 025, `**Version:** 1.1.0`: "Amended by spec 029 (gem 0.2.0, #29).<br>• D6's stand-in note, Story 7's AC-7.1 and AC-7.3's wording about the note, AC-8.1's and AC-8.4's note, `RulesEngine.stand_in?` and the partial `results/_practice_note` are retired; no results view carries a practice note.<br>• The Goal and Non-Goal lines, AC-7.2's \"stand-in's loader\" wording and the Known limits entries that call the results fake are read as the real engine. The paradox warning and every other behavior stand."

### Verify

`bundle exec rspec spec/docs` green, then `bundle exec rspec`. Commit: "Record the stand-in's retirement in specs 019, 022 and 025".

---

## Phase 5: Screenshots and the proof

**Implements:** D6 (screenshots), the "Done when" list. **Files:** `docs/specs/025-reveal-results/screens/*.png`.

Run the whole system spec file, which writes the six images:

```bash
cd web && SCREENSHOTS="$PWD/docs/specs/025-reveal-results/screens" bundle exec rspec spec/system/reveal_results_spec.rb
```

Open the six images (they should show the pages without the practice note) before committing: "Regenerate spec 025's screenshots without the practice note".

Then the proof of every "Done when" item, from `web/`:

| Done when | Command |
|---|---|
| The pin moves to the new tag | `grep -n 'adjudicator-v0.2.0' Gemfile` and `bundle exec rspec spec/config/gemfile_pin_spec.rb` |
| A frozen install works | `BUNDLE_FROZEN=true bundle install` |
| Real engine, stand-in off the production path | `bundle exec rspec spec/models/phase_reveal_real_engine_spec.rb spec/models/rules_engine_boundary_spec.rb spec/models/rules_engine_adjudicate_spec.rb spec/requests/real_results_spec.rb` |
| Specs pass | `bundle exec rspec` (system specs included) |
| Clean | `bin/brakeman` and `bin/rubocop` |
| One side only | `git diff --name-only main...HEAD` lists only `web/` paths |
| CI and early warning | the `Web specs` job green; `gh workflow run early-warning.yml --ref web/29-gem-0.2.0`, then link the run in the pull request |

After that: the implementation review (Opus, read-only), `session-wrap`, the push that opens the draft pull request, and `gh pr ready`. The pull request description links the early-warning run and says (spec D5) that no data holds stand-in results, that no migration is needed, and that a development database may be reset with `bin/rails db:reset`; it does not promise that an old development row fails to load.

## Gates

- Spec coverage: every AC has a phase (AC-1.x P2; AC-2.x P1/P2; AC-3.x P1/P3; AC-4.x P1; AC-5.x P4). FR-1 and FR-2 are carried by P1 to P3.
- No placeholders. Every code step has its code. Where a spec's exact order list depends on what the engine accepts (the unmatched-support example), the plan says what to do at execution.
- Names are consistent: `reveal_position!`, `amendment_row`, `save_dislodging_orders`.

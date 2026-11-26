# Implementation Plan: The adjudicator boundary and a stand-in adjudicator

**Spec:** web/docs/specs/019-adjudicator-boundary/spec.md (v1.2.1, Approved at Gate A)
**Decisions:** none new. Spec decisions D1 to D4 stand. `docs/architecture.md` "The boundary between the gem and the app"
**Created:** 2026-11-26

All paths are relative to `web/`. Nothing outside `web/` changes.

## Global Constraints

- The only gem facts used are in `adjudicator/docs/interface.md` at the tag `adjudicator-v0.1.0`. No gem source is read or called beyond what it documents. Never edit `adjudicator/`, `.github/` or the root files.
- Every gem call lives in `app/models/rules_engine.rb`. No other file under `app/`, `lib/`, `config/`, `db/`, `bin/` or `spec/` (guard spec excepted) names `Trucebearer::`, `TA`, the gem's `require`, or the stand-in class names. (FR-7)
- The name: no file name, class, method or word matches `diplomacy` or a word starting with `dip`, or `Dip` inside a CamelCase name (the existing `spec/styles/words_spec.rb` scans `app/`, `lib/`, `spec/`). Avoid words such as "dip", "dips", "dipped" in comments.
- Test first, RSpec. Every phase writes its specs, sees them fail for the right reason, then writes the code. Run `bundle exec rspec` from `web/` before every push.
- No new gem. Standard library and Rails defaults only. No migration and no file in `db/`. (AC-4.10)
- Commit messages: a plain imperative sentence, ending with `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`. One git operation per shell call.
- Specs that need gem objects build them with `RulesEngine.load_position` and `RulesEngine.load_order` from hand-written string-keyed hashes (helper in Phase 3).

## Goal

The app depends on the gem at the tag `adjudicator-v0.1.0`. One module, `RulesEngine`, is the only code that touches the gem. It offers the starting position, checking, legal orders, a stand-in adjudication in the documented shape, and loaders for the hash forms. Four ActiveRecord attribute types store those objects as JSON and load them back. A guard spec keeps it that way.

## File map

| File | Responsibility |
|---|---|
| `Gemfile`, `Gemfile.lock` | Pin the tag, with the `ADJUDICATOR_PATH` switch. Declared `require: false` |
| `app/models/rules_engine.rb` | The boundary: the four calls, four loaders, `InvalidInput`, and the nested stand-in (`StandIn` module, `StandInOutcome`, `StandInAdjudication`) |
| `app/models/rules_object_type.rb` | `RulesObjectType`, an `ActiveRecord::Type::Value` subclass with one instance per kind (`.position`, `.order`, `.check_result`, `.adjudication`). Calls only `RulesEngine.load_*` |
| `spec/support/rules_helpers.rb` | `rules_position`, `rules_order` helpers building objects from hash forms |
| `spec/models/rules_engine_spec.rb` | AC-2.1 to AC-2.6 (written first) |
| `spec/models/rules_engine_boundary_spec.rb` | The guard: AC-2.7, 2.8, 2.8a, 5.1 |
| `spec/config/gemfile_pin_spec.rb` | AC-1.1 and the `require: false` half of AC-2.8a, from the Gemfile text only |
| `spec/models/rules_engine_stand_in_spec.rb` | AC-3.x, AC-5.2 |
| `spec/models/stored_gem_objects_spec.rb` | AC-4.x, with a table that exists only during its examples |
| `AGENTS.md` | One line under "The adjudicator gem" (AC-5.3) |

---

## Phase 1: The first failing spec

**Implements:** AC-2.1, AC-2.2. **Files:** `spec/models/rules_engine_spec.rb`

Write the boundary spec first. It fails until the gem is pinned and `RulesEngine` exists.

```ruby
require "rails_helper"

RSpec.describe RulesEngine do
  let(:start) { RulesEngine.starting_position }

  it "gives the classic starting position, with 22 units (AC-2.1)" do
    expect([ start.season, start.year, start.phase ]).to eq([ :spring, 1901, :movement ])
    expect(start.units.size).to eq(22)
  end

  it "checks England's hold in London as legal (AC-2.2)" do
    order = RulesEngine.load_order({ "format" => 1, "type" => "hold", "power" => "england", "at" => "lon" })
    result = RulesEngine.check(start, order)
    expect(result.legal).to be(true)
    expect(result.reasons).to eq([])
  end
end
```

**Verify:** `bundle exec rspec spec/models/rules_engine_spec.rb` fails with `uninitialized constant RulesEngine`. Commit the red spec: "Add the first failing boundary spec".

## Phase 2: Pin the gem and build the boundary's calls

**Implements:** FR-1, FR-2, AC-1.1 to AC-1.5, AC-2.1 to AC-2.6, AC-2.8a. **Files:** `Gemfile`, `Gemfile.lock`, `app/models/rules_engine.rb`, `spec/config/gemfile_pin_spec.rb`, `spec/support/rules_helpers.rb`, `spec/models/rules_engine_spec.rb`

### 2a. The pin spec (red first)

```ruby
require "spec_helper"

# Reads Gemfile text only. The early-warning job's unfrozen install rewrites Gemfile.lock to a
# path source, so nothing here reads the lockfile or the loaded gem.
RSpec.describe "The gem pin (AC-1.1, AC-2.8a)" do
  gemfile = File.read(File.expand_path("../../Gemfile", __dir__))

  it "pins the git tag with the gemspec glob when the variable is unset" do
    expect(gemfile).to include('git: "https://github.com/plainprogrammer/trucebearer.git"')
    expect(gemfile).to include('tag: "adjudicator-v0.1.0"')
    expect(gemfile).to include('glob: "adjudicator/*.gemspec"')
  end

  it "treats an empty ADJUDICATOR_PATH as unset" do
    expect(gemfile).to include('ENV["ADJUDICATOR_PATH"].to_s.empty?')
  end

  it "uses a path source only for the ADJUDICATOR_PATH branch" do
    paths = gemfile.lines.grep(/\bpath:/)
    expect(paths.size).to eq(1)
    expect(paths.first).to include('path: ENV["ADJUDICATOR_PATH"]')
  end

  it "declares the gem with require: false, so only the boundary file requires it" do
    gem_lines = gemfile.lines.select { |l| l.include?("trucebearer-adjudicator") && l.include?("gem ") }
    expect(gem_lines.size).to eq(2)
    expect(gem_lines).to all(include("require: false"))
  end
end
```

To keep each `gem` call on one logical line for this check, the Gemfile writes each gem call on a single line with trailing keyword arguments broken after a comma is not used; see 2b.

### 2b. The Gemfile

Add after the `solid_*` gems (before `bootsnap`):

```ruby
# The rules engine, pinned to a released tag of this repository (docs/repository-layout.md).
# ADJUDICATOR_PATH points at a checked-out adjudicator/ folder instead, for the early-warning job only.
# Upgrading the tag is its own pull request. Required by app/models/rules_engine.rb alone.
if ENV["ADJUDICATOR_PATH"].to_s.empty?
  gem "trucebearer-adjudicator", git: "https://github.com/plainprogrammer/trucebearer.git", tag: "adjudicator-v0.1.0", glob: "adjudicator/*.gemspec", require: false
else
  gem "trucebearer-adjudicator", path: ENV["ADJUDICATOR_PATH"], require: false
end
```

Then, from `web/`, with the variable unset: `bundle install` (writes the GIT section of `Gemfile.lock`). Check `git diff Gemfile.lock` shows only the new GIT block (remote, revision, tag, glob, the gem) and the DEPENDENCIES line. Commit: "Pin the adjudicator gem to adjudicator-v0.1.0".

### 2c. The boundary (calls, loaders, error alias)

`app/models/rules_engine.rb`:

```ruby
require "trucebearer/adjudicator"

# The one door to the rules engine gem (spec 019). Every call to the gem is made here and nowhere
# else in the app. Callers get gem objects back, hand hash forms to the loaders, and never name a
# gem class. Before gem 0.2.0, adjudicate is answered by the stand-in at the end of this file.
module RulesEngine
  TA = Trucebearer::Adjudicator
  private_constant :TA

  # The gem's own error class under the app's constant: rescuing this catches what the gem raises.
  InvalidInput = TA::InvalidInput

  ORDER_CLASSES = [ TA::Order::Hold, TA::Order::Move, TA::Order::MoveViaConvoy,
                    TA::Order::SupportHold, TA::Order::SupportMove, TA::Order::Convoy ].freeze
  private_constant :ORDER_CLASSES

  class << self
    def starting_position = TA::Map.classic.starting_position

    def check(position, order) = TA.check(position, order)

    def legal_orders(position, unit) = TA.legal_orders(position, unit)

    # Each loader takes an object of its kind (returned as it is), a string-keyed hash (rebuilt with
    # from_h) or nil (returned as nil). Anything else raises InvalidInput naming the value.
    def load_position(value) = coerce(value, "position", TA::Position, ->(h) { TA::Position.from_h(h) })

    def load_order(value)
      coerce(value, "order", ->(v) { ORDER_CLASSES.any? { |c| c === v } }, ->(h) { TA::Order.from_h(h) })
    end

    def load_check_result(value) = coerce(value, "check result", TA::CheckResult, ->(h) { TA::CheckResult.from_h(h) })

    private

    def coerce(value, name, kind, build)
      return nil if value.nil?
      return value if kind === value
      raise InvalidInput, "a #{name} must be a #{name}, a Hash or nil, got #{value.inspect}" unless value.is_a?(Hash)

      build.call(value)
    end
  end
end
```

`adjudicate` and `load_adjudication` are not in this file yet. Phase 4 writes their specs first, then adds them next to `load_check_result`:

```ruby
    def adjudicate(position, orders) = StandIn.adjudicate(position, orders)

    def load_adjudication(value) = coerce(value, "adjudication", StandInAdjudication, ->(h) { StandInAdjudication.from_h(h) })
```

### 2d. Helpers and the rest of AC-2.x (red first, then green)

`spec/support/rules_helpers.rb`:

```ruby
# Builds gem objects from hand-written, string-keyed hash forms, so specs need no gem constants.
module RulesHelpers
  def rules_position(units:, ownership: {}, season: "spring", year: 1901, phase: "movement", standoffs: [], dislodged_units: [])
    RulesEngine.load_position(
      "format" => 1, "map" => "classic", "season" => season, "year" => year, "phase" => phase,
      "units" => units.map { |power, type, province, coast| unit_hash(power, type, province, coast) },
      "ownership" => ownership.transform_keys(&:to_s).transform_values(&:to_s),
      "dislodged_units" => dislodged_units, "standoffs" => standoffs.map(&:to_s)
    )
  end

  def unit_hash(power, type, province, coast = nil)
    { "power" => power.to_s, "type" => type.to_s, "location" => { "province" => province.to_s, "coast" => coast&.to_s } }
  end

  def rules_order(type, power, at, **rest)
    RulesEngine.load_order({ "format" => 1, "type" => type.to_s, "power" => power.to_s, "at" => at.to_s }
      .merge(rest.transform_keys(&:to_s)))
  end

  def move(power, at, province, coast = nil)
    rules_order(:move, power, at, destination: { "province" => province.to_s, "coast" => coast&.to_s })
  end
end
```

Extend `spec/models/rules_engine_spec.rb` (written before the code that needs it; the file already exists from Phase 1) with examples for AC-2.3 to AC-2.6, each in its own `it`:

```ruby
  it "gives a reason for an illegal order (AC-2.3)" do
    result = RulesEngine.check(start, rules_order(:hold, :france, :lon))
    expect([ result.legal, result.reasons ]).to eq([ false, [ :foreign_unit ] ])
  end

  it "lists legal orders starting with the hold, and every one passes check (AC-2.4)" do
    fleet = start.units.find { |u| u.location.province == :lon }
    orders = RulesEngine.legal_orders(start, fleet)
    expect(orders.first).to eq(rules_order(:hold, :england, :lon))
    expect(orders.map { |o| RulesEngine.check(start, o).legal }).to all(be(true))
  end

  describe "loaders" do
    let(:order_hashes) do
      [ { "type" => "hold", "power" => "england", "at" => "lon" },
        { "type" => "move", "power" => "france", "at" => "mao", "destination" => { "province" => "spa", "coast" => "nc" } },
        { "type" => "move_via_convoy", "power" => "england", "at" => "lon", "to" => "wal" },
        { "type" => "support_hold", "power" => "germany", "at" => "mun", "target" => "ber" },
        { "type" => "support_move", "power" => "france", "at" => "por", "from" => "mao", "to" => "spa" },
        { "type" => "convoy", "power" => "england", "at" => "nth", "from" => "lon", "to" => "nwy" } ]
        .map { |h| { "format" => 1 }.merge(h) }
    end

    it "round-trips each kind through JSON (AC-2.5)" do
      order_hashes.each do |h|
        order = RulesEngine.load_order(JSON.parse(JSON.generate(h)))
        expect(order.to_h).to eq(h)
      end
      expect(RulesEngine.load_position(JSON.parse(JSON.generate(start.to_h)))).to eq(start)
      result = RulesEngine.check(start, rules_order(:hold, :france, :lon))
      expect(RulesEngine.load_check_result(JSON.parse(JSON.generate(result.to_h)))).to eq(result)
    end

    it "returns an object of the right kind as it is, and nil as nil (AC-2.5a)" do
      order = rules_order(:hold, :england, :lon)
      expect(RulesEngine.load_order(order)).to equal(order)
      expect(RulesEngine.load_position(start)).to equal(start)
      expect(RulesEngine.load_order(nil)).to be_nil
    end

    it "raises InvalidInput naming a value of the wrong kind (AC-2.5b)" do
      [ 5, "hold", [], rules_order(:hold, :england, :lon) ].each do |bad|
        expect { RulesEngine.load_position(bad) }.to raise_error(RulesEngine::InvalidInput, /#{Regexp.escape(bad.inspect)}/)
      end
    end

    it "raises InvalidInput for a bad hash (AC-2.6)" do
      good = start.to_h
      [ good.merge("format" => 2), good.except("format"), good.transform_keys(&:to_sym), good.merge("extra" => 1), good.except("year") ].each do |bad|
        expect { RulesEngine.load_position(bad) }.to raise_error(RulesEngine::InvalidInput)
      end
    end
  end
```

Add `require_relative "../support/rules_helpers"` and `include RulesHelpers` at the top of the spec file, with `RSpec.describe RulesEngine do` unchanged.

**Verify:** the pin spec is red before 2b and green after. `bundle exec rspec spec/models/rules_engine_spec.rb spec/config` is green with the Phase 1 spec now passing.

### 2e. Proof of the pin and the switch

Run each from `web/` and record the output for the pull request:

1. `ADJUDICATOR_PATH= BUNDLE_FROZEN=true bundle install` succeeds, then `git diff --exit-code Gemfile.lock`. (AC-1.2)
2. `ADJUDICATOR_PATH=../adjudicator BUNDLE_FROZEN=false bundle install && ADJUDICATOR_PATH=../adjudicator BUNDLE_FROZEN=false bundle exec rspec spec/models spec/config`, then `git checkout -- Gemfile.lock`, then rerun step 1. (AC-1.3, AC-1.4)
3. Read `Dockerfile`: the build stage's `apt-get install` list holds `git` (line 36). No Dockerfile change. (AC-1.5)

Commit: "Add the RulesEngine boundary with checking, legal orders and loaders". (Pin spec, helpers, loaders, the Phase 1 spec turning green.)

## Phase 3: The guard

**Implements:** FR-7, AC-2.7, AC-2.8, AC-5.1 (the stand-in half is checked again in Phase 4). **Files:** `spec/models/rules_engine_boundary_spec.rb`

Written first. It passes at once on today's tree (only the boundary names the gem), so the proof that it can fail is AC-2.8: the matcher is exercised on strings, and a scratch file is added and removed during the phase (not committed).

```ruby
require "spec_helper"

# Textual: a constant built from pieces would pass it, so review still matters.
RSpec.describe "The gem boundary (AC-2.7, AC-2.8, AC-5.1)" do
  root = File.expand_path("../..", __dir__)
  boundary = File.join(root, "app/models/rules_engine.rb")
  gem_patterns = [
    /\bTrucebearer\s*::/,
    /\bTrucebearer\s*\.\s*[a-z_]/,
    /(?<![A-Za-z0-9_])TA(?![A-Za-z0-9_])/,
    /require\s*\(?\s*["']trucebearer/
  ]
  stand_in_pattern = /StandInAdjudication|StandInOutcome/

  app_files = Dir.glob(File.join(root, "{app,lib,config,db,bin}/**/*"), File::FNM_DOTMATCH)
                 .push(File.join(root, "config.ru"), File.join(root, "Rakefile"))
  spec_files = Dir.glob(File.join(root, "spec/**/*"), File::FNM_DOTMATCH).reject { |p| p == __FILE__ }

  scan = lambda do |paths, patterns|
    paths.select { |p| File.file?(p) && p != boundary }.filter_map do |path|
      bytes = File.binread(path)
      next if bytes.include?("\0") # fonts and images

      text = bytes.force_encoding("UTF-8").scrub
      hit = patterns.find { |pattern| text.match?(pattern) }
      "#{path.delete_prefix("#{root}/")}: #{hit.source}" if hit
    end
  end

  it "flags what it should and spares what it should not (AC-2.8)" do
    flagged = [ "Trucebearer::Adjudicator", "Trucebearer.const_get(:X)", "TA::Order", "x = TA.check(a, b)",
                'require "trucebearer/adjudicator"' ]
    spared = [ "Trucebearer", '"description": "Trucebearer."', "Trucebearer. Next", "TABLE", "DATA", "STATUS",
               "RulesEngine::InvalidInput", "RulesEngine.check" ]
    flagged.each { |s| expect(gem_patterns.any? { |p| s.match?(p) }).to be(true), s }
    spared.each { |s| expect(gem_patterns.any? { |p| s.match?(p) }).to be(false), s }
    expect("RulesEngine::StandInOutcome").to match(stand_in_pattern)
  end

  it "finds files to scan" do
    expect(app_files.count { |p| File.file?(p) }).to be > 10
    expect(spec_files.count { |p| File.file?(p) }).to be > 5
  end

  it "keeps every gem call in app/models/rules_engine.rb (AC-2.7)" do
    expect(scan.call(app_files + spec_files, gem_patterns)).to be_empty
  end

  it "keeps the stand-in's classes in that file alone (AC-5.1)" do
    expect(scan.call(app_files, [ stand_in_pattern ])).to be_empty
  end
end
```

**Verify:** green. Then temporarily create `app/models/scratch_probe.rb` containing `Trucebearer::Adjudicator`, see the third example fail naming that file, delete the file. Commit: "Add the spec that keeps every gem call in RulesEngine".

## Phase 4: The stand-in adjudicator

**Implements:** FR-3, AC-3.x, AC-5.2. **Files:** `spec/models/rules_engine_stand_in_spec.rb`, `app/models/rules_engine.rb`

### 4a. Specs first

One example per AC, using the helpers. Positions are built with `rules_position(units: [[:england, :fleet, :lon], ...], ownership: {...})`. Outline of the file, each `it` an AC:

```ruby
require "rails_helper"
require_relative "../support/rules_helpers"

RSpec.describe "RulesEngine.adjudicate, the stand-in (spec 019 FR-3; outcomes are fake)" do
  include RulesHelpers
  let(:start) { RulesEngine.starting_position }

  def results(adjudication) = adjudication.outcomes.map(&:result)

  it "succeeds two separate moves and gives the other 20 units implied holds (AC-3.1)" do
    adj = RulesEngine.adjudicate(start, [ move(:england, :lon, :nth), move(:germany, :kie, :hol) ])
    expect(results(adj).first(2)).to eq([ :succeeded, :succeeded ])
    implied = adj.outcomes.reject(&:submitted)
    expect(implied.size).to eq(20)
    expect(implied.map(&:result).uniq).to eq([ :held ])
    expect(implied.map { |o| o.order.at }).to eq(implied.map { |o| o.order.at }.sort)
    expect(adj.paradox).to be(false)
  end

  it "bounces two moves into one province and records the standoff (AC-3.2)" do
    adj = RulesEngine.adjudicate(start, [ move(:russia, :war, :gal), move(:austria, :vie, :gal) ])
    expect(results(adj).first(2)).to eq([ :bounced, :bounced ])
    expect(adj.position.units.map { |u| u.location.province }).not_to include(:gal)
    expect(adj.position.standoffs).to eq([ :gal ])
  end

  it "voids a failing order and gives the owner's unit an implied hold (AC-3.3)" do
    adj = RulesEngine.adjudicate(start, [ rules_order(:hold, :france, :lon) ])
    expect(adj.outcomes.first).to have_attributes(result: :void, submitted: true, dislodged: false)
    expect(adj.outcomes.find { |o| o.order.at == :lon && !o.submitted }.result).to eq(:held)
  end

  it "gives a legal support or convoy :given with no effect (AC-3.4)" do
    pos = rules_position(units: [ [ :england, :army, :lon ], [ :england, :fleet, :nth ], [ :germany, :army, :mun ], [ :germany, :army, :ber ] ])
    adj = RulesEngine.adjudicate(pos, [
      rules_order(:convoy, :england, :nth, from: "lon", to: "nwy"),
      rules_order(:support_hold, :germany, :mun, target: "ber") ])
    expect(results(adj).first(2)).to eq([ :given, :given ])
    expect(adj.position.units.size).to eq(4)
  end

  # AC-3.5 to AC-3.6g: one example each, each with a small hand-built position:
  #  3.5  a move into a province whose unit holds / is void / supports / convoys / has a bounced move -> :bounced, no standoff
  #  3.6  a move into a province whose unit moves away -> both :succeeded
  #  3.6a a swap (par<->bur armies) and a rotation (par->bur->mar->par armies) -> all :succeeded
  #  3.6b chain: A->B, B->C, C holds: A->B, B->C both :bounced
  #  3.6c three armies (a, b, c) into one empty province -> three :bounced, province once in standoffs
  #  3.6d fleet MAO->spa/nc keeps :nc; fleet stp/sc -> bar loses coast
  #  3.6e move_via_convoy lon->wal -> unit ends in wal with coast nil
  #  3.6g two moves into a province whose occupant leaves: both :bounced, leaver :succeeded, province in standoffs once
  # AC-3.7: no outcome dislodged, dislodged_units [], same season/year/ownership, phase :retreat
  # AC-3.8: order of outcomes; every result in the nine documented symbols
  # AC-3.9: retreat-phase position, two orders from one power for one unit -> InvalidInput; non-position or non-array argument -> InvalidInput
  # AC-3.10: to_h keys and shape; position hash loads
  # AC-5.2: outcomes/paradox/position readers; outcome order/result/submitted/dislodged readers
end
```

Each outline line becomes a full example in the real file (concrete provinces, no placeholders). The AC-3.6f sweep:

```ruby
  it "never raises and always builds a valid next position over seeded random legal orders (AC-3.6f)" do
    rng = Random.new(2026)
    positions = [
      start,
      rules_position(units: [ [ :france, :fleet, :mao ], [ :france, :fleet, :gol ], [ :france, :army, :mar ], [ :england, :fleet, :nth ], [ :england, :army, :lon ] ]),
      rules_position(units: [ [ :russia, :fleet, :stp, :sc ], [ :russia, :army, :mos ], [ :russia, :fleet, :sev ], [ :turkey, :fleet, :bla ], [ :germany, :army, :ber ] ])
    ]
    phases = 0
    positions.each do |pos|
      120.times do
        orders = pos.units.map { |u| RulesEngine.legal_orders(pos, u).sample(random: rng) }
        adj = RulesEngine.adjudicate(pos, orders)
        expect(RulesEngine.load_position(adj.position.to_h)).to eq(adj.position)
        expect(RulesEngine.load_adjudication(JSON.parse(JSON.generate(adj.to_h)))).to eq(adj)
        phases += 1
      end
    end
    expect(phases).to be >= 300
  end
```

**Verify:** `bundle exec rspec spec/models/rules_engine_stand_in_spec.rb` fails with `NoMethodError`/`NameError` (`StandIn`) for the right reason.

### 4b. The code

Add to `app/models/rules_engine.rb` inside `module RulesEngine`, after the `class << self` block (the two stand-in loader lines and `adjudicate` already reference these constants):

```ruby
  RESULTS = %w[void held no_route bounced succeeded unmatched cut given disrupted].freeze
  private_constant :RESULTS

  # STAND-IN, until gem 0.2.0 (#29). Its outcomes are FAKE. It answers in the documented shape of
  # TA.adjudicate (interface.md, "Adjudicating a movement phase") with only these rules:
  #  1. The position must be in the movement phase, and no power gives two orders for one province.
  #  2. An order that fails check is :void.
  #  3. A legal hold is :held. A legal support or convoy is :given and has no other effect.
  #  4. A legal move succeeds unless another legal move targets the same province, or its target
  #     holds a unit that is not making a move that still succeeds (worked out until nothing
  #     changes). Swaps and rotations succeed: that is fake, and 0.2.0 corrects it.
  #  5. A unit with no legal order from its owner holds. No unit is ever dislodged. No paradox.
  #  6. The next position keeps season, year and ownership, has phase :retreat, moves the units that
  #     succeeded, and lists each province two or more moves targeted and that is empty afterward.
  # Supports, convoys, strength and cuts are not looked at. At 0.2.0 delete this and the two
  # classes below, and let adjudicate and load_adjudication call TA.
  StandInOutcome = Data.define(:order, :result, :submitted, :dislodged) do
    KEYS = %w[order result submitted dislodged].freeze

    def self.from_h(hash)
      raise InvalidInput, "an outcome must be a Hash, got #{hash.inspect}" unless hash.is_a?(Hash)
      unless hash.keys.sort == KEYS.sort
        raise InvalidInput, "an outcome needs exactly the keys #{KEYS.inspect}, got #{hash.keys.inspect}"
      end
      unless RESULTS.include?(hash["result"])
        raise InvalidInput, "\"result\" must be one of #{RESULTS.inspect}, got #{hash["result"].inspect}"
      end
      %w[submitted dislodged].each do |key|
        raise InvalidInput, "#{key.inspect} must be true or false, got #{hash[key].inspect}" unless [ true, false ].include?(hash[key])
      end
      raise InvalidInput, "\"order\" must be a Hash, got #{hash["order"].inspect}" unless hash["order"].is_a?(Hash)

      new(order: RulesEngine.load_order(hash["order"]), result: hash["result"].to_sym,
          submitted: hash["submitted"], dislodged: hash["dislodged"])
    end

    def to_h = { "order" => order.to_h, "result" => result.to_s, "submitted" => submitted, "dislodged" => dislodged }
  end

  StandInAdjudication = Data.define(:outcomes, :paradox, :position) do
    def initialize(outcomes:, paradox:, position:) = super(outcomes: outcomes.dup.freeze, paradox: paradox, position: position)

    def self.from_h(hash)
      raise InvalidInput, "an adjudication must be a Hash, got #{hash.inspect}" unless hash.is_a?(Hash)
      unless hash.keys.sort == %w[format outcomes paradox position]
        raise InvalidInput, "an adjudication needs exactly the keys format, outcomes, paradox and position, got #{hash.keys.inspect}"
      end
      raise InvalidInput, "\"format\" must be 1, got #{hash["format"].inspect}" unless hash["format"] == 1
      raise InvalidInput, "\"outcomes\" must be an Array, got #{hash["outcomes"].inspect}" unless hash["outcomes"].is_a?(Array)
      raise InvalidInput, "\"paradox\" must be true or false, got #{hash["paradox"].inspect}" unless [ true, false ].include?(hash["paradox"])

      new(outcomes: hash["outcomes"].map { |h| StandInOutcome.from_h(h) }, paradox: hash["paradox"],
          position: RulesEngine.load_position(hash["position"]))
    end

    def to_h = { "format" => 1, "outcomes" => outcomes.map(&:to_h), "paradox" => paradox, "position" => position.to_h }
  end

  module StandIn
    MOVES = [ TA::Order::Move, TA::Order::MoveViaConvoy ].freeze
    SUPPORTS_AND_CONVOYS = [ TA::Order::SupportHold, TA::Order::SupportMove, TA::Order::Convoy ].freeze

    def self.adjudicate(position, orders)
      unless position.is_a?(TA::Position) && orders.is_a?(Array)
        raise InvalidInput, "adjudicate needs a position and an Array of orders, got #{position.inspect} and #{orders.inspect}"
      end
      raise InvalidInput, "the phase must be :movement, got #{position.phase.inspect}" unless position.phase == :movement

      legal = orders.map { |order| TA.check(position, order).legal }
      reject_duplicates(orders)
      units = position.units.to_h { |u| [ u.location.province, u ] }
      followed = orders.zip(legal).select(&:last).map(&:first)
      implied = units.values.reject { |u| followed.any? { |o| o.at == u.location.province } }
                     .sort_by { |u| u.location.province }
                     .map { |u| TA::Order::Hold.new(power: u.power, at: u.location.province) }

      targets = followed.select { |o| MOVES.any? { |c| c === o } }.to_h { |o| [ o.at, target_of(o) ] }
      succeeded = surviving_moves(targets, units)

      outcomes = orders.zip(legal).map { |order, ok| outcome(order, ok ? result_for(order, succeeded) : :void, true) } +
                 implied.map { |order| outcome(order, :held, false) }
      StandInAdjudication.new(outcomes: outcomes, paradox: false, position: next_position(position, targets, succeeded))
    end

    def self.reject_duplicates(orders)
      dup = orders.group_by { |o| [ o.power, o.at ] }.find { |_, list| list.size > 1 }
      raise InvalidInput, "#{dup.first.first} gave #{dup.last.size} orders for the unit in #{dup.first.last}" if dup
    end

    def self.target_of(order)
      order.is_a?(TA::Order::Move) ? order.destination : TA::Location.new(province: order.to)
    end

    # Rule 4: start with every move succeeding, bounce contested targets, then repeat bouncing any
    # move whose target holds a unit not making a move that still succeeds, until nothing changes.
    def self.surviving_moves(targets, units)
      succeeded = targets.keys.to_set
      contested = targets.group_by { |_, loc| loc.province }.select { |_, list| list.size > 1 }.keys
      succeeded.reject! { |from| contested.include?(targets[from].province) }
      loop do
        blocked = succeeded.select { |from| units.key?(targets[from].province) && !succeeded.include?(targets[from].province) }
        break if blocked.empty?

        succeeded.subtract(blocked)
      end
      succeeded
    end

    def self.result_for(order, succeeded)
      case order
      when TA::Order::Hold then :held
      when *SUPPORTS_AND_CONVOYS then :given
      else succeeded.include?(order.at) ? :succeeded : :bounced
      end
    end

    def self.outcome(order, result, submitted) = StandInOutcome.new(order: order, result: result, submitted: submitted, dislodged: false)

    def self.next_position(position, targets, succeeded)
      units = position.units.map do |unit|
        from = unit.location.province
        succeeded.include?(from) ? TA::Unit.new(power: unit.power, type: unit.type, location: targets[from]) : unit
      end
      occupied = units.map { |u| u.location.province }
      contested = targets.values.group_by(&:province).select { |_, list| list.size > 1 }.keys
      TA::Position.new(map: position.map, season: position.season, year: position.year, phase: :retreat, units: units,
                       ownership: position.ownership, dislodged_units: [], standoffs: contested - occupied)
    end

    private_class_method :reject_duplicates, :target_of, :surviving_moves, :result_for, :outcome, :next_position
  end
```

Notes for the implementer:
- `TA` is a private constant of `RulesEngine`, readable lexically inside the nested module and `Data.define` blocks. A constant assigned inside a `Data.define` block lands on `RulesEngine` (the block's lexical scope), so `KEYS` becomes `RulesEngine::KEYS`; make it `OUTCOME_KEYS` and `private_constant` it, next to `RESULTS`.
- `reject_duplicates` runs after `TA.check` has run on every element, so a non-order element raises the gem's own `InvalidInput` first.
- The head comment's rule list must match FR-3 in the spec exactly; FR-3 is the reference.

**Verify:** Phase 4 specs green, then the full `bundle exec rspec`. Commit: "Add the stand-in adjudicator to RulesEngine, with its specs".

## Phase 5: Stored gem objects

**Implements:** FR-4, FR-5, FR-6 (storage), AC-4.x. **Files:** `spec/models/stored_gem_objects_spec.rb`, `app/models/rules_object_type.rb`

### 5a. Spec first

The spec builds its own table and model (nothing in `db/`):

```ruby
require "rails_helper"
require_relative "../support/rules_helpers"

RSpec.describe "Stored gem objects (spec 019, Story 4)" do
  include RulesHelpers

  before(:all) do
    ActiveRecord::Schema.define do
      create_table :rules_storage_rows, force: true do |t|
        t.string :label
        t.json :board
        t.json :move
        t.json :verdict
        t.json :result
      end
    end
    @model = Class.new(ApplicationRecord) do
      self.table_name = "rules_storage_rows"
      def self.name = "RulesStorageRow"
      attribute :board, RulesObjectType.position
      attribute :move, RulesObjectType.order
      attribute :verdict, RulesObjectType.check_result
      attribute :result, RulesObjectType.adjudication
    end
  end

  after(:all) { ActiveRecord::Schema.define { drop_table :rules_storage_rows, if_exists: true } }

  let(:model) { @model }
  let(:start) { RulesEngine.starting_position }

  def raw(record, column) = model.connection.select_value("SELECT #{column} FROM rules_storage_rows WHERE id = #{record.id}")
  def insert_raw(column, text)
    model.connection.execute("INSERT INTO rules_storage_rows (#{column}) VALUES (#{model.connection.quote(text)})")
    model.order(:id).last
  end
```

Examples (each is a full `it`, one per AC):
- AC-4.1: save and `reload`/`find` the starting position and a position with a split-coast fleet (`rules_position(units: [[:france, :fleet, :spa, :nc]])`); equal.
- AC-4.2: each of the six order types, same hashes as Phase 2's `order_hashes`; loaded `be_a` check by comparing `order.class` to the original's class.
- AC-4.3: a legal and an illegal check result.
- AC-4.4: a stand-in adjudication (`RulesEngine.adjudicate(start, [move(:england, :lon, :nth)])`).
- AC-4.5: `JSON.parse(raw(record, "board"))` equals `start.to_h` and `raw(record, "board")` includes `"format":1`.
- AC-4.6: nil saves as SQL NULL (`raw` is nil) and loads as nil.
- AC-4.7: assigning `start.to_h` saves and loads the equal position.
- AC-4.7a: `record.board = 5`, a String, `start.to_h.transform_keys(&:to_sym)`, an order given to the position attribute — each raises `RulesEngine::InvalidInput` at assignment; also `model.new(board: 5)`.
- AC-4.8: `insert_raw("board", JSON.generate(start.to_h.merge("format" => 2)))`, then `model.find(id).board` raises `RulesEngine::InvalidInput`.
- AC-4.9: the raised message includes `2` (the bad value): `/2/`.
- AC-4.9a: `insert_raw("board", "not json")` raises `JSON::ParserError`; `insert_raw("board", "[]")` raises `InvalidInput`; `insert_raw("board", "null")` loads as nil.
- AC-4.9b: a row with a bad `board`; `record = model.find(id); record.update!(label: "x")` does not raise and `raw(record, "board")` is unchanged.
- AC-4.10: after the group, the table is dropped: checked by a separate trailing `after(:all)` expectation is not possible, so verify with `git status --porcelain db` in the phase's verify step, and with an example that asserts `ActiveRecord::Base.connection.table_exists?("rules_storage_rows")` is true *inside* the group (it exists during, and `after(:all)` removes it).

**Verify:** red with `uninitialized constant RulesObjectType`.

### 5b. The type

`app/models/rules_object_type.rb`:

```ruby
# An ActiveRecord attribute type that stores one kind of rules object (a position, an order, a check
# result or an adjudication) as the JSON text of its hash form, and loads it back through RulesEngine
# (spec 019, FR-4). It names no gem class. An unknown format is not rescued or repaired: the
# InvalidInput from the loader reaches the caller (FR-5).
class RulesObjectType < ActiveRecord::Type::Value
  KINDS = %i[position order check_result adjudication].freeze
  KINDS.each { |kind| define_singleton_method(kind) { new(kind) } }

  attr_reader :kind

  def initialize(kind)
    raise ArgumentError, "kind must be one of #{KINDS.inspect}, got #{kind.inspect}" unless KINDS.include?(kind)

    super()
    @kind = kind
  end

  def type = :"rules_#{kind}"

  # A bad value fails at assignment, not on a later read (ActiveModel otherwise casts lazily).
  def assert_valid_value(value) = load(value)

  def cast(value) = load(value)

  def serialize(value)
    object = load(value)
    object && JSON.generate(object.to_h)
  end

  def deserialize(raw)
    return nil if raw.nil?

    load(JSON.parse(raw))
  end

  # The objects are immutable, so a save never re-reads an untouched column.
  def changed_in_place?(_raw_old_value, _new_value) = false

  def ==(other) = other.is_a?(RulesObjectType) && other.kind == kind
  alias_method :eql?, :==
  def hash = [ self.class, kind ].hash

  private

  def load(value) = RulesEngine.public_send(:"load_#{kind}", value)
end
```

**Verify:** `bundle exec rspec spec/models/stored_gem_objects_spec.rb` green; `git status --porcelain db` empty. If `serialize` of a hash-assigned value turns out to double-load (cast already loaded it), that is harmless (loaders return objects as they are). Commit: "Add attribute types that store rules objects as JSON, with their specs".

## Phase 6: Docs, the full run and the pull request

**Implements:** FR-8, AC-5.3. **Files:** `AGENTS.md`

Add one bullet under "The adjudicator gem" in `AGENTS.md`:

```
- Every call to the gem goes through `RulesEngine` (`app/models/rules_engine.rb`), the only file that requires it or names its constants; `spec/models/rules_engine_boundary_spec.rb` fails if any other code does. Stored columns use `RulesObjectType`. Until gem 0.2.0, `RulesEngine.adjudicate` is a stand-in whose outcomes are fake.
```

Then, from `web/`:

1. `bundle exec rspec` passes (record the counts).
2. `BUNDLE_FROZEN=true bundle install` with the variable unset succeeds and `git diff --exit-code Gemfile.lock` is clean. (AC-1.2)
3. `ADJUDICATOR_PATH=../adjudicator BUNDLE_FROZEN=false bundle install && ... bundle exec rspec`, then `git checkout -- Gemfile.lock`. (AC-1.3)
4. `git diff --name-only main...HEAD` lists only `web/` paths.
5. `bin/rubocop` on the changed Ruby files, and `bin/brakeman -q` if the app already runs it in CI (it does not; skip if not configured).

Push (first push opens a draft pull request from `.github/pull_request_template.md`, "Closes #19"). Then:

6. Start the early-warning workflow by hand on the branch: `gh workflow run early-warning.yml --ref web/19-adjudicator-boundary`, wait for it, link the run in the pull request. (It does not run on web-only pull requests.)
7. Wait for `Web specs` to be green.
8. Implementation review by a read-only Opus subagent, findings and handling recorded in the pull request description.
9. `gh pr ready`, then `gh pr edit --add-assignee @me`.

The pull request description lists, for the maintainer, the stale lines that name the missing pin, so the root Issue can cite them:

- `docs/repository-layout.md` line 82 ("The app doesn't depend on the gem yet (Issue #19 adds the pin), so for now it runs the app's own specs.") and line 83 ("That takes effect once `web/Gemfile` honors it (Issue #19); until then the job runs the same specs as the app job.").
- `.github/workflows/web.yml` lines 41 to 43 (comment: "The app does not depend on the gem yet (Issue #19 adds the pin), so today this runs the app's own specs.").
- `.github/workflows/early-warning.yml` lines 33 to 37 (comment: "web/Gemfile does not honor it yet (Issue #19 adds the switch). Until then the variable has no effect...").

## Coverage

| Spec item | Phase |
|---|---|
| FR-1, AC-1.1 to 1.5 | 2 |
| FR-2, AC-2.1 to 2.6, 2.5a, 2.5b | 1, 2 |
| FR-7, AC-2.7, 2.8, 2.8a, AC-5.1 | 2 (require: false), 3, 4 |
| FR-3, AC-3.1 to 3.11 | 4 |
| FR-4, FR-5, FR-6, AC-4.1 to 4.10 | 5 |
| AC-5.2 | 4 |
| FR-8, AC-5.3 | 6 |
| NFR (security, reliability) | 2 (pin, no credentials), 5 (no rescue) |

## Risks

- **Bundler and the git source.** If the git source fails to resolve, check the tag exists on the remote (it does: `git ls-remote --tags https://github.com/plainprogrammer/trucebearer.git adjudicator-v0.1.0`). The gemspec reads `../.ruby-version`, present in the checked-out repository. If `bundle install` needs the network and the sandbox has none, ask the coordinator.
- **ActiveModel behavior.** `assert_valid_value` and `changed_in_place?` are used as ActiveModel 8.1 defines them. If an example shows otherwise, fix the type, not the spec.
- **Words spec.** The stand-in's comments and names avoid words that begin with the three forbidden letters.

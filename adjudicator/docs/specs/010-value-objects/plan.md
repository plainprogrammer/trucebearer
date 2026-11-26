# Implementation Plan: Value objects for positions, units and orders

**Spec:** adjudicator/docs/specs/010-value-objects/spec.md (v1.2.0, Approved)
**Decisions:** none in `docs/adr/`. The recorded decisions are `docs/architecture.md` ("everything that crosses the boundary is an immutable value object built on `Data`, with `to_h`, `from_h` and a `format` version") and the contract in `adjudicator/docs/interface.md`.
**Created:** 2026-11-25

## Global Constraints

- **Read `spec.md` in full before starting any phase.** Where a phase cites an AC or FR, the spec's wording is what the code must satisfy.
- Change files in `adjudicator/` only. The spec and this plan ship in the same pull request.
- `docs/interface.md` changes in exactly one place: Phase 5 adds the two stricter rules to "Impossible objects" (AC-8.7, ruled at Gate A). If a phase shows anything else in the contract is wrong, stop and ask.
- Never give anything a name that contains or echoes the game's trademarked name or its three-letter prefix: files, classes, methods, specs, comments, commit messages.
- No copied rules text. No new dependency: standard library only, and `json` is used by the specs only.
- **Test first.** Each phase writes its specs, runs them, and sees them fail for the right reason before it writes any code. The examples spec (`interface_examples_spec.rb`) grows with each phase for the same reason: the interface examples for that phase's objects are written first.
- Run every command from `adjudicator/`. Spec files begin with `require "trucebearer/adjudicator"` and, from Phase 1, `require_relative "../../support/board"`. `.rspec` already loads `spec_helper`.
- `TA`, `L` and `O` stand for `Trucebearer::Adjudicator`, `TA::Location` and `TA::Order`, as in `interface.md`. Code files begin with `# frozen_string_literal: true`.
- Commit messages are plain imperative sentences, one commit per phase, each ending with the `Co-Authored-By:` trailer the session's attribution reminder gives (at the time of writing, `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`). One git operation per shell call.
- A phase is committed only when `bundle exec rspec` is green, with one exception: Phase 1, Step 1 commits the round-trip spec (and `spec/support/board.rb`) on its own, red, as the first code commit, so the history shows it was written first (AC-6.9). Nothing is pushed before Phase 5, so CI never sees a red commit. Until Phase 4 turns that spec green, the phases run the suite with `--exclude-pattern "**/starting_position_spec.rb"`.

## Pre-implementation gates

- **Simplicity:** five new code files, one concept each: `shape.rb` (the checks the classes share), `unit.rb` (`Unit`), `dislodged_unit.rb` (`DislodgedUnit`), `position.rb` (`Position`) and `order.rb` (the `Order` module and its six classes). `Map` gains one method. No dependency.
- **Anti-abstraction:** `Data.define` is used directly, as `Location` does. The one helper module, `Shape`, holds only the checks that three or more classes repeat (symbol and string identifiers, key sets, `format`). The six orders differ only in their field names, so one private builder, `Order.define`, makes them; writing six copies of the same `initialize`, `to_h` and `from_h` would give six places to get the shape rule wrong.
- **Integration-first:** the contract is `docs/interface.md`. Each phase's first spec is taken from its examples, and the very first spec of the feature is the starting-position round trip.

## Decisions the plan settles (spec left them open)

| Decision | Choice | Spec |
|---|---|---|
| Files | `lib/trucebearer/adjudicator/{shape,unit,dislodged_unit,position,order}.rb`, required from `lib/trucebearer/adjudicator.rb` after `location`, in that order | FR-1 to FR-4 |
| Format value | `Shape::FORMAT = 1`, the only place the number is written. `Position` and every order read it from there | AC-4.4 |
| `new` checks | Each `initialize` checks its fields and calls `super`. `Data` rejects a missing or unknown keyword itself, with `ArgumentError` | AC-1.10 |
| Order construction | `Order.define(type, *own_fields)` builds a `Data` class with `power`, `at` and the own fields; its `initialize` calls `super` first and then `Order.validate!`. The object is discarded if validation raises, so no invalid order escapes | FR-3 |
| Identifier checks | `new` side: `Shape.symbol_of` accepts only a member of the known list. `from_h` side: `Shape.text_of` finds the known symbol whose text matches, so text from the caller is compared, never interned | FR-4, AC-4.6 |
| Known lists | `Shape::PROVINCES`, `POWERS` and `SUPPLY_CENTERS` come from `Map.classic` when `shape.rb` loads (the map loads first), so the data file stays the only place they are written | FR-4 |
| Check order in `from_h` | Hash check, then `"format"`, then (orders) `"type"`, then the key set, then each field in field order | AC-3.5, AC-4.5 |
| Map identifier | `Shape.map!` accepts only a `String` equal to `"classic"` and returns `-value`, a frozen copy, so the caller's string is never held | AC-2.1 |
| Canonical order | Built in `Position#initialize`: `units` and `dislodged_units` by the unit's province, `standoffs` by identifier, `ownership` by province. The input arrays are copied before sorting | FR-2, AC-2.10 |
| `starting_position` | Built on each call (the map is frozen, so it cannot hold one) from `starting_units` and `home_centers` | FR-6 |
| Spec helpers | `spec/support/board.rb`: the constants `TA`, `L` and `O`, the exhaustive lists the map allows, and the `army`, `fleet` and `spring` objects of the interface examples | AC-7.4 |

## Files

| File | Change | Responsibility |
|---|---|---|
| `adjudicator/lib/trucebearer/adjudicator/shape.rb` | create | Internal checks shared by the value objects; `FORMAT` |
| `adjudicator/lib/trucebearer/adjudicator/unit.rb` | create | `TA::Unit` |
| `adjudicator/lib/trucebearer/adjudicator/dislodged_unit.rb` | create | `TA::DislodgedUnit` |
| `adjudicator/lib/trucebearer/adjudicator/position.rb` | create | `TA::Position` |
| `adjudicator/lib/trucebearer/adjudicator/order.rb` | create | `TA::Order`, `Order.from_h`, the six classes |
| `adjudicator/lib/trucebearer/adjudicator/map.rb` | edit | Add `Map#starting_position`; update the comment on `starting_units` |
| `adjudicator/lib/trucebearer/adjudicator.rb` | edit | Require the five new files |
| `adjudicator/spec/support/board.rb` | create | Shared constants and lists for the specs |
| `adjudicator/spec/trucebearer/adjudicator/unit_spec.rb` | create | `Unit` |
| `adjudicator/spec/trucebearer/adjudicator/dislodged_unit_spec.rb` | create | `DislodgedUnit` |
| `adjudicator/spec/trucebearer/adjudicator/position_spec.rb` | create | `Position`, canonical order, impossible positions, `with` |
| `adjudicator/spec/trucebearer/adjudicator/order_spec.rb` | create | The six orders and `Order.from_h` |
| `adjudicator/spec/trucebearer/adjudicator/starting_position_spec.rb` | create | `Map#starting_position` (the first spec written) |
| `adjudicator/spec/trucebearer/adjudicator/interface_examples_spec.rb` | create | Every interface example about these objects |
| `adjudicator/spec/trucebearer/adjudicator/map_spec.rb` | edit | Replace the "starting_position is not built" example |
| `adjudicator/docs/interface.md` | edit | Two lines in "Impossible objects" (Phase 5 only) |
| `adjudicator/CHANGELOG.md` | edit | "Added" entry, "Changed" line, trim the #9 sentence |

---

## Phase 1: The first failing spec, then `Shape`, `Unit` and `DislodgedUnit`

**Implements:** FR-1, FR-4 (identifier and key checks, `format` value), FR-5 (units) | **Satisfies:** AC-1.1 to AC-1.10, AC-5.2, AC-5.3, AC-5.4, AC-4.4 (the value), AC-7.1 (Location, Unit, DislodgedUnit examples)
**Files:** `spec/support/board.rb`, `starting_position_spec.rb`, `unit_spec.rb`, `dislodged_unit_spec.rb`, `interface_examples_spec.rb`, `shape.rb`, `unit.rb`, `dislodged_unit.rb`, `lib/trucebearer/adjudicator.rb`

### Step 1: The round-trip spec (the first spec written), committed red

Create `spec/trucebearer/adjudicator/starting_position_spec.rb` with the round trip only. It is the test the Issue names first.

```ruby
# frozen_string_literal: true

require "json"
require "trucebearer/adjudicator"
require_relative "../../support/board"

RSpec.describe "Map#starting_position" do
  it "round-trips through JSON, with 22 units and 22 owned centers (AC-6.5)" do
    start = TA::Map.classic.starting_position
    rebuilt = TA::Position.from_h(JSON.parse(JSON.generate(start.to_h)))
    expect(rebuilt).to eq(start)
    expect(rebuilt.units.size).to eq(22)
    expect(rebuilt.ownership.size).to eq(22)
  end
end
```

It needs `spec/support/board.rb`, which is created in the same step (see Step 2 for its text; create it before running the spec). Run the spec:

```sh
bundle exec rspec spec/trucebearer/adjudicator/starting_position_spec.rb
```

Expected: fails with `NoMethodError: undefined method 'starting_position' for an instance of Trucebearer::Adjudicator::Map`. Commit this spec and `spec/support/board.rb` now, as the red first commit: "Add the failing starting-position round-trip spec". Phase 4 extends the spec and turns it green.

### Step 2: Shared spec helpers

Create `spec/support/board.rb`. `O` is added in Phase 3, when `TA::Order` exists.

```ruby
# frozen_string_literal: true

require "trucebearer/adjudicator"

TA = Trucebearer::Adjudicator unless defined?(TA)
L = TA::Location unless defined?(L)

# What the classic map allows, for the specs that try every case, and the example
# objects that docs/interface.md reuses (army, fleet, spring).
module Board
  module_function

  def map = TA::Map.classic
  def provinces = map.provinces.map(&:id)                                   # 75
  def powers = map.powers.map(&:id)                                         # 7
  def inland = map.provinces.select { |p| p.type == :inland }.map(&:id)     # 14
  def sea = map.provinces.select { |p| p.type == :sea }.map(&:id)           # 19
  def split = map.provinces.reject { |p| p.coasts.empty? }                  # bul, spa, stp
  def army_provinces = map.provinces.reject { |p| p.type == :sea }.map(&:id)   # 56

  # 64 places a fleet can stand: seas, coastal provinces, and each split coast.
  def fleet_locations
    map.provinces.reject { |p| p.type == :inland }.flat_map do |p|
      p.coasts.empty? ? [L.new(province: p.id)] : p.coasts.map { |c| L.new(province: p.id, coast: c) }
    end
  end

  # 81 locations: every province with no coast, and the six split coasts.
  def locations
    provinces.map { |id| L.new(province: id) } +
      split.flat_map { |p| p.coasts.map { |c| L.new(province: p.id, coast: c) } }
  end

  def army = TA::Unit.new(power: :austria, type: :army, location: L.new(province: :bud))
  def fleet = TA::Unit.new(power: :russia, type: :fleet, location: L.new(province: :stp, coast: :sc))
  def spring = { map: "classic", season: :spring, year: 1901, phase: :movement, dislodged_units: [], standoffs: [] }
end
```

### Step 3: Write the Phase 1 specs, and watch them fail

Create `spec/trucebearer/adjudicator/unit_spec.rb`:

```ruby
# frozen_string_literal: true

require "json"
require "trucebearer/adjudicator"
require_relative "../../support/board"

RSpec.describe Trucebearer::Adjudicator::Unit do
  let(:unit) { described_class.new(power: :russia, type: :fleet, location: L.new(province: :stp, coast: :sc)) }

  describe ".new" do
    it "keeps the fields, is frozen, and equals a unit with the same contents (AC-1.1)" do
      expect([unit.power, unit.type, unit.location]).to eq([:russia, :fleet, L.new(province: :stp, coast: :sc)])
      expect(unit).to be_frozen
      twin = described_class.new(power: :russia, type: :fleet, location: L.new(province: :stp, coast: :sc))
      expect([unit == twin, unit.eql?(twin), unit.hash == twin.hash]).to eq([true, true, true])
      expect(unit).not_to eq(described_class.new(power: :russia, type: :army, location: L.new(province: :stp)))
    end

    it "rejects a bad power, type or location, naming the value (AC-1.4)" do
      loc = L.new(province: :par)
      expect { described_class.new(power: "russia", type: :army, location: loc) }.to raise_error(TA::InvalidInput, /"russia"/)
      expect { described_class.new(power: :atlantis, type: :army, location: loc) }.to raise_error(TA::InvalidInput, /:atlantis/)
      expect { described_class.new(power: :france, type: "army", location: loc) }.to raise_error(TA::InvalidInput, /"army"/)
      expect { described_class.new(power: :france, type: :ship, location: loc) }.to raise_error(TA::InvalidInput, /:ship/)
      [{ "province" => "par", "coast" => nil }, :par, nil].each do |bad|
        expect { described_class.new(power: :france, type: :army, location: bad) }.to raise_error(TA::InvalidInput, /#{Regexp.escape(bad.inspect)}/)
      end
    end

    it "raises ArgumentError, not InvalidInput, for a missing or unknown keyword (AC-1.10)" do
      expect { described_class.new(power: :france, type: :army) }.to raise_error(ArgumentError)
      expect { described_class.new(power: :france, type: :army, location: L.new(province: :par), extra: 1) }.to raise_error(ArgumentError)
      expect { L.new }.to raise_error(ArgumentError) # the #9 behavior, pinned (AC-1.10)
    end
  end

  describe "placement (AC-5.2 to AC-5.4)" do
    it "refuses a fleet in every inland province and an army in every sea province" do
      Board.inland.each do |id|
        expect { described_class.new(power: :germany, type: :fleet, location: L.new(province: id)) }
          .to raise_error(TA::InvalidInput, /#{id.inspect}/)
      end
      Board.sea.each do |id|
        expect { described_class.new(power: :england, type: :army, location: L.new(province: id)) }
          .to raise_error(TA::InvalidInput, /#{id.inspect}/)
      end
    end

    it "refuses an army that names a coast, for all six split coasts" do
      Board.split.each do |province|
        province.coasts.each do |coast|
          expect { described_class.new(power: :france, type: :army, location: L.new(province: province.id, coast: coast)) }
            .to raise_error(TA::InvalidInput, /#{province.id.inspect}.*#{coast.inspect}/m)
        end
      end
    end

    it "refuses a fleet on a split-coast province with no coast, and accepts one with a coast" do
      Board.split.each do |province|
        expect { described_class.new(power: :france, type: :fleet, location: L.new(province: province.id)) }
          .to raise_error(TA::InvalidInput, /#{province.id.inspect}/)
        province.coasts.each do |coast|
          expect(described_class.new(power: :france, type: :fleet, location: L.new(province: province.id, coast: coast))).to be_a(described_class)
        end
      end
    end

    it "refuses an impossible change made with #with (AC-5.11)" do
      army = described_class.new(power: :germany, type: :army, location: L.new(province: :mun))
      expect { army.with(type: :fleet) }.to raise_error(TA::InvalidInput, /:mun/)
      expect { army.with(power: :xyz) }.to raise_error(TA::InvalidInput, /:xyz/)
    end
  end

  describe "#to_h (AC-1.2)" do
    it "gives string keys and no format" do
      expect(unit.to_h).to eq("power" => "russia", "type" => "fleet", "location" => { "province" => "stp", "coast" => "sc" })
      expect(unit.to_h.keys).to eq(%w[power type location])
    end
  end

  describe ".from_h" do
    let(:valid) { unit.to_h }

    it "round-trips all 840 valid units through JSON (AC-1.3)" do
      count = 0
      Board.powers.each do |power|
        Board.army_provinces.each do |id|
          army = described_class.new(power: power, type: :army, location: L.new(province: id))
          expect(described_class.from_h(JSON.parse(JSON.generate(army.to_h)))).to eq(army)
          count += 1
        end
        Board.fleet_locations.each do |location|
          fleet = described_class.new(power: power, type: :fleet, location: location)
          expect(described_class.from_h(JSON.parse(JSON.generate(fleet.to_h)))).to eq(fleet)
          count += 1
        end
      end
      expect(count).to eq(840)
    end

    it "rejects a bad shape, naming the key or value (AC-1.5)" do
      expect { described_class.from_h(valid.merge("power" => :russia)) }.to raise_error(TA::InvalidInput, /:russia/)
      expect { described_class.from_h(valid.merge("power" => "atlantis")) }.to raise_error(TA::InvalidInput, /"atlantis"/)
      expect { described_class.from_h(valid.merge("type" => "ship")) }.to raise_error(TA::InvalidInput, /"ship"/)
      expect { described_class.from_h(valid.merge("location" => "stp")) }.to raise_error(TA::InvalidInput, /"stp"/)
      expect { described_class.from_h(valid.merge("location" => valid["location"].merge("format" => 1))) }.to raise_error(TA::InvalidInput, /"format"/)
      expect { described_class.from_h(valid.reject { |k, _| k == "type" }) }.to raise_error(TA::InvalidInput, /"type"/)
      expect { described_class.from_h(valid.merge("extra" => 1)) }.to raise_error(TA::InvalidInput, /"extra"/)
      expect { described_class.from_h(valid.transform_keys(&:to_sym)) }.to raise_error(TA::InvalidInput, /"power"/)
      expect { described_class.from_h([valid]) }.to raise_error(TA::InvalidInput, /\[\{/)
    end

    it "does not change the hash it is given, and accepts a frozen one (AC-2.9)" do
      frozen = Ractor.make_shareable(JSON.parse(JSON.generate(valid)))
      before = Marshal.load(Marshal.dump(frozen))
      expect(described_class.from_h(frozen)).to eq(unit)
      expect(frozen).to eq(before)
    end

    it "refuses an impossible unit written as a hash (AC-5.10)" do
      expect { described_class.from_h("power" => "germany", "type" => "fleet", "location" => { "province" => "mun", "coast" => nil }) }.to raise_error(TA::InvalidInput, /:mun/)
      expect { described_class.from_h("power" => "france", "type" => "fleet", "location" => { "province" => "spa", "coast" => nil }) }.to raise_error(TA::InvalidInput, /:spa/)
      expect { described_class.from_h("power" => "england", "type" => "army", "location" => { "province" => "nth", "coast" => nil }) }.to raise_error(TA::InvalidInput, /:nth/)
      expect { described_class.from_h("power" => "france", "type" => "army", "location" => { "province" => "spa", "coast" => "nc" }) }.to raise_error(TA::InvalidInput, /:spa/)
    end
  end
end
```

Create `spec/trucebearer/adjudicator/dislodged_unit_spec.rb`:

```ruby
# frozen_string_literal: true

require "json"
require "trucebearer/adjudicator"
require_relative "../../support/board"

RSpec.describe Trucebearer::Adjudicator::DislodgedUnit do
  let(:serbian_army) { TA::Unit.new(power: :austria, type: :army, location: L.new(province: :ser)) }
  let(:dislodged) { described_class.new(unit: serbian_army, attacker_from: :bul, by_convoy: false) }

  it "keeps its fields, is frozen, and equals one with the same contents (AC-1.6)" do
    expect([dislodged.unit, dislodged.attacker_from, dislodged.by_convoy]).to eq([serbian_army, :bul, false])
    expect(dislodged).to be_frozen
    expect(dislodged).to eq(described_class.new(unit: serbian_army, attacker_from: :bul, by_convoy: false))
    expect(dislodged.hash).to eq(described_class.new(unit: serbian_army, attacker_from: :bul, by_convoy: false).hash)
  end

  it "gives the hash form of the interface example, with no format (AC-1.6)" do
    expect(dislodged.to_h).to eq(
      "unit" => { "power" => "austria", "type" => "army", "location" => { "province" => "ser", "coast" => nil } },
      "attacker_from" => "bul", "by_convoy" => false
    )
    expect(dislodged.to_h.keys).to eq(%w[unit attacker_from by_convoy])
  end

  it "round-trips for both by_convoy values and an attacker from every province (AC-1.7)" do
    Board.provinces.each do |from|
      [true, false].each do |convoy|
        built = described_class.new(unit: serbian_army, attacker_from: from, by_convoy: convoy)
        expect(described_class.from_h(JSON.parse(JSON.generate(built.to_h)))).to eq(built)
      end
    end
  end

  it "rejects a bad unit, attacker or by_convoy, naming the value (AC-1.8)" do
    expect { described_class.new(unit: { "power" => "austria" }, attacker_from: :bul, by_convoy: false) }.to raise_error(TA::InvalidInput, /austria/)
    ["bul", L.new(province: :bul), nil, :xyz].each do |bad|
      expect { described_class.new(unit: serbian_army, attacker_from: bad, by_convoy: false) }
        .to raise_error(TA::InvalidInput, /#{Regexp.escape(bad.inspect)}/)
    end
    [nil, "false", 0].each do |bad|
      expect { described_class.new(unit: serbian_army, attacker_from: :bul, by_convoy: bad) }
        .to raise_error(TA::InvalidInput, /#{Regexp.escape(bad.inspect)}/)
    end
  end

  it "rejects a bad hash, naming the key or value (AC-1.9)" do
    valid = dislodged.to_h
    expect { described_class.from_h(valid.merge("attacker_from" => :bul)) }.to raise_error(TA::InvalidInput, /:bul/)
    expect { described_class.from_h(valid.merge("attacker_from" => { "province" => "spa", "coast" => "nc" })) }.to raise_error(TA::InvalidInput, /"coast" => "nc"/)
    expect { described_class.from_h(valid.merge("by_convoy" => "true")) }.to raise_error(TA::InvalidInput, /"true"/)
    expect { described_class.from_h(valid.merge("attacker_from" => "xyz")) }.to raise_error(TA::InvalidInput, /"xyz"/)
    expect { described_class.from_h(valid.merge("unit" => { "power" => "austria" })) }.to raise_error(TA::InvalidInput, /"type"/)
    expect { described_class.from_h(valid.reject { |k, _| k == "by_convoy" }) }.to raise_error(TA::InvalidInput, /"by_convoy"/)
    expect { described_class.from_h(valid.merge("extra" => 1)) }.to raise_error(TA::InvalidInput, /"extra"/)
    expect { described_class.from_h("nope") }.to raise_error(TA::InvalidInput, /"nope"/)
  end

  it "raises ArgumentError for a missing keyword (AC-1.10)" do
    expect { described_class.new(unit: serbian_army, attacker_from: :bul) }.to raise_error(ArgumentError)
  end

  it "leaves the hash it is given alone, accepts a frozen one, and holds no reference to it (AC-2.9)" do
    parsed = JSON.parse(JSON.generate(dislodged.to_h))
    before = Marshal.load(Marshal.dump(parsed))
    built = described_class.from_h(parsed)
    expect(parsed).to eq(before)
    parsed["unit"]["power"] << "x"
    expect(built).to eq(dislodged)
    expect(described_class.from_h(Ractor.make_shareable(JSON.parse(JSON.generate(dislodged.to_h))))).to eq(dislodged)
  end
end
```

Create `spec/trucebearer/adjudicator/interface_examples_spec.rb` with the Phase 1 examples. Later phases add `describe` blocks to this file. The header names what is excluded (AC-7.3).

```ruby
# frozen_string_literal: true

require "json"
require "trucebearer/adjudicator"
require_relative "../../support/board"

# Every Ruby example in docs/interface.md that is about the value objects built by
# issue #10 (Location, Unit, DislodgedUnit, Position, Order and its six classes,
# Canonical order, Impossible objects, Map#starting_position, and the from_h examples
# under Errors), run as a spec. Each example is built as the document builds it.
#
# Excluded, because they belong to later issues (AC-7.3):
#   - both TA::CheckResult examples, and the three CheckResult lines at the end of
#     "Impossible objects" (#11);
#   - the TA::Outcome and TA::Adjudication examples (#14);
#   - the TA.check, TA.legal_orders and TA.adjudicate calls in their own sections.
RSpec.describe "docs/interface.md examples" do
  describe "TA::Location, TA::Unit and TA::DislodgedUnit" do
    it "gives the hash forms the document shows" do
      expect(L.new(province: :spa, coast: :nc).to_h).to eq("province" => "spa", "coast" => "nc")
      expect(L.new(province: :bud).to_h).to eq("province" => "bud", "coast" => nil)
      expect(TA::Unit.new(power: :russia, type: :fleet, location: L.new(province: :stp, coast: :sc)).to_h)
        .to eq("power" => "russia", "type" => "fleet", "location" => { "province" => "stp", "coast" => "sc" })
      expect(TA::DislodgedUnit.new(
        unit: TA::Unit.new(power: :austria, type: :army, location: L.new(province: :ser)),
        attacker_from: :bul, by_convoy: false
      ).to_h).to eq("unit" => { "power" => "austria", "type" => "army", "location" => { "province" => "ser", "coast" => nil } },
                    "attacker_from" => "bul", "by_convoy" => false)
    end
  end
end
```

Run:

```sh
bundle exec rspec spec/trucebearer/adjudicator/unit_spec.rb spec/trucebearer/adjudicator/dislodged_unit_spec.rb
```

Expected: every example fails with `NameError: uninitialized constant Trucebearer::Adjudicator::Unit` (the interface-examples spec fails the same way). That is the right reason.

### Step 4: Code

Create `lib/trucebearer/adjudicator/shape.rb`:

```ruby
# frozen_string_literal: true

module Trucebearer
  module Adjudicator
    # Internal: the checks the value objects share. Not part of docs/interface.md,
    # and it may change in any release.
    module Shape
      # The one format value for the whole gem. It goes up whenever any hash form changes.
      FORMAT = 1

      SEASONS = %i[spring fall].freeze
      PHASES = %i[movement retreat adjustment].freeze
      UNIT_TYPES = %i[army fleet].freeze
      PROVINCES = Map.classic.provinces.map(&:id).freeze
      SUPPLY_CENTERS = Map.classic.supply_centers
      POWERS = Map.classic.powers.map(&:id).freeze

      module_function

      # `new` side: the value must be one of the allowed symbols.
      def symbol_of(value, allowed, name, noun)
        return value if allowed.include?(value)

        raise InvalidInput, "#{name.inspect} must be a #{noun} identifier (a Symbol), got #{value.inspect}"
      end

      # `from_h` side: the value must be the text of one of the allowed symbols. The
      # symbol returned is the existing one, so unchecked text never becomes a symbol.
      def text_of(value, allowed, name, noun)
        found = allowed.find { |candidate| candidate.to_s == value }
        return found if found

        raise InvalidInput, "#{name.inspect} must be a #{noun} identifier (a String), got #{value.inspect}"
      end

      def instance_of!(value, klass, name)
        return value if value.is_a?(klass)

        raise InvalidInput, "#{name.inspect} must be a #{klass}, got #{value.inspect}"
      end

      def integer!(value, name)
        return value if value.is_a?(Integer)

        raise InvalidInput, "#{name.inspect} must be an Integer, got #{value.inspect}"
      end

      def boolean!(value, name)
        return value if value == true || value == false

        raise InvalidInput, "#{name.inspect} must be true or false, got #{value.inspect}"
      end

      # The map identifier is the String "classic" in Ruby and in the hash form.
      # Returns a frozen copy, so the caller's string is never held or changed.
      def map!(value)
        unless value.is_a?(String) && value == "classic"
          raise InvalidInput, "\"map\" must be the String \"classic\", got #{value.inspect}"
        end

        -value
      end

      # Returns a new array, so the caller's array is never frozen or changed.
      def list_of(value, klass, name)
        array!(value, name).each { |element| instance_of!(element, klass, name) }.dup
      end

      def array!(value, name)
        raise InvalidInput, "#{name.inspect} must be an Array, got #{value.inspect}" unless value.is_a?(Array)

        value
      end

      def hash!(value, name)
        raise InvalidInput, "#{name} must be a Hash, got #{value.inspect}" unless value.is_a?(Hash)

        value
      end

      # A hash form has exactly these string keys.
      def keys!(hash, keys)
        hash!(hash, "hash form")
        (keys - hash.keys).each { |key| raise InvalidInput, "missing key #{key.inspect}" }
        (hash.keys - keys).each { |key| raise InvalidInput, "unknown key #{key.inspect}" }
      end

      # A storable hash form must carry the gem's format value. eql? so that 1.0 is refused.
      def format!(hash)
        hash!(hash, "hash form")
        raise InvalidInput, "missing key \"format\"" unless hash.key?("format")
        return if hash["format"].eql?(FORMAT)

        raise InvalidInput, "unknown format #{hash["format"].inspect}, expected #{FORMAT}"
      end

      def unique!(values, message)
        repeated = values.tally.find { |_, count| count > 1 }
        raise InvalidInput, "#{message} #{repeated.first.inspect}" if repeated
      end
    end
    private_constant :Shape
  end
end
```

Create `lib/trucebearer/adjudicator/unit.rb`:

```ruby
# frozen_string_literal: true

module Trucebearer
  module Adjudicator
    # An army or a fleet on the board. Carries no format (it only appears nested).
    Unit = Data.define(:power, :type, :location) do
      def initialize(power:, type:, location:)
        Shape.symbol_of(power, Shape::POWERS, "power", "power")
        Shape.symbol_of(type, Shape::UNIT_TYPES, "type", "unit type")
        Shape.instance_of!(location, Location, "location")
        check_placement(type, location)
        super
      end

      def to_h
        { "power" => power.to_s, "type" => type.to_s, "location" => location.to_h }
      end

      def self.from_h(hash)
        Shape.keys!(hash, %w[power type location])
        new(power: Shape.text_of(hash["power"], Shape::POWERS, "power", "power"),
            type: Shape.text_of(hash["type"], Shape::UNIT_TYPES, "type", "unit type"),
            location: Location.from_h(hash["location"]))
      end

      private

      def check_placement(type, location)
        province = Map.classic.province(location.province)
        if type == :army
          raise InvalidInput, "an army cannot stand on a sea province: #{location.inspect}" if province.type == :sea
          raise InvalidInput, "an army's location must not name a coast: #{location.inspect}" if location.coast
        else
          raise InvalidInput, "a fleet cannot stand on an inland province: #{location.inspect}" if province.type == :inland
          if location.coast.nil? && !province.coasts.empty?
            raise InvalidInput, "a fleet on a split-coast province must name a coast: #{location.inspect}"
          end
        end
      end
    end
  end
end
```

Create `lib/trucebearer/adjudicator/dislodged_unit.rb`:

```ruby
# frozen_string_literal: true

module Trucebearer
  module Adjudicator
    # A unit pushed out of its province, waiting to retreat. Carries no format.
    DislodgedUnit = Data.define(:unit, :attacker_from, :by_convoy) do
      def initialize(unit:, attacker_from:, by_convoy:)
        Shape.instance_of!(unit, Unit, "unit")
        Shape.symbol_of(attacker_from, Shape::PROVINCES, "attacker_from", "province")
        Shape.boolean!(by_convoy, "by_convoy")
        super
      end

      def to_h
        { "unit" => unit.to_h, "attacker_from" => attacker_from.to_s, "by_convoy" => by_convoy }
      end

      def self.from_h(hash)
        Shape.keys!(hash, %w[unit attacker_from by_convoy])
        new(unit: Unit.from_h(hash["unit"]),
            attacker_from: Shape.text_of(hash["attacker_from"], Shape::PROVINCES, "attacker_from", "province"),
            by_convoy: hash["by_convoy"])
      end
    end
  end
end
```

Edit `lib/trucebearer/adjudicator.rb`: after `require_relative "adjudicator/location"` add

```ruby
require_relative "adjudicator/shape"
require_relative "adjudicator/unit"
require_relative "adjudicator/dislodged_unit"
```

(`position` and `order` are required in Phases 2 and 3, so each phase loads.)

### Verification

```sh
bundle exec rspec spec/trucebearer/adjudicator/unit_spec.rb spec/trucebearer/adjudicator/dislodged_unit_spec.rb spec/trucebearer/adjudicator/interface_examples_spec.rb
bundle exec rspec --exclude-pattern "**/starting_position_spec.rb"
```

Expected: all pass, 0 failures. Commit: "Add Unit and DislodgedUnit value objects".

---

## Phase 2: `Position`

**Implements:** FR-2, FR-4, FR-5 (positions) | **Satisfies:** AC-2.1 to AC-2.10, AC-4.1 (position), AC-4.2 (position), AC-4.3 (position), AC-4.5, AC-5.1, AC-5.5 to AC-5.12, AC-7.1 (Position, Canonical order, Impossible objects), AC-7.2 (Errors examples)
**Files:** `position_spec.rb`, `interface_examples_spec.rb`, `position.rb`, `lib/trucebearer/adjudicator.rb`

### Step 1: Specs first

Create `spec/trucebearer/adjudicator/position_spec.rb`:

```ruby
# frozen_string_literal: true

require "json"
require "trucebearer/adjudicator"
require_relative "../../support/board"

RSpec.describe Trucebearer::Adjudicator::Position do
  let(:army) { Board.army }
  let(:fleet) { Board.fleet }
  let(:fields) { Board.spring.merge(units: [army, fleet], ownership: { bud: :austria, stp: :russia }) }
  let(:position) { described_class.new(**fields) }
  let(:valid_hash) { position.to_h }

  def refuse(message = nil, **changes)
    expect { described_class.new(**fields.merge(changes)) }.to raise_error(TA::InvalidInput, message || //)
  end

  describe ".new" do
    it "freezes the object and its fields, and copies what it is given (AC-2.1)" do
      units = [fleet, army]
      ownership = { stp: :russia, bud: :austria }
      map = +"classic"
      built = described_class.new(**fields.merge(units: units, ownership: ownership, map: map))
      expect(built).to be_frozen
      expect([built.map, built.units, built.ownership, built.dislodged_units, built.standoffs]).to all(be_frozen)
      expect([units, ownership, map].map(&:frozen?)).to eq([false, false, false])
      units << army
      ownership[:ber] = :germany
      map << "x"
      expect(built).to eq(position)
      expect(built.map).to eq("classic")
    end

    it "keeps the eight fields, in the order the interface gives them" do
      expect(described_class.members).to eq(%i[map season year phase units ownership dislodged_units standoffs])
    end

    it "is equal, with the same hash, to a position with the same contents (AC-2.3)" do
      a = described_class.new(**Board.spring, units: [army, fleet], ownership: { bud: :austria, stp: :russia })
      b = described_class.new(**Board.spring, units: [fleet, army], ownership: { stp: :russia, bud: :austria })
      expect([a == b, a.eql?(b), a.hash == b.hash, a.to_h == b.to_h]).to eq([true, true, true, true])
      expect(b.units.map { _1.location.province }).to eq(%i[bud stp])
      expect(b.ownership.keys).to eq(%i[bud stp])
      expect(b.to_h["ownership"].keys).to eq(%w[bud stp])
    end

    it "sorts units and dislodged units by province, and standoffs by identifier (AC-2.4)" do
      spa = TA::Unit.new(power: :france, type: :fleet, location: L.new(province: :spa, coast: :sc))
      stp = TA::Unit.new(power: :russia, type: :army, location: L.new(province: :stp))
      d_stp = TA::DislodgedUnit.new(unit: stp, attacker_from: :fin, by_convoy: false)
      d_spa = TA::DislodgedUnit.new(unit: spa, attacker_from: :mar, by_convoy: true)
      built = described_class.new(**fields.merge(phase: :retreat, units: [stp, spa], dislodged_units: [d_stp, d_spa], standoffs: %i[tyr bur ruh]))
      expect(built.units).to eq([spa, stp])
      expect(built.dislodged_units).to eq([d_spa, d_stp])
      expect(built.standoffs).to eq(%i[bur ruh tyr])
      expect(described_class.from_h(built.to_h).units).to eq([spa, stp])
    end

    it "sorts the ownership it holds, as to_h writes it (AC-2.10)" do
      built = described_class.new(**fields.merge(ownership: { stp: :russia, bud: :austria, ank: :turkey }))
      expect(built.ownership.keys).to eq(%i[ank bud stp])
    end

    it "rejects a bad map, season, phase or year, naming the value (AC-2.6)" do
      refuse(/:classic/, map: :classic)
      refuse(/"modern"/, map: "modern")
      refuse(/"spring"/, season: "spring")
      refuse(/:summer/, season: :summer)
      refuse(/:build/, phase: :build)
      ["1901", 1901.0, nil].each { |bad| refuse(/#{Regexp.escape(bad.inspect)}/, year: bad) }
    end

    it "rejects a list field of the wrong kind (AC-2.6)" do
      refuse(/"units"/, units: "none")
      refuse(/\{"power"/, units: [army.to_h])
      refuse(/"dislodged_units"/, dislodged_units: nil)
      refuse(/"x"/, dislodged_units: ["x"])
      refuse(/1/, standoffs: [1])
      refuse(/"standoffs"/, standoffs: "bur")
      refuse(/"bur"/, standoffs: ["bur"])
      refuse(/:xyz/, standoffs: [:xyz])
      refuse(/"ownership"/, ownership: [])
    end

    it "rejects bad ownership keys and values (AC-2.7)" do
      refuse(/"bud"/, ownership: { "bud" => :austria })
      refuse(/:xyz/, ownership: { xyz: :austria })
      refuse(/"austria"/, ownership: { bud: "austria" })
      refuse(/nil/, ownership: { bel: nil })
      refuse(/:atlantis/, ownership: { bud: :atlantis })
    end

    it "raises ArgumentError for a missing or unknown keyword (AC-1.10)" do
      expect { described_class.new(**fields.reject { |k, _| k == :standoffs }) }.to raise_error(ArgumentError)
      expect { described_class.new(**fields.reject { |k, _| k == :dislodged_units }) }.to raise_error(ArgumentError)
      expect { described_class.new(**fields.merge(extra: 1)) }.to raise_error(ArgumentError)
    end
  end

  describe "#to_h" do
    it "gives the hash of the interface example, in its key order (AC-2.2)" do
      expect(valid_hash).to eq(
        "format" => 1, "map" => "classic", "season" => "spring", "year" => 1901, "phase" => "movement",
        "units" => [{ "power" => "austria", "type" => "army", "location" => { "province" => "bud", "coast" => nil } },
                    { "power" => "russia", "type" => "fleet", "location" => { "province" => "stp", "coast" => "sc" } }],
        "ownership" => { "bud" => "austria", "stp" => "russia" },
        "dislodged_units" => [], "standoffs" => []
      )
      expect(valid_hash.keys).to eq(%w[format map season year phase units ownership dislodged_units standoffs])
      expect(described_class.from_h(JSON.parse(JSON.generate(valid_hash)))).to eq(position)
    end

    it "writes only plain data, with string keys all the way down (AC-4.3)" do
      plain = lambda do |value|
        case value
        when Hash then value.all? { |k, v| k.is_a?(String) && plain.call(v) }
        when Array then value.all? { plain.call(_1) }
        else [String, Integer, true, false, nil].any? { |type| type === value }
        end
      end
      expect(plain.call(valid_hash)).to be(true)
      expect(valid_hash["units"].first).not_to have_key("format")
    end
  end

  describe ".from_h" do
    let(:retreat_fields) do
      d_army = TA::DislodgedUnit.new(unit: TA::Unit.new(power: :austria, type: :army, location: L.new(province: :ser)), attacker_from: :bul, by_convoy: false)
      d_fleet = TA::DislodgedUnit.new(unit: TA::Unit.new(power: :england, type: :fleet, location: L.new(province: :nth)), attacker_from: :nwy, by_convoy: true)
      Board.spring.merge(phase: :retreat, units: [army], ownership: { bud: :austria },
                         dislodged_units: [d_army, d_fleet], standoffs: %i[bur tyr])
    end

    it "round-trips positions of every phase through JSON (AC-2.5)" do
      empty = described_class.new(**Board.spring, units: [], ownership: {})
      fall = described_class.new(**Board.spring.merge(season: :fall, phase: :adjustment), units: [army], ownership: { bud: :austria, vie: :austria })
      [position, described_class.new(**retreat_fields), fall, empty].each do |built|
        expect(described_class.from_h(JSON.parse(JSON.generate(built.to_h)))).to eq(built)
      end
    end

    it "refuses a bad shape, naming the key or value (AC-2.8)" do
      bad = lambda do |changes, pattern|
        expect { described_class.from_h(valid_hash.merge(changes)) }.to raise_error(TA::InvalidInput, pattern)
      end
      bad.call({ "season" => :spring }, /:spring/)
      bad.call({ "year" => "1901" }, /"1901"/)
      bad.call({ "year" => 1901.5 }, /1901\.5/)
      bad.call({ "units" => "none" }, /"none"/)
      bad.call({ "dislodged_units" => {} }, /\{\}/)
      bad.call({ "standoffs" => "bur" }, /"bur"/)
      bad.call({ "units" => ["bud"] }, /"bud"/)
      bad.call({ "units" => [valid_hash["units"].first.reject { |k, _| k == "type" }] }, /"type"/)
      bad.call({ "units" => [valid_hash["units"].first.merge("extra" => 1)] }, /"extra"/)
      bad.call({ "units" => [valid_hash["units"].first.merge("format" => 1)] }, /"format"/)
      bad.call({ "units" => [valid_hash["units"].first.merge("location" => { "province" => "bud", "coast" => nil, "format" => 1 })] }, /"format"/)
      bad.call({ "standoffs" => [:bur] }, /:bur/)
      bad.call({ "standoffs" => [1] }, /1/)
      bad.call({ "dislodged_units" => ["x"] }, /"x"/)
      bad.call({ "ownership" => [] }, /\[\]/)
      bad.call({ "ownership" => { bud: "austria" } }, /:bud/)
      bad.call({ "ownership" => { "bud" => :austria } }, /:austria/)
      bad.call({ "ownership" => { "bud" => nil } }, /nil/)
      bad.call({ "map" => :classic }, /:classic/)
      expect { described_class.from_h(valid_hash.reject { |k, _| k == "year" }) }.to raise_error(TA::InvalidInput, /"year"/)
      expect { described_class.from_h(valid_hash.merge("extra" => 1)) }.to raise_error(TA::InvalidInput, /"extra"/)
      expect { described_class.from_h(valid_hash.transform_keys(&:to_sym)) }.to raise_error(TA::InvalidInput, /"format"/)
      expect { described_class.from_h("position") }.to raise_error(TA::InvalidInput, /"position"/)
    end

    it "checks the format first, and never accepts a hash for its format alone (AC-4.2, AC-4.5)" do
      expect { described_class.from_h(valid_hash.reject { |k, _| k == "format" }) }.to raise_error(TA::InvalidInput, /"format"/)
      [2, 0, "1", 1.0, nil].each do |bad|
        expect { described_class.from_h(valid_hash.merge("format" => bad)) }.to raise_error(TA::InvalidInput, /#{Regexp.escape(bad.inspect)}/)
      end
      expect { described_class.from_h(valid_hash.merge("year" => "1901")) }.to raise_error(TA::InvalidInput)
    end

    it "leaves its argument alone, accepts a frozen one, and holds no reference to it (AC-2.9)" do
      parsed = JSON.parse(JSON.generate(valid_hash))
      before = Marshal.load(Marshal.dump(parsed))
      built = described_class.from_h(parsed)
      expect(parsed).to eq(before)
      parsed["units"] << {}
      parsed["ownership"]["ber"] = "germany"
      parsed["map"] << "x"
      expect(built).to eq(position)
      expect(described_class.from_h(Ractor.make_shareable(JSON.parse(JSON.generate(valid_hash))))).to eq(position)
    end
  end

  describe "impossible positions (Story 5)" do
    it "refuses two units in one province, naming it, and lets a dislodged unit share one (AC-5.1)" do
      bur = ->(power) { TA::Unit.new(power: power, type: :army, location: L.new(province: :bur)) }
      refuse(/:bur/, units: [bur.call(:france), bur.call(:germany)], ownership: {})
      stp = [TA::Unit.new(power: :russia, type: :army, location: L.new(province: :stp)), fleet]
      refuse(/:stp/, units: stp, ownership: {})
      dislodged = TA::DislodgedUnit.new(unit: army, attacker_from: :boh, by_convoy: false)
      expect(described_class.new(**fields.merge(phase: :retreat, dislodged_units: [dislodged]))).to be_a(described_class)
    end

    it "refuses a map other than classic, from new and from from_h (AC-5.5)" do
      refuse(/"modern"/, map: "modern")
      expect { described_class.from_h(valid_hash.merge("map" => "modern")) }.to raise_error(TA::InvalidInput, /"modern"/)
    end

    it "refuses ownership of every province that is not a supply center, and accepts every supply center (AC-5.6)" do
      not_centers = Board.provinces - TA::Map.classic.supply_centers
      expect(not_centers.size).to eq(41)
      not_centers.each { |id| refuse(/#{id.inspect}/, ownership: { id => :france }) }
      expect(TA::Map.classic.supply_centers.size).to eq(34)
      TA::Map.classic.supply_centers.each do |id|
        expect(described_class.new(**fields.merge(ownership: { id => :france }))).to be_a(described_class)
      end
    end

    it "refuses standoffs and dislodged units in a movement phase, and allows them later (AC-5.7)" do
      refuse(/:movement/, standoffs: [:bur])
      dislodged = TA::DislodgedUnit.new(unit: fleet, attacker_from: :fin, by_convoy: false)
      refuse(/:movement/, dislodged_units: [dislodged], units: [army])
      %i[retreat adjustment].each do |phase|
        expect(described_class.new(**fields.merge(phase: phase, standoffs: [:bur], dislodged_units: [dislodged], units: [army]))).to be_a(described_class)
      end
    end

    it "refuses an unknown identifier anywhere one is accepted (AC-5.8)" do
      refuse(/:xyz/, standoffs: [:xyz])
      refuse(/:xyz/, ownership: { xyz: :austria })
      refuse(/:xyz/, phase: :retreat, standoffs: [:xyz])
      refuse(/:atlantis/, ownership: { bud: :atlantis })
    end

    it "refuses a repeated standoff, and two dislodged units in one province (AC-5.9)" do
      refuse(/:bur/, phase: :retreat, standoffs: %i[bur bur])
      first = TA::DislodgedUnit.new(unit: fleet, attacker_from: :fin, by_convoy: false)
      second = TA::DislodgedUnit.new(unit: fleet, attacker_from: :nwy, by_convoy: false)
      refuse(/:stp/, phase: :retreat, dislodged_units: [first, second])
    end

    it "refuses each impossible position written as a hash (AC-5.10)" do
      dup_unit = valid_hash["units"].first
      cases = {
        "two units in one province" => valid_hash.merge("units" => [dup_unit, dup_unit]),
        "a province that is not a supply center" => valid_hash.merge("ownership" => { "bur" => "france" }),
        "a standoff in a movement phase" => valid_hash.merge("standoffs" => ["bur"]),
        "a repeated standoff" => valid_hash.merge("phase" => "retreat", "standoffs" => %w[bur bur]),
        "an unknown power" => valid_hash.merge("ownership" => { "bud" => "atlantis" }),
        "a dislodged unit in a movement phase" => valid_hash.merge("dislodged_units" => [{ "unit" => fleet.to_h, "attacker_from" => "fin", "by_convoy" => false }]),
        "an unknown attacker_from" => valid_hash.merge("phase" => "retreat", "dislodged_units" => [{ "unit" => fleet.to_h, "attacker_from" => "xyz", "by_convoy" => false }])
      }
      cases.each do |name, hash|
        expect { described_class.from_h(hash) }.to raise_error(TA::InvalidInput), name
      end
      two = { "unit" => fleet.to_h, "attacker_from" => "fin", "by_convoy" => false }
      expect { described_class.from_h(valid_hash.merge("phase" => "retreat", "dislodged_units" => [two, two.merge("attacker_from" => "nwy")])) }
        .to raise_error(TA::InvalidInput, /:stp/)
    end

    it "refuses an impossible change made with #with, and sorts a valid one (AC-5.11, AC-5.12)" do
      with_standoff = described_class.new(**fields.merge(phase: :retreat, standoffs: [:bur]))
      expect { with_standoff.with(phase: :movement) }.to raise_error(TA::InvalidInput, /:movement/)
      units = [fleet, army]
      swapped = position.with(units: units)
      expect(swapped).to eq(position)
      expect(swapped).to be_frozen
      expect(swapped.units).to be_frozen
      expect(swapped.units.map { _1.location.province }).to eq(%i[bud stp])
      expect(units).not_to be_frozen
      expect(units).to eq([fleet, army])
    end
  end
end
```

Add to `interface_examples_spec.rb`, inside the top `RSpec.describe`, the Position, Canonical order, Impossible objects and Errors examples. Each is built as the document builds it:

```ruby
  describe "TA::Position, Canonical order and the Errors examples" do
    let(:army) { TA::Unit.new(power: :austria, type: :army, location: L.new(province: :bud)) }
    let(:fleet) { TA::Unit.new(power: :russia, type: :fleet, location: L.new(province: :stp, coast: :sc)) }
    let(:spring) { { map: "classic", season: :spring, year: 1901, phase: :movement, dislodged_units: [], standoffs: [] } }
    let(:a) { TA::Position.new(**spring, units: [army, fleet], ownership: { bud: :austria, stp: :russia }) }
    let(:b) { TA::Position.new(**spring, units: [fleet, army], ownership: { stp: :russia, bud: :austria }) }

    it "gives the position hash and round trip of the TA::Position example" do
      position = TA::Position.new(
        map: "classic", season: :spring, year: 1901, phase: :movement,
        units: [TA::Unit.new(power: :austria, type: :army, location: L.new(province: :bud)),
                TA::Unit.new(power: :russia, type: :fleet, location: L.new(province: :stp, coast: :sc))],
        ownership: { bud: :austria, stp: :russia },
        dislodged_units: [], standoffs: []
      )
      expect(position.to_h).to eq(
        "format" => 1, "map" => "classic", "season" => "spring", "year" => 1901, "phase" => "movement",
        "units" => [{ "power" => "austria", "type" => "army", "location" => { "province" => "bud", "coast" => nil } },
                    { "power" => "russia", "type" => "fleet", "location" => { "province" => "stp", "coast" => "sc" } }],
        "ownership" => { "bud" => "austria", "stp" => "russia" },
        "dislodged_units" => [], "standoffs" => []
      )
      expect(TA::Position.from_h(JSON.parse(JSON.generate(position.to_h))) == position).to be(true)
    end

    it "gives the Canonical order results" do
      expect(a == b).to be(true)
      expect(a.to_h == b.to_h).to be(true)
      expect(b.units.map { _1.location.province }).to eq(%i[bud stp])
      expect(b.to_h["ownership"].keys).to eq(%w[bud stp])
    end

    it "raises for each impossible object the document lists" do
      two_in_bur = [TA::Unit.new(power: :france, type: :army, location: L.new(province: :bur)),
                    TA::Unit.new(power: :germany, type: :army, location: L.new(province: :bur))]
      expect { TA::Position.new(**spring, ownership: {}, units: two_in_bur) }.to raise_error(TA::InvalidInput)
      expect { TA::Unit.new(power: :germany, type: :fleet, location: L.new(province: :mun)) }.to raise_error(TA::InvalidInput)
      expect { TA::Unit.new(power: :england, type: :army, location: L.new(province: :nth)) }.to raise_error(TA::InvalidInput)
      expect { TA::Unit.new(power: :france, type: :army, location: L.new(province: :spa, coast: :nc)) }.to raise_error(TA::InvalidInput)
      expect { TA::Unit.new(power: :france, type: :fleet, location: L.new(province: :spa)) }.to raise_error(TA::InvalidInput)
      expect { L.new(province: :par, coast: :nc) }.to raise_error(TA::InvalidInput)
      expect { L.new(province: :bul, coast: :nc) }.to raise_error(TA::InvalidInput)
      expect { L.new(province: :xyz) }.to raise_error(TA::InvalidInput)
      expect { TA::Position.from_h(JSON.parse(JSON.generate(a.to_h)).merge("map" => "modern")) }.to raise_error(TA::InvalidInput)
      expect { TA::Position.new(**spring, units: [army], ownership: { bur: :france }) }.to raise_error(TA::InvalidInput)
      expect { TA::Position.new(**spring.merge(standoffs: [:bur]), units: [army], ownership: {}) }.to raise_error(TA::InvalidInput)
      expect do
        TA::Position.new(**spring.merge(dislodged_units: [TA::DislodgedUnit.new(unit: fleet, attacker_from: :fin, by_convoy: false)]),
                         units: [army], ownership: {})
      end.to raise_error(TA::InvalidInput)
    end
  end
```

The `from_h` year example under Errors needs `starting_position`, so it is added in Phase 4.

Run:

```sh
bundle exec rspec spec/trucebearer/adjudicator/position_spec.rb spec/trucebearer/adjudicator/interface_examples_spec.rb
```

Expected: fail with `NameError: uninitialized constant Trucebearer::Adjudicator::Position`.

### Step 2: Code

Create `lib/trucebearer/adjudicator/position.rb`:

```ruby
# frozen_string_literal: true

module Trucebearer
  module Adjudicator
    # The state of the board at one moment. Storable: its hash form carries format.
    Position = Data.define(:map, :season, :year, :phase, :units, :ownership, :dislodged_units, :standoffs) do
      def initialize(map:, season:, year:, phase:, units:, ownership:, dislodged_units:, standoffs:)
        map = Shape.map!(map)
        Shape.symbol_of(season, Shape::SEASONS, "season", "season")
        Shape.symbol_of(phase, Shape::PHASES, "phase", "phase")
        Shape.integer!(year, "year")
        units = canonical_units(units)
        dislodged_units = canonical_dislodged(dislodged_units)
        standoffs = canonical_standoffs(standoffs)
        ownership = canonical_ownership(ownership)
        if phase == :movement && !(dislodged_units.empty? && standoffs.empty?)
          raise InvalidInput, "a position in phase #{phase.inspect} cannot hold dislodged units or standoffs"
        end

        super(map: map, season: season, year: year, phase: phase, units: units, ownership: ownership,
              dislodged_units: dislodged_units, standoffs: standoffs)
      end

      def to_h
        { "format" => Shape::FORMAT, "map" => map, "season" => season.to_s, "year" => year, "phase" => phase.to_s,
          "units" => units.map(&:to_h),
          "ownership" => ownership.to_h { |center, power| [center.to_s, power.to_s] },
          "dislodged_units" => dislodged_units.map(&:to_h),
          "standoffs" => standoffs.map(&:to_s) }
      end

      def self.from_h(hash)
        Shape.format!(hash)
        Shape.keys!(hash, %w[format map season year phase units ownership dislodged_units standoffs])
        new(map: hash["map"],
            season: Shape.text_of(hash["season"], Shape::SEASONS, "season", "season"),
            year: hash["year"],
            phase: Shape.text_of(hash["phase"], Shape::PHASES, "phase", "phase"),
            units: Shape.array!(hash["units"], "units").map { |unit| Unit.from_h(unit) },
            ownership: ownership_from(hash["ownership"]),
            dislodged_units: Shape.array!(hash["dislodged_units"], "dislodged_units").map { |entry| DislodgedUnit.from_h(entry) },
            standoffs: Shape.array!(hash["standoffs"], "standoffs").map do |province|
              Shape.text_of(province, Shape::PROVINCES, "standoffs", "province")
            end)
      end

      def self.ownership_from(value)
        Shape.hash!(value, "\"ownership\"").to_h do |center, power|
          [Shape.text_of(center, Shape::SUPPLY_CENTERS, "ownership key", "supply center"),
           Shape.text_of(power, Shape::POWERS, "ownership value", "power")]
        end
      end
      private_class_method :ownership_from

      private

      def canonical_units(units)
        list = Shape.list_of(units, Unit, "units")
        Shape.unique!(list.map { |unit| unit.location.province }, "two units share the province")
        list.sort_by { |unit| unit.location.province }.freeze
      end

      def canonical_dislodged(dislodged)
        list = Shape.list_of(dislodged, DislodgedUnit, "dislodged_units")
        Shape.unique!(list.map { |entry| entry.unit.location.province }, "two dislodged units share the province")
        list.sort_by { |entry| entry.unit.location.province }.freeze
      end

      def canonical_standoffs(standoffs)
        list = Shape.array!(standoffs, "standoffs").dup
        list.each { |province| Shape.symbol_of(province, Shape::PROVINCES, "standoffs", "province") }
        Shape.unique!(list, "the standoff province is listed twice:")
        list.sort.freeze
      end

      def canonical_ownership(ownership)
        Shape.hash!(ownership, "\"ownership\"").each do |center, power|
          Shape.symbol_of(center, Shape::SUPPLY_CENTERS, "ownership key", "supply center")
          Shape.symbol_of(power, Shape::POWERS, "ownership value", "power")
        end
        ownership.sort_by { |center, _| center }.to_h.freeze
      end
    end
  end
end
```

Edit `lib/trucebearer/adjudicator.rb`: add `require_relative "adjudicator/position"` after `dislodged_unit`.

### Verification

```sh
bundle exec rspec spec/trucebearer/adjudicator/position_spec.rb spec/trucebearer/adjudicator/interface_examples_spec.rb
bundle exec rspec --exclude-pattern "**/starting_position_spec.rb"
```

Expected: all pass. Commit: "Add the Position value object".

---

## Phase 3: The `Order` module and the six order classes

**Implements:** FR-3, FR-4, FR-5 (orders) | **Satisfies:** AC-3.1 to AC-3.12, AC-4.1 (orders), AC-4.2 (orders), AC-4.3 (orders), AC-4.5 (orders), AC-1.10 (orders), AC-5.10 (orders), AC-7.1 (Order examples and the two `format` examples), AC-7.2 (Errors examples with `O.from_h`)
**Files:** `spec/support/board.rb`, `order_spec.rb`, `interface_examples_spec.rb`, `order.rb`, `lib/trucebearer/adjudicator.rb`

### Step 1: Specs first

Edit `spec/support/board.rb`: after the `L = ...` line add `O = TA::Order unless defined?(O)`. (It is added now because `TA::Order` exists from this phase.) The line fails until `order.rb` exists, so make this edit and the spec in the same step and see them fail together.

Create `spec/trucebearer/adjudicator/order_spec.rb`:

```ruby
# frozen_string_literal: true

require "json"
require "trucebearer/adjudicator"
require_relative "../../support/board"

RSpec.describe Trucebearer::Adjudicator::Order do
  # class, keywords, hash form (the interface examples)
  cases = [
    [O::Hold, { power: :england, at: :lon },
     { "format" => 1, "type" => "hold", "power" => "england", "at" => "lon" }],
    [O::Move, { power: :france, at: :mao, destination: L.new(province: :spa, coast: :nc) },
     { "format" => 1, "type" => "move", "power" => "france", "at" => "mao", "destination" => { "province" => "spa", "coast" => "nc" } }],
    [O::MoveViaConvoy, { power: :england, at: :lon, to: :wal },
     { "format" => 1, "type" => "move_via_convoy", "power" => "england", "at" => "lon", "to" => "wal" }],
    [O::SupportHold, { power: :germany, at: :mun, target: :ber },
     { "format" => 1, "type" => "support_hold", "power" => "germany", "at" => "mun", "target" => "ber" }],
    [O::SupportMove, { power: :france, at: :por, from: :mao, to: :spa },
     { "format" => 1, "type" => "support_move", "power" => "france", "at" => "por", "from" => "mao", "to" => "spa" }],
    [O::Convoy, { power: :england, at: :nth, from: :lon, to: :nwy },
     { "format" => 1, "type" => "convoy", "power" => "england", "at" => "nth", "from" => "lon", "to" => "nwy" }]
  ].freeze

  it "has the six classes, with the fields the interface gives (AC-3.1, AC-3.2)" do
    expect(cases.map { |klass, _, _| klass.members }).to eq(
      [%i[power at], %i[power at destination], %i[power at to], %i[power at target], %i[power at from to], %i[power at from to]]
    )
    expect(cases.map { |_, _, hash| O.from_h(hash).class }).to eq(cases.map(&:first))
    expect(O::SupportMove.new(power: :france, at: :por, from: :mao, to: :spa))
      .not_to eq(O::Convoy.new(power: :france, at: :por, from: :mao, to: :spa))
  end

  cases.each do |klass, keywords, hash|
    describe klass.name.split("::").last do
      let(:order) { klass.new(**keywords) }

      it "is frozen, equal to one with the same contents, and gives its hash form (AC-3.1, AC-3.2)" do
        expect(order).to be_frozen
        expect(order).to eq(klass.new(**keywords))
        expect(order.hash).to eq(klass.new(**keywords).hash)
        expect(order.to_h).to eq(hash)
        expect(order.to_h.keys).to eq(hash.keys)
      end

      it "round-trips through JSON, through its own from_h and through Order.from_h (AC-3.3)" do
        json = JSON.parse(JSON.generate(order.to_h))
        expect(klass.from_h(json)).to eq(order)
        expect(O.from_h(json)).to eq(order)
        expect(O.from_h(json)).to be_a(klass)
      end

      it "refuses the hash of each other class (AC-3.5)" do
        cases.each do |other, _, other_hash|
          next if other == klass

          expect { klass.from_h(other_hash) }.to raise_error(TA::InvalidInput, /#{Regexp.escape(other_hash["type"].inspect)}/)
        end
      end

      it "refuses a missing key, an unknown key, symbol keys and a non-hash (AC-3.11)" do
        hash.each_key do |key|
          expect { klass.from_h(hash.reject { |k, _| k == key }) }.to raise_error(TA::InvalidInput, /#{Regexp.escape(key.inspect)}/)
        end
        expect { klass.from_h(hash.merge("extra" => 1)) }.to raise_error(TA::InvalidInput, /"extra"/)
        expect { klass.from_h(hash.transform_keys(&:to_sym)) }.to raise_error(TA::InvalidInput)
        expect { klass.from_h("order") }.to raise_error(TA::InvalidInput, /"order"/)
        expect { klass.from_h(hash.merge("power" => :england)) }.to raise_error(TA::InvalidInput, /:england/)
        expect { klass.from_h(hash.merge("power" => "atlantis")) }.to raise_error(TA::InvalidInput, /"atlantis"/)
      end

      it "refuses a bad format, naming it (AC-4.2, AC-4.5)" do
        expect { klass.from_h(hash.reject { |k, _| k == "format" }) }.to raise_error(TA::InvalidInput, /"format"/)
        [2, 0, "1", 1.0, nil].each do |bad|
          expect { klass.from_h(hash.merge("format" => bad)) }.to raise_error(TA::InvalidInput, /#{Regexp.escape(bad.inspect)}/)
          expect { O.from_h(hash.merge("format" => bad)) }.to raise_error(TA::InvalidInput, /#{Regexp.escape(bad.inspect)}/)
        end
      end

      it "refuses a missing keyword, and a bad power or at, in new (AC-1.10, AC-3.10)" do
        expect { klass.new(**keywords.reject { |k, _| k == :at }) }.to raise_error(ArgumentError)
        expect { klass.new(**keywords, extra: 1) }.to raise_error(ArgumentError)
        expect { klass.new(**keywords.merge(power: "england")) }.to raise_error(TA::InvalidInput, /"england"/)
        expect { klass.new(**keywords.merge(power: :atlantis)) }.to raise_error(TA::InvalidInput, /:atlantis/)
        expect { klass.new(**keywords.merge(at: :xyz)) }.to raise_error(TA::InvalidInput, /:xyz/)
        expect { klass.new(**keywords.merge(at: "lon")) }.to raise_error(TA::InvalidInput, /"lon"/)
      end

      it "refuses an impossible change made with #with (AC-5.11)" do
        expect { order.with(at: :xyz) }.to raise_error(TA::InvalidInput, /:xyz/)
      end

      it "writes only plain data (AC-4.3)" do
        expect(JSON.generate(order.to_h)).to be_a(String)
        expect(order.to_h.values.grep(Symbol)).to be_empty
      end
    end
  end

  describe "province fields and location fields (AC-3.6, AC-3.7, AC-3.12)" do
    province_fields = { O::Hold => %w[at], O::Move => %w[at], O::MoveViaConvoy => %w[at to],
                        O::SupportHold => %w[at target], O::SupportMove => %w[at from to], O::Convoy => %w[at from to] }

    province_fields.each do |klass, fields|
      it "refuses a coast, a location, a symbol, nil or an unknown name in each province field of #{klass.name.split("::").last}" do
        valid = cases.find { |k, _, _| k == klass }.last
        fields.each do |field|
          [{ "province" => "spa", "coast" => "nc" }, { "province" => "spa", "coast" => nil }, :spa, nil, "xyz"].each do |bad|
            expect { klass.from_h(valid.merge(field => bad)) }.to raise_error(TA::InvalidInput, /#{Regexp.escape(bad.inspect)}/)
          end
        end
      end
    end

    it "refuses a Location or a string in a province field of new, and a non-Location destination (AC-3.7)" do
      expect { O::Hold.new(power: :england, at: L.new(province: :lon)) }.to raise_error(TA::InvalidInput, /#{Regexp.escape(L.new(province: :lon).inspect)}/)
      expect { O::MoveViaConvoy.new(power: :england, at: :lon, to: "wal") }.to raise_error(TA::InvalidInput, /"wal"/)
      [:spa, nil, { "province" => "spa", "coast" => nil }].each do |bad|
        expect { O::Move.new(power: :france, at: :mao, destination: bad) }.to raise_error(TA::InvalidInput, /#{Regexp.escape(bad.inspect)}/)
      end
      expect(O::Move.new(power: :france, at: :mao, destination: L.new(province: :spa, coast: :nc))).to be_a(O::Move)
    end

    it "refuses a destination that is not exactly a location hash (AC-3.12)" do
      valid = cases.find { |k, _, _| k == O::Move }.last
      [["spa", /"spa"/], [nil, /nil/], [:spa, /:spa/], [{ "province" => "spa" }, /"coast"/],
       [{ "province" => "spa", "coast" => nil, "x" => 1 }, /"x"/], [{ "province" => "par", "coast" => "nc" }, /"nc"/]].each do |bad, pattern|
        expect { O::Move.from_h(valid.merge("destination" => bad)) }.to raise_error(TA::InvalidInput, pattern)
        expect { O.from_h(valid.merge("destination" => bad)) }.to raise_error(TA::InvalidInput, pattern)
      end
    end
  end

  describe ".from_h" do
    it "refuses an unknown, missing or non-string type, and a non-hash (AC-3.4)" do
      hold = cases.first.last
      ["teleport", "Hold"].each { |bad| expect { O.from_h(hold.merge("type" => bad)) }.to raise_error(TA::InvalidInput, /#{Regexp.escape(bad.inspect)}/) }
      [:hold, nil, 1].each { |bad| expect { O.from_h(hold.merge("type" => bad)) }.to raise_error(TA::InvalidInput, /#{Regexp.escape(bad.inspect)}/) }
      expect { O.from_h(hold.reject { |k, _| k == "type" }) }.to raise_error(TA::InvalidInput, /"type"/)
      expect { O.from_h("hold") }.to raise_error(TA::InvalidInput, /"hold"/)
    end

    it "checks format and type before the other keys (AC-3.5)" do
      hold = cases.first.last
      expect { O::Move.from_h(hold) }.to raise_error(TA::InvalidInput, /"hold"/)
    end

    it "leaves its argument alone, accepts a frozen hash, and holds no reference to it (AC-2.9)" do
      move = cases.find { |k, _, _| k == O::Move }.last
      parsed = JSON.parse(JSON.generate(move))
      before = Marshal.load(Marshal.dump(parsed))
      order = O.from_h(Ractor.make_shareable(parsed))
      expect(parsed).to eq(before)
      expect(order.destination).to eq(L.new(province: :spa, coast: :nc))
    end
  end

  describe "orders that break a rule of the game (AC-3.8)" do
    it "builds them, with new and with from_h" do
      odd = [
        O::Move.new(power: :england, at: :lon, destination: L.new(province: :lon)),
        O::Move.new(power: :germany, at: :mun, destination: L.new(province: :nth)),
        O::Convoy.new(power: :france, at: :par, from: :bur, to: :bur),
        O::SupportMove.new(power: :france, at: :par, from: :bur, to: :bur),
        O::Hold.new(power: :turkey, at: :nth)
      ]
      odd.each { |order| expect(O.from_h(JSON.parse(JSON.generate(order.to_h)))).to eq(order) }
    end
  end

  describe "round trips over every place (AC-3.9)" do
    it "round-trips a Move to each of the 81 locations" do
      Board.locations.each do |location|
        order = O::Move.new(power: :france, at: :mao, destination: location)
        json = JSON.parse(JSON.generate(order.to_h))
        expect([O::Move.from_h(json), O.from_h(json)]).to eq([order, order])
      end
    end

    it "round-trips each province in each province field of each class" do
      Board.provinces.each do |id|
        orders = [O::Hold.new(power: :italy, at: id), O::MoveViaConvoy.new(power: :italy, at: id, to: id),
                  O::SupportHold.new(power: :italy, at: id, target: id), O::SupportMove.new(power: :italy, at: id, from: id, to: id),
                  O::Convoy.new(power: :italy, at: id, from: id, to: id)]
        orders.each do |order|
          json = JSON.parse(JSON.generate(order.to_h))
          expect([order.class.from_h(json), O.from_h(json)]).to eq([order, order])
        end
      end
    end
  end
end
```

Add to `interface_examples_spec.rb` (inside the top `RSpec.describe`):

```ruby
  describe "TA::Order and its six classes, and the format examples" do
    it "gives the examples of the Value objects introduction and the Errors section" do
      expect { O.from_h({ "type" => "hold", "power" => "england", "at" => "lon" }) }.to raise_error(TA::InvalidInput, /"format"/)
      expect { O.from_h({ "format" => 2, "type" => "hold", "power" => "england", "at" => "lon" }) }.to raise_error(TA::InvalidInput, /2/)
      expect { O.from_h({ "format" => 1, "type" => "hold", "power" => "england" }) }.to raise_error(TA::InvalidInput, /"at"/)
      expect { O.from_h({ "format" => 1, "type" => "hold", "power" => "england", "at" => "xyz" }) }.to raise_error(TA::InvalidInput, /"xyz"/)
      expect do
        O.from_h({ "format" => 1, "type" => "hold", "power" => "england", "at" => { "province" => "spa", "coast" => "nc" } })
      end.to raise_error(TA::InvalidInput, /#{Regexp.escape({ "province" => "spa", "coast" => "nc" }.inspect)}/)
    end

    it "gives the TA::Order examples" do
      expect(O.from_h({ "format" => 1, "type" => "hold", "power" => "england", "at" => "lon" }))
        .to eq(O::Hold.new(power: :england, at: :lon))
      expect(O.from_h({ "format" => 1, "type" => "hold", "power" => "england", "at" => "lon" }).inspect)
        .to eq("#<data Trucebearer::Adjudicator::Order::Hold power=:england, at=:lon>")
      expect { O::Move.from_h({ "format" => 1, "type" => "hold", "power" => "england", "at" => "lon" }) }.to raise_error(TA::InvalidInput)
      expect(O::Hold.new(power: :england, at: :lon).to_h).to eq({ "format" => 1, "type" => "hold", "power" => "england", "at" => "lon" })
      expect(O::Move.new(power: :france, at: :mao, destination: L.new(province: :spa, coast: :nc)).to_h)
        .to eq({ "format" => 1, "type" => "move", "power" => "france", "at" => "mao", "destination" => { "province" => "spa", "coast" => "nc" } })
      expect(O::MoveViaConvoy.new(power: :england, at: :lon, to: :wal).to_h)
        .to eq({ "format" => 1, "type" => "move_via_convoy", "power" => "england", "at" => "lon", "to" => "wal" })
      expect(O::SupportHold.new(power: :germany, at: :mun, target: :ber).to_h)
        .to eq({ "format" => 1, "type" => "support_hold", "power" => "germany", "at" => "mun", "target" => "ber" })
      expect(O::SupportMove.new(power: :france, at: :por, from: :mao, to: :spa).to_h)
        .to eq({ "format" => 1, "type" => "support_move", "power" => "france", "at" => "por", "from" => "mao", "to" => "spa" })
      expect(O::Convoy.new(power: :england, at: :nth, from: :lon, to: :nwy).to_h)
        .to eq({ "format" => 1, "type" => "convoy", "power" => "england", "at" => "nth", "from" => "lon", "to" => "nwy" })
    end
  end
```

Run:

```sh
bundle exec rspec spec/trucebearer/adjudicator/order_spec.rb spec/trucebearer/adjudicator/interface_examples_spec.rb
```

Expected: fails loading `spec/support/board.rb` with `NameError: uninitialized constant Trucebearer::Adjudicator::Order`. That is the right reason.

### Step 2: Code

Create `lib/trucebearer/adjudicator/order.rb`:

```ruby
# frozen_string_literal: true

module Trucebearer
  module Adjudicator
    # The six movement orders. Each is a Data class with the fields power and at
    # (a province field) first, then its own. Storable: the hash form carries format.
    module Order
      TYPES = {}

      def self.from_h(hash)
        Shape.hash!(hash, "order")
        raise InvalidInput, "missing key \"type\"" unless hash.key?("type")

        klass = TYPES[hash["type"]]
        raise InvalidInput, "unknown order type #{hash["type"].inspect}" unless klass

        klass.from_h(hash)
      end

      # Internal: builds one order class. Called only below.
      def self.define(type, *own_fields)
        klass = Data.define(:power, :at, *own_fields)
        klass.class_eval do
          define_method(:initialize) do |**given|
            super(**given)
            Order.validate!(self)
          end
          define_method(:to_h) { Order.hash_form(type, self) }
          define_singleton_method(:from_h) { |hash| Order.build(self, type, hash) }
        end
        TYPES[type] = klass
      end
      private_class_method :define

      # Internal: checks every field of a built order. The ordered unit and the
      # destination are the only fields that are not province fields.
      def self.validate!(order)
        order.class.members.each do |name|
          value = order.public_send(name)
          case name
          when :power then Shape.symbol_of(value, Shape::POWERS, "power", "power")
          when :destination then Shape.instance_of!(value, Location, "destination")
          else Shape.symbol_of(value, Shape::PROVINCES, name.to_s, "province")
          end
        end
      end

      # Internal: the hash form of an order, "format" and "type" first.
      def self.hash_form(type, order)
        fields = order.class.members.to_h do |name|
          value = order.public_send(name)
          [name.to_s, value.is_a?(Symbol) ? value.to_s : value.to_h]
        end
        { "format" => Shape::FORMAT, "type" => type }.merge(fields)
      end

      # Internal: the from_h every class shares. Checked in this order: format, type,
      # the key set, then each field in field order.
      def self.build(klass, type, hash)
        Shape.format!(hash)
        raise InvalidInput, "missing key \"type\"" unless hash.key?("type")
        raise InvalidInput, "expected order type #{type.inspect}, got #{hash["type"].inspect}" unless hash["type"] == type

        Shape.keys!(hash, %w[format type] + klass.members.map(&:to_s))
        values = klass.members.to_h { |name| [name, field_from(name, hash[name.to_s])] }
        klass.new(**values)
      end

      def self.field_from(name, value)
        case name
        when :power then Shape.text_of(value, Shape::POWERS, "power", "power")
        when :destination then Location.from_h(value)
        else Shape.text_of(value, Shape::PROVINCES, name.to_s, "province")
        end
      end

      Hold = define("hold")
      Move = define("move", :destination)
      MoveViaConvoy = define("move_via_convoy", :to)
      SupportHold = define("support_hold", :target)
      SupportMove = define("support_move", :from, :to)
      Convoy = define("convoy", :from, :to)

      TYPES.freeze
      private_constant :TYPES
    end
  end
end
```

Edit `lib/trucebearer/adjudicator.rb`: add `require_relative "adjudicator/order"` after `position`.

### Verification

```sh
bundle exec rspec spec/trucebearer/adjudicator/order_spec.rb spec/trucebearer/adjudicator/interface_examples_spec.rb
bundle exec rspec --exclude-pattern "**/starting_position_spec.rb"
```

Expected: all pass. Commit: "Add the Order module and the six movement orders".

---

## Phase 4: `Map#starting_position`

**Implements:** FR-6, FR-7 (the `map_spec.rb` line and the comment) | **Satisfies:** AC-6.1 to AC-6.8, AC-7.2 (the `starting_position` examples and the year example), AC-8.2, AC-8.6
**Files:** `starting_position_spec.rb` (already written), `interface_examples_spec.rb`, `map_spec.rb`, `map.rb`

### Step 1: Specs first

The round trip of Phase 1, Step 1 is already red. Extend `starting_position_spec.rb`:

```ruby
# frozen_string_literal: true

require "json"
require "yaml"
require "trucebearer/adjudicator"
require_relative "../../support/board"

RSpec.describe "Map#starting_position" do
  let(:map) { TA::Map.classic }
  let(:start) { map.starting_position }

  it "round-trips through JSON, with 22 units and 22 owned centers (AC-6.5)" do
    rebuilt = TA::Position.from_h(JSON.parse(JSON.generate(start.to_h)))
    expect(rebuilt).to eq(start)
    expect(rebuilt.units.size).to eq(22)
    expect(rebuilt.ownership.size).to eq(22)
  end

  it "is a spring 1901 movement position on the classic map (AC-6.1)" do
    expect(start).to be_a(TA::Position)
    expect([start.map, start.season, start.year, start.phase]).to eq(["classic", :spring, 1901, :movement])
  end

  it "holds the 22 starting units, sorted by province (AC-6.2)" do
    expect(start.units.size).to eq(22)
    expect(start.units.map { _1.location.province }).to eq(start.units.map { _1.location.province }.sort)
    expect(start.units).to eq(map.starting_units.map { |u| TA::Unit.new(power: u[:power], type: u[:type], location: u[:location]) }.sort_by { _1.location.province })
    by_power = start.units.group_by(&:power).transform_values { |units| units.map { [_1.type, _1.location.province, _1.location.coast] } }
    expect(by_power.fetch(:russia)).to contain_exactly(
      [:army, :mos, nil], [:army, :war, nil], [:fleet, :sev, nil], [:fleet, :stp, :sc]
    )
    expect(by_power.fetch(:england)).to contain_exactly([:fleet, :lon, nil], [:fleet, :edi, nil], [:army, :lvp, nil])
    expect(by_power.keys.sort).to eq(Board.powers)
    expect(by_power.values.map(&:size)).to all(be_between(3, 4))
  end

  it "gives each power its own home centers and leaves the 12 neutral centers out (AC-6.3)" do
    expect(start.ownership.size).to eq(22)
    map.powers.each do |power|
      map.home_centers(power.id).each { |center| expect(start.ownership[center]).to eq(power.id) }
    end
    expect(start.ownership[:lon]).to eq(:england)
    expect(start.ownership.key?(:bel)).to be(false)
    expect(map.supply_centers - start.ownership.keys).to have_attributes(size: 12)
  end

  it "has no dislodged units and no standoffs (AC-6.4)" do
    expect([start.dislodged_units, start.standoffs]).to eq([[], []])
  end

  it "comes from the data file, unit for unit (AC-6.6)" do
    raw = YAML.safe_load_file(File.expand_path("../../../data/maps/classic.yml", __dir__), permitted_classes: [], aliases: false)
    from_file = raw["starting_units"].map { |u| [u["power"].to_sym, u["type"].to_sym, u["province"].to_sym, u["coast"]&.to_sym] }
    expect(from_file.size).to eq(22)
    expect(start.units.map { [_1.power, _1.type, _1.location.province, _1.location.coast] }).to match_array(from_file)
    start.units.each { |unit| expect(start.ownership[unit.location.province]).to eq(unit.power) }
  end

  it "gives an equal, valid, frozen position on every call (AC-6.7)" do
    expect(map.starting_position).to eq(map.starting_position)
    expect(map.starting_position).to be_frozen
  end

  it "is not mentioned alongside starting_units in the interface document (AC-6.8)" do
    interface = File.read(File.expand_path("../../../docs/interface.md", __dir__))
    expect(interface).not_to include("starting_units")
  end
end
```

Add to `interface_examples_spec.rb` a `describe "Map#starting_position"` and the Errors example that needed it:

```ruby
  describe "Map#starting_position and the year example" do
    it "gives the values of the Map section (overview block and subsection)" do
      map = TA::Map.classic
      start = map.starting_position
      expect([start.season, start.year, start.phase]).to eq([:spring, 1901, :movement])
      expect(start.units.size).to eq(22)
      expect(start.ownership.size).to eq(22)
      expect(start.ownership[:lon]).to eq(:england)
      expect(start.ownership.key?(:bel)).to be(false)
    end

    it "raises for the year example under Errors" do
      start = TA::Map.classic.starting_position
      expect { TA::Position.from_h(start.to_h.merge("year" => "1901")) }.to raise_error(TA::InvalidInput, /"1901"/)
    end
  end
```

Edit `spec/trucebearer/adjudicator/map_spec.rb` (AC-8.2): replace the example at the end of the `starting_units` group

```ruby
    it "is not mentioned in the interface document, and starting_position is not built here" do
      expect(File.read(INTERFACE_DOC)).not_to include("starting_units")
      expect(map).not_to respond_to(:starting_position)
    end
```

with

```ruby
    it "is not mentioned in the interface document" do
      expect(File.read(INTERFACE_DOC)).not_to include("starting_units")
    end
```

Run:

```sh
bundle exec rspec spec/trucebearer/adjudicator/starting_position_spec.rb spec/trucebearer/adjudicator/interface_examples_spec.rb
```

Expected: fail with `NoMethodError: undefined method 'starting_position'`.

### Step 2: Code

Edit `lib/trucebearer/adjudicator/map.rb`. Change the comment above `starting_units` to

```ruby
      # Internal: not part of docs/interface.md, and may change in any release.
      # The units a game starts with, which Map#starting_position turns into a TA::Position.
      # Each entry is a frozen Hash with :power, :type and :location (a TA::Location).
      # Built on each call so that no Location is made while the map is loading.
```

and add, after `starting_units` and before `private`:

```ruby
      # The position the game starts from: spring 1901, the movement phase, each power's
      # units, and each power owning its own home centers. The neutral centers are absent
      # from ownership. Built on each call, since a frozen map cannot hold one.
      def starting_position
        Position.new(
          map: id, season: :spring, year: 1901, phase: :movement,
          units: starting_units.map { |u| Unit.new(power: u[:power], type: u[:type], location: u[:location]) },
          ownership: @powers.each_with_object({}) do |power, owned|
            home_centers(power.id).each { |center| owned[center] = power.id }
          end,
          dislodged_units: [], standoffs: []
        )
      end
```

### Verification

```sh
bundle exec rspec
bundle exec rake
```

Expected: all pass, 0 failures, none pending. Commit: "Add Map#starting_position".

---

## Phase 5: The interface list, the examples sweep, the changelog and final verification

**Implements:** FR-7 | **Satisfies:** AC-7.3, AC-7.5, AC-8.1, AC-8.3 to AC-8.7
**Files:** `interface_examples_spec.rb`, `docs/interface.md`, `CHANGELOG.md`

### Step 1: Specs first

Add to `interface_examples_spec.rb`:

```ruby
  describe "the Impossible objects list names the two stricter rules (AC-8.7)" do
    let(:interface) { File.read(File.expand_path("../../../docs/interface.md", __dir__)) }
    let(:impossible) { interface[/^### Impossible objects\n(.*?)^## Checking an order/m, 1] }

    it "lists the same standoff province twice, and two dislodged units in one province" do
      expect(impossible).to include("standoffs: [:bur, :bur]")
      expect(impossible).to include("Two dislodged units in one province")
    end

    it "raises for both examples" do
      army = Board.army
      fleet = Board.fleet
      spring = Board.spring
      expect { TA::Position.new(**spring.merge(phase: :retreat, standoffs: [:bur, :bur]), units: [army], ownership: {}) }.to raise_error(TA::InvalidInput)
      expect do
        TA::Position.new(**spring.merge(phase: :retreat, dislodged_units: [fleet, fleet].map { TA::DislodgedUnit.new(unit: _1, attacker_from: :fin, by_convoy: false) }),
                         units: [army], ownership: {})
      end.to raise_error(TA::InvalidInput)
    end
  end

  describe "constructions in the excluded sections that need only these objects (AC-7.5)" do
    # Every unit and order those sections build, so that #11 and #14 can use the examples as they stand.
    unit = ->(power, type, province, coast = nil) { TA::Unit.new(power: power, type: type, location: L.new(province: province, coast: coast)) }
    move = ->(power, at, to, coast = nil) { O::Move.new(power: power, at: at, destination: L.new(province: to, coast: coast)) }
    base = { map: "classic", season: :spring, year: 1901, phase: :movement, ownership: {}, dislodged_units: [], standoffs: [] }

    it "builds the positions" do
      start = TA::Map.classic.starting_position
      expect(TA::Position.from_h(start.to_h.merge("phase" => "retreat")).phase).to eq(:retreat) # retreat
      at_sea = TA::Position.new(**base, units: [unit.call(:france, :fleet, :mao), unit.call(:france, :fleet, :gol)])
      ln = TA::Position.new(**base, units: [unit.call(:england, :army, :lon), unit.call(:england, :fleet, :nth)])
      pos = TA::Position.new(map: "classic", season: :spring, year: 1901, phase: :movement,
                             units: [unit.call(:england, :fleet, :lon)], ownership: { lon: :england }, dislodged_units: [], standoffs: [])
      vienna = TA::Position.new(**base, units: [unit.call(:austria, :army, :vie), unit.call(:germany, :army, :boh), unit.call(:germany, :army, :tyr)])
      paradox_pos = TA::Position.new(**base, units: [unit.call(:england, :fleet, :lon), unit.call(:england, :fleet, :wal),
                                                     unit.call(:france, :army, :bre), unit.call(:france, :fleet, :eng)])
      expect([at_sea, ln, pos, vienna, paradox_pos].map { _1.units.size }).to eq([2, 2, 1, 3, 4])
    end

    it "builds the units used with legal orders" do
      [unit.call(:england, :fleet, :lon), unit.call(:france, :fleet, :lon), unit.call(:austria, :army, :vie),
       unit.call(:france, :fleet, :mao), unit.call(:england, :army, :lon)].each { |built| expect(built).to be_frozen }
      expect(TA::DislodgedUnit.new(unit: unit.call(:austria, :army, :vie), attacker_from: :boh, by_convoy: false)).to be_frozen
    end

    it "builds the orders used with checking, legal orders and adjudication" do
      orders = [
        O::Hold.new(power: :england, at: :lon), O::Hold.new(power: :france, at: :lon), O::Hold.new(power: :england, at: :wal),
        O::Hold.new(power: :austria, at: :vie),
        move.call(:england, :lon, :bel), move.call(:russia, :sev, :rum), move.call(:france, :mar, :spa, :nc),
        move.call(:france, :mao, :spa), move.call(:france, :gol, :spa, :nc), move.call(:england, :lon, :eng),
        move.call(:england, :lon, :nth), move.call(:germany, :kie, :hol), move.call(:russia, :war, :gal),
        move.call(:austria, :vie, :gal), move.call(:england, :lon, :yor), move.call(:england, :wal, :eng),
        move.call(:france, :bre, :lon), move.call(:germany, :boh, :vie),
        O::MoveViaConvoy.new(power: :england, at: :lvp, to: :wal),
        O::SupportMove.new(power: :austria, at: :vie, from: :war, to: :gal),
        O::SupportMove.new(power: :england, at: :lon, from: :wal, to: :eng),
        O::SupportMove.new(power: :germany, at: :tyr, from: :boh, to: :vie),
        O::SupportHold.new(power: :germany, at: :mun, target: :ber), O::SupportHold.new(power: :germany, at: :mun, target: :sil),
        O::Convoy.new(power: :england, at: :lon, from: :lvp, to: :bel), O::Convoy.new(power: :england, at: :nth, from: :lon, to: :yor),
        O::Convoy.new(power: :france, at: :eng, from: :bre, to: :lon)
      ]
      expect(orders.size).to eq(27)
      orders.each { |order| expect(O.from_h(JSON.parse(JSON.generate(order.to_h)))).to eq(order) }
    end
  end
end
```

That nothing else in `interface.md` changes is checked by the `git diff` command in Step 4, not by a spec, since a spec that diffs against `main` would break on a shallow CI checkout.

Run:

```sh
bundle exec rspec spec/trucebearer/adjudicator/interface_examples_spec.rb
```

Expected: the "lists the same standoff province twice..." example fails (`expect(impossible).to include(...)` is false) because `interface.md` does not name the two cases yet. The "raises for both examples" example and the construction example already pass, since Phases 1 to 3 built everything they use; they are kept as the executable form of the new document lines.

### Step 2: Edit `docs/interface.md` (the only change to it, AC-8.7)

In `### Impossible objects`, after the movement-phase block (the lines ending `units: [army], ownership: {})` for the dislodged-unit example) and before `# A check result whose legal flag and reasons disagree.`, insert:

```ruby
# The same province twice in the standoffs.
TA::Position.new(**spring.merge(phase: :retreat, standoffs: [:bur, :bur]), units: [army], ownership: {})

# Two dislodged units in one province.
TA::Position.new(**spring.merge(phase: :retreat, dislodged_units: [fleet, fleet].map { TA::DislodgedUnit.new(unit: _1, attacker_from: :fin, by_convoy: false) }), units: [army], ownership: {})

```

(Each comment line is the text the new specs look for, with "Two dislodged units in one province." matching case.) Change nothing else in the file.

### Step 3: `CHANGELOG.md`

- Under "Unreleased" → "Added", trim the #9 entry: delete the sentence "`Map#starting_position` arrives with #10; until then the starting units are available through an internal reader." and keep the "(#9)" that follows it.
- Add under "Added":

```markdown
- The value objects of `docs/interface.md`: `TA::Unit`, `TA::DislodgedUnit`, `TA::Position`, the `TA::Order` module with `TA::Order.from_h`, and the six order classes `Hold`, `Move`, `MoveViaConvoy`, `SupportHold`, `SupportMove` and `Convoy`. Each is an immutable `Data` class with `to_h` and `from_h`, validated against the classic map, with list fields in canonical order; positions and orders carry `format` 1. `Map#starting_position` returns the spring 1901 position, built from the map data. `TA::CheckResult` arrives with #11, and `TA::Outcome` and `TA::Adjudication` with #14. (#10)
```

- Under "Changed" add:

```markdown
- `docs/interface.md`: the "Impossible objects" list now names two more cases that raise `TA::InvalidInput`: the same province twice in `standoffs`, and two dislodged units in one province. No release carried the old list. (#10)
```

### Step 4: Final verification

```sh
bundle exec rspec
bundle exec rake
git diff --name-only main...HEAD
git diff main...HEAD -- docs/interface.md
grep -rniE 'd[i]plomac|\bd[i]p' lib spec docs/specs/010-value-objects docs/interface.md CHANGELOG.md || true
```

Expected:
- `rspec` and `rake` pass, with no failure and no pending example;
- every path from `git diff --name-only` starts with `adjudicator/`;
- the `interface.md` diff adds only the two examples and their comments, and removes nothing;
- the grep prints nothing (the name rule).

Then, from the repository root, confirm `CHANGELOG.md` has the "Added" and "Changed" entries and no stale `starting_position` sentence:

```sh
grep -n "starting_position" adjudicator/CHANGELOG.md
```

Commit: "Document the two stricter impossible-object rules and record the change". Then the implementation review (an Opus reviewer, read-only), `sdd-superpowers:session-wrap`, the push that opens the draft pull request, and the finish steps from the brief.

---

## Spec coverage

| Spec | Where |
|---|---|
| Story 1 (AC-1.1 to AC-1.10) | Phase 1 (`unit_spec.rb`, `dislodged_unit_spec.rb`); AC-1.10 for `Position` and orders in Phases 2 and 3 |
| Story 2 (AC-2.1 to AC-2.10) | Phase 2 (`position_spec.rb`); AC-2.9 for units in Phase 1 and for orders in Phase 3 |
| Story 3 (AC-3.1 to AC-3.12) | Phase 3 (`order_spec.rb`) |
| Story 4 (AC-4.1 to AC-4.6) | Phases 2 and 3 (format, plain data, the `from_h` checks); AC-4.4 and AC-4.6 in review of `shape.rb` |
| Story 5 (AC-5.1 to AC-5.12) | Phase 1 (units: AC-5.2 to 5.4, 5.11), Phase 2 (positions: the rest) |
| Story 6 (AC-6.1 to AC-6.9) | Phase 4 (`starting_position_spec.rb`); AC-6.9 by the red first commit (Phase 1, Step 1) |
| Story 7 (AC-7.1 to AC-7.5) | `interface_examples_spec.rb`, grown in Phases 1 to 5 |
| Story 8 (AC-8.1 to AC-8.7) | Phases 4 and 5 |
| FR-1 to FR-7 | FR-1: Phase 1. FR-2: Phase 2. FR-3: Phase 3. FR-4 and FR-5: Phases 1 to 3 (`shape.rb`). FR-6: Phase 4. FR-7: Phases 4 and 5 |

## Self-review notes

- **Type consistency:** `Shape.symbol_of(value, allowed, name, noun)` and `Shape.text_of(value, allowed, name, noun)` have the same signature everywhere they are called. `Shape.keys!(hash, keys)` takes string keys. `Order.build`, `Order.hash_form`, `Order.validate!` and `Order.field_from` are called only from `Order.define` and from each other.
- **Messages:** every `InvalidInput` message contains `inspect` of the offending value, so the specs' regular expressions match. The standoff message ends `:bur` after the colon text; the placement messages contain `location.inspect`, which contains `province=:mun`, so `/:mun/` and `/#{id.inspect}/` match.
- **Known risks to watch in execution:**
  - `Data` calls a custom `initialize` for `with` (probed on Ruby 4.0.10), so `#with` is checked by the same code. If a spec shows otherwise, stop.
  - The `git diff main` example in Phase 5 depends on a local `main`. It is replaced by the verification command if CI has no `main`.
  - `Position#initialize` uses private instance methods before `super`. This works on `Data` (the object exists, unfrozen, until `initialize` ends); the prototype confirmed it.

# Implementation Plan: Check a single movement order against a position

**Spec:** adjudicator/docs/specs/011-check-order/spec.md (v1.1.1, Approved)
**Decisions:** none in `docs/adr/`. The recorded decisions are `docs/architecture.md` ("checking of a single order separately from adjudication", value objects built on `Data` with `to_h`, `from_h` and `format`) and the contract in `adjudicator/docs/interface.md`.
**Created:** 2026-11-25

## Global Constraints

- **Read `spec.md` in full before starting any phase.** Where a phase cites an AC or FR, the spec's wording is what the code must satisfy.
- Change files in `adjudicator/` only. The spec and this plan ship in the same pull request.
- **`docs/interface.md` is not changed**, by any phase. If a phase shows that the contract is wrong or contradicts itself (for example a reason that can't be reached in its precedence order), stop and `ask` the coordinator.
- Never give anything a name that contains or echoes the game's trademarked name or its three-letter prefix: files, classes, methods, specs, fixtures, comments, commit messages.
- No copied rules text, and none of the DATC's prose: fixtures, comments and `docs/ruleset.md` rows are in our own words and cite section numbers. The reference copy at `docs/reference/datc-v3.4.html` is read only.
- No new dependency. Standard library only (`yaml` and `set` are already in use or in the standard library). `json` is used by specs only.
- **Test first.** Each phase writes its specs, runs them, and sees them fail for the right reason before it writes any code.
- Run every command from `adjudicator/`. Spec files begin with `require "trucebearer/adjudicator"` and `require_relative "../../support/board"`. `.rspec` already loads `spec_helper`. Code files begin with `# frozen_string_literal: true`.
- `TA`, `L` and `O` stand for `Trucebearer::Adjudicator`, `TA::Location` and `TA::Order`, as in `interface.md`.
- Commit messages are plain imperative sentences, one commit per phase (plus the red first commit of Phase 1), each ending with the trailer `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`. One git operation per shell call.
- A phase is committed only when its own specs pass and the rest of the suite is green, with one exception: Phase 1, Step 1 commits the starting-position spec on its own, red, as the first code commit, so the history shows it was written first. Nothing is pushed before the end, so CI never sees a red commit. Until Phase 3 turns that spec green, the earlier phases run the suite with `--exclude-pattern "**/check_spec.rb"`.
- Fixtures hold exactly the units and orders of their DATC case and nothing more. Extra checks go in ordinary specs.

## Goal

`TA.check(position, order)` returns a `TA::CheckResult` for every well formed position and order, exactly as `docs/interface.md` describes, proved by specs for every reason and every precedence pair, by 30 hand-written DATC fixtures, and by every interface example.

---

## Pre-implementation gates

- **Simplicity (≤3 components):** three new library files, one concept each: `check_result.rb` (`CheckResult`), `reach.rb` (`Reach`, the board questions: can reach, convoy chain, minimal chain) and `check.rb` (`Check`, the rules per order type). `TA.check` is a one-line method in `adjudicator.rb` that calls `Check.call`. No dependency.
- **Anti-abstraction:** `Data.define` is used directly, as `Position` does. `Reach` and `Check` are plain modules of functions, private to the gem like `Shape`. They are split because #12 reuses `Reach` and not `Check`.
- **Integration-first:** the contract is `docs/interface.md`. The very first spec of the feature is the starting-position hold (Phase 1, Step 1), and every phase starts from the examples and the tables of the contract.

## Decisions the plan settles (spec left them open)

| Decision | Choice | Spec |
|---|---|---|
| Files | `lib/trucebearer/adjudicator/{check_result,reach,check}.rb`, required from `lib/trucebearer/adjudicator.rb` after `order`, in that order | FR-1 to FR-3 |
| Private helpers | `Reach` and `Check` are `private_constant` of `Trucebearer::Adjudicator`, like `Shape`. Specs reach `Reach` through `TA.const_get(:Reach)` | FR-3, AC-9.6 |
| `CheckResult::REASONS` | A public constant listing the 17 reasons in the order of the interface table. It is the one list `new` and `from_h` check against, and the specs compare it with the document. It is not part of the contract | FR-1, AC-7.1 |
| Adjacency tables | `Reach` builds `ARMY_STEPS` and `FLEET_STEPS` once when it loads, by asking `Map#adjacent?` for every pair, so the map data stays the only place adjacency is written. `Map` is not changed | FR-3 |
| Convoy chain | A chain is searched over the sea provinces that hold a fleet of any power. "Touches" means that some coast of a coastal province is adjacent to the sea for a fleet | FR-2, FR-3 |
| Minimal chain | A fleet is on a minimal chain when some sequence of sea provinces holding fleets is a chain with no shortcut: only the first touches the origin, only the last touches the destination, and no sea touches an earlier one but its predecessor. Such a sequence has no proper subset that is also a chain, which is the definition in the contract | FR-2 |
| "Without the supporter's province" | The chain search for a supported army leaves out the sea province of the supporting fleet (`without:`) | FR-2, AC-5.5 |
| Non-order argument | `Check.call` raises `TA::InvalidInput` unless the position is a `TA::Position` and the order is one of the six classes | AC-2.7 |
| Fixtures | One YAML file per case in `spec/datc/`, read by `spec/support/datc.rb` with `YAML.safe_load_file` (no classes, no aliases) | Story 8 |
| Spec helpers | `spec/support/board.rb` gains `loc`, `unit`, `position` and `verdict`. `spec/support/reasons_table.rb` reads the reasons table out of `docs/interface.md` and holds the precedence helper | AC-7.1, AC-7.3 |

## Files

| File | Change | Responsibility |
|---|---|---|
| `adjudicator/lib/trucebearer/adjudicator/check_result.rb` | create | `TA::CheckResult`, `CheckResult::REASONS` |
| `adjudicator/lib/trucebearer/adjudicator/reach.rb` | create | Internal: can reach, convoy chain, minimal convoy chain |
| `adjudicator/lib/trucebearer/adjudicator/check.rb` | create | Internal: the rules of each order type; `Check.call` |
| `adjudicator/lib/trucebearer/adjudicator.rb` | edit | Require the three files; define `TA.check` |
| `adjudicator/spec/support/board.rb` | edit | Add `loc`, `unit`, `position`, `verdict` |
| `adjudicator/spec/support/reasons_table.rb` | create | Reads the reasons table of `interface.md`; the precedence helper |
| `adjudicator/spec/support/datc.rb` | create | Loads and validates the fixtures |
| `adjudicator/spec/datc/*.yml` | create | The 30 fixtures |
| `adjudicator/spec/trucebearer/adjudicator/check_result_spec.rb` | create | `CheckResult` (Story 1) |
| `adjudicator/spec/trucebearer/adjudicator/reach_spec.rb` | create | The helpers (FR-3, AC-9.6) |
| `adjudicator/spec/trucebearer/adjudicator/check_spec.rb` | create | The first spec, and Story 2 |
| `adjudicator/spec/trucebearer/adjudicator/check_move_spec.rb` | create | Stories 3 and 4 |
| `adjudicator/spec/trucebearer/adjudicator/check_support_spec.rb` | create | Story 5 |
| `adjudicator/spec/trucebearer/adjudicator/check_convoy_spec.rb` | create | Story 6 |
| `adjudicator/spec/trucebearer/adjudicator/check_reasons_spec.rb` | create | Story 7: every reason, the table, the sweep |
| `adjudicator/spec/datc/datc_check_spec.rb` | create | Runs the fixtures (AC-8.1, AC-8.2, AC-8.4) |
| `adjudicator/spec/datc/datc_loader_spec.rb` | create | The loader (AC-8.5, AC-8.6) |
| `adjudicator/spec/trucebearer/adjudicator/check_examples_spec.rb` | create | Every example of `interface.md` for checking and `CheckResult` (AC-9.1) |
| `adjudicator/spec/trucebearer/adjudicator/interface_examples_spec.rb` | edit | Update the header comment (AC-9.2) |
| `adjudicator/CHANGELOG.md` | edit | "Added" entry; trim the #10 line (AC-9.3) |
| `adjudicator/docs/ruleset.md` | edit | Two rows beside 4.E.1 (AC-9.4) |
| `adjudicator/docs/specs/011-check-order/{spec,plan}.md` | create | This feature's documents |

`spec/datc/.gitkeep` stays. The runner spec files sit in `spec/datc/`, next to the fixtures they read.

---

## Phase 1: The first spec, and `TA::CheckResult`

**Implements:** FR-1 | **Satisfies:** AC-1.1 to AC-1.8, AC-2.1
**Files:** `spec/trucebearer/adjudicator/check_spec.rb`, `spec/trucebearer/adjudicator/check_result_spec.rb`, `lib/trucebearer/adjudicator/check_result.rb`, `lib/trucebearer/adjudicator.rb`
**Interfaces:** Consumes: `Shape.boolean!`, `Shape.array!`, `Shape.symbol_of`, `Shape.text_of`, `Shape.format!`, `Shape.keys!`, `Shape::FORMAT` (from #10), `InvalidInput`. Produces: `TA::CheckResult.new(legal:, reasons:)`, `#to_h`, `.from_h(hash)`, `CheckResult::REASONS` (Array of 17 Symbols).

The very first spec of the feature is the starting-position hold. It is committed red, on its own, before any code. Then the `CheckResult` specs are written and the class built.

- [ ] **Step 1: write the first spec.** Create `spec/trucebearer/adjudicator/check_spec.rb`:

```ruby
# frozen_string_literal: true

require "trucebearer/adjudicator"
require_relative "../../support/board"

# TA.check: what every order needs (Story 2). The first example is the first spec
# of the feature: the starting position, England's hold and France's hold.
RSpec.describe "TA.check" do
  let(:start) { TA::Map.classic.starting_position }

  it "gives England's hold at London no reasons, and France's hold for the same unit one" do
    expect(TA.check(start, O::Hold.new(power: :england, at: :lon)))
      .to eq(TA::CheckResult.new(legal: true, reasons: []))
    expect(TA.check(start, O::Hold.new(power: :france, at: :lon)))
      .to eq(TA::CheckResult.new(legal: false, reasons: [:foreign_unit]))
  end
end
```

- [ ] **Step 2: run it and confirm it fails.** `bundle exec rspec spec/trucebearer/adjudicator/check_spec.rb` — expect: FAIL with `NameError: uninitialized constant Trucebearer::Adjudicator::CheckResult`.
- [ ] **Step 3: commit it, red, on its own.** `git add spec/trucebearer/adjudicator/check_spec.rb`, then `git commit -m "Add the first spec for checking an order, red"` (with the trailer).
- [ ] **Step 4: write the `CheckResult` specs.** Create `spec/trucebearer/adjudicator/check_result_spec.rb`:

```ruby
# frozen_string_literal: true

require "json"
require "trucebearer/adjudicator"
require_relative "../../support/board"

RSpec.describe TA::CheckResult do
  let(:illegal) { described_class.new(legal: false, reasons: [:foreign_unit]) }
  let(:legal) { described_class.new(legal: true, reasons: []) }

  def refused(message_part = nil, &block)
    expect(&block).to raise_error(TA::InvalidInput, /#{Regexp.escape(message_part.to_s)}/)
  end

  describe "new" do
    it "builds frozen results with a frozen reasons list (AC-1.1)" do
      expect(legal).to be_frozen
      expect(illegal).to be_frozen
      expect(illegal.reasons).to be_frozen
      expect(legal.reasons).to eq([])
      expect(illegal.legal).to be(false)
    end

    it "makes equal results equal, with the same hash (AC-1.1)" do
      again = described_class.new(legal: false, reasons: [:foreign_unit])
      expect(again).to eq(illegal)
      expect(again).to eql(illegal)
      expect(again.hash).to eq(illegal.hash)
      expect(illegal).not_to eq(described_class.new(legal: false, reasons: [:no_unit]))
    end

    it "copies the reasons it is given (AC-1.1)" do
      given = [:no_unit]
      result = described_class.new(legal: false, reasons: given)
      expect(given).not_to be_frozen
      given << :own_province
      expect(result.reasons).to eq([:no_unit])
    end

    it "has the 17 reasons of the interface table, in its order" do
      expect(described_class::REASONS.size).to eq(17)
      expect(described_class::REASONS).to eq(
        %i[wrong_phase no_such_unit foreign_unit own_province not_reachable coast_not_allowed coast_required
           coast_unreachable not_army not_adjacent no_convoy_route same_province no_unit move_impossible
           not_fleet_at_sea bad_endpoints not_on_chain]
      )
    end

    it "refuses a legal flag that is not true or false, naming the value (AC-1.5)" do
      [nil, "true", 1].each do |bad|
        refused(bad.inspect) { described_class.new(legal: bad, reasons: []) }
      end
    end

    it "refuses reasons that are not an Array, naming the value (AC-1.5)" do
      refused(":no_unit") { described_class.new(legal: false, reasons: :no_unit) }
      refused("nil") { described_class.new(legal: false, reasons: nil) }
    end

    it "refuses a reason that is a string or an unknown symbol, naming it (AC-1.5)" do
      refused('"own_province"') { described_class.new(legal: false, reasons: ["own_province"]) }
      refused(":bogus") { described_class.new(legal: false, reasons: [:bogus]) }
    end

    it "refuses the three impossible results of the interface (AC-1.4)" do
      refused(":own_province") { described_class.new(legal: true, reasons: [:own_province]) }
      refused("[]") { described_class.new(legal: false, reasons: []) }
      refused(":not_reachable") { described_class.new(legal: false, reasons: %i[own_province not_reachable]) }
    end

    it "raises Ruby's ArgumentError for a missing or unknown keyword (AC-1.8)" do
      expect { described_class.new(legal: true) }.to raise_error(ArgumentError)
      expect { described_class.new(reasons: []) }.to raise_error(ArgumentError)
      expect { described_class.new(legal: true, reasons: [], extra: 1) }.to raise_error(ArgumentError)
    end
  end

  describe "to_h" do
    it "gives the hash forms of the interface, keys in order (AC-1.2)" do
      expect(illegal.to_h).to eq("format" => 1, "legal" => false, "reasons" => ["foreign_unit"])
      expect(legal.to_h).to eq("format" => 1, "legal" => true, "reasons" => [])
      expect(illegal.to_h.keys).to eq(%w[format legal reasons])
    end
  end

  describe "round trip" do
    let(:all) do
      [legal] + described_class::REASONS.map { |reason| described_class.new(legal: false, reasons: [reason]) }
    end

    it "rebuilds an equal object for a legal result and each of the 17 reasons (AC-1.3)" do
      expect(all.size).to eq(18)
      all.each do |result|
        expect(described_class.from_h(JSON.parse(JSON.generate(result.to_h)))).to eq(result)
      end
    end
  end

  describe "from_h" do
    let(:good) { { "format" => 1, "legal" => false, "reasons" => ["no_unit"] } }

    it "refuses the three impossible results as hashes (AC-1.4)" do
      [{ "legal" => true, "reasons" => ["own_province"] },
       { "legal" => false, "reasons" => [] },
       { "legal" => false, "reasons" => %w[own_province not_reachable] }].each do |fields|
        expect { described_class.from_h({ "format" => 1 }.merge(fields)) }.to raise_error(TA::InvalidInput)
      end
    end

    it "refuses a missing key, an unknown key, symbol keys and a non-hash (AC-1.6)" do
      refused('"legal"') { described_class.from_h(good.reject { |key, _| key == "legal" }) }
      refused('"reasons"') { described_class.from_h(good.reject { |key, _| key == "reasons" }) }
      refused('"extra"') { described_class.from_h(good.merge("extra" => 1)) }
      expect { described_class.from_h(good.transform_keys(&:to_sym)) }.to raise_error(TA::InvalidInput)
      refused("nil") { described_class.from_h(nil) }
      refused("[]") { described_class.from_h([]) }
    end

    it "refuses a missing or unknown format (AC-1.6)" do
      refused('"format"') { described_class.from_h(good.reject { |key, _| key == "format" }) }
      refused("2") { described_class.from_h(good.merge("format" => 2)) }
      refused("1.0") { described_class.from_h(good.merge("format" => 1.0)) }
    end

    it "refuses wrong types and unknown reasons (AC-1.6)" do
      refused('"yes"') { described_class.from_h(good.merge("legal" => "yes")) }
      refused('"no_unit"') { described_class.from_h(good.merge("reasons" => "no_unit")) }
      refused(":no_unit") { described_class.from_h(good.merge("reasons" => [:no_unit])) }
      refused('"bogus"') { described_class.from_h(good.merge("reasons" => ["bogus"])) }
    end

    it "leaves its argument unchanged and accepts a frozen one (AC-1.7)" do
      hash = { "format" => 1, "legal" => false, "reasons" => ["no_unit"] }
      before = Marshal.load(Marshal.dump(hash))
      result = described_class.from_h(hash)
      expect(hash).to eq(before)
      hash["reasons"] << "own_province"
      expect(result.reasons).to eq([:no_unit])
      frozen = { "format" => 1, "legal" => false, "reasons" => ["no_unit"].freeze }.freeze
      expect(described_class.from_h(frozen)).to eq(result)
      expect { described_class.from_h(good.merge("legal" => "yes")) }.to raise_error(TA::InvalidInput)
    end
  end
end
```

- [ ] **Step 5: run and confirm the failure.** `bundle exec rspec spec/trucebearer/adjudicator/check_result_spec.rb` — expect: FAIL with `uninitialized constant Trucebearer::Adjudicator::CheckResult`.
- [ ] **Step 6: implement.** Create `lib/trucebearer/adjudicator/check_result.rb`:

```ruby
# frozen_string_literal: true

module Trucebearer
  module Adjudicator
    # The answer to checking one order. Storable: its hash form carries format.
    # A legal result has no reasons. An illegal one has exactly one.
    CheckResult = Data.define(:legal, :reasons) do
      def initialize(legal:, reasons:)
        Shape.boolean!(legal, "legal")
        list = Shape.array!(reasons, "reasons")
        list.each { |reason| Shape.symbol_of(reason, CheckResult::REASONS, "reason", "rejection-reason") }
        if legal && !list.empty?
          raise InvalidInput, "a legal result has no reasons, got #{list.inspect}"
        elsif !legal && list.size != 1
          raise InvalidInput, "an illegal result has exactly one reason, got #{list.inspect}"
        end

        super(legal: legal, reasons: list.dup.freeze)
      end

      def to_h
        { "format" => Shape::FORMAT, "legal" => legal, "reasons" => reasons.map(&:to_s) }
      end

      def self.from_h(hash)
        Shape.format!(hash)
        Shape.keys!(hash, %w[format legal reasons])
        new(legal: Shape.boolean!(hash["legal"], "legal"),
            reasons: Shape.array!(hash["reasons"], "reasons").map do |reason|
              Shape.text_of(reason, CheckResult::REASONS, "reasons", "rejection-reason")
            end)
      end
    end

    # Every rejection reason, in the order of the tables in docs/interface.md. Internal:
    # the contract is the document, and a spec keeps the two equal.
    CheckResult::REASONS = %i[
      wrong_phase no_such_unit foreign_unit
      own_province not_reachable coast_not_allowed coast_required coast_unreachable
      not_army not_adjacent no_convoy_route
      same_province no_unit move_impossible
      not_fleet_at_sea bad_endpoints not_on_chain
    ].freeze
  end
end
```

Edit `lib/trucebearer/adjudicator.rb`: add `require_relative "adjudicator/check_result"` after the `order` require.

- [ ] **Step 7: run and confirm.** `bundle exec rspec spec/trucebearer/adjudicator/check_result_spec.rb` — expect: all PASS. Then `bundle exec rspec --exclude-pattern "**/check_spec.rb"` — expect: no failures.
- [ ] **Step 8: commit.** `git add -A adjudicator`, then `git commit -m "Add TA::CheckResult"` (with the trailer).

---

## Phase 2: The board questions (`Reach`)

**Implements:** FR-3 | **Satisfies:** AC-5.5 and AC-6.4 (their convoy-chain logic), AC-9.6 (privacy)
**Files:** `spec/trucebearer/adjudicator/reach_spec.rb`, `spec/support/board.rb`, `lib/trucebearer/adjudicator/reach.rb`, `lib/trucebearer/adjudicator.rb`
**Interfaces:** Consumes: `Map.classic`, `Map#adjacent?`, `Location`, `Unit`, `Position` (all from #9, #10). Produces, all module functions of `Reach` (private to the gem): `Reach.step_coasts(unit, province) -> Array<Symbol|nil>`, `Reach.reaches?(unit, province) -> Boolean`, `Reach.chain?(position, from, to, without: nil) -> Boolean`, `Reach.on_minimal_chain?(position, fleet_province, from, to) -> Boolean`, `Reach.touches?(sea, province) -> Boolean`; and for #12 the tables `Reach::ARMY_STEPS`, `Reach::FLEET_STEPS`. Spec helpers: `Board.loc(text)`, `Board.unit(power, type, at)`, `Board.position(*units, phase: :movement)`, `Board.verdict(position, order)`.

- [ ] **Step 1: add the spec helpers.** In `spec/support/board.rb`, add before the final `end` of `module Board`:

```ruby

  # "spa/nc" or "par" as a TA::Location.
  def loc(text)
    province, coast = text.split("/")
    L.new(province: province.to_sym, coast: coast&.to_sym)
  end

  # A unit from short pieces: unit(:france, :fleet, "spa/nc").
  def unit(power, type, at) = TA::Unit.new(power: power, type: type, location: loc(at))

  # A spring 1901 position holding only these units, no ownership.
  def position(*units, phase: :movement)
    TA::Position.new(map: "classic", season: :spring, year: 1901, phase: phase, units: units,
                     ownership: {}, dislodged_units: [], standoffs: [])
  end

  # What checking says, as the list of reasons: [] when legal.
  def verdict(position, order)
    result = TA.check(position, order)
    result.legal ? [] : result.reasons
  end
```

- [ ] **Step 2: write the spec.** Create `spec/trucebearer/adjudicator/reach_spec.rb`:

```ruby
# frozen_string_literal: true

require "trucebearer/adjudicator"
require_relative "../../support/board"

# The internal helpers of FR-3. They are private to the gem, so the spec reaches
# them through const_get (AC-9.6).
RSpec.describe "TA::Reach (internal)" do
  let(:reach) { TA.const_get(:Reach) }
  let(:fleet) { ->(at) { Board.unit(:france, :fleet, at) } }
  let(:army) { ->(at) { Board.unit(:france, :army, at) } }

  it "is not reachable from outside the module (AC-9.6)" do
    expect { TA::Reach }.to raise_error(NameError)
    expect { TA::Check }.to raise_error(NameError)
  end

  describe "step_coasts and reaches?" do
    it "gives an army's step as [nil], by land only" do
      expect(reach.step_coasts(army.("par"), :bur)).to eq([nil])
      expect(reach.step_coasts(army.("par"), :spa)).to eq([])
      expect(reach.step_coasts(army.("lvp"), :iri)).to eq([])
      expect(reach.reaches?(army.("rom"), :ven)).to be(true)
    end

    it "judges a fleet from the coast it stands on, giving the coasts it can step to" do
      expect(reach.step_coasts(fleet.("mao"), :spa)).to eq(%i[nc sc])
      expect(reach.step_coasts(fleet.("gas"), :spa)).to eq([:nc])
      expect(reach.step_coasts(fleet.("gol"), :spa)).to eq([:sc])
      expect(reach.step_coasts(fleet.("spa/nc"), :gol)).to eq([])
      expect(reach.step_coasts(fleet.("spa/sc"), :gol)).to eq([:nil.to_proc.call(nil)].compact + [nil])
      expect(reach.step_coasts(fleet.("lon"), :nth)).to eq([nil])
    end

    it "treats a province a fleet can't touch as unreachable" do
      expect(reach.reaches?(fleet.("rom"), :ven)).to be(false)
      expect(reach.reaches?(fleet.("kie"), :mun)).to be(false)
      expect(reach.reaches?(fleet.("lon"), :lon)).to be(false)
    end
  end

  describe "chain?" do
    let(:ln) { Board.position(Board.unit(:england, :army, "lon"), Board.unit(:england, :fleet, "nth")) }

    it "finds a chain of one fleet, whoever owns it" do
      expect(reach.chain?(ln, :lon, :nwy)).to be(true)
      foreign = Board.position(army.("lon"), Board.unit(:germany, :fleet, "nth"))
      expect(reach.chain?(foreign, :lon, :nwy)).to be(true)
    end

    it "finds a chain of two" do
      two = Board.position(army.("lon"), fleet.("eng"), fleet.("mao"))
      expect(reach.chain?(two, :lon, :por)).to be(true)
    end

    it "finds none without fleets, for the same province, or for inland ends" do
      expect(reach.chain?(Board.position(army.("lon")), :lon, :nwy)).to be(false)
      expect(reach.chain?(ln, :lon, :lon)).to be(false)
      expect(reach.chain?(ln, :lon, :hol)).to be(true)
      expect(reach.chain?(ln, :lon, :bur)).to be(false)
      expect(reach.chain?(ln, :bur, :nwy)).to be(false)
      expect(reach.chain?(ln, :lon, :nth)).to be(false)
    end

    it "ignores a fleet that is not at sea" do
      coastal = Board.position(army.("lon"), fleet.("wal"))
      expect(reach.chain?(coastal, :lon, :nwy)).to be(false)
    end

    it "can leave out the fleet in one province" do
      expect(reach.chain?(ln, :lon, :nwy, without: :nth)).to be(false)
      expect(reach.chain?(ln, :lon, :nwy, without: :eng)).to be(true)
    end

    it "ignores coasts at both ends (6.B.18, 6.B.19)" do
      from_bulgaria = Board.position(army.("bul"), fleet.("bla"))
      expect(reach.chain?(from_bulgaria, :bul, :sev)).to be(true)
      to_spain = Board.position(army.("tus"), fleet.("gol"))
      expect(reach.chain?(to_spain, :tus, :spa)).to be(true)
    end
  end

  describe "on_minimal_chain?" do
    let(:c) do
      Board.position(army.("lon"), fleet.("nth"), fleet.("eng"), fleet.("wal"))
    end

    it "is true for the one fleet of a one-fleet chain" do
      expect(reach.on_minimal_chain?(c, :nth, :lon, :nwy)).to be(true)
    end

    it "is false for a fleet a one-fleet chain bypasses (the shape of 6.G.19)" do
      g19 = Board.position(army.("mar"), fleet.("wes"), Board.unit(:italy, :fleet, "gol"), Board.unit(:italy, :army, "spa"))
      expect(reach.on_minimal_chain?(g19, :gol, :mar, :spa)).to be(true)
      expect(reach.on_minimal_chain?(g19, :wes, :mar, :spa)).to be(false)
    end

    it "is false for a fleet that touches a chain fleet but neither end (the shape of 6.F.12)" do
      shape = Board.position(army.("lon"), fleet.("eng"), fleet.("iri"), fleet.("nth"))
      expect(reach.on_minimal_chain?(shape, :iri, :lon, :bel)).to be(false)
    end

    it "is true for both fleets of a chain of two whose ends each touch one" do
      two = Board.position(army.("lon"), fleet.("eng"), fleet.("mao"))
      expect(reach.on_minimal_chain?(two, :eng, :lon, :por)).to be(true)
      expect(reach.on_minimal_chain?(two, :mao, :lon, :por)).to be(true)
    end

    it "is false for a coastal fleet, an empty sea, equal ends, or an end that is not coastal" do
      expect(reach.on_minimal_chain?(c, :wal, :lon, :nwy)).to be(false)
      expect(reach.on_minimal_chain?(c, :bal, :lon, :nwy)).to be(false)
      expect(reach.on_minimal_chain?(c, :nth, :lon, :lon)).to be(false)
      expect(reach.on_minimal_chain?(c, :nth, :lon, :bur)).to be(false)
      expect(reach.on_minimal_chain?(c, :nth, :iri, :nwy)).to be(false)
    end
  end
end
```

Replace the one deliberately silly expectation before running: the line `expect(reach.step_coasts(fleet.("spa/sc"), :gol)).to eq([:nil.to_proc.call(nil)].compact + [nil])` must read `expect(reach.step_coasts(fleet.("spa/sc"), :gol)).to eq([nil])`.

- [ ] **Step 3: run and confirm the failure.** `bundle exec rspec spec/trucebearer/adjudicator/reach_spec.rb` — expect: FAIL (`uninitialized constant Trucebearer::Adjudicator::Reach`, and `TA::Check` raising `NameError` already, which is a pass).
- [ ] **Step 4: implement.** Create `lib/trucebearer/adjudicator/reach.rb`:

```ruby
# frozen_string_literal: true

require "set"

module Trucebearer
  module Adjudicator
    # Internal: the questions checking asks about the board, and that legal orders (#12)
    # asks too. Not part of docs/interface.md, and it may change in any release.
    # Everything is worked out once from the map when this file loads, so the map
    # data stays the only place adjacency is written.
    module Reach
      MAP = Map.classic
      SEAS = MAP.provinces.select { |province| province.type == :sea }.map(&:id).freeze
      COASTAL = MAP.provinces.select { |province| province.type == :coastal }.map(&:id).freeze
      LAND = MAP.provinces.reject { |province| province.type == :sea }.map(&:id).freeze

      # Every place a fleet can stand, as [province, coast] (the coast is nil off a split coast).
      FLEET_PLACES = MAP.provinces.reject { |province| province.type == :inland }.flat_map do |province|
        province.coasts.empty? ? [[province.id, nil]] : province.coasts.map { |coast| [province.id, coast] }
      end.freeze

      # province => the provinces an army there can step to
      ARMY_STEPS = LAND.to_h do |from|
        steps = LAND.select do |to|
          MAP.adjacent?(:army, Location.new(province: from), Location.new(province: to))
        end
        [from, steps.freeze]
      end.freeze

      # [province, coast] => the [province, coast] places a fleet there can step to
      FLEET_STEPS = FLEET_PLACES.to_h do |(from, from_coast)|
        from_location = Location.new(province: from, coast: from_coast)
        steps = FLEET_PLACES.select do |(to, to_coast)|
          MAP.adjacent?(:fleet, from_location, Location.new(province: to, coast: to_coast))
        end
        [[from, from_coast], steps.freeze]
      end.freeze

      # sea => the seas next to it
      SEA_LINKS = SEAS.to_h do |sea|
        [sea, FLEET_STEPS.fetch([sea, nil]).map(&:first).select { |to| SEAS.include?(to) }.to_set.freeze]
      end.freeze

      # coastal province => the seas that touch any coast of it
      SEA_TOUCHES = COASTAL.to_h do |province|
        seas = FLEET_PLACES.select { |(id, _)| id == province }.flat_map do |place|
          FLEET_STEPS.fetch(place).map(&:first).select { |to| SEAS.include?(to) }
        end
        [province, seas.to_set.freeze]
      end.freeze
      NO_SEAS = Set.new.freeze

      module_function

      # The coasts (nil for a province without split coasts) a unit can step to in this
      # province from where it stands. Empty when it can't reach the province.
      def step_coasts(unit, province)
        location = unit.location
        if unit.type == :army
          ARMY_STEPS.fetch(location.province, []).include?(province) ? [nil] : []
        else
          FLEET_STEPS.fetch([location.province, location.coast]).select { |(to, _)| to == province }.map(&:last)
        end
      end

      def reaches?(unit, province)
        !step_coasts(unit, province).empty?
      end

      # True when the position has a convoy chain from one coastal province to another
      # different one. `without` leaves out the fleet standing in that province.
      def chain?(position, from, to, without: nil)
        return false if from == to

        seas = fleet_seas(position, without)
        frontier = seas.select { |sea| touches?(sea, from) }
        reached = frontier.to_set
        until frontier.empty?
          sea = frontier.pop
          return true if touches?(sea, to)

          (SEA_LINKS.fetch(sea) & seas).each { |next_sea| frontier << next_sea if reached.add?(next_sea) }
        end
        false
      end

      # True when the fleet standing in `fleet_province` is part of at least one minimal
      # convoy chain from one coastal province to another: a chain with no shortcut, so
      # that no smaller set of the position's fleets is also a chain between the same two.
      def on_minimal_chain?(position, fleet_province, from, to)
        return false if from == to || !COASTAL.include?(from) || !COASTAL.include?(to)

        seas = fleet_seas(position, nil)
        return false unless seas.include?(fleet_province)

        seas.any? { |first| touches?(first, from) && extend_chain?([first], seas, fleet_province, from, to) }
      end

      def touches?(sea, province)
        SEA_TOUCHES.fetch(province, NO_SEAS).include?(sea)
      end

      # The sea provinces that hold a fleet of any power.
      def fleet_seas(position, without)
        position.units.select { |unit| unit.type == :fleet && SEAS.include?(unit.location.province) }
                .map { |unit| unit.location.province }.reject { |sea| sea == without }.to_set
      end

      # Grows a chain one sea at a time. A new sea may not touch the origin or any sea
      # before the last one, so every chain it completes is free of shortcuts. Completed
      # when the last sea touches the destination and no earlier one does.
      def extend_chain?(path, seas, wanted, from, to)
        last = path.last
        return true if touches?(last, to) && path[0...-1].none? { |sea| touches?(sea, to) } && path.include?(wanted)

        (SEA_LINKS.fetch(last) & seas).any? do |sea|
          next false if path.include?(sea) || touches?(sea, from)
          next false if path[0...-1].any? { |earlier| SEA_LINKS.fetch(earlier).include?(sea) }

          extend_chain?(path + [sea], seas, wanted, from, to)
        end
      end
    end
    private_constant :Reach
  end
end
```

Edit `lib/trucebearer/adjudicator.rb`: add `require_relative "adjudicator/reach"` after the `check_result` require.

- [ ] **Step 5: run and confirm.** `bundle exec rspec spec/trucebearer/adjudicator/reach_spec.rb` — expect: all PASS (the `TA::Check` privacy example passes because `Check` doesn't exist yet and is private once it does). Then `bundle exec rspec --exclude-pattern "**/check_spec.rb"` — expect: no failures.
- [ ] **Step 6: commit.** `git add -A adjudicator`, then `git commit -m "Add the internal board questions for checking"` (with the trailer).

> **Complexity note** (Simplicity gate, within bounds): `Reach` builds five lookup tables when it loads. Justification: FR-3 asks for helpers #12 can reuse, and one-off scans of the map per call would make the sweep of AC-7.2 slow.

---

## Phase 3: `TA.check` for the common conditions, holds, moves and moves by convoy

**Implements:** FR-2 (common conditions, Hold, Move, MoveViaConvoy) | **Satisfies:** AC-2.1 to AC-2.7, AC-3.1 to AC-3.9, AC-4.1 to AC-4.4
**Files:** `spec/support/reasons_table.rb`, `spec/trucebearer/adjudicator/check_spec.rb`, `spec/trucebearer/adjudicator/check_move_spec.rb`, `lib/trucebearer/adjudicator/check.rb`, `lib/trucebearer/adjudicator.rb`
**Interfaces:** Consumes: `Reach.step_coasts`, `Reach.reaches?`, `Reach.chain?`, `CheckResult.new`, `Shape.instance_of!`, the six order classes. Produces: `TA.check(position, order) -> TA::CheckResult`, `Check.call(position, order)` and `Check.reason_for(position, order) -> Symbol | nil`; and for the specs `ReasonsTable.row(name) -> Array<Symbol>`, `ReasonsTable.all -> Array<Symbol>`, and `expect_precedence(row, first, second, position, both, second_only)`.

- [ ] **Step 1: write the support file.** Create `spec/support/reasons_table.rb`:

```ruby
# frozen_string_literal: true

require_relative "board"

# The table of rejection reasons in docs/interface.md, read from the document itself
# so that the specs follow it and can't drift from it (AC-7.1, AC-7.3).
module ReasonsTable
  PATH = File.expand_path("../../docs/interface.md", __dir__)

  # row name => reasons in precedence order, for example "Move" => [:own_province, ...].
  # "Hold" has no reasons of its own and is absent.
  ROWS = File.read(PATH).lines
             .drop_while { |line| !line.start_with?("### Rejection reasons") }
             .take_while { |line| !line.start_with?("What each reason means") }
             .select { |line| line.start_with?("| ") && line.include?("`") }
             .to_h do |line|
               cells = line.split("|").map(&:strip).reject(&:empty?)
               [cells[0], cells[1].scan(/`:(\w+)`/).flatten.map(&:to_sym)]
             end.freeze

  def self.row(name) = ROWS.fetch(name)
  def self.all = ROWS.values.flatten.uniq
end

# Pins one pair of the precedence in a table row. `both` fails the first and the second
# condition and must report the first. `second_only` fails the second alone.
module PrecedenceHelpers
  def expect_precedence(row, first, second, position, both, second_only)
    list = ReasonsTable.row(row)
    expect(list).to include(first, second)
    expect(list.index(first)).to be < list.index(second)
    expect(Board.verdict(position, second_only)).to eq([second])
    expect(Board.verdict(position, both)).to eq([first])
  end
end

RSpec.configure { |config| config.include PrecedenceHelpers }
```

- [ ] **Step 2: extend `check_spec.rb` with Story 2.** Add `require_relative "../../support/reasons_table"` under the existing `require_relative`, and, inside the existing `RSpec.describe "TA.check"` block after the first example, add:

```ruby
  let(:retreat) { TA::Position.from_h(start.to_h.merge("phase" => "retreat")) }
  let(:adjustment) { TA::Position.from_h(start.to_h.merge("phase" => "adjustment")) }

  # One order of each of the six types for England's fleet in London, given by `power`.
  def orders_for_london(power)
    [O::Hold.new(power: power, at: :lon),
     O::Move.new(power: power, at: :lon, destination: L.new(province: :bel)),
     O::MoveViaConvoy.new(power: power, at: :lon, to: :wal),
     O::SupportHold.new(power: power, at: :lon, target: :wal),
     O::SupportMove.new(power: power, at: :lon, from: :lon, to: :wal),
     O::Convoy.new(power: power, at: :lon, from: :lvp, to: :bel)]
  end

  it "answers a legal order with legal true and no reasons (AC-2.5)" do
    result = TA.check(start, O::Hold.new(power: :england, at: :lon))
    expect([result.legal, result.reasons]).to eq([true, []])
  end

  it "makes a hold legal for every unit of a movement position (AC-2.5)" do
    start.units.each do |unit|
      order = O::Hold.new(power: unit.power, at: unit.location.province)
      expect(Board.verdict(start, order)).to eq([])
    end
  end

  it "gives :wrong_phase and nothing else outside the movement phase, for every order (AC-2.2)" do
    [retreat, adjustment].each do |position|
      orders_for_london(:england).each { |order| expect(Board.verdict(position, order)).to eq([:wrong_phase]) }
      orders_for_london(:france).each { |order| expect(Board.verdict(position, order)).to eq([:wrong_phase]) }
      empty = O::Hold.new(power: :england, at: :wal)
      expect(Board.verdict(position, empty)).to eq([:wrong_phase])
    end
  end

  it "gives :no_such_unit when no unit stands in the at province, for every order type (AC-2.3)" do
    nobody = [O::Hold.new(power: :england, at: :wal),
              O::Move.new(power: :england, at: :wal, destination: L.new(province: :lon)),
              O::MoveViaConvoy.new(power: :england, at: :wal, to: :lon),
              O::SupportHold.new(power: :england, at: :wal, target: :wal),
              O::SupportMove.new(power: :england, at: :wal, from: :wal, to: :wal),
              O::Convoy.new(power: :england, at: :wal, from: :wal, to: :wal)]
    nobody.each { |order| expect(Board.verdict(start, order)).to eq([:no_such_unit]) }
  end

  it "gives :foreign_unit for another power's unit, for every order type (AC-2.4)" do
    orders_for_london(:france).each { |order| expect(Board.verdict(start, order)).to eq([:foreign_unit]) }
  end

  it "checks the phase first, then the unit, then its owner (AC-2.2 to AC-2.4)" do
    expect(Board.verdict(retreat, O::Hold.new(power: :france, at: :wal))).to eq([:wrong_phase])
    expect(Board.verdict(start, O::Hold.new(power: :france, at: :wal))).to eq([:no_such_unit])
    expect(Board.verdict(start, O::Hold.new(power: :france, at: :lon))).to eq([:foreign_unit])
  end

  it "reads the position and the order alone, and changes neither (AC-2.6)" do
    order = O::SupportMove.new(power: :austria, at: :vie, from: :war, to: :gal)
    before = [start.to_h, order.to_h]
    first = TA.check(start, order)
    expect(TA.check(start, order)).to eq(first)
    expect([start.to_h, order.to_h]).to eq(before)
    unowned = start.with(ownership: {})
    expect(TA.check(unowned, order)).to eq(first)
  end

  it "judges a support for a foreign unit like one for the supporter's own (AC-2.6)" do
    own = O::SupportHold.new(power: :germany, at: :mun, target: :ber)
    foreign = O::SupportHold.new(power: :italy, at: :ven, target: :tri)
    expect(Board.verdict(start, own)).to eq([])
    expect(Board.verdict(start, foreign)).to eq([])
  end

  it "raises InvalidInput, naming the argument, for something that isn't a position or an order (AC-2.7)" do
    order = O::Hold.new(power: :england, at: :lon)
    [nil, start.to_h, :start].each do |bad|
      expect { TA.check(bad, order) }.to raise_error(TA::InvalidInput, /#{Regexp.escape(bad.inspect)}/)
    end
    [nil, order.to_h, :hold, TA::Unit.new(power: :england, type: :fleet, location: L.new(province: :lon))].each do |bad|
      expect { TA.check(start, bad) }.to raise_error(TA::InvalidInput, /#{Regexp.escape(bad.inspect)}/)
    end
  end
```

- [ ] **Step 3: write the move spec.** Create `spec/trucebearer/adjudicator/check_move_spec.rb`:

```ruby
# frozen_string_literal: true

require "trucebearer/adjudicator"
require_relative "../../support/board"
require_relative "../../support/reasons_table"

# TA.check for moves (Story 3) and moves by convoy (Story 4).
RSpec.describe "TA.check: moves and moves by convoy" do
  def u(power, type, at) = Board.unit(power, type, at)

  def move(power, at, to) = O::Move.new(power: power, at: at, destination: Board.loc(to))

  def via(power, at, to) = O::MoveViaConvoy.new(power: power, at: at, to: to)

  def verdict(position, order) = Board.verdict(position, order)

  let(:start) { TA::Map.classic.starting_position }
  let(:ln) { Board.position(u(:england, :army, "lon"), u(:england, :fleet, "nth")) }

  describe "Move" do
    it "gives the interface examples' results (AC-3.1)" do
      expect(verdict(start, move(:russia, :sev, "rum"))).to eq([])
      expect(verdict(start, move(:england, :lon, "bel"))).to eq([:not_reachable])
      expect(verdict(start, move(:france, :mar, "spa/nc"))).to eq([:coast_not_allowed])
    end

    it "allows a move the unit can reach (AC-3.2)" do
      expect(verdict(Board.position(u(:france, :army, "par")), move(:france, :par, "bur"))).to eq([])
      expect(verdict(Board.position(u(:england, :fleet, "nth")), move(:england, :nth, "eng"))).to eq([])
      expect(verdict(Board.position(u(:france, :fleet, "por")), move(:france, :por, "mao"))).to eq([])
      expect(verdict(Board.position(u(:england, :fleet, "lon")), move(:england, :lon, "eng"))).to eq([])
    end

    it "allows a fleet to name a coast it can reach (AC-3.2)" do
      at_sea = Board.position(u(:france, :fleet, "mao"))
      expect(verdict(at_sea, move(:france, :mao, "spa/nc"))).to eq([])
      expect(verdict(at_sea, move(:france, :mao, "spa/sc"))).to eq([])
      expect(verdict(Board.position(u(:france, :fleet, "gas")), move(:france, :gas, "spa/nc"))).to eq([])
    end

    it "allows an army to go by a convoy chain it can't walk (AC-3.2)" do
      expect(verdict(ln, move(:england, :lon, "nwy"))).to eq([])
      two = Board.position(u(:england, :army, "lon"), u(:england, :fleet, "eng"), u(:france, :fleet, "mao"))
      expect(verdict(two, move(:england, :lon, "por"))).to eq([])
    end

    it "gives :own_province for the unit's own province (AC-3.3)" do
      expect(verdict(Board.position(u(:france, :army, "par")), move(:france, :par, "par"))).to eq([:own_province])
      expect(verdict(Board.position(u(:england, :fleet, "lon")), move(:england, :lon, "lon"))).to eq([:own_province])
      crawl = Board.position(u(:france, :fleet, "spa/nc"))
      expect(verdict(crawl, move(:france, :spa, "spa/sc"))).to eq([:own_province])
    end

    it "gives :not_reachable for what the unit can't reach (AC-3.4)" do
      expect(verdict(Board.position(u(:england, :army, "lvp")), move(:england, :lvp, "iri"))).to eq([:not_reachable])
      expect(verdict(Board.position(u(:england, :army, "lon")), move(:england, :lon, "bel"))).to eq([:not_reachable])
      expect(verdict(Board.position(u(:germany, :fleet, "kie")), move(:germany, :kie, "mun"))).to eq([:not_reachable])
      expect(verdict(Board.position(u(:england, :fleet, "nth")), move(:england, :nth, "pic"))).to eq([:not_reachable])
    end

    it "never lets a fleet go by a convoy chain (AC-3.4, 6.A.7)" do
      with_chain = Board.position(u(:england, :fleet, "lon"), u(:england, :fleet, "nth"))
      expect(verdict(with_chain, move(:england, :lon, "nwy"))).to eq([:not_reachable])
    end

    it "judges a fleet from its own coast (AC-3.4, 6.B.11)" do
      north = Board.position(u(:france, :fleet, "spa/nc"))
      expect(verdict(north, move(:france, :spa, "gol"))).to eq([:not_reachable])
      south = Board.position(u(:france, :fleet, "spa/sc"))
      expect(verdict(south, move(:france, :spa, "gol"))).to eq([])
    end

    it "gives :coast_not_allowed for an army's move that names a coast (AC-3.5)" do
      expect(verdict(Board.position(u(:france, :army, "gas")), move(:france, :gas, "spa/nc"))).to eq([:coast_not_allowed])
      by_chain = Board.position(u(:italy, :army, "tus"), u(:italy, :fleet, "gol"))
      expect(verdict(by_chain, move(:italy, :tus, "spa/sc"))).to eq([:coast_not_allowed])
    end

    it "gives :coast_required for a fleet's move to split coasts with no coast named (AC-3.6)" do
      expect(verdict(Board.position(u(:france, :fleet, "por")), move(:france, :por, "spa"))).to eq([:coast_required])
      expect(verdict(Board.position(u(:france, :fleet, "gas")), move(:france, :gas, "spa"))).to eq([:coast_required])
    end

    it "gives :coast_unreachable for a coast the fleet can't reach, and never corrects it (AC-3.7)" do
      expect(verdict(Board.position(u(:france, :fleet, "gas")), move(:france, :gas, "spa/sc"))).to eq([:coast_unreachable])
      expect(verdict(Board.position(u(:france, :fleet, "gol")), move(:france, :gol, "spa/nc"))).to eq([:coast_unreachable])
    end

    it "judges each unit type by its own adjacency (AC-3.9)" do
      expect(verdict(Board.position(u(:italy, :army, "rom")), move(:italy, :rom, "ven"))).to eq([])
      expect(verdict(Board.position(u(:italy, :fleet, "rom")), move(:italy, :rom, "ven"))).to eq([:not_reachable])
      expect(verdict(Board.position(u(:england, :fleet, "lon")), move(:england, :lon, "nth"))).to eq([])
      expect(verdict(Board.position(u(:england, :army, "lon")), move(:england, :lon, "nth"))).to eq([:not_reachable])
    end

    # AC-3.8: seven pairs can fail together. Each is pinned with an order that fails both
    # conditions, and an order that fails only the second.
    describe "precedence (AC-3.8)" do
      it "own_province before not_reachable" do
        expect_precedence("Move", :own_province, :not_reachable, Board.position(u(:england, :fleet, "lon")),
                          move(:england, :lon, "lon"), move(:england, :lon, "bel"))
      end

      it "own_province before coast_not_allowed" do
        position = Board.position(u(:france, :army, "spa"), u(:france, :army, "gas"))
        expect_precedence("Move", :own_province, :coast_not_allowed, position,
                          move(:france, :spa, "spa/nc"), move(:france, :gas, "spa/nc"))
      end

      it "own_province before coast_required" do
        position = Board.position(u(:france, :fleet, "spa/nc"), u(:france, :fleet, "por"))
        expect_precedence("Move", :own_province, :coast_required, position,
                          move(:france, :spa, "spa"), move(:france, :por, "spa"))
      end

      it "own_province before coast_unreachable" do
        position = Board.position(u(:france, :fleet, "spa/nc"), u(:france, :fleet, "gas"))
        expect_precedence("Move", :own_province, :coast_unreachable, position,
                          move(:france, :spa, "spa/sc"), move(:france, :gas, "spa/sc"))
      end

      it "not_reachable before coast_not_allowed" do
        position = Board.position(u(:france, :army, "par"), u(:france, :army, "gas"))
        expect_precedence("Move", :not_reachable, :coast_not_allowed, position,
                          move(:france, :par, "spa/nc"), move(:france, :gas, "spa/nc"))
      end

      it "not_reachable before coast_required" do
        position = Board.position(u(:england, :fleet, "lon"), u(:france, :fleet, "por"))
        expect_precedence("Move", :not_reachable, :coast_required, position,
                          move(:england, :lon, "spa"), move(:france, :por, "spa"))
      end

      it "not_reachable before coast_unreachable" do
        position = Board.position(u(:england, :fleet, "lon"), u(:france, :fleet, "gas"))
        expect_precedence("Move", :not_reachable, :coast_unreachable, position,
                          move(:england, :lon, "spa/nc"), move(:france, :gas, "spa/sc"))
      end

      it "never reports two of the three coast reasons together (AC-3.8)" do
        # An army has no :coast_required or :coast_unreachable, and a fleet no :coast_not_allowed.
        army_naming = Board.position(u(:france, :army, "gas"))
        expect(verdict(army_naming, move(:france, :gas, "spa/sc"))).to eq([:coast_not_allowed])
        fleet_without = Board.position(u(:france, :fleet, "gas"))
        expect(verdict(fleet_without, move(:france, :gas, "spa"))).to eq([:coast_required])
        fleet_naming = Board.position(u(:france, :fleet, "gas"))
        expect(verdict(fleet_naming, move(:france, :gas, "spa/sc"))).to eq([:coast_unreachable])
      end
    end
  end

  describe "MoveViaConvoy" do
    it "gives :no_convoy_route for the interface example (AC-4.1)" do
      expect(verdict(start, via(:england, :lvp, :wal))).to eq([:no_convoy_route])
    end

    it "is legal for an army that could walk there, with a chain (AC-4.2)" do
      expect(verdict(ln, via(:england, :lon, :yor))).to eq([])
    end

    it "gives one reason for each condition (AC-4.3)" do
      expect(verdict(Board.position(u(:england, :fleet, "lon"), u(:england, :fleet, "nth")), via(:england, :lon, :wal)))
        .to eq([:not_army])
      expect(verdict(ln, via(:england, :lon, :lon))).to eq([:own_province])
      expect(verdict(ln, via(:england, :lon, :nwy))).to eq([:not_adjacent])
      expect(verdict(Board.position(u(:england, :army, "lon")), via(:england, :lon, :wal))).to eq([:no_convoy_route])
    end

    describe "precedence (AC-4.4)" do
      def position_for(*units) = Board.position(*units)

      it "not_army before own_province" do
        expect_precedence("MoveViaConvoy", :not_army, :own_province,
                          position_for(u(:england, :fleet, "lon"), u(:england, :army, "lvp")),
                          via(:england, :lon, :lon), via(:england, :lvp, :lvp))
      end

      it "not_army before not_adjacent" do
        expect_precedence("MoveViaConvoy", :not_army, :not_adjacent,
                          position_for(u(:england, :fleet, "lon"), u(:england, :army, "lvp")),
                          via(:england, :lon, :bel), via(:england, :lvp, :bel))
      end

      it "not_army before no_convoy_route" do
        expect_precedence("MoveViaConvoy", :not_army, :no_convoy_route,
                          position_for(u(:england, :fleet, "lvp"), u(:england, :army, "lon")),
                          via(:england, :lvp, :wal), via(:england, :lon, :wal))
      end

      it "own_province before not_adjacent" do
        expect_precedence("MoveViaConvoy", :own_province, :not_adjacent,
                          position_for(u(:england, :army, "lon"), u(:england, :army, "lvp")),
                          via(:england, :lon, :lon), via(:england, :lvp, :bel))
      end

      it "own_province before no_convoy_route" do
        expect_precedence("MoveViaConvoy", :own_province, :no_convoy_route,
                          position_for(u(:england, :army, "lon"), u(:england, :army, "lvp")),
                          via(:england, :lon, :lon), via(:england, :lvp, :wal))
      end

      it "not_adjacent before no_convoy_route" do
        expect_precedence("MoveViaConvoy", :not_adjacent, :no_convoy_route,
                          position_for(u(:england, :army, "lon"), u(:england, :army, "lvp")),
                          via(:england, :lon, :bel), via(:england, :lvp, :wal))
      end
    end
  end
end
```

- [ ] **Step 4: run and confirm the failure.** `bundle exec rspec spec/trucebearer/adjudicator/check_spec.rb spec/trucebearer/adjudicator/check_move_spec.rb` — expect: FAIL with `NoMethodError: undefined method 'check' for module Trucebearer::Adjudicator`.
- [ ] **Step 5: implement.** Create `lib/trucebearer/adjudicator/check.rb`:

```ruby
# frozen_string_literal: true

module Trucebearer
  module Adjudicator
    # Internal: checks one order against a position, following the precedence tables of
    # docs/interface.md `## Checking an order`. TA.check is its one public door.
    module Check
      ORDERS = [Order::Hold, Order::Move, Order::MoveViaConvoy,
                Order::SupportHold, Order::SupportMove, Order::Convoy].freeze

      module_function

      def call(position, order)
        Shape.instance_of!(position, Position, "position")
        unless ORDERS.any? { |klass| order.is_a?(klass) }
          raise InvalidInput, "\"order\" must be one of the six order classes, got #{order.inspect}"
        end

        reason = reason_for(position, order)
        reason ? CheckResult.new(legal: false, reasons: [reason]) : CheckResult.new(legal: true, reasons: [])
      end

      # The first failing condition's reason, or nil when the order is legal.
      def reason_for(position, order)
        return :wrong_phase unless position.phase == :movement

        unit = unit_at(position, order.at)
        return :no_such_unit unless unit
        return :foreign_unit unless unit.power == order.power

        case order
        when Order::Hold then nil
        when Order::Move then move(position, unit, order)
        when Order::MoveViaConvoy then move_via_convoy(position, unit, order)
        end
      end

      def move(position, unit, order)
        destination = order.destination
        return :own_province if destination.province == order.at

        coasts = Reach.step_coasts(unit, destination.province)
        by_chain = unit.type == :army && Reach.chain?(position, order.at, destination.province)
        return :not_reachable if coasts.empty? && !by_chain

        if unit.type == :army
          destination.coast ? :coast_not_allowed : nil
        elsif Map.classic.coasts(destination.province).empty?
          nil
        elsif destination.coast.nil?
          :coast_required
        elsif !coasts.include?(destination.coast)
          :coast_unreachable
        end
      end

      def move_via_convoy(position, unit, order)
        return :not_army unless unit.type == :army
        return :own_province if order.to == order.at
        return :not_adjacent unless Reach.reaches?(unit, order.to)

        :no_convoy_route unless Reach.chain?(position, order.at, order.to)
      end

      def unit_at(position, province)
        position.units.find { |unit| unit.location.province == province }
      end
    end
    private_constant :Check
  end
end
```

Edit `lib/trucebearer/adjudicator.rb`: add `require_relative "adjudicator/check"` after the `reach` require, and, inside `module Adjudicator` (replacing the empty body), the door:

```ruby
module Trucebearer
  # The rules engine: checks orders and adjudicates each phase of a game turn.
  module Adjudicator
    # Checks one order against a position and says whether it is legal, with the first
    # reason it is not (docs/interface.md, "Checking an order"). Raises InvalidInput only for
    # an argument that is not a position or an order; a broken rule is a result, never an error.
    def self.check(position, order) = Check.call(position, order)
  end
end
```

- [ ] **Step 6: run and confirm.** `bundle exec rspec spec/trucebearer/adjudicator/check_spec.rb spec/trucebearer/adjudicator/check_move_spec.rb` — expect: all PASS, including the first spec of the feature. Then `bundle exec rspec` — expect: the whole suite passes (the exclude pattern is no longer needed).
- [ ] **Step 7: commit.** `git add -A adjudicator`, then `git commit -m "Add TA.check for holds, moves and moves by convoy"` (with the trailer).

---

## Phase 4: Supports and convoys

**Implements:** FR-2 (SupportHold, SupportMove, Convoy) | **Satisfies:** AC-5.1 to AC-5.7, AC-6.1 to AC-6.6
**Files:** `spec/trucebearer/adjudicator/check_support_spec.rb`, `spec/trucebearer/adjudicator/check_convoy_spec.rb`, `lib/trucebearer/adjudicator/check.rb`
**Interfaces:** Consumes: `Reach.reaches?`, `Reach.chain?(position, from, to, without:)`, `Reach.on_minimal_chain?`, `Check.unit_at`, `expect_precedence`. Produces: `Check.support_hold`, `Check.support_move`, `Check.convoy`, `Check.could_move?(position, unit, province, supporter_province)`, `Check.coastal?(province)`.

- [ ] **Step 1: write the support spec.** Create `spec/trucebearer/adjudicator/check_support_spec.rb`:

```ruby
# frozen_string_literal: true

require "trucebearer/adjudicator"
require_relative "../../support/board"
require_relative "../../support/reasons_table"

# TA.check for supports (Story 5).
RSpec.describe "TA.check: supports" do
  def u(power, type, at) = Board.unit(power, type, at)

  def hold_support(power, at, target) = O::SupportHold.new(power: power, at: at, target: target)

  def move_support(power, at, from, to) = O::SupportMove.new(power: power, at: at, from: from, to: to)

  def verdict(position, order) = Board.verdict(position, order)

  let(:start) { TA::Map.classic.starting_position }

  describe "SupportHold" do
    it "gives the interface examples' results (AC-5.1)" do
      expect(verdict(start, hold_support(:germany, :mun, :ber))).to eq([])
      expect(verdict(start, hold_support(:germany, :mun, :sil))).to eq([:no_unit])
    end

    it "is legal for a unit the supporter can reach, whoever owns it (AC-5.2)" do
      expect(verdict(start, hold_support(:italy, :ven, :tri))).to eq([])
    end

    it "gives one reason for each condition (AC-5.2)" do
      expect(verdict(start, hold_support(:germany, :mun, :mun))).to eq([:own_province])
      expect(verdict(start, hold_support(:germany, :mun, :sil))).to eq([:no_unit])
      expect(verdict(start, hold_support(:germany, :mun, :vie))).to eq([:not_reachable])
    end

    describe "precedence (AC-5.7)" do
      let(:position) { Board.position(u(:england, :fleet, "lon"), u(:england, :army, "bel")) }

      it "own_province before not_reachable" do
        expect_precedence("SupportHold", :own_province, :not_reachable, position,
                          hold_support(:england, :lon, :lon), hold_support(:england, :lon, :bel))
      end

      it "no_unit before not_reachable" do
        expect_precedence("SupportHold", :no_unit, :not_reachable, position,
                          hold_support(:england, :lon, :hol), hold_support(:england, :lon, :bel))
      end

      it "never reports own_province together with no_unit: the supporter stands in its own province" do
        expect(verdict(position, hold_support(:england, :lon, :lon))).to eq([:own_province])
      end
    end
  end

  describe "SupportMove" do
    it "is legal for Austria supporting a Russian army, as in the interface (AC-5.1)" do
      expect(verdict(start, move_support(:austria, :vie, :war, :gal))).to eq([])
    end

    it "gives one reason for each condition (AC-5.3)" do
      expect(verdict(start, move_support(:austria, :vie, :vie, :gal))).to eq([:own_province])
      expect(verdict(start, move_support(:austria, :vie, :war, :vie))).to eq([:own_province])
      expect(verdict(start, move_support(:austria, :vie, :war, :war))).to eq([:same_province])
      expect(verdict(start, move_support(:austria, :vie, :sil, :gal))).to eq([:no_unit])
      expect(verdict(start, move_support(:austria, :vie, :war, :ukr))).to eq([:not_reachable])
    end

    it "judges a fleet supporter's reach from the coast it stands on (AC-5.3, 6.B.5)" do
      position = Board.position(u(:france, :fleet, "mar"), u(:france, :fleet, "spa/nc"))
      expect(verdict(position, move_support(:france, :spa, :mar, :gol))).to eq([:not_reachable])
      south = Board.position(u(:france, :fleet, "mar"), u(:france, :fleet, "spa/sc"))
      expect(verdict(south, move_support(:france, :spa, :mar, :gol))).to eq([])
    end

    it "is :move_impossible when the supported unit couldn't move there itself (AC-5.4)" do
      two_armies = Board.position(u(:england, :army, "lon"), u(:england, :army, "bel"))
      expect(verdict(two_armies, move_support(:england, :lon, :bel, :yor))).to eq([:move_impossible])
      fleet = Board.position(u(:italy, :fleet, "rom"), u(:italy, :army, "apu"))
      expect(verdict(fleet, move_support(:italy, :rom, :apu, :ven))).to eq([:not_reachable])
      fleets = Board.position(u(:france, :fleet, "wes"), u(:france, :fleet, "gas"))
      expect(verdict(fleets, move_support(:france, :wes, :gas, :spa))).to eq([])
    end

    it "is legal for a coast the supporter can't reach itself, whatever coast the supported fleet is on (AC-5.4, 6.B.4, 6.B.17)" do
      expect(verdict(Board.position(u(:france, :fleet, "mar"), u(:france, :fleet, "gas")),
                     move_support(:france, :mar, :gas, :spa))).to eq([])
      expect(verdict(Board.position(u(:italy, :fleet, "wes"), u(:france, :fleet, "spa/nc")),
                     move_support(:italy, :wes, :spa, :mao))).to eq([])
    end

    it "judges the supported army's convoy chain without the supporter's fleet (AC-5.5, 6.D.31)" do
      shaped = Board.position(u(:austria, :army, "rum"), u(:turkey, :fleet, "bla"))
      expect(verdict(shaped, move_support(:turkey, :bla, :rum, :arm))).to eq([:move_impossible])
      other = Board.position(u(:austria, :army, "rum"), u(:turkey, :fleet, "bla"), u(:turkey, :army, "ank"))
      expect(verdict(other, move_support(:turkey, :ank, :rum, :arm))).to eq([])
    end

    it "treats a support for a foreign unit like any other, and names no coast (AC-5.6)" do
      expect(verdict(start, move_support(:austria, :vie, :war, :gal))).to eq([])
      expect(O::SupportMove.members).to eq(%i[power at from to])
    end

    # AC-5.7: nine pairs can fail together. The tenth, no_unit with move_impossible, never
    # does, because an empty origin has no unit to judge.
    describe "precedence (AC-5.7)" do
      let(:lon_bel) { Board.position(u(:england, :army, "lon"), u(:england, :army, "bel")) }
      let(:lon_bel_hol) { Board.position(u(:england, :army, "lon"), u(:england, :army, "bel"), u(:england, :army, "hol")) }

      it "own_province before same_province" do
        expect_precedence("SupportMove", :own_province, :same_province, lon_bel,
                          move_support(:england, :lon, :lon, :lon), move_support(:england, :lon, :bel, :bel))
      end

      it "own_province before no_unit" do
        expect_precedence("SupportMove", :own_province, :no_unit, lon_bel,
                          move_support(:england, :lon, :wal, :lon), move_support(:england, :lon, :wal, :yor))
      end

      it "own_province before not_reachable" do
        expect_precedence("SupportMove", :own_province, :not_reachable, lon_bel,
                          move_support(:england, :lon, :bel, :lon), move_support(:england, :lon, :bel, :hol))
      end

      it "own_province before move_impossible" do
        expect_precedence("SupportMove", :own_province, :move_impossible, lon_bel,
                          move_support(:england, :lon, :bel, :lon), move_support(:england, :lon, :bel, :yor))
      end

      it "same_province before no_unit" do
        expect_precedence("SupportMove", :same_province, :no_unit, lon_bel,
                          move_support(:england, :lon, :wal, :wal), move_support(:england, :lon, :wal, :yor))
      end

      it "same_province before not_reachable" do
        expect_precedence("SupportMove", :same_province, :not_reachable, lon_bel_hol,
                          move_support(:england, :lon, :hol, :hol), move_support(:england, :lon, :bel, :hol))
      end

      it "same_province before move_impossible" do
        position = Board.position(u(:england, :army, "lon"), u(:england, :army, "wal"), u(:england, :army, "bel"))
        expect_precedence("SupportMove", :same_province, :move_impossible, position,
                          move_support(:england, :lon, :wal, :wal), move_support(:england, :lon, :bel, :yor))
      end

      it "no_unit before not_reachable" do
        expect_precedence("SupportMove", :no_unit, :not_reachable, lon_bel,
                          move_support(:england, :lon, :wal, :hol), move_support(:england, :lon, :bel, :hol))
      end

      it "not_reachable before move_impossible" do
        position = Board.position(u(:england, :army, "lon"), u(:england, :army, "bel"))
        expect_precedence("SupportMove", :not_reachable, :move_impossible, position,
                          move_support(:england, :lon, :bel, :den), move_support(:england, :lon, :bel, :yor))
      end

      it "never reports no_unit together with move_impossible: an empty origin has no unit to judge" do
        expect(verdict(lon_bel, move_support(:england, :lon, :wal, :yor))).to eq([:no_unit])
      end
    end
  end
end
```

- [ ] **Step 2: write the convoy spec.** Create `spec/trucebearer/adjudicator/check_convoy_spec.rb`:

```ruby
# frozen_string_literal: true

require "trucebearer/adjudicator"
require_relative "../../support/board"
require_relative "../../support/reasons_table"

# TA.check for convoys (Story 6).
RSpec.describe "TA.check: convoys" do
  def u(power, type, at) = Board.unit(power, type, at)

  def convoy(power, at, from, to) = O::Convoy.new(power: power, at: at, from: from, to: to)

  def verdict(position, order) = Board.verdict(position, order)

  let(:start) { TA::Map.classic.starting_position }
  # England's army in London, fleets in the North Sea and the Channel, and a coastal fleet in Wales.
  let(:c) do
    Board.position(u(:england, :army, "lon"), u(:england, :fleet, "nth"), u(:england, :fleet, "eng"), u(:england, :fleet, "wal"))
  end

  it "gives :not_fleet_at_sea for the interface example (AC-6.1)" do
    expect(verdict(start, convoy(:england, :lon, :lvp, :bel))).to eq([:not_fleet_at_sea])
  end

  it "is legal for a fleet on a minimal chain, whoever owns the army and the fleets (AC-6.2)" do
    expect(verdict(c, convoy(:england, :nth, :lon, :nwy))).to eq([])
    foreign = Board.position(u(:germany, :army, "lon"), u(:england, :fleet, "nth"))
    expect(verdict(foreign, convoy(:england, :nth, :lon, :nwy))).to eq([])
  end

  it "gives one reason for each condition (AC-6.3)" do
    expect(verdict(c, convoy(:england, :lon, :lon, :nwy))).to eq([:not_fleet_at_sea])
    expect(verdict(c, convoy(:england, :wal, :lon, :nwy))).to eq([:not_fleet_at_sea])
    expect(verdict(c, convoy(:england, :nth, :lon, :lon))).to eq([:bad_endpoints])
    expect(verdict(c, convoy(:england, :nth, :lon, :nth))).to eq([:bad_endpoints])
    expect(verdict(c, convoy(:england, :nth, :bur, :nwy))).to eq([:bad_endpoints])
    expect(verdict(c, convoy(:england, :nth, :yor, :nwy))).to eq([:no_unit])
    expect(verdict(c, convoy(:england, :nth, :wal, :nwy))).to eq([:no_unit])
    expect(verdict(c, convoy(:england, :eng, :lon, :nwy))).to eq([:not_on_chain])
  end

  it "shows a fleet bypassed by a shorter chain is refused, as in 6.G.19 (AC-6.4)" do
    g19 = Board.position(u(:france, :army, "mar"), u(:france, :fleet, "wes"), u(:italy, :fleet, "gol"), u(:italy, :army, "spa"))
    expect(verdict(g19, convoy(:france, :wes, :mar, :spa))).to eq([:not_on_chain])
    expect(verdict(g19, convoy(:italy, :gol, :mar, :spa))).to eq([])
  end

  it "shows a sea fleet touching a chain fleet but neither end is refused, as in 6.F.12 (AC-6.4)" do
    shape = Board.position(u(:england, :army, "lon"), u(:england, :fleet, "eng"), u(:england, :fleet, "iri"), u(:england, :fleet, "nth"))
    expect(verdict(shape, convoy(:england, :iri, :lon, :bel))).to eq([:not_on_chain])
  end

  it "makes both fleets of a chain of two legal (AC-6.4)" do
    two = Board.position(u(:england, :army, "lon"), u(:england, :fleet, "eng"), u(:france, :fleet, "mao"))
    expect(verdict(two, convoy(:england, :eng, :lon, :por))).to eq([])
    expect(verdict(two, convoy(:france, :mao, :lon, :por))).to eq([])
  end

  it "ignores coasts at both ends (AC-6.5, 6.B.18, 6.B.19)" do
    from_bulgaria = Board.position(u(:turkey, :army, "bul"), u(:turkey, :fleet, "bla"))
    expect(verdict(from_bulgaria, convoy(:turkey, :bla, :bul, :sev))).to eq([])
    to_spain = Board.position(u(:italy, :army, "tus"), u(:italy, :fleet, "gol"))
    expect(verdict(to_spain, convoy(:italy, :gol, :tus, :spa))).to eq([])
  end

  # AC-6.6: every pair can fail together. Each uses the position `c`.
  describe "precedence (AC-6.6)" do
    it "not_fleet_at_sea before bad_endpoints" do
      expect_precedence("Convoy", :not_fleet_at_sea, :bad_endpoints, c,
                        convoy(:england, :lon, :lon, :lon), convoy(:england, :nth, :lon, :lon))
    end

    it "not_fleet_at_sea before no_unit" do
      expect_precedence("Convoy", :not_fleet_at_sea, :no_unit, c,
                        convoy(:england, :wal, :yor, :nwy), convoy(:england, :nth, :yor, :nwy))
    end

    it "not_fleet_at_sea before not_on_chain" do
      expect_precedence("Convoy", :not_fleet_at_sea, :not_on_chain, c,
                        convoy(:england, :wal, :lon, :nwy), convoy(:england, :eng, :lon, :nwy))
    end

    it "bad_endpoints before no_unit" do
      expect_precedence("Convoy", :bad_endpoints, :no_unit, c,
                        convoy(:england, :nth, :iri, :nwy), convoy(:england, :nth, :yor, :nwy))
    end

    it "bad_endpoints before not_on_chain" do
      expect_precedence("Convoy", :bad_endpoints, :not_on_chain, c,
                        convoy(:england, :eng, :lon, :lon), convoy(:england, :eng, :lon, :nwy))
    end

    it "no_unit before not_on_chain" do
      expect_precedence("Convoy", :no_unit, :not_on_chain, c,
                        convoy(:england, :eng, :yor, :nwy), convoy(:england, :eng, :lon, :nwy))
    end
  end
end
```

- [ ] **Step 3: run and confirm the failures.** `bundle exec rspec spec/trucebearer/adjudicator/check_support_spec.rb spec/trucebearer/adjudicator/check_convoy_spec.rb` — expect: FAIL. The support and convoy orders fall through `reason_for`'s `case`, which returns `nil`, so each example that expects a reason fails with `expected [:own_province] got []`.
- [ ] **Step 4: implement.** In `lib/trucebearer/adjudicator/check.rb`, replace the `case` in `reason_for` with:

```ruby
        case order
        when Order::Hold then nil
        when Order::Move then move(position, unit, order)
        when Order::MoveViaConvoy then move_via_convoy(position, unit, order)
        when Order::SupportHold then support_hold(position, unit, order)
        when Order::SupportMove then support_move(position, unit, order)
        when Order::Convoy then convoy(position, unit, order)
        end
```

and add these methods after `move_via_convoy`:

```ruby
      def support_hold(position, unit, order)
        return :own_province if order.target == order.at
        return :no_unit unless unit_at(position, order.target)

        :not_reachable unless Reach.reaches?(unit, order.target)
      end

      def support_move(position, unit, order)
        return :own_province if order.from == order.at || order.to == order.at
        return :same_province if order.from == order.to

        supported = unit_at(position, order.from)
        return :no_unit unless supported
        return :not_reachable unless Reach.reaches?(unit, order.to)

        :move_impossible unless could_move?(position, supported, order.to, order.at)
      end

      def convoy(position, unit, order)
        return :not_fleet_at_sea unless unit.type == :fleet && Map.classic.province(order.at).type == :sea
        return :bad_endpoints if order.from == order.to || !coastal?(order.from) || !coastal?(order.to)

        army = unit_at(position, order.from)
        return :no_unit unless army&.type == :army

        :not_on_chain unless Reach.on_minimal_chain?(position, order.at, order.from, order.to)
      end

      # Could this unit make a plain move into the province? An army may also go by a
      # convoy chain that doesn't need the supporter's fleet (6.D.31).
      def could_move?(position, unit, province, supporter_province)
        return true if Reach.reaches?(unit, province)

        unit.type == :army && Reach.chain?(position, unit.location.province, province, without: supporter_province)
      end

      def coastal?(province)
        Map.classic.province(province).type == :coastal
      end
```

- [ ] **Step 5: run and confirm.** `bundle exec rspec spec/trucebearer/adjudicator/check_support_spec.rb spec/trucebearer/adjudicator/check_convoy_spec.rb` — expect: all PASS. Then `bundle exec rspec` — expect: no failures.
- [ ] **Step 6: commit.** `git add -A adjudicator`, then `git commit -m "Add TA.check for supports and convoys"` (with the trailer).

---

## Phase 5: Every reason, the table and the sweep

**Implements:** FR-2 (the tables), FR-1 (`REASONS`) | **Satisfies:** AC-7.1, AC-7.2, AC-7.3
**Files:** `spec/trucebearer/adjudicator/check_reasons_spec.rb`
**Interfaces:** Consumes: `ReasonsTable.row`, `ReasonsTable.all`, `Board.verdict`, `TA::CheckResult::REASONS`. Produces: the guard specs only.

The specs of Phases 3 and 4 already pin every reason and each pair. This phase adds the checks that tie the code to the document and the whole-input sweep.

- [ ] **Step 1: write the spec.** Create `spec/trucebearer/adjudicator/check_reasons_spec.rb`:

```ruby
# frozen_string_literal: true

require "trucebearer/adjudicator"
require_relative "../../support/board"
require_relative "../../support/reasons_table"

RSpec.describe "TA.check: the reasons table" do
  def u(power, type, at) = Board.unit(power, type, at)

  let(:start) { TA::Map.classic.starting_position }

  # One position and one order for each of the 17 reasons (AC-7.1).
  let(:examples) do
    lon_bel = Board.position(u(:england, :army, "lon"), u(:england, :army, "bel"))
    convoys = Board.position(u(:england, :army, "lon"), u(:england, :fleet, "nth"), u(:england, :fleet, "eng"))
    {
      wrong_phase: [TA::Position.from_h(start.to_h.merge("phase" => "retreat")), O::Hold.new(power: :england, at: :lon)],
      no_such_unit: [start, O::Hold.new(power: :england, at: :wal)],
      foreign_unit: [start, O::Hold.new(power: :france, at: :lon)],
      own_province: [start, O::Move.new(power: :england, at: :lon, destination: L.new(province: :lon))],
      not_reachable: [start, O::Move.new(power: :england, at: :lon, destination: L.new(province: :bel))],
      coast_not_allowed: [start, O::Move.new(power: :france, at: :mar, destination: L.new(province: :spa, coast: :nc))],
      coast_required: [Board.position(u(:france, :fleet, "por")), O::Move.new(power: :france, at: :por, destination: L.new(province: :spa))],
      coast_unreachable: [Board.position(u(:france, :fleet, "gol")),
                          O::Move.new(power: :france, at: :gol, destination: L.new(province: :spa, coast: :nc))],
      not_army: [Board.position(u(:england, :fleet, "lon")), O::MoveViaConvoy.new(power: :england, at: :lon, to: :wal)],
      not_adjacent: [Board.position(u(:england, :army, "lon")), O::MoveViaConvoy.new(power: :england, at: :lon, to: :bel)],
      no_convoy_route: [start, O::MoveViaConvoy.new(power: :england, at: :lvp, to: :wal)],
      same_province: [lon_bel, O::SupportMove.new(power: :england, at: :lon, from: :bel, to: :bel)],
      no_unit: [start, O::SupportHold.new(power: :germany, at: :mun, target: :sil)],
      move_impossible: [lon_bel, O::SupportMove.new(power: :england, at: :lon, from: :bel, to: :yor)],
      not_fleet_at_sea: [start, O::Convoy.new(power: :england, at: :lon, from: :lvp, to: :bel)],
      bad_endpoints: [convoys, O::Convoy.new(power: :england, at: :nth, from: :lon, to: :lon)],
      not_on_chain: [convoys, O::Convoy.new(power: :england, at: :eng, from: :lon, to: :nwy)]
    }
  end

  it "has the 17 reasons of the document's table, and the code accepts exactly those (AC-7.1)" do
    expect(ReasonsTable.all.size).to eq(17)
    expect(ReasonsTable.all).to match_array(TA::CheckResult::REASONS)
  end

  it "returns each of the 17 reasons for its own example (AC-7.1)" do
    expect(examples.keys).to match_array(ReasonsTable.all)
    examples.each do |reason, (position, order)|
      expect(Board.verdict(position, order)).to eq([reason]), "expected #{reason}"
    end
  end

  it "reads the rows of the document in the order the code follows (AC-7.3)" do
    expect(ReasonsTable.row("every order, checked first")).to eq(%i[wrong_phase no_such_unit foreign_unit])
    expect(ReasonsTable.row("Move")).to eq(%i[own_province not_reachable coast_not_allowed coast_required coast_unreachable])
    expect(ReasonsTable.row("MoveViaConvoy")).to eq(%i[not_army own_province not_adjacent no_convoy_route])
    expect(ReasonsTable.row("SupportHold")).to eq(%i[own_province no_unit not_reachable])
    expect(ReasonsTable.row("SupportMove")).to eq(%i[own_province same_province no_unit not_reachable move_impossible])
    expect(ReasonsTable.row("Convoy")).to eq(%i[not_fleet_at_sea bad_endpoints no_unit not_on_chain])
  end

  describe "the sweep (AC-7.2)" do
    let(:at_sea) do
      Board.position(u(:france, :fleet, "mao"), u(:france, :fleet, "gol"), u(:england, :fleet, "nth"),
                     u(:england, :army, "lon"), u(:russia, :fleet, "stp/sc"), u(:france, :fleet, "spa/nc"),
                     u(:turkey, :fleet, "bul/ec"), u(:italy, :army, "tus"), u(:germany, :fleet, "kie"))
    end

    def all_orders(power, at, provinces)
      locations = Board.locations
      orders = [O::Hold.new(power: power, at: at)]
      orders += locations.map { |location| O::Move.new(power: power, at: at, destination: location) }
      orders += provinces.flat_map do |to|
        [O::MoveViaConvoy.new(power: power, at: at, to: to), O::SupportHold.new(power: power, at: at, target: to)]
      end
      orders + provinces.product(provinces).flat_map do |from, to|
        [O::SupportMove.new(power: power, at: at, from: from, to: to), O::Convoy.new(power: power, at: at, from: from, to: to)]
      end
    end

    it "never raises, and every result agrees with itself, for every order of every unit" do
      provinces = Board.provinces
      [start, at_sea].each do |position|
        position.units.each do |unit|
          [unit.power, :turkey == unit.power ? :austria : :turkey].each do |power|
            all_orders(power, unit.location.province, provinces).each do |order|
              result = TA.check(position, order)
              expect(result).to be_a(TA::CheckResult)
              expect(result.reasons.size).to eq(result.legal ? 0 : 1)
            end
          end
        end
      end
    end
  end
end
```

Note for the executor: the sweep runs about half a million checks; the prototype of the same loop took about one second per 250 000. If it exceeds 10 seconds, narrow `provinces` for the foreign power only, and record that in the pull request. The `expect` inside the innermost loop is kept cheap by testing two plain facts.

- [ ] **Step 2: run.** `bundle exec rspec spec/trucebearer/adjudicator/check_reasons_spec.rb` — expect: all PASS. These guard specs describe behavior Phases 3 and 4 already built, so they pass at once. To prove the first two can fail, run the **mutation check**: temporarily change `CheckResult::REASONS` by deleting `not_on_chain` from `lib/trucebearer/adjudicator/check_result.rb` and run the spec — expect FAIL (`match_array` and the construction of the `not_on_chain` example). Restore the line with `git checkout lib/trucebearer/adjudicator/check_result.rb` and rerun — expect PASS.
- [ ] **Step 3: commit.** `git add -A adjudicator`, then `git commit -m "Pin every rejection reason to the table and sweep every order"` (with the trailer).

---

## Phase 6: The DATC fixtures

**Implements:** Story 8 (the fixtures, loader and runner) | **Satisfies:** AC-8.1 to AC-8.6
**Files:** `spec/support/datc.rb`, `spec/datc/datc_loader_spec.rb`, `spec/datc/datc_check_spec.rb`, `spec/datc/*.yml` (30 files)
**Interfaces:** Consumes: `TA::Order.from_h`, `TA::Unit.from_h`, `TA::Position.new`, `TA::CheckResult.new`, `CheckResult::REASONS`, `TA.check`. Produces: `Datc.load_all -> Array<Datc::Case>`, `Datc.load_file(path)`, `Datc.parse(data, name) -> Datc::Case` (raises `Datc::FormatError` naming the file), `Datc::Case(id, departure, position, entries)`, `Datc::Entry(order, expected)` where `expected` is a `TA::CheckResult` or `nil` (no check), and `Datc.files`.

- [ ] **Step 1: write the loader spec first.** Create `spec/datc/datc_loader_spec.rb`:

```ruby
# frozen_string_literal: true

require "trucebearer/adjudicator"
require_relative "../support/datc"

# The loader of the DATC fixtures (AC-8.5, AC-8.6). The fixtures themselves are run in
# datc_check_spec.rb.
RSpec.describe Datc do
  let(:good) do
    { "case" => "6.X.1", "summary" => "a test case",
      "position" => { "units" => [{ "power" => "england", "type" => "fleet", "at" => "lon" }] },
      "orders" => [{ "order" => { "type" => "hold", "power" => "england", "at" => "lon" }, "check" => { "legal" => true } }] }
  end

  def parse(data, name = "6.X.1") = described_class.parse(data, name)

  it "builds the position and the orders of a case, expanding short locations" do
    data = good.merge("position" => { "units" => [{ "power" => "france", "type" => "fleet", "at" => "spa/nc" }] },
                      "orders" => [{ "order" => { "type" => "move", "power" => "france", "at" => "spa", "destination" => "gol" },
                                     "check" => { "legal" => false, "reason" => "not_reachable" } }])
    kase = parse(data)
    expect(kase.id).to eq("6.X.1")
    expect(kase.position.units.first.location).to eq(L.new(province: :spa, coast: :nc))
    expect(kase.position.phase).to eq(:movement)
    expect(kase.entries.first.order).to eq(O::Move.new(power: :france, at: :spa, destination: L.new(province: :gol)))
    expect(kase.entries.first.expected).to eq(TA::CheckResult.new(legal: false, reasons: [:not_reachable]))
  end

  it "takes an optional phase and an optional departure mark" do
    kase = parse(good.merge("departure" => true, "position" => { "phase" => "retreat", "units" => [] }))
    expect(kase.position.phase).to eq(:retreat)
    expect(kase.departure).to be(true)
  end

  it "ignores the keys reserved for #14, and an order with no check (AC-8.5)" do
    data = good.merge("after" => { "units" => [] })
    data["orders"] = [
      { "order" => { "type" => "hold", "power" => "england", "at" => "lon" }, "check" => { "legal" => true }, "result" => "held" },
      { "order" => { "type" => "hold", "power" => "england", "at" => "lon" }, "result" => "held" }
    ]
    kase = parse(data)
    expect(kase.entries.map(&:expected)).to eq([TA::CheckResult.new(legal: true, reasons: []), nil])
  end

  it "refuses a malformed fixture, naming the file (AC-8.6)" do
    bad = {
      "an unknown top-level key" => good.merge("surprise" => 1),
      "an unknown order-entry key" => good.merge("orders" => [{ "order" => good["orders"][0]["order"], "oops" => 1 }]),
      "an unknown check key" => good.merge("orders" => [{ "order" => good["orders"][0]["order"], "check" => { "legal" => true, "why" => "x" } }]),
      "an unknown unit key" => good.merge("position" => { "units" => [{ "power" => "england", "type" => "fleet", "at" => "lon", "x" => 1 }] }),
      "an unknown reason" => good.merge("orders" => [{ "order" => good["orders"][0]["order"], "check" => { "legal" => false, "reason" => "bogus" } }]),
      "a reason on a legal check" => good.merge("orders" => [{ "order" => good["orders"][0]["order"], "check" => { "legal" => true, "reason" => "own_province" } }]),
      "an illegal check with no reason" => good.merge("orders" => [{ "order" => good["orders"][0]["order"], "check" => { "legal" => false } }]),
      "a missing summary" => good.reject { |key, _| key == "summary" },
      "a case id that doesn't match the file" => good.merge("case" => "6.X.2"),
      "an order that can't be built" => good.merge("orders" => [{ "order" => { "type" => "hold", "power" => "england" } }]),
      "a unit that can't be built" => good.merge("position" => { "units" => [{ "power" => "england", "type" => "fleet", "at" => "xyz" }] })
    }
    bad.each do |label, data|
      expect { parse(data) }.to raise_error(Datc::FormatError, /6\.X\.1/), "expected #{label} to be refused"
    end
  end

  it "reads a real file with no classes and no aliases" do
    Dir.mktmpdir do |dir|
      path = File.join(dir, "6.X.1.yml")
      File.write(path, "case: \"6.X.1\"\nsummary: x\nposition: &p\n  units: []\norders: []\nother: *p\n")
      expect { described_class.load_file(path) }.to raise_error(Psych::Exception)
    end
  end
end
```

Add `require "tmpdir"` under the first `require`.

- [ ] **Step 2: write the runner spec.** Create `spec/datc/datc_check_spec.rb`:

```ruby
# frozen_string_literal: true

require "trucebearer/adjudicator"
require_relative "../support/datc"

# Runs every DATC fixture through TA.check (AC-8.1), and keeps the set of fixtures
# exactly the one the spec lists (AC-8.2). #14 adds its cases to ENCODED.
RSpec.describe "DATC fixtures: checking" do
  # The cases encoded for checking: 6.A and 6.B, except the four left out, and three
  # from 6.D and 6.G that interface.md cites. See spec 011, "Cases encoded".
  ENCODED = (
    (1..10).map { |n| "6.A.#{n}" } +
    [1, 2, 3, 4, 5, 6, 7, 8, 10, 11, 12, 13, 15, 16, 17, 18, 19].map { |n| "6.B.#{n}" } +
    %w[6.D.31 6.D.34 6.G.19]
  ).sort.freeze
  LEFT_OUT = %w[6.A.11 6.A.12 6.B.9 6.B.14].freeze

  it "has one fixture for each encoded case and no other (AC-8.2)" do
    names = Datc.files.map { |path| File.basename(path, ".yml") }
    expect(ENCODED.size).to eq(30)
    expect(names).to eq(ENCODED)
    expect(names & LEFT_OUT).to eq([])
  end

  it "marks only 6.B.2 and 6.B.12 as departures (AC-8.4)" do
    expect(Datc.load_all.select(&:departure).map(&:id)).to eq(%w[6.B.12 6.B.2])
  end

  Datc.load_all.each do |kase|
    describe kase.id do
      kase.entries.each_with_index do |entry, index|
        next unless entry.expected

        it "checks order #{index + 1} (#{entry.order.class.name.split("::").last} at #{entry.order.at})" do
          expect(TA.check(kase.position, entry.order)).to eq(entry.expected)
        end
      end
    end
  end

  it "gives every order of every encoded file a check (the rule for files on disk)" do
    Datc.load_all.each do |kase|
      expect(kase.entries.map(&:expected)).to all(be_a(TA::CheckResult)), "#{kase.id} has an order with no check"
    end
  end
end
```

- [ ] **Step 3: run both and confirm the failures.** `bundle exec rspec spec/datc` — expect: FAIL with `cannot load such file -- ../support/datc`.
- [ ] **Step 4: write the loader.** Create `spec/support/datc.rb`:

```ruby
# frozen_string_literal: true

require "yaml"
require "trucebearer/adjudicator"
require_relative "board"

# Reads the hand-written DATC fixtures in spec/datc/ (one YAML file per case, named by
# its DATC section number). A fixture holds exactly the units and orders of its case.
#
# Short notation, expanded here: a location is "spa/nc" or "par"; an order is the hash
# form of docs/interface.md without "format", which is added; `destination` is a location.
# `check:` is {legal: true} or {legal: false, reason: <symbol text>}. `result:` and `after:`
# are reserved for the adjudication specs (#14) and ignored here.
module Datc
  class FormatError < StandardError; end

  Case = Data.define(:id, :departure, :position, :entries)
  Entry = Data.define(:order, :expected)

  DIR = File.expand_path("../datc", __dir__)
  TOP_KEYS = %w[case summary departure position orders after].freeze
  TOP_REQUIRED = %w[case summary position orders].freeze
  POSITION_KEYS = %w[units phase].freeze
  UNIT_KEYS = %w[power type at].freeze
  ENTRY_KEYS = %w[order check result].freeze
  CHECK_KEYS = %w[legal reason].freeze
  PHASES = %w[movement retreat adjustment].freeze

  module_function

  def files = Dir[File.join(DIR, "*.yml")].sort

  def load_all = files.map { |path| load_file(path) }

  def load_file(path)
    parse(YAML.safe_load_file(path, permitted_classes: [], aliases: false), File.basename(path, ".yml"))
  end

  def parse(data, name)
    fail!(name, "expected a mapping, got #{data.inspect}") unless data.is_a?(Hash)
    keys!(data, TOP_KEYS, TOP_REQUIRED, name, "the top level")
    fail!(name, "\"case\" is #{data["case"].inspect}, which doesn't match the file name") unless data["case"] == name
    Case.new(id: name, departure: data["departure"] == true,
             position: build_position(data["position"], name),
             entries: Array(data["orders"]).map { |entry| build_entry(entry, name) })
  end

  def build_position(data, name)
    fail!(name, "\"position\" must be a mapping") unless data.is_a?(Hash)
    keys!(data, POSITION_KEYS, %w[units], name, "\"position\"")
    phase = data.fetch("phase", "movement")
    fail!(name, "unknown phase #{phase.inspect}") unless PHASES.include?(phase)
    units = Array(data["units"]).map { |unit| build_unit(unit, name) }
    Board.position(*units, phase: phase.to_sym)
  rescue TA::InvalidInput => e
    fail!(name, "bad position: #{e.message}")
  end

  def build_unit(unit, name)
    fail!(name, "a unit must be a mapping, got #{unit.inspect}") unless unit.is_a?(Hash)
    keys!(unit, UNIT_KEYS, UNIT_KEYS, name, "a unit")
    TA::Unit.from_h("power" => unit["power"], "type" => unit["type"], "location" => location_hash(unit["at"]))
  rescue TA::InvalidInput => e
    fail!(name, "bad unit #{unit.inspect}: #{e.message}")
  end

  def build_entry(entry, name)
    fail!(name, "an order entry must be a mapping, got #{entry.inspect}") unless entry.is_a?(Hash)
    keys!(entry, ENTRY_KEYS, %w[order], name, "an order entry")
    Entry.new(order: build_order(entry["order"], name), expected: build_check(entry["check"], name))
  end

  def build_order(hash, name)
    fail!(name, "an order must be a mapping, got #{hash.inspect}") unless hash.is_a?(Hash)
    fields = hash.dup
    fields["destination"] = location_hash(fields["destination"]) if fields.key?("destination")
    TA::Order.from_h({ "format" => TA.const_get(:Shape)::FORMAT }.merge(fields))
  rescue TA::InvalidInput => e
    fail!(name, "bad order #{hash.inspect}: #{e.message}")
  end

  def build_check(check, name)
    return nil if check.nil?

    fail!(name, "\"check\" must be a mapping, got #{check.inspect}") unless check.is_a?(Hash)
    keys!(check, CHECK_KEYS, %w[legal], name, "\"check\"")
    legal = check["legal"]
    fail!(name, "\"legal\" must be true or false, got #{legal.inspect}") unless [true, false].include?(legal)
    if legal
      fail!(name, "a legal check has no \"reason\"") if check.key?("reason")
      return TA::CheckResult.new(legal: true, reasons: [])
    end
    reason = TA::CheckResult::REASONS.find { |candidate| candidate.to_s == check["reason"] }
    fail!(name, "unknown reason #{check["reason"].inspect}") unless reason
    TA::CheckResult.new(legal: false, reasons: [reason])
  end

  def location_hash(text)
    province, coast = text.to_s.split("/")
    { "province" => province, "coast" => coast }
  end

  def keys!(hash, allowed, required, name, where)
    (hash.keys - allowed).each { |key| fail!(name, "unknown key #{key.inspect} in #{where}") }
    (required - hash.keys).each { |key| fail!(name, "missing key #{key.inspect} in #{where}") }
  end

  def fail!(name, message)
    raise FormatError, "#{name}: #{message}"
  end
end
```

- [ ] **Step 5: run the loader spec.** `bundle exec rspec spec/datc/datc_loader_spec.rb` — expect: PASS (the runner spec still fails to load fixtures: there are none yet, so `names` is empty and the AC-8.2 example fails until Step 6).
- [ ] **Step 6: write the 30 fixtures.** Each file below is created in `spec/datc/` under the name in its heading. Every `summary` is our own wording; nothing is copied from the DATC.

`6.A.1.yml`
```yaml
case: "6.A.1"
summary: A fleet may not move to a province that does not touch its own
position:
  units:
    - {power: england, type: fleet, at: nth}
orders:
  - order: {type: move, power: england, at: nth, destination: pic}
    check: {legal: false, reason: not_reachable}
```
`6.A.2.yml`
```yaml
case: "6.A.2"
summary: An army may not move into the open sea
position:
  units:
    - {power: england, type: army, at: lvp}
orders:
  - order: {type: move, power: england, at: lvp, destination: iri}
    check: {legal: false, reason: not_reachable}
```
`6.A.3.yml`
```yaml
case: "6.A.3"
summary: A fleet may not move to an inland province
position:
  units:
    - {power: germany, type: fleet, at: kie}
orders:
  - order: {type: move, power: germany, at: kie, destination: mun}
    check: {legal: false, reason: not_reachable}
```
`6.A.4.yml`
```yaml
case: "6.A.4"
summary: A move to the unit's own province is not an order
position:
  units:
    - {power: germany, type: fleet, at: kie}
orders:
  - order: {type: move, power: germany, at: kie, destination: kie}
    check: {legal: false, reason: own_province}
```
`6.A.5.yml`
```yaml
case: "6.A.5"
summary: A move to the unit's own province is still not an order when a convoy and a support point at it
position:
  units:
    - {power: england, type: fleet, at: nth}
    - {power: england, type: army, at: yor}
    - {power: england, type: army, at: lvp}
    - {power: germany, type: fleet, at: lon}
    - {power: germany, type: army, at: wal}
orders:
  - order: {type: convoy, power: england, at: nth, from: yor, to: yor}
    check: {legal: false, reason: bad_endpoints}
  - order: {type: move, power: england, at: yor, destination: yor}
    check: {legal: false, reason: own_province}
  - order: {type: support_move, power: england, at: lvp, from: yor, to: yor}
    check: {legal: false, reason: same_province}
  - order: {type: move, power: germany, at: lon, destination: yor}
    check: {legal: true}
  - order: {type: support_move, power: germany, at: wal, from: lon, to: yor}
    check: {legal: true}
```
`6.A.6.yml`
```yaml
case: "6.A.6"
summary: A power may not give an order to another power's unit
position:
  units:
    - {power: england, type: fleet, at: lon}
orders:
  - order: {type: move, power: germany, at: lon, destination: nth}
    check: {legal: false, reason: foreign_unit}
```
`6.A.7.yml`
```yaml
case: "6.A.7"
summary: A fleet can't be convoyed, so neither its move nor a convoy for it is legal
position:
  units:
    - {power: england, type: fleet, at: lon}
    - {power: england, type: fleet, at: nth}
orders:
  - order: {type: move, power: england, at: lon, destination: bel}
    check: {legal: false, reason: not_reachable}
  - order: {type: convoy, power: england, at: nth, from: lon, to: bel}
    check: {legal: false, reason: no_unit}
```
`6.A.8.yml`
```yaml
case: "6.A.8"
summary: A unit may not support itself to hold
position:
  units:
    - {power: italy, type: army, at: ven}
    - {power: italy, type: army, at: tyr}
    - {power: austria, type: fleet, at: tri}
orders:
  - order: {type: move, power: italy, at: ven, destination: tri}
    check: {legal: true}
  - order: {type: support_move, power: italy, at: tyr, from: ven, to: tri}
    check: {legal: true}
  - order: {type: support_hold, power: austria, at: tri, target: tri}
    check: {legal: false, reason: own_province}
```
`6.A.9.yml`
```yaml
case: "6.A.9"
summary: Provinces that touch for an army may not touch for a fleet
position:
  units:
    - {power: italy, type: fleet, at: rom}
orders:
  - order: {type: move, power: italy, at: rom, destination: ven}
    check: {legal: false, reason: not_reachable}
```
`6.A.10.yml`
```yaml
case: "6.A.10"
summary: A support is illegal when the supporter can't reach the province the move goes to
position:
  units:
    - {power: austria, type: army, at: ven}
    - {power: italy, type: fleet, at: rom}
    - {power: italy, type: army, at: apu}
orders:
  - order: {type: hold, power: austria, at: ven}
    check: {legal: true}
  - order: {type: support_move, power: italy, at: rom, from: apu, to: ven}
    check: {legal: false, reason: not_reachable}
  - order: {type: move, power: italy, at: apu, destination: ven}
    check: {legal: true}
```
`6.B.1.yml`
```yaml
case: "6.B.1"
summary: A fleet that can reach both coasts must name one
position:
  units:
    - {power: france, type: fleet, at: por}
orders:
  - order: {type: move, power: france, at: por, destination: spa}
    check: {legal: false, reason: coast_required}
```
`6.B.2.yml`
```yaml
case: "6.B.2"
summary: A fleet that can reach only one coast must still name it
departure: true
position:
  units:
    - {power: france, type: fleet, at: gas}
orders:
  - order: {type: move, power: france, at: gas, destination: spa}
    check: {legal: false, reason: coast_required}
```
`6.B.3.yml`
```yaml
case: "6.B.3"
summary: A fleet naming a coast it can't reach is refused, not corrected
position:
  units:
    - {power: france, type: fleet, at: gas}
orders:
  - order: {type: move, power: france, at: gas, destination: "spa/sc"}
    check: {legal: false, reason: coast_unreachable}
```
`6.B.4.yml`
```yaml
case: "6.B.4"
summary: A fleet may support a move to a coast it can't reach itself
position:
  units:
    - {power: france, type: fleet, at: gas}
    - {power: france, type: fleet, at: mar}
    - {power: italy, type: fleet, at: wes}
orders:
  - order: {type: move, power: france, at: gas, destination: "spa/nc"}
    check: {legal: true}
  - order: {type: support_move, power: france, at: mar, from: gas, to: spa}
    check: {legal: true}
  - order: {type: move, power: italy, at: wes, destination: "spa/sc"}
    check: {legal: true}
```
`6.B.5.yml`
```yaml
case: "6.B.5"
summary: A fleet on one coast may not support a move to a province only the other coast touches
position:
  units:
    - {power: france, type: fleet, at: mar}
    - {power: france, type: fleet, at: "spa/nc"}
    - {power: italy, type: fleet, at: gol}
orders:
  - order: {type: move, power: france, at: mar, destination: gol}
    check: {legal: true}
  - order: {type: support_move, power: france, at: spa, from: mar, to: gol}
    check: {legal: false, reason: not_reachable}
  - order: {type: hold, power: italy, at: gol}
    check: {legal: true}
```
`6.B.6.yml`
```yaml
case: "6.B.6"
summary: Orders around Spain, where the other coast cuts a support, are all legal
position:
  units:
    - {power: england, type: fleet, at: iri}
    - {power: england, type: fleet, at: nao}
    - {power: france, type: fleet, at: "spa/nc"}
    - {power: france, type: fleet, at: mao}
    - {power: italy, type: fleet, at: gol}
orders:
  - order: {type: support_move, power: england, at: iri, from: nao, to: mao}
    check: {legal: true}
  - order: {type: move, power: england, at: nao, destination: mao}
    check: {legal: true}
  - order: {type: support_hold, power: france, at: spa, target: mao}
    check: {legal: true}
  - order: {type: hold, power: france, at: mao}
    check: {legal: true}
  - order: {type: move, power: italy, at: gol, destination: "spa/sc"}
    check: {legal: true}
```
`6.B.7.yml`
```yaml
case: "6.B.7"
summary: A support names no coast, so supporting a move to either coast of Spain is legal
position:
  units:
    - {power: france, type: fleet, at: por}
    - {power: france, type: fleet, at: mao}
    - {power: italy, type: fleet, at: gol}
    - {power: italy, type: fleet, at: wes}
orders:
  - order: {type: support_move, power: france, at: por, from: mao, to: spa}
    check: {legal: true}
  - order: {type: move, power: france, at: mao, destination: "spa/nc"}
    check: {legal: true}
  - order: {type: support_move, power: italy, at: gol, from: wes, to: spa}
    check: {legal: true}
  - order: {type: move, power: italy, at: wes, destination: "spa/sc"}
    check: {legal: true}
```
`6.B.8.yml`
```yaml
case: "6.B.8"
summary: A support names no coast, and the supported fleet can reach only one coast
position:
  units:
    - {power: france, type: fleet, at: por}
    - {power: france, type: fleet, at: gas}
    - {power: italy, type: fleet, at: gol}
    - {power: italy, type: fleet, at: wes}
orders:
  - order: {type: support_move, power: france, at: por, from: gas, to: spa}
    check: {legal: true}
  - order: {type: move, power: france, at: gas, destination: "spa/nc"}
    check: {legal: true}
  - order: {type: support_move, power: italy, at: gol, from: wes, to: spa}
    check: {legal: true}
  - order: {type: move, power: italy, at: wes, destination: "spa/sc"}
    check: {legal: true}
```
`6.B.10.yml`
```yaml
case: "6.B.10"
summary: A fleet on the south coast of Spain may move to the Gulf of Lyon (written without the unit's coast)
position:
  units:
    - {power: france, type: fleet, at: "spa/sc"}
orders:
  - order: {type: move, power: france, at: spa, destination: gol}
    check: {legal: true}
```
`6.B.11.yml`
```yaml
case: "6.B.11"
summary: A fleet on the north coast of Spain can't move to the Gulf of Lyon (written without the unit's coast)
position:
  units:
    - {power: france, type: fleet, at: "spa/nc"}
orders:
  - order: {type: move, power: france, at: spa, destination: gol}
    check: {legal: false, reason: not_reachable}
```
`6.B.12.yml`
```yaml
case: "6.B.12"
summary: An army's move may not name a coast
departure: true
position:
  units:
    - {power: france, type: army, at: gas}
orders:
  - order: {type: move, power: france, at: gas, destination: "spa/nc"}
    check: {legal: false, reason: coast_not_allowed}
```
`6.B.13.yml`
```yaml
case: "6.B.13"
summary: Two fleets each move across the two coasts of Bulgaria and Constantinople, both moves legal
position:
  units:
    - {power: turkey, type: fleet, at: "bul/sc"}
    - {power: turkey, type: fleet, at: con}
orders:
  - order: {type: move, power: turkey, at: bul, destination: con}
    check: {legal: true}
  - order: {type: move, power: turkey, at: con, destination: "bul/ec"}
    check: {legal: true}
```
`6.B.15.yml`
```yaml
case: "6.B.15"
summary: One power may support a move another power makes to a coast, with no coast named
position:
  units:
    - {power: france, type: fleet, at: por}
    - {power: england, type: fleet, at: mao}
    - {power: italy, type: fleet, at: gol}
    - {power: italy, type: fleet, at: wes}
orders:
  - order: {type: support_move, power: france, at: por, from: mao, to: spa}
    check: {legal: true}
  - order: {type: move, power: england, at: mao, destination: "spa/nc"}
    check: {legal: true}
  - order: {type: support_move, power: italy, at: gol, from: wes, to: spa}
    check: {legal: true}
  - order: {type: move, power: italy, at: wes, destination: "spa/sc"}
    check: {legal: true}
```
`6.B.16.yml`
```yaml
case: "6.B.16"
summary: A support to hold a fleet that stands on a coast names the province only
position:
  units:
    - {power: france, type: army, at: gas}
    - {power: france, type: army, at: mar}
    - {power: italy, type: fleet, at: "spa/sc"}
    - {power: england, type: fleet, at: por}
orders:
  - order: {type: move, power: france, at: gas, destination: spa}
    check: {legal: true}
  - order: {type: support_move, power: france, at: mar, from: gas, to: spa}
    check: {legal: true}
  - order: {type: hold, power: italy, at: spa}
    check: {legal: true}
  - order: {type: support_hold, power: england, at: por, target: spa}
    check: {legal: true}
```
`6.B.17.yml`
```yaml
case: "6.B.17"
summary: A support for a move out of a split-coast province names the province only
position:
  units:
    - {power: england, type: fleet, at: mao}
    - {power: france, type: fleet, at: "spa/sc"}
    - {power: italy, type: fleet, at: wes}
orders:
  - order: {type: hold, power: england, at: mao}
    check: {legal: true}
  - order: {type: move, power: france, at: spa, destination: mao}
    check: {legal: true}
  - order: {type: support_move, power: italy, at: wes, from: spa, to: mao}
    check: {legal: true}
```
`6.B.18.yml`
```yaml
case: "6.B.18"
summary: An army may be convoyed out of a split-coast province, and the convoy order is legal
position:
  units:
    - {power: turkey, type: army, at: bul}
    - {power: turkey, type: fleet, at: bla}
orders:
  - order: {type: move, power: turkey, at: bul, destination: sev}
    check: {legal: true}
  - order: {type: convoy, power: turkey, at: bla, from: bul, to: sev}
    check: {legal: true}
```
`6.B.19.yml`
```yaml
case: "6.B.19"
summary: An army may be convoyed into a split-coast province, and the convoy order is legal
position:
  units:
    - {power: italy, type: army, at: tus}
    - {power: italy, type: fleet, at: gol}
orders:
  - order: {type: move, power: italy, at: tus, destination: spa}
    check: {legal: true}
  - order: {type: convoy, power: italy, at: gol, from: tus, to: spa}
    check: {legal: true}
```
`6.D.31.yml`
```yaml
case: "6.D.31"
summary: A fleet may not support a move whose only convoy route is through that same fleet
position:
  units:
    - {power: austria, type: army, at: rum}
    - {power: turkey, type: fleet, at: bla}
orders:
  - order: {type: move, power: austria, at: rum, destination: arm}
    check: {legal: true}
  - order: {type: support_move, power: turkey, at: bla, from: rum, to: arm}
    check: {legal: false, reason: move_impossible}
```
`6.D.34.yml`
```yaml
case: "6.D.34"
summary: A support for a move into the supporter's own province is illegal
position:
  units:
    - {power: germany, type: army, at: ber}
    - {power: germany, type: army, at: sil}
    - {power: germany, type: fleet, at: bal}
    - {power: italy, type: army, at: pru}
orders:
  - order: {type: move, power: germany, at: ber, destination: pru}
    check: {legal: true}
  - order: {type: support_move, power: germany, at: sil, from: ber, to: pru}
    check: {legal: true}
  - order: {type: support_move, power: germany, at: bal, from: ber, to: pru}
    check: {legal: true}
  - order: {type: support_move, power: italy, at: pru, from: lvn, to: pru}
    check: {legal: false, reason: own_province}
```
`6.G.19.yml`
```yaml
case: "6.G.19"
summary: A convoy order from a fleet that no minimal chain needs is illegal
position:
  units:
    - {power: france, type: army, at: mar}
    - {power: france, type: fleet, at: wes}
    - {power: italy, type: fleet, at: gol}
    - {power: italy, type: army, at: spa}
orders:
  - order: {type: move, power: france, at: mar, destination: spa}
    check: {legal: true}
  - order: {type: convoy, power: france, at: wes, from: mar, to: spa}
    check: {legal: false, reason: not_on_chain}
  - order: {type: convoy, power: italy, at: gol, from: mar, to: spa}
    check: {legal: true}
  - order: {type: move, power: italy, at: spa, destination: mar}
    check: {legal: true}
```

- [ ] **Step 7: run and confirm.** `bundle exec rspec spec/datc` — expect: all PASS (30 fixtures, about 90 order checks, the loader examples). If a fixture's result differs from what the contract gives, stop and work out whether the fixture or the code is wrong against `docs/interface.md` and the DATC section; if the contract itself is at fault, `ask`. Then `bundle exec rspec` — expect: no failures.
- [ ] **Step 8: mutation check.** Temporarily change one expectation, for example `6.B.3.yml`'s `reason: coast_unreachable` to `reason: coast_required`, run `bundle exec rspec spec/datc/datc_check_spec.rb` — expect FAIL naming `6.B.3`. Restore it with `git checkout spec/datc/6.B.3.yml` (it is not committed yet: instead retype the line) and rerun — expect PASS.
- [ ] **Step 9: commit.** `git add -A adjudicator`, then `git commit -m "Add the DATC fixtures for checking and their runner"` (with the trailer).

---

## Phase 7: The examples, the record, and the integration check

**Implements:** FR-4, Story 9 | **Satisfies:** AC-9.1 to AC-9.6, AC-8.3
**Files:** `spec/trucebearer/adjudicator/check_examples_spec.rb`, `spec/trucebearer/adjudicator/interface_examples_spec.rb`, `CHANGELOG.md`, `docs/ruleset.md`
**Interfaces:** Consumes: everything above. Produces: nothing new.

- [ ] **Step 1: write the examples spec.** Create `spec/trucebearer/adjudicator/check_examples_spec.rb`, each example built as `docs/interface.md` builds it:

```ruby
# frozen_string_literal: true

require "json"
require "trucebearer/adjudicator"
require_relative "../../support/board"

# Every Ruby example in docs/interface.md under "### TA::CheckResult" and under
# "## Checking an order", and the three CheckResult lines at the end of "Impossible
# objects", run as a spec (AC-9.1).
RSpec.describe "docs/interface.md examples: checking" do
  def result(legal, reasons) = TA::CheckResult.new(legal: legal, reasons: reasons)

  describe "### TA::CheckResult" do
    it "gives the hash forms the document shows" do
      expect(TA::CheckResult.new(legal: false, reasons: [:foreign_unit]).to_h)
        .to eq("format" => 1, "legal" => false, "reasons" => ["foreign_unit"])
      expect(TA::CheckResult.new(legal: true, reasons: []).to_h).to eq("format" => 1, "legal" => true, "reasons" => [])
    end
  end

  describe "### Impossible objects: a check result whose legal flag and reasons disagree" do
    it "raises InvalidInput for each of the three lines" do
      expect { TA::CheckResult.new(legal: true, reasons: [:own_province]) }.to raise_error(TA::InvalidInput)
      expect { TA::CheckResult.new(legal: false, reasons: []) }.to raise_error(TA::InvalidInput)
      expect { TA::CheckResult.new(legal: false, reasons: [:own_province, :not_reachable]) }.to raise_error(TA::InvalidInput)
    end
  end

  describe "## Checking an order" do
    let(:start) { TA::Map.classic.starting_position }
    let(:at_sea) do
      TA::Position.new(map: "classic", season: :spring, year: 1901, phase: :movement, ownership: {},
                       dislodged_units: [], standoffs: [],
                       units: [TA::Unit.new(power: :france, type: :fleet, location: L.new(province: :mao)),
                               TA::Unit.new(power: :france, type: :fleet, location: L.new(province: :gol))])
    end

    it "gives every result the document shows" do
      expect(TA.check(start, O::Hold.new(power: :england, at: :lon))).to eq(result(true, []))
      expect(TA.check(start, O::Hold.new(power: :france, at: :lon))).to eq(result(false, [:foreign_unit]))
      expect(TA.check(start, O::Move.new(power: :england, at: :lon, destination: L.new(province: :bel))))
        .to eq(result(false, [:not_reachable]))
      expect(TA.check(start, O::Move.new(power: :russia, at: :sev, destination: L.new(province: :rum))))
        .to eq(result(true, []))
      expect(TA.check(start, O::Move.new(power: :france, at: :mar, destination: L.new(province: :spa, coast: :nc))))
        .to eq(result(false, [:coast_not_allowed]))
      expect(TA.check(start, O::MoveViaConvoy.new(power: :england, at: :lvp, to: :wal)))
        .to eq(result(false, [:no_convoy_route]))
      expect(TA.check(start, O::SupportMove.new(power: :austria, at: :vie, from: :war, to: :gal)))
        .to eq(result(true, []))
      expect(TA.check(at_sea, O::Move.new(power: :france, at: :mao, destination: L.new(province: :spa))))
        .to eq(result(false, [:coast_required]))
      expect(TA.check(at_sea, O::Move.new(power: :france, at: :gol, destination: L.new(province: :spa, coast: :nc))))
        .to eq(result(false, [:coast_unreachable]))
      retreat = TA::Position.from_h(start.to_h.merge("phase" => "retreat"))
      expect(TA.check(retreat, O::Hold.new(power: :england, at: :lon))).to eq(result(false, [:wrong_phase]))
      expect(TA.check(start, O::Hold.new(power: :england, at: :wal))).to eq(result(false, [:no_such_unit]))
      expect(TA.check(start, O::SupportHold.new(power: :germany, at: :mun, target: :ber))).to eq(result(true, []))
      expect(TA.check(start, O::SupportHold.new(power: :germany, at: :mun, target: :sil))).to eq(result(false, [:no_unit]))
      expect(TA.check(start, O::Convoy.new(power: :england, at: :lon, from: :lvp, to: :bel)))
        .to eq(result(false, [:not_fleet_at_sea]))
    end

    it "gives results with the inspect form the document shows" do
      expect(TA.check(start, O::Hold.new(power: :england, at: :lon)).inspect)
        .to eq("#<data Trucebearer::Adjudicator::CheckResult legal=true, reasons=[]>")
      expect(TA.check(start, O::Hold.new(power: :france, at: :lon)).inspect)
        .to eq("#<data Trucebearer::Adjudicator::CheckResult legal=false, reasons=[:foreign_unit]>")
    end

    it "round-trips the result through JSON" do
      checked = TA.check(start, O::Hold.new(power: :france, at: :lon))
      expect(TA::CheckResult.from_h(JSON.parse(JSON.generate(checked.to_h)))).to eq(checked)
    end
  end
end
```

- [ ] **Step 2: run it.** `bundle exec rspec spec/trucebearer/adjudicator/check_examples_spec.rb` — expect: PASS (it describes behavior already built; the inspect strings are the ones the document prints, so a wrong one fails here). If the `inspect` example fails because Ruby prints the class differently, stop and `ask`, because the document's `# =>` lines are the contract.
- [ ] **Step 3: update the header comment of `interface_examples_spec.rb`.** Replace the block that lists the exclusions (the lines starting `# Excluded, because they belong to later issues (AC-7.3):` through the line ending `calls in their own sections.`) with:

```ruby
# Excluded, because they belong to later issues (AC-7.3):
#   - the TA::Outcome and TA::Adjudication examples (#14);
#   - the TA.legal_orders and TA.adjudicate calls in their own sections.
# The TA::CheckResult examples, the three CheckResult lines at the end of "Impossible
# objects" and the TA.check examples run in check_examples_spec.rb (#11).
```

- [ ] **Step 4: edit `CHANGELOG.md`.** Under "Unreleased" → "Added", append:

```markdown
- `TA::CheckResult` and `TA.check(position, order)`: checking one movement order against a position, with the 17 rejection reasons and the precedence of `docs/interface.md`. A legal order has no reasons; an illegal one has exactly one. The DATC cases about legality (6.A, 6.B, and 6.D.31, 6.D.34, 6.G.19) are fixtures in `spec/datc/`, named by section number. The helpers `legal_orders` (#12) will share are internal. (#11)
```

and in the #10 entry replace the sentence `` `TA::CheckResult` arrives with #11, and `TA::Outcome` and `TA::Adjudication` with #14. (#10)`` with `` `TA::Outcome` and `TA::Adjudication` arrive with #14. (#10)``.

- [ ] **Step 5: edit `docs/ruleset.md`.** Beside the 4.E.1 row of the "Choices" table, add two rows, in our own words:

```markdown
| 6.D.31 | May a unit support a move that could happen only through a convoy chain that needs the supporter's own fleet? | No. The support is rejected with `move_impossible`, judging the supported army's chain without the supporter's fleet | Our reading of 4.E.1: the order lists offer only orders that could matter. One fleet can't be both the sea route and the support |
| 6.G.19 | May a fleet that no minimal convoy chain needs give a convoy order? | No. It is rejected with `not_on_chain`; a chain counts only when no smaller set of fleets is also a chain | Our reading of 4.E.1, as above; it also keeps the question of who showed intent out of checking |
```

- [ ] **Step 6: run the whole proof.** From `adjudicator/`:
  - `bundle exec rspec` — expect: 0 failures (record the example count).
  - `bundle exec rake` — expect: exit 0.
  - `git diff --name-only main...HEAD` — expect: every path begins with `adjudicator/`, and `adjudicator/docs/interface.md` is not listed.
  - `grep -rn "Dip" lib spec docs/specs/011-check-order | grep -v "Dip\\?" | head` — expect: no output (no name echoing the game's name: also scan for the trademarked name in full).
- [ ] **Step 7: commit.** `git add -A adjudicator`, then `git commit -m "Run the interface examples for checking and record the check choices"` (with the trailer).

---

## Phase 8: Integration verification

**Implements:** All FRs | **Satisfies:** All ACs

- [ ] Run the full suite: `bundle exec rspec` and `bundle exec rake` — expect: 0 failures, exit 0.
- [ ] Walk the spec's acceptance criteria against the specs: Story 1 in `check_result_spec.rb`; Story 2 in `check_spec.rb`; Stories 3 and 4 in `check_move_spec.rb`; Story 5 in `check_support_spec.rb`; Story 6 in `check_convoy_spec.rb`; Story 7 in `check_reasons_spec.rb`; Story 8 in `spec/datc/`; Story 9 in `check_examples_spec.rb`, the changelog, `ruleset.md`, the file list and `reach_spec.rb` (AC-9.6). The criteria marked (review) (AC-8.3, AC-9.2 to AC-9.5) are checked by reading, and by the implementation review.
- [ ] If #77 (Marshal) has merged to `main`, merge `origin/main` and give `TA::CheckResult` the same handling it added to the other value objects, with a spec that mirrors #77's own. If it hasn't, leave it to the #77 worker and say so in the pull request.
- [ ] Dispatch the implementation review (read-only Opus), record its findings and how they were handled in the pull request description.
- [ ] Commit any review fixes: `git commit -m "Settle the implementation review of checking an order"`.

---

## Quickstart Validation

From `adjudicator/`, with the gem's own load path:

```
bundle exec ruby -Ilib -e '
require "trucebearer/adjudicator"
TA = Trucebearer::Adjudicator
start = TA::Map.classic.starting_position
p TA.check(start, TA::Order::Hold.new(power: :england, at: :lon))
p TA.check(start, TA::Order::Hold.new(power: :france, at: :lon))
p TA.check(start, TA::Order::Move.new(power: :france, at: :mar, destination: TA::Location.new(province: :spa, coast: :nc)))
'
```

Expected output, one line each: `#<data Trucebearer::Adjudicator::CheckResult legal=true, reasons=[]>`, then `legal=false, reasons=[:foreign_unit]`, then `legal=false, reasons=[:coast_not_allowed]`.

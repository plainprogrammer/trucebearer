# Implementation Plan: Adjudicate movement phases without convoys

**Spec:** adjudicator/docs/specs/014-adjudicate-movement/spec.md (v1.2.1, Approved at Gate A)
**Decisions:** none in `docs/adr/`. The recorded decisions are `docs/architecture.md` and the contract in `adjudicator/docs/interface.md`. The algorithm is the decision-based resolution of the spec's "How the conditions are resolved"; the Gate A rulings are in the spec's changelog.
**Created:** 2026-11-26

## Global Constraints

- **Read `spec.md` in full before starting any phase.** Where a phase cites an AC, the spec's wording is what the code must satisfy.
- Change files in `adjudicator/` only. The spec and this plan ship in the same pull request.
- **`docs/interface.md`** changes only in Phase 8, and only by the impossible-object examples of Phase 8, Step 3, in `### Impossible objects`. `origin/main` (0.1.0, #13) is already merged into the branch. If a phase shows the contract is wrong or contradicts itself, stop and `ask` the coordinator.
- Never give anything a name that contains or echoes the game's trademarked name or its three-letter prefix: files, classes, methods, specs, comments, fixtures, commit messages.
- No copied rules text and no DATC prose, in code, comments, specs, fixtures or docs. Fixture summaries are in our own words; every case is cited by number only.
- No new dependency: standard library only (`set` is in it).
- **Test first.** Each phase writes its specs, runs them, and sees them fail for the right reason before it writes the code. Phase 1 commits the first spec alone, red, as the first code commit.
- Run every command from `adjudicator/`. Spec files begin with `require "trucebearer/adjudicator"` and a `require_relative` of the support file they use. `.rspec` already loads `spec_helper`. Code files begin with `# frozen_string_literal: true`.
- `TA`, `L` and `O` stand for `Trucebearer::Adjudicator`, `TA::Location` and `TA::Order`, as in `interface.md` (`spec/support/board.rb` defines them for the specs).
- `Check` and `Reach` are **not edited**. The resolver uses `Check.reason_for` (to void orders), `Check::ORDERS` and `Reach.reaches?`. The only existing spec changed in a way that matters is the public-surface spec of #12 (Phase 4), which pins the list of public names and has to list the three new ones.
- Commit messages are plain imperative sentences, one commit per phase (plus the red first commit, and one for each batch of fixtures), each ending with the attribution line the session gives. One git operation per shell call.
- **The code in this plan was run.** It was written and run in a scratch copy of the gem (outside the repository) before this plan was written: the full suite there is 1750 examples, 0 failures, 2 pending, the 80 hand-derived DATC results all match, and four deliberate bugs were each caught by the specs (the owner's own supports counting toward a dislodgement: 38 failures; no exception for a supported move's destination when cutting: 18; no "province must be empty" condition for standoffs: 9; a circle that fails instead of succeeding: 8). A step that shows a different result than the plan says is a bug to find, not a number to edit.

## Goal

`TA.adjudicate(position, orders)` returns a `TA::Adjudication` that matches `docs/interface.md` for every input without a working convoy, with `TA::Outcome` and `TA::Adjudication` as value objects that keep the rules of `## Value objects`. It gives the DATC v3.4 preferred results for the 80 encoded cases of 6.A to 6.F.1, and stays consistent with the DATC's conditions over seeded random boards that hold the hard shapes. Convoys are #15: until then a move that goes by convoy is `:no_route` and a legal convoy order is `:unmatched`, pinned in one file.

---

## Pre-implementation gates

- **Simplicity (≤3 components):** value objects (`Outcome`, `Adjudication`: two small files, each one `Data` class like the others), the resolver (`Resolver`: decides every move, one concept), and the assembly (`Adjudicate`: orders in, `TA::Adjudication` out). `TA.adjudicate` is one line. No dependency.
- **Anti-abstraction:** `Resolver` and `Adjudicate` are plain internal classes and modules, `private_constant` like `Check` and `Reach`. The orders are the existing `Data` classes; `Resolver::Entry` pairs an order with its unit and nothing more. No parallel model.
- **Integration-first:** the contract is `docs/interface.md`. The first spec of the feature is its first example (Phase 1), and the examples spec runs every example of the three sections (Phases 4 and 8).

## Decisions the plan settles (spec left them open)

| Decision | Choice | Spec |
|---|---|---|
| Files | `lib/trucebearer/adjudicator/outcome.rb`, `adjudication.rb`, `resolver.rb`, `adjudicate.rb`, required from `adjudicator.rb` after `legal_orders`. `Resolver` and `Adjudicate` are `private_constant` | all |
| How a move is decided | Each move is `nil` (unknown), `true` or `false`. Strengths are `[least, most]` pairs from what is decided; a move is decided when its pair settles it. When nothing more can be decided, the undecided moves that wait on one another in a circle of three or more all succeed; anything else left over fails and sets `paradox` | AC-10.3, AC-12.2 |
| One place for the convoy rule | `Resolver#path?(move)` is `!convoy?(move)`. #15 changes that one method and the result symbols for convoy orders | AC-13.1 |
| How the resolver reads a support | `matched?` is fixed by the orders alone; `cut?` is `true` when a move from another power with a route reaches the supporter's province (unless the supported move goes to that move's origin), or when a move into the supporter's province is decided true; `given?` is its negation, `nil` while unknown | AC-8.x |
| Outcome checks | `Outcome::ALLOWED` maps each order class to its results; `Outcome::RESULTS` is the contract's order. Checks live in `Outcome.check_combination!` and `Adjudication.check_list!` | AC-2.4, AC-3.4 |
| Where the impossible-object examples go in the contract | `### Impossible objects`, labelled "From 0.2.0", as the spec's AC-3.5 says. #87 now marks `## Value objects` as "0.1.0, except `TA::Outcome` and `TA::Adjudication`", so this is inside the 0.2.0 material, as Gate A ruled | AC-3.5, AC-14.3 |
| The last-resort branch | `Resolver#last_resort` fails the moves on the cycles that are stuck (any size), or every undecided move if no cycle is found, and sets `paradox`. Unreachable without convoys | AC-12.2 |
| Commits that are red | None after Phase 1's deliberate red first spec: Phase 5 adds a loader and a runner that have no cases yet; Phase 6 adds the fixtures and the file-set examples in one commit | |
| A failure that `main` already has | `spec/trucebearer/adjudicator_spec.rb` pins `VERSION` to `0.0.0`, and the 0.1.0 release moved it to `0.1.0`; the `Adjudicator` job fails on `main`'s release commit for that reason alone. **If the coordinator approves (Gate B), the Preliminary step fixes it first**, in its own commit; if `main` gets the fix another way, merge it instead | `Done when`: the CI job is green |
| Error message for a duplicate | `"england gave two orders for the province lon"` | AC-5.2 |
| Fixtures | Written by a throwaway script from the table in Phase 6 (kept out of the repository), then checked by the runner and the checking runner. The table is the hand-derived expectation, in this plan | AC-11.1 |
| Extending #12's public-surface spec | In step with the code: `:Outcome` joins `TA.constants` in Phase 2, `:Adjudication` in Phase 3, and in Phase 4 `:adjudicate` joins `TA.singleton_methods` and `Adjudicate` and `Resolver` are checked private | spec 012 AC-7.5 |

## Phases at a glance

| Phase | Delivers | Commit |
|---|---|---|
| Prelim. | The version spec that `main` already fails (if approved) | "Let the version spec follow releases" |
| 1 | The first spec, red | "Add the first adjudication spec, which fails until TA.adjudicate exists" |
| 2 | `TA::Outcome` | "Add TA::Outcome" |
| 3 | `TA::Adjudication` and the `Marshal` examples | "Add TA::Adjudication and keep both through Marshal" |
| 4 | The resolver, `TA.adjudicate`, the examples spec | "Adjudicate movement phases without convoys" |
| 5 | The DATC loader and the adjudication runner | "Read results and the position after the moves from the DATC fixtures" |
| 6 | The 80 fixtures and the file-set examples | "Encode the DATC cases of 6.A to 6.E and 6.F.1 with results" |
| 7 | Random boards and the conditions | "Check the results against the DATC conditions on random boards" |
| 8 | Contract examples, `ruleset.md`, CHANGELOG, final checks | "Record the adjudication choices and the contract's impossible objects" |

**Size.** 8 phases (and the one-commit preliminary), about 560 lines of code and 1,300 lines of specs, plus 53 new and 27 changed fixture files of 10 to 40 lines. **Recommendation (Open Question 4): one pull request.** The resolver can't be split by DATC section (the same algorithm decides all of them), and every phase ends green, so each commit can be reviewed on its own. If it is thought too large, the fallback split is: pull request 1 = the engine, the random boards and the contract (Phases 1 to 4, 7 and 8); pull request 2 = the DATC runner and the fixtures (Phases 5 and 6, "Closes #14"). The review suggested this cut, which keeps the specs that share the resolver together. Both follow this one spec. (A split by DATC section would separate specs that share one resolver.)

---

## Preliminary: the version spec that `main` already fails

*Only if the coordinator approves it at Gate B.* `bundle exec rspec` on the merged branch, before any change of this feature, gives 742 examples, 1 failure, 1 pending: the failure is `spec/trucebearer/adjudicator_spec.rb`, which expects `VERSION` to be `"0.0.0"`. The release script bumps the version and doesn't touch that spec, so every release would break it. The `Adjudicator` job on `main`'s release commit fails for this reason. The proof the Issue asks for ("`bundle exec rspec` passes", the CI job green) can't hold without it.

- [ ] **Step 1: change the spec** so that it follows releases:

```ruby
# frozen_string_literal: true

require "trucebearer/adjudicator"

RSpec.describe Trucebearer::Adjudicator do
  it "has a version number" do
    expect(Trucebearer::Adjudicator::VERSION).to match(/\A\d+\.\d+\.\d+\z/)
  end
end
```

- [ ] **Step 2: run** `bundle exec rspec spec/trucebearer/adjudicator_spec.rb`. Expected: 1 example, 0 failures. Then `bundle exec rspec`: 742 examples, 0 failures, 1 pending.
- [ ] **Step 3: commit** "Let the version spec follow releases".

---

## Phase 1: The first spec, red

**Implements:** Story 1 | **Satisfies:** AC-1.1 (written, red)
**Files:** create `spec/trucebearer/adjudicator/adjudicate_examples_spec.rb`
**Interfaces:** `TA.adjudicate(position, orders) -> TA::Adjudication` (not yet defined)

- [ ] **Step 1: write the contract's example as a spec.** It is the example under `## Adjudicating a movement phase`, with every expected value of AC-1.1.

```ruby
# frozen_string_literal: true

require "trucebearer/adjudicator"
require_relative "../../support/board"

# The first spec of the feature: the contract's adjudication example (AC-1.1).
RSpec.describe "TA.adjudicate: the examples of docs/interface.md" do
  let(:start) { TA::Map.classic.starting_position }

  it "adjudicates England's London to the North Sea and Germany's Kiel to Holland (AC-1.1)" do
    orders = [O::Move.new(power: :england, at: :lon, destination: L.new(province: :nth)),
              O::Move.new(power: :germany, at: :kie, destination: L.new(province: :hol))]
    result = TA.adjudicate(start, orders)
    expect(result.outcomes.first(2).map(&:result)).to eq(%i[succeeded succeeded])
    implied = result.outcomes.reject(&:submitted)
    expect(implied.size).to eq(20)
    expect(implied.map(&:order)).to all(be_a(O::Hold))
    expect(implied.map(&:result)).to all(eq(:held))
    expect(result.paradox).to be(false)
    expect(result.position.phase).to eq(:retreat)
    expect(result.position.dislodged_units).to eq([])
    expect(result.position.standoffs).to eq([])
    expect(result.outcomes.drop(2).first(3).map { _1.order.at }).to eq(%i[ank ber bre])
    provinces = result.position.units.map { _1.location.province }
    expect(provinces).to include(:nth, :hol)
    expect(provinces).not_to include(:lon, :kie)
    expect(result.position.ownership).to eq(start.ownership)
  end
end
```

- [ ] **Step 2: run it, see it fail for the right reason.**
  Command: `bundle exec rspec spec/trucebearer/adjudicator/adjudicate_examples_spec.rb`
  Expected: 1 example, 1 failure, `NoMethodError: undefined method 'adjudicate' for module Trucebearer::Adjudicator`.
- [ ] **Step 3: commit** "Add the first adjudication spec, which fails until TA.adjudicate exists" (the spec file only; the spec and this plan are already committed).

---

## Phase 2: `TA::Outcome`

**Implements:** Story 2 | **Satisfies:** AC-2.1 to AC-2.5
**Files:** create `lib/trucebearer/adjudicator/outcome.rb`, `spec/trucebearer/adjudicator/outcome_spec.rb`; modify `lib/trucebearer/adjudicator.rb` (one `require_relative`), `spec/trucebearer/adjudicator/legal_orders_spec.rb` (one constant)
**Interfaces:** `TA::Outcome.new(order:, result:, submitted:, dislodged:)`, `#to_h`, `Outcome.from_h(hash)`, `Outcome::RESULTS`, `Outcome::ALLOWED`, `Outcome.check_combination!`

- [ ] **Step 1: write `outcome_spec.rb`.**

```ruby
# frozen_string_literal: true

require "json"
require "trucebearer/adjudicator"
require_relative "../../support/board"

# TA::Outcome (AC-2.1 to AC-2.5).
RSpec.describe TA::Outcome do
  let(:hold) { O::Hold.new(power: :england, at: :lon) }
  let(:move) { O::Move.new(power: :france, at: :mao, destination: L.new(province: :spa, coast: :nc)) }

  # One order of each class, with the results docs/interface.md `### Outcomes` allows it.
  samples = {
    "Hold" => [-> { O::Hold.new(power: :england, at: :lon) }, %i[void held]],
    "Move" => [-> { O::Move.new(power: :france, at: :mao, destination: L.new(province: :spa, coast: :nc)) }, %i[void no_route bounced succeeded]],
    "MoveViaConvoy" => [-> { O::MoveViaConvoy.new(power: :england, at: :lon, to: :wal) }, %i[void no_route bounced succeeded]],
    "SupportHold" => [-> { O::SupportHold.new(power: :germany, at: :mun, target: :ber) }, %i[void unmatched cut given]],
    "SupportMove" => [-> { O::SupportMove.new(power: :france, at: :por, from: :mao, to: :spa) }, %i[void unmatched cut given]],
    "Convoy" => [-> { O::Convoy.new(power: :england, at: :nth, from: :lon, to: :nwy) }, %i[void unmatched disrupted given]]
  }

  def build(order, result, submitted: true, dislodged: false)
    described_class.new(order: order, result: result, submitted: submitted, dislodged: dislodged)
  end

  it "builds a frozen value with equal contents equal (AC-2.1)" do
    outcome = build(hold, :held, submitted: false)
    expect(outcome).to be_frozen
    expect(outcome).to eq(build(hold, :held, submitted: false))
    expect(outcome.hash).to eq(build(hold, :held, submitted: false).hash)
    expect(outcome.to_h).to eq(
      "order" => { "format" => 1, "type" => "hold", "power" => "england", "at" => "lon" },
      "result" => "held", "submitted" => false, "dislodged" => false
    )
    expect(outcome.to_h.keys).to eq(%w[order result submitted dislodged])
    expect(described_class.from_h(JSON.parse(JSON.generate(outcome.to_h)))).to eq(outcome)
  end

  it "lists the nine results in the order of the contract (AC-2.5)" do
    expect(described_class::RESULTS).to eq(%i[void held no_route bounced succeeded unmatched cut given disrupted])
    line = File.read(File.expand_path("../../../docs/interface.md", __dir__))[/^- `result`: one of .*$/]
    expect(line.scan(/`:(\w+)`/).flatten.map(&:to_sym)).to eq(described_class::RESULTS)
  end

  samples.each do |name, (maker, allowed)|
    describe "an outcome of a #{name}" do
      allowed.each do |result|
        [true, false].each do |dislodged|
          next if result == :void && dislodged
          next if result == :succeeded && dislodged

          it "round-trips with #{result.inspect}, dislodged #{dislodged} (AC-2.2)" do
            outcome = build(maker.call, result, dislodged: dislodged)
            rebuilt = described_class.from_h(JSON.parse(JSON.generate(outcome.to_h)))
            expect(rebuilt).to eq(outcome)
            expect(outcome.to_h).not_to have_key("format")
            expect(outcome.to_h["order"]["format"]).to eq(1)
          end
        end
      end

      (described_class::RESULTS - allowed).each do |result|
        it "refuses #{result.inspect} (AC-2.4)" do
          expect { build(maker.call, result) }.to raise_error(TA::InvalidInput, /#{result}/)
        end
      end
    end
  end

  it "refuses the other impossible outcomes, from new and from from_h (AC-2.4)" do
    impossible = [
      -> { build(hold, :void, dislodged: true) },
      -> { build(move, :void, dislodged: true) },
      -> { build(move, :bounced, submitted: false) },
      -> { build(hold, :void, submitted: false) },
      -> { build(move, :succeeded, dislodged: true) }
    ]
    impossible.each { |make| expect { make.call }.to raise_error(TA::InvalidInput) }
    hash = build(hold, :held).to_h.merge("result" => "void", "dislodged" => true)
    expect { described_class.from_h(hash) }.to raise_error(TA::InvalidInput, /void/)
  end

  it "refuses a bad hash, naming the key or value (AC-2.3)" do
    good = build(hold, :held).to_h
    expect { described_class.from_h(good.reject { |key, _| key == "result" }) }.to raise_error(TA::InvalidInput, /result/)
    expect { described_class.from_h(good.merge("extra" => 1)) }.to raise_error(TA::InvalidInput, /extra/)
    expect { described_class.from_h(good.merge("format" => 1)) }.to raise_error(TA::InvalidInput, /format/)
    expect { described_class.from_h(good.merge("result" => "nonsense")) }.to raise_error(TA::InvalidInput, /nonsense/)
    expect { described_class.from_h(good.merge("submitted" => "yes")) }.to raise_error(TA::InvalidInput, /submitted/)
    expect { described_class.from_h(good.merge("dislodged" => nil)) }.to raise_error(TA::InvalidInput, /dislodged/)
    expect { described_class.from_h(good.merge("order" => { "type" => "hold" })) }.to raise_error(TA::InvalidInput)
    expect { described_class.new(order: hold, result: "held", submitted: true, dislodged: false) }.to raise_error(TA::InvalidInput, /held/)
    expect { described_class.new(order: hold.to_h, result: :held, submitted: true, dislodged: false) }.to raise_error(TA::InvalidInput)
  end
end
```

- [ ] **Step 2: run it, see it fail.**
  Command: `bundle exec rspec spec/trucebearer/adjudicator/outcome_spec.rb`
  Expected: `NameError: uninitialized constant ... Outcome` (every example errors).
- [ ] **Step 3: write `outcome.rb`.** The contract's `### TA::Outcome`; the impossible combinations of AC-2.4 (a result the order class doesn't have, a void order that is dislodged, an implied hold that isn't a held `Hold`, and a move that succeeded and was dislodged).

```ruby
# frozen_string_literal: true

module Trucebearer
  module Adjudicator
    # What happened to one order in an adjudicated phase. Carries no format of its own: it
    # only appears inside an Adjudication, and its order keeps the order's own format.
    Outcome = Data.define(:order, :result, :submitted, :dislodged) do
      include Shape::Marshalable

      def initialize(order:, result:, submitted:, dislodged:)
        unless Outcome::ALLOWED.key?(order.class)
          raise InvalidInput, "\"order\" must be one of the six order classes, got #{order.inspect}"
        end
        Shape.symbol_of(result, Outcome::RESULTS, "result", "result")
        Shape.boolean!(submitted, "submitted")
        Shape.boolean!(dislodged, "dislodged")
        Outcome.check_combination!(order, result, submitted, dislodged)
        super
      end

      def to_h
        { "order" => order.to_h, "result" => result.to_s, "submitted" => submitted, "dislodged" => dislodged }
      end

      def self.from_h(hash)
        Shape.keys!(hash, %w[order result submitted dislodged])
        new(order: Order.from_h(hash["order"]),
            result: Shape.text_of(hash["result"], Outcome::RESULTS, "result", "result"),
            submitted: Shape.boolean!(hash["submitted"], "submitted"),
            dislodged: Shape.boolean!(hash["dislodged"], "dislodged"))
      end

      # The impossible outcomes of docs/interface.md: a result the order class doesn't have,
      # a void order that is dislodged, an implied hold that is not a held Hold, and a
      # move that succeeded and was dislodged.
      def self.check_combination!(order, result, submitted, dislodged)
        unless Outcome::ALLOWED.fetch(order.class).include?(result)
          raise InvalidInput, "an order of class #{order.class.name.split("::").last} cannot have the result #{result.inspect}"
        end
        raise InvalidInput, "a void order cannot be dislodged" if result == :void && dislodged
        if !submitted && !(order.is_a?(Order::Hold) && result == :held)
          raise InvalidInput, "an implied hold is a Hold with the result :held, got #{order.inspect} with #{result.inspect}"
        end
        return unless result == :succeeded && dislodged

        raise InvalidInput, "a unit whose move succeeded cannot be dislodged"
      end
    end

    # The nine result symbols, in the order of docs/interface.md.
    Outcome::RESULTS = %i[void held no_route bounced succeeded unmatched cut given disrupted].freeze

    # Which results each order class can have (docs/interface.md `### Outcomes`).
    Outcome::ALLOWED = {
      Order::Hold => %i[void held],
      Order::Move => %i[void no_route bounced succeeded],
      Order::MoveViaConvoy => %i[void no_route bounced succeeded],
      Order::SupportHold => %i[void unmatched cut given],
      Order::SupportMove => %i[void unmatched cut given],
      Order::Convoy => %i[void unmatched disrupted given]
    }.freeze
  end
end
```

- [ ] **Step 4: require it.** In `lib/trucebearer/adjudicator.rb`, after `require_relative "adjudicator/legal_orders"` add `require_relative "adjudicator/outcome"`.
- [ ] **Step 5: keep #12's public-surface spec true.** `TA::Outcome` is a public constant from now on, and `legal_orders_spec.rb` pins the exact list. In `describe "the public surface (AC-7.5)"`, change the `TA.constants` line to:

```ruby
      expect(TA.constants).to contain_exactly(:CheckResult, :DislodgedUnit, :InvalidInput, :Location, :Map,
                                              :Order, :Outcome, :Position, :Unit, :VERSION)
```

- [ ] **Step 6: run it, see it pass.**
  Command: `bundle exec rspec spec/trucebearer/adjudicator/outcome_spec.rb spec/trucebearer/adjudicator/legal_orders_spec.rb`
  Expected: 0 failures.
- [ ] **Step 7: run the whole suite** (`bundle exec rspec`): 0 failures, except the first spec of Phase 1 (1 failure, still red on purpose).
- [ ] **Step 8: commit** "Add TA::Outcome".

---

## Phase 3: `TA::Adjudication`

**Implements:** Story 3 and Story 4 | **Satisfies:** AC-3.1 to AC-3.4, AC-4.1, AC-4.2
**Files:** create `lib/trucebearer/adjudicator/adjudication.rb`, `spec/trucebearer/adjudicator/adjudication_spec.rb`; modify `lib/trucebearer/adjudicator.rb`, `spec/trucebearer/adjudicator/marshal_spec.rb`, `spec/trucebearer/adjudicator/legal_orders_spec.rb` (one constant)
**Interfaces:** `TA::Adjudication.new(outcomes:, paradox:, position:)`, `#to_h`, `Adjudication.from_h(hash)`, `Adjudication.check_list!`

- [ ] **Step 1: write `adjudication_spec.rb`.**

```ruby
# frozen_string_literal: true

require "json"
require "trucebearer/adjudicator"
require_relative "../../support/board"

# TA::Adjudication (AC-3.1 to AC-3.5).
RSpec.describe TA::Adjudication do
  let(:position) { TA::Map.classic.starting_position }

  def outcome(order, result = :held, submitted: true, dislodged: false)
    TA::Outcome.new(order: order, result: result, submitted: submitted, dislodged: dislodged)
  end

  def hold(power, at) = O::Hold.new(power: power, at: at)

  def build(outcomes, paradox: false) = described_class.new(outcomes: outcomes, paradox: paradox, position: position)

  it "keeps the order of the outcomes, freezes its own copy and leaves the caller's array alone (AC-3.1)" do
    list = [outcome(hold(:england, :lon)), outcome(hold(:austria, :bud)), outcome(hold(:france, :bre), submitted: false)]
    adjudication = build(list)
    expect(adjudication).to be_frozen
    expect(adjudication.outcomes).to be_frozen
    expect(adjudication.outcomes.map { _1.order.at }).to eq(%i[lon bud bre])
    expect(list).not_to be_frozen
    expect(build(list)).to eq(adjudication)
    expect(build(list).hash).to eq(adjudication.hash)
  end

  it "round-trips through JSON, with format first (AC-3.2)" do
    adjudication = build([outcome(hold(:england, :lon)), outcome(hold(:france, :bre), submitted: false)], paradox: true)
    expect(adjudication.to_h.keys).to eq(%w[format outcomes paradox position])
    expect(adjudication.to_h["format"]).to eq(1)
    expect(described_class.from_h(JSON.parse(JSON.generate(adjudication.to_h)))).to eq(adjudication)
  end

  it "refuses a bad hash, naming the key or value (AC-3.3)" do
    good = build([outcome(hold(:england, :lon))]).to_h
    expect { described_class.from_h(good.reject { |key, _| key == "paradox" }) }.to raise_error(TA::InvalidInput, /paradox/)
    expect { described_class.from_h(good.merge("extra" => 1)) }.to raise_error(TA::InvalidInput, /extra/)
    expect { described_class.from_h(good.reject { |key, _| key == "format" }) }.to raise_error(TA::InvalidInput, /format/)
    expect { described_class.from_h(good.merge("format" => 2)) }.to raise_error(TA::InvalidInput, /2/)
    expect { described_class.from_h(good.merge("paradox" => "no")) }.to raise_error(TA::InvalidInput, /paradox/)
    expect { described_class.from_h(good.merge("outcomes" => "none")) }.to raise_error(TA::InvalidInput, /outcomes/)
    expect { described_class.from_h(good.merge("outcomes" => [{}])) }.to raise_error(TA::InvalidInput)
    expect { described_class.from_h(good.merge("position" => {})) }.to raise_error(TA::InvalidInput)
    expect { described_class.new(outcomes: [1], paradox: false, position: position) }.to raise_error(TA::InvalidInput, /outcomes/)
    expect { described_class.new(outcomes: [], paradox: 1, position: position) }.to raise_error(TA::InvalidInput, /paradox/)
    expect { described_class.new(outcomes: [], paradox: false, position: nil) }.to raise_error(TA::InvalidInput, /position/)
  end

  describe "the impossible adjudications (AC-3.4)" do
    it "refuses a submitted outcome after an implied hold" do
      list = [outcome(hold(:france, :bre), submitted: false), outcome(hold(:england, :lon))]
      expect { build(list) }.to raise_error(TA::InvalidInput, /after an implied hold/)
    end

    it "refuses implied holds that are not in ascending order of province, or repeat one" do
      expect { build([outcome(hold(:france, :bre), submitted: false), outcome(hold(:england, :bel), submitted: false)]) }
        .to raise_error(TA::InvalidInput, /ascending/)
      expect { build([outcome(hold(:france, :bre), submitted: false), outcome(hold(:france, :bre), submitted: false)]) }
        .to raise_error(TA::InvalidInput, /ascending/)
    end

    it "refuses two submitted outcomes for one power and province, which adjudication refuses as input" do
      list = [outcome(hold(:england, :lon)), outcome(O::Move.new(power: :england, at: :lon, destination: L.new(province: :nth)), :bounced)]
      expect { build(list) }.to raise_error(TA::InvalidInput, /same power and province/)
    end

    it "accepts two submitted outcomes for one province from two powers (one is void)" do
      list = [outcome(hold(:france, :lon), :void), outcome(hold(:england, :lon))]
      expect { build(list) }.not_to raise_error
    end

    it "takes any phase for the position, since 0.3 changes it" do
      movement = TA::Position.from_h(position.to_h.merge("phase" => "movement"))
      expect { described_class.new(outcomes: [], paradox: false, position: movement) }.not_to raise_error
    end
  end
end
```

- [ ] **Step 2: add `Outcome` and `Adjudication` to the `Marshal` spec** (the two entries each in the object list, the tampered-payload rows and the base objects). The adjudications are built by hand, since `TA.adjudicate` doesn't exist yet. The complete diff against the file as it is on `main`:

```diff
@@ -58,7 +58,25 @@
     ["SupportMove", -> { O::SupportMove.new(power: :france, at: :por, from: :mao, to: :spa) }],
     ["Convoy", -> { O::Convoy.new(power: :england, at: :nth, from: :lon, to: :nwy) }],
     ["CheckResult, legal", -> { TA::CheckResult.new(legal: true, reasons: []) }],
-    ["CheckResult, illegal", -> { TA::CheckResult.new(legal: false, reasons: [:no_unit]) }]
+    ["CheckResult, illegal", -> { TA::CheckResult.new(legal: false, reasons: [:no_unit]) }],
+    ["Outcome, an implied hold", -> { TA::Outcome.new(order: O::Hold.new(power: :england, at: :lon), result: :held, submitted: false, dislodged: false) }],
+    ["Outcome, a dislodged move", lambda {
+      TA::Outcome.new(order: O::Move.new(power: :germany, at: :boh, destination: L.new(province: :vie)),
+                      result: :bounced, submitted: true, dislodged: true)
+    }],
+    ["Adjudication, hand built", lambda {
+      held = TA::Outcome.new(order: O::Hold.new(power: :england, at: :lon), result: :held, submitted: true, dislodged: false)
+      TA::Adjudication.new(outcomes: [held], paradox: false, position: TA::Map.classic.starting_position)
+    }],
+    ["Adjudication, with a dislodged unit", lambda {
+      move = O::Move.new(power: :germany, at: :boh, destination: L.new(province: :vie))
+      outcomes = [TA::Outcome.new(order: O::Hold.new(power: :austria, at: :vie), result: :held, submitted: false, dislodged: true),
+                  TA::Outcome.new(order: move, result: :succeeded, submitted: true, dislodged: false)]
+      dislodged = TA::DislodgedUnit.new(unit: Board.army, attacker_from: :boh, by_convoy: false)
+      TA::Adjudication.new(outcomes: outcomes.reverse, paradox: false,
+                           position: TA::Position.new(map: "classic", season: :spring, year: 1901, phase: :retreat,
+                                                      units: [Board.fleet], ownership: {}, dislodged_units: [dislodged], standoffs: []))
+    }]
   ]
 
   it "returns an equal position whose units are frozen, for the 1901 start (the Issue's own example)" do
@@ -185,7 +203,13 @@
       [O::Convoy, ->(h) { h.merge("from" => "xyz") }, /"xyz"/],
       [TA::CheckResult, ->(h) { h.merge("format" => 2) }, /format/],
       [TA::CheckResult, ->(h) { h.merge("reasons" => ["bogus"]) }, /"bogus"/],
-      [TA::CheckResult, ->(h) { h.merge("legal" => true) }, /no reasons/]
+      [TA::CheckResult, ->(h) { h.merge("legal" => true) }, /no reasons/],
+      [TA::Outcome, ->(h) { h.merge("result" => "bounced") }, /bounced/],
+      [TA::Outcome, ->(h) { h.merge("result" => "void", "dislodged" => true) }, /void/],
+      [TA::Outcome, ->(h) { h.merge("order" => h["order"].merge("format" => 2)) }, /format/],
+      [TA::Adjudication, ->(h) { h.merge("format" => 2) }, /format/],
+      [TA::Adjudication, ->(h) { h.merge("outcomes" => h["outcomes"].dup.insert(1, h["outcomes"].first)) }, /same power and province/],
+      [TA::Adjudication, ->(h) { h.merge("paradox" => "no") }, /paradox/]
     ]
     bases = {
       TA::Location => -> { L.new(province: :bud) },
@@ -198,7 +222,13 @@
       O::SupportHold => -> { O::SupportHold.new(power: :germany, at: :mun, target: :ber) },
       O::SupportMove => -> { O::SupportMove.new(power: :france, at: :por, from: :mao, to: :spa) },
       O::Convoy => -> { O::Convoy.new(power: :england, at: :nth, from: :lon, to: :nwy) },
-      TA::CheckResult => -> { TA::CheckResult.new(legal: false, reasons: [:no_unit]) }
+      TA::CheckResult => -> { TA::CheckResult.new(legal: false, reasons: [:no_unit]) },
+      TA::Outcome => -> { TA::Outcome.new(order: O::Hold.new(power: :england, at: :lon), result: :held, submitted: true, dislodged: false) },
+      TA::Adjudication => lambda {
+        outcomes = [TA::Outcome.new(order: O::Hold.new(power: :england, at: :lon), result: :held, submitted: true, dislodged: false),
+                    TA::Outcome.new(order: O::Hold.new(power: :france, at: :bre), result: :held, submitted: false, dislodged: false)]
+        TA::Adjudication.new(outcomes: outcomes, paradox: false, position: TA::Map.classic.starting_position)
+      }
     }
 
     spots.each_with_index do |(klass, change, message), index|
```

- [ ] **Step 3: run, see it fail.**
  Command: `bundle exec rspec spec/trucebearer/adjudicator/adjudication_spec.rb spec/trucebearer/adjudicator/marshal_spec.rb`
  Expected: `NameError: uninitialized constant ... Adjudication` (the `Outcome` examples of the `Marshal` spec already pass, since `Outcome` exists).
- [ ] **Step 4: write `adjudication.rb`.** The contract's `### TA::Adjudication`; the impossible lists of AC-3.4. `check_list!` only reads the outcomes, so the position can be in any phase.

```ruby
# frozen_string_literal: true

module Trucebearer
  module Adjudicator
    # The result of adjudicating a phase. Storable: its hash form carries format.
    Adjudication = Data.define(:outcomes, :paradox, :position) do
      include Shape::Marshalable

      def initialize(outcomes:, paradox:, position:)
        list = Shape.list_of(outcomes, Outcome, "outcomes")
        Shape.boolean!(paradox, "paradox")
        Shape.instance_of!(position, Position, "position")
        Adjudication.check_list!(list)
        super(outcomes: list.dup.freeze, paradox: paradox, position: position)
      end

      def to_h
        { "format" => Shape::FORMAT, "outcomes" => outcomes.map(&:to_h), "paradox" => paradox, "position" => position.to_h }
      end

      def self.from_h(hash)
        Shape.format!(hash)
        Shape.keys!(hash, %w[format outcomes paradox position])
        new(outcomes: Shape.array!(hash["outcomes"], "outcomes").map { |outcome| Outcome.from_h(outcome) },
            paradox: Shape.boolean!(hash["paradox"], "paradox"),
            position: Position.from_h(hash["position"]))
      end

      # The impossible adjudications: a submitted outcome after an implied hold, implied holds
      # that are not in ascending order of province, and two submitted outcomes for one power
      # and province (adjudication refuses that input).
      def self.check_list!(list)
        submitted, implied = list.partition(&:submitted)
        first_implied = list.index { |outcome| !outcome.submitted }
        if first_implied && list[first_implied..].any?(&:submitted)
          raise InvalidInput, "an outcome of a submitted order comes after an implied hold"
        end
        Shape.unique!(submitted.map { |outcome| [outcome.order.power, outcome.order.at] },
                      "two submitted outcomes are for the same power and province")
        provinces = implied.map { |outcome| outcome.order.at }
        return if provinces.each_cons(2).all? { |a, b| a < b }

        raise InvalidInput, "implied holds must be in ascending order of province, got #{provinces.inspect}"
      end
    end
  end
end
```

- [ ] **Step 5: require it.** After the `outcome` line add `require_relative "adjudicator/adjudication"`.
- [ ] **Step 6: keep the public-surface spec true.** In `legal_orders_spec.rb` the `TA.constants` line becomes:

```ruby
      expect(TA.constants).to contain_exactly(:Adjudication, :CheckResult, :DislodgedUnit, :InvalidInput, :Location, :Map,
                                              :Order, :Outcome, :Position, :Unit, :VERSION)
```

- [ ] **Step 7: run, see them pass.** Command: `bundle exec rspec spec/trucebearer/adjudicator/adjudication_spec.rb spec/trucebearer/adjudicator/marshal_spec.rb spec/trucebearer/adjudicator/legal_orders_spec.rb`. Expected: 0 failures (the `Marshal` spec is 182 examples).
- [ ] **Step 8: commit** "Add TA::Adjudication and keep both through Marshal".

---

## Phase 4: The resolver, `TA.adjudicate` and the examples

**Implements:** Stories 1, 5, 6, 7, 8, 9, 10 and 13 | **Satisfies:** AC-1.1 to AC-1.3, AC-5.1 to AC-5.5, AC-6.1 to AC-6.5, AC-7.1 to AC-7.5, AC-8.1 to AC-8.7, AC-9.2 to AC-9.6, AC-10.1 to AC-10.4 (the unit-level ones; the DATC ones are Phase 6), AC-13.1, AC-13.2
**Files:** create `lib/trucebearer/adjudicator/resolver.rb`, `lib/trucebearer/adjudicator/adjudicate.rb`, `spec/support/adjudicating.rb`, `spec/trucebearer/adjudicator/adjudicate_input_spec.rb`, `adjudicate_moves_spec.rb`, `adjudicate_supports_spec.rb`, `adjudicate_battles_spec.rb`, `adjudicate_convoy_stub_spec.rb`; replace `adjudicate_examples_spec.rb`; modify `lib/trucebearer/adjudicator.rb`, `spec/trucebearer/adjudicator/legal_orders_spec.rb`
**Interfaces:** `TA.adjudicate(position, orders) -> TA::Adjudication`; internal `Adjudicate.call`, `Resolver.new(position, orders)` with `#result(entry)`, `#dislodged?(entry)`, `#entry_at(province)`, `#next_units`, `#dislodged_units`, `#standoffs`, `#paradox`

- [ ] **Step 1: write the support file** the specs of this and later phases use.

```ruby
# frozen_string_literal: true

require_relative "board"

# Short builders for the adjudication specs: units and orders in the notation of the
# DATC fixtures ("spa/nc" for a coast), and a call that adjudicates them in a position
# that holds only those units.
module Adjudicating
  module_function

  def u(power, type, at) = Board.unit(power, type, at)
  def hd(power, at) = O::Hold.new(power: power, at: at)
  def mv(power, at, to) = O::Move.new(power: power, at: at, destination: Board.loc(to))
  def mvc(power, at, to) = O::MoveViaConvoy.new(power: power, at: at, to: to)
  def sh(power, at, target) = O::SupportHold.new(power: power, at: at, target: target)
  def sm(power, at, from, to) = O::SupportMove.new(power: power, at: at, from: from, to: to)
  def cv(power, at, from, to) = O::Convoy.new(power: power, at: at, from: from, to: to)

  def run(units, orders) = TA.adjudicate(Board.position(*units), orders)

  # The result symbols of the first `count` outcomes (the submitted ones).
  def results(adjudication, count) = adjudication.outcomes.first(count).map(&:result)

  # Where each unit of the next position stands, as {province => power}.
  def after(adjudication) = adjudication.position.units.to_h { |unit| [unit.location.province, unit.power] }

  # The dislodged units of the next position, as {province => attacker_from}.
  def dislodged(adjudication)
    adjudication.position.dislodged_units.to_h { |entry| [entry.unit.location.province, entry.attacker_from] }
  end
end

RSpec.configure { |config| config.include Adjudicating }
```

- [ ] **Step 2: write the five behavior specs.** The input and void orders (Stories 5 and 6):

```ruby
# frozen_string_literal: true

require "trucebearer/adjudicator"
require_relative "../../support/adjudicating"

# What TA.adjudicate refuses (Story 5), and void orders and implied holds (Story 6).
RSpec.describe "TA.adjudicate: input, void orders and implied holds" do
  let(:start) { TA::Map.classic.starting_position }
  let(:retreat) { TA::Position.from_h(start.to_h.merge("phase" => "retreat")) }
  let(:adjustment) { TA::Position.from_h(start.to_h.merge("phase" => "adjustment")) }

  describe "what it refuses" do
    it "raises for a position that isn't in the movement phase, naming the phase (AC-5.1)" do
      expect { TA.adjudicate(retreat, []) }.to raise_error(TA::InvalidInput, /retreat/)
      expect { TA.adjudicate(adjustment, []) }.to raise_error(TA::InvalidInput, /adjustment/)
    end

    it "raises for two orders of one power for one province, naming both (AC-5.2)" do
      [
        [hd(:england, :lon), hd(:england, :lon)],
        [hd(:england, :lon), mv(:england, :lon, "nth")],
        [hd(:england, :wal), hd(:england, :wal)],
        [hd(:england, :lon), hd(:england, :lon), hd(:france, :lon)]
      ].each do |orders|
        expect { TA.adjudicate(start, orders) }.to raise_error(TA::InvalidInput, /(england|france).*(lon|wal)/)
      end
      expect { TA.adjudicate(start, [hd(:france, :lon), hd(:france, :lon)]) }.to raise_error(TA::InvalidInput, /france.*lon/)
    end

    it "raises the errors in a fixed order: wrong class, then phase, then duplicates (AC-5.2)" do
      twice = [hd(:england, :lon), hd(:england, :lon)]
      expect { TA.adjudicate(retreat, twice) }.to raise_error(TA::InvalidInput, /retreat/)
      expect { TA.adjudicate(nil, twice) }.to raise_error(TA::InvalidInput, /position/)
      expect { TA.adjudicate(retreat, [nil, nil]) }.to raise_error(TA::InvalidInput, /nil/)
    end

    it "raises for an argument of the wrong class, naming it (AC-5.3)" do
      [nil, {}, start.to_h, :start].each { |bad| expect { TA.adjudicate(bad, []) }.to raise_error(TA::InvalidInput, /position/) }
      [nil, {}, hd(:england, :lon)].each { |bad| expect { TA.adjudicate(start, bad) }.to raise_error(TA::InvalidInput, /orders/) }
      [nil, hd(:england, :lon).to_h, TA::CheckResult.new(legal: true, reasons: [])].each do |bad|
        expect { TA.adjudicate(start, [bad]) }.to raise_error(TA::InvalidInput, /#{Regexp.escape(bad.inspect[0, 20])}/)
      end
    end

    it "refuses as input what an Adjudication refuses as output (AC-3.4)" do
      expect { TA.adjudicate(start, [hd(:england, :lon), mv(:england, :lon, "nth")]) }.to raise_error(TA::InvalidInput)
      held = TA::Outcome.new(order: hd(:england, :lon), result: :held, submitted: true, dislodged: false)
      expect { TA::Adjudication.new(outcomes: [held, held], paradox: false, position: start) }
        .to raise_error(TA::InvalidInput, /same power and province/)
    end

    it "never raises for orders of different powers for one unit (AC-5.4)" do
      result = TA.adjudicate(start, [hd(:france, :lon), mv(:england, :lon, "nth"), hd(:germany, :lon)])
      expect(results(result, 3)).to eq(%i[void succeeded void])
      expect(result.outcomes.first(3).map { _1.order.power }).to eq(%i[france england germany])
      result = TA.adjudicate(start, [hd(:france, :wal), hd(:england, :wal)])
      expect(results(result, 2)).to eq(%i[void void])
    end

    it "changes none of its arguments, and gives equal results twice (AC-5.5)" do
      orders = [mv(:england, :lon, "nth"), hd(:france, :lon)]
      first = TA.adjudicate(start, orders)
      expect(orders).not_to be_frozen
      expect(orders.size).to eq(2)
      expect(start).to eq(TA::Map.classic.starting_position)
      expect(TA.adjudicate(start, orders)).to eq(first)
    end
  end

  describe "void orders" do
    # One position and one order for each reason checking can give, except wrong_phase.
    let(:lon_bel) { Board.position(u(:england, :army, "lon"), u(:england, :army, "bel")) }
    let(:convoys) { Board.position(u(:england, :army, "lon"), u(:england, :fleet, "nth"), u(:england, :fleet, "eng")) }
    let(:cases) do
      {
        no_such_unit: [start, hd(:england, :wal)],
        foreign_unit: [start, hd(:france, :lon)],
        own_province: [start, mv(:england, :lon, "lon")],
        not_reachable: [start, mv(:england, :lon, "bel")],
        coast_not_allowed: [start, mv(:france, :mar, "spa/nc")],
        coast_required: [Board.position(u(:france, :fleet, "por")), mv(:france, :por, "spa")],
        coast_unreachable: [Board.position(u(:france, :fleet, "gol")), mv(:france, :gol, "spa/nc")],
        not_army: [Board.position(u(:england, :fleet, "lon")), mvc(:england, :lon, :wal)],
        not_adjacent: [Board.position(u(:england, :army, "lon")), mvc(:england, :lon, :bel)],
        no_convoy_route: [start, mvc(:england, :lvp, :wal)],
        same_province: [lon_bel, sm(:england, :lon, :bel, :bel)],
        no_unit: [start, sh(:germany, :mun, :sil)],
        move_impossible: [lon_bel, sm(:england, :lon, :bel, :yor)],
        not_fleet_at_sea: [start, cv(:england, :lon, :lvp, :bel)],
        bad_endpoints: [convoys, cv(:england, :nth, :lon, :lon)],
        not_on_chain: [convoys, cv(:england, :eng, :lon, :nwy)]
      }
    end

    it "is void exactly when TA.check says the order is illegal, never dislodged, always submitted (AC-6.1)" do
      expect(cases.keys).to match_array(TA::CheckResult::REASONS - [:wrong_phase])
      cases.each do |reason, (position, order)|
        expect(TA.check(position, order).reasons).to eq([reason])
        outcome = TA.adjudicate(position, [order]).outcomes.first
        expect([outcome.result, outcome.dislodged, outcome.submitted]).to eq([:void, false, true]), reason.to_s
      end
      legal = [hd(:england, :lon), mv(:england, :lon, "nth"), sh(:germany, :mun, :ber),
               sm(:austria, :vie, :war, :gal)]
      legal.each do |order|
        expect(TA.check(start, order).legal).to be(true)
        expect(TA.adjudicate(start, [order]).outcomes.first.result).not_to eq(:void)
      end
    end

    it "gives the unit an implied hold when its only order is void (AC-6.2)" do
      result = TA.adjudicate(start, [hd(:france, :lon)])
      implied = result.outcomes.find { _1.order.at == :lon && !_1.submitted }
      expect([implied.order.power, implied.result]).to eq(%i[england held])
    end
  end

  describe "implied holds" do
    it "come after the submitted outcomes, sorted by province, each held and owned by the unit's owner (AC-6.3)" do
      result = TA.adjudicate(start, [mv(:russia, :war, "gal"), hd(:france, :lon), hd(:austria, :vie)])
      expect(result.outcomes.first(3).map { _1.order.at }).to eq(%i[war lon vie])
      implied = result.outcomes.drop(3)
      expect(implied.size).to eq(20)
      expect(implied.map { _1.order.at }).to eq(implied.map { _1.order.at }.sort)
      expect(implied.map(&:submitted)).to all(be(false))
      expect(implied.map(&:result)).to all(eq(:held))
      expect(implied.map(&:dislodged)).to all(be(false))
      owners = start.units.to_h { [_1.location.province, _1.power] }
      expect(implied.map { [_1.order.at, _1.order.power] }).to all(satisfy { |at, power| owners[at] == power })
      expect(implied.map { _1.order.at }).not_to include(:war, :vie)
    end

    it "can be supported and dislodged, and a dislodged one is still held (AC-6.4)" do
      units = [u(:austria, :army, "vie"), u(:germany, :army, "boh"), u(:germany, :army, "tyr"), u(:russia, :army, "gal")]
      result = run(units, [mv(:germany, :boh, "vie"), sm(:germany, :tyr, :boh, :vie), sh(:russia, :gal, :vie)])
      implied = result.outcomes.last
      expect([implied.order.at, implied.result, implied.dislodged, implied.submitted]).to eq([:vie, :held, false, false])
      expect(results(result, 3)).to eq(%i[bounced given given])
      units = [u(:austria, :army, "vie"), u(:germany, :army, "boh"), u(:germany, :army, "tyr")]
      implied = run(units, [mv(:germany, :boh, "vie"), sm(:germany, :tyr, :boh, :vie)]).outcomes.last
      expect([implied.result, implied.dislodged]).to eq([:held, true])
    end

    it "a void support doesn't cut, support or move, and its unit holds (AC-6.4)" do
      units = [u(:england, :army, "lon"), u(:england, :army, "bel"), u(:germany, :army, "kie"), u(:germany, :army, "hol")]
      result = run(units, [sm(:england, :lon, :bel, :yor), mv(:germany, :kie, "hol")])
      expect(results(result, 2)).to eq(%i[void bounced])
      expect(after(result)[:lon]).to eq(:england)
    end

    it "makes every unit hold when no order is given (AC-6.5)" do
      result = TA.adjudicate(start, [])
      expect(result.outcomes.size).to eq(22)
      expect(result.outcomes.map(&:result)).to all(eq(:held))
      expect(result.paradox).to be(false)
      expect(result.position.units).to eq(start.units)
      expect(result.position.phase).to eq(:retreat)
    end
  end
end
```

Moves, bounces and standoffs (Story 7):

```ruby
# frozen_string_literal: true

require "trucebearer/adjudicator"
require_relative "../../support/adjudicating"

# Moves, bounces and standoffs (Story 7).
RSpec.describe "TA.adjudicate: moves, bounces and standoffs" do
  it "moves a unit into an empty province, a fleet onto the coast it named (AC-7.1)" do
    result = run([u(:france, :army, "par")], [mv(:france, :par, "bur")])
    expect(results(result, 1)).to eq([:succeeded])
    expect(after(result)).to eq(bur: :france)
    fleet = run([u(:france, :fleet, "mao")], [mv(:france, :mao, "spa/nc")])
    expect(fleet.position.units.first.location).to eq(L.new(province: :spa, coast: :nc))
    stays = run([u(:france, :fleet, "spa/sc")], [hd(:france, :spa)])
    expect(stays.position.units.first.location).to eq(L.new(province: :spa, coast: :sc))
  end

  it "bounces two units, then three, that move into one empty province, and marks it a standoff (AC-7.2)" do
    two = run([u(:austria, :army, "vie"), u(:italy, :army, "ven")], [mv(:austria, :vie, "tyr"), mv(:italy, :ven, "tyr")])
    expect(results(two, 2)).to eq(%i[bounced bounced])
    expect(two.position.standoffs).to eq([:tyr])
    expect(after(two)).to eq(vie: :austria, ven: :italy)
    three = run([u(:austria, :army, "vie"), u(:germany, :army, "mun"), u(:italy, :army, "ven")],
                [mv(:austria, :vie, "tyr"), mv(:germany, :mun, "tyr"), mv(:italy, :ven, "tyr")])
    expect(results(three, 3)).to eq(%i[bounced bounced bounced])
    expect(three.position.standoffs).to eq([:tyr])
  end

  it "lets the supported move win, and then there is no standoff (AC-7.2)" do
    units = [u(:austria, :army, "vie"), u(:germany, :army, "mun"), u(:germany, :army, "boh"), u(:italy, :army, "ven")]
    result = run(units, [mv(:austria, :vie, "tyr"), mv(:germany, :mun, "tyr"), sm(:germany, :boh, :mun, :tyr), mv(:italy, :ven, "tyr")])
    expect(results(result, 4)).to eq(%i[bounced succeeded given bounced])
    expect(result.position.standoffs).to eq([])
    expect(after(result)[:tyr]).to eq(:germany)
  end

  it "bounces a move of equal strength against a holder, which is no standoff (AC-7.3)" do
    result = run([u(:austria, :army, "vie"), u(:italy, :army, "tyr")], [mv(:austria, :vie, "tyr")])
    expect(results(result, 1)).to eq([:bounced])
    expect(result.position.standoffs).to eq([])
    expect(result.position.dislodged_units).to eq([])
  end

  it "lets a move follow the winner of a head-to-head battle into the province it left (AC-7.3)" do
    units = [u(:germany, :army, "ber"), u(:germany, :fleet, "kie"), u(:germany, :army, "sil"), u(:russia, :army, "pru")]
    result = run(units, [mv(:germany, :ber, "pru"), mv(:germany, :kie, "ber"), sm(:germany, :sil, :ber, :pru), mv(:russia, :pru, "ber")])
    expect(results(result, 4)).to eq(%i[succeeded succeeded given bounced])
    expect(result.position.standoffs).to eq([])
  end

  it "marks a province a standoff when its holder left in the same turn (AC-7.4)" do
    units = [u(:austria, :army, "vie"), u(:italy, :army, "ven"), u(:germany, :army, "mun")]
    result = run(units, [mv(:austria, :vie, "tyr"), mv(:italy, :ven, "tyr"), mv(:germany, :mun, "boh")])
    expect(results(result, 3)).to eq(%i[bounced bounced succeeded])
    expect(result.position.standoffs).to eq([:tyr])
    units = [u(:austria, :army, "vie"), u(:italy, :army, "ven"), u(:germany, :army, "tyr")]
    left = run(units, [mv(:austria, :vie, "tyr"), mv(:italy, :ven, "tyr"), mv(:germany, :tyr, "boh")])
    expect(results(left, 3)).to eq(%i[bounced bounced succeeded])
    expect(left.position.standoffs).to eq([:tyr])
  end

  it "is no standoff when a third, stronger move enters (AC-7.4)" do
    units = [u(:austria, :army, "vie"), u(:italy, :army, "ven"), u(:germany, :army, "mun"), u(:germany, :army, "boh")]
    result = run(units, [mv(:austria, :vie, "tyr"), mv(:italy, :ven, "tyr"), mv(:germany, :mun, "tyr"), sm(:germany, :boh, :mun, :tyr)])
    expect(result.position.standoffs).to eq([])
    expect(after(result)[:tyr]).to eq(:germany)
  end

  it "puts every unit in place: a failed move stays, a successful one is alone in its province (AC-7.5)" do
    units = [u(:austria, :army, "vie"), u(:italy, :army, "ven"), u(:germany, :army, "mun"), u(:france, :army, "par")]
    result = run(units, [mv(:austria, :vie, "tyr"), mv(:italy, :ven, "tyr"), mv(:germany, :mun, "boh"), mv(:france, :par, "bur")])
    expect(after(result)).to eq(vie: :austria, ven: :italy, boh: :germany, bur: :france)
    expect(result.position.units.map { _1.location.province }.uniq.size).to eq(4)
  end
end
```

Supports (Story 8):

```ruby
# frozen_string_literal: true

require "trucebearer/adjudicator"
require_relative "../../support/adjudicating"

# Supports: strength, matching and cuts (Story 8).
RSpec.describe "TA.adjudicate: supports" do
  let(:vie_boh_tyr) { [u(:austria, :army, "vie"), u(:germany, :army, "boh"), u(:germany, :army, "tyr")] }

  it "gives a support to hold and adds one to the hold strength (AC-8.1)" do
    units = [u(:austria, :army, "vie"), u(:austria, :army, "gal"), u(:germany, :army, "boh"), u(:germany, :army, "tyr")]
    result = run(units, [sh(:austria, :gal, :vie), mv(:germany, :boh, "vie"), sm(:germany, :tyr, :boh, :vie)])
    expect(results(result, 3)).to eq(%i[given bounced given])
    expect(dislodged(result)).to eq({})
  end

  it "gives a support to move and adds one to the move's strength (AC-8.1)" do
    result = run(vie_boh_tyr, [mv(:germany, :boh, "vie"), sm(:germany, :tyr, :boh, :vie)])
    expect(results(result, 2)).to eq(%i[succeeded given])
    expect(dislodged(result)).to eq(vie: :boh)
  end

  it "is unmatched when the supported unit moves and the support is for a hold (AC-8.2)" do
    units = [u(:germany, :army, "boh"), u(:germany, :army, "tyr")]
    result = run(units, [mv(:germany, :boh, "vie"), sh(:germany, :tyr, :boh)])
    expect(results(result, 2)).to eq(%i[succeeded unmatched])
  end

  it "is unmatched when the supported move has another origin or destination, or the unit holds (AC-8.2)" do
    units = [u(:germany, :army, "boh"), u(:germany, :army, "tyr"), u(:austria, :army, "gal")]
    expect(results(run(units, [mv(:germany, :boh, "vie"), sm(:germany, :tyr, :boh, :mun)]), 2)).to eq(%i[succeeded unmatched])
    expect(results(run(units, [mv(:germany, :boh, "vie"), sm(:germany, :tyr, :gal, :vie)]), 2)).to eq(%i[succeeded unmatched])
    expect(results(run(units, [hd(:germany, :boh), sm(:germany, :tyr, :boh, :vie)]), 2)).to eq(%i[held unmatched])
  end

  it "is unmatched for a unit that holds because its own order was void, and matched for a hold support (AC-8.2)" do
    units = [u(:germany, :army, "boh"), u(:germany, :army, "tyr"), u(:austria, :army, "vie")]
    result = run(units, [mv(:germany, :boh, "bur"), sm(:germany, :tyr, :boh, :bur), sh(:austria, :vie, :boh)])
    expect(results(result, 3)).to eq(%i[void void given])
    expect(results(run(units, [mv(:germany, :boh, "mun"), sm(:germany, :tyr, :boh, :mun)]), 2)).to eq(%i[succeeded given])
  end

  it "ignores the coast when matching, and never calls an unmatched support cut (AC-8.2)" do
    matched = run([u(:france, :fleet, "mao"), u(:france, :fleet, "por")],
                  [mv(:france, :mao, "spa/nc"), sm(:france, :por, :mao, :spa)])
    expect(results(matched, 2)).to eq(%i[succeeded given])
    units = [u(:france, :fleet, "mao"), u(:france, :fleet, "por"), u(:italy, :fleet, "spa/sc")]
    unmatched = run(units, [hd(:france, :mao), sm(:france, :por, :mao, :spa), mv(:italy, :spa, "por")])
    expect(results(unmatched, 3)).to eq(%i[held unmatched bounced])
  end

  it "is cut by a move into the supporter's province from another power, not from the same power (AC-8.3)" do
    units = vie_boh_tyr + [u(:italy, :army, "ven"), u(:germany, :army, "mun")]
    cut = run(units, [mv(:germany, :boh, "vie"), sm(:germany, :tyr, :boh, :vie), mv(:italy, :ven, "tyr")])
    expect(results(cut, 3)).to eq(%i[bounced cut bounced])
    own = run(units, [mv(:germany, :boh, "vie"), sm(:germany, :tyr, :boh, :vie), mv(:germany, :mun, "tyr")])
    expect(results(own, 3)).to eq(%i[succeeded given bounced])
  end

  it "is not cut by the unit it attacks, unless that unit dislodges it (AC-8.3, AC-8.4)" do
    units = [u(:austria, :army, "vie"), u(:germany, :army, "boh"), u(:germany, :army, "tyr"), u(:italy, :army, "ven")]
    attacked = run(units, [mv(:austria, :vie, "boh"), mv(:germany, :boh, "vie"), sm(:germany, :tyr, :boh, :vie)])
    expect(results(attacked, 3)).to eq(%i[bounced succeeded given])
    # Here the supporter is attacked from the supported move's destination and dislodged: cut.
    dislodging = [u(:russia, :fleet, "con"), u(:russia, :fleet, "bla"), u(:turkey, :fleet, "ank"), u(:turkey, :army, "smy"),
                  u(:turkey, :army, "arm")]
    result = run(dislodging, [sm(:russia, :con, :bla, :ank), mv(:russia, :bla, "ank"), mv(:turkey, :ank, "con"),
                              sm(:turkey, :smy, :ank, :con), mv(:turkey, :arm, "ank")])
    expect(results(result, 5)).to eq(%i[cut bounced succeeded given bounced])
    expect(dislodged(result)).to eq(con: :ank)
    kept = run(dislodging.first(4), [sm(:russia, :con, :bla, :ank), mv(:russia, :bla, "ank"), mv(:turkey, :ank, "con")])
    expect(results(kept, 3)).to eq(%i[given succeeded bounced])
  end

  it "is not cut by an attack that has no route, a move that needs a convoy and has none (AC-8.3)" do
    units = [u(:england, :army, "lon"), u(:england, :fleet, "nth"), u(:germany, :army, "bel"), u(:germany, :army, "hol")]
    result = run(units, [mv(:england, :lon, "bel"), sh(:germany, :bel, :hol)])
    expect(results(result, 2)).to eq(%i[no_route given])
    expect(dislodged(result)).to eq({})
  end

  it "counts a support from another power for the supported unit, and not toward dislodging its own (AC-8.5)" do
    foreign = run([u(:austria, :army, "vie"), u(:germany, :army, "boh"), u(:italy, :army, "tyr")],
                  [mv(:germany, :boh, "vie"), sm(:italy, :tyr, :boh, :vie)])
    expect(results(foreign, 2)).to eq(%i[succeeded given])
    own_power = run([u(:austria, :army, "vie"), u(:austria, :army, "gal"), u(:germany, :army, "boh")],
                    [mv(:germany, :boh, "vie"), sm(:austria, :gal, :boh, :vie)])
    expect(results(own_power, 2)).to eq(%i[bounced given])
    expect(dislodged(own_power)).to eq({})
  end

  it "keeps the support's result the same whether its move succeeds or bounces (AC-8.6)" do
    wins = run(vie_boh_tyr, [mv(:germany, :boh, "vie"), sm(:germany, :tyr, :boh, :vie)])
    loses = run(vie_boh_tyr + [u(:austria, :army, "gal")], [mv(:germany, :boh, "vie"), sm(:germany, :tyr, :boh, :vie), sh(:austria, :gal, :vie)])
    expect([wins.outcomes[1].result, loses.outcomes[1].result]).to eq(%i[given given])
    expect([wins.outcomes[0].result, loses.outcomes[0].result]).to eq(%i[succeeded bounced])
  end

  it "can support an unmatched support or an unmatched convoy (AC-8.7)" do
    units = [u(:germany, :army, "ber"), u(:germany, :fleet, "kie"), u(:russia, :fleet, "bal"), u(:russia, :army, "pru")]
    result = run(units, [sh(:germany, :ber, :pru), sh(:germany, :kie, :ber), sm(:russia, :bal, :pru, :ber), mv(:russia, :pru, "ber")])
    expect(results(result, 4)).to eq(%i[unmatched given given bounced])
  end

  it "voids a support for a move that can't be made, and the move too (AC-8.7)" do
    units = [u(:germany, :fleet, "kie"), u(:germany, :army, "bur"), u(:russia, :army, "mun"), u(:russia, :army, "ber")]
    result = run(units, [mv(:germany, :kie, "mun"), sm(:germany, :bur, :kie, :mun), mv(:russia, :mun, "kie"), sm(:russia, :ber, :mun, :kie)])
    expect(results(result, 4)).to eq(%i[void void succeeded given])
    expect(result.outcomes.drop(4).map { [_1.order.at, _1.dislodged] }).to eq([[:bur, false], [:kie, true]])
  end
end
```

Dislodgement, head-to-head battles, beleaguered garrisons and circles (Stories 9 and 10):

```ruby
# frozen_string_literal: true

require "trucebearer/adjudicator"
require_relative "../../support/adjudicating"

# Dislodgement and the next position (Story 9); head-to-head battles, beleaguered
# garrisons and circular movement (Story 10). The DATC cases of these (6.C, 6.D, 6.E) are
# fixtures, run in spec/datc/datc_adjudicate_spec.rb.
RSpec.describe "TA.adjudicate: dislodgement, battles and circles" do
  describe "the dislodged units" do
    it "records the unit, its attacker's province and no convoy, and flags only the order it followed (AC-9.2)" do
      units = [u(:austria, :army, "vie"), u(:austria, :army, "gal"), u(:germany, :army, "boh"), u(:germany, :army, "tyr")]
      result = run(units, [sm(:austria, :gal, :vie, :bud), mv(:germany, :boh, "vie"), sm(:germany, :tyr, :boh, :vie)])
      expect(result.position.dislodged_units).to eq(
        [TA::DislodgedUnit.new(unit: u(:austria, :army, "vie"), attacker_from: :boh, by_convoy: false)]
      )
      expect(after(result)).to eq(gal: :austria, vie: :germany, tyr: :germany)
      expect(result.outcomes.select(&:dislodged).map { _1.order.at }).to eq([:vie])
      expect(result.outcomes.last.order).to eq(hd(:austria, :vie))
      expect(result.outcomes.last.dislodged).to be(true)
    end

    it "flags a failed move, a support and a convoy that were dislodged, on the order each followed (AC-9.2)" do
      units = [u(:germany, :army, "ber"), u(:germany, :fleet, "kie"), u(:russia, :fleet, "bal"), u(:russia, :army, "pru"),
               u(:russia, :army, "sil"), u(:germany, :army, "mun")]
      result = run(units, [mv(:germany, :ber, "pru"), sh(:germany, :kie, :ber), sh(:russia, :bal, :pru),
                           mv(:russia, :pru, "ber"), mv(:russia, :sil, "mun"), sm(:germany, :mun, :ber, :pru)])
      flags = result.outcomes.to_h { [_1.order.at, _1.dislodged] }
      expect(flags.values.count(true)).to eq(result.position.dislodged_units.size)
      expect(result.position.dislodged_units.map { _1.unit.location.province }).to all(satisfy { |province| flags[province] })
    end

    it "keeps a dislodged fleet's coast, and names the attacker's province with no coast (AC-9.3)" do
      units = [u(:france, :fleet, "spa/nc"), u(:italy, :fleet, "gol"), u(:italy, :fleet, "wes")]
      result = run(units, [mv(:italy, :gol, "spa/sc"), sm(:italy, :wes, :gol, :spa)])
      entry = result.position.dislodged_units.first
      expect(entry.unit.location).to eq(L.new(province: :spa, coast: :nc))
      expect(entry.attacker_from).to eq(:gol)
      expect(result.position.units.find { _1.location.province == :spa }.location).to eq(L.new(province: :spa, coast: :sc))
    end

    it "dislodges an army next to a split-coast province (AC-9.3)" do
      units = [u(:france, :army, "mar"), u(:germany, :army, "gas"), u(:germany, :army, "bur")]
      result = run(units, [mv(:germany, :gas, "mar"), sm(:germany, :bur, :gas, :mar)])
      expect(dislodged(result)).to eq(mar: :gas)
      expect(result.position.dislodged_units.first.by_convoy).to be(false)
    end

    it "keeps every unit once, and the season, year, map and ownership (AC-9.4)" do
      start = TA::Map.classic.starting_position
      orders = [mv(:germany, :kie, "hol"), mv(:england, :lon, "nth"), mv(:russia, :war, "gal"), mv(:austria, :vie, "gal")]
      result = TA.adjudicate(start, orders)
      position = result.position
      expect([position.season, position.year, position.map, position.phase]).to eq([:spring, 1901, "classic", :retreat])
      expect(position.ownership).to eq(start.ownership)
      expect(position.units.size + position.dislodged_units.size).to eq(start.units.size)
    end
  end

  describe "units that can't be dislodged by their own power (AC-9.6)" do
    it "gives a move against a unit of the mover's own power no strength" do
      units = [u(:germany, :army, "ber"), u(:germany, :fleet, "kie"), u(:germany, :army, "mun")]
      result = run(units, [hd(:germany, :ber), mv(:germany, :kie, "ber"), sm(:germany, :mun, :kie, :ber)])
      expect(results(result, 3)).to eq(%i[held bounced given])
      expect(dislodged(result)).to eq({})
    end
  end

  describe "head-to-head battles" do
    let(:vie_tyr) { [u(:austria, :army, "vie"), u(:austria, :army, "boh"), u(:italy, :army, "tyr")] }

    it "lets the stronger unit win and dislodges the other (AC-10.1)" do
      result = run(vie_tyr, [mv(:austria, :vie, "tyr"), sm(:austria, :boh, :vie, :tyr), mv(:italy, :tyr, "vie")])
      expect(results(result, 3)).to eq(%i[succeeded given bounced])
      expect(dislodged(result)).to eq(tyr: :vie)
      expect(after(result)).to eq(tyr: :austria, boh: :austria)
    end

    it "bounces both when they are equal (AC-10.1)" do
      result = run([u(:austria, :army, "vie"), u(:italy, :army, "tyr")], [mv(:austria, :vie, "tyr"), mv(:italy, :tyr, "vie")])
      expect(results(result, 2)).to eq(%i[bounced bounced])
      expect(after(result)).to eq(vie: :austria, tyr: :italy)
    end

    it "bounces both when they belong to one power, even with support (AC-10.1)" do
      units = [u(:austria, :army, "vie"), u(:austria, :army, "tyr"), u(:austria, :army, "boh")]
      result = run(units, [mv(:austria, :vie, "tyr"), mv(:austria, :tyr, "vie"), sm(:austria, :boh, :vie, :tyr)])
      expect(results(result, 3)).to eq(%i[bounced bounced given])
    end
  end

  describe "a unit attacked from several sides" do
    it "fails every attack of equal strength and dislodges nobody (AC-10.2)" do
      units = [u(:germany, :army, "tyr"), u(:austria, :army, "vie"), u(:germany, :army, "mun"), u(:italy, :army, "ven")]
      result = run(units, [hd(:germany, :tyr), mv(:austria, :vie, "tyr"), mv(:germany, :mun, "tyr"), mv(:italy, :ven, "tyr")])
      expect(results(result, 4)).to eq(%i[held bounced bounced bounced])
      expect(dislodged(result)).to eq({})
    end
  end

  describe "circular movement" do
    # Armies that can step around: tri, ser, bud, vie (four), and with gal for five.
    def circle(power, *provinces)
      provinces.each_cons(2).map { |from, to| mv(power, from, to.to_s) } << mv(power, provinces.last, provinces.first.to_s)
    end

    def circle_units(power, *provinces) = provinces.map { |province| u(power, :army, province.to_s) }

    it "moves a circle of three, four and five units, with no paradox (AC-10.3)" do
      [%i[ank con smy], %i[tri ser bud vie], %i[tri ser bud gal vie]].each do |provinces|
        result = run(circle_units(:austria, *provinces), circle(:austria, *provinces))
        expect(results(result, provinces.size)).to eq([:succeeded] * provinces.size)
        expect(result.paradox).to be(false)
        expect(after(result).keys).to match_array(provinces)
      end
    end

    it "moves two circles that share no province, of different powers (AC-10.3)" do
      units = circle_units(:austria, :tri, :ser, :bud, :vie) + circle_units(:turkey, :ank, :con, :smy)
      orders = circle(:austria, :tri, :ser, :bud, :vie) + circle(:turkey, :ank, :con, :smy)
      result = run(units, orders)
      expect(results(result, 7)).to eq([:succeeded] * 7)
      expect(result.paradox).to be(false)
    end

    it "moves a circle that one supported move runs through, and one of another power (AC-10.3)" do
      units = [u(:turkey, :fleet, "ank"), u(:turkey, :army, "smy"), u(:turkey, :army, "bul"), u(:italy, :army, "con")]
      orders = [mv(:turkey, :ank, "con"), mv(:turkey, :smy, "ank"), sm(:turkey, :bul, :ank, :con), mv(:italy, :con, "smy")]
      result = run(units, orders)
      expect(results(result, 4)).to eq(%i[succeeded succeeded given succeeded])
      expect(result.paradox).to be(false)
    end

    it "holds the whole circle when a fourth unit bounces one of its moves (AC-10.3)" do
      units = circle_units(:austria, :tri, :ser, :bud, :vie) + [u(:italy, :army, "ven")]
      result = run(units, circle(:austria, :tri, :ser, :bud, :vie) + [mv(:italy, :ven, "tri")])
      expect(results(result, 5)).to eq([:bounced] * 5)
      expect(after(result).keys).to match_array(%i[tri ser bud vie ven])
      expect(result.paradox).to be(false)
    end
  end
end
```

The temporary convoy behavior (Story 13). The header says it is temporary and that #15 replaces the file:

```ruby
# frozen_string_literal: true

require "trucebearer/adjudicator"
require_relative "../../support/adjudicating"

# TEMPORARY. Convoy routing arrives with #15, before 0.2.0 ships. Until then convoys never
# work (docs/specs/014-adjudicate-movement/spec.md, "Convoys in this release", AC-13.1): a
# move that goes by convoy is :no_route, and a legal Convoy order is :unmatched. This is the
# only file that pins that behavior. #15 replaces it, and the two convoy examples that are
# pending in adjudicate_examples_spec.rb.
RSpec.describe "TA.adjudicate: convoys in this release (temporary, replaced by #15)" do
  let(:england) { [u(:england, :army, "lon"), u(:england, :fleet, "nth")] }

  it "fails a move to a province an army can't reach by land, whatever fleet is at sea" do
    result = run(england, [mv(:england, :lon, "nwy")])
    expect(results(result, 1)).to eq([:no_route])
    expect(after(result)).to eq(lon: :england, nth: :england)
  end

  it "fails a move via convoy" do
    expect(results(run(england, [mvc(:england, :lon, :yor)]), 1)).to eq([:no_route])
  end

  it "fails a plain move to a neighbor when a fleet of its own power gives a matching convoy order" do
    result = run(england, [mv(:england, :lon, "yor"), cv(:england, :nth, :lon, :yor)])
    expect(results(result, 2)).to eq(%i[no_route unmatched])
  end

  it "sends that move by land when the convoy order comes from another power's fleet" do
    units = [u(:england, :army, "lon"), u(:germany, :fleet, "nth")]
    result = run(units, [mv(:england, :lon, "yor"), cv(:germany, :nth, :lon, :yor)])
    expect(results(result, 2)).to eq(%i[succeeded unmatched])
  end

  it "gives a legal convoy order :unmatched, and an illegal one :void" do
    expect(results(run(england, [cv(:england, :nth, :lon, :nwy)]), 1)).to eq([:unmatched])
    expect(results(run(england, [cv(:england, :lon, :lon, :nwy)]), 1)).to eq([:void])
  end

  it "treats a failed move like a unit that stays: it cuts nothing, and can be dislodged" do
    units = england + [u(:germany, :army, "wal"), u(:germany, :army, "yor")]
    result = run(units, [mv(:england, :lon, "nwy"), mv(:germany, :wal, "lon"), sm(:germany, :yor, :wal, :lon)])
    expect(results(result, 3)).to eq(%i[no_route succeeded given])
    expect(result.outcomes.first.dislodged).to be(true)
    expect(dislodged(result)).to eq(lon: :wal)
    expect(result.position.dislodged_units.first.by_convoy).to be(false)
  end

  it "bounces nothing: a failed move into a province gives way to another move into it" do
    units = england + [u(:russia, :army, "swe")]
    result = run(units, [mv(:england, :lon, "nwy"), mv(:russia, :swe, "nwy")])
    expect(results(result, 2)).to eq(%i[no_route succeeded])
  end

  it "holds with strength one: an unsupported attack on it bounces" do
    units = england + [u(:germany, :army, "wal")]
    result = run(units, [mv(:england, :lon, "nwy"), mv(:germany, :wal, "lon")])
    expect(results(result, 2)).to eq(%i[no_route bounced])
    expect(dislodged(result)).to eq({})
  end

  it "cuts no support even when a convoy order was given for it" do
    units = england + [u(:germany, :army, "yor"), u(:germany, :army, "wal")]
    result = run(units, [mv(:england, :lon, "yor"), cv(:england, :nth, :lon, :yor), sh(:germany, :yor, :wal)])
    expect(results(result, 3)).to eq(%i[no_route unmatched given])
  end

  it "never sets the paradox flag, and raises nothing" do
    pos = TA::Position.new(map: "classic", season: :spring, year: 1901, phase: :movement, ownership: {},
                           dislodged_units: [], standoffs: [],
                           units: [u(:england, :fleet, "lon"), u(:england, :fleet, "wal"), u(:france, :army, "bre"), u(:france, :fleet, "eng")])
    result = TA.adjudicate(pos, [mv(:england, :wal, "eng"), sm(:england, :lon, :wal, :eng), mv(:france, :bre, "lon"),
                                 cv(:france, :eng, :bre, :lon)])
    expect(result.paradox).to be(false)
    expect(result.position.phase).to eq(:retreat)
  end
end
```

- [ ] **Step 3: replace the examples spec with the full one** (AC-1.1 to AC-1.3, with the first example unchanged, the other examples of the three sections, and the two convoy examples pending). Phase 8 adds the impossible-object examples to it.

```ruby
# frozen_string_literal: true

require "json"
require "trucebearer/adjudicator"
require_relative "../../support/board"

# Every Ruby example under `## Adjudicating a movement phase`, `### TA::Outcome` and
# `### TA::Adjudication` of docs/interface.md, with the same expected values (AC-1.1 to
# AC-1.3). The first example is the first spec of the feature. The two examples that need
# a working convoy are pending until #15.
RSpec.describe "TA.adjudicate: the examples of docs/interface.md" do
  let(:start) { TA::Map.classic.starting_position }

  # The position `ln` of docs/interface.md `## Legal orders`.
  let(:ln) do
    TA::Position.new(map: "classic", season: :spring, year: 1901, phase: :movement, ownership: {},
                     dislodged_units: [], standoffs: [],
                     units: [TA::Unit.new(power: :england, type: :army, location: L.new(province: :lon)),
                             TA::Unit.new(power: :england, type: :fleet, location: L.new(province: :nth))])
  end

  it "adjudicates England's London to the North Sea and Germany's Kiel to Holland (AC-1.1)" do
    orders = [O::Move.new(power: :england, at: :lon, destination: L.new(province: :nth)),
              O::Move.new(power: :germany, at: :kie, destination: L.new(province: :hol))]
    result = TA.adjudicate(start, orders)
    expect(result.outcomes.first(2).map(&:result)).to eq(%i[succeeded succeeded])
    implied = result.outcomes.reject(&:submitted)
    expect(implied.size).to eq(20)
    expect(implied.map(&:order)).to all(be_a(O::Hold))
    expect(implied.map(&:result)).to all(eq(:held))
    expect(result.paradox).to be(false)
    expect(result.position.phase).to eq(:retreat)
    expect(result.position.dislodged_units).to eq([])
    expect(result.position.standoffs).to eq([])
    expect(result.outcomes.drop(2).first(3).map { _1.order.at }).to eq(%i[ank ber bre])
    provinces = result.position.units.map { _1.location.province }
    expect(provinces).to include(:nth, :hol)
    expect(provinces).not_to include(:lon, :kie)
    expect(result.position.ownership).to eq(start.ownership)
  end

  it "bounces two armies that move into Galicia and leaves it a standoff" do
    bounce = [O::Move.new(power: :russia, at: :war, destination: L.new(province: :gal)),
              O::Move.new(power: :austria, at: :vie, destination: L.new(province: :gal))]
    result = TA.adjudicate(start, bounce)
    expect(result.outcomes.first(2).map(&:result)).to eq(%i[bounced bounced])
    expect(result.position.standoffs).to eq([:gal])
  end

  it "raises for two orders of one power for one province, and for a retreat position" do
    expect { TA.adjudicate(start, [O::Hold.new(power: :england, at: :lon), O::Hold.new(power: :england, at: :lon)]) }
      .to raise_error(TA::InvalidInput)
    retreat = TA.adjudicate(start, []).position
    expect { TA.adjudicate(retreat, []) }.to raise_error(TA::InvalidInput)
  end

  it "voids an order from a power that doesn't own the unit, and holds the unit" do
    result = TA.adjudicate(start, [O::Hold.new(power: :france, at: :lon)])
    expect(result.outcomes.first.result).to eq(:void)
    expect(result.outcomes.find { _1.order.at == :lon && !_1.submitted }.result).to eq(:held)
  end

  it "sends an army by land when no convoy is ordered (the by_land example)" do
    by_land = TA.adjudicate(ln, [O::Move.new(power: :england, at: :lon, destination: L.new(province: :yor))])
    expect(by_land.outcomes.map(&:result)).to eq(%i[succeeded held])
  end

  it "dislodges a holding army with a supported move (the Vienna example)" do
    vienna = TA::Position.new(map: "classic", season: :spring, year: 1901, phase: :movement, ownership: {},
                              dislodged_units: [], standoffs: [],
                              units: [TA::Unit.new(power: :austria, type: :army, location: L.new(province: :vie)),
                                      TA::Unit.new(power: :germany, type: :army, location: L.new(province: :boh)),
                                      TA::Unit.new(power: :germany, type: :army, location: L.new(province: :tyr))])
    result = TA.adjudicate(vienna, [O::Hold.new(power: :austria, at: :vie),
                                    O::Move.new(power: :germany, at: :boh, destination: L.new(province: :vie)),
                                    O::SupportMove.new(power: :germany, at: :tyr, from: :boh, to: :vie)])
    expect([result.outcomes.first.result, result.outcomes.first.dislodged]).to eq([:held, true])
    expect(result.position.dislodged_units).to eq(
      [TA::DislodgedUnit.new(unit: TA::Unit.new(power: :austria, type: :army, location: L.new(province: :vie)),
                             attacker_from: :boh, by_convoy: false)]
    )
    expect(result.position.units.find { _1.location.province == :vie }.power).to eq(:germany)
  end

  it "gives the Outcome example's hash form" do
    outcome = TA::Outcome.new(order: O::Hold.new(power: :england, at: :lon), result: :held, submitted: false, dislodged: false)
    expect(outcome.to_h).to eq(
      "order" => { "format" => 1, "type" => "hold", "power" => "england", "at" => "lon" },
      "result" => "held", "submitted" => false, "dislodged" => false
    )
  end

  it "gives the Adjudication example's hash form" do
    pos = TA::Position.new(map: "classic", season: :spring, year: 1901, phase: :movement,
                           units: [TA::Unit.new(power: :england, type: :fleet, location: L.new(province: :lon))],
                           ownership: { lon: :england }, dislodged_units: [], standoffs: [])
    adjudication = TA.adjudicate(pos, [O::Hold.new(power: :england, at: :lon)])
    expect(adjudication.to_h).to eq(
      "format" => 1,
      "outcomes" => [{ "order" => { "format" => 1, "type" => "hold", "power" => "england", "at" => "lon" },
                       "result" => "held", "submitted" => true, "dislodged" => false }],
      "paradox" => false,
      "position" => { "format" => 1, "map" => "classic", "season" => "spring", "year" => 1901, "phase" => "retreat",
                      "units" => [{ "power" => "england", "type" => "fleet", "location" => { "province" => "lon", "coast" => nil } }],
                      "ownership" => { "lon" => "england" }, "dislodged_units" => [], "standoffs" => [] }
    )
    expect(TA::Adjudication.from_h(JSON.parse(JSON.generate(adjudication.to_h)))).to eq(adjudication)
  end

  # AC-1.3: needs a working convoy, which arrives with #15. These run and fail as expected;
  # when #15 makes one pass, RSpec flags it until the `pending` is removed.
  it "sends an army by sea when a fleet convoys it (the by_sea example)" do
    pending "convoys: #15"
    by_sea = TA.adjudicate(ln, [O::Move.new(power: :england, at: :lon, destination: L.new(province: :yor)),
                                O::Convoy.new(power: :england, at: :nth, from: :lon, to: :yor)])
    expect(by_sea.outcomes.map(&:result)).to eq(%i[succeeded given])
  end

  it "flags the convoy paradox of the paradox_pos example" do
    pending "convoys: #15"
    paradox_pos = TA::Position.new(map: "classic", season: :spring, year: 1901, phase: :movement, ownership: {},
                                   dislodged_units: [], standoffs: [],
                                   units: [TA::Unit.new(power: :england, type: :fleet, location: L.new(province: :lon)),
                                           TA::Unit.new(power: :england, type: :fleet, location: L.new(province: :wal)),
                                           TA::Unit.new(power: :france, type: :army, location: L.new(province: :bre)),
                                           TA::Unit.new(power: :france, type: :fleet, location: L.new(province: :eng))])
    result = TA.adjudicate(paradox_pos, [
      O::Move.new(power: :england, at: :wal, destination: L.new(province: :eng)),
      O::SupportMove.new(power: :england, at: :lon, from: :wal, to: :eng),
      O::Move.new(power: :france, at: :bre, destination: L.new(province: :lon)),
      O::Convoy.new(power: :france, at: :eng, from: :bre, to: :lon)
    ])
    expect(result.paradox).to be(true)
  end
end
```

- [ ] **Step 4: finish #12's public-surface spec.** Phases 2 and 3 added the two constants; now `adjudicate` joins the public methods and the two internal modules are checked private. The block, as it ends up:

```ruby
  describe "the public surface (AC-7.5)" do
    # #14 added adjudicate, Outcome and Adjudication (docs/specs/014-adjudicate-movement/spec.md).
    it "adds only legal_orders, and keeps the generator private" do
      expect(TA.singleton_methods(false)).to contain_exactly(:check, :legal_orders, :adjudicate)
      expect(TA.constants).to contain_exactly(:Adjudication, :CheckResult, :DislodgedUnit, :InvalidInput, :Location, :Map,
                                              :Order, :Outcome, :Position, :Unit, :VERSION)
      expect { TA::LegalOrders }.to raise_error(NameError, /private constant/)
      expect { TA::Adjudicate }.to raise_error(NameError, /private constant/)
      expect { TA::Resolver }.to raise_error(NameError, /private constant/)
    end
  end
```

- [ ] **Step 5: run them, see them fail.**
  Command: `bundle exec rspec spec/trucebearer/adjudicator/adjudicate_*_spec.rb spec/trucebearer/adjudicator/legal_orders_spec.rb`
  Expected: failures everywhere with `NoMethodError: undefined method 'adjudicate'`, and the surface spec failing on `contain_exactly(:check, :legal_orders, :adjudicate)`.
- [ ] **Step 6: write the resolver.** Read it with the spec's "The conditions" beside it. Every strength is `[least, most]`; `verdict` decides a move only when the range settles it; `circle_pass` is the only place that guesses, and only for a circle of three or more.

```ruby
# frozen_string_literal: true

require "set"

module Trucebearer
  module Adjudicator
    # Internal: decides every move of a movement phase, following the decision-based approach
    # of Kruijswijk's "The Math of Adjudication" (docs/specs/014-adjudicate-movement/spec.md,
    # "How the conditions are resolved"). Not part of docs/interface.md.
    #
    # It is given one followed order for each unit. A move's decision starts unknown. Each
    # strength is kept as a range [least, most] given what is already decided, and a move is
    # decided as soon as its range settles it. When nothing more can be decided, the moves
    # that remain wait on each other in a circle, and circular movement decides them.
    class Resolver
      Entry = Data.define(:order, :unit) do
        def province = unit.location.province
        def power = unit.power
        def move? = order.is_a?(Order::Move) || order.is_a?(Order::MoveViaConvoy)
        def destination = order.is_a?(Order::Move) ? order.destination.province : order.to
      end

      # True when the last-resort rule ran: moves still undecided after the circle rule all
      # failed. It can't run without convoys (docs/specs/014-adjudicate-movement/spec.md, "The
      # paradox flag"), and #15 decides what it becomes.
      attr_reader :paradox

      def initialize(position, orders)
        @position = position
        @entries = position.units.zip(orders).map { |unit, order| Entry.new(order: order, unit: unit) }
        @at = @entries.to_h { |entry| [entry.province, entry] }
        @moves = @entries.select(&:move?)
        @into = @moves.group_by(&:destination)
        @by_convoy = @moves.select { |move| goes_by_convoy?(move) }.to_set
        @state = {}
        @paradox = false
        resolve
      end

      def entry_at(province) = @at.fetch(province)
      def convoy?(move) = @by_convoy.include?(move)
      def succeeded?(move) = @state[move] == true

      # The result symbol of the order a unit follows (docs/interface.md `### Outcomes`).
      def result(entry)
        case entry.order
        when Order::Hold then :held
        when Order::Move, Order::MoveViaConvoy
          return :no_route if convoy?(entry)

          succeeded?(entry) ? :succeeded : :bounced
        when Order::SupportHold, Order::SupportMove then support_result(entry)
        when Order::Convoy then :unmatched
        end
      end

      # The move that dislodged this unit, or nil.
      def attacker_of(entry)
        return nil if entry.move? && succeeded?(entry)

        (@into[entry.province] || []).find { |move| succeeded?(move) }
      end

      def dislodged?(entry) = !attacker_of(entry).nil?

      # The units after the moves, the dislodged units and the standoffs.
      def next_units
        @entries.reject { |entry| dislodged?(entry) }.map do |entry|
          next entry.unit unless entry.move? && succeeded?(entry)

          Unit.new(power: entry.power, type: entry.unit.type, location: destination_location(entry))
        end
      end

      def dislodged_units
        @entries.filter_map do |entry|
          attacker = attacker_of(entry)
          next unless attacker

          DislodgedUnit.new(unit: entry.unit, attacker_from: attacker.province, by_convoy: convoy?(attacker))
        end
      end

      # Provinces left empty after a standoff: at least two moves into the province had a
      # route, had not lost a head-to-head battle, and shared the greatest prevent strength.
      def standoffs
        @into.filter_map do |province, moves|
          next if occupied_after?(province)

          strengths = moves.map { |move| prevent(move).first }.select(&:positive?)
          top = strengths.max
          province if top && strengths.count(top) >= 2
        end.sort
      end

      private

      # ---- what is fixed by the orders alone ----

      # A move goes by convoy when an army can't reach the province by land, when it is a
      # MoveViaConvoy, or when a fleet of its own power gives a matching convoy order that is
      # legal (docs/interface.md `### Convoy routing`). Fleets never do.
      def goes_by_convoy?(move)
        return false unless move.unit.type == :army
        return true if move.order.is_a?(Order::MoveViaConvoy)
        return true unless Reach.reaches?(move.unit, move.destination)

        @entries.any? do |entry|
          entry.order.is_a?(Order::Convoy) && entry.power == move.power &&
            entry.order.from == move.province && entry.order.to == move.destination
        end
      end

      # The one place a later release decides whether a convoy route works (#15).
      def path?(move) = !convoy?(move)

      def destination_location(entry)
        entry.order.is_a?(Order::Move) ? entry.order.destination : Location.new(province: entry.order.to)
      end

      def hold_supporters(province)
        @entries.select do |entry|
          entry.order.is_a?(Order::SupportHold) && entry.order.target == province && !@at[province].move?
        end
      end

      def move_supporters(move)
        @entries.select do |entry|
          entry.order.is_a?(Order::SupportMove) && entry.order.from == move.province && entry.order.to == move.destination
        end
      end

      def matched?(entry)
        case entry.order
        when Order::SupportHold then !@at[entry.order.target].move?
        when Order::SupportMove
          supported = @at[entry.order.from]
          supported.move? && supported.destination == entry.order.to
        end
      end

      def support_result(entry)
        return :unmatched unless matched?(entry)

        cut?(entry) ? :cut : :given
      end

      # ---- the decisions ----

      def resolve
        until @moves.none? { |move| @state[move].nil? }
          next if decide_pass
          next if circle_pass

          last_resort
        end
      end

      # Nothing can be decided and no circle of three or more is left. Without convoys this
      # can't happen (docs/specs/014-adjudicate-movement/spec.md, "The paradox flag"). The moves
      # on the cycles that are stuck fail, or every undecided move if there is no cycle, so the
      # loop always ends.
      def last_resort
        stuck = cycles.flatten
        stuck = @moves.select { |move| @state[move].nil? } if stuck.empty?
        stuck.each { |move| @state[move] = false }
        @paradox = true
      end

      def decide_pass
        progressed = false
        @moves.each do |move|
          next unless @state[move].nil?

          verdict = verdict(move)
          next if verdict.nil?

          @state[move] = verdict
          progressed = true
        end
        progressed
      end

      # Moves that wait on each other in a circle of three or more units, each into the
      # province the next one leaves, all succeed (circular movement).
      def circle_pass
        circles = cycles.select { |circle| circle.size >= 3 }
        circles.each { |circle| circle.each { |move| @state[move] = true } }
        !circles.empty?
      end

      # The cycles that the undecided moves form: each move waits on the undecided move of the
      # unit in its destination, so every move has at most one successor.
      def cycles
        seen = Set.new
        found = []
        @moves.select { |move| @state[move].nil? }.each do |start|
          path = []
          current = start
          while current && !seen.include?(current) && !path.include?(current)
            path << current
            current = waits_on(current)
          end
          found << path[path.index(current)..] if current && path.include?(current)
          path.each { |move| seen << move }
        end
        found
      end

      # The undecided move of the unit that stands in this move's destination, if any.
      def waits_on(move)
        other = @at[move.destination]
        other if other&.move? && @state[other].nil?
      end

      # true: the move surely succeeds; false: it surely fails; nil: not yet known.
      def verdict(move)
        attack = attack(move)
        against = head_to_head?(move) ? defend(@at[move.destination]) : hold(move.destination)
        rivals = (@into[move.destination] - [move]).map { |rival| prevent(rival) }
        return true if attack[0] > against[1] && rivals.all? { |rival| attack[0] > rival[1] }
        return false if attack[1] <= against[0] || rivals.any? { |rival| attack[1] <= rival[0] }

        nil
      end

      def head_to_head?(move)
        other = @at[move.destination]
        other&.move? && other.destination == move.province && !convoy?(move) && !convoy?(other)
      end

      # ---- strengths, each as [least, most] ----

      def hold(province)
        entry = @at[province]
        return [0, 0] unless entry

        if entry.move?
          case @state[entry]
          when true then [0, 0]
          when false then [1, 1]
          else [0, 1]
          end
        else
          range(1, hold_supporters(province))
        end
      end

      def attack(move)
        return [0, 0] unless path?(move)

        other = @at[move.destination]
        return range(1, move_supporters(move)) unless other
        return staying_attack(move, other) if !other.move? || head_to_head?(move)

        case @state[other]
        when true then range(1, move_supporters(move))
        when false then staying_attack(move, other)
        else
          leaving = range(1, move_supporters(move))
          staying = staying_attack(move, other)
          [[leaving[0], staying[0]].min, [leaving[1], staying[1]].max]
        end
      end

      # Against a unit that stays: nothing against its own power, and no help from its owner.
      def staying_attack(move, other)
        return [0, 0] if other.power == move.power

        range(1, move_supporters(move).reject { |support| support.power == other.power })
      end

      def prevent(move)
        return [0, 0] unless path?(move)

        if head_to_head?(move)
          case @state[@at[move.destination]]
          when true then return [0, 0]
          when nil then return [0, range(1, move_supporters(move))[1]]
          end
        end
        range(1, move_supporters(move))
      end

      def defend(move) = range(1, move_supporters(move))

      # base plus the supports that are given, as [least, most].
      def range(base, supporters)
        given = supporters.map { |support| given?(support) }
        [base + given.count(true), base + given.count { |state| !state.equal?(false) }]
      end

      def given?(support)
        cut = cut?(support)
        cut.nil? ? nil : !cut
      end

      # A support is cut by a move into its province from another power with a route, unless
      # the supported move goes to the province that move comes from; and by dislodgement.
      def cut?(support)
        attackers = @into[support.province] || []
        return true if attackers.any? { |move| cuts?(move, support) }

        states = attackers.map { |move| @state[move] }
        return true if states.any?(true)

        states.all?(false) ? false : nil
      end

      def cuts?(move, support)
        return false if !path?(move) || move.power == support.power

        support.order.is_a?(Order::SupportHold) || move.province != support.order.to
      end

      def occupied_after?(province)
        entry = @at[province]
        return true if entry && !(entry.move? && succeeded?(entry))

        (@into[province] || []).any? { |move| succeeded?(move) }
      end
    end
    private_constant :Resolver
  end
end
```

- [ ] **Step 7: write the assembly.** The error order is the spec's: class, then phase, then duplicates. It calls `Check.reason_for` once per order for the outcomes and once to find the legal ones, so a void order is void exactly when `TA.check` says so.

```ruby
# frozen_string_literal: true

module Trucebearer
  module Adjudicator
    # Internal: TA.adjudicate's one public door (docs/interface.md, "Adjudicating a movement
    # phase"). Sorts out which order each unit follows, asks the Resolver, and reads the
    # outcome list and the next position from its decisions.
    module Adjudicate
      module_function

      def call(position, orders)
        Shape.instance_of!(position, Position, "position")
        Shape.array!(orders, "orders").each do |order|
          next if Check::ORDERS.any? { |klass| order.is_a?(klass) }

          raise InvalidInput, "\"orders\" must hold only the six order classes, got #{order.inspect}"
        end
        raise InvalidInput, "adjudication needs a position in the movement phase, got #{position.phase.inspect}" unless position.phase == :movement

        repeated = orders.map { |order| [order.power, order.at] }.tally.find { |_, count| count > 1 }
        raise InvalidInput, "#{repeated.first[0]} gave two orders for the province #{repeated.first[1]}" if repeated

        build(position, orders)
      end

      def build(position, orders)
        legal = orders.reject { |order| Check.reason_for(position, order) }
        by_province = legal.to_h { |order| [order.at, order] }
        followed = position.units.map do |unit|
          by_province[unit.location.province] || Order::Hold.new(power: unit.power, at: unit.location.province)
        end
        resolver = Resolver.new(position, followed)

        Adjudication.new(outcomes: submitted_outcomes(position, orders, resolver) + implied_outcomes(position, by_province, resolver),
                         paradox: resolver.paradox, position: next_position(position, resolver))
      end

      def submitted_outcomes(position, orders, resolver)
        orders.map do |order|
          if Check.reason_for(position, order)
            Outcome.new(order: order, result: :void, submitted: true, dislodged: false)
          else
            entry = resolver.entry_at(order.at)
            Outcome.new(order: order, result: resolver.result(entry), submitted: true, dislodged: resolver.dislodged?(entry))
          end
        end
      end

      def implied_outcomes(position, by_province, resolver)
        position.units.reject { |unit| by_province.key?(unit.location.province) }.map do |unit|
          province = unit.location.province
          Outcome.new(order: Order::Hold.new(power: unit.power, at: province), result: :held, submitted: false,
                      dislodged: resolver.dislodged?(resolver.entry_at(province)))
        end
      end

      def next_position(position, resolver)
        Position.new(map: position.map, season: position.season, year: position.year, phase: :retreat,
                     units: resolver.next_units, ownership: position.ownership,
                     dislodged_units: resolver.dislodged_units, standoffs: resolver.standoffs)
      end
    end
    private_constant :Adjudicate
  end
end
```

- [ ] **Step 8: wire it in.** Phases 2 and 3 added the first two `require_relative` lines; add the last two and `TA.adjudicate`. The file as it ends up:

```ruby
# frozen_string_literal: true

require_relative "adjudicator/version"
require_relative "adjudicator/errors"
require_relative "adjudicator/map"
require_relative "adjudicator/shape"
require_relative "adjudicator/location"
require_relative "adjudicator/unit"
require_relative "adjudicator/dislodged_unit"
require_relative "adjudicator/position"
require_relative "adjudicator/order"
require_relative "adjudicator/check_result"
require_relative "adjudicator/reach"
require_relative "adjudicator/check"
require_relative "adjudicator/legal_orders"
require_relative "adjudicator/outcome"
require_relative "adjudicator/adjudication"
require_relative "adjudicator/resolver"
require_relative "adjudicator/adjudicate"

module Trucebearer
  # The rules engine: checks orders and adjudicates each phase of a game turn.
  module Adjudicator
    # Checks one order against a position and says whether it is legal, with the first
    # reason it is not (docs/interface.md, "Checking an order"). Raises InvalidInput only for
    # an argument that is not a position or an order; a broken rule is a result, never an error.
    def self.check(position, order) = Check.call(position, order)

    # Lists every order that is legal for one unit, in a fixed order (docs/interface.md,
    # "Legal orders"). Empty when the position isn't in a movement phase or the unit isn't on
    # the board. Raises InvalidInput only for an argument of the wrong class.
    def self.legal_orders(position, unit) = LegalOrders.call(position, unit)

    def self.adjudicate(position, orders) = Adjudicate.call(position, orders)
  end
end
```

- [ ] **Step 9: run, see them pass.**
  Command: `bundle exec rspec`
  Expected: 0 failures, 3 pending (the two convoy examples, `convoys: #15`, and the `changelog_spec` example that skips while "Unreleased" is empty, which ends in Phase 8), and the first spec of Phase 1 green. The DATC specs are not changed yet and pass as before.
- [ ] **Step 10: commit** "Adjudicate movement phases without convoys".

---

## Phase 5: The DATC loader and the adjudication runner

**Implements:** Story 11 (the loader and the per-case runner) | **Satisfies:** AC-11.4, and the per-case side of AC-11.1 and AC-9.1
**Files:** modify `spec/support/datc.rb`, `spec/datc/datc_loader_spec.rb`; create `spec/datc/datc_adjudicate_spec.rb`
**Interfaces:** `Datc::Case#after` (a `TA::Position` or `nil`), `Datc::Entry#result`, `#dislodged`, `Datc::ADJUDICATED`, `Datc::CHECKING_ONLY`, `Datc.expected_outcomes(kase)`

No fixture has an `after:` yet, so the runner of this phase has no cases and everything stays green; the file-set examples and the fixtures come together in Phase 6.

- [ ] **Step 1: update the loader spec** (the failing side). It gets the examples of AC-11.1 and AC-11.4 and drops the "ignores the reserved keys" example, which the new format replaces; the example "takes an order with no check when the case has no after" keeps spec 011's AC-8.5 true.

```diff
@@ -15,6 +15,12 @@
 
   def parse(data, name = "6.X.1") = described_class.parse(data, name)
 
+  # `good` with the keys of its one order changed and an `after` that holds its unit.
+  def with_after(data, entry)
+    data.merge("orders" => [(data["orders"][0].reject { |key, _| %w[result dislodged].include?(key) }).merge(entry)],
+               "after" => { "units" => [{ "power" => "england", "type" => "fleet", "at" => "lon" }] })
+  end
+
   it "builds the position and the orders of a case, expanding short locations" do
     data = good.merge("position" => { "units" => [{ "power" => "france", "type" => "fleet", "at" => "spa/nc" }] },
                       "orders" => [{ "order" => { "type" => "move", "power" => "france", "at" => "spa", "destination" => "gol" },
@@ -33,16 +39,44 @@
     expect(kase.departure).to be(true)
   end
 
-  it "ignores the keys reserved for #14, and an order with no check (AC-8.5)" do
-    data = good.merge("after" => { "units" => [] })
-    data["orders"] = [
-      { "order" => { "type" => "hold", "power" => "england", "at" => "lon" }, "check" => { "legal" => true }, "result" => "held" },
-      { "order" => { "type" => "hold", "power" => "england", "at" => "lon" }, "result" => "held" }
-    ]
+  it "takes an order with no check when the case has no \"after\" (AC-8.5)" do
+    data = good.merge("orders" => [{ "order" => { "type" => "hold", "power" => "england", "at" => "lon" } }])
+    expect(parse(data).entries.map(&:expected)).to eq([nil])
+  end
+
+  it "reads each result, each dislodged mark and the position after the moves (AC-11.1)" do
+    data = good.merge(
+      "position" => { "units" => [{ "power" => "austria", "type" => "army", "at" => "vie" },
+                                  { "power" => "germany", "type" => "army", "at" => "boh" },
+                                  { "power" => "germany", "type" => "fleet", "at" => "bal" }] },
+      "orders" => [{ "order" => { "type" => "hold", "power" => "austria", "at" => "vie" }, "check" => { "legal" => true },
+                     "result" => "held", "dislodged" => true },
+                   { "order" => { "type" => "move", "power" => "germany", "at" => "boh", "destination" => "vie" },
+                     "check" => { "legal" => true }, "result" => "succeeded" }],
+      "after" => { "units" => [{ "power" => "germany", "type" => "army", "at" => "vie" },
+                               { "power" => "germany", "type" => "fleet", "at" => "bal" }],
+                   "dislodged" => [{ "power" => "austria", "type" => "army", "at" => "vie", "from" => "boh" }],
+                   "standoffs" => ["gal"] }
+    )
     kase = parse(data)
-    expect(kase.entries.map(&:expected)).to eq([TA::CheckResult.new(legal: true, reasons: []), nil])
+    expect(kase.entries.map { [_1.result, _1.dislodged] }).to eq([[:held, true], [:succeeded, false]])
+    expect(kase.after.phase).to eq(:retreat)
+    expect(kase.after.units.map { _1.location.province }).to eq(%i[bal vie])
+    expect(kase.after.dislodged_units.first.attacker_from).to eq(:boh)
+    expect(kase.after.dislodged_units.first.by_convoy).to be(false)
+    expect(kase.after.standoffs).to eq([:gal])
+    expect(described_class.expected_outcomes(kase).map { [_1.order.at, _1.result, _1.submitted, _1.dislodged] })
+      .to eq([[:vie, :held, true, true], [:boh, :succeeded, true, false], [:bal, :held, false, false]])
   end
 
+  it "works out an implied hold for a unit whose only order is illegal (AC-11.1)" do
+    data = good.merge("orders" => [{ "order" => { "type" => "hold", "power" => "france", "at" => "lon" },
+                                     "check" => { "legal" => false, "reason" => "foreign_unit" }, "result" => "void" }],
+                      "after" => { "units" => [{ "power" => "england", "type" => "fleet", "at" => "lon" }] })
+    outcomes = described_class.expected_outcomes(parse(data))
+    expect(outcomes.map { [_1.order.power, _1.result, _1.submitted] }).to eq([[:france, :void, true], [:england, :held, false]])
+  end
+
   it "refuses a malformed fixture, naming the file (AC-8.6)" do
     bad = {
       "an unknown top-level key" => good.merge("surprise" => 1),
@@ -56,7 +90,23 @@
       "a missing summary" => good.reject { |key, _| key == "summary" },
       "a case id that doesn't match the file" => good.merge("case" => "6.X.2"),
       "an order that can't be built" => good.merge("orders" => [{ "order" => { "type" => "hold", "power" => "england" } }]),
-      "a unit that can't be built" => good.merge("position" => { "units" => [{ "power" => "england", "type" => "fleet", "at" => "xyz" }] })
+      "a unit that can't be built" => good.merge("position" => { "units" => [{ "power" => "england", "type" => "fleet", "at" => "xyz" }] }),
+      "an unknown result" => with_after(good, "result" => "won"),
+      "a result with no after" => good.merge("orders" => [good["orders"][0].merge("result" => "held")]),
+      "a dislodged mark that isn't true or false" => with_after(good, "result" => "held", "dislodged" => "yes"),
+      "an after with an order that has no result" => with_after(good, {}),
+      "an after with an order that has no check" => with_after(good.merge("orders" => [{ "order" => good["orders"][0]["order"], "result" => "held" }]), "result" => "held"),
+      "an unknown key in after" => good.merge("orders" => [good["orders"][0].merge("result" => "held")],
+                                              "after" => { "units" => [], "surprise" => 1 }),
+      "an after with no units" => good.merge("orders" => [good["orders"][0].merge("result" => "held")], "after" => {}),
+      "an after unit that can't be built" => good.merge("orders" => [good["orders"][0].merge("result" => "held")],
+                                                         "after" => { "units" => [{ "power" => "england", "type" => "army", "at" => "nth" }] }),
+      "a dislodged unit with no attacker" => good.merge("orders" => [good["orders"][0].merge("result" => "held")],
+                                                        "after" => { "units" => [], "dislodged" => [{ "power" => "england", "type" => "fleet", "at" => "lon" }] }),
+      "a dislodged unit whose attacker isn't a province" => good.merge("orders" => [good["orders"][0].merge("result" => "held")],
+                                                                       "after" => { "units" => [], "dislodged" => [{ "power" => "england", "type" => "fleet", "at" => "lon", "from" => "xyz" }] }),
+      "an unknown standoff province" => good.merge("orders" => [good["orders"][0].merge("result" => "held")],
+                                                    "after" => { "units" => [{ "power" => "england", "type" => "fleet", "at" => "lon" }], "standoffs" => ["xyz"] })
     }
     bad.each do |label, data|
       expect { parse(data) }.to raise_error(Datc::FormatError, /6\.X\.1/), "expected #{label} to be refused"
```

- [ ] **Step 2: write the adjudication runner** (per-case examples; its two file-set examples are added in Phase 6).

```ruby
# frozen_string_literal: true

require "trucebearer/adjudicator"
require_relative "../support/datc"

# Adjudicates every DATC fixture that has an `after:` (Story 11), and keeps the set of those
# fixtures exactly Datc::ADJUDICATED (AC-11.2). The expectation is read from the fixture
# alone (Datc.expected_outcomes), so it doesn't depend on the engine. See spec 014, "DATC
# cases", for what is encoded, what is left out and why.
RSpec.describe "DATC fixtures: adjudication" do
  cases = Datc.load_all.select(&:after)

  # Every order of every case, adjudicated in any order. A case of up to five orders is tried
  # in every order; the others in a few shuffles (AC-9.1).
  def outcomes_by_order(adjudication)
    adjudication.outcomes.to_h { |outcome| [outcome.order, [outcome.result, outcome.submitted, outcome.dislodged]] }
  end

  cases.each do |kase|
    describe kase.id do
      let(:orders) { kase.entries.map(&:order) }
      let(:adjudication) { TA.adjudicate(kase.position, orders) }
      let(:expected) { Datc.expected_outcomes(kase) }

      kase.entries.each_with_index do |entry, index|
        it "gives order #{index + 1} (#{entry.order.class.name.split("::").last} at #{entry.order.at}) the result #{entry.result}" do
          outcome = adjudication.outcomes[index]
          expect([outcome.order, outcome.result, outcome.dislodged, outcome.submitted])
            .to eq([entry.order, entry.result, entry.dislodged, true])
        end
      end

      it "gives the implied holds, last and sorted by province, and no outcome besides" do
        expect(adjudication.outcomes).to eq(expected)
      end

      it "gives the position after the moves, with no paradox" do
        expect(adjudication.position).to eq(kase.after)
        expect(adjudication.paradox).to be(false)
      end

      it "gives the same results for the orders given in any order (AC-9.1)" do
        baseline = [outcomes_by_order(adjudication), adjudication.position, adjudication.paradox]
        arrangements = orders.size <= 5 ? orders.permutation.to_a : Array.new(6) { |seed| orders.shuffle(random: Random.new(seed)) }
        arrangements.each do |arranged|
          other = TA.adjudicate(kase.position, arranged)
          expect([outcomes_by_order(other), other.position, other.paradox]).to eq(baseline)
        end
      end
    end
  end
end
```

- [ ] **Step 3: run, see the loader spec fail.**
  Command: `bundle exec rspec spec/datc/datc_loader_spec.rb`
  Expected: failures on `Datc.expected_outcomes`, on `kase.after` and on the new refusals (the new keys are not read yet).
- [ ] **Step 4: write the loader support.** The complete diff of `spec/support/datc.rb`. `ADJUDICATED` is the list of 80 cases of the spec's "Encoded" table. The loader refuses what the spec's "Fixture format" lists.

```diff
@@ -9,20 +9,40 @@
 #
 # Short notation, expanded here: a location is "spa/nc" or "par"; an order is the hash
 # form of docs/interface.md without "format", which is added; `destination` is a location.
-# `check:` is {legal: true} or {legal: false, reason: <symbol text>}. `result:` and `after:`
-# are reserved for the adjudication specs (#14) and ignored here.
+# `check:` is {legal: true} or {legal: false, reason: <symbol text>}. `result:` (an outcome
+# symbol text) and `dislodged:` (true when the unit that followed the order was dislodged) go
+# beside each `check:`, and `after:` holds the position after the moves: `units` (each
+# {power, type, at}), `dislodged` (each {power, type, at, from, by_convoy}) and `standoffs`.
+# A case with `after:` is adjudicated (spec/datc/datc_adjudicate_spec.rb). Every order of such
+# a case carries a `check:` and a `result:`, and the implied holds are worked out from the
+# checks, so the expectation doesn't depend on the engine.
 module Datc
   class FormatError < StandardError; end
 
-  Case = Data.define(:id, :departure, :position, :entries)
-  Entry = Data.define(:order, :expected)
+  Case = Data.define(:id, :departure, :position, :entries, :after)
+  Entry = Data.define(:order, :expected, :result, :dislodged)
 
   DIR = File.expand_path("../datc", __dir__)
   TOP_KEYS = %w[case summary departure position orders after].freeze
   TOP_REQUIRED = %w[case summary position orders].freeze
   POSITION_KEYS = %w[units phase].freeze
   UNIT_KEYS = %w[power type at].freeze
-  ENTRY_KEYS = %w[order check result].freeze
+  ENTRY_KEYS = %w[order check result dislodged].freeze
+  AFTER_KEYS = %w[units dislodged standoffs].freeze
+  DISLODGED_KEYS = %w[power type at from by_convoy].freeze
+  RESULTS = %w[void held no_route bounced succeeded unmatched cut given disrupted].freeze
+
+  # The cases that carry `after:`: the ones adjudicated. The checking runner expects these
+  # files and the three that are encoded for checking only (6.B.18, 6.B.19, 6.G.19).
+  ADJUDICATED = (
+    (1..12).map { |n| "6.A.#{n}" } +
+    [1, 2, 3, 4, 5, 6, 7, 8, 10, 11, 12, 13, 15, 16, 17].map { |n| "6.B.#{n}" } +
+    [1, 2, 3, 8, 9].map { |n| "6.C.#{n}" } +
+    ((1..35).to_a - [6, 16]).map { |n| "6.D.#{n}" } +
+    ((1..15).to_a - [11]).map { |n| "6.E.#{n}" } +
+    %w[6.F.1]
+  ).sort.freeze
+  CHECKING_ONLY = %w[6.B.18 6.B.19 6.G.19].freeze
   CHECK_KEYS = %w[legal reason].freeze
   PHASES = %w[movement retreat adjustment].freeze
 
@@ -42,9 +62,11 @@
     fail!(name, "\"case\" is #{data["case"].inspect}, which doesn't match the file name") unless data["case"] == name
     departure = data.fetch("departure", false)
     fail!(name, "\"departure\" must be true or false, got #{departure.inspect}") unless [true, false].include?(departure)
-    Case.new(id: name, departure: departure,
-             position: build_position(data["position"], name),
-             entries: Array(data["orders"]).map { |entry| build_entry(entry, name) })
+    position = build_position(data["position"], name)
+    entries = Array(data["orders"]).map { |entry| build_entry(entry, name) }
+    after = data.key?("after") ? build_after(data["after"], position, entries, name) : nil
+    fail!(name, "an order has a \"result\" but the case has no \"after\"") if after.nil? && entries.any?(&:result)
+    Case.new(id: name, departure: departure, position: position, entries: entries, after: after)
   end
 
   def build_position(data, name)
@@ -69,9 +91,56 @@
   def build_entry(entry, name)
     fail!(name, "an order entry must be a mapping, got #{entry.inspect}") unless entry.is_a?(Hash)
     keys!(entry, ENTRY_KEYS, %w[order], name, "an order entry")
-    Entry.new(order: build_order(entry["order"], name), expected: build_check(entry["check"], name))
+    result = entry["result"]
+    fail!(name, "unknown result #{result.inspect}") unless result.nil? || RESULTS.include?(result)
+    dislodged = entry.fetch("dislodged", false)
+    fail!(name, "\"dislodged\" must be true or false, got #{dislodged.inspect}") unless [true, false].include?(dislodged)
+    Entry.new(order: build_order(entry["order"], name), expected: build_check(entry["check"], name),
+              result: result&.to_sym, dislodged: dislodged)
   end
 
+  # The position after the moves, as the retreat-phase position adjudication gives. A case
+  # with `after:` needs a `check:` and a `result:` on every order.
+  def build_after(data, position, entries, name)
+    fail!(name, "\"after\" must be a mapping") unless data.is_a?(Hash)
+    keys!(data, AFTER_KEYS, %w[units], name, "\"after\"")
+    entries.each do |entry|
+      fail!(name, "an order of a case with \"after\" has no \"result\": #{entry.order.inspect}") if entry.result.nil?
+      fail!(name, "an order of a case with \"after\" has no \"check\": #{entry.order.inspect}") if entry.expected.nil?
+    end
+    units = Array(data["units"]).map { |unit| build_unit(unit, name).to_h }
+    dislodged = Array(data["dislodged"]).map { |entry| build_dislodged(entry, name) }
+    TA::Position.from_h(position.to_h.merge("phase" => "retreat", "units" => units, "dislodged_units" => dislodged,
+                                            "standoffs" => Array(data["standoffs"]).map(&:to_s)))
+  rescue TA::InvalidInput => e
+    fail!(name, "bad \"after\": #{e.message}")
+  end
+
+  def build_dislodged(entry, name)
+    fail!(name, "a dislodged unit must be a mapping, got #{entry.inspect}") unless entry.is_a?(Hash)
+    keys!(entry, DISLODGED_KEYS, %w[power type at from], name, "a dislodged unit")
+    unit = build_unit(entry.slice("power", "type", "at"), name)
+    { "unit" => unit.to_h, "attacker_from" => entry["from"].to_s, "by_convoy" => entry.fetch("by_convoy", false) }
+  end
+
+  # What adjudicating the case must give, worked out from the fixture alone: the submitted
+  # orders as written, then an implied hold for each unit that has no legal order from its
+  # owner, sorted by province.
+  def expected_outcomes(kase)
+    submitted = kase.entries.map do |entry|
+      TA::Outcome.new(order: entry.order, result: entry.result, submitted: true, dislodged: entry.dislodged)
+    end
+    legal = kase.entries.select { |entry| entry.expected.legal }.map(&:order)
+    implied = kase.position.units.reject do |unit|
+      legal.any? { |order| order.at == unit.location.province && order.power == unit.power }
+    end
+    submitted + implied.sort_by { |unit| unit.location.province }.map do |unit|
+      province = unit.location.province
+      TA::Outcome.new(order: TA::Order::Hold.new(power: unit.power, at: province), result: :held, submitted: false,
+                      dislodged: kase.after.dislodged_units.any? { |entry| entry.unit.location.province == province })
+    end
+  end
+
   def build_order(hash, name)
     fail!(name, "an order must be a mapping, got #{hash.inspect}") unless hash.is_a?(Hash)
     fields = hash.dup
```

- [ ] **Step 5: run, see it pass.**
  Command: `bundle exec rspec spec/datc`
  Expected: 0 failures (the runner has no cases yet; the checking runner still expects its 30 files and finds them).
- [ ] **Step 6: commit** "Read results and the position after the moves from the DATC fixtures".

---

## Phase 6: The fixtures

**Implements:** Story 11 | **Satisfies:** AC-11.1, AC-11.2, AC-11.3, AC-11.5, AC-7.6, AC-9.1 (over the fixtures), the DATC side of AC-8.7, AC-9.x and AC-10.x
**Files:** create 53 files and change 27 files in `spec/datc/`; modify `spec/datc/datc_adjudicate_spec.rb`, `spec/datc/datc_check_spec.rb`
**Interfaces:** the fixture format of the spec's "Fixture format"

The fixtures are written from the table below, which is the expectation, derived by hand from the DATC text for each case (positions and orders as the case lists them, results and dislodgements as the case states them, in our symbols). A throwaway script in the scratchpad (kept out of the repository) turns the table into the files; its emitter was checked to reproduce the 27 existing files byte for byte, so the diff of those files is only the `result:`, `dislodged:` and `after:` lines. The script is reproduced after the table so that nothing in this phase is left to guess.

**Reading the table.** `units`: `P:t:place`, power letter (A Austria, E England, F France, G Germany, I Italy, R Russia, T Turkey), `a`rmy or `f`leet, place with `/nc`, `/sc` or `/ec` for a coast. `orders`: `h` hold, `m` move, `sh` support to hold, `sm` support to move, `c` convoy, then the power, the province, and the order's own fields. Each order is followed by its result: `S` succeeded, `B` bounced, `H` held, `G` given, `C` cut, `U` unmatched, `V` void, `N` no_route; `>x` after it means the unit that followed the order was dislodged by the unit that came from `x`. `imp` lists units that were dislodged while following an implied hold (their only order was void). `st` lists standoff provinces. The order of the orders is the order of the file.

- [ ] **Step 1: write the file-set examples first** (they fail until the fixtures exist). Add these two examples to `datc_adjudicate_spec.rb`, right after `cases = Datc.load_all.select(&:after)`:

```ruby
  it "has an after: in exactly the encoded files, and in none of the cases left out (AC-11.2)" do
    expect(Datc::ADJUDICATED.size).to eq(80)
    expect(cases.map(&:id).sort).to eq(Datc::ADJUDICATED)
    without = Datc.load_all.reject(&:after).map(&:id)
    expect(without).to eq(Datc::CHECKING_ONLY)
    left_out = %w[6.B.9 6.B.14 6.C.4 6.C.5 6.C.6 6.C.7 6.D.6 6.D.16 6.E.11 6.F.12 6.G.7]
    expect(cases.map(&:id) & left_out).to eq([])
  end

  it "marks only 6.B.2 and 6.B.12 as departures, and their results are the strict ones (AC-8.4)" do
    expect(cases.select(&:departure).map(&:id).sort).to eq(%w[6.B.12 6.B.2])
    %w[6.B.2 6.B.12].each do |id|
      kase = cases.find { _1.id == id }
      expect(kase.entries.map(&:result)).to eq([:void])
      expect(kase.after.units).to eq(kase.position.units)
    end
  end
```

  and update the checking runner so that it expects all 83 files (its list comes from `Datc::ADJUDICATED`, and its `left_out` is now `6.B.9` and `6.B.14` only):

```diff
@@ -4,20 +4,17 @@
 require_relative "../support/datc"
 
 # Runs every DATC fixture through TA.check (AC-8.1), and keeps the set of fixtures
-# exactly the one the spec lists (AC-8.2). #14 adds its cases to `encoded`.
+# exactly the one the specs list (AC-8.2). #14 added its cases through Datc::ADJUDICATED.
 RSpec.describe "DATC fixtures: checking" do
-  # The cases encoded for checking: 6.A and 6.B, except the four left out, and three
-  # from 6.D and 6.G that interface.md cites. See spec 011, "Cases encoded".
-  encoded = (
-    (1..10).map { |n| "6.A.#{n}" } +
-    [1, 2, 3, 4, 5, 6, 7, 8, 10, 11, 12, 13, 15, 16, 17, 18, 19].map { |n| "6.B.#{n}" } +
-    %w[6.D.31 6.D.34 6.G.19]
-  ).sort.freeze
-  left_out = %w[6.A.11 6.A.12 6.B.9 6.B.14].freeze
+  # Every fixture is run for checking: the cases adjudicated by #14 (Datc::ADJUDICATED), which
+  # include all of 6.A and 6.B except the four left out, and the three encoded for checking
+  # only. See spec 011, "Cases encoded", and spec 014, "DATC cases".
+  encoded = (Datc::ADJUDICATED + Datc::CHECKING_ONLY).sort.freeze
+  left_out = %w[6.B.9 6.B.14].freeze
 
   it "has one fixture for each encoded case and no other (AC-8.2)" do
     names = Datc.files.map { |path| File.basename(path, ".yml") }
-    expect(encoded.size).to eq(30)
+    expect(encoded.size).to eq(83)
     expect(names).to eq(encoded)
     expect(names & left_out).to eq([])
   end
```

  Command: `bundle exec rspec spec/datc`. Expected: the two file-set examples of the adjudication runner and the file-set example of the checking runner fail (80 and 83 files expected, 30 found); `marks only 6.B.2 and 6.B.12` of the adjudication runner fails too (it finds no case).
- [ ] **Step 2: write the table** to `table.rb` in the scratchpad.

```ruby
# Expected results of every encoded case, derived by hand from the DATC text.
# units: "P:t:loc ..." (power letter A E F G I R T; type a/f). orders: [token string, result].
# result token: S succeeded B bounced H held G given C cut U unmatched V void N no_route,
# optionally ">origin" = the unit following that order was dislodged by the unit from origin.
# imp: dislodged units whose own order was void (their implied hold), province => origin.
# st: standoff provinces.
POWERS = {"A"=>:austria,"E"=>:england,"F"=>:france,"G"=>:germany,"I"=>:italy,"R"=>:russia,"T"=>:turkey}
CASES = {}
def kase(id, units, orders, imp: {}, st: [])
  CASES[id] = {units: units, orders: orders, imp: imp, st: st}
end
# 6.A
kase "6.A.1",  "E:f:nth", [["m E nth pic","V"]]
kase "6.A.2",  "E:a:lvp", [["m E lvp iri","V"]]
kase "6.A.3",  "G:f:kie", [["m G kie mun","V"]]
kase "6.A.4",  "G:f:kie", [["m G kie kie","V"]]
kase "6.A.5",  "E:f:nth E:a:yor E:a:lvp G:f:lon G:a:wal",
  [["c E nth yor yor","V"],["m E yor yor","V"],["sm E lvp yor yor","V"],["m G lon yor","S"],["sm G wal lon yor","G"]], imp: {"yor"=>"lon"}
kase "6.A.6",  "E:f:lon", [["m G lon nth","V"]]
kase "6.A.7",  "E:f:lon E:f:nth", [["m E lon bel","V"],["c E nth lon bel","V"]]
kase "6.A.8",  "I:a:ven I:a:tyr A:f:tri", [["m I ven tri","S"],["sm I tyr ven tri","G"],["sh A tri tri","V"]], imp: {"tri"=>"ven"}
kase "6.A.9",  "I:f:rom", [["m I rom ven","V"]]
kase "6.A.10", "A:a:ven I:f:rom I:a:apu", [["h A ven","H"],["sm I rom apu ven","V"],["m I apu ven","B"]]
kase "6.A.11", "A:a:vie I:a:ven", [["m A vie tyr","B"],["m I ven tyr","B"]], st: ["tyr"]
kase "6.A.12", "A:a:vie G:a:mun I:a:ven", [["m A vie tyr","B"],["m G mun tyr","B"],["m I ven tyr","B"]], st: ["tyr"]
# 6.B
kase "6.B.1",  "F:f:por", [["m F por spa","V"]]
kase "6.B.2",  "F:f:gas", [["m F gas spa","V"]]
kase "6.B.3",  "F:f:gas", [["m F gas spa/sc","V"]]
kase "6.B.4",  "F:f:gas F:f:mar I:f:wes", [["m F gas spa/nc","S"],["sm F mar gas spa","G"],["m I wes spa/sc","B"]]
kase "6.B.5",  "F:f:mar F:f:spa/nc I:f:gol", [["m F mar gol","B"],["sm F spa mar gol","V"],["h I gol","H"]]
kase "6.B.6",  "E:f:iri E:f:nao F:f:spa/nc F:f:mao I:f:gol",
  [["sm E iri nao mao","G"],["m E nao mao","S"],["sh F spa mao","C"],["h F mao","H>nao"],["m I gol spa/sc","B"]]
kase "6.B.7",  "F:f:por F:f:mao I:f:gol I:f:wes", [["sm F por mao spa","G"],["m F mao spa/nc","B"],["sm I gol wes spa","G"],["m I wes spa/sc","B"]], st: ["spa"]
kase "6.B.8",  "F:f:por F:f:gas I:f:gol I:f:wes", [["sm F por gas spa","G"],["m F gas spa/nc","B"],["sm I gol wes spa","G"],["m I wes spa/sc","B"]], st: ["spa"]
kase "6.B.10", "F:f:spa/sc", [["m F spa gol","S"]]
kase "6.B.11", "F:f:spa/nc", [["m F spa gol","V"]]
kase "6.B.12", "F:a:gas", [["m F gas spa/nc","V"]]
kase "6.B.13", "T:f:bul/sc T:f:con", [["m T bul con","B"],["m T con bul/ec","B"]]
kase "6.B.15", "F:f:por E:f:mao I:f:gol I:f:wes", [["sm F por mao spa","G"],["m E mao spa/nc","B"],["sm I gol wes spa","G"],["m I wes spa/sc","B"]], st: ["spa"]
kase "6.B.16", "F:a:gas F:a:mar I:f:spa/sc E:f:por", [["m F gas spa","B"],["sm F mar gas spa","G"],["h I spa","H"],["sh E por spa","G"]]
kase "6.B.17", "E:f:mao F:f:spa/sc I:f:wes", [["h E mao","H>spa"],["m F spa mao","S"],["sm I wes spa mao","G"]]
# 6.C
kase "6.C.1", "T:f:ank T:a:con T:a:smy", [["m T ank con","S"],["m T con smy","S"],["m T smy ank","S"]]
kase "6.C.2", "T:f:ank T:a:smy T:a:bul I:a:con", [["m T ank con","S"],["m T smy ank","S"],["sm T bul ank con","G"],["m I con smy","S"]]
kase "6.C.3", "T:f:ank T:a:con T:a:smy T:a:bul", [["m T ank con","B"],["m T con smy","B"],["m T smy ank","B"],["m T bul con","B"]]
kase "6.C.8", "T:f:con T:a:bul T:a:smy R:f:bla A:a:ser",
  [["m T con bla","B"],["m T bul con","B"],["sm T smy bul con","G"],["m R bla bul/ec","B"],["m A ser bul","B"]]
kase "6.C.9", "T:f:con T:a:smy R:f:bla A:a:ser A:a:bul",
  [["m T con bla","B"],["sm T smy bul con","G"],["m R bla bul/ec","B"],["m A ser bul","B"],["m A bul con","B"]]
# 6.D
kase "6.D.1", "A:f:adr A:a:tri I:a:ven I:a:tyr", [["sm A adr tri ven","G"],["m A tri ven","B"],["h I ven","H"],["sh I tyr ven","G"]]
kase "6.D.2", "A:f:adr A:a:tri A:a:vie I:a:ven I:a:tyr", [["sm A adr tri ven","G"],["m A tri ven","S"],["m A vie tyr","B"],["h I ven","H>tri"],["sh I tyr ven","C"]]
kase "6.D.3", "A:f:adr A:a:tri I:a:ven I:f:ion", [["sm A adr tri ven","C"],["m A tri ven","B"],["h I ven","H"],["m I ion adr","B"]]
kase "6.D.4", "G:a:ber G:f:kie R:f:bal R:a:pru", [["sh G ber kie","C"],["sh G kie ber","G"],["sm R bal pru ber","G"],["m R pru ber","B"]]
kase "6.D.5", "G:a:ber G:f:kie G:a:mun R:f:bal R:a:pru", [["sm G ber mun sil","C"],["sh G kie ber","G"],["m G mun sil","S"],["sm R bal pru ber","G"],["m R pru ber","B"]]
kase "6.D.7", "G:f:bal G:f:pru R:f:lvn R:f:bot R:a:fin", [["m G bal swe","B>lvn"],["sh G pru bal","U"],["m R lvn bal","S"],["sm R bot lvn bal","G"],["m R fin swe","B"]], st: ["swe"]
kase "6.D.8", "A:f:ion A:a:ser A:a:alb T:a:gre T:a:bul", [["h A ion","H"],["sm A ser alb gre","G"],["m A alb gre","S"],["m T gre nap","N>alb"],["sh T bul gre","U"]]
kase "6.D.9", "I:a:ven I:a:tyr A:a:alb A:a:tri", [["m I ven tri","S"],["sm I tyr ven tri","G"],["sm A alb tri ser","U"],["h A tri","H>ven"]]
kase "6.D.10", "G:a:ber G:f:kie G:a:mun", [["h G ber","H"],["m G kie ber","B"],["sm G mun kie ber","G"]]
kase "6.D.11", "G:a:ber G:f:kie G:a:mun R:a:war", [["m G ber pru","B"],["m G kie ber","B"],["sm G mun kie ber","G"],["m R war pru","B"]], st: ["pru"]
kase "6.D.12", "A:f:tri A:a:vie I:a:ven", [["h A tri","H"],["sm A vie ven tri","G"],["m I ven tri","B"]]
kase "6.D.13", "A:f:tri A:a:vie I:a:ven I:f:apu", [["m A tri adr","B"],["sm A vie ven tri","G"],["m I ven tri","B"],["m I apu adr","B"]], st: ["adr"]
kase "6.D.14", "A:f:tri A:a:vie I:a:ven I:a:tyr I:f:adr", [["h A tri","H>ven"],["sm A vie ven tri","G"],["m I ven tri","S"],["sm I tyr ven tri","G"],["sm I adr ven tri","G"]]
kase "6.D.15", "R:f:con R:f:bla T:f:ank", [["sm R con bla ank","G"],["m R bla ank","S"],["m T ank con","B>bla"]]
kase "6.D.17", "R:f:con R:f:bla T:f:ank T:a:smy T:a:arm", [["sm R con bla ank","C>ank"],["m R bla ank","B"],["m T ank con","S"],["sm T smy ank con","G"],["m T arm ank","B"]], st: ["ank"]
kase "6.D.18", "R:f:con R:f:bla R:a:bul T:f:ank T:a:smy T:a:arm", [["sm R con bla ank","G"],["m R bla ank","S"],["sh R bul con","G"],["m T ank con","B>bla"],["sm T smy ank con","G"],["m T arm ank","B"]]
kase "6.D.19", "R:f:con R:f:bla R:a:smy T:f:ank", [["sm R con bla ank","G"],["m R bla ank","S"],["sm R smy ank con","G"],["m T ank con","B>bla"]]
kase "6.D.20", "E:f:lon E:f:nth E:a:yor F:f:eng", [["sm E lon nth eng","G"],["m E nth eng","S"],["m E yor lon","B"],["h F eng","H>nth"]]
kase "6.D.21", "A:f:tri I:a:ven I:a:tyr G:a:mun R:a:sil R:a:ber", [["h A tri","H"],["m I ven tri","B"],["sm I tyr ven tri","C"],["m G mun tyr","B>sil"],["m R sil mun","S"],["sm R ber sil mun","G"]]
kase "6.D.22", "G:f:kie G:a:bur R:a:mun R:a:ber", [["m G kie mun","V"],["sm G bur kie mun","V"],["m R mun kie","S"],["sm R ber mun kie","G"]], imp: {"kie"=>"mun"}
kase "6.D.23", "I:f:gol I:f:wes F:f:spa/nc F:f:mar", [["m I gol spa/sc","S"],["sm I wes gol spa","G"],["m F spa gol","V"],["sm F mar spa gol","V"]], imp: {"spa"=>"gol"}
kase "6.D.24", "F:a:mar F:f:spa/sc I:f:gol T:f:tys T:f:wes", [["m F mar gol","V"],["sm F spa mar gol","V"],["h I gol","H>wes"],["sm T tys wes gol","G"],["m T wes gol","S"]]
kase "6.D.25", "G:a:ber G:f:kie R:f:bal R:a:pru", [["sh G ber pru","U"],["sh G kie ber","G"],["sm R bal pru ber","G"],["m R pru ber","B"]]
kase "6.D.26", "G:a:ber G:f:kie R:f:bal R:a:pru", [["sm G ber pru sil","U"],["sh G kie ber","G"],["sm R bal pru ber","G"],["m R pru ber","B"]]
kase "6.D.27", "E:f:swe E:f:den G:a:ber R:f:bal R:f:pru", [["m E swe bal","B"],["sm E den swe bal","G"],["h G ber","H"],["c R bal ber lvn","U"],["sh R pru bal","G"]]
kase "6.D.28", "A:a:bud R:f:rum T:f:bla T:a:bul", [["sh A bud rum","G"],["m R rum hol","V"],["m T bla rum","B"],["sm T bul bla rum","G"]]
kase "6.D.29", "A:a:bud R:f:rum T:f:bla T:a:bul", [["sh A bud rum","G"],["m R rum bul/sc","V"],["m T bla rum","B"],["sm T bul bla rum","G"]]
kase "6.D.30", "I:f:aeg R:f:con T:f:bla T:a:bul", [["sh I aeg con","G"],["m R con bul","V"],["m T bla con","B"],["sm T bul bla con","G"]]
kase "6.D.31", "A:a:rum T:f:bla", [["m A rum arm","N"],["sm T bla rum arm","V"]]
kase "6.D.32", "E:f:edi E:a:lvp F:f:lon G:a:yor", [["sm E edi lvp yor","G"],["m E lvp yor","B"],["sh F lon yor","G"],["m G yor hol","V"]]
kase "6.D.33", "A:a:ser A:a:vie R:a:gal T:a:bul", [["m A ser bud","S"],["m A vie bud","B"],["sm R gal ser bud","G"],["m T bul ser","S"]]
kase "6.D.34", "G:a:ber G:a:sil G:f:bal I:a:pru R:a:war R:a:lvn", [["m G ber pru","S"],["sm G sil ber pru","G"],["sm G bal ber pru","G"],["sm R war lvn pru","G"],["m R lvn pru","B"],["sm I pru lvn pru","V"]], imp: {"pru"=>"ber"}
kase "6.D.35", "R:f:bla R:f:con T:f:ank T:f:aeg T:a:arm T:a:smy", [["m R bla ank","B"],["sm R con bla ank","C>ank"],["m T ank con","S"],["sm T aeg ank con","G"],["m T arm ank","S"],["sm T smy arm ank","G"]]
# 6.E
kase "6.E.1", "G:a:ber G:f:kie G:a:sil R:a:pru", [["m G ber pru","S"],["m G kie ber","S"],["sm G sil ber pru","G"],["m R pru ber","B>ber"]]
kase "6.E.2", "G:a:ber G:f:kie G:a:mun", [["m G ber kie","B"],["m G kie ber","B"],["sm G mun ber kie","G"]]
kase "6.E.3", "G:a:ber G:a:mun E:f:kie", [["m G ber kie","B"],["sm G mun kie ber","G"],["m E kie ber","B"]]
kase "6.E.4", "G:f:hol G:f:hel G:f:ska F:f:nth F:f:bel E:f:edi E:f:yor E:f:nwg A:a:kie A:a:ruh",
  [["m G hol nth","B"],["sm G hel hol nth","G"],["sm G ska hol nth","G"],["m F nth hol","B"],["sm F bel nth hol","G"],["sm E edi nwg nth","G"],["sm E yor nwg nth","G"],["m E nwg nth","B"],["sm A kie ruh hol","G"],["m A ruh hol","B"]]
kase "6.E.5", "G:f:hol G:f:hel G:f:ska F:f:nth F:f:bel E:f:edi E:f:yor E:f:nwg E:f:lon A:a:kie A:a:ruh",
  [["m G hol nth","B"],["sm G hel hol nth","G"],["sm G ska hol nth","G"],["m F nth hol","B>nwg"],["sm F bel nth hol","G"],["sm E edi nwg nth","G"],["sm E yor nwg nth","G"],["m E nwg nth","S"],["sm E lon nwg nth","G"],["sm A kie ruh hol","G"],["m A ruh hol","B"]]
kase "6.E.6", "G:f:hol G:f:hel F:f:nth F:f:bel F:f:eng A:a:kie A:a:ruh",
  [["m G hol nth","B"],["sm G hel hol nth","G"],["m F nth hol","B"],["sm F bel nth hol","G"],["sm F eng hol nth","G"],["sm A kie ruh hol","G"],["m A ruh hol","B"]]
kase "6.E.7", "E:f:nth E:f:yor G:f:hol G:f:hel R:f:ska R:f:nwy",
  [["h E nth","H"],["sm E yor nwy nth","G"],["sm G hol hel nth","G"],["m G hel nth","B"],["sm R ska nwy nth","G"],["m R nwy nth","B"]]
kase "6.E.8", "E:f:nth E:f:yor G:f:hol G:f:hel R:f:ska R:f:nwy",
  [["m E nth nwy","B"],["sm E yor nwy nth","G"],["sm G hol hel nth","G"],["m G hel nth","B"],["sm R ska nwy nth","G"],["m R nwy nth","B"]]
kase "6.E.9", "E:f:nth E:f:yor G:f:hol G:f:hel R:f:ska R:f:nwy",
  [["m E nth nwg","S"],["sm E yor nwy nth","G"],["sm G hol hel nth","G"],["m G hel nth","B"],["sm R ska nwy nth","G"],["m R nwy nth","S"]]
kase "6.E.10", "E:f:nth E:f:yor G:f:hol G:f:hel G:f:den R:f:ska R:f:nwy",
  [["m E nth den","B"],["sm E yor nwy nth","G"],["sm G hol hel nth","G"],["m G hel nth","B"],["m G den hel","B"],["sm R ska nwy nth","G"],["m R nwy nth","B"]]
kase "6.E.12", "A:a:bud A:a:ser I:a:vie R:a:gal R:a:rum",
  [["m A bud rum","B"],["sm A ser vie bud","G"],["m I vie bud","B"],["m R gal bud","B"],["sm R rum gal bud","G"]]
kase "6.E.13", "E:f:edi E:f:yor F:f:bel F:f:eng G:f:nth R:f:nwg R:f:nwy",
  [["sm E edi yor nth","G"],["m E yor nth","B"],["m F bel nth","B"],["sm F eng bel nth","G"],["h G nth","H"],["m R nwg nth","B"],["sm R nwy nwg nth","G"]]
kase "6.E.14", "E:a:lvp R:f:edi", [["m E lvp edi","B"],["m R edi lvp","V"]]
kase "6.E.15", "E:f:hol E:a:ruh F:a:kie F:a:mun F:a:sil G:a:ber G:f:den G:f:hel R:f:bal R:a:pru",
  [["sm E hol ruh kie","G"],["m E ruh kie","B"],["m F kie ber","B"],["sm F mun kie ber","G"],["sm F sil kie ber","G"],["m G ber kie","B"],["sm G den ber kie","G"],["sm G hel ber kie","G"],["sm R bal pru ber","G"],["m R pru ber","B"]]
# 6.F.1
kase "6.F.1", "T:a:gre T:f:aeg T:f:con T:f:bla", [["m T gre sev","V"],["c T aeg gre sev","V"],["c T con gre sev","V"],["c T bla gre sev","V"]]
```

- [ ] **Step 3: write the summaries** (our own words, one per new file) to `summaries.yml` in the scratchpad.

```yaml
6.A.11: Two armies that move into the same empty province bounce, and the province is a standoff
6.A.12: Three armies that move into the same empty province all bounce
6.C.1: Three units moving in a circle all move
6.C.2: A circle of three moves when one of its moves is supported
6.C.3: A fourth unit bounces one move of a circle, so the whole circle stays where it is
6.C.8: A circle blocked from outside stays put, because an army may not push out a unit of its own power
6.C.9: A support from the power that owns the attacked fleet doesn't help the attack, so the blocked circle stays put
6.D.1: A supported hold stands against an attack of equal strength
6.D.2: An attack on a supporter cuts the support, and the unsupported holder is dislodged
6.D.3: A move into a supporter's province cuts its support, so the supported attack only equals the hold
6.D.4: A unit that supports a hold may itself receive a hold support
6.D.5: A unit that supports a move may receive a hold support
6.D.7: A hold support for a unit that moves is unmatched, so the unit gets none and is dislodged
6.D.8: An army that needs a convoy nobody ordered fails and can't be given a hold support, so it is dislodged
6.D.9: A support for a move that its unit doesn't make is unmatched, and the holder is dislodged
6.D.10: A unit can't dislodge a unit of its own power
6.D.11: A unit whose move failed still can't be dislodged by its own power
6.D.12: A support for a foreign attack on one's own unit adds nothing to the dislodging
6.D.13: The same, when the supporter's own unit tried to leave and failed
6.D.14: A foreign attack with enough support of its own still dislodges, despite a support from the attacked unit's power
6.D.15: A unit can't keep its place by attacking the supporter of the attack on itself
6.D.17: A support attacked from the province it aims at is cut only if the supporter is dislodged
6.D.18: A supporter that isn't dislodged keeps its support, even when attacked from the province it aims at
6.D.19: A support from the attacked unit's own power doesn't count toward dislodging it
6.D.20: A unit can't cut the support of its own power
6.D.21: A unit dislodged in the same turn still cuts the support it attacked
6.D.22: A fleet's move into an inland province is void and can't be supported
6.D.23: A fleet's move out of the wrong coast is void and can't be supported
6.D.24: An army's move into the sea is void and can't be supported, while the fleet in that sea is dislodged by others
6.D.25: An unmatched support for a hold may itself be supported
6.D.26: An unmatched support for a move may itself be supported
6.D.27: A convoy order for an army that doesn't move is unmatched, yet its fleet may be supported
6.D.28: A fleet's illegal move is void, so it holds and receives support
6.D.29: A move naming a coast the fleet can't reach is void, so the fleet holds and receives support
6.D.30: A move with no coast where one is needed is void, so the fleet holds and receives support
6.D.32: An army's move with no convoy chain available is void, so the unit holds and receives support
6.D.33: A support from another power can break a standoff between two units of one power
6.D.35: A dislodged supporter's support is cut, which lets another army's supported move succeed
6.E.1: A dislodged unit doesn't hold its attacker's old province, so another unit can follow in
6.E.2: Two units of one power can't dislodge each other in a head-to-head battle
6.E.3: A power can't help dislodge its own unit in a head-to-head battle
6.E.4: A head-to-head loser that isn't dislodged still keeps another unit out of the province it attacked
6.E.5: A head-to-head loser that is dislodged by a third unit still keeps another unit out
6.E.6: A head-to-head loser that isn't dislodged, because the winner's support came from its own power, still keeps another unit out
6.E.7: A unit isn't dislodged when its own support is what makes the attack against it strong enough
6.E.8: The same, when the attacked fleet is also in a head-to-head battle
6.E.9: The same, when the attacked fleet moves away
6.E.10: The same, when the attacked fleet is in a circle whose other unit is stopped
6.E.12: A support for an attack on one's own unit can still stop a third unit
6.E.13: Three equal attacks on one unit all fail and nobody is dislodged
6.E.14: An illegal move is void, but the unit still holds against an attack of strength one
6.E.15: A head-to-head battle in which every unit is equally supported leaves everyone in place
6.F.1: A fleet in a coastal province can't convoy, and no convoy chain exists, so every order is void
```

- [ ] **Step 4: write the generator** to `gen.rb`. For a new file it writes the units and orders from the table, with a `check:` for every order (`legal: true`, or for a void order the reason of the `REASONS` list, which is what `TA.check` gives and the checking runner verifies); for an existing file it keeps everything and adds the results. It works out `after:` from the table alone: the units that were not dislodged, a successful mover at its destination (a fleet on the coast the order names), the dislodged units with their attacker's province, and the standoffs.

```ruby
# Throwaway: writes spec/datc fixtures from table.rb. Usage: ruby gen.rb <datc dir> [--check-roundtrip]
require "yaml"
require_relative "table"
DIR = ARGV[0]
ROUNDTRIP = ARGV.include?("--check-roundtrip")
TYPE = {"h"=>"hold","m"=>"move","sh"=>"support_hold","sm"=>"support_move","c"=>"convoy"}
SUMMARIES = YAML.safe_load(File.read(File.join(__dir__, "summaries.yml")))
REASONS = {
  "6.D.22"=>%w[not_reachable move_impossible], "6.D.23"=>%w[not_reachable move_impossible], "6.D.24"=>%w[not_reachable move_impossible],
  "6.D.28"=>%w[not_reachable], "6.D.29"=>%w[coast_unreachable], "6.D.30"=>%w[coast_required], "6.D.32"=>%w[not_reachable],
  "6.E.14"=>%w[not_reachable], "6.F.1"=>%w[not_reachable not_on_chain not_fleet_at_sea not_on_chain]
}
def q(v) = v.to_s.include?("/") ? %("#{v}") : v.to_s
def flow(h) = "{" + h.map { |k, v| "#{k}: #{q(v)}" }.join(", ") + "}"
def unit_hash(t) = (pw, ty, at = t.split(":"); {"power"=>POWERS.fetch(pw).to_s, "type"=>ty == "a" ? "army" : "fleet", "at"=>at})
def order_hash(tok)
  k, pw, at, a, b = tok.split
  h = {"type"=>TYPE.fetch(k), "power"=>POWERS.fetch(pw).to_s, "at"=>at}
  case k
  when "m" then h["destination"] = a
  when "sh" then h["target"] = a
  when "sm", "c" then h["from"] = a; h["to"] = b
  end
  h
end
# the table's token form of a fixture order hash (so existing files can use the same results)
def emit(id, summary, departure, units, entries, after)
  out = []
  out << %(case: "#{id}")
  out << "summary: #{summary}"
  out << "departure: true" if departure
  out << "position:" << "  units:"
  units.each { |u| out << "    - #{flow(u)}" }
  out << "orders:"
  entries.each do |e|
    out << "  - order: #{flow(e[:order])}"
    out << "    check: #{flow(e[:check])}"
    out << "    result: #{e[:result]}" if e[:result]
    out << "    dislodged: true" if e[:dislodged]
  end
  if after
    out << "after:" << "  units:"
    after[:units].each { |u| out << "    - #{flow(u)}" }
    unless after[:dislodged].empty?
      out << "  dislodged:"
      after[:dislodged].each { |d| out << "    - #{flow(d)}" }
    end
    out << "  standoffs: [#{after[:standoffs].join(", ")}]" unless after[:standoffs].empty?
  end
  out.join("\n") + "\n"
end
def compute_after(units, entries, dislodged_map)
  moved = entries.select { |e| e[:result] == "succeeded" }.to_h { |e| [e[:order]["at"], e[:order]["destination"]] }
  keep = []; dis = []
  units.each do |u|
    prov = u["at"].split("/").first
    if dislodged_map.key?(prov)
      dis << u.merge("from"=>dislodged_map[prov]).slice("power", "type", "at", "from")
    elsif moved.key?(prov)
      keep << u.merge("at"=>(u["type"] == "army" ? moved[prov].split("/").first : moved[prov]))
    else
      keep << u
    end
  end
  [keep, dis]
end
RES = {"S"=>"succeeded","B"=>"bounced","H"=>"held","G"=>"given","C"=>"cut","U"=>"unmatched","V"=>"void","N"=>"no_route"}
CASES.each do |id, c|
  path = File.join(DIR, "#{id}.yml")
  existing = File.exist?(path) ? YAML.safe_load_file(path) : nil
  if existing
    units = existing["position"]["units"]
    entries = existing["orders"].map { |o| {order: o["order"], check: o["check"]} }
    summary = existing["summary"]; departure = existing["departure"]
    if ROUNDTRIP
      text = emit(id, summary, departure, units, entries, nil)
      puts "#{id}: roundtrip differs" unless text == File.read(path)
      next
    end
  else
    next if ROUNDTRIP
    units = c[:units].split.map { |t| unit_hash(t) }
    reasons = (REASONS[id] || []).dup
    entries = c[:orders].map do |tok, res|
      check = res[0] == "V" ? {"legal"=>"false", "reason"=>reasons.shift} : {"legal"=>"true"}
      {order: order_hash(tok), check: check}
    end
    summary = SUMMARIES.fetch(id); departure = nil
  end
  raise "#{id}: #{c[:orders].size} results for #{entries.size} orders" unless c[:orders].size == entries.size
  dmap = {}
  entries.each_with_index do |e, i|
    r = c[:orders][i][1]
    e[:result] = RES.fetch(r[0])
    if r.include?(">") then e[:dislodged] = true; dmap[e[:order]["at"]] = r.split(">")[1] end
  end
  c[:imp].each { |k, v| dmap[k] = v }
  keep, dis = compute_after(units, entries, dmap)
  File.write(path, emit(id, summary, departure, units, entries, {units: keep, dislodged: dis, standoffs: c[:st]}))
end
puts "done"
```

- [ ] **Step 5: check the emitter first.** Command (from `adjudicator/`, with the scratchpad directory in `$S`): `ruby $S/gen.rb spec/datc --check-roundtrip`
  Expected: it prints only `done`: every existing file is reproduced exactly, so nothing but the additions will show in a diff.
- [ ] **Step 6: generate and run.** `ruby $S/gen.rb spec/datc`, then `bundle exec rspec spec/datc`.
  Expected: 0 failures. The adjudication runner has one example per order, plus three per case (implied holds, position, any order of the orders) and its two file-set examples; the checking runner runs all 83 files.
- [ ] **Step 7: run everything.** `bundle exec rspec` → 1748 examples, 0 failures, 3 pending (the scratch run: 1750 after Phase 8, and 2 pending once the CHANGELOG entry ends the `changelog_spec` skip). If yours differ by a few, look at the spec files before the number.
- [ ] **Step 8: verify the fixtures don't just mirror the engine.** They were derived from the DATC text, not from the output. As a spot check, change one expected result in a copy of one fixture and see the runner fail (the scratch run did this for three cases).
- [ ] **Step 9: commit** the generated files, the table's consumers and the two spec changes in one commit: `git add spec/datc` and commit "Encode the DATC cases of 6.A to 6.E and 6.F.1 with results". (53 new and 27 changed fixtures; reviewing them by section is `git diff --stat -- spec/datc/6.D.*`.)

---

## Phase 7: Random boards and the DATC conditions

**Implements:** Story 12 | **Satisfies:** AC-12.1 to AC-12.5
**Files:** create `spec/support/random_boards.rb`, `spec/support/conditions.rb`, `spec/trucebearer/adjudicator/adjudicate_random_spec.rb`
**Interfaces:** `RandomBoards.board(rng, shape, size: nil) -> [position, orders]` and the shape detectors; `Conditions.violations(position, adjudication) -> [String]`

- [ ] **Step 1: write the generator.** Seeded; plain boards of 2 to 34 units, and boards built around a circle, a head-to-head battle, a supporter attacked from its supported move's destination, and a unit attacked from three sides, then filled. No board holds a convoy order, a move via convoy, or a move only a convoy could make.

```ruby
# frozen_string_literal: true

require_relative "adjudicating"

# Random movement positions and orders for the adjudication specs (spec 014, Story 12). Every
# board is made from a seeded Random, so a failure is reproducible. A board is a plain one
# (units and orders chosen at random) or is built around a hard shape: a circle of moves, a
# head-to-head battle, a supporter attacked from the province its support aims at, or a unit
# attacked from three sides. Shaped boards are then filled with more units and orders.
#
# No board holds a convoy order, a move via convoy, or a move that only a convoy could make.
module RandomBoards
  MAP = TA::Map.classic
  POWERS = MAP.powers.map(&:id).freeze
  LAND = MAP.provinces.reject { |province| province.type == :sea }.map(&:id).freeze
  NEIGHBORS = LAND.to_h do |from|
    [from, LAND.select { |to| MAP.adjacent?(:army, L.new(province: from), L.new(province: to)) }.freeze]
  end.freeze
  FLEET_PLACES = MAP.provinces.reject { |province| province.type == :inland }.flat_map do |province|
    province.coasts.empty? ? [[province.id, nil]] : province.coasts.map { |coast| [province.id, coast] }
  end.freeze
  SHAPES = %i[plain circle pure_circle head_to_head supporter_attacked beleaguered].freeze
  CLASS_WEIGHTS = { O::Hold => 1, O::Move => 4, O::SupportHold => 1, O::SupportMove => 3 }.freeze

  module_function

  # [position, orders] for the given shape. `size` is the number of units to fill the board to
  # (the shaped part counts); by default a plain board has 2 to 34 units, a shaped one a few more.
  def board(rng, shape, size: nil)
    units = {}
    orders = []
    case shape
    when :circle, :pure_circle then circle(rng, units, orders)
    when :head_to_head then head_to_head(rng, units, orders)
    when :supporter_attacked then supporter_attacked(rng, units, orders)
    when :beleaguered then beleaguered(rng, units, orders)
    end
    fill(rng, units, size || (shape == :plain ? rng.rand(2..34) : units.size + rng.rand(0..14))) unless shape == :pure_circle
    position = Board.position(*units.values)
    [position, orders + chosen_orders(rng, position, units.values - shaped_units(units, orders))]
  end

  def army(rng, units, province, power = POWERS.sample(random: rng))
    units[province] = TA::Unit.new(power: power, type: :army, location: L.new(province: province))
  end

  def circle(rng, units, orders)
    path = nil
    200.times do
      candidate = [LAND.sample(random: rng)]
      rng.rand(3..5).pred.times do
        options = NEIGHBORS[candidate.last] - candidate
        break if options.empty?

        candidate << options.sample(random: rng)
      end
      path = candidate if candidate.size >= 3 && NEIGHBORS[candidate.last].include?(candidate.first)
      break if path
    end
    return unless path

    path.each_with_index do |province, index|
      unit = army(rng, units, province)
      orders << O::Move.new(power: unit.power, at: province, destination: L.new(province: path[(index + 1) % path.size]))
    end
  end

  def head_to_head(rng, units, orders)
    a = LAND.sample(random: rng)
    b = NEIGHBORS[a].sample(random: rng)
    [[a, b], [b, a]].each do |from, to|
      unit = army(rng, units, from)
      orders << O::Move.new(power: unit.power, at: from, destination: L.new(province: to))
    end
    [[a, b], [b, a]].each do |from, to|
      NEIGHBORS[to].reject { |c| units.key?(c) }.sample(rng.rand(0..2), random: rng).each do |supporter|
        unit = army(rng, units, supporter)
        orders << O::SupportMove.new(power: unit.power, at: supporter, from: from, to: to)
      end
    end
  end

  def supporter_attacked(rng, units, orders)
    y = LAND.select { |province| NEIGHBORS[province].size >= 2 }.sample(random: rng)
    s, x = NEIGHBORS[y].sample(2, random: rng)
    mover = army(rng, units, x)
    supporter = army(rng, units, s)
    attacker = army(rng, units, y)
    orders << O::Move.new(power: mover.power, at: x, destination: L.new(province: y))
    orders << O::SupportMove.new(power: supporter.power, at: s, from: x, to: y)
    orders << O::Move.new(power: attacker.power, at: y, destination: L.new(province: s))
  end

  def beleaguered(rng, units, orders)
    target = LAND.select { |province| NEIGHBORS[province].size >= 3 }.sample(random: rng)
    holder = army(rng, units, target)
    orders << O::Hold.new(power: holder.power, at: target)
    NEIGHBORS[target].sample(3, random: rng).each do |from|
      unit = army(rng, units, from)
      orders << O::Move.new(power: unit.power, at: from, destination: L.new(province: target))
    end
  end

  # More units on free provinces (armies and fleets, on any coast), up to 34 in all.
  def fill(rng, units, size)
    while units.size < [size, 34].min
      if rng.rand < 0.5
        army(rng, units, (LAND - units.keys).sample(random: rng))
      else
        province, coast = (FLEET_PLACES.reject { |(id, _)| units.key?(id) }).sample(random: rng)
        units[province] = TA::Unit.new(power: POWERS.sample(random: rng), type: :fleet, location: L.new(province: province, coast: coast))
      end
    end
  end

  # The units that already have an order from the shape.
  def shaped_units(units, orders) = orders.filter_map { |order| units[order.at] }

  # A random legal order for each of these units (a tenth are left without), and now and then
  # a hold from another power for a unit.
  def chosen_orders(rng, position, units)
    given = units.filter_map { |unit| choose(rng, position, unit) unless rng.rand < 0.1 }
    foreign = units.sample(rng.rand(0..2), random: rng).map do |unit|
      O::Hold.new(power: (POWERS - [unit.power]).sample(random: rng), at: unit.location.province)
    end
    given + foreign.reject { |order| given.any? { |other| other.power == order.power && other.at == order.at } }
  end

  def choose(rng, position, unit)
    legal = TA.legal_orders(position, unit).reject do |order|
      O::Convoy === order || O::MoveViaConvoy === order ||
        (O::Move === order && unit.type == :army && !TA.const_get(:Reach).reaches?(unit, order.destination.province))
    end
    weighted = CLASS_WEIGHTS.flat_map { |klass, weight| [klass] * weight }.sample(random: rng)
    pool = legal.select { |order| weighted === order }
    (pool.empty? ? legal : pool).sample(random: rng)
  end

  # ---- what a board holds, read from its orders ----

  def circle?(orders)
    moves = orders.grep(O::Move).to_h { |order| [order.at, order.destination.province] }
    moves.keys.any? do |start|
      path = [start]
      path << moves[path.last] until moves[path.last].nil? || path.include?(moves[path.last])
      follower = moves[path.last]
      follower && path.include?(follower) && path.size - path.index(follower) >= 3
    end
  end

  def head_to_head?(orders)
    moves = orders.grep(O::Move).map { |order| [order.at, order.destination.province] }
    moves.any? { |from, to| moves.include?([to, from]) }
  end

  def supporter_attacked?(orders)
    orders.grep(O::SupportMove).any? do |support|
      orders.any? { |order| O::Move === order && order.at == support.to && order.destination.province == support.at }
    end
  end

  def beleaguered?(position, orders)
    moves = orders.grep(O::Move)
    moves.group_by { |order| order.destination.province }.any? do |province, attackers|
      attackers.size >= 3 && position.units.any? { |unit| unit.location.province == province } &&
        moves.none? { |order| order.at == province }
    end
  end
end
```

- [ ] **Step 2: write the conditions.** The DATC's conditions re-stated from the final results, independently of the resolver. It checks each support's result, each move's result, each dislodgement and the standoffs.

```ruby
# frozen_string_literal: true

require_relative "adjudicating"

# The conditions of the DATC's section 5 (DATC 5.B), written again here, in the spec, from the
# contract and the DATC and not from the resolver: given the orders and the result that
# TA.adjudicate gave, does every result satisfy them? (spec 014, AC-12.3.) It is read from the
# final results only, so it checks a solution and doesn't pick one: it can't tell which of
# several consistent solutions a circle should have, which is what the circle specs are for.
#
# It covers boards with no convoy: every move has a route.
module Conditions
  Entry = Data.define(:order, :power, :type, :result, :dislodged) do
    def province = order.at
    def move? = O::Move === order
    def destination = order.destination.province
    def support? = O::SupportHold === order || O::SupportMove === order
  end

  module_function

  # An array of messages, empty when every condition holds.
  def violations(position, adjudication)
    entries = entries_of(position, adjudication)
    at = entries.to_h { |entry| [entry.province, entry] }
    into = entries.select(&:move?).group_by(&:destination)
    problems = []

    entries.each do |entry|
      problems << "#{label(entry)}: #{support_problem(entry, at, into)}" if entry.support? && support_problem(entry, at, into)
      problems << "#{label(entry)}: #{move_problem(entry, at, into, entries)}" if entry.move? && move_problem(entry, at, into, entries)
    end
    problems.concat(dislodgement_problems(position, adjudication, entries, into))
    problems.concat(standoff_problems(position, adjudication, entries, at, into))
    problems
  end

  def entries_of(position, adjudication)
    owners = position.units.to_h { |unit| [unit.location.province, unit] }
    adjudication.outcomes.reject { |outcome| outcome.result == :void }.map do |outcome|
      unit = owners.fetch(outcome.order.at)
      Entry.new(order: outcome.order, power: unit.power, type: unit.type, result: outcome.result, dislodged: outcome.dislodged)
    end
  end

  def label(entry) = "#{entry.order.class.name.split("::").last} at #{entry.province}"

  def succeeded?(entry) = entry.result == :succeeded

  # A support that belongs to a move or a hold of the unit it names.
  def matched?(support, at)
    case support.order
    when O::SupportHold then at[support.order.target] && !at[support.order.target].move?
    when O::SupportMove
      supported = at[support.order.from]
      supported&.move? && supported.destination == support.order.to
    end
  end

  def cut?(support, into)
    attackers = into.fetch(support.province, [])
    attackers.any? do |attacker|
      (attacker.power != support.power && (O::SupportHold === support.order || attacker.province != support.order.to)) ||
        succeeded?(attacker)
    end
  end

  def support_problem(support, at, into)
    expected = if !matched?(support, at) then :unmatched
               elsif cut?(support, into) then :cut
               else :given
               end
    "result #{support.result.inspect}, expected #{expected.inspect}" unless support.result == expected
  end

  def given_move_supports(move, entries, except_power: nil)
    entries.count do |entry|
      O::SupportMove === entry.order && entry.result == :given && entry.order.from == move.province &&
        entry.order.to == move.destination && entry.power != except_power
    end
  end

  def head_to_head?(move, at)
    other = at[move.destination]
    other&.move? && other.destination == move.province
  end

  def hold_strength(province, at, entries)
    entry = at[province]
    return 0 unless entry
    return (succeeded?(entry) ? 0 : 1) if entry.move?

    1 + entries.count { |other| O::SupportHold === other.order && other.order.target == province && other.result == :given }
  end

  def attack_strength(move, at, entries)
    other = at[move.destination]
    return 1 + given_move_supports(move, entries) if other.nil? || (other.move? && !head_to_head?(move, at) && succeeded?(other))
    return 0 if other.power == move.power

    1 + given_move_supports(move, entries, except_power: other.power)
  end

  def prevent_strength(move, at, entries)
    return 0 if head_to_head?(move, at) && succeeded?(at[move.destination])

    1 + given_move_supports(move, entries)
  end

  def move_problem(move, at, into, entries)
    attack = attack_strength(move, at, entries)
    opposing = head_to_head?(move, at) ? 1 + given_move_supports(at[move.destination], entries) : hold_strength(move.destination, at, entries)
    rivals = (into.fetch(move.destination) - [move]).map { |rival| prevent_strength(rival, at, entries) }
    expected = attack > opposing && rivals.all? { |rival| attack > rival } ? :succeeded : :bounced
    "result #{move.result.inspect}, expected #{expected.inspect} (attack #{attack}, against #{opposing}, rivals #{rivals})" unless move.result == expected
  end

  def dislodgement_problems(position, adjudication, entries, into)
    problems = []
    into.each { |province, moves| problems << "two moves into #{province} succeeded" if moves.count { |move| succeeded?(move) } > 1 }
    dislodged = adjudication.position.dislodged_units.to_h { |entry| [entry.unit.location.province, entry] }
    entries.each do |entry|
      stays = !(entry.move? && succeeded?(entry))
      winner = into.fetch(entry.province, []).find { |move| succeeded?(move) }
      expected = stays && !winner.nil?
      problems << "#{label(entry)}: dislodged #{entry.dislodged}, expected #{expected}" unless entry.dislodged == expected
      problems << "#{label(entry)}: dislodged unit missing or wrong attacker" if expected && dislodged[entry.province]&.attacker_from != winner.province
      problems << "#{label(entry)}: a power dislodged its own unit" if expected && winner.power == entry.power
    end
    problems << "dislodged units differ from the flagged outcomes" unless dislodged.keys.sort == entries.select(&:dislodged).map(&:province).sort
    problems << "a unit is lost or doubled" unless adjudication.position.units.size + dislodged.size == position.units.size
    problems
  end

  # An empty province that two or more moves entered on equal terms (spec 014, "Standoffs").
  def standoff_problems(position, adjudication, entries, at, into)
    occupied = adjudication.position.units.map { |unit| unit.location.province }
    expected = into.filter_map do |province, moves|
      next if occupied.include?(province)

      strengths = moves.map { |move| prevent_strength(move, at, entries) }.select(&:positive?)
      province if strengths.any? && strengths.count(strengths.max) >= 2
    end.sort
    expected == adjudication.position.standoffs ? [] : ["standoffs #{adjudication.position.standoffs}, expected #{expected}"]
  end
end
```

- [ ] **Step 3: write the spec.**

```ruby
# frozen_string_literal: true

require "trucebearer/adjudicator"
require_relative "../../support/random_boards"
require_relative "../../support/conditions"

# Correctness beyond the DATC (Story 12): seeded random boards, with the hard shapes built in on
# purpose. Every board is adjudicated, and the result has to satisfy the conditions of the DATC,
# re-stated in spec/support/conditions.rb (AC-12.1 to AC-12.5).
RSpec.describe "TA.adjudicate on random boards" do
  per_shape = { plain: 120, circle: 40, pure_circle: 40, head_to_head: 40, supporter_attacked: 40, beleaguered: 40 }.freeze

  boards = per_shape.flat_map do |shape, count|
    rng = Random.new(shape.to_s.sum * 1_000 + 14)
    Array.new(count) { |index| [shape, index, *RandomBoards.board(rng, shape)] }
  end
  results = boards.map { |shape, index, position, orders| [shape, index, position, orders, TA.adjudicate(position, orders)] }

  it "adjudicates every board, builds a valid position, and keeps every unit once (AC-12.1)" do
    expect(boards.size).to eq(320)
    expect(boards.map { |_, _, position, _| position.units.size }.max).to be <= 34
    results.each do |shape, index, position, orders, adjudication|
      expect(adjudication).to be_a(TA::Adjudication), "#{shape} board #{index}"
      expect(adjudication.outcomes.size).to be >= orders.size
      moved = adjudication.position.units.size + adjudication.position.dislodged_units.size
      expect(moved).to eq(position.units.size), "#{shape} board #{index}"
    end
  end

  it "holds each hard shape in at least 20 boards, found from the orders and not from the generator (AC-12.1)" do
    counts = Hash.new(0)
    results.each do |_, _, position, orders, _|
      counts[:circle] += 1 if RandomBoards.circle?(orders)
      counts[:head_to_head] += 1 if RandomBoards.head_to_head?(orders)
      counts[:supporter_attacked] += 1 if RandomBoards.supporter_attacked?(orders)
      counts[:beleaguered] += 1 if RandomBoards.beleaguered?(position, orders)
    end
    expect(counts.values_at(:circle, :head_to_head, :supporter_attacked, :beleaguered).min).to be >= 20, counts.inspect
  end

  it "never sets the paradox flag; the last-resort branch can't run unseen (AC-12.2)" do
    expect(results.map { |*, adjudication| adjudication.paradox }).to all(be(false))
  end

  it "satisfies the conditions of the DATC on every board (AC-12.3)" do
    results.each do |shape, index, position, _, adjudication|
      expect(Conditions.violations(position, adjudication)).to eq([]), "#{shape} board #{index}"
    end
  end

  it "moves every unit of a circle that nothing else touches (AC-12.3)" do
    results.select { |shape, *| shape == :pure_circle }.each do |_, index, position, orders, adjudication|
      expect(orders.size).to be >= 3
      expect(adjudication.outcomes.map(&:result)).to all(eq(:succeeded)), "pure circle board #{index}"
      expect(adjudication.position.units.size).to eq(position.units.size)
    end
  end

  it "gives the same results when the orders are shuffled (AC-12.4)" do
    key = lambda do |adjudication|
      [adjudication.outcomes.to_h { |outcome| [outcome.order, [outcome.result, outcome.submitted, outcome.dislodged]] },
       adjudication.position, adjudication.paradox]
    end
    results.each_with_index do |(shape, index, position, orders, adjudication), number|
      shuffled = TA.adjudicate(position, orders.shuffle(random: Random.new(number)))
      expect(key.call(shuffled)).to eq(key.call(adjudication)), "#{shape} board #{index}"
    end
  end

  it "adjudicates a position of 34 units in under a second (AC-12.5)" do
    rng = Random.new(34)
    position, orders = RandomBoards.board(rng, :plain, size: 34)
    expect(position.units.size).to eq(34)
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    TA.adjudicate(position, orders)
    expect(Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).to be < 1.0
  end
end
```

- [ ] **Step 4: run it.** Command: `bundle exec rspec spec/trucebearer/adjudicator/adjudicate_random_spec.rb`
  Expected: 7 examples, 0 failures, about 5 seconds (the boards are built once, at load). It goes green at first run because Phases 4 and 6 are done: it is a check that the finished resolver agrees with an independent restatement of the conditions, and TDD's red step for it is the mutation check below.
- [ ] **Step 5: show the specs can fail.** Temporarily change `resolver.rb` in each of these ways, run `bundle exec rspec spec/trucebearer/adjudicator/adjudicate_random_spec.rb spec/datc/datc_adjudicate_spec.rb`, see failures, and restore the file with `git checkout lib/trucebearer/adjudicator/resolver.rb`:
  1. in `staying_attack`, replace `range(1, move_supporters(move).reject { |support| support.power == other.power })` with `range(1, move_supporters(move))` (expected: about 38 failures);
  2. in `cuts?`, replace `support.order.is_a?(Order::SupportHold) || move.province != support.order.to` with `true` (about 18);
  3. in `standoffs`, delete the line `next if occupied_after?(province)` (about 9);
  4. in `circle_pass`, set each move of a circle to `false` instead of `true` (about 8).
  Two changes survive and are equivalent without convoys: counting a standoff for a single move (a lone move into an empty province always succeeds), and treating a circle of two as a circle (a swap is decided by strength first). Say so in the pull request.
- [ ] **Step 6: commit** "Check the results against the DATC conditions on random boards".

---

## Phase 8: The contract, the records and the final checks

**Implements:** Story 3 (AC-3.5) and Story 14 | **Satisfies:** AC-3.5, AC-14.1 to AC-14.3
**Files:** modify `docs/interface.md`, `docs/ruleset.md`, `CHANGELOG.md`, `spec/trucebearer/adjudicator/adjudicate_examples_spec.rb`

- [ ] **Step 1: make sure `main` is in.** `origin/main` (the 0.1.0 release, #13) was merged into the branch at Gate B (merge commit `ee6a865`); #13 marked `Outcome` and `Adjudication` as arriving in 0.2.0 and moved the CHANGELOG entries under 0.1.0. If the coordinator says `main` moved again, `git fetch origin` and `git merge origin/main` (a merge, never a rebase) before touching `interface.md`, keeping this feature's entry under "Unreleased". Run `bundle exec rspec`: 0 failures.
- [ ] **Step 2: write the examples as specs first.** Append this block to `adjudicate_examples_spec.rb`, inside the `RSpec.describe`, before its last `end`. The specs pass at once, since the behavior exists from Phases 2 and 3: what they pin is that the examples the document is about to show are true. Step 3 adds the text, which must match these calls.

```ruby
  describe "the impossible outcomes and adjudications of the contract" do
    let(:hold) { O::Hold.new(power: :england, at: :lon) }
    let(:pos) do
      TA::Position.new(map: "classic", season: :spring, year: 1901, phase: :movement,
                       units: [TA::Unit.new(power: :england, type: :fleet, location: L.new(province: :lon))],
                       ownership: { lon: :england }, dislodged_units: [], standoffs: [])
    end

    def held(power, at, submitted) = TA::Outcome.new(order: O::Hold.new(power: power, at: at), result: :held, submitted: submitted, dislodged: false)

    it "refuses the impossible outcomes of ### Impossible objects" do
      expect { TA::Outcome.new(order: hold, result: :bounced, submitted: true, dislodged: false) }.to raise_error(TA::InvalidInput)
      expect { TA::Outcome.new(order: hold, result: :void, submitted: true, dislodged: true) }.to raise_error(TA::InvalidInput)
      expect { TA::Outcome.new(order: hold, result: :void, submitted: false, dislodged: false) }.to raise_error(TA::InvalidInput)
    end

    it "refuses the impossible adjudications of ### Impossible objects" do
      expect { TA::Adjudication.new(outcomes: [held(:france, :bre, false), held(:england, :lon, true)], paradox: false, position: pos) }
        .to raise_error(TA::InvalidInput)
      expect { TA::Adjudication.new(outcomes: [held(:france, :bre, false), held(:england, :bel, false)], paradox: false, position: pos) }
        .to raise_error(TA::InvalidInput)
      expect { TA::Adjudication.new(outcomes: [held(:england, :lon, true), held(:england, :lon, true)], paradox: false, position: pos) }
        .to raise_error(TA::InvalidInput)
    end
  end
```

  Command: `bundle exec rspec spec/trucebearer/adjudicator/adjudicate_examples_spec.rb`. Expected: 12 examples, 0 failures, 2 pending.
- [ ] **Step 3: add the examples to `docs/interface.md`** (Open Question 2, yes; only rules that follow from the contract's wording). They go at the end of the code block of `### Impossible objects`, labelled "From 0.2.0" in the style #87 uses for the other 0.2.0 items of that part of the document. `a` is the position of `### Canonical order`, which the section's other examples already use. Add after the last `TA::CheckResult` example:

````markdown
# From 0.2.0: an outcome with a result its order class can't have, a void order that is dislodged,
# or an implied hold that isn't a held Hold.
hold = O::Hold.new(power: :england, at: :lon)
TA::Outcome.new(order: hold, result: :bounced, submitted: true, dislodged: false)
TA::Outcome.new(order: hold, result: :void, submitted: true, dislodged: true)
TA::Outcome.new(order: hold, result: :void, submitted: false, dislodged: false)

# From 0.2.0: an adjudication with a submitted outcome after an implied hold, with implied holds
# that aren't in ascending order of province, or with two submitted outcomes for one power and
# province (TA.adjudicate refuses such orders). Its position may be in any phase.
held = ->(power, at, submitted) { TA::Outcome.new(order: O::Hold.new(power: power, at: at), result: :held, submitted: submitted, dislodged: false) }
TA::Adjudication.new(outcomes: [held.(:france, :bre, false), held.(:england, :lon, true)], paradox: false, position: a)
TA::Adjudication.new(outcomes: [held.(:france, :bre, false), held.(:england, :bel, false)], paradox: false, position: a)
TA::Adjudication.new(outcomes: [held.(:england, :lon, true), held.(:england, :lon, true)], paradox: false, position: a)
````

  The section's opening sentence says each object "can't exist on the classic map"; add "(or, from 0.2.0, can't be the result of an adjudication)" after it. Nothing else in the file changes: `git diff docs/interface.md` shows only these lines and that clause.
- [ ] **Step 4: `docs/ruleset.md`.** Amend the existing 4.D.3 row and add the rows below after the 4.E.1 row, in this wording, and no other change. The 4.D.3 row becomes:

```markdown
| 4.D.3 | What if one power gives the same unit two orders? | `InvalidInput` is raised. Two orders count as two for one unit when the same power names the same province in both, even when no unit stands there. An order from a power that doesn't own the unit is void and counts for the power that gave it | Not one of the listed options. The app keeps one order per unit |
```

and the new rows are:

```markdown
| 4.E.2 | What are the results of an order called? | The nine result symbols of `interface.md`; the DATC leaves naming free | Names chosen for display and replay |
| 4.E.3 | What does a unit do when its owner gave it no legal order? | It holds. The hold is implied, is not marked as submitted, and other units can support it | Preferred; with 4.E.1 this also covers a void order |
| 5.B.9 | What happens to a circle of moves, each into the province the next one leaves? | With three or more units, all succeed unless something else stops one of them. A circle of two is a head-to-head battle and is decided by strength. None of this is a paradox | The DATC's circular-movement rule |
| 5.B.9 | What if a cycle of moves is still undecided when no rule applies? | The moves on the cycles that are stuck fail, and `paradox` is true. This can't happen without convoys, which seeded random boards check; #15 decides what it becomes | The DATC advises failing the non-hold orders of a cycle no rule decides |
| 6.H.6, 6.H.9, 6.H.17 | What is a standoff, for the retreat phase? | A province that is empty after the moves and that at least two moves with a route entered on equal terms: neither lost a head-to-head battle, and they shared the greatest prevent strength. A province whose own unit stays, one that a winner entered, and one whose attackers were stopped by a stronger unit or lost a head-to-head battle are not standoffs | The retreat cases name "contested" provinces without defining them; this is our reading of them |
| 4.A.1, 4.A.3 | (Temporary) Does a convoy route work in this build? | No. Until convoys arrive (#15), a move that goes by convoy is `:no_route` and a legal convoy order is `:unmatched`. This is replaced before 0.2.0 ships | Scaffolding in an unreleased build |
```

- [ ] **Step 5: `CHANGELOG.md`.** Under "Unreleased", "Added" (empty since the 0.1.0 release), add this entry as its first item (and keep it there when `main` is merged in). It also ends the `changelog_spec` skip:

```markdown
- `TA::Outcome`, `TA::Adjudication` and `TA.adjudicate(position, orders)`: adjudicating a movement phase with no convoys, following the decision-based approach of Kruijswijk's "The Math of Adjudication". Every order gets an outcome; a unit with no legal order holds and can be supported; each dislodged unit records the province its attacker came from; and `position` is the retreat-phase snapshot of `docs/interface.md`. The DATC cases of 6.A to 6.E that need no convoy, and 6.F.1, are fixtures in `spec/datc/` with their results; every result is also checked against the DATC's conditions on seeded random boards. `docs/interface.md` now names the impossible `TA::Outcome` and `TA::Adjudication`. **Convoy routing arrives with #15, before 0.2.0 ships:** until then a move that goes by convoy is `:no_route` and a legal convoy order is `:unmatched`. (#14)
```

- [ ] **Step 6: the proof of the Issue's "Done when".** Run each and read the output:
  - `bundle exec rspec` → 1750 examples, 0 failures, 2 pending.
  - `bundle exec rake` → the same.
  - `bundle exec rspec spec/trucebearer/adjudicator/adjudicate_examples_spec.rb` → every example of `## Adjudicating a movement phase`, `### TA::Outcome` and `### TA::Adjudication` is a passing spec, except the two marked pending.
  - `bundle exec rspec spec/datc` → every encoded case passes.
  - `git diff --name-only main...HEAD` → only paths under `adjudicator/`, and `docs/interface.md` among them with only the two additions.
  - The `Adjudicator` job of GitHub Actions is green on the pull request.
- [ ] **Step 7: commit** "Record the adjudication choices and the contract's impossible objects".

---

## Finish (after Phase 8)

1. Dispatch the implementation review (Opus, read-only): it traces the spec and plan against the code and the fixtures, and **confirms the defensive branch of `Resolver#resolve` is unreachable** (the coordinator's ruling). Record its findings, and how each was handled, in the pull request description; fix what is blocking and commit "Settle the implementation review of adjudication".
2. Run `sdd-superpowers:session-wrap`; commit only memory items inside `adjudicator/` that a fresh session couldn't rediscover, or none.
3. Push. The first push opens a draft pull request that follows `.github/pull_request_template.md`, says "Closes #14", lists the deviations below, and ends with "🤖 Generated with [Claude Code](https://claude.com/claude-code)".
4. Run the tests until they pass; wait for the `Adjudicator` job.
5. `gh pr ready <N>`, then `gh pr edit <N> --add-assignee @me`. Never merge.

**Deviations to state in the pull request:** the two convoy examples are pending (AC-1.3); #12's public-surface spec is updated in step with the code; the checking runner's file set and `left_out` change (spec 011 AC-8.2 anticipated it); 6.F.1 is encoded though outside 6.A to 6.E (Gate A); wrong-class arguments raise (Gate A, Open Question 5).

## Self-review

- **Spec coverage.** Story 1: Phases 1, 4 and 8. Story 2: Phase 2. Story 3: Phases 3 and 8. Story 4: Phases 2 and 3. Story 5 and 6: Phase 4. Story 7 to 10: Phase 4 (unit specs) and Phase 6 (the DATC cases). Story 11: Phases 5 and 6. Story 12: Phase 7. Story 13: Phase 4. Story 14: Phase 8. AC-9.1: Phase 6 (every fixture, every permutation) and Phase 7 (random shuffles). AC-14.3: Phase 8, Step 6.
- **Placeholder scan.** No "TBD" or "similar to": every code step shows its code, every command its expected result. The generator script and the table are in Phase 6, in full.
- **Type consistency.** `Outcome.new(order:, result:, submitted:, dislodged:)` and `Adjudication.new(outcomes:, paradox:, position:)` are used the same way in Phases 2, 3, 4, 5 and 8; `Resolver#result`, `#dislodged?`, `#entry_at`, `#next_units`, `#dislodged_units`, `#standoffs`, `#paradox` are the names `Adjudicate` calls; `Datc::ADJUDICATED` and `Datc.expected_outcomes` are used the same way by both runners.

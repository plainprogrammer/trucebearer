# Implementation Plan: List the legal orders for a unit

**Spec:** adjudicator/docs/specs/012-legal-orders/spec.md (v1.1.2, Approved)
**Decisions:** none in `docs/adr/`. The recorded decisions are `docs/architecture.md` and the contract in `adjudicator/docs/interface.md`; the generation approach (B: narrow, then ask `Check`) is settled in the spec's "How the list is generated" and approved at Gate A.
**Created:** 2026-11-25

## Global Constraints

- **Read `spec.md` in full before starting any phase.** Where a phase cites an AC or FR, the spec's wording is what the code must satisfy.
- Change files in `adjudicator/` only. The spec and this plan ship in the same pull request.
- **`docs/interface.md` is not changed**, by any phase. If a phase shows that the contract is wrong or contradicts itself (for example a list-order rule that `check` contradicts), stop and `ask` the coordinator.
- Never give anything a name that contains or echoes the game's trademarked name or its three-letter prefix: files, classes, methods, specs, comments, commit messages.
- No copied rules text and no DATC prose. No DATC fixtures are added (the 11 deferred cases stay with #14).
- No new dependency: standard library only. No benchmark gem; `Process.clock_gettime` is enough.
- **Test first.** Each phase writes its specs, runs them, and sees them fail for the right reason before it writes any code. Phase 1, Step 1 commits the first spec alone, red, as the first code commit.
- **The generator may drop a candidate only by the four narrowings N1 to N4 of the spec, and `Check.reason_for` decides every listed order.** Adding a narrowing, or any other test, needs a spec change first.
- Run every command from `adjudicator/`. Spec files begin with `require "trucebearer/adjudicator"` and `require_relative "../../support/board"`. `.rspec` already loads `spec_helper`. Code files begin with `# frozen_string_literal: true`.
- `TA`, `L` and `O` stand for `Trucebearer::Adjudicator`, `TA::Location` and `TA::Order`, as in `interface.md`.
- Commit messages are plain imperative sentences, one commit per phase (plus the red first commit), each ending with `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`. One git operation per shell call. A phase is committed only when its own specs pass and the rest of the suite is green, except the red first commit. Nothing is pushed before the end, so CI never sees a red commit.
- `Reach` and `Check` are not edited. #11's specs must pass unchanged. If a step shows a helper needs a small change to be reusable, make it in that step with a spec, and say so in the pull request.

## Goal

`TA.legal_orders(position, unit)` returns the legal orders of a unit exactly as `docs/interface.md` describes, proved by specs for every list rule, by an agreement spec against `TA.check` over each unit's whole candidate space (in both directions, on sampled positions and fixed-seed random boards), by a speed spec, and by every interface example.

---

## Pre-implementation gates

- **Simplicity (≤3 components):** one new library file, `legal_orders.rb` (`LegalOrders`, internal, one concept: which orders to ask `Check` about, and in what order). `TA.legal_orders` is a one-line method in `adjudicator.rb` that calls `LegalOrders.call`. `Reach` and `Check` are reused as they are. No dependency.
- **Anti-abstraction:** plain module of functions, private to the gem like `Reach` and `Check`; the orders are the existing `Data` classes.
- **Integration-first:** the contract is `docs/interface.md`. The first spec of the feature is its first example (Phase 1, Step 1), and the examples spec (Phase 4) runs every example under `## Legal orders`.

## Decisions the plan settles (spec left them open)

| Decision | Choice | Spec |
|---|---|---|
| Files | `lib/trucebearer/adjudicator/legal_orders.rb`, required from `lib/trucebearer/adjudicator.rb` after `check`. `LegalOrders` is `private_constant` | FR-2, AC-7.5 |
| What `Check` offers | `Check.reason_for(position, order)` returns `nil` for a legal order. It is already a module function and is used as it stands | FR-2 |
| Which `Reach` tables | `ARMY_STEPS`, `FLEET_STEPS`, `COASTAL` and `SEAS`, as they stand | N1 to N4 |
| Sorting | Candidates are built already in list order. Provinces and coasts sort by `to_s`. `SORTED_COASTAL` is sorted once when the file loads. Groups are concatenated in the contract's order, so the list needs no final sort | AC-4.1, AC-4.2 |
| Argument errors | `Shape.instance_of!` for both arguments, so the message is `"position" must be a Trucebearer::Adjudicator::Position, got nil` as `TA.check` gives for its own | AC-2.3 |
| On the board | `position.units.include?(unit)`: `Data` equality on power, type and location | AC-2.2 |
| Sample positions | `spec/support/legal_positions.rb` holds every sampled position, the stress position, the six random boards (fixed seeds) and the full candidate space of a unit, built fresh for each unit (a cache would hold about 1.8 million orders in memory for the rest of the suite, which the review measured at about 245 MB, for a 20% saving) | AC-5.2, AC-5.3 |
| Seeds | Boards are `[seed, armies, sea_fleets, coast_fleets]`: `[1, 22, 8, 4]` (34 units, the mid-game board), `[2, 18, 6, 4]` (28 units), `[3, 12, 3, 3]`, `[4, 8, 2, 2]`, `[5, 3, 1, 1]`, `[6, 3, 2, 0]` (5 units). The first coast fleet of every board that has one is always put on a split coast (bulgaria, spain or saint petersburg, one drawn with the seed), so the split coasts are exercised by random boards too | AC-5.2 |
| Relative guard | Median of 3 runs of approach A against the median of 5 runs of `TA.legal_orders`, at least 10 times. **If this guard ever flakes on CI, drop it and keep the absolute ceilings; say so in the pull request** (coordinator's note at Gate A) | AC-6.3 |
| Recording times | The measured times for the pull request come from a throwaway script kept outside the repository (the scratchpad) that uses the same positions through `LegalPositions`. No benchmark code ships | AC-6.5 |
| Agreement spec running time and CI | See "Agreement spec: how long, and how CI runs it" below | AC-5.5 |

## Agreement spec: how long, and how CI runs it

The agreement spec checks 11,482 candidates for every unit of every sampled position: about 200 units in all (22 of the start, 11 and 12 of the split-coast positions, 2 of `ln`, 2 of `at_sea`, 12 of the three convoy positions, 39 of the stress position, 34 + 28 + 18 + 12 + 5 + 5 of the random boards, and two units of each of the two non-movement positions). A unit costs about 0.06 s (building its candidates and checking each), so the spec takes **about 12 s locally** (the plan review ran it in a scratch copy: 12.3 s). The full suite takes about 9 s today and is expected to take about 30 s with this feature (the review measured 29.8 s with the speed spec's 8 s included).

It runs in CI with everything else: `.github/workflows/adjudicator.yml` runs `bundle exec rspec` with no filter and has a 10-minute timeout, and `.rspec` and `spec_helper.rb` have no tag filter. Because it is over the spec's 10 s line (AC-5.5), it is **tagged `:slow`** (`RSpec.describe "...", :slow`), a tag that only names it and excludes nothing. Phase 2 measures the real time and the pull request states it and how CI runs it.

## Files

| File | Change | Responsibility |
|---|---|---|
| `adjudicator/lib/trucebearer/adjudicator/legal_orders.rb` | create | Internal: candidates (N1 to N4) in list order, filtered by `Check.reason_for`; `LegalOrders.call` |
| `adjudicator/lib/trucebearer/adjudicator.rb` | edit | Require the file; define `TA.legal_orders` |
| `adjudicator/spec/support/legal_positions.rb` | create | Sample positions, the stress position, the random boards, the candidate space |
| `adjudicator/spec/trucebearer/adjudicator/legal_orders_spec.rb` | create | Stories 1 to 4, AC-7.5 |
| `adjudicator/spec/trucebearer/adjudicator/legal_orders_agreement_spec.rb` | create | Story 5 |
| `adjudicator/spec/trucebearer/adjudicator/legal_orders_performance_spec.rb` | create | Story 6 |
| `adjudicator/spec/trucebearer/adjudicator/legal_orders_examples_spec.rb` | create | AC-7.1 |
| `adjudicator/spec/trucebearer/adjudicator/interface_examples_spec.rb` | edit | Header comment (AC-7.2) |
| `adjudicator/CHANGELOG.md` | edit | "Unreleased → Added" entry (AC-7.3) |
| `adjudicator/docs/specs/012-legal-orders/{spec,plan}.md` | create | This feature's spec and plan |

---

## Phase 1: The first spec, the generator and the list rules

**Implements:** FR-1, FR-2. **Satisfies:** AC-1.1 to AC-1.3, AC-2.1 to AC-2.3, AC-3.1 to AC-3.9, AC-4.1 to AC-4.4, AC-7.5.

**Goal:** `TA.legal_orders` exists and gives the right list for the contract's examples and every list rule.

### Step 1: The first spec, red, committed alone

Create `spec/trucebearer/adjudicator/legal_orders_spec.rb` holding only the contract's first example (AC-1.1, AC-1.2):

```ruby
# frozen_string_literal: true

require "trucebearer/adjudicator"
require_relative "../../support/board"

# TA.legal_orders: the list of the legal orders of one unit (Stories 1 to 4 of spec 012).
# The first example of docs/interface.md `## Legal orders` is the first spec of the feature.
RSpec.describe "TA.legal_orders" do
  let(:start) { TA::Map.classic.starting_position }
  let(:london_fleet) { Board.unit(:england, :fleet, "lon") }

  describe "the first example (AC-1.1, AC-1.2)" do
    it "starts with the hold, then the moves to eng and nth, for England's fleet in London" do
      expect(TA.legal_orders(start, london_fleet).first(3)).to eq(
        [O::Hold.new(power: :england, at: :lon),
         O::Move.new(power: :england, at: :lon, destination: L.new(province: :eng)),
         O::Move.new(power: :england, at: :lon, destination: L.new(province: :nth))]
      )
    end

    it "is empty for a French fleet in London, where no such unit stands" do
      expect(TA.legal_orders(start, Board.unit(:france, :fleet, "lon"))).to eq([])
    end
  end
end
```

Run `bundle exec rspec spec/trucebearer/adjudicator/legal_orders_spec.rb`. Expected: both fail with `NoMethodError: undefined method 'legal_orders'`. Commit the file alone: `Add the first spec for listing a unit's legal orders`.

### Step 2: The sample positions the list specs need

Create `spec/support/legal_positions.rb`. Phase 2 adds the rest of this module with `Edit` (the stress position, the random boards, the sample list and the candidate space).

```ruby
# frozen_string_literal: true

require "trucebearer/adjudicator"
require_relative "board"

# The positions the legal-orders specs share, and the whole candidate space of a unit.
# Positions are built the way docs/interface.md builds its examples where it has one.
module LegalPositions
  module_function

  def start = TA::Map.classic.starting_position

  # French fleets in the Mid-Atlantic and the Gulf of Lyon (the interface's `at_sea`).
  def at_sea = Board.position(Board.unit(:france, :fleet, "mao"), Board.unit(:france, :fleet, "gol"))

  # England's army in London and fleet in the North Sea (the interface's `ln`).
  def ln = Board.position(Board.unit(:england, :army, "lon"), Board.unit(:england, :fleet, "nth"))

  # A fleet that a one-fleet chain bypasses (the shape of 6.G.19).
  def bypassed
    Board.position(Board.unit(:france, :army, "mar"), Board.unit(:france, :fleet, "wes"),
                   Board.unit(:italy, :fleet, "gol"), Board.unit(:italy, :army, "spa"))
  end

  # The only chain is two fleets, of two powers.
  def two_fleet_chain
    Board.position(Board.unit(:england, :army, "lon"), Board.unit(:england, :fleet, "eng"),
                   Board.unit(:france, :fleet, "mao"))
  end

  # A sea fleet that touches a chain fleet but neither end (the shape of 6.F.12).
  def no_chain_through
    Board.position(Board.unit(:england, :army, "lon"), Board.unit(:england, :fleet, "eng"),
                   Board.unit(:england, :fleet, "iri"), Board.unit(:england, :fleet, "nth"))
  end

  # Fleets on bul/ec, spa/nc and stp/nc, with neighbors. A position holds one unit per
  # province, so the six split coasts need two positions.
  def north_coasts
    Board.position(
      Board.unit(:turkey, :fleet, "bul/ec"), Board.unit(:turkey, :army, "con"), Board.unit(:russia, :fleet, "bla"),
      Board.unit(:austria, :army, "rum"), Board.unit(:france, :fleet, "spa/nc"), Board.unit(:france, :army, "gas"),
      Board.unit(:france, :fleet, "mao"), Board.unit(:italy, :army, "por"), Board.unit(:russia, :fleet, "stp/nc"),
      Board.unit(:england, :fleet, "bar"), Board.unit(:germany, :army, "nwy")
    )
  end

  # Fleets on bul/sc, spa/sc and stp/sc, with neighbors.
  def south_coasts
    Board.position(
      Board.unit(:turkey, :fleet, "bul/sc"), Board.unit(:turkey, :army, "gre"), Board.unit(:italy, :fleet, "aeg"),
      Board.unit(:austria, :army, "ser"), Board.unit(:france, :fleet, "spa/sc"), Board.unit(:france, :army, "mar"),
      Board.unit(:france, :fleet, "gol"), Board.unit(:italy, :fleet, "wes"), Board.unit(:russia, :fleet, "stp/sc"),
      Board.unit(:russia, :fleet, "bot"), Board.unit(:russia, :army, "fin"), Board.unit(:germany, :army, "lvn")
    )
  end
end
```

### Step 3: The list-rule specs, red

Add to `legal_orders_spec.rb`, inside the same `RSpec.describe`, after the first-example block. Add `require_relative "../../support/legal_positions"` below the `board` require.

```ruby
  # An independent source of truth for fleet moves: the map's own adjacency.
  def fleet_destinations(unit)
    Board.fleet_locations.select do |place|
      place.province != unit.location.province && TA::Map.classic.adjacent?(:fleet, unit.location, place)
    end.sort_by { |place| [place.province.to_s, place.coast.to_s] }
  end

  def moves_of(list) = list.grep(O::Move)

  describe "the shape of the list (AC-1.3, AC-3.1)" do
    it "starts with the unit's hold and names the unit's owner and province in every order" do
      LegalPositions.start.units.each do |unit|
        list = TA.legal_orders(LegalPositions.start, unit)
        expect(list.first).to eq(O::Hold.new(power: unit.power, at: unit.location.province))
        expect(list.map(&:power).uniq).to eq([unit.power])
        expect(list.map(&:at).uniq).to eq([unit.location.province])
      end
    end

    it "returns an array the caller owns: not frozen, and changing it changes nothing later" do
      list = TA.legal_orders(start, london_fleet)
      expect(list).not_to be_frozen
      list.clear
      expect(TA.legal_orders(start, london_fleet)).not_to be_empty
    end
  end

  describe "an empty list, never an exception (AC-2.1, AC-2.2)" do
    it "is empty in the retreat phase and in the adjustment phase, for a unit that is on the board" do
      unit = Board.unit(:england, :army, "lon")
      %i[retreat adjustment].each do |phase|
        expect(TA.legal_orders(Board.position(unit, phase: phase), unit)).to eq([])
      end
    end

    it "is empty for a unit that is not on the board" do
      position = Board.position(Board.unit(:england, :fleet, "lon"), Board.unit(:russia, :fleet, "stp/sc"))
      expect(TA.legal_orders(position, Board.unit(:england, :fleet, "wal"))).to eq([])      # nothing there
      expect(TA.legal_orders(position, Board.unit(:france, :fleet, "lon"))).to eq([])       # another power
      expect(TA.legal_orders(position, Board.unit(:england, :army, "lon"))).to eq([])       # another type
      expect(TA.legal_orders(position, Board.unit(:russia, :fleet, "stp/nc"))).to eq([])    # the other coast
    end
  end

  describe "arguments of the wrong class (AC-2.3)" do
    it "raises InvalidInput naming the argument, for a position that is not a position" do
      [nil, start.to_h, :start, london_fleet].each do |bad|
        expect { TA.legal_orders(bad, london_fleet) }
          .to raise_error(TA::InvalidInput, /#{Regexp.escape(bad.inspect)}/)
      end
    end

    it "raises InvalidInput naming the argument, for a unit that is not a unit" do
      [nil, london_fleet.to_h, :lon, O::Hold.new(power: :england, at: :lon)].each do |bad|
        expect { TA.legal_orders(start, bad) }
          .to raise_error(TA::InvalidInput, /#{Regexp.escape(bad.inspect)}/)
      end
    end
  end

  describe "what is in the list" do
    it "includes supports nobody has ordered, for any power's unit (AC-3.2)" do
      vie = Board.unit(:austria, :army, "vie")
      list = TA.legal_orders(start, vie)
      expect(list).to include(O::SupportMove.new(power: :austria, at: :vie, from: :war, to: :gal))
      expect(list.grep(O::SupportHold).map(&:target)).to eq(%i[bud tri])
    end

    it "gives one move for each coast a fleet can reach, and none without a coast (AC-3.3)" do
      spa = ->(position, unit) { moves_of(TA.legal_orders(position, unit)).select { _1.destination.province == :spa } }
      expect(spa.(LegalPositions.at_sea, Board.unit(:france, :fleet, "mao")).map { _1.destination.coast }).to eq(%i[nc sc])
      expect(spa.(LegalPositions.at_sea, Board.unit(:france, :fleet, "gol")).map { _1.destination.coast }).to eq([:sc])
      gascony = Board.unit(:france, :fleet, "gas")
      expect(spa.(Board.position(gascony), gascony).map { _1.destination.coast }).to eq([:nc])
    end

    it "judges a fleet's moves from the coast it stands on, and never lists its own province (AC-3.4)" do
      [Board.unit(:russia, :fleet, "stp/sc"), Board.unit(:russia, :fleet, "stp/nc"),
       Board.unit(:france, :fleet, "spa/nc"), Board.unit(:france, :fleet, "spa/sc"),
       Board.unit(:turkey, :fleet, "bul/ec"), Board.unit(:turkey, :fleet, "bul/sc")].each do |unit|
        destinations = moves_of(TA.legal_orders(Board.position(unit), unit)).map(&:destination)
        expect(destinations).to eq(fleet_destinations(unit))
        expect(destinations.map(&:province)).not_to include(unit.location.province)
      end
    end

    it "gives an army one move via convoy only where it can also walk, and a plain move wherever a chain reaches (AC-3.5)" do
      army = Board.unit(:england, :army, "lon")
      list = TA.legal_orders(LegalPositions.ln, army)
      expect(list.grep(O::MoveViaConvoy).map(&:to)).to eq([:yor])
      expect(moves_of(list).map { _1.destination.province }).to eq(%i[bel den edi hol nwy wal yor])
      expect(moves_of(list).map { _1.destination.coast }.uniq).to eq([nil])
    end

    it "gives a fleet no move via convoy and no move a chain alone could make, and an inland army none (AC-3.6)" do
      nth = Board.unit(:england, :fleet, "nth")
      list = TA.legal_orders(LegalPositions.ln, nth)
      expect(list.grep(O::MoveViaConvoy)).to eq([])
      expect(moves_of(list).map(&:destination)).to eq(fleet_destinations(nth))

      munich = Board.unit(:germany, :army, "mun")
      by_land = TA::Map.classic.provinces.map(&:id).select do |id|
        id != :mun && TA::Map.classic.adjacent?(:army, L.new(province: :mun), L.new(province: id))
      end
      with_fleet = Board.position(munich, Board.unit(:england, :fleet, "nth"))
      expect(moves_of(TA.legal_orders(with_fleet, munich)).map { _1.destination.province }).to eq(by_land.sort_by(&:to_s))
    end

    it "gives a convoy exactly to the fleets on a minimal chain (AC-3.7)" do
      bypassed = LegalPositions.bypassed
      expect(TA.legal_orders(bypassed, Board.unit(:italy, :fleet, "gol")))
        .to include(O::Convoy.new(power: :italy, at: :gol, from: :mar, to: :spa))
      expect(TA.legal_orders(bypassed, Board.unit(:france, :fleet, "wes")))
        .not_to include(O::Convoy.new(power: :france, at: :wes, from: :mar, to: :spa))

      two = LegalPositions.two_fleet_chain
      expect(TA.legal_orders(two, Board.unit(:england, :fleet, "eng")))
        .to include(O::Convoy.new(power: :england, at: :eng, from: :lon, to: :por))
      expect(TA.legal_orders(two, Board.unit(:france, :fleet, "mao")))
        .to include(O::Convoy.new(power: :france, at: :mao, from: :lon, to: :por))

      shape = LegalPositions.no_chain_through
      expect(TA.legal_orders(shape, Board.unit(:england, :fleet, "iri")))
        .not_to include(O::Convoy.new(power: :england, at: :iri, from: :lon, to: :bel))
    end

    it "depends on the position alone, and changes neither argument (AC-3.8)" do
      ln = LegalPositions.ln
      reversed = TA::Position.new(map: "classic", season: :spring, year: 1901, phase: :movement, ownership: {},
                                  dislodged_units: [], standoffs: [], units: ln.units.reverse)
      army = Board.unit(:england, :army, "lon")
      before = [ln.to_h, army.to_h]
      expect(TA.legal_orders(reversed, army)).to eq(TA.legal_orders(ln, army))
      expect([ln.to_h, army.to_h]).to eq(before)
    end

    it "gives a lone unit its hold and its moves only (AC-3.9)" do
      lone = Board.unit(:france, :fleet, "mao")
      list = TA.legal_orders(Board.position(lone), lone)
      expect(list.map(&:class).uniq).to eq([O::Hold, O::Move])
      expect(list.size).to eq(1 + fleet_destinations(lone).size)
    end
  end

  describe "the order of the list (AC-4.1 to AC-4.4)" do
    def groups = [O::Hold, O::Move, O::MoveViaConvoy, O::SupportHold, O::SupportMove, O::Convoy]

    def sort_key(order)
      case order
      when O::Hold then []
      when O::Move then [order.destination.province.to_s, order.destination.coast.to_s]
      when O::MoveViaConvoy then [order.to.to_s]
      when O::SupportHold then [order.target.to_s]
      when O::SupportMove then [order.from.to_s, order.to.to_s]
      when O::Convoy then [order.from.to_s, order.to.to_s]
      end
    end

    def lists
      [LegalPositions.start, LegalPositions.ln, LegalPositions.at_sea, LegalPositions.north_coasts,
       LegalPositions.south_coasts].flat_map do |position|
        position.units.map { |unit| [position, TA.legal_orders(position, unit)] }
      end
    end

    it "puts the six groups in the contract's order, none interleaved (AC-4.1)" do
      lists.each do |_, list|
        ranks = list.map { |order| groups.index(order.class) }
        expect(ranks).to eq(ranks.sort)
      end
    end

    it "sorts each group as the contract says (AC-4.2)" do
      lists.each do |_, list|
        list.group_by(&:class).each_value do |group|
          expect(group.map { sort_key(_1) }).to eq(group.map { sort_key(_1) }.sort)
        end
      end
    end

    it "gives the same list on every call and from a rebuilt position, with no duplicate (AC-4.3, AC-4.4)" do
      lists.each do |position, list|
        unit = position.units.find { |candidate| candidate.location.province == list.first.at }
        rebuilt = TA::Position.from_h(position.to_h)
        expect(TA.legal_orders(position, unit)).to eq(list)
        expect(TA.legal_orders(rebuilt, unit)).to eq(list)
        expect(list.uniq.size).to eq(list.size)
      end
    end
  end

  describe "the public surface (AC-7.5)" do
    it "adds only legal_orders, and keeps the generator private" do
      expect(TA.singleton_methods(false)).to contain_exactly(:check, :legal_orders)
      expect(TA.constants).to contain_exactly(:CheckResult, :DislodgedUnit, :InvalidInput, :Location, :Map,
                                              :Order, :Position, :Unit, :VERSION)
      expect { TA::LegalOrders }.to raise_error(NameError, /private constant/)
    end
  end
```

Run it. Expected: every example fails with `NoMethodError: undefined method 'legal_orders'` (the surface example fails on the method list). Nothing is committed yet.

### Step 4: The generator and the wiring

Create `lib/trucebearer/adjudicator/legal_orders.rb`:

```ruby
# frozen_string_literal: true

module Trucebearer
  module Adjudicator
    # Internal: the legal orders of one unit (docs/interface.md `## Legal orders`).
    # It builds only the orders that could possibly be legal (the narrowings N1 to N4 of
    # spec 012), in the contract's list order, and `Check.reason_for` decides each one. So
    # the list can never hold an order that TA.check refuses, and the generator applies
    # no other test of its own.
    module LegalOrders
      SORTED_COASTAL = Reach::COASTAL.sort_by(&:to_s).freeze

      module_function

      def call(position, unit)
        Shape.instance_of!(position, Position, "position")
        Shape.instance_of!(unit, Unit, "unit")
        return [] unless position.phase == :movement && position.units.include?(unit)

        candidates(position, unit).select { |order| Check.reason_for(position, order).nil? }
      end

      # Every order that could be legal, grouped and sorted as the contract lists them.
      def candidates(position, unit)
        power = unit.power
        at = unit.location.province
        occupied = position.units.map { |other| other.location.province }.sort_by(&:to_s)
        steps = step_provinces(unit)

        [Order::Hold.new(power: power, at: at)] +
          move_destinations(unit).map { |to| Order::Move.new(power: power, at: at, destination: to) } +
          via_convoy_targets(unit, steps).map { |to| Order::MoveViaConvoy.new(power: power, at: at, to: to) } +
          occupied.map { |target| Order::SupportHold.new(power: power, at: at, target: target) } +
          occupied.product(steps).map { |from, to| Order::SupportMove.new(power: power, at: at, from: from, to: to) } +
          convoy_pairs(position, unit).map { |from, to| Order::Convoy.new(power: power, at: at, from: from, to: to) }
      end

      # N1: where a move could go, by destination province and then coast. An army on a
      # coastal province may also go to any coastal province, because a chain could carry it.
      def move_destinations(unit)
        location = unit.location
        places =
          if unit.type == :army
            provinces = Reach::ARMY_STEPS.fetch(location.province)
            provinces |= Reach::COASTAL if Reach::COASTAL.include?(location.province)
            provinces.map { |province| [province, nil] }
          else
            Reach::FLEET_STEPS.fetch([location.province, location.coast])
          end
        places.sort_by { |province, coast| [province.to_s, coast.to_s] }
              .map { |province, coast| Location.new(province: province, coast: coast) }
      end

      # The provinces the unit reaches in one step, by identifier.
      def step_provinces(unit)
        location = unit.location
        provinces =
          if unit.type == :army
            Reach::ARMY_STEPS.fetch(location.province)
          else
            Reach::FLEET_STEPS.fetch([location.province, location.coast]).map(&:first)
          end
        provinces.uniq.sort_by(&:to_s)
      end

      # N2: only an army, and only to a province it reaches by land.
      def via_convoy_targets(unit, steps)
        unit.type == :army ? steps : []
      end

      # N4: only a fleet in a sea province, from a province that holds an army, to a coastal province.
      def convoy_pairs(position, unit)
        return [] unless unit.type == :fleet && Reach::SEAS.include?(unit.location.province)

        armies = position.units.select { |other| other.type == :army }.map { |other| other.location.province }
        armies.sort_by(&:to_s).product(SORTED_COASTAL)
      end
    end
    private_constant :LegalOrders
  end
end
```

(N3 is the `occupied` list for supports to hold, and `occupied` crossed with `steps` for supports to move, in `candidates`.)

Edit `lib/trucebearer/adjudicator.rb`: add `require_relative "adjudicator/legal_orders"` after the `check` require, and below `TA.check`:

```ruby
    # Lists every order that is legal for one unit, in a fixed order (docs/interface.md,
    # "Legal orders"). Empty when the position isn't in a movement phase or the unit isn't on
    # the board. Raises InvalidInput only for an argument of the wrong class.
    def self.legal_orders(position, unit) = LegalOrders.call(position, unit)
```

Run `bundle exec rspec spec/trucebearer/adjudicator/legal_orders_spec.rb`, expect green (the first two examples too). Fix by changing the **generator or the spec's expectation after checking the contract**, never by loosening an expectation to fit. Then run the whole suite: `bundle exec rspec` must be green with #11's specs unchanged. Commit the supporting module, the generator, the wiring and the spec additions: `Add TA.legal_orders and the specs for its list rules`.

**Verifies:** the hold, `eng`, `nth` example; every list rule; the empty cases; the errors; the order; AC-7.5.

---

## Phase 2: The agreement spec

**Implements:** the agreement proof. **Satisfies:** AC-5.1 to AC-5.5.

**Goal:** the list and `TA.check` are proved to say the same thing, over each unit's whole candidate space, on hand-picked positions and fixed-seed random boards.

### Step 1: Extend the sample positions (Edit `spec/support/legal_positions.rb`)

Add these methods inside `module LegalPositions`, before the closing `end` (`north_coasts` and `south_coasts` already exist from Phase 1):

```ruby
  # A fleet in each of the 19 sea provinces and an army in each of the first 20 coastal
  # provinces by identifier, the seven powers dealt in turn in identifier order.
  def stress
    powers = Board.powers.sort_by(&:to_s)
    seas = Board.sea.sort_by(&:to_s)
    coastal = Board.map.provinces.select { |province| province.type == :coastal }.map(&:id).sort_by(&:to_s).first(20)
    units = seas.each_with_index.map { |id, i| Board.unit(powers[i % 7], :fleet, id.to_s) } +
            coastal.each_with_index.map { |id, i| Board.unit(powers[i % 7], :army, id.to_s) }
    Board.position(*units)
  end

  # [seed, armies, fleets at sea, fleets on a coast]. The first board has 34 units and is
  # the mid-game board of the speed target.
  RANDOM_BOARDS = [[1, 22, 8, 4], [2, 18, 6, 4], [3, 12, 3, 3], [4, 8, 2, 2], [5, 3, 1, 1], [6, 3, 2, 0]].freeze

  def random_board(seed, armies, sea_fleets, coast_fleets)
    rng = Random.new(seed)
    powers = Board.powers.sort_by(&:to_s)
    seas = Board.sea.sort_by(&:to_s).shuffle(random: rng).first(sea_fleets)
    coastal = Board.map.provinces.select { |province| province.type == :coastal }.sort_by { _1.id.to_s }
    split, plain = coastal.partition { |province| !province.coasts.empty? }
    # The first coast fleet always stands on a split coast, so the boards exercise them.
    on_coast = split.shuffle(random: rng).first(coast_fleets.clamp(0, 1)) +
               plain.shuffle(random: rng).first([coast_fleets - 1, 0].max)
    land = (Board.army_provinces - on_coast.map(&:id)).sort_by(&:to_s).shuffle(random: rng).first(armies)
    coast_places = on_coast.map do |province|
      province.coasts.empty? ? province.id.to_s : "#{province.id}/#{province.coasts.sort.sample(random: rng)}"
    end
    units = (seas.map(&:to_s) + coast_places).map { |place| [:fleet, place] } + land.map { |id| [:army, id.to_s] }
    Board.position(*units.each_with_index.map { |(type, place), i| Board.unit(powers[i % 7], type, place) })
  end

  def random_boards = RANDOM_BOARDS.map { |seed, *counts| random_board(seed, *counts) }

  # The sampled positions of AC-5.3, by name.
  def samples
    { "the starting position" => start, "fleets on the north coasts" => north_coasts,
      "fleets on the south coasts" => south_coasts, "the interface's at_sea" => at_sea, "ln" => ln,
      "a fleet bypassed by a shorter chain" => bypassed, "a chain of two fleets" => two_fleet_chain,
      "a fleet with no chain through it" => no_chain_through, "the stress position" => stress }
      .merge(random_boards.each_with_index.to_h { |position, i| ["random board #{i + 1}", position] })
  end

  # Every order the six classes can form for the unit's owner and province, with every
  # province and every location: 11,482 orders. Built fresh each time.
  def candidates(unit)
    power = unit.power
    at = unit.location.province
    provinces = Board.provinces
    [O::Hold.new(power: power, at: at)] +
      Board.locations.map { |to| O::Move.new(power: power, at: at, destination: to) } +
      provinces.map { |to| O::MoveViaConvoy.new(power: power, at: at, to: to) } +
      provinces.map { |target| O::SupportHold.new(power: power, at: at, target: target) } +
      provinces.product(provinces).map { |from, to| O::SupportMove.new(power: power, at: at, from: from, to: to) } +
      provinces.product(provinces).map { |from, to| O::Convoy.new(power: power, at: at, from: from, to: to) }
  end

```

`random_board` and `stress` build units on distinct provinces by construction (fleets on seas or on coastal provinces, armies on the other land provinces). Check it by running `ruby -Ilib -Ispec -e 'require "support/legal_positions"; LegalPositions.samples.each { |n, p| puts "#{n}: #{p.units.size} units, split coasts: #{p.units.select { _1.location.coast }.size}" }'`. Expected: the starting position 22, the stress position 39, and the six random boards 34, 28, 18, 12, 5 and 5 units, with one split-coast fleet on each of boards 1 to 5 (the plan review confirmed these counts, and that the seeds give `spa/sc`, `bul/ec`, `spa/nc`, `spa/sc` and `bul/sc`).

### Step 2: The agreement spec, then watch it guard

Create `spec/trucebearer/adjudicator/legal_orders_agreement_spec.rb`:

```ruby
# frozen_string_literal: true

require "trucebearer/adjudicator"
require_relative "../../support/board"
require_relative "../../support/legal_positions"

# TA.legal_orders and TA.check say the same thing (Story 5). For every unit of every
# sampled position, every listed order passes TA.check (AC-5.1), and every order of the
# unit's whole candidate space that passes TA.check is listed (AC-5.2). The candidate space
# is built here, not by the generator, so a narrowing that is too tight can't hide.
# It takes about 12 seconds in all, so it is tagged :slow. The tag only names it: .rspec has no
# filter and CI runs `bundle exec rspec`, so it runs in CI with everything else.
RSpec.describe "TA.legal_orders agrees with TA.check", :slow do
  it "builds a candidate space of 11,482 orders for a unit" do
    expect(LegalPositions.candidates(Board.unit(:england, :fleet, "lon")).size).to eq(11_482)
  end

  LegalPositions.samples.each do |name, position|
    it "agrees in both directions for every unit of #{name}" do
      aggregate_failures do
        position.units.each do |unit|
          listed = TA.legal_orders(position, unit)
          passing = LegalPositions.candidates(unit).select { |order| TA.check(position, order).legal }

          extra = listed - passing
          missing = passing - listed
          expect(extra).to eq([]), "#{unit.inspect}: listed but refused by TA.check, e.g. #{extra.first(3).inspect}"
          expect(missing).to eq([]), "#{unit.inspect}: legal but not listed, e.g. #{missing.first(3).inspect}"
          expect(listed.size).to eq(listed.uniq.size), "#{unit.inspect}: the list holds a duplicate"
        end
      end
    end
  end

  %i[retreat adjustment].each do |phase|
        expect(TA.legal_orders(Board.position(unit, phase: phase), unit)).to eq([])
      end
    end

    it "is empty for a unit that is not on the board" do
      position = Board.position(Board.unit(:england, :fleet, "lon"), Board.unit(:russia, :fleet, "stp/sc"))
      expect(TA.legal_orders(position, Board.unit(:england, :fleet, "wal"))).to eq([])      # nothing there
      expect(TA.legal_orders(position, Board.unit(:france, :fleet, "lon"))).to eq([])       # another power
      expect(TA.legal_orders(position, Board.unit(:england, :army, "lon"))).to eq([])       # another type
      expect(TA.legal_orders(position, Board.unit(:russia, :fleet, "stp/nc"))).to eq([])    # the other coast
    end
  end

  describe "arguments of the wrong class (AC-2.3)" do
    it "raises InvalidInput naming the argument, for a position that is not a position" do
      [nil, start.to_h, :start, london_fleet].each do |bad|
        expect { TA.legal_orders(bad, london_fleet) }
          .to raise_error(TA::InvalidInput, /#{Regexp.escape(bad.inspect)}/)
      end
    end

    it "raises InvalidInput naming the argument, for a unit that is not a unit" do
      [nil, london_fleet.to_h, :lon, O::Hold.new(power: :england, at: :lon)].each do |bad|
        expect { TA.legal_orders(start, bad) }
          .to raise_error(TA::InvalidInput, /#{Regexp.escape(bad.inspect)}/)
      end
    end
  end

  describe "what is in the list" do
    it "includes supports nobody has ordered, for any power's unit (AC-3.2)" do
      vie = Board.unit(:austria, :army, "vie")
      list = TA.legal_orders(start, vie)
      expect(list).to include(O::SupportMove.new(power: :austria, at: :vie, from: :war, to: :gal))
      expect(list.grep(O::SupportHold).map(&:target)).to eq(%i[bud tri])
    end

    it "gives one move for each coast a fleet can reach, and none without a coast (AC-3.3)" do
      spa = ->(position, unit) { moves_of(TA.legal_orders(position, unit)).select { _1.destination.province == :spa } }
      expect(spa.(LegalPositions.at_sea, Board.unit(:france, :fleet, "mao")).map { _1.destination.coast }).to eq(%i[nc sc])
      expect(spa.(LegalPositions.at_sea, Board.unit(:france, :fleet, "gol")).map { _1.destination.coast }).to eq([:sc])
      gascony = Board.unit(:france, :fleet, "gas")
      expect(spa.(Board.position(gascony), gascony).map { _1.destination.coast }).to eq([:nc])
    end

    it "judges a fleet's moves from the coast it stands on, and never lists its own province (AC-3.4)" do
      [Board.unit(:russia, :fleet, "stp/sc"), Board.unit(:russia, :fleet, "stp/nc"),
       Board.unit(:france, :fleet, "spa/nc"), Board.unit(:france, :fleet, "spa/sc"),
       Board.unit(:turkey, :fleet, "bul/ec"), Board.unit(:turkey, :fleet, "bul/sc")].each do |unit|
        destinations = moves_of(TA.legal_orders(Board.position(unit), unit)).map(&:destination)
        expect(destinations).to eq(fleet_destinations(unit))
        expect(destinations.map(&:province)).not_to include(unit.location.province)
      end
    end

    it "gives an army one move via convoy only where it can also walk, and a plain move wherever a chain reaches (AC-3.5)" do
      army = Board.unit(:england, :army, "lon")
      list = TA.legal_orders(LegalPositions.ln, army)
      expect(list.grep(O::MoveViaConvoy).map(&:to)).to eq([:yor])
      expect(moves_of(list).map { _1.destination.province }).to eq(%i[bel den edi hol nwy wal yor])
      expect(moves_of(list).map { _1.destination.coast }.uniq).to eq([nil])
    end

    it "gives a fleet no move via convoy and no move a chain alone could make, and an inland army none (AC-3.6)" do
      nth = Board.unit(:england, :fleet, "nth")
      list = TA.legal_orders(LegalPositions.ln, nth)
      expect(list.grep(O::MoveViaConvoy)).to eq([])
      expect(moves_of(list).map(&:destination)).to eq(fleet_destinations(nth))

      munich = Board.unit(:germany, :army, "mun")
      by_land = TA::Map.classic.provinces.map(&:id).select do |id|
        id != :mun && TA::Map.classic.adjacent?(:army, L.new(province: :mun), L.new(province: id))
      end
      with_fleet = Board.position(munich, Board.unit(:england, :fleet, "nth"))
      expect(moves_of(TA.legal_orders(with_fleet, munich)).map { _1.destination.province }).to eq(by_land.sort_by(&:to_s))
    end

    it "gives a convoy exactly to the fleets on a minimal chain (AC-3.7)" do
      bypassed = LegalPositions.bypassed
      expect(TA.legal_orders(bypassed, Board.unit(:italy, :fleet, "gol")))
        .to include(O::Convoy.new(power: :italy, at: :gol, from: :mar, to: :spa))
      expect(TA.legal_orders(bypassed, Board.unit(:france, :fleet, "wes")))
        .not_to include(O::Convoy.new(power: :france, at: :wes, from: :mar, to: :spa))

      two = LegalPositions.two_fleet_chain
      expect(TA.legal_orders(two, Board.unit(:england, :fleet, "eng")))
        .to include(O::Convoy.new(power: :england, at: :eng, from: :lon, to: :por))
      expect(TA.legal_orders(two, Board.unit(:france, :fleet, "mao")))
        .to include(O::Convoy.new(power: :france, at: :mao, from: :lon, to: :por))

      shape = LegalPositions.no_chain_through
      expect(TA.legal_orders(shape, Board.unit(:england, :fleet, "iri")))
        .not_to include(O::Convoy.new(power: :england, at: :iri, from: :lon, to: :bel))
    end

    it "depends on the position alone, and changes neither argument (AC-3.8)" do
      ln = LegalPositions.ln
      reversed = TA::Position.new(map: "classic", season: :spring, year: 1901, phase: :movement, ownership: {},
                                  dislodged_units: [], standoffs: [], units: ln.units.reverse)
      army = Board.unit(:england, :army, "lon")
      before = [ln.to_h, army.to_h]
      expect(TA.legal_orders(reversed, army)).to eq(TA.legal_orders(ln, army))
      expect([ln.to_h, army.to_h]).to eq(before)
    end

    it "gives a lone unit its hold and its moves only (AC-3.9)" do
      lone = Board.unit(:france, :fleet, "mao")
      list = TA.legal_orders(Board.position(lone), lone)
      expect(list.map(&:class).uniq).to eq([O::Hold, O::Move])
      expect(list.size).to eq(1 + fleet_destinations(lone).size)
    end
  end

  describe "the order of the list (AC-4.1 to AC-4.4)" do
    def groups = [O::Hold, O::Move, O::MoveViaConvoy, O::SupportHold, O::SupportMove, O::Convoy]

    def sort_key(order)
      case order
      when O::Hold then []
      when O::Move then [order.destination.province.to_s, order.destination.coast.to_s]
      when O::MoveViaConvoy then [order.to.to_s]
      when O::SupportHold then [order.target.to_s]
      when O::SupportMove then [order.from.to_s, order.to.to_s]
      when O::Convoy then [order.from.to_s, order.to.to_s]
      end
    end

    def lists
      [LegalPositions.start, LegalPositions.ln, LegalPositions.at_sea, LegalPositions.north_coasts,
       LegalPositions.south_coasts].flat_map do |position|
        position.units.map { |unit| [position, TA.legal_orders(position, unit)] }
      end
    end

    it "puts the six groups in the contract's order, none interleaved (AC-4.1)" do
      lists.each do |_, list|
        ranks = list.map { |order| groups.index(order.class) }
        expect(ranks).to eq(ranks.sort)
      end
    end

    it "sorts each group as the contract says (AC-4.2)" do
      lists.each do |_, list|
        list.group_by(&:class).each_value do |group|
          expect(group.map { sort_key(_1) }).to eq(group.map { sort_key(_1) }.sort)
        end
      end
    end

    it "gives the same list on every call and from a rebuilt position, with no duplicate (AC-4.3, AC-4.4)" do
      lists.each do |position, list|
        unit = position.units.find { |candidate| candidate.location.province == list.first.at }
        rebuilt = TA::Position.from_h(position.to_h)
        expect(TA.legal_orders(position, unit)).to eq(list)
        expect(TA.legal_orders(rebuilt, unit)).to eq(list)
        expect(list.uniq.size).to eq(list.size)
      end
    end
  end

  describe "the public surface (AC-7.5)" do
    it "adds only legal_orders, and keeps the generator private" do
      expect(TA.singleton_methods(false)).to contain_exactly(:check, :legal_orders)
      expect(TA.constants).to contain_exactly(:CheckResult, :DislodgedUnit, :InvalidInput, :Location, :Map,
                                              :Order, :Position, :Unit, :VERSION)
      expect { TA::LegalOrders }.to raise_error(NameError, /private constant/)
    end
  end
```

Run it. Expected: every example fails with `NoMethodError: undefined method 'legal_orders'` (the surface example fails on the method list). Nothing is committed yet.

### Step 4: The generator and the wiring

Create `lib/trucebearer/adjudicator/legal_orders.rb`:

```ruby
# frozen_string_literal: true

module Trucebearer
  module Adjudicator
    # Internal: the legal orders of one unit (docs/interface.md `## Legal orders`).
    # It builds only the orders that could possibly be legal (the narrowings N1 to N4 of
    # spec 012), in the contract's list order, and `Check.reason_for` decides each one. So
    # the list can never hold an order that TA.check refuses, and the generator applies
    # no other test of its own.
    module LegalOrders
      SORTED_COASTAL = Reach::COASTAL.sort_by(&:to_s).freeze

      module_function

      def call(position, unit)
        Shape.instance_of!(position, Position, "position")
        Shape.instance_of!(unit, Unit, "unit")
        return [] unless position.phase == :movement && position.units.include?(unit)

        candidates(position, unit).select { |order| Check.reason_for(position, order).nil? }
      end

      # Every order that could be legal, grouped and sorted as the contract lists them.
      def candidates(position, unit)
        power = unit.power
        at = unit.location.province
        occupied = position.units.map { |other| other.location.province }.sort_by(&:to_s)
        steps = step_provinces(unit)

        [Order::Hold.new(power: power, at: at)] +
          move_destinations(unit).map { |to| Order::Move.new(power: power, at: at, destination: to) } +
          via_convoy_targets(unit, steps).map { |to| Order::MoveViaConvoy.new(power: power, at: at, to: to) } +
          occupied.map { |target| Order::SupportHold.new(power: power, at: at, target: target) } +
          occupied.product(steps).map { |from, to| Order::SupportMove.new(power: power, at: at, from: from, to: to) } +
          convoy_pairs(position, unit).map { |from, to| Order::Convoy.new(power: power, at: at, from: from, to: to) }
      end

      # N1: where a move could go, by destination province and then coast. An army on a
      # coastal province may also go to any coastal province, because a chain could carry it.
      def move_destinations(unit)
        location = unit.location
        places =
          if unit.type == :army
            provinces = Reach::ARMY_STEPS.fetch(location.province)
            provinces |= Reach::COASTAL if Reach::COASTAL.include?(location.province)
            provinces.map { |province| [province, nil] }
          else
            Reach::FLEET_STEPS.fetch([location.province, location.coast])
          end
        places.sort_by { |province, coast| [province.to_s, coast.to_s] }
              .map { |province, coast| Location.new(province: province, coast: coast) }
      end

      # The provinces the unit reaches in one step, by identifier.
      def step_provinces(unit)
        location = unit.location
        provinces =
          if unit.type == :army
            Reach::ARMY_STEPS.fetch(location.province)
          else
            Reach::FLEET_STEPS.fetch([location.province, location.coast]).map(&:first)
          end
        provinces.uniq.sort_by(&:to_s)
      end

      # N2: only an army, and only to a province it reaches by land.
      def via_convoy_targets(unit, steps)
        unit.type == :army ? steps : []
      end

      # N4: only a fleet in a sea province, from a province that holds an army, to a coastal province.
      def convoy_pairs(position, unit)
        return [] unless unit.type == :fleet && Reach::SEAS.include?(unit.location.province)

        armies = position.units.select { |other| other.type == :army }.map { |other| other.location.province }
        armies.sort_by(&:to_s).product(SORTED_COASTAL)
      end
    end
    private_constant :LegalOrders
  end
end
```

(N3 is the `occupied` list for supports to hold, and `occupied` crossed with `steps` for supports to move, in `candidates`.)

Edit `lib/trucebearer/adjudicator.rb`: add `require_relative "adjudicator/legal_orders"` after the `check` require, and below `TA.check`:

```ruby
    # Lists every order that is legal for one unit, in a fixed order (docs/interface.md,
    # "Legal orders"). Empty when the position isn't in a movement phase or the unit isn't on
    # the board. Raises InvalidInput only for an argument of the wrong class.
    def self.legal_orders(position, unit) = LegalOrders.call(position, unit)
```

Run `bundle exec rspec spec/trucebearer/adjudicator/legal_orders_spec.rb`, expect green (the first two examples too). Fix by changing the **generator or the spec's expectation after checking the contract**, never by loosening an expectation to fit. Then run the whole suite: `bundle exec rspec` must be green with #11's specs unchanged. Commit the supporting module, the generator, the wiring and the spec additions: `Add TA.legal_orders and the specs for its list rules`.

**Verifies:** the hold, `eng`, `nth` example; every list rule; the empty cases; the errors; the order; AC-7.5.

---

## Phase 2: The agreement spec

**Implements:** the agreement proof. **Satisfies:** AC-5.1 to AC-5.5.

**Goal:** the list and `TA.check` are proved to say the same thing, over each unit's whole candidate space, on hand-picked positions and fixed-seed random boards.

### Step 1: Extend the sample positions (Edit `spec/support/legal_positions.rb`)

Add these methods inside `module LegalPositions`, before the closing `end` (`north_coasts` and `south_coasts` already exist from Phase 1):

```ruby
  # A fleet in each of the 19 sea provinces and an army in each of the first 20 coastal
  # provinces by identifier, the seven powers dealt in turn in identifier order.
  def stress
    powers = Board.powers.sort_by(&:to_s)
    seas = Board.sea.sort_by(&:to_s)
    coastal = Board.map.provinces.select { |province| province.type == :coastal }.map(&:id).sort_by(&:to_s).first(20)
    units = seas.each_with_index.map { |id, i| Board.unit(powers[i % 7], :fleet, id.to_s) } +
            coastal.each_with_index.map { |id, i| Board.unit(powers[i % 7], :army, id.to_s) }
    Board.position(*units)
  end

  # [seed, armies, fleets at sea, fleets on a coast]. The first board has 34 units and is
  # the mid-game board of the speed target.
  RANDOM_BOARDS = [[1, 22, 8, 4], [2, 18, 6, 4], [3, 12, 3, 3], [4, 8, 2, 2], [5, 3, 1, 1], [6, 3, 2, 0]].freeze

  def random_board(seed, armies, sea_fleets, coast_fleets)
    rng = Random.new(seed)
    powers = Board.powers.sort_by(&:to_s)
    seas = Board.sea.sort_by(&:to_s).shuffle(random: rng).first(sea_fleets)
    coastal = Board.map.provinces.select { |province| province.type == :coastal }.sort_by { _1.id.to_s }
    split, plain = coastal.partition { |province| !province.coasts.empty? }
    # The first coast fleet always stands on a split coast, so the boards exercise them.
    on_coast = split.shuffle(random: rng).first(coast_fleets.clamp(0, 1)) +
               plain.shuffle(random: rng).first([coast_fleets - 1, 0].max)
    land = (Board.army_provinces - on_coast.map(&:id)).sort_by(&:to_s).shuffle(random: rng).first(armies)
    coast_places = on_coast.map do |province|
      province.coasts.empty? ? province.id.to_s : "#{province.id}/#{province.coasts.sort.sample(random: rng)}"
    end
    units = (seas.map(&:to_s) + coast_places).map { |place| [:fleet, place] } + land.map { |id| [:army, id.to_s] }
    Board.position(*units.each_with_index.map { |(type, place), i| Board.unit(powers[i % 7], type, place) })
  end

  def random_boards = RANDOM_BOARDS.map { |seed, *counts| random_board(seed, *counts) }

  # The sampled positions of AC-5.3, by name.
  def samples
    { "the starting position" => start, "fleets on the north coasts" => north_coasts,
      "fleets on the south coasts" => south_coasts, "the interface's at_sea" => at_sea, "ln" => ln,
      "a fleet bypassed by a shorter chain" => bypassed, "a chain of two fleets" => two_fleet_chain,
      "a fleet with no chain through it" => no_chain_through, "the stress position" => stress }
      .merge(random_boards.each_with_index.to_h { |position, i| ["random board #{i + 1}", position] })
  end

  # Every order the six classes can form for the unit's owner and province, with every
  # province and every location: 11,482 orders. Built fresh each time.
  def candidates(unit)
    power = unit.power
    at = unit.location.province
    provinces = Board.provinces
    [O::Hold.new(power: power, at: at)] +
      Board.locations.map { |to| O::Move.new(power: power, at: at, destination: to) } +
      provinces.map { |to| O::MoveViaConvoy.new(power: power, at: at, to: to) } +
      provinces.map { |target| O::SupportHold.new(power: power, at: at, target: target) } +
      provinces.product(provinces).map { |from, to| O::SupportMove.new(power: power, at: at, from: from, to: to) } +
      provinces.product(provinces).map { |from, to| O::Convoy.new(power: power, at: at, from: from, to: to) }
  end

```

`random_board` and `stress` build units on distinct provinces by construction (fleets on seas or on coastal provinces, armies on the other land provinces). Check it by running `ruby -Ilib -Ispec -e 'require "support/legal_positions"; LegalPositions.samples.each { |n, p| puts "#{n}: #{p.units.size} units, split coasts: #{p.units.select { _1.location.coast }.size}" }'`. Expected: the starting position 22, the stress position 39, and the six random boards 34, 28, 18, 12, 5 and 5 units, with one split-coast fleet on each of boards 1 to 5 (the plan review confirmed these counts, and that the seeds give `spa/sc`, `bul/ec`, `spa/nc`, `spa/sc` and `bul/sc`).

### Step 2: The agreement spec, then watch it guard

Create `spec/trucebearer/adjudicator/legal_orders_agreement_spec.rb`:

```ruby
# frozen_string_literal: true

require "trucebearer/adjudicator"
require_relative "../../support/board"
require_relative "../../support/legal_positions"

# TA.legal_orders and TA.check say the same thing (Story 5). For every unit of every
# sampled position, every listed order passes TA.check (AC-5.1), and every order of the
# unit's whole candidate space that passes TA.check is listed (AC-5.2). The candidate space
# is built here, not by the generator, so a narrowing that is too tight can't hide.
# It takes about 12 seconds in all, so it is tagged :slow. The tag only names it: .rspec has no
# filter and CI runs `bundle exec rspec`, so it runs in CI with everything else.
RSpec.describe "TA.legal_orders agrees with TA.check", :slow do
  it "builds a candidate space of 11,482 orders for a unit" do
    expect(LegalPositions.candidates(Board.unit(:england, :fleet, "lon")).size).to eq(11_482)
  end

  LegalPositions.samples.each do |name, position|
    it "agrees in both directions for every unit of #{name}" do
      position.units.each do |unit|
        listed = TA.legal_orders(position, unit)
        passing = LegalPositions.candidates(unit).select { |order| TA.check(position, order).legal }

        extra = listed - passing
        missing = passing - listed
        aggregate_failures(unit.inspect) do
          expect(extra).to eq([]), "listed but refused by TA.check, e.g. #{extra.first(3).inspect}"
          expect(missing).to eq([]), "legal but not listed, e.g. #{missing.first(3).inspect}"
          expect(listed.size).to eq(listed.uniq.size)
        end
      end
    end
  end

  %i[retreat adjustment].each do |phase|
    it "agrees, with both sides empty, in the #{phase} phase" do
      position = TA::Position.from_h(LegalPositions.start.to_h.merge("phase" => phase.to_s))
      position.units.first(2).each do |unit|
        expect(TA.legal_orders(position, unit)).to eq([])
        expect(LegalPositions.candidates(unit).count { |order| TA.check(position, order).legal }).to eq(0)
      end
    end
  end
end
```

Run it with `bundle exec rspec spec/trucebearer/adjudicator/legal_orders_agreement_spec.rb`; it passes at once, because Phase 1 built the generator. Record the time `rspec` prints (the spec's running time for the pull request, and the check against "about 12 s").

**Prove it can fail (not committed):** in `legal_orders.rb`, temporarily change N1 so that a fleet's moves drop one coast (for example `.reject { |_, coast| coast == :nc }` after `FLEET_STEPS.fetch`). Run the spec: the north-coast sample must fail with "legal but not listed". Undo with `git checkout -- lib/trucebearer/adjudicator/legal_orders.rb`. Then temporarily make N4 require `unit.location.province` to touch `from` (an invented narrowing that is too tight) and confirm one of the convoy samples fails. Undo again the same way. Say in the pull request that both mutations were caught.

Run `bundle exec rspec`; green. State the measured time and that it is tagged `:slow` (which excludes nothing from CI) in the pull request. Commit: `Add the spec that checks the list against TA.check in both directions`.

**Verifies:** AC-5.1 to AC-5.4. AC-5.5 is the recorded time.

---

## Phase 3: The speed spec

**Implements:** the proof of speed. **Satisfies:** AC-6.1 to AC-6.3.

### Step 1: The spec

Create `spec/trucebearer/adjudicator/legal_orders_performance_spec.rb`:

```ruby
# frozen_string_literal: true

require "trucebearer/adjudicator"
require_relative "../../support/board"
require_relative "../../support/legal_positions"

# TA.legal_orders is fast enough to call for every unit on each page load (Story 6).
# The targets are in spec 012 (22 starting units under 100 ms, a 34-unit mid-game board
# under 250 ms, the stress position under 1 s). The ceilings here are far above them so a
# slow CI machine can't fail the spec; the ratio check is what notices a fall back to
# filtering every candidate through TA.check. If the ratio check ever flakes, drop it and keep
# the ceilings.
RSpec.describe "TA.legal_orders speed" do
  def seconds
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    yield
    Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
  end

  def median(values) = values.sort[values.size / 2]

  def list_every_unit(position) = position.units.map { |unit| TA.legal_orders(position, unit) }

  # Approach A: every candidate of the whole candidate space, through TA.check.
  def filter_every_candidate(position)
    position.units.map { |unit| LegalPositions.candidates(unit).select { |order| TA.check(position, order).legal } }
  end

  it "lists the 22 units of the starting position in under a second (AC-6.1)" do
    start = LegalPositions.start
    list_every_unit(start) # warm-up, not timed
    expect(median(Array.new(3) { seconds { list_every_unit(start) } })).to be < 1.0
  end

  it "lists the 39 units of the stress position in under five seconds (AC-6.2)" do
    stress = LegalPositions.stress
    list_every_unit(stress)
    expect(median(Array.new(3) { seconds { list_every_unit(stress) } })).to be < 5.0
  end

  it "is at least ten times faster than filtering every candidate, with the same orders (AC-6.3)" do
    start = LegalPositions.start
    list_every_unit(start)
    filter_every_candidate(start)
    listed = nil
    filtered = nil
    fast = median(Array.new(5) { seconds { listed = list_every_unit(start) } })
    slow = median(Array.new(3) { seconds { filtered = filter_every_candidate(start) } })

    expect(slow).to be >= 10 * fast
    expect(listed.zip(filtered).all? { |a, b| a.sort_by(&:inspect) == b.sort_by(&:inspect) }).to be(true)
  end
end
```

Run it. It passes at once (the generator exists), so confirm it can fail (not committed): temporarily add `sleep 0.05` as the first line of `LegalOrders.call`. The first example must then fail (22 × 0.05 s is over 1 s) and so must the ratio example (the listing is no longer 10 times faster). Undo with `git checkout -- lib/trucebearer/adjudicator/legal_orders.rb`.

### Step 2: Measure for the pull request

Measure with a throwaway script in the scratchpad, never committed, requiring `spec/support/legal_positions`: time `list_every_unit` for the starting position, the mid-game board (`random_boards.first`) and the stress position, and `filter_every_candidate` for the starting position, 5 runs each, medians. Record them for the pull request description with the machine (laptop, Ruby 4.0.10). Run `bundle exec rspec` (green) and commit the spec: `Add the spec that bounds how long listing takes`.

**Verifies:** AC-6.1 to AC-6.3. AC-6.4 is for the implementation review. AC-6.5 is the pull request text.

---

## Phase 4: The interface examples and the record

**Implements:** FR-3. **Satisfies:** AC-7.1 to AC-7.4.

### Step 1: The examples spec, then the header comment

Create `spec/trucebearer/adjudicator/legal_orders_examples_spec.rb` (every Ruby example under `## Legal orders`, built as the document builds it):

```ruby
# frozen_string_literal: true

require "trucebearer/adjudicator"
require_relative "../../support/board"

# Every Ruby example in docs/interface.md under "## Legal orders" (AC-7.1), built as the
# document builds it.
RSpec.describe "docs/interface.md examples: legal orders" do
  let(:start) { TA::Map.classic.starting_position }
  let(:fleet) { TA::Unit.new(power: :england, type: :fleet, location: L.new(province: :lon)) }
  let(:at_sea) do
    TA::Position.new(map: "classic", season: :spring, year: 1901, phase: :movement, ownership: {},
                     dislodged_units: [], standoffs: [],
                     units: [TA::Unit.new(power: :france, type: :fleet, location: L.new(province: :mao)),
                             TA::Unit.new(power: :france, type: :fleet, location: L.new(province: :gol))])
  end
  let(:retreat) { TA::Position.from_h(start.to_h.merge("phase" => "retreat")) }
  let(:ln) do
    TA::Position.new(map: "classic", season: :spring, year: 1901, phase: :movement, ownership: {},
                     dislodged_units: [], standoffs: [],
                     units: [TA::Unit.new(power: :england, type: :army, location: L.new(province: :lon)),
                             TA::Unit.new(power: :england, type: :fleet, location: L.new(province: :nth))])
  end

  it "gives the list order example" do
    expect(TA.legal_orders(start, fleet).first(3)).to eq(
      [O::Hold.new(power: :england, at: :lon),
       O::Move.new(power: :england, at: :lon, destination: L.new(province: :eng)),
       O::Move.new(power: :england, at: :lon, destination: L.new(province: :nth))]
    )
    expect(TA.legal_orders(start, TA::Unit.new(power: :france, type: :fleet, location: L.new(province: :lon)))).to eq([])
  end

  it "gives the support, coast, convoy and phase examples" do
    vie = TA::Unit.new(power: :austria, type: :army, location: L.new(province: :vie))
    expect(TA.legal_orders(start, vie).include?(O::SupportMove.new(power: :austria, at: :vie, from: :war, to: :gal))).to be(true)

    mao = TA::Unit.new(power: :france, type: :fleet, location: L.new(province: :mao))
    expect(TA.legal_orders(at_sea, mao).select { O::Move === _1 && _1.destination.province == :spa }.map { _1.destination.coast })
      .to eq(%i[nc sc])

    army = TA::Unit.new(power: :england, type: :army, location: L.new(province: :lon))
    expect(TA.legal_orders(ln, army).grep(O::MoveViaConvoy).map(&:to)).to eq([:yor])
    expect(TA.legal_orders(ln, army).any? { O::Move === _1 && _1.destination.province == :nwy }).to be(true)
    expect(TA.legal_orders(retreat, fleet)).to eq([])
  end
end
```

Run it; green. Then edit the header comment of `interface_examples_spec.rb`: replace the line `#   - the TA.legal_orders and TA.adjudicate calls in their own sections.` with `#   - the TA.adjudicate calls in its own section (#14).` and add after the sentence about `TA.check`: `# The TA.legal_orders examples run in legal_orders_examples_spec.rb (#12).`

### Step 2: The changelog

In `CHANGELOG.md`, under "Unreleased → Added", after the #11 entry, add:

```
- `TA.legal_orders(position, unit)`: every legal order for one unit, in the list order of `docs/interface.md` (hold, moves by destination and coast, moves via convoy, supports to hold, supports to move, convoys). It agrees with `TA.check` exactly, includes legal but pointless orders, and is empty for a position that isn't in a movement phase or a unit that isn't on the board. It checks only candidates a unit could possibly give and asks the checker about each, so it takes under 20 ms for the 22 units of the starting position. (#12)
```

### Step 3: Whole-suite proof and commit

From `adjudicator/`: `bundle exec rspec` and `bundle exec rake`, both green. Check `git diff --name-only main...HEAD` lists only paths under `adjudicator/` and that `docs/interface.md` is not among them. Commit: `Run the legal-orders examples and record the change`.

---

## Proof, for each "Done when" item of Issue #12

| Done when | Command | Passes when |
|---|---|---|
| Includes legal but pointless orders | `bundle exec rspec spec/trucebearer/adjudicator/legal_orders_spec.rb -e "supports nobody has ordered"` | the Vienna support for Warsaw to Galicia is listed |
| Agreement with checking, both directions | `bundle exec rspec spec/trucebearer/adjudicator/legal_orders_agreement_spec.rb` | all green, over every candidate of every unit of every sample; both mutations of Phase 2 were caught |
| Fast enough for every unit on each page load | `bundle exec rspec spec/trucebearer/adjudicator/legal_orders_performance_spec.rb` | all green; times in the pull request |
| Every interface example runs | `bundle exec rspec spec/trucebearer/adjudicator/legal_orders_examples_spec.rb` | green |
| Whole gem | `bundle exec rspec` and `bundle exec rake` | green, with counts |
| One side only | `git diff --name-only main...HEAD` | only `adjudicator/` paths, no `docs/interface.md` |

## Self-review

- **Spec coverage:** FR-1 and FR-2 by Phase 1; FR-3 by Phase 4; AC-1.x to AC-4.x and AC-7.5 by the Phase 1 spec; AC-5.x by Phase 2; AC-6.1 to AC-6.3 by Phase 3, AC-6.4 and AC-6.5 by the review and the pull request; AC-7.1 to AC-7.4 by Phase 4. No gap.
- **Placeholders:** none; every code step shows code.
- **Names:** `LegalOrders.call`, `LegalOrders.candidates`, `LegalPositions.candidates`, `LegalPositions.samples`, `LegalPositions.random_board(s)` and `LegalPositions.stress` are used with the same signatures in every phase.
- **Risk:** the agreement spec's running time (stated above, measured in Phase 2) and the relative guard (dropped, not loosened, if it flakes).

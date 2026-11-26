# Feature 014: Adjudicate movement phases without convoys

**Status:** Approved
**Version:** 1.2.0
**Created:** 2026-11-26
**Last Updated:** 2026-11-26
**Issue:** #14
**Branch:** `adjudicator/14-adjudicate-movement`

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 1.0.0 | 2026-11-26 | Initial draft |
| 1.1.0 | 2026-11-26 | Folded in the Gate A review (round 1, changes required, five blocking):<br>• Attack strength drops the owner's supports only when the unit in the province stays or is the head-to-head opponent (6.D.35, 6.E.9).<br>• A unit is dislodged when it stays (it follows no move, or its move fails); "loses a head-to-head battle" is defined once as "the opposing move succeeds".<br>• AC-7.3, AC-5.2, AC-6.1, AC-8.2, AC-8.7, AC-9.3, AC-9.6 and AC-10.1 are made consistent and testable.<br>• 6.D.8 is encoded (no convoy is ordered, so its result is the same before and after #15).<br>• The convoy section says openly where it departs from the contract; AC-5.3 is flagged; the random specs seed the hard shapes and carry a minimum count of each; the paradox check needs no counter |
| 1.2.0 | 2026-11-26 | Gate A approved by the coordinator under the maintainer's delegation. Rulings: convoys never work yet (option 1), pinned in its own spec file, and the spec and the CHANGELOG entry say convoy routing arrives with #15 before 0.2.0 ships; the Outcome and Adjudication impossible objects are added to `docs/interface.md` (one Ruby example each, only rules that follow from the contract, and the duplicate-province rule agrees with the duplicate-order raise), after `origin/main` is merged in; 6.F.1 is encoded; one pull request for now (Gate B decides); wrong-class arguments raise `TA::InvalidInput`; the implementation review confirms the defensive branch is unreachable. Status is now Approved |

## Problem Statement

`docs/interface.md` (merged in #5) promises `TA.adjudicate(position, orders)`: it takes a movement-phase position and a list of orders and returns a `TA::Adjudication`, with one `TA::Outcome` for every order, the position after the moves, and a `paradox` flag. #10 built the value objects that go in (`TA::Position`, the six orders), #11 built `TA.check`, which decides whether one order is legal, and #12 built `TA.legal_orders`. Nothing builds `TA::Outcome` or `TA::Adjudication`, and nothing decides who moves, who bounces and who is dislodged. This is the heart of the playtest: without it, a host can't have a turn adjudicated.

This feature builds `TA::Outcome`, `TA::Adjudication` and `TA.adjudicate` for movement phases **without convoys**, following the decision-based approach of Kruijswijk's "The Math of Adjudication" that `AGENTS.md` names. Convoys (an army carried by fleets, and the convoy paradoxes) are #15. Everything else that a movement phase holds is here: holds, moves, bounces and standoffs, supports and cuts, dislodgements, head-to-head battles, beleaguered garrisons, circular movement, and orders that are void.

## Goals

- `TA.adjudicate(position, orders)` returns a `TA::Adjudication` that matches `docs/interface.md` for every input that holds no convoy, and gives the DATC v3.4 preferred results for 6.A to 6.E (except the departures recorded in `ruleset.md`, and the cases that need a convoy, listed under "DATC cases").
- `TA::Outcome` and `TA::Adjudication` exist as value objects that follow the rules of `## Value objects`: immutable, `to_h` and `from_h`, `format` where the contract says, validated on construction, canonical, and kept through `Marshal`.
- Illegal orders are void, using the same function `TA.check` uses, so adjudication and checking can never disagree. Units without a legal order hold, and can be supported.
- Each dislodged unit records the province its attacker came from.
- Every Ruby example under `## Adjudicating a movement phase`, `### TA::Outcome` and `### TA::Adjudication` of `docs/interface.md` is a passing spec, except the two that need convoys (AC-1.3).
- Every encoded DATC case is a fixture in `spec/datc/` and passes through the runner.
- The resolver is correct by construction and also checked against an independent re-statement of the DATC's conditions over many random boards (Story 12).

## Non-Goals

- **Convoys and convoy paradoxes (#15).** A move or a convoy order that involves a convoy gets the temporary behavior of "Convoys in this release", below. The two interface examples that need convoys are written and left pending. No DATC case that needs a convoy route to work is encoded.
- **Resolving paradoxes (#39).** In this feature's scope no paradox can occur, so `paradox` is always `false` (see "The paradox flag").
- **Retreat and adjustment phases, and the real next phase (0.3).** `position` is the retreat-phase snapshot of `### The next position`.
- **Any change to `docs/interface.md`.** The contract is implemented as it stands. One addition is proposed for Gate A (Open Question 2), and nothing is edited without an answer. If building shows the contract is wrong or contradicts itself, work stops and goes to the coordinator. None was found while writing this spec, apart from two points it states openly: the conflict between "every example is a spec" and the two convoy examples (AC-1.3), and the wrong-class errors of AC-5.3, which go beyond the contract's two cases (Open Question 5).
- **A new public name besides `TA.adjudicate`, `TA::Outcome` and `TA::Adjudication`.** The resolver is an internal module, private to the gem like `Check` and `Reach`.
- **A map other than the classic one,** and building or disbanding units (adjustments).

## Users and Context

**Primary users:** the app, which calls `TA.adjudicate` once per movement phase with the position and the orders the host collected, and stores the `TA::Adjudication` (it carries `format`, so any phase can be replayed); and the agent building #15 (convoys), who extends the resolver.

**Secondary users:** James, who reads the examples in `docs/interface.md` and expects them to be true.

**Usage context:** a position holds at most 34 units, so at most 34 orders plus a few void ones. A call is made after all orders are in. It is called once per phase, so speed is not a concern, but a call must never be slow enough to notice (the specs hold a coarse ceiling).

## How adjudication works

### What a unit follows

The orders are first sorted out, one unit at a time:

1. Three things raise `TA::InvalidInput`, checked in this order, and nothing else raises: (a) an argument of the wrong class (a position that isn't a `TA::Position`, `orders` that isn't an `Array`, an element that isn't one of the six order classes), as `TA.check` and `TA.legal_orders` do; (b) a position that isn't in the movement phase; (c) one power giving two orders for units in the same province, whatever the two orders say. "Units in the same province" is read as two orders that name the same province in `at`, so it holds even when no unit stands there, and an order from a power that doesn't own the unit still counts for the power that gave it. (a) goes beyond the contract's two cases and follows the precedent of `TA.check`; Open Question 5 asks about it. The reading of (c) is recorded in `ruleset.md` (4.D.3).
2. An order is **void** when `Check.reason_for(position, order)` gives a reason. That covers an order that fails checking, an order from a power that doesn't own the unit, and an order for a unit that isn't on the board. It is the function `TA.check` uses, and no rule of checking is written a second time.
3. A unit **follows** its owner's legal order. A unit whose owner gave no legal order follows an **implied hold**.

Orders from different powers for the same unit never raise: the owner's order stands, and the other is void (`:foreign_unit`).

### The conditions

The conditions below are the DATC's section 5 equations, in our own words. Each decision (does this move succeed, is this support cut, is this unit dislodged) is true or false, and it doesn't change once it is made.

- **A unit moves** when it follows a `Move` or a `MoveViaConvoy`, whether or not the move works. A unit that follows anything else stays in its province, and so does a unit whose move fails. "Stays" below means either.
- **Matching.** A support to hold matches a unit that doesn't move. A support to move matches a move with the same origin and destination province. Coasts don't count (`### Terms used in adjudication`). An unmatched support adds nothing.
- **A head-to-head battle** is two units moving into each other's provinces, neither by convoy. A move **loses** its head-to-head battle when the opposing unit's move succeeds. (A move that fails while the opposing move also fails, or that is stopped by a third unit, has not lost: it keeps its prevent strength below.)
- **Strengths.** For a move into province P:
  - its **attack strength** is the force it brings against what is in P. It is 0 when the move has no route. When the unit in P leaves with a successful move (and is not the head-to-head opponent of this move), it is 1 plus all the given supports of the move. When the unit in P stays, or is the head-to-head opponent, it is 0 if that unit belongs to the mover's own power (no self-dislodgement), and otherwise 1 plus the given supports of the move that come from powers other than the owner of that unit (a power can't help dislodge its own unit). When P is empty it is 1 plus all the given supports;
  - its **prevent strength** is the force it uses to keep any other unit out of P. It is 0 when the move has no route or loses its head-to-head battle, and otherwise 1 plus all its given supports, whatever their power;
  - its **defend strength**, used only against the unit it faces head to head, is 1 plus all its given supports.
- **A province's hold strength** is 0 when it is empty or its unit's move succeeds, 1 when its unit's move fails, and otherwise 1 plus the given supports to hold.
- **A move succeeds** when its attack strength is greater than the hold strength of P (or, in a head-to-head battle, the opponent's defend strength) and greater than the prevent strength of every other move into P.
- **A support is cut** when a unit from another power moves into the supporter's province with a route, unless the supported move goes to the province that unit comes from. It is also cut when the supporter is dislodged, even by that unit (the exception in the first sentence doesn't apply to dislodgement). A cut support is not given.
- **A unit is dislodged** when it stays in its province and another unit's move into that province succeeds. The unit that moved in is its attacker. The dislodged unit is in the position's `dislodged_units` and not in `units`.
- **Circular movement.** Units that move in a circle of three or more, each into the province the next leaves, all succeed when nothing else stops one of them, and none of them is a paradox (DATC 5.B.9, 6.C.1 to 6.C.3). A circle of two is a head-to-head battle and is decided by strength, not by this rule.

### How the conditions are resolved

This is the "decision-based resolution" of `AGENTS.md`, written for this gem and not copied from any engine. Every decision starts unresolved. Each strength is kept as a range, from the least to the most it can still turn out to be given what is already decided, and a decision is made as soon as its range settles it, whatever else is unresolved. That is repeated until nothing more can be decided. If moves remain unresolved, they depend on one another in a circle, and the circular-movement rule decides them; then the loop runs again. When nothing is left unresolved, every outcome, the next position and the standoffs are read from the decisions.

The result never depends on the order of the orders: the same orders in another order give the same results (AC-9.1). The plan describes the data structures.

### The paradox flag

`paradox` is `false` in this feature's scope. Without convoys, a dependency between decisions that has no consistent result can't arise (DATC 5.B.9), and the circular-movement rule above is the only case of a dependency circle. A defensive branch is still written: if moves remain unresolved after the circular-movement rule, they all fail and `paradox` is `true`. The contract defines the flag as true exactly for a convoy paradox, so the branch is not reachable from any input, and a spec over random boards shows that it never runs (AC-12.2). #15 decides what the branch becomes when convoy paradoxes exist.

Circular movement and every other cycle of moves resolve with `paradox: false` (DATC 6.C.1 to 6.C.3, 6.E.10).

### Standoffs

`position.standoffs` lists every province that, after the moves, holds no unit, and that at least two moves into it entered on equal terms and stopped each other: they had a route, neither lost a head-to-head battle, and they shared the greatest prevent strength. A province that is entered, a province whose own unit stays, and a province whose attackers were stopped by a stronger unit or a lost head-to-head battle are not standoffs. This is what the later retreat phase needs (DATC 6.H.6, 6.H.9, 6.H.17). The DATC doesn't define it in these words, so `ruleset.md` records it.

### Convoys in this release

#15 has not been built, so this feature needs a rule for any input that involves a convoy. **Approved at Gate A (Open Question 1, option 1).** It is temporary: convoy routing arrives with #15, before 0.2.0 ships, and the file that pins it is named so that #15 replaces it. The CHANGELOG entry says so too.

Convoys never work. The convoy routing rules of `### Convoy routing` are applied as written to decide whether a move **goes by convoy**: a move to a province an army can't reach by land, a `MoveViaConvoy`, or a plain `Move` to a province the army can reach by land when a fleet of the army's own power gives a matching `Convoy` order that passes checking. Then:

- a move that goes by convoy gets the result `:no_route`, and it is a failed move with attack and prevent strength 0 (so it cuts no support, and the unit stays and holds with strength 1);
- a `Convoy` order that passes checking gets `:unmatched`. By the contract's wording this is true of the stub's world (no matching move went by convoy, since none could), but it is a departure all the same: a convoy that would be `:given`, or `:disrupted` when its fleet is dislodged, is never so in this release;
- `by_convoy` of a dislodged unit is therefore always `false`, and `paradox` always `false`.

Nothing raises. Every other rule of this feature applies unchanged to the other orders of the same call. Two examples of the contract (`by_sea`, and the paradox position) disagree with this and are written pending (AC-1.3).

**Alternatives (not taken).** (2) Raise `TA::InvalidInput` for any convoy input: simple, and it fails loudly instead of returning a result that is silently wrong for any input where a convoy would have worked, but it adds a case to the contract's list of errors (as the wrong-class errors of AC-5.3 already do, see Open Question 5), and has to be undone. (3) Build the routes now (without paradoxes): it adds #15's route and disruption logic and fixtures to this pull request and makes it about twice the size, and #15 would shrink to paradoxes and 6.F to 6.G. The recommendation (1) keeps each issue to its own scope and leaves one place for #15 to change: the function that says whether a move has a working route.

## DATC cases

Fixtures are the same hand-written files that #11 started, in `spec/datc/`, named by section number. The format of #11 gets its two reserved keys filled (see "Fixture format"). Nothing is quoted from the DATC.

### Encoded

An existing file (27 of them, from #11) gets `result:` and `after:`; a new file (53, or 52 without 6.F.1) is written. Every order carries a `check:` as #11 requires, even in a new file, and the checking runner runs it.

| Section | Encoded | Notes |
|---|---|---|
| 6.A | 6.A.1 to 6.A.12 (12) | 6.A.1 to 6.A.10 exist; 6.A.11 and 6.A.12 are new. 6.A.5 and 6.A.7 hold convoy orders, but void ones, so no convoy is resolved |
| 6.B | 6.B.1 to 6.B.8, 6.B.10 to 6.B.13, 6.B.15 to 6.B.17 (15) | All exist. 6.B.2 and 6.B.12 are departures, so the fixture states our result (the order is void and the unit holds) |
| 6.C | 6.C.1, 6.C.2, 6.C.3, 6.C.8, 6.C.9 (5) | The circular-movement cases that hold no convoy |
| 6.D | 6.D.1 to 6.D.5, 6.D.7 to 6.D.15, 6.D.17 to 6.D.35 (33) | 6.D.31 and 6.D.34 exist. 6.D.27 holds a convoy order that matches no move, so it is `:unmatched` whatever #15 does. 6.D.8 and 6.D.31 hold an army move that needs a convoy and no convoy order is given, so `:no_route` is the result with or without #15 (6.D.8's hold support is unmatched and its unit is dislodged just the same) |
| 6.E | 6.E.1 to 6.E.10, 6.E.12 to 6.E.15 (14) | |
| 6.F | 6.F.1 (1) | Parked for #14 by spec 011. Every order in it is void, and no convoy is resolved. It is outside 6.A to 6.E, so it is Open Question 3 |

The 11 cases that spec 011 left to #14 are 6.D.22 to 6.D.24, 6.D.28 to 6.D.30, 6.D.32, 6.E.14, 6.F.1, 6.F.12 and 6.G.7. Eight fall in 6.A to 6.E and need no convoy, so they are encoded. 6.F.1 is encoded if Open Question 3 says so. 6.F.12 and 6.G.7 are left out (below).

### Left out

| Case | Why |
|---|---|
| 6.B.9 | Can't be expressed: a support carries no coast (a departure in `ruleset.md`) |
| 6.B.14 | A build; adjustments are 0.3 (#37) |
| 6.B.18, 6.B.19 | The army is carried by a convoy that must work: #15 |
| 6.C.4 to 6.C.7 | A circle or swap that holds convoyed armies: #15 |
| 6.D.6, 6.D.16 | A convoyed army that must get across: #15 |
| 6.E.11 | A swap by convoy: #15 |
| 6.F.2 to 6.F.30, 6.G.1 to 6.G.18, 6.G.20 | Convoy cases: #15 and #39. This includes 6.F.12 and 6.G.7 from spec 011's list, which resolve a convoy route. 6.F.1 is the one exception (Open Question 3) |
| 6.G.19 | An existing checking fixture; its adjudication needs a route: #15 |
| 6.H | Retreats: 0.3 |

6.B.18, 6.B.19 and 6.G.19 stay as checking fixtures with no `after:`; the adjudication runner skips a file with no `after:` and a spec lists them as the skipped ones, so a file can't be left out by accident (AC-11.2).

### Fixture format

#11 reserved `result:` per order and `after:` for the file. This feature defines them:

```yaml
orders:
  - order: {type: move, power: italy, at: vie, destination: boh}
    check: {legal: true}
    result: bounced          # an outcome symbol (the nine of TA::Outcome). Required in a file that has `after:`
    dislodged: true          # optional, default false
after:                       # the position after the moves
  units:                     # required: every unit not dislodged, at its final place ("spa/nc" for a coast)
    - {power: italy, type: army, at: vie}
  dislodged:                 # optional, default none
    - {power: austria, type: army, at: tri, from: ven, by_convoy: false}   # by_convoy optional, default false
  standoffs: [boh]           # optional, default none
```

A fixture lists the submitted orders only. The runner works out the implied holds from the fixture itself: a unit with no order from its owner that has `check: {legal: true}` gets an implied hold, which must come back `:held`, with `dislodged` true exactly when the unit is in `after.dislodged`. The implied holds come last, sorted by province, as the contract says. `dislodged:` on an order is a new key (#11 reserved only `result:` and `after:`). The loader refuses an unknown key, an unknown result symbol, a `dislodged:` that isn't true or false, an `after:` in a file that has an order with no `result:`, an `after:` unit that is not a valid unit, and a `from:` that is not a province.

## Definitions

- **Followed order, void, implied hold:** see "What a unit follows".
- **Goes by convoy:** see "Convoys in this release".
- **Submitted outcome:** an outcome with `submitted: true`. **Implied-hold outcome:** one with `submitted: false`.

## User Stories

Every acceptance criterion is verified by a passing spec in this pull request, except those marked (review), which the implementation review and the pull request check. "A valid position" and "a valid order" mean built with `new` or `from_h` without raising.

### Story 1: The first example

**As an** app developer
**I want** to adjudicate a first turn from the starting position
**So that** I see the shape of the answer

**Acceptance criteria:**

- [ ] **AC-1.1** Given the starting position, England's move from London to the North Sea, and Germany's move from Kiel to Holland When `TA.adjudicate(start, orders)` is called Then the first two outcomes' results are `[:succeeded, :succeeded]`; 20 outcomes have `submitted: false` and each is a `Hold` with result `:held`; `paradox` is `false`; the position's phase is `:retreat` and `dislodged_units` and `standoffs` are `[]`; the position's units include one in `nth` and one in `hol` and none in `lon` or `kie`; `ownership` equals the start's; and `outcomes.drop(2).first(3).map { _1.order.at }` is `[:ank, :ber, :bre]`. This is the first spec written, and it fails until `TA.adjudicate` exists
- [ ] **AC-1.2** Every Ruby example under `## Adjudicating a movement phase` of `docs/interface.md` is a passing spec with the same expected values, except the two in AC-1.3: the bounce example (`[:bounced, :bounced]` and `standoffs == [:gal]`), the two raises, the void example, the `by_land` example, and the Vienna example (a dislodged Austrian army with `attacker_from: :boh` and `by_convoy: false`, and a German army in Vienna). The examples under `### TA::Outcome` and `### TA::Adjudication` are passing specs as well
- [ ] **AC-1.3** The two examples that need a working convoy (`by_sea` under `### Convoy routing`, and `paradox_pos` under `### Convoy paradoxes`) are written as pending examples with the reason "convoys: #15", so they run, fail as expected, and can't be forgotten. When #15 makes one pass, RSpec flags it until the `pending` is removed

### Story 2: `TA::Outcome`

**As an** app developer
**I want** what happened to each order as a value object I can save and rebuild
**So that** I can show it and replay it

**Acceptance criteria:**

- [ ] **AC-2.1** Given `order`, `result`, `submitted` and `dislodged` When `TA::Outcome.new(...)` is called with a valid combination Then it returns a frozen object with those fields, two outcomes with the same contents are equal and have the same `hash`, and the `to_h` of the interface's example is exactly `{"order" => {"format" => 1, "type" => "hold", "power" => "england", "at" => "lon"}, "result" => "held", "submitted" => false, "dislodged" => false}`, keys in that order
- [ ] **AC-2.2** Given any outcome When `TA::Outcome.from_h(JSON.parse(JSON.generate(outcome.to_h)))` is called Then it equals the original (every order class, every result that order class allows, both `submitted` values, both `dislodged` values). The hash carries no `"format"` key of its own, and the nested order keeps its own `"format" => 1`
- [ ] **AC-2.3** Given a hash with a missing or unknown key, an unknown result text, a non-boolean `submitted` or `dislodged`, or an `order` that doesn't build Then `from_h` raises `TA::InvalidInput` and the message includes the offending key or value. A hash with `"format"` at the top level raises too (the key is unknown), and `new` takes the result as a symbol only
- [ ] **AC-2.4** Given the table of results `### Outcomes` Then these are impossible, and each raises `TA::InvalidInput` from both `new` and `from_h`: a result the order class doesn't have (for example a `Hold` that is `:bounced`, a `Move` that is `:given`); an outcome that is `:void` with `dislodged: true`; an outcome with `submitted: false` that is not a `Hold` with `:held`; a `Move` or `MoveViaConvoy` that is `:succeeded` with `dislodged: true` (a unit that moved is not dislodged). A spec holds every one
- [ ] **AC-2.5** Given the nine result symbols Then `TA::Outcome::RESULTS` lists them in the order of the contract, and a spec keeps the list equal to the one in `docs/interface.md`

### Story 3: `TA::Adjudication`

**As an** app developer
**I want** the whole answer as one value object I can store
**So that** any phase can be replayed from the record

**Acceptance criteria:**

- [ ] **AC-3.1** Given `outcomes`, `paradox` and `position` When `TA::Adjudication.new(...)` is called Then it returns a frozen object, its `outcomes` array is frozen and keeps the order given (it is not sorted), the caller's own array is neither frozen nor changed, and equal contents are equal with the same `hash`
- [ ] **AC-3.2** The `to_h` of the interface's example (England's fleet holding in London) is exactly the hash shown in `### TA::Adjudication`, with `"format" => 1` first, and `from_h` of its JSON round trip equals the original
- [ ] **AC-3.3** Given a missing or unknown key, a missing or unknown `format`, a non-boolean `paradox`, a list that isn't an `Array`, or an element that doesn't build Then `from_h` raises `TA::InvalidInput` and the message includes the offending key or value
- [ ] **AC-3.4** These are impossible, and each raises `TA::InvalidInput` from `new` and `from_h`: an outcome in the list after an implied-hold outcome that is submitted; implied-hold outcomes that are not in ascending order of province (including two for one province); two submitted outcomes for the same power and province (adjudication refuses that input). The position may be in any phase, since 0.3 will change it
- [ ] **AC-3.5** The "Impossible objects" examples that follow from AC-2.4 and AC-3.4 are specs. They are added to `docs/interface.md` under `### Impossible objects`, one Ruby example each for `TA::Outcome` and `TA::Adjudication` (Open Question 2, yes)

### Story 4: `Marshal`

**As an** app developer who caches values with `Marshal`
**I want** `TA::Outcome` and `TA::Adjudication` to keep the guarantees of the other value objects
**So that** a cached adjudication is as safe as a rebuilt one

**Acceptance criteria:**

- [ ] **AC-4.1** Given `Shape::Marshalable` is included in both classes Then both are added to the object list in `spec/trucebearer/adjudicator/marshal_spec.rb`: an outcome, an outcome with a nested move and a dislodged flag, an adjudication with outcomes and a retreat position that holds a dislodged unit. Every example of that file runs for them: equal and deeply frozen after a round trip; equal with `freeze: true`; a hand-built payload equals the real one; the hooks can't run again; the hooks aren't public; a payload that isn't a hash form, a missing key and an extra key are refused
- [ ] **AC-4.2** Given a payload edited to describe an impossible outcome or adjudication (a `Hold` that is `:bounced`, a duplicate submitted province) Then `Marshal.load` raises `TA::InvalidInput`, as `from_h` does

### Story 5: What `TA.adjudicate` refuses

**As an** app developer
**I want** the contract's two errors, plus the malformed-input error of `TA.check` (Open Question 5), and nothing else
**So that** I can rescue them and know a rules failure never raises

**Acceptance criteria:**

- [ ] **AC-5.1** Given a position in the retreat phase, and one in the adjustment phase, and an empty list of orders When `TA.adjudicate` is called Then it raises `TA::InvalidInput` and the message includes the phase
- [ ] **AC-5.2** Given two orders from one power that name the same province in `at`: two identical holds; a hold and a move; two orders for a province with no unit; one of them void When `TA.adjudicate` is called Then it raises `TA::InvalidInput` and the message names the power and the province. The errors come in the order of "What a unit follows": a retreat position with such orders raises the phase error, and a wrong-class argument raises before both
- [ ] **AC-5.3** Given an argument of the wrong class (`nil`, a hash form, a `Symbol` for the position; `nil`, a hash, a single order for `orders`; a list with `nil`, a hash form or a `CheckResult` in it) Then it raises `TA::InvalidInput` and the message includes the argument. This goes beyond the contract's two cases (Open Question 5)
- [ ] **AC-5.4** Given orders from different powers for the same unit, or two orders for one province from two powers that don't own it Then nothing raises: the owner's order stands and the other is void, and both are in the outcome list in the order given. Given a valid position and valid orders Then nothing else ever raises (shown by Story 12)
- [ ] **AC-5.5** The call changes none of its arguments: the position is the same object afterwards, `orders` is neither frozen nor changed, and the same call twice gives equal results

### Story 6: Void orders and implied holds

**As a** host
**I want** a mistyped order to do nothing, and a unit with no order to hold
**So that** a turn always has a result

**Acceptance criteria:**

- [ ] **AC-6.1** Given any order, from a sample of every reason `TA.check` can give except `:wrong_phase` (which can't be adjudicated, since a position that isn't in a movement phase raises), one per reason, and a legal one of each class When it is adjudicated alone Then its outcome is `:void` exactly when `TA.check` says `legal: false`, `dislodged` is `false`, and `submitted` is `true`. The check is made with `TA.check` in the spec, not with a copy of its rules
- [ ] **AC-6.2** Given the contract's void example (France orders England's fleet in London to hold) Then the order is `:void`, and the implied hold for London is `:held`, `submitted: false`, and owned by England
- [ ] **AC-6.3** Given a position and orders that cover only some of its units Then the outcome list is one outcome for each order in the order given, then one `Hold` for each unit whose owner gave no legal order, sorted by province, each `:held` unless dislodged (it is still `:held` and then `dislodged: true`), each with `submitted: false` and the unit's owner as `power`
- [ ] **AC-6.4** Given a unit with an implied hold Then other units can support it, and it can be dislodged. Given a unit with a void order, a foreign-power order, or no order at all Then it counts as holding for matching and for hold strength, and a void order never cuts, supports or moves
- [ ] **AC-6.5** Given an empty list of orders in a movement position Then every unit holds, there are as many outcomes as units, all `:held`, `paradox` is `false`, and the position's units are the original ones in the retreat phase

### Story 7: Moves, bounces and standoffs

**As a** host
**I want** moves to succeed or bounce as the rules say
**So that** the board after the turn is right

**Acceptance criteria:**

- [ ] **AC-7.1** Given a move into an empty province with no rival Then it is `:succeeded` and the unit is in the new province, with its coast if it is a fleet moving to a coast (a fleet's `Location` in the next position is exactly the move's `destination`)
- [ ] **AC-7.2** Given two, then three, units of different powers moving into one empty province with no support Then every move is `:bounced`, nobody enters, and the province is in `standoffs`. Given the same with one supported move Then only it succeeds and the province is not a standoff
- [ ] **AC-7.3** Given a province with a holding unit and a move into it with equal strength Then the move is `:bounced`, the holder is not dislodged, and the province is not a standoff. Given a province that the winner of a head-to-head battle left, and one other unit's move into it Then that move succeeds and the province is not a standoff
- [ ] **AC-7.4** Given a standoff in a province that a unit left in the same turn Then the province is in `standoffs`. Given a province where two moves tie and a third, stronger move enters Then it is not a standoff
- [ ] **AC-7.5** Given every move that doesn't succeed Then its unit is in `units` at its own place, and given every move that succeeds Then the unit is at the destination and no other unit is in that province
- [ ] **AC-7.6** Given the encoded cases of 6.A (12) and 6.C (5) Then results, `after.units` and standoffs are exactly the fixtures' (Story 11). 6.A.11 and 6.A.12 are the two- and three-way standoffs of AC-7.2

### Story 8: Supports

**As a** host
**I want** supports to add strength and to be cut as the rules say
**So that** a supported unit wins

**Acceptance criteria:**

- [ ] **AC-8.1** Given a support to hold for a unit that holds Then it is `:given` and adds one to the hold strength. Given a support to move that matches a move Then it is `:given` and adds one to the attack, defend and prevent strengths
- [ ] **AC-8.2** Given a support to hold for a unit that moves Then it is `:unmatched`. Given a support to move that names another origin or destination than the move the unit follows, or whose supported unit follows a hold because its own order was void, foreign or missing Then it is `:unmatched` too. (A support to hold for a unit that holds for those reasons is matched.) The support itself is `:void` only when it fails checking, never because of what its target did. Coasts and whether a move is by convoy never matter for matching. An unmatched support is never `:cut`, since `:unmatched` comes first
- [ ] **AC-8.3** Given a move into the supporter's province from another power, with a route Then the support is `:cut`, unless the supported move goes to the attacking unit's own province. Given an attack from the same power Then the support is not cut. Given an attack with no route (it needs a convoy and has none) Then it is not cut
- [ ] **AC-8.4** Given a supporter that is dislodged Then its support is `:cut`, even when the unit that dislodged it came from the supported move's destination. Given an attack from that destination that doesn't dislodge Then the support is `:given`
- [ ] **AC-8.5** Given a support for the unit of another power Then it counts for the supported move or hold. Given a support from the power that owns the unit being attacked Then it doesn't count toward dislodging that unit but does count for the supported unit's prevent and defend strength
- [ ] **AC-8.6** The result of a support never depends on whether the move it helped succeeded: a spec shows the same support `:given` when its move succeeds and when it bounces
- [ ] **AC-8.7** Given a support for a unit whose own order is an unmatched support, or an unmatched convoy Then the support is `:given` (6.D.25 to 6.D.27). Given a support for a move that can't be made (a fleet into an inland province, a wrong coast, an army into the sea) Then the support fails checking (`:move_impossible`), so it is `:void` and its unit holds, and the supported unit's own move is `:void` too (6.D.22 to 6.D.24)

### Story 9: Dislodgement and the next position

**As a** host
**I want** to see who was dislodged, by whom, and where everybody ends up
**So that** the retreat phase can start

**Acceptance criteria:**

- [ ] **AC-9.1** Given the orders of any case in any order (all permutations of a case of at most five orders, and a fixed-seed shuffle of the others) Then each order's result, the dislodged flags, the units, the dislodged units and the standoffs are the same: the result doesn't depend on the order of the list. Only the outcome list's own order follows the input
- [ ] **AC-9.2** Given a unit dislodged by a successful move Then the position has a `TA::DislodgedUnit` for it with the unit at the location it stood on, `attacker_from` the province the attacker came from (a province, no coast), and `by_convoy: false`, and the unit is not in `units`. The outcome of the order it followed (a hold, a failed move, a support or a convoy) has `dislodged: true`, and no other outcome does
- [ ] **AC-9.3** Given every dislodged unit of every encoded case and of the random boards Then `attacker_from` is a province with no coast, the province it was dislodged in holds in `units` the unit that came from `attacker_from`, and the position builds. Three named scenarios are specs: a fleet dislodged from a split-coast province, a fleet that dislodges by moving to a coast, and an army dislodged from a province next to a split-coast province
- [ ] **AC-9.4** Given any adjudication Then the next position has the same season, year and map, the phase `:retreat`, the same `ownership`, no unit in a province twice, and every input unit appears exactly once, in `units` or in `dislodged_units`
- [ ] **AC-9.5** Given a unit that is dislodged and a unit that follows its attacker into the vacated province (a unit that moves into the province the attacker left) Then the follower's move can succeed, as in 6.E.1
- [ ] **AC-9.6** Given a move into a province whose unit stays and belongs to the mover's own power Then its attack strength is 0 and it never dislodges (6.D.10, 6.D.11, 6.E.2). Given a province whose unit is attacked by a move that is supported by a unit of the attacked unit's own power Then that support doesn't count toward dislodging it (6.D.12 to 6.D.14, 6.E.3, 6.E.6, 6.E.7), though it does count for the supported unit's prevent and defend strength

### Story 10: Head-to-head battles, beleaguered garrisons and circular movement

**As a** host
**I want** the hard cases decided as the DATC says
**So that** the engine can be trusted in a real game

**Acceptance criteria:**

- [ ] **AC-10.1** Given two units that move into each other's provinces (no convoy) with no third unit involved Then the one whose attack strength is greater than the other's defend strength succeeds (supports from the attacked unit's own power don't count toward the attack, 6.E.6), and the other is `:bounced` and, since it stays, dislodged; given equal strength both are `:bounced` and nobody moves; given two units of one power both are `:bounced` (6.E.2). A unit that has not lost its battle (the opposing move failed, because a third unit was stronger or because of the beleaguered garrison) keeps its prevent strength, so it still stops a third unit from entering the province its rival tried to enter (6.E.4 to 6.E.6)
- [ ] **AC-10.2** Given a unit attacked from several sides with equal strength Then every attack fails, even if two of them could beat one, and the unit is not dislodged (a beleaguered garrison, 6.E.13 to 6.E.15). A garrison whose own support creates the winning attack is not dislodged by it (6.E.7 to 6.E.10)
- [ ] **AC-10.3** Given three units moving in a circle (6.C.1), with a support (6.C.2), and with a fourth unit that bounces one of them (6.C.3) Then the circle succeeds when nothing stops it and holds in full when something does, and `paradox` is `false` in every case. A longer circle (four and five units) and two circles that share no province are specs of their own
- [ ] **AC-10.4** Given a circle where one unit is stopped by the no-self-dislodgement rule (6.C.8, 6.C.9) Then no unit of the circle moves
- [ ] **AC-10.5** Given a position that holds a convoy order or a move that needs a convoy Then the temporary rule of "Convoys in this release" applies and these specs (Story 13) are the only ones that pin it

### Story 11: The DATC fixtures and their runner

**As a** maintainer
**I want** each encoded case adjudicated from its fixture
**So that** the DATC is the test, as `AGENTS.md` says

**Acceptance criteria:**

- [ ] **AC-11.1** Given a file `spec/datc/<section>.yml` with `after:` When the runner adjudicates it Then each submitted order's result and `dislodged` equal the fixture's, the implied holds are as in "Fixture format", `paradox` is `false`, and the position's units, dislodged units (with `attacker_from` and `by_convoy`) and standoffs equal `after:`; each is its own example, named by case and order
- [ ] **AC-11.2** Given the directory `spec/datc/` Then the files with an `after:` are exactly the list of "Encoded" in the adjudication runner, none missing and none extra, the files without one are exactly 6.B.18, 6.B.19 and 6.G.19, none of the cases of "Left out" has a file with an `after:`, and each file's `case:` equals its name
- [ ] **AC-11.3** Given the checking runner of #11 Then it still passes: the list of files it expects is extended with the new files (each with a `check:` for every order), its `size == 30` check and its `left_out` list change (6.A.11 and 6.A.12 are encoded now), and `6.B.2` and `6.B.12` are still the only departures; the rest of spec 011's expectations stand
- [ ] **AC-11.4** Given the loader Then a spec shows each refusal of "Fixture format", and the example of spec 011's AC-8.5 (a fixture with reserved keys) still loads
- [ ] **AC-11.5** Given every encoded fixture Then the units and orders are those of the DATC case, and nothing more: no extra order and no extra unit (the adjudication would change). The two adapted checking fixtures, 6.A.5 and 6.D.31, keep the adaptations #11 made, since they give the DATC's results (review)

### Story 12: Correctness beyond the DATC

**As a** maintainer
**I want** the resolver tested where the DATC doesn't reach
**So that** a rare combination can't fail in a game

**Acceptance criteria:**

- [ ] **AC-12.1** Given fixed-seed random movement positions (a hundred or more, of 2 to 34 units, with a spread of provinces, powers, armies and fleets, including split coasts) and orders for each unit chosen from `TA.legal_orders` without any convoy order or any move that needs a convoy, with some units left without an order and a few foreign orders added, and with a share of the boards built to hold the hard shapes (at least 20 boards with a circle of three or more, 20 with a head-to-head battle, 20 with a supporter attacked from the supported move's destination, and 20 with a beleaguered garrison, each count checked by the spec) Then `TA.adjudicate` returns an `Adjudication` and raises nothing, every unit appears once, the position builds, and no unit is dislodged by a unit of its own power
- [ ] **AC-12.2** Given the same boards Then `paradox` is `false`. Since the defensive branch of "The paradox flag" sets the flag, it can't run unseen. Random boards support the claim that it is unreachable; they don't prove it, and the spec says so. The branch picks the circles that are actually stuck, not every unresolved move
- [ ] **AC-12.3** Given the same boards and their outcomes Then a re-statement of the DATC's conditions, written independently in the spec from the contract and the DATC (not from the resolver), is satisfied by every result: a move succeeds exactly when its strength beats what the conditions say, a support is cut exactly when the conditions say, a unit is dislodged exactly when the conditions say. The re-statement is written from the same prose as the resolver, so it catches faults in the iteration and the circle rule, not a misreading of the DATC; the fixtures catch that. It doesn't pick a solution for circular movement, so a circle's moves must all succeed or all fail and the spec checks that they do the first when nothing else stops them
- [ ] **AC-12.4** Given the same boards with the orders shuffled Then the results are the same (AC-9.1 over the random boards)
- [ ] **AC-12.5** Given a position of 34 units Then adjudicating takes under 1 000 ms (a coarse ceiling that can't flake)

### Story 13: Convoys in this release

**As** #15's author
**I want** the temporary behavior pinned in one clearly named place
**So that** I know exactly what to replace

**Acceptance criteria:**

- [ ] **AC-13.1** Given the proposed behavior of "Convoys in this release" is approved Then `spec/trucebearer/adjudicator/adjudicate_convoy_stub_spec.rb` holds every specification of it, and nothing else pins it: a move that goes by convoy by each of the three rules is `:no_route` and a failed move (it cuts no support, bounces nothing, holds with strength 1, and can be dislodged); a legal `Convoy` order is `:unmatched`; an illegal one is `:void`; `by_convoy` of a dislodged unit is `false`; `paradox` is `false`; nothing raises. The file's first lines say it is temporary and that #15 replaces it
- [ ] **AC-13.2** The `by_land` example is a passing spec, since an army with no matching convoy order goes by land, and the two convoy examples are pending (AC-1.3)

### Story 14: Records

**As** the next person to read the repository
**I want** every choice written where the contract says
**So that** nothing is decided silently

**Acceptance criteria:**

- [ ] **AC-14.1** `docs/ruleset.md` gets a row for each choice this feature makes that the DATC leaves open, citing the section: what a standoff is (6.H.6, 6.H.9, 6.H.17), the result name of each outcome (4.E.2), that a unit whose owner gave no legal order holds and can be supported (4.E.3, 6.D.28 to 6.D.30, already partly recorded under 4.E.1), the circular-movement rule (5.B.9) and what is done with a circle that no rule decides, and the temporary convoy behavior (4.A.3)
- [ ] **AC-14.2** `CHANGELOG.md` has an entry under "Unreleased", "Added", naming `TA::Outcome`, `TA::Adjudication` and `TA.adjudicate` and #14, and says that convoy routing arrives with #15, before 0.2.0 ships (a second "Added" line, or part of the same entry, covers the new "Impossible objects" examples of the contract). No other entry is touched. When #13 moves the entries under 0.1.0 and `main` is merged in, the entry stays under "Unreleased" (review)
- [ ] **AC-14.3** `git diff --name-only main...HEAD` lists only paths under `adjudicator/`, and `docs/interface.md` is among them only for its "Impossible objects" list (Open Question 2); nothing else in it changes

## Open Questions

1. **What does `TA.adjudicate` do in this release with a convoy?** *Decided at Gate A: option (1).* Options, with the one recommended first:
   - **(1) Convoys never work (recommended).** A move that goes by convoy is `:no_route`, a legal `Convoy` order is `:unmatched`, and nothing raises. Described under "Convoys in this release". The contract promises more for 0.2.0, but 0.2.0 ships only after #15 and the temporary behavior can't reach the app.
   - **(2) Refuse.** Raise `TA::InvalidInput`. Needs a third error case in the contract.
   - **(3) Build the routes now,** without paradoxes. About double the size of this pull request.
2. **Impossible objects.** *Decided at Gate A: yes, add them to `docs/interface.md`, one Ruby example each, inside the 0.2.0 material, with a CHANGELOG "Added" line. Every rule must follow from what the contract already says about outcomes, and the duplicate-province rule must agree with the duplicate-order raise. `origin/main` is merged in first, since #13 edits the same file.* The contract's `### Impossible objects` list has no `TA::Outcome` or `TA::Adjudication` entry, but `## Value objects` says every value object is validated, and the Issue asks for "impossible objects". AC-2.4 and AC-3.4 propose a set, all following from the contract's wording of the outcome list, the dislodged flag and the results table. One forward note: "an implied hold is a `Hold` that is `:held`" will need loosening in 0.3, when retreat and disband orders can be implied. **Recommendation:** add those examples to the contract's list (an addition under "Added", no Issue for the app needed). The alternative is to keep them only in this spec and in specs; then the contract would say less than the code does.
3. **6.F.1.** *Decided at Gate A: encode it.* It is outside 6.A to 6.E, but spec 011 parked it for #14, every order in it is void, and no convoy is resolved. **Recommendation:** encode it (one file). The alternative is to leave it to #15 with the other two parked cases (6.F.12 and 6.G.7), which need a route.
4. **Splitting the work.** *Decided at Gate A: one pull request for now; Gate B decides from the plan's size.* The Issue allows a split by DATC section. The code is one resolver, so a split by section doesn't map to code. **Recommendation:** one pull request, unless the plan at Gate B shows it is too large. If it is: the first pull request holds the two value objects, `TA.adjudicate` for holds, moves, bounces and void orders, and its fixtures (6.A and the move-only cases of 6.B); the second adds supports, dislodgement, head-to-head, circular movement, and the fixtures of 6.C to 6.E, and "Closes #14". Both would follow this one spec.
5. **Wrong-class arguments.** *Decided at Gate A: keep, they raise.* The contract names two cases that raise. A wrong-class position, `orders` or order element is malformed input, and `TA.check` and `TA.legal_orders` already raise `TA::InvalidInput` for it (the contract's own rule: malformed input raises, a broken rule doesn't). AC-5.3 does the same here. **Recommendation:** keep it, and word the contract's "two cases only" as "two rules failures" when the contract is next edited. The alternative is to let a `NoMethodError` out, which the contract's last paragraph in `## Errors` rules out.

## Notes for the plan

- Order of work: the first spec (AC-1.1), then `Outcome` and `Adjudication` with their specs and Marshal, then the resolver in the order of the stories, the runner extension (loader and runner first, with one fixture), then the fixtures in batches by section, then the random specs.
- The number of fixture files (53 new, 27 changed) is the bulk of the work. They are small, independent and can be written by separate implementers, each checking its own cases against the DATC text for the position and orders, and against the contract for the result names.
- The reviewers of the plan check that the resolver uses `Check.reason_for` and the `Reach` helpers, and does not copy a rule of checking.

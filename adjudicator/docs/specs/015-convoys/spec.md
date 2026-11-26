# Feature 015: Adjudicate convoys

**Status:** Draft
**Version:** 1.0.0
**Created:** 2026-11-26
**Last Updated:** 2026-11-26
**Issue:** #15
**Branch:** `adjudicator/15-convoys`

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 1.0.0 | 2026-11-26 | Initial draft |

## Problem Statement

`TA.adjudicate` (#14) adjudicates every movement phase without convoys. A move that goes by convoy is `:no_route` and a legal `Convoy` order is `:unmatched`, and a spec file pins that stub. The contract in `docs/interface.md` promises more for 0.2.0: convoy routes, disrupted convoys, moves to neighboring provinces by sea, `by_convoy` on dislodged units, and the `paradox` flag. Two interface examples (`by_sea` and `paradox_pos`) are pending until this is built, and the DATC cases of 6.F and 6.G, and the cases of 6.A to 6.E that need a convoy, are not yet encoded.

## Goals

- Replace the stub with real convoy adjudication: working routes, disrupted convoys, `:given` and `:disrupted` results for `Convoy` orders, `by_convoy` on dislodged units, and moves that go by convoy to a neighboring province, all as `interface.md` defines them under "Convoy routing" and "Outcomes".
- **Detect** convoy paradoxes and set `paradox`, exactly as the contract promises for 0.2.0, and **not resolve** them. Resolving them (Szykman's rule or another) is #39.
- Encode every DATC case that #14 left out for #15, so that 6.F and 6.G pass apart from the paradox cases, and the 6.A to 6.E cases that need a convoy pass.
- Make the two pending interface examples pass for real, and delete the stub spec.
- Extend the random boards to convoys, with an independent check that the flag is set only where a board really holds a paradox.
- Record the choices in `docs/ruleset.md`.

## Non-Goals

- **Paradox resolution (#39, for 1.0).** While `paradox` is `true`, outcomes and where units end up are unspecified until 0.3. This feature gives them a rule only so that the position is valid (see "What a paradox does today").
- **Any public change.** `TA.adjudicate` keeps its signature, `Resolver` stays internal, and `docs/interface.md` is not edited. If a phase shows the contract is wrong or contradicts itself, stop and ask the coordinator.
- **Retreats, adjustments, the next phase (0.3).**
- **A different map.** The classic map only, as in every spec so far.

## Users and Context

**Primary users:** the app, which calls `TA.adjudicate` once per movement phase; the maintainer playing the game with convoys in the playtest; and the author of #16 (release 0.2.0) and #29 (the app drops its stand-in), which this unblocks.

## How convoys are adjudicated

This extends the resolver of spec 014 (`docs/specs/014-adjudicate-movement/spec.md`, "The conditions" and "How the conditions are resolved"). Everything there still applies. This section lists only what changes. The terms **matching**, **working convoy route** and **convoy paradox** are those of `interface.md` under "Terms used in adjudication".

### Which moves go by convoy

Unchanged from #14, which already applied the contract's "Convoy routing" rules to decide whether a move **goes by convoy**: a move to a province an army can't reach by land, a `MoveViaConvoy`, or a plain `Move` to a province the army can reach by land when a fleet of the army's own power gives a matching `Convoy` order that passes checking. This is fixed by the orders alone. It never changes during resolution, and a move that goes by convoy never falls back to land (DATC 6.G.8, 6.G.11, 6.G.20).

### The route of a move that goes by convoy

The **fleets that carry** a move are the fleets whose followed order is a `Convoy` that matches it. Any power may own them, and the fleet that showed the intent need not be among those on the route (DATC 6.G.6). A **route** is a convoy chain made only of carrying fleets, found with the chain helpers of spec 011 in `reach.rb`.

The move **has a route** when some route has no dislodged fleet (DATC 4.A.1: only when every route is broken does the move lose its route). While some fleets' dislodgement is still undecided, a move's route is one of three things:

- **sure**: some route has only fleets that are surely not dislodged;
- **lost**: every route has a fleet that is surely dislodged, or there is no route at all;
- **open**: neither.

A fleet is dislodged when some move into its province succeeds. The fleet never moves, so this is decided like any other staying unit.

### What a route changes in the conditions

A move that goes by convoy:

- is **never a head-to-head battle** with the move of the unit it faces, whichever way that unit goes (already so in #14). So two units may swap places by convoy (DATC 6.G.1, 6.G.5, 6.G.9, 6.G.12), and the swap is decided as circular movement (below);
- has attack strength 0 and prevent strength 0 when it has no route (a `:no_route` move holds its unit with strength 1, as in #14), and its full strengths when it has one. While the route is open, the ranges of spec 014 simply widen: attack and prevent are `[0, most]`;
- cuts a support only when it has a route. While the route is open, whether the support is cut is open too (the support's range widens the same way);
- carries its attack from the **army's own province**, not from the sea (DATC 4.A.4, 6.G.13, 6.F.30), so `attacker_from` of a unit it dislodges is that province, and the dislodged unit's `by_convoy` is `true` (DATC 4.A.5).

Each of these is the stub's `path?` question asked in three values instead of two. The contract says the route is read from the fleets that are actually dislodged, which is what makes a route depend on other decisions.

### Results of the orders

- **Move, MoveViaConvoy:** `:no_route` when the move goes by convoy and has no route, then `:bounced` or `:succeeded` as before. (A move that goes by land never gets `:no_route`.)
- **Convoy:** `:unmatched` when no matching move goes by convoy (the army holds, goes by land, moves elsewhere, or isn't there: DATC 6.G.2, 6.G.3, 6.G.19), then `:disrupted` when this fleet is dislodged, otherwise `:given`. It never depends on whether the army got across (the contract's promise). Other fleets on the same route are not marked.
- `dislodged` and `by_convoy` follow the same rules as any unit.

### Circular movement with convoys

A circle of moves, each into the province the next one leaves, all succeed when nothing else stops one of them (DATC 6.C.1 to 6.C.3), and it is not a paradox. #14 applied this to circles of three or more. With convoys it also covers:

- a swap of two units in which at least one goes by convoy (a swap of two plain moves is a head-to-head battle, decided by strength, as before): DATC 6.C.6, 6.G.1, 6.G.12;
- a circle that holds convoyed armies: DATC 6.C.4.

The rule applies to a circle in which every move **has a route that is sure**. A circle with an open route in it is not circular movement; it goes to the paradox search below. A circle with a lost route has failed already: the move without a route fails, and the others fail after it (DATC 6.C.5, 6.C.7).

### Detecting a paradox (the flag, not the resolution)

The contract defines the flag: `true` exactly when the orders have no consistent result, or more than one, because whether a convoying fleet is dislodged turns on the move of an army it carries (DATC 4.A.2). Units moving in a circle are not a paradox.

The resolver decides moves as in #14: a move is decided when the range of its strengths settles it, and this is repeated until nothing more is decided. Then, if moves remain undecided:

1. **Circular movement.** Every circle of undecided moves whose routes are all sure succeeds (above). Go back to deciding.
2. **Search.** If undecided moves remain, they depend on each other through a route. Count the consistent ways to settle them, up to two:
   - take the undecided move that comes first by province and try it as succeeded and as failed;
   - after each guess, decide everything that follows (the same deciding, and circular movement);
   - a guess is **dropped** when it makes some decided move differ from what its strengths give; a guess in which every move is decided and none is dropped is **one solution**.
3. **One solution:** adopt it. The flag stays clear. The orders hold a dependency that the ranges could not see, but they have exactly one result, so by the contract they are no paradox.
4. **None, or two or more:** the orders hold a convoy paradox. `paradox` is `true`, and the moves that were still undecided before the search all fail (see below).

The search is exact against the contract's definition. It runs only on the moves left undecided, so on a position with no dependency through a route it never runs, and its cost is bounded by the undecided moves (a paradox in the DATC is a handful of them). A spec adjudicates a position of 34 units in under a second (AC-8.5).

**Circular movement and the search agree:** a circle whose routes are all sure is settled by the rule before the search can count "all succeed" and "all fail" as two results.

### What a paradox does today

When `paradox` is `true`, the contract leaves every outcome value and where each unit ends up unspecified until 0.3 (#39). This feature gives them a rule only because the next position must still be a valid `TA::Position`:

- the moves left undecided fail, and every other decision stays as the deciding made it;
- the outcomes are then read from those decisions like any others (a failed move has the result `:no_route` when it has no route, else `:bounced`; a support is `:cut` or `:given` as the decisions say);
- the units, the dislodged units and the standoffs are built from the decisions as usual, so no unit is lost or counted twice.

That is not a promise. It is tested only as far as the contract promises: `paradox` is `true`, nothing raises, `result.position` builds, and every unit of the position is in it once, either in `units` or in `dislodged_units`. #39 replaces it with the real resolution, and the outcome values of the pending cases below get their own specs then.

## DATC cases

Fixtures are the hand-written files of `spec/datc/`, named by section number, in the format of #14 (`### Fixture format`) with one new key (below). Nothing is quoted from the DATC.

### Encoded for #15 (46 cases, each with `result:` and `after:`)

| Section | Cases | Notes |
|---|---|---|
| 6.B | 6.B.18, 6.B.19 (2) | Existing checking fixtures; they get results |
| 6.C | 6.C.4, 6.C.5, 6.C.6, 6.C.7 (4) | A circle with an attacked convoy, a circle with a dislodged one, a swap by two convoys, a swap that one unit's bounce breaks |
| 6.D | 6.D.6, 6.D.16 (2) | Hold support on a convoying fleet; convoying a foreign army that dislodges your own unit |
| 6.E | 6.E.11 (1) | A swap by convoy on a split-coast province |
| 6.F | 6.F.2 to 6.F.13, 6.F.19, 6.F.20, 6.F.21, 6.F.25, 6.F.29, 6.F.30 (18) | Includes 6.F.12 (a fleet that no minimal chain needs, so its convoy order is void). 6.F.7 is encoded to its movement step; its retreat step is 0.3 |
| 6.G | 6.G.1 to 6.G.10, 6.G.12 to 6.G.20 (19) | Includes 6.G.7. 6.G.19 is the existing checking fixture, which gets its results |

With the 80 cases of #14, **126** fixtures have an `after:`, and the checking-only set (6.B.18, 6.B.19, 6.G.19) is empty.

6.F.19, 6.F.20, 6.F.21, 6.F.25 and 6.F.29 hold no paradox under the preferred rules (the contract says so), so each is adjudicated with `paradox: false` and an exact result. They are the cases that test the "every route is broken" rule, and that a fleet's dislodgement is decided before the cuts that depend on it.

### Pending for #39 (12 cases)

| Case | What it holds |
|---|---|
| 6.F.14, 6.F.15, 6.F.26 | The simplest paradox: a convoyed army attacks a supporter whose support decides whether a fleet that carries it is dislodged (6.F.15 and 6.F.26 add convoys that are not part of it) |
| 6.F.16, 6.F.17 | The same, with a beleaguered garrison (Pandin's paradox) |
| 6.F.18 | The attacked unit supports the carrying fleet itself (betrayal) |
| 6.F.22, 6.F.23, 6.F.24 | Two paradoxes tied together |
| 6.F.27 | Two separate paradoxes |
| 6.F.28 | A ring of six convoyed armies, with eight convoying fleets |
| 6.G.11 | A move to a neighboring province, ordered by convoy, whose route is cut by its own support |

These twelve are the contract's list under "DATC scope". Each has a fixture with its orders, a `check:` on every order and `paradox: true`, and **no `after:`**. Each is tested to give `paradox: true` and a valid position (AC-6.2). The DATC's preferred results for them are not asserted: a separate example per case is `skip`ped with the reason "paradox resolution: #39", so each shows as pending in the suite.

How each is detected today, from the rules above (to be confirmed by the specs; AC-6.3):

- **6.F.14, 6.F.15, 6.F.26, 6.G.11:** two solutions: the carried army attacks and cuts the support, so the fleet survives; or it doesn't, the support is given, and the fleet is dislodged.
- **6.F.16, 6.F.17, 6.F.18:** no solution: each guess leaves some decision at odds with its strengths.
- **6.F.22, 6.F.23:** two solutions. **6.F.24:** none.
- **6.F.27:** both paradoxes are in the same residue; none or two solutions.
- **6.F.28:** the ring of fleets and armies is one residue; no solution.

If any of the twelve turns out to have exactly one solution, the contract's list is wrong. Stop and ask.

### Not encoded

| Case | Why |
|---|---|
| 6.B.9 | A support has no coast (a departure in `ruleset.md`) |
| 6.B.14 | A build: 0.3 (#37) |
| 6.F.7, retreat step | Retreats: 0.3 |
| 6.H | Retreats: 0.3 |

Every case that #14 left out for #15 is therefore encoded, or pending for #39:

| Left out by #14 | Now |
|---|---|
| 6.B.18, 6.B.19 | Encoded |
| 6.C.4 to 6.C.7 | Encoded |
| 6.D.6, 6.D.16 | Encoded |
| 6.E.11 | Encoded |
| 6.F.2 to 6.F.13, 6.F.19 to 6.F.21, 6.F.25, 6.F.29, 6.F.30 | Encoded (6.F.12 included) |
| 6.F.14 to 6.F.18, 6.F.22 to 6.F.24, 6.F.26 to 6.F.28 | Pending, #39 |
| 6.G.1 to 6.G.10, 6.G.12 to 6.G.20 | Encoded (6.G.7 and 6.G.19 included) |
| 6.G.11 | Pending, #39 |

### Fixture format

One new key: a top-level **`paradox: true`**. The loader refuses it together with an `after:` (a pending case has no asserted outcome), and refuses a value that isn't `true`. A case with `paradox: true` must have a `check:` on every order and may have no `result:`. Everything else in the format of #14 stays. The adjudication runner treats a `paradox: true` case as in AC-6.2 and an `after:` case as in AC-11.1 of spec 014, with `paradox: false`.

## Definitions

- **Route, carrying fleet, sure, lost, open:** see "The route of a move that goes by convoy".
- **Paradox search, solution:** see "Detecting a paradox".

## User Stories

Every acceptance criterion is verified by a passing spec in this pull request, except those marked (review), which the implementation review and the pull request check.

### Story 1: The first example, made real

**As** the app's author
**I want** the contract's `by_sea` example to pass
**So that** I know a convoy works as written

**Acceptance criteria:**

- [ ] **AC-1.1** Given `ln` (England's army in London and fleet in the North Sea) and a move to Yorkshire with a matching convoy order from the North Sea When adjudicated Then the results are `[:succeeded, :given]`. This is the first spec written, and it fails until routes work. It is the `by_sea` example of `interface.md`, a passing example, not a pending one
- [ ] **AC-1.2** The `paradox_pos` example passes too: `paradox` is `true` and `result.position` is a valid position. Neither example is `pending`
- [ ] **AC-1.3** The `by_land` example and every other example of the contract still pass

### Story 2: Routes

**As** a player
**I want** a convoy to carry my army when the fleets are there
**So that** a convoy works as the rulebook says

**Acceptance criteria:**

- [ ] **AC-2.1** Given an army ordered to a coastal province it can't reach by land, with fleets in a chain that all give matching convoy orders Then the move succeeds when nothing stops it; with a fleet of the chain missing or without a matching order, it is `:no_route`
- [ ] **AC-2.2** Given a move with two routes, one of whose fleets is dislodged Then the move still succeeds (DATC 6.F.9 to 6.F.11, preferred option of 4.A.1); with every route broken it is `:no_route`
- [ ] **AC-2.3** Given a route whose fleets belong to other powers, wholly or in part, Then it works (DATC 6.F.10, 6.F.11); and a fleet that gave the intent but is not on the route does not matter (DATC 6.G.6, 6.F.12)
- [ ] **AC-2.4** Given the routing rules of the contract, for plain moves to a neighboring province Then: with a matching convoy order from a fleet of the army's own power that passes checking, the move goes by convoy and never falls back to land (DATC 6.G.1, 6.G.5, 6.G.8, 6.G.20); with a matching order only from another power, or from an own fleet whose order is void, it goes by land (DATC 6.G.2, 6.G.3, 6.G.7, 6.G.19); a `MoveViaConvoy` goes by convoy always (DATC 6.G.10, 6.G.12)
- [ ] **AC-2.5** Given a convoyed move Then it can bounce, can receive support, and a unit that it faces may bounce it, as any move (DATC 6.F.2, 6.F.3)
- [ ] **AC-2.6** Given a move by convoy to a neighboring province and an opposite move Then there is no head-to-head battle, whichever of the two goes by convoy (DATC 6.G.9, 6.G.10, 6.G.14, 6.G.15), and two armies may swap by convoy (DATC 6.G.1, 6.G.5, 6.G.12, 6.C.6, 6.E.11)

### Story 3: Disruption

**As** a player
**I want** a convoy to fail when its fleet is dislodged, and only then
**So that** an attack on a convoy that doesn't dislodge it changes nothing

**Acceptance criteria:**

- [ ] **AC-3.1** Given an attacked fleet that is not dislodged (a bounce, a beleaguered garrison) Then the convoy is `:given` (DATC 6.F.4, 6.F.5)
- [ ] **AC-3.2** Given a dislodged carrying fleet Then its `Convoy` order is `:disrupted` and `dislodged`, and the move it carried is `:no_route` and cuts no support (DATC 6.F.6) and contests no province (DATC 6.F.7, 6.F.8)
- [ ] **AC-3.3** Given a `Convoy` order with no matching move that goes by convoy (the army holds, goes by land, goes elsewhere, or the order is for a move that nobody ordered) Then its result is `:unmatched`, even when the fleet is dislodged (DATC 6.G.3, 6.D.27)
- [ ] **AC-3.4** Given a convoyed move that dislodges a unit Then the dislodged unit has `attacker_from` the army's own province and `by_convoy: true` (DATC 4.A.4, 4.A.5, 6.G.13, 6.F.30); a unit dislodged by a move by land has `by_convoy: false`
- [ ] **AC-3.5** The result of a `Convoy` order and the result of a support never depend on whether the move they helped succeeded (the contract's promise), shown by a spec that changes only that move's fate

### Story 4: Circular movement with convoys

**As** a player
**I want** a circle that holds convoyed armies to move
**So that** convoys and circles work together

**Acceptance criteria:**

- [ ] **AC-4.1** A circle that holds a convoyed army succeeds when its fleets are attacked but not dislodged (DATC 6.C.4), and every move of it fails when a fleet is dislodged (DATC 6.C.5); a swap by two convoys succeeds (DATC 6.C.6) and fails when one army bounces (DATC 6.C.7)
- [ ] **AC-4.2** `paradox` is `false` for each of these

### Story 5: Detecting a paradox

**As** the app's author
**I want** `paradox` set exactly when the orders hold a convoy paradox
**So that** the app can tell the host that this phase has no specified result

**Acceptance criteria:**

- [ ] **AC-5.1** Given each of the twelve pending cases Then `paradox` is `true`, nothing raises, and the position builds with each unit once (AC-6.2)
- [ ] **AC-5.2** Given every encoded case, including 6.F.19 to 6.F.21, 6.F.25 and 6.F.29, and 6.C.4 to 6.C.7 Then `paradox` is `false`
- [ ] **AC-5.3** Given the simplest paradox (the `paradox_pos` example) Then a spec shows the search finds two solutions, and given the betrayal case (6.F.18) it finds none. Resolver specs may call the internal search directly
- [ ] **AC-5.4** Given a position in which the ranges alone can't decide a move but the orders have exactly one result, Then `paradox` is `false` and the result is that one. If no such position can be found, the spec for the one-solution branch drives it with a position built for the purpose, or the branch is removed and the spec says so (review)
- [ ] **AC-5.5** Given a paradox in one part of the board and independent orders elsewhere, Then `paradox` is `true`, nothing raises, and every unit of the position is in the next position once (the contract leaves every outcome unspecified)
- [ ] **AC-5.6** Given `paradox` is `true` Then the outcome list has one outcome for each order and every outcome is a valid `TA::Outcome`, so the adjudication builds

### Story 6: The DATC fixtures and their runner

**As** a maintainer
**I want** each case adjudicated from its fixture
**So that** the DATC is the test

**Acceptance criteria:**

- [ ] **AC-6.1** The 46 cases of "Encoded for #15" each have `result:` on every order and an `after:`, and with the 80 of #14 give a runner of exactly 126; the checking-only list is empty; none of "Not encoded" has an `after:`
- [ ] **AC-6.2** Each of the twelve pending files has `paradox: true`, `check:` on every order and no `after:`. For each, a spec asserts `paradox` is `true`, `result.position` builds, every unit is in the position once, and `outcomes` holds one outcome for each order and one for each implied hold. A second example for each is `skip`ped, with the reason "paradox resolution: #39". Those twelve are the only pending examples of the suite
- [ ] **AC-6.3** Each of the twelve is checked to be one that the paradox search finds none or two solutions for. If one has exactly one, that is reported to the coordinator, not changed
- [ ] **AC-6.4** The loader refuses `paradox: true` with an `after:`, and any other value of `paradox`. A spec shows each refusal
- [ ] **AC-6.5** The checking runner still passes, with its expected lists updated: 6.B.18, 6.B.19 and 6.G.19 move into the adjudicated list; the twelve pending files are in the set it expects; `left_out` is updated
- [ ] **AC-6.6** Every fixture holds the units and orders of its DATC case and nothing more, written in our own words, with the summary citing no DATC text (review). The DATC overlap check finds 0 shared 8-word runs over every file the pull request changes (the maintainer's check, run by the author, result in the pull request)
- [ ] **AC-6.7** The same orders in another order give the same results and the same flag, for every encoded case (AC-9.1 of spec 014), and the twelve pending ones

### Story 7: The stub is gone

**As** the next person to read the repository
**I want** the temporary behavior removed
**So that** nothing says convoys don't work

**Acceptance criteria:**

- [ ] **AC-7.1** `spec/trucebearer/adjudicator/adjudicate_convoy_stub_spec.rb` is deleted. A spec file of the same subject that holds real specs may replace it. Nothing says convoys never work
- [ ] **AC-7.2** The `pending "convoys: #15"` lines of the two examples are gone
- [ ] **AC-7.3** The resolver's comments about "this release" and "#15" are replaced by what the code now does, and the unreachable defensive branch of #14 (`last_resort`) is replaced by the search above. `Resolver` stays `private_constant` and `docs/interface.md` is not edited

### Story 8: Correctness beyond the DATC

**As** a maintainer
**I want** convoys tested on random boards, with an independent check of the flag
**So that** a rare combination can't fail in a game

**Acceptance criteria:**

- [ ] **AC-8.1** The generator makes boards with convoys: armies on the coast, fleets at sea that form chains of one to three, `Move`, `MoveViaConvoy` and `Convoy` orders (from own fleets and foreign fleets), attacks on carrying fleets, supporters attacked from the destination of a convoyed move, swaps by convoy, and circles with a convoyed move. At least 20 boards each hold a move that goes by convoy, a dislodged carrying fleet, a swap by convoy, and a flagged paradox, each counted by the spec from the orders. The boards of #14 stay and still pass
- [ ] **AC-8.2** On **every** board, `TA.adjudicate` returns an `Adjudication` and raises nothing, every unit appears once, and no unit is dislodged by a unit of its own power. When `paradox` is `false`, the result satisfies the conditions of spec 014 as extended for convoys (route, cut with a route, no head-to-head with a convoy), re-stated independently in `spec/support/conditions.rb` from the contract and the DATC, not from the resolver
- [ ] **AC-8.3** On boards of at most 12 units, a reference written in the spec, apart from the resolver, tries every set of move results (success or failure for each move), keeps those that satisfy the conditions, applies circular movement (it drops a consistent set in which a circle of moves fails although the set with that circle succeeding is also consistent), and says the board holds a paradox when **none or more than one** is left. `paradox` equals that on every such board. At least 20 small boards are flagged, and at least 20 hold a convoy and are not
- [ ] **AC-8.4** On every board, a flagged board holds at least one move that goes by convoy, and the converse is not claimed
- [ ] **AC-8.5** A position of 34 units, with convoys, adjudicates in under a second
- [ ] **AC-8.6** The same boards with the orders shuffled give the same results and the same flag

### Story 9: Records

**As** the next person to read the repository
**I want** every choice written where the contract says
**So that** nothing is decided silently

**Acceptance criteria:**

- [ ] **AC-9.1** `docs/ruleset.md`: the row that says convoys don't work in this build (4.A.1, 4.A.3, "temporary") is removed. Rows are added for: what a route needs and that only a full break loses it (4.A.1, already in the table, is extended to name the fleets that carry); the swap and circle by convoy (5.B.9); the paradox flag and that it is exactly the contract's (4.A.2), with that the outcomes of a flagged board are unspecified until #39; the "every undecided move fails" fallback; and what happens to the cycle row of 5.B.9 that said "#15 decides" (it is now this rule)
- [ ] **AC-9.2** `CHANGELOG.md`: the "Unreleased" entry of #14 loses its caveat that convoy routing arrives later, and an entry under "Added" names convoy routes, `:given` and `:disrupted`, `by_convoy`, the `paradox` flag and the DATC cases (#15). No "Changed" entry: nothing in the contract changed
- [ ] **AC-9.3** `git diff --name-only main...HEAD` lists only paths under `adjudicator/`, and `docs/interface.md` is not among them

## Open Questions

1. **A flagged board's other results.** The contract leaves every result unspecified while the flag is set, "even for orders that have nothing to do with the paradox". The proposal fails the moves that were undecided and keeps every other decision. **Recommendation:** keep this. It gives a valid position without any new rule. The alternative, failing every convoyed move, is simpler to state and changes more.
2. **The search's exactness.** The search counts solutions, so an exact flag costs a few lines more than "flag whenever the ranges stall". **Recommendation:** the exact search, because the contract says exactly, and the reference of AC-8.3 would catch the shortcut otherwise. If the search shows no position with exactly one solution, AC-5.4's branch is removed and the rule becomes "flag whenever moves remain after circular movement", and the spec says so.
3. **A swap where one army goes by convoy and the other by land.** Neither is a head-to-head battle. **Recommendation:** treat it as circular movement, as the contract's examples do (DATC 6.G.9).
4. **Size.** About 46 fixtures, 12 pending fixtures, the resolver change, the generator and the independent check. **Proposal:** one pull request, unless the plan shows more than about 1 200 added lines of code and specs apart from fixtures. If it does, split at Gate B: routes and disruption first (with every encoded case, and boards with convoys but with the paradox flag left to the old defensive fallback), then the paradox search, the twelve pending fixtures and the reference check. A single spec covers both.

## Notes for the plan

- The one place a route is decided is `Resolver#path?`, which #14 left as a stub. It becomes a three-valued question, `route(move)`, answering sure, lost or open, built on `Reach` with the carrying fleets only. `Reach` gets one new method that takes a set of seas, and its existing chain check calls it; nothing else in `reach.rb` or `check.rb` changes.
- A fleet's dislodgement is three-valued like a support's cut: dislodged when some move into it has succeeded, not when every move into it has failed, open otherwise.
- The strengths and the cut take the open route as a wider range. The ranges must stay sound: a range may be wider than the truth, never narrower, so a decision made from it holds under every outcome.
- The paradox search works on a copy of the decisions, so a dropped guess leaves no trace.
- Fixtures are derived by hand from the DATC position and our own reading of the rules, with the contract's result names: for example, a convoy order whose army went by land is `:unmatched` where the DATC's own label differs (labels are free, DATC 4.E.2).

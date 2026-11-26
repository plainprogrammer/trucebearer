# Feature 012: List the legal orders for a unit

**Status:** Draft
**Version:** 1.0.0
**Created:** 2026-11-25
**Last Updated:** 2026-11-25
**Issue:** #12
**Branch:** `adjudicator/12-legal-orders`

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 1.0.0 | 2026-11-25 | Initial draft |

## Problem Statement

`docs/interface.md` (merged in #5) promises `TA.legal_orders(position, unit)`: every legal order for one unit, in a fixed order. The app's order pickers offer only what this returns, so a player can't build an invalid order. #11 built `TA.check` and left the board questions it asks ("can reach", "convoy chain", "minimal chain") as internal code so that this feature could reuse them. Nothing implements `legal_orders` yet, and #13 (release 0.1.0) and #14 (adjudication) wait for it.

The contract's central promise is agreement with checking: an order is in the list exactly when `TA.check` accepts it. A unit has 11,482 order values to choose from (a hold, a move to each of 81 locations, a move via convoy and a support to hold for each of 75 provinces, and a support to move and a convoy for each of 75 × 75 pairs), so the list can't be built by trying every one on every page load. The measurements below decide how it is built.

## Goals

- `TA.legal_orders(position, unit)` returns an `Array` of orders that equals, as a set, the orders for that unit that `TA.check` accepts, and comes in the list order of `docs/interface.md` `### List order`.
- Agreement with `TA.check` is proved in both directions, over the full candidate space, for sampled positions that include the starting position, split coasts, a convoy chain and a non-movement phase.
- It is fast enough to call for every unit on every page load, with a concrete target and a spec that proves it.
- Every Ruby example under `## Legal orders` in `docs/interface.md` runs as a passing spec.
- No rule is written twice: the decision whether an order is legal stays in `Check`, and the board questions stay in `Reach`.

## Non-Goals

- **Any change to `docs/interface.md`.** This feature implements the contract as it stands. If building it shows that the contract is wrong or contradicts itself (for example a list-order rule that `check` contradicts), work stops and goes to the coordinator. None was found while writing this spec (see Open Questions).
- **A new public class or method besides `TA.legal_orders`.** The generator is an internal module, private to the gem like `Reach` and `Check`. No new value object, so no `Marshal` work.
- **Adjudication (#14, #15)** and the 11 DATC cases #11 left to #14 (6.D.22–24, 6.D.28–30, 6.D.32, 6.E.14, 6.F.1, 6.F.12 and 6.G.7). They are not encoded here.
- **Retreat and adjustment orders.** They have no order classes yet (0.3); a position in those phases gives an empty list.
- **Looking at any submitted order.** The list depends on the position only.
- A map other than the classic one, and a benchmark gem.

## Users and Context

**Primary users:** the app, which calls `TA.legal_orders` for each of a player's units to fill the order pickers, on each page load; and the agent building #14, which relies on listed orders always passing checking.

**Secondary users:** James, who reads the examples in `docs/interface.md` and expects them to be true.

**Usage context:** a position has up to 34 units. A page for one player lists the orders of that player's units; a host's page may list all of them. Calls are made with a position the app has already built, so it is well formed.

## How the list is generated

This is the decision the Issue leaves to Gate A. Two ways were measured on the starting position and on a stress position (19 fleets, one in every sea, and 20 armies on coastal provinces: 39 units), using `Process.clock_gettime` on a development laptop, Ruby 4.0:

| Approach | What it does | Starting position, 22 units | Stress position, 39 units |
|---|---|---|---|
| **A. Filter every candidate through `TA.check`** | Builds all 11,482 candidate orders per unit (252,604 for the 22 units) and keeps those `TA.check` accepts | 1,143 ms (558 ms of it just building the candidates) | 2,828 ms |
| **B. Narrow, then check** | Builds only candidates that could possibly be legal, from the reach tables and from where units stand, and keeps those that `Check.reason_for` accepts | **18 ms** | 644 ms |
| C. Generate directly | Writes each legality rule again as a generator, with no check | not measured | not measured |

Both A and B gave the same lists as each other on both positions (238 and 5,160 orders in total).

**Choice: B.** A is correct by construction and the simplest, but at 1.1 s to 2.8 s per page it fails the Issue's "fast enough to call for every unit on every page load". C is fastest but writes every rule twice, which the Issue rules out ("reuse, don't duplicate") and which can drift. B keeps the decision in one place: whether a candidate is legal is decided by `Check.reason_for`, the function `TA.check` itself uses. B only decides which candidates are worth asking about, and each narrowing is a necessary condition taken from the contract's own wording:

- a move can only go to a province the unit reaches by one step, or, for an army on a coastal province, to a coastal province (a chain is then possible);
- a move via convoy is for an army, and only to a province it reaches by land;
- a support is only for a province that holds a unit, and a support to move only to a province the supporter reaches;
- a convoy is only for a fleet in a sea province, from a province that holds an army, to a coastal province.

**What B risks:** a narrowing that is too tight silently drops a legal order. That is the one failure the agreement spec (Story 5) exists to catch, so it checks the "nothing legal is missing" direction over the full candidate space and not over B's own candidates. The other direction (everything listed passes `TA.check`) holds by construction, and is checked as well.

## Performance target

**Target: listing all 22 units of the starting position takes under 100 ms** (measured 18 ms). A spec proves it with a bound of **1,000 ms**, which is 55 times the measurement and still below what approach A takes (1,143 ms here), so the bound can't flake on a slow CI machine and still catches a fall back to filtering every candidate.

**Stress target:** the 39-unit position above takes under 1 s (measured 644 ms); the spec's bound is 5,000 ms. The cost there is the convoy orders for 19 sea fleets (each asks whether the fleet is on a minimal chain for each army and coastal destination). If measuring in the plan shows more than that on a plausible board, a convoy narrowing may be added, if it is a necessary condition drawn from `Reach`, and the agreement spec guards it.

The measured times go in the pull request description. The spec uses `Process.clock_gettime(Process::CLOCK_MONOTONIC)` and the standard library only.

## Definitions

- **Candidate space** (for one unit): every order value of the six classes that names the unit's owner as `power` and the unit's province as `at`, with every province, and for a move every location (a province, or a split-coast province with each coast, and without a coast): 1 hold, 81 moves, 75 moves via convoy, 75 supports to hold, 75 × 75 supports to move, and 75 × 75 convoys, 11,482 orders. "Each order has one accepted form", so this is the whole finite space.
- **On the board:** the position holds a unit with the same power, type and location as the argument (the contract's wording).
- **Legal:** `TA.check(position, order).legal`.

## User Stories

Every acceptance criterion is verified by a passing spec in this pull request, except those marked (review), which the implementation review and the pull request check.

### Story 1: The first example

**As an** app developer
**I want** a unit's orders in a fixed list that starts with the hold
**So that** an order picker can show them in a stable order

**Acceptance criteria:**

- [ ] **AC-1.1** Given the starting position and England's fleet in London When `TA.legal_orders(start, fleet)` is called Then `first(3)` is the hold, then the move to `eng`, then the move to `nth`, each naming `england` and `lon`, with no coast. This is the first spec written, and it fails until `TA.legal_orders` exists
- [ ] **AC-1.2** Given a French fleet in London in the starting position (no such unit) When it is listed Then the result is `[]`
- [ ] **AC-1.3** Given any unit on the board in a movement position When it is listed Then the result is an `Array` whose first element is that unit's hold, and the array is the caller's own: changing it never changes the result of a later call

### Story 2: Empty, never an exception

**As an** app developer
**I want** an empty list when there is nothing to offer
**So that** I don't have to guard the call

**Acceptance criteria:**

- [ ] **AC-2.1** Given a position in the retreat phase, and one in the adjustment phase, and a unit that is on the board When it is listed Then the result is `[]`
- [ ] **AC-2.2** Given a movement position and a unit that is not on the board Then the result is `[]`, for each of: no unit in that province; a unit of another power there; a unit of another type there; a fleet standing on the other coast of the same split-coast province
- [ ] **AC-2.3** Given an argument that is not a `TA::Position`, or a unit that is not a `TA::Unit` (`nil`, a hash form, an order, a `Symbol`) When `TA.legal_orders` is called Then it raises `TA::InvalidInput` and the message includes the offending argument, as `TA.check` does. Nothing else raises, for a position and a unit that were built without raising

### Story 3: What is in the list

**As an** app developer
**I want** every legal order, including the pointless ones, and only those
**So that** the picker offers each move a player could give

**Acceptance criteria:**

- [ ] **AC-3.1** Given any unit on the board in a movement position When it is listed Then every listed order names the unit's owner as `power` and the unit's province as `at`
- [ ] **AC-3.2** Given Austria's army in Vienna in the starting position When it is listed Then it includes the support for Russia's army in Warsaw to move to Galicia (a support for a move nobody has ordered, and one for another power's unit), and a support to hold for each neighboring unit
- [ ] **AC-3.3** Given `at_sea` of the interface (French fleets in the Mid-Atlantic and the Gulf of Lyon) When the Mid-Atlantic fleet is listed Then its moves to Spain are exactly one for the north coast and one for the south coast, in that order, and none without a coast. Given a fleet that can reach one coast of a split-coast province Then it gets the one move naming that coast, and none without
- [ ] **AC-3.4** Given a fleet on a split coast (for example Saint Petersburg's south coast, and Spain's north coast in a position that holds such a fleet) When it is listed Then its moves are exactly those whose coast it can reach from where it stands, and a move to its own province is never listed (not for the other coast either)
- [ ] **AC-3.5** Given `ln`, the contract's position with England's army in London and fleet in the North Sea When the army is listed Then its moves via convoy are exactly one, to `yor`; it has a plain move to each of Wales and Yorkshire (by land) and to each of `bel`, `den`, `edi`, `hol`, `nwy` (by convoy only); and no plain move to a sea province, an inland province or its own province
- [ ] **AC-3.6** Given a fleet Then its list holds no move via convoy and no plain move that only a chain could make. Given an army not on a coastal province Then it holds no move through a chain
- [ ] **AC-3.7** Given the three convoy positions #11 pinned (a sea fleet that touches a chain fleet but neither end; two fleets that form the only chain; a fleet that a one-fleet chain bypasses) When the fleets are listed Then a fleet has a convoy for an army's province and a destination exactly when it is on a minimal chain between them: both fleets of the only chain list the convoy, the bypassed fleet does not, and the fleet with no chain through it does not. (Story 5 proves the agreement with `TA.check` for the same positions.)
- [ ] **AC-3.8** Given a position and a unit Then the list depends on the position alone: it is the same list however the position's `units` are ordered when it was built, for a position built from the same units in a different order, and `legal_orders` never changes the position or the unit
- [ ] **AC-3.9** Given a unit that is the only unit on the board Then its list holds its hold and its moves, and nothing that needs another unit: no support and no convoy

### Story 4: The order of the list

**As an** app developer
**I want** the same list, in the same order, on every call
**So that** pickers don't shuffle

**Acceptance criteria:**

- [ ] **AC-4.1** Given any listed unit When its list is read Then it is the hold, then all moves, then all moves via convoy, then all supports to hold, then all supports to move, then all convoys, with no group interleaved with another
- [ ] **AC-4.2** Given each group Then it is sorted as `docs/interface.md` says: moves by destination province then coast; moves via convoy by destination; supports to hold by target; supports to move by origin then destination; convoys by origin then destination, with provinces and coasts compared by identifier (a province or coast compared as its `to_s`)
- [ ] **AC-4.3** Given the same position and unit When the list is made twice, and when made in a position rebuilt from `to_h` and `from_h` Then the two lists are equal, element by element
- [ ] **AC-4.4** Given any listed unit Then the list holds no duplicate order

### Story 5: Agreement with checking, in both directions

**As** James
**I want** the list and the checker proved to say the same thing
**So that** a player can never pick a move the adjudicator calls illegal, and never be denied one it would accept

**Acceptance criteria:**

- [ ] **AC-5.1** Given each sampled position, and each unit in it When it is listed Then every order in the list passes `TA.check` (`legal: true`)
- [ ] **AC-5.2** Given each sampled position and each unit in it When every order of the unit's whole candidate space (see Definitions: not only the narrowed candidates) is checked Then every order that passes `TA.check` is in the list. Together with AC-5.1 the list equals the set of passing orders
- [ ] **AC-5.3** Given the sampled positions Then they include at least:
  - the starting position (22 units);
  - a position with a fleet on each of the six split coasts (`bul/ec`, `bul/sc`, `spa/nc`, `spa/sc`, `stp/nc`, `stp/sc`) and neighboring units;
  - `ln`, the contract's convoy-chain position, and a position with a two-fleet chain and a fleet that a shorter chain bypasses;
  - the stress position (19 sea fleets, 20 coastal armies);
  - a retreat-phase position and an adjustment-phase position, where both sides of the agreement are empty (`TA.check` gives `:wrong_phase` for every order)
- [ ] **AC-5.4** Given a unit that is not on the board Then its list is `[]` (AC-2.2). The agreement promise is for a unit that is on the board: `TA.check` judges an order by the unit the position holds in the province, so it may accept orders for a unit that differs from the argument, and Story 5 therefore samples only units the position holds
- [ ] **AC-5.5** (review) Given the agreement spec's running time Then it is stated in the pull request. If the spec takes more than about 10 seconds it is tagged `:slow` and CI runs it, as `rspec` with no filter does; none of the specs is excluded from CI. At the measured cost (about 1 s per 22 units for the candidate space) no tag is expected

### Story 6: Fast enough for every page

**As an** app developer
**I want** to list every unit's orders on each page load
**So that** the picker never waits

**Acceptance criteria:**

- [ ] **AC-6.1** Given the starting position When `TA.legal_orders` is called for each of its 22 units Then the total time is under 1,000 ms (target: under 100 ms), measured with `Process.clock_gettime(Process::CLOCK_MONOTONIC)`, after one warm-up call that is not timed
- [ ] **AC-6.2** Given the stress position (39 units) When every unit is listed Then the total time is under 5,000 ms
- [ ] **AC-6.3** (review) Given the pull request description Then it records the measured times of both examples and of the filter-every-candidate approach they were compared against, from the machine the author used, and says which number is the target and which is the bound
- [ ] **AC-6.4** Given the helpers of #11 Then `Reach` is reused for adjacency and chains, `Check.reason_for` decides legality, and no legality rule appears a second time in the generator. If a helper needs a small change to be reusable it is made in this pull request, and the specs of #11 pass unchanged (review: the implementation review reads the diff for a duplicated rule)

### Story 7: The examples and the record

**As** James
**I want** every example in the interface to run, and the change recorded
**So that** the document stays true

**Acceptance criteria:**

- [ ] **AC-7.1** Given every Ruby example under `## Legal orders` of `docs/interface.md` (the three `first(3)`, hold and `[]` calls; the Vienna support; the Spain coasts; the `ln` calls and `retreat`), built as the document builds it When the specs run Then each is a passing example
- [ ] **AC-7.2** (review) Given `interface_examples_spec.rb` Then its header comment no longer lists `TA.legal_orders` as excluded, and says where the examples run now
- [ ] **AC-7.3** (review) Given `adjudicator/CHANGELOG.md` Then "Unreleased → Added" has an entry for `TA.legal_orders`, citing #12, and the #11 entry's remark that the helpers are for #12 stays true
- [ ] **AC-7.4** (review) Given the pull request Then `git diff --name-only main...HEAD` lists only paths under `adjudicator/`, and `docs/interface.md` is unchanged
- [ ] **AC-7.5** Given the generator module Then it is private to the gem: referring to `TA::LegalOrders` raises `NameError`, and `TA.legal_orders` is the only public method or constant added to `Trucebearer::Adjudicator`

## Functional Requirements

### FR-1: `TA.legal_orders`

A module function of `Trucebearer::Adjudicator`: `TA.legal_orders(position, unit)`. It returns a new `Array` of order objects.

**Must:**
- Raise `TA::InvalidInput` for a position that is not a `TA::Position` or a unit that is not a `TA::Unit`, with the argument in the message.
- Return `[]` for a position that isn't in the movement phase, and for a unit that is not on the board (same power, type and location).
- Otherwise return exactly the orders for the unit that `TA.check` accepts, each in its one accepted form, in the list order of the contract, with no duplicates.
- Give every order the unit's owner as `power` and the unit's province as `at`.
- Give a fleet one move for each coast of a split-coast province that it can reach, and no coastless move there; give an army a plain move to a province only a convoy chain reaches and, for a province it also reaches by land, both a plain move and a move via convoy.
- Judge by the position alone, and change neither argument.

**Must not:**
- Look at any other order, or at who owns a province's supply center.
- Write any legality condition a second time (the one place is `Check`).
- Add a public class, constant or method besides `TA.legal_orders`.

### FR-2: The generator (internal)

A module, private to the gem, in `lib/trucebearer/adjudicator/legal_orders.rb`, required after `check`. It builds, for a unit, a candidate list of every order that could be legal (never fewer than the legal orders), in the contract's list order, and keeps the candidates that `Check.reason_for` accepts.

**Must:**
- Take its candidates from `Reach`'s tables and from the units in the position, so the map data stays the only place adjacency is written.
- Produce a candidate list that is a superset of the legal orders for every position, which the agreement spec proves for the sampled positions.
- Leave `check.rb` and `reach.rb` as they are unless a helper needs a small change to be reusable; any such change keeps #11's specs passing unchanged.

### FR-3: The record

**Must:**
- Add "Unreleased → Added" to `adjudicator/CHANGELOG.md` (AC-7.3).
- Update the header comment of `interface_examples_spec.rb` (AC-7.2).
- Require the new file from `lib/trucebearer/adjudicator.rb`.

**Must not:**
- Change `docs/interface.md`, or any file outside `adjudicator/`.
- Add a dependency. Standard library only.

## Non-Functional Requirements

### Performance

See "Performance target": 22 starting units under 100 ms (spec bound 1 s); the 39-unit stress position under 1 s (spec bound 5 s). The measurements are in "How the list is generated" and will be repeated for the pull request.

### Reliability

- Listing is deterministic: the same position and unit always give an equal list.
- `TA.legal_orders` raises only `TA::InvalidInput`, and only for an argument of the wrong class.

### Security

- No input is evaluated or read from disk. The agreement spec builds its own candidates.

## Error Scenarios

| Scenario | Expected Behavior |
|----------|-------------------|
| A position that isn't in the movement phase | `[]` |
| A unit that isn't on the board (no unit there, another power, another type, or the other coast) | `[]` |
| A position that is not a `TA::Position`, or a unit that is not a `TA::Unit` | Raises `TA::InvalidInput`, and the message includes the argument |
| A unit with nothing legal beyond its hold | A list of one: the hold |

## Open Questions

None blocking. These are decisions made in this spec, put to the maintainer at Gate A so approval settles them.

1. **Malformed arguments raise.** The contract says the list is empty for a non-movement position or a unit not on the board, but does not say what a non-`Position` or non-`Unit` argument does. This spec has it raise `TA::InvalidInput`, as `TA.check` does for its own arguments and as `## Errors` says ("raised for … a bad hash … an impossible value object"). No contract line is contradicted.
2. **Approach B over A and C** (see "How the list is generated"). If the maintainer prefers A's simplicity and accepts about a second per page, it is a one-line change to the generator, and every other criterion stays.
3. **Agreement spec untagged.** About 1 s per 22 units over the whole candidate space, a few seconds for all samples, so it runs with the ordinary suite and in CI. It is tagged `:slow` only if it grows past about 10 s.
4. **No contradiction found** between the list-order rules, the "When each order type is legal" section and `check`. The contract's `ln` example (`yor` the only destination reachable both by land and by convoy) agrees with `check`, and one prototype run of both approaches on the starting and stress positions gave identical lists.

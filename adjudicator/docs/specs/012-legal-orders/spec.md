# Feature 012: List the legal orders for a unit

**Status:** Approved
**Version:** 1.1.2
**Created:** 2026-11-25
**Last Updated:** 2026-11-25
**Issue:** #12
**Branch:** `adjudicator/12-legal-orders`

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 1.0.0 | 2026-11-25 | Initial draft |
| 1.1.0 | 2026-11-25 | Folded in the Gate A review (round 1, changes required, three blocking):<br>• AC-5.3 needs two split-coast positions, since a position can't hold two units in one province.<br>• The performance bound no longer claims to catch a fall back to filtering; a same-example relative guard (B at least 10 times faster than A) does, next to coarse ceilings. A mid-game target is added, and the stress position is named.<br>• "No rule written twice" is reworded: the generator may only drop candidates by the four listed narrowings, and every kept order is decided by `Check.reason_for`.<br>• Fixed-seed random boards join the agreement spec; AC-3.7, AC-4.2, AC-3.8, AC-1.3 and AC-7.5 are made literal |
| 1.1.1 | 2026-11-25 | Gate A round 2 (approve, nothing blocking): AC-6.3 compares sets; AC-7.5 holds the literal lists; the mid-game board is named and AC-5.2 requires a 34-unit board with sea fleets; the running-time estimate is no longer promised |
| 1.1.2 | 2026-11-25 | Gate A approved by the coordinator under the maintainer's delegation. Open Question 1 decided: a non-position or non-unit argument raises `TA::InvalidInput`. Status is now Approved. Notes for the plan: the relative guard (AC-6.3) uses the median of several runs and may be dropped if it ever flakes, and the plan states how long the agreement spec takes and how CI runs it |

## Problem Statement

`docs/interface.md` (merged in #5) promises `TA.legal_orders(position, unit)`: every legal order for one unit, in a fixed order. The app's order pickers offer only what this returns, so a player can't build an invalid order. #11 built `TA.check` and left the board questions it asks ("can reach", "convoy chain", "minimal chain") as internal code so that this feature could reuse them. Nothing implements `legal_orders` yet, and #13 (release 0.1.0) and #14 (adjudication) wait for it.

The contract's central promise is agreement with checking: an order is in the list exactly when `TA.check` accepts it. A unit has 11,482 order values to choose from (a hold, a move to each of 81 locations, a move via convoy and a support to hold for each of 75 provinces, and a support to move and a convoy for each of 75 × 75 pairs), so the list can't be built by trying every one on every page load. The measurements below decide how it is built.

## Goals

- `TA.legal_orders(position, unit)` returns an `Array` of orders that equals, as a set, the orders for that unit that `TA.check` accepts, and comes in the list order of `docs/interface.md` `### List order`.
- Agreement with `TA.check` is proved in both directions, over the full candidate space, for sampled positions that include the starting position, split coasts, a convoy chain and a non-movement phase.
- It is fast enough to call for every unit on every page load, with a concrete target and a spec that proves it.
- Every Ruby example under `## Legal orders` in `docs/interface.md` runs as a passing spec.
- The decision whether an order is legal is made only by `Check`, and the board questions stay in `Reach`. The generator adds nothing to the rules: it only chooses which orders are worth asking `Check` about.

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

This is the decision the Issue leaves to Gate A. Two ways were measured on the starting position and on a stress position (19 fleets, one in every sea, and 20 armies on coastal provinces: 39 units), using `Process.clock_gettime` on a development laptop, Ruby 4.0 (the stress position is defined under "Performance target"):

| Approach | What it does | Starting position, 22 units | Stress position, 39 units |
|---|---|---|---|
| **A. Filter every candidate through `TA.check`** | Builds all 11,482 candidate orders per unit (252,604 for the 22 units) and keeps those `TA.check` accepts | 1,143 ms (558 ms of it just building the candidates) | 2,828 ms |
| **B. Narrow, then check** | Builds only candidates that could possibly be legal, from the reach tables and from where units stand, and keeps those that `Check.reason_for` accepts | **18 ms** | 644 ms |
| C. Generate directly | Writes each legality rule again as a generator, with no check | not measured | not measured |

Both A and B gave the same lists as each other on both positions (238 and 5,160 orders in total). The review reproduced this and also found them identical on 40 fixed-seed random boards of 5 to 34 units.

**Choice: B.** A is correct by construction and the simplest, but at 1.1 s to 2.8 s per page it fails the Issue's "fast enough to call for every unit on every page load". C is fastest but writes every rule twice, which the Issue rules out ("reuse, don't duplicate") and which can drift. B keeps the decision in one place: whether a candidate is legal is decided by `Check.reason_for`, the function `TA.check` itself uses. B only decides which candidates are worth asking about, and each narrowing is a necessary condition taken from the contract's own wording:

- **N1.** A move goes only to a location the unit reaches in one step, or, for an army on a coastal province, to any coastal province (a chain is then possible). Every convoy chain joins two coastal provinces, so no other move can pass `Check`.
- **N2.** A move via convoy is for an army, and only to a province it reaches by land.
- **N3.** A support to hold is only for a province that holds a unit, and a support to move only from a province that holds a unit and to a province the supporter reaches in one step.
- **N4.** A convoy is only for a fleet in a sea province, from a province that holds an army, to a coastal province.

**The rule for the generator.** It may drop a candidate only by N1 to N4. Every order it lists is decided by `Check.reason_for` and nothing is listed without that call. Each narrowing is a necessary condition that `Check` itself applies before any later condition (the review traced each in `check.rb`), so it can only skip orders `Check` would refuse. Adding or changing a narrowing is a change to this spec, and the agreement spec has to keep passing.

**What B risks:** a narrowing that is too tight silently drops a legal order. That is the one failure the agreement spec (Story 5) exists to catch, so it checks the "nothing legal is missing" direction over the full candidate space and not over B's own candidates, on the sampled positions and on fixed-seed random boards. The other direction (everything listed passes `TA.check`) holds by construction, and is checked as well.

## Performance target

**Targets** (on a development laptop):

| Position | Target for all its units | Measured |
|---|---|---|
| The starting position, 22 units (no fleet at sea, so no convoy work) | under 100 ms | 18 ms |
| The mid-game board: the 34-unit random board of AC-5.2 with several fleets at sea | under 250 ms | 44 to 136 ms on random boards (2 to 13 fleets at sea; the 13-fleet boards were the slower ones) |
| The stress position, 39 units | under 1 s | 644 ms |

**The stress position:** a fleet in each of the 19 sea provinces and an army in each of the first 20 coastal provinces by identifier, with the seven powers dealt in turn in identifier order. It is the worst case the rules allow for convoy work and is not a board a game reaches.

**What the specs prove.** Absolute timings differ by machine, so the specs use two kinds of check:
- **Ceilings that can't flake:** the starting position under 1,000 ms, the stress position under 5,000 ms. They are coarse. They catch a gross regression, not a fall back to approach A (A takes about 0.9 to 1.1 s for the starting position).
- **A relative guard, timed in the same example:** listing the 22 starting units by approach A (every candidate through `TA.check`) takes at least 10 times as long as `TA.legal_orders` does (observed: about 50 times). This is what catches a fall back to filtering every candidate, and it holds on any machine.

The measured times of all rows go in the pull request description. The specs use `Process.clock_gettime(Process::CLOCK_MONOTONIC)` and the standard library only.

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
- [ ] **AC-1.3** Given any unit on the board in a movement position When it is listed Then the result is an `Array` whose first element is that unit's hold, and the array is not frozen and is the caller's own: changing it never changes the result of a later call (the orders in it are immutable `Data` objects)

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
- [ ] **AC-3.7** Given these three positions (the ones #11 pinned for convoys) When the fleets are listed Then:
  - Spain/Marseilles: a French army in Marseilles, a French fleet in the Western Mediterranean, an Italian fleet in the Gulf of Lyon and an Italian army in Spain. The Italian fleet's list includes `Convoy(italy, at: gol, from: mar, to: spa)`; the French fleet's list does not include `Convoy(france, at: wes, from: mar, to: spa)`, because the one-fleet chain bypasses it;
  - an English army in London, an English fleet in the English Channel and a French fleet in the Mid-Atlantic Ocean. Each fleet's list includes `Convoy(…, from: lon, to: por)` for its own power;
  - an English army in London, English fleets in the English Channel, the Irish Sea and the North Sea. The Irish Sea fleet's list does not include `Convoy(england, at: iri, from: lon, to: bel)`, which has no chain through the Irish Sea fleet.

  (Story 5 proves the agreement with `TA.check` for the same positions.)
- [ ] **AC-3.8** Given a position and a unit Then the list depends on the position alone: it is the same list for a position built from the same units in a different order, and `legal_orders` never changes the position or the unit
- [ ] **AC-3.9** Given a unit that is the only unit on the board Then its list holds its hold and its moves, and nothing that needs another unit: no support and no convoy

### Story 4: The order of the list

**As an** app developer
**I want** the same list, in the same order, on every call
**So that** pickers don't shuffle

**Acceptance criteria:**

- [ ] **AC-4.1** Given any listed unit When its list is read Then it is the hold, then all moves, then all moves via convoy, then all supports to hold, then all supports to move, then all convoys, with no group interleaved with another
- [ ] **AC-4.2** Given each group Then it is sorted as `docs/interface.md` says: moves by destination province then coast; moves via convoy by destination; supports to hold by target; supports to move by origin then destination; convoys by origin then destination, with provinces and coasts compared by identifier (a province or coast compared as its `to_s`). Supports to hold are sorted by target, as the contract says. A move without a coast and a move with a coast never share a destination province (a province either has split coasts or doesn't), so the sort never compares a missing coast with a named one
- [ ] **AC-4.3** Given the same position and unit When the list is made twice, and when made in a position rebuilt from `to_h` and `from_h` Then the two lists are equal, element by element
- [ ] **AC-4.4** Given any listed unit Then the list holds no duplicate order

### Story 5: Agreement with checking, in both directions

**As** James
**I want** the list and the checker proved to say the same thing
**So that** a player can never pick a move the adjudicator calls illegal, and never be denied one it would accept

**Acceptance criteria:**

- [ ] **AC-5.1** Given each sampled position, and each unit in it When it is listed Then every order in the list passes `TA.check` (`legal: true`)
- [ ] **AC-5.2** Given each sampled position and each unit in it When every order of the unit's whole candidate space (see Definitions: not only the narrowed candidates) is checked Then every order that passes `TA.check` is in the list. Together with AC-5.1 the list equals the set of passing orders. Besides the positions of AC-5.3, this runs on six random boards built from fixed seeds (5 to 34 units, with fleets in seas and on coasts, split coasts included), so a narrowing that is too tight can't hide in positions picked by hand. At least one board has 34 units with several fleets at sea, so the chain parts of N1 and N4 are exercised beyond the stress position; the plan names the seeds and the builder, and that board is the mid-game board of "Performance target"
- [ ] **AC-5.3** Given the sampled positions Then they include at least:
  - the starting position (22 units);
  - two positions that between them put a fleet on each of the six split coasts, each with neighboring units (a position holds at most one unit per province): fleets on `bul/ec`, `spa/nc` and `stp/nc` in one, and on `bul/sc`, `spa/sc` and `stp/sc` in the other;
  - `ln`, the contract's convoy-chain position, and a position with a two-fleet chain and a fleet that a shorter chain bypasses;
  - the stress position defined under "Performance target";
  - a retreat-phase position and an adjustment-phase position, where both sides of the agreement are empty (`TA.check` gives `:wrong_phase` for every order)
- [ ] **AC-5.4** Given a unit that is not on the board Then its list is `[]` (AC-2.2). The agreement promise is for a unit that is on the board: `TA.check` judges an order by the unit the position holds in the province, so it may accept orders for a unit that differs from the argument, and Story 5 therefore samples only units the position holds
- [ ] **AC-5.5** (review) Given the agreement spec's running time Then it is stated in the pull request. If the spec takes more than about 10 seconds it is tagged `:slow` and CI runs it, as `rspec` with no filter does; none of the specs is excluded from CI. The candidate space costs about 1 s per 22 units, so the sampled positions and the six random boards may take about 10 s together; the plan measures it and tags the spec `:slow` if it is clearly over

### Story 6: Fast enough for every page

**As an** app developer
**I want** to list every unit's orders on each page load
**So that** the picker never waits

**Acceptance criteria:**

- [ ] **AC-6.1** Given the starting position When `TA.legal_orders` is called for each of its 22 units Then the total time is under 1,000 ms (target: under 100 ms), measured with `Process.clock_gettime(Process::CLOCK_MONOTONIC)`, after one warm-up call that is not timed
- [ ] **AC-6.2** Given the stress position (39 units) When every unit is listed Then the total time is under 5,000 ms
- [ ] **AC-6.3** Given the starting position When, in the same example, the 22 units are listed by approach A (every candidate of the whole candidate space through `TA.check`) and by `TA.legal_orders` Then A takes at least 10 times as long, and both give the same set of orders (A's result sorted into list order first)
- [ ] **AC-6.4** (review) Given the generator Then it reuses `Reach` for adjacency and chains and asks `Check.reason_for` about every order it lists; the only conditions it applies itself are N1 to N4, and it drops a candidate by no other test. If a helper of #11 needs a small change to be reusable it is made in this pull request and #11's specs pass unchanged. The implementation review reads the diff for any other test
- [ ] **AC-6.5** (review) Given the pull request description Then it records the measured times of every row of the table in "Performance target" and of approach A, from the machine the author used, and says which numbers are targets and which are bounds

### Story 7: The examples and the record

**As** James
**I want** every example in the interface to run, and the change recorded
**So that** the document stays true

**Acceptance criteria:**

- [ ] **AC-7.1** Given every Ruby example under `## Legal orders` of `docs/interface.md` (the three `first(3)`, hold and `[]` calls; the Vienna support; the Spain coasts; the `ln` calls and `retreat`), built as the document builds it When the specs run Then each is a passing example
- [ ] **AC-7.2** (review) Given `interface_examples_spec.rb` Then its header comment no longer lists `TA.legal_orders` as excluded, and says where the examples run now
- [ ] **AC-7.3** (review) Given `adjudicator/CHANGELOG.md` Then "Unreleased → Added" has an entry for `TA.legal_orders`, citing #12, and the #11 entry's remark that the helpers are for #12 stays true
- [ ] **AC-7.4** (review) Given the pull request Then `git diff --name-only main...HEAD` lists only paths under `adjudicator/`, and `docs/interface.md` is unchanged
- [ ] **AC-7.5** Given the gem is loaded Then `TA::LegalOrders` raises `NameError` (the generator is `private_constant`), and `TA.singleton_methods(false)` and `TA.constants` equal these exact lists, compared without regard to order: `singleton_methods(false)` is `[:check, :legal_orders]` and `constants` is `[:CheckResult, :DislodgedUnit, :InvalidInput, :Location, :Map, :Order, :Position, :Unit, :VERSION]` (these are the lists today, plus `:legal_orders`)

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
- Decide legality itself: `Check.reason_for` decides every listed order. The generator may only drop candidates by N1 to N4.
- Add a public class, constant or method besides `TA.legal_orders`.

### FR-2: The generator (internal)

A module named `LegalOrders`, private to the gem (`private_constant`), in `lib/trucebearer/adjudicator/legal_orders.rb`, required after `check`. It builds, for a unit, a candidate list of every order that could be legal (never fewer than the legal orders), in the contract's list order, and keeps the candidates that `Check.reason_for` accepts.

**Must:**
- Take its candidates from `Reach`'s tables and from the units in the position, so the map data stays the only place adjacency is written.
- Drop candidates only by N1 to N4, so that the candidate list is a superset of the legal orders for every position; the agreement spec proves it for the sampled positions and the random boards.
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

See "Performance target": 22 starting units under 100 ms, a 34-unit mid-game board under 250 ms, the 39-unit stress position under 1 s; spec bounds 1 s and 5 s, and a relative guard against filtering every candidate. The measurements will be repeated for the pull request.

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
2. **Approach B over A and C** (see "How the list is generated"). If the maintainer prefers A's simplicity and accepts about a second per page, it is a small change to the generator, and every other criterion stays except AC-6.3 and the targets.
3. **Agreement spec untagged.** About 1 s per 22 units over the whole candidate space, roughly 10 s for all samples and the six random boards, so it runs with the ordinary suite and in CI (which runs `bundle exec rspec` with no filter). It is tagged `:slow` only if it grows past about 10 s, and the tag excludes nothing from CI.
4. **No contradiction found** between the list-order rules, the "When each order type is legal" section and `check`. The contract's `ln` example (`yor` the only destination reachable both by land and by convoy) agrees with `check`, and prototype runs of both approaches gave identical lists on the starting and stress positions and, in the review, on 40 random boards.

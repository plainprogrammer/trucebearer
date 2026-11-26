# Feature 011: Check a single movement order against a position

**Status:** Draft
**Version:** 1.1.0
**Created:** 2026-11-25
**Last Updated:** 2026-11-25
**Issue:** #11
**Branch:** `adjudicator/11-check-order`

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 1.0.0 | 2026-11-25 | Initial draft |
| 1.1.0 | 2026-11-25 | Folded in the first independent review (round 1, changes required, three blocking):<br>• AC-3.8 names all three Move pairs that never fail together, and the seven that can.<br>• The "cases left to #14" table no longer claims 6.C to 6.H hold no legality: the cases that do are listed, with the reasons checking gives.<br>• Every order of an encoded case carries a `check:`, and an order the table doesn't name is legal (6.D.31's move included).<br>• Fixture format lists its keys and says where `phase` goes.<br>• AC-7.1 and AC-7.3 name their mechanism; AC-5.7, AC-3.9 and AC-6.4 are made concrete.<br>• Review-only criteria are marked, FR-3 has a criterion, and `Marshal` is stated once.<br>• AC-9.4 records only the 4.E.1 consequences |

## Problem Statement

`docs/interface.md` (merged in #5) promises `TA.check(position, order)`: it takes one movement order and a position, and says whether the order is legal and, if not, why. The app calls it as each order is entered, and the legal-order listing (#12) and the adjudicator (#14, where an illegal order is void) must agree with it. Its answer is a `TA::CheckResult`, a value object that #10 deliberately left out. Nothing implements either yet. This feature builds `TA::CheckResult` and `TA.check` exactly as the contract describes them, and proves them against the DATC cases about legality.

## Goals

- `TA::CheckResult` exists as an immutable `Data` class with the fields, hash form (with `format`) and impossible objects that `docs/interface.md` gives.
- `TA.check(position, order)` returns a `TA::CheckResult` for every well formed position and order, applying the conditions and the precedence of `docs/interface.md` `## Checking an order` exactly:
  - ownership and phase;
  - adjacency for each unit type, and coasts;
  - supports a unit could really give;
  - convoys, and convoy moves, a fleet and an army could really make.
- Every reason in the table of `docs/interface.md` is returned by at least one spec, and the precedence within each order type is pinned by specs.
- The DATC cases about legality (6.A, 6.B, and three cases from 6.D and 6.G that the contract cites) are written as hand-made fixtures in `spec/datc/`, named by section number, and pass.
- The fixture format can take expected adjudication results later (#14) without being redesigned.
- Every Ruby example under `### TA::CheckResult` and under `## Checking an order` in `docs/interface.md`, and the three `CheckResult` lines at the end of "Impossible objects", run as a passing spec.
- The helpers that #12 will need ("can reach", "convoy chain") exist as internal code, named so #12 can reuse them.

## Non-Goals

- **`TA.legal_orders` (#12).** Listing legal orders is not built here. Only the helpers it will share are, and they stay internal.
- **Adjudication (#14, #15).** Nothing here decides who moves, bounces or is dislodged. A DATC case that is about what happens on adjudication is not encoded here, apart from the legality of its orders (see "DATC fixtures").
- **Any change to `docs/interface.md`.** This feature implements the contract as it stands. If building it shows that the contract is wrong or contradicts itself, for example a reason that can't be reached in its precedence order, work stops and goes to the coordinator, because changing the contract is an interface change with its own rules in `adjudicator/AGENTS.md`. None was found while writing this spec (see Open Questions 1).
- **Retreat and adjustment orders.** They have no order classes yet (0.3). A position in those phases is answered with `:wrong_phase`.
- **Its own design of `Marshal` handling.** #77 adds it for the value objects. If #77 has merged when this pull request is ready, `CheckResult` gets the same handling and a spec that mirrors #77's own, and nothing more (Open Question 3).
- A map other than the classic one.
- Reporting more than one reason. `reasons` stays a list for a later version, but holds at most one now.

## Users and Context

**Primary users:** the app, which calls `TA.check` as each player picks an order and shows or hides it by the result; and agents building #12 (legal orders, which must give exactly the orders that pass checking) and #14 (adjudication, which voids any order that fails checking).

**Secondary users:** James, who reads the examples in `docs/interface.md` and expects them to be true, and the DATC section numbers in the fixtures to be right.

**Usage context:** checking is called often, one order at a time, with a position the app has already built (so it is well formed) and an order the app has built from a player's choice (also well formed). Checking looks only at the position and the order. It never looks at any other order. A player can therefore support or convoy a unit of another power.

**User mental model:** the board and the rulebook. "Can this unit go there?", "is there a unit to support?", "is there a chain of fleets at sea?".

## Definitions

These are the terms of `docs/interface.md` `### Terms used in checking`, repeated here because the criteria rely on them.

- **Can reach:** a unit can reach a province when the map's adjacency for its unit type joins the unit's current location to some location of that province. For a fleet the step starts from the coast the fleet is on, and it is enough to reach any one coast of the province.
- **Convoy chain:** a sequence of different sea provinces, each holding a fleet of any power, that links two different coastal provinces: the first borders the origin, each borders the next, and the last borders the destination. Coasts at the two ends don't matter.
- **Minimal convoy chain:** a convoy chain that stops being a chain between the same two provinces if any one or more of its fleets are taken out.
- **Supporter's province:** the province named by the `at` of a support order.
- **The position alone decides:** a result depends on the position and the order only.

## DATC fixtures

Fixtures are hand-written data in `spec/datc/`, named by section number, one file per case, in the format below. They are written in our own words from each case's position and legality outcome. Nothing is copied from the DATC.

### Format

One YAML file per case, `spec/datc/<section>.yml` (for example `6.B.4.yml`). Positions and orders use the hash forms of `docs/interface.md`, in a short notation the loader expands: a location is `"spa/nc"` or `"par"`, and the loader adds `"format"`, the classic map, spring 1901, the movement phase and empty ownership, standoffs and dislodged units (a case may set `phase` to override it).

```yaml
case: "6.B.4"                      # the DATC section number; must equal the file name
summary: A fleet may support a move to a coast it cannot reach itself   # our own words
position:
  units:
    - {power: france, type: fleet, at: gas}
    - {power: france, type: fleet, at: mar}
    - {power: italy,  type: fleet, at: wes}
orders:
  - order: {type: move, power: france, at: gas, destination: "spa/nc"}
    check: {legal: true}
  - order: {type: support_move, power: france, at: mar, from: gas, to: spa}
    check: {legal: true}
  - order: {type: move, power: italy, at: wes, destination: "spa/sc"}
    check: {legal: true}
```

An order that is not legal says why, and a departure from the DATC's preferred result is marked:

```yaml
case: "6.B.2"
summary: A fleet that can reach only one coast must still name it
departure: true                    # follows ruleset.md, not the DATC's preferred result
position:
  units:
    - {power: france, type: fleet, at: gas}
orders:
  - order: {type: move, power: france, at: gas, destination: spa}
    check: {legal: false, reason: coast_required}
```

**Keys.** The loader accepts these and no others (AC-8.6):
- top level: `case`, `summary`, `departure` (optional), `position`, `orders`, and `after`, which is reserved for #14 and ignored here;
- `position`: `units`, and `phase` (optional, `movement` unless given, for a case in another phase);
- a unit: `power`, `type`, `at`, where `at` is a location (`"spa/nc"`) because a unit may stand on a coast;
- an order entry: `order`, `check` and `result` (reserved for #14, ignored here). The order's own keys are those of its hash form, where `at`, `from`, `to` and `target` are provinces and `destination` is a location;
- `check`: `legal` and `reason` (omitted when legal).

**Room for #14.** `check:` is the only key this feature reads, so #14 adds its expected results beside it without touching ours: a `result:` next to each `check:` (the outcome symbol), and a top-level `after:` for the next position. Orders written only for #14 (such as a case's implied holds) can be added to the same `orders:` list with no `check:`; the checking runner skips an entry that has none. A case this feature leaves to #14 becomes a new file in the same format. Nothing in the format has to change.

### Cases encoded

Each is encoded for what checking decides: which orders are legal and, if not, which reason. Where the DATC says an order is "illegal", "invalid" or similar, the fixture says which reason `docs/interface.md` gives.

**Every order of an encoded case carries a `check:`.** An order that the table below doesn't name expects `legal: true`. So in 6.D.31 the army's move from Rumania to Armenia is legal (the contract finds a chain through the Black Sea; the DATC's word "invalid" there is about the move being matched, not about its legality), and in 6.G.19 both army moves are legal.

| Case | What checking decides | Expected |
|---|---|---|
| 6.A.1 | Fleet move to a province it doesn't touch | `not_reachable` |
| 6.A.2 | Army move to sea | `not_reachable` |
| 6.A.3 | Fleet move to an inland province | `not_reachable` |
| 6.A.4 | Move to the unit's own province | `own_province` |
| 6.A.5 | Move to own province, with a convoy order and a support for it | move `own_province`; convoy `bad_endpoints`; support `same_province`; the other orders legal |
| 6.A.6 | Ordering another power's unit | `foreign_unit` |
| 6.A.7 | Fleet move that only a convoy could make, and a convoy of a fleet | move `not_reachable`; convoy `no_unit` |
| 6.A.8 | Support to hold oneself | `own_province`; the other orders legal |
| 6.A.9 | Fleet move between provinces that touch for armies only | `not_reachable` |
| 6.A.10 | Support for a move to a province the supporter can't reach | `not_reachable` |
| 6.B.1 | Fleet move to a split-coast province, no coast, both coasts reachable | `coast_required` |
| 6.B.2 | The same, with one coast reachable (a departure, see `ruleset.md`) | `coast_required` |
| 6.B.3 | Fleet move naming a coast it can't reach, the other being reachable | `coast_unreachable` |
| 6.B.4 | Support for a move to a coast the supporter can't reach | legal |
| 6.B.5 | Support from a coast that can't reach the destination | `not_reachable` |
| 6.B.6 | Supports and moves around Spain | all legal |
| 6.B.7 | Supports for moves to Spain, own and other coast | all legal |
| 6.B.8 | The same with only one coast reachable | all legal |
| 6.B.10 | Move ordered for a fleet on a coast (encoded without the unit's coast) | legal |
| 6.B.11 | The same from the coast that can't reach the target | `not_reachable` |
| 6.B.12 | Army move naming a coast (a departure, see `ruleset.md`) | `coast_not_allowed` |
| 6.B.13 | The two fleets of the "coastal crawl" | both moves legal |
| 6.B.15 | Support, by one power, for another power's move to Spain | legal |
| 6.B.16 | Support to hold a fleet standing on a coast | legal |
| 6.B.17 | Support for a move out of a split-coast province | legal |
| 6.B.18 | Army move and convoy starting from a split-coast province | both legal |
| 6.B.19 | Army move and convoy ending at a split-coast province | both legal |
| 6.D.31 | Support that would need a convoy through the supporter's own province | `move_impossible` |
| 6.D.34 | Support for a move into the supporter's own province | `own_province` |
| 6.G.19 | Convoy by a fleet that no minimal chain needs | `not_on_chain`; the fleet on the needed chain is legal |

6.D.31, 6.D.34 and 6.G.19 are outside the 6.A and 6.B range of the Issue. They are added because `docs/interface.md` cites each of them as the source of a checking condition, so each is a fixture and not only a unit spec (Open Question 2).

### Cases left out

| Case | Why |
|---|---|
| 6.A.11 | Two armies bounce. Every order is plainly legal, so checking has nothing to decide; it is a result for #14 |
| 6.A.12 | Three armies bounce. As 6.A.11 |
| 6.B.9 | Can't be expressed: a support carries no coast (a departure in `ruleset.md`). Nothing to encode |
| 6.B.14 | A build. It is not a movement order, and adjustments arrive in 0.3 (#37) |

### Cases outside the Issue's range that also hold legality

Some cases in 6.D to 6.G are mostly about adjudication but contain orders the DATC calls illegal, which checking decides. They are outside the range the Issue names, so only the three that the contract cites (above) are encoded here. The others are added later as files in the same format, by #12 or #14, each with a `check:` per order. The reasons checking gives for them, traced from the contract, are:

| Case | Reasons for its illegal orders |
|---|---|
| 6.D.22 to 6.D.24 | the move: `not_reachable`; the support for it: `move_impossible` |
| 6.D.28 | `not_reachable` |
| 6.D.29 | `coast_unreachable` |
| 6.D.30 | `coast_required` |
| 6.D.32 | an army move with no chain: `not_reachable` |
| 6.E.14 | `not_reachable` |
| 6.F.1 | the move: `not_reachable`; the coastal fleet's convoy: `not_fleet_at_sea`; the two sea fleets' convoys: `not_on_chain` |
| 6.F.12 and 6.G.7 | the unneeded fleet's convoy: `not_on_chain` |

Every other case in 6.C to 6.G holds no order the DATC marks illegal, and is left to #14 and later. 6.H is the retreat section, and arrives with retreats in 0.3. Encoding the cases above now instead is a one-line decision for the maintainer at Gate A (Open Question 2).

## User Stories

Every acceptance criterion is verified by a passing spec in this pull request, except those marked (review), which the implementation review and the pull request check. In the criteria, "a valid position" and "a valid order" mean built with `new` or `from_h` without raising.

**Error messages.** Where a criterion says the message includes the offending value or key, it means the value or key in `inspect` form, as in #9 and #10.

### Story 1: Describe the answer to a check

**As an** app developer
**I want** the answer to a check as a value object I can save and rebuild
**So that** the app can store what a player was told, and replay it

**Acceptance criteria:**

- [ ] **AC-1.1** Given `legal` and `reasons` When `TA::CheckResult.new(legal:, reasons:)` is called with `legal: true` and `[]`, or with `legal: false` and one reason Then it returns a frozen object with those two fields and a frozen `reasons`, two results with the same contents are equal and have the same `hash`, and the caller's own `reasons` array is neither frozen nor changed
- [ ] **AC-1.2** Given the two `CheckResult` examples under `### TA::CheckResult` When `to_h` is called Then it gives exactly `{"format" => 1, "legal" => false, "reasons" => ["foreign_unit"]}` and `{"format" => 1, "legal" => true, "reasons" => []}`, with its keys in that order
- [ ] **AC-1.3** Given a legal result, and an illegal result for each of the 17 reasons in the table of `docs/interface.md` When it is converted with `to_h`, written with `JSON.generate`, read with `JSON.parse` and passed to `TA::CheckResult.from_h` Then the result equals the original
- [ ] **AC-1.4** Given the three impossible examples at the end of "Impossible objects" (`legal: true` with a reason, `legal: false` with none, `legal: false` with two reasons) When each is built with `new`, and when each is written as a hash and passed to `from_h` Then each raises `TA::InvalidInput`
- [ ] **AC-1.5** Given a `legal` that is not `true` or `false` (`nil`, `"true"`, `1`), a `reasons` that is not an `Array`, a reason that is a string (`"own_province"`), not a symbol, or a symbol that is not one of the 17 (`:bogus`) When `TA::CheckResult.new` is called with it Then it raises `TA::InvalidInput`, and the message includes the offending value
- [ ] **AC-1.6** Given a hash with a missing key, an unknown key, symbol keys, a missing or unknown `"format"` (including `2` and `1.0`), a `"legal"` that is not a boolean, a `"reasons"` that is not an array, a reason that is a symbol or an unknown string, or an argument that is not a hash When it is passed to `TA::CheckResult.from_h` Then it raises `TA::InvalidInput`, and the message includes the offending key or value
- [ ] **AC-1.7** Given any hash handed to `CheckResult.from_h`, whether accepted or refused When the call returns or raises Then the hash handed in is unchanged, a frozen hash is accepted, and changing the hash afterwards leaves the result unchanged
- [ ] **AC-1.8** Given `TA::CheckResult.new` called with a missing or an unknown keyword When it is called Then it raises Ruby's `ArgumentError`, as the other value objects do (the decision of #10)

### Story 2: Check what every order needs

**As an** app developer
**I want** an order refused at once when it can't be given at all
**So that** a player never sees an order for a unit they don't have

**Acceptance criteria:**

- [ ] **AC-2.1** Given the starting position When France's hold for London is checked, and England's hold for London Then the first gives `legal: false` with `[:foreign_unit]` and the second `legal: true` with `[]`. This is the first spec written
- [ ] **AC-2.2** Given a position in the retreat phase and in the adjustment phase, and any order for any province Then the result is `legal: false` with `[:wrong_phase]` and nothing else, even when the order also has no unit or the wrong power
- [ ] **AC-2.3** Given a movement position and an order whose `at` province holds no unit Then the result is `[:no_such_unit]`, even when the order would also fail a later condition
- [ ] **AC-2.4** Given a movement position and an order whose `at` unit belongs to another power Then the result is `[:foreign_unit]`, even when the order would also fail a later condition, for each of the six order types
- [ ] **AC-2.5** Given a legal order Then the result is `legal: true` with `[]`, and a hold is legal for every unit in a movement position
- [ ] **AC-2.6** Given any position and any order Then checking leaves both unchanged and gives equal results when called twice, and the result depends on nothing else: a support for a unit of another power is checked the same as one for a unit of the supporter's own power
- [ ] **AC-2.7** Given an argument that is not a `TA::Position`, or an order that is not one of the six order classes (`nil`, a hash form, a `Symbol`, a `TA::Unit`) When `TA.check` is called Then it raises `TA::InvalidInput`, and the message includes the offending argument

### Story 3: Check a move

**As an** app developer
**I want** a move judged by what the unit can reach and the coast it names
**So that** only moves a unit could make are offered

**Acceptance criteria:**

- [ ] **AC-3.1** Given the interface examples for moves (Russia's army in Sevastopol to Rumania, England's fleet in London to Belgium, France's army in Marseilles to Spain naming the north coast) Then they give `legal: true`, `[:not_reachable]` and `[:coast_not_allowed]` as the document shows
- [ ] **AC-3.2** Given an army, a fleet at sea, a fleet on a coast, and a fleet moving to a province with no split coast, each moving to a province it can reach Then the move is legal. A fleet that names a coast it can reach is legal, and an army with a convoy chain to a coastal province it can't reach by land is legal, for a chain of one fleet and of two, and with a fleet of another power in the chain
- [ ] **AC-3.3** Given a move whose destination is the unit's own province, for an army, a fleet, and a fleet that names the other coast of its own split-coast province Then the result is `[:own_province]`
- [ ] **AC-3.4** Given an army moving to a sea province or to a province it doesn't touch with no chain, a fleet moving to an inland province or to one it doesn't touch, a fleet that could only get there by a convoy chain, and a fleet on one coast of a split-coast province moving to a province only the other coast touches Then the result is `[:not_reachable]`
- [ ] **AC-3.5** Given an army whose move names a coast, whether it reaches by land or by a chain Then the result is `[:coast_not_allowed]`
- [ ] **AC-3.6** Given a fleet moving to a split-coast province without a coast, whether it can reach one coast or both Then the result is `[:coast_required]`
- [ ] **AC-3.7** Given a fleet moving to a split-coast province and naming a coast it can't reach, while it can reach the other Then the result is `[:coast_unreachable]`, and the coast is never changed for the caller
- [ ] **AC-3.8** Given a move that fails two conditions Then the earlier in the order `:own_province`, `:not_reachable`, `:coast_not_allowed`, `:coast_required`, `:coast_unreachable` is reported. Seven pairs can fail together, and a spec pins each: `:own_province` with each of the other four, and `:not_reachable` with each of the three coast reasons. Three never can, because `:coast_not_allowed` is for armies and the other two for fleets, and `:coast_required` needs the coast missing where `:coast_unreachable` needs it named: `:coast_not_allowed` with `:coast_required`, `:coast_not_allowed` with `:coast_unreachable`, and `:coast_required` with `:coast_unreachable`. A spec says so
- [ ] **AC-3.9** Given a province that touches the unit's province for an army but not for a fleet (Rome to Venice), and one that touches it for a fleet but not for an army (London to the North Sea) Then each unit type is judged by its own adjacency

### Story 4: Check a move by convoy

**As an** app developer
**I want** the tag "by convoy" accepted only where it means something
**So that** it can only pick the sea route to a neighboring province

**Acceptance criteria:**

- [ ] **AC-4.1** Given the interface example for England's army in Liverpool moving to Wales via convoy with no fleet at sea Then the result is `[:no_convoy_route]`
- [ ] **AC-4.2** Given an army that could also get there by land and a convoy chain between its province and the destination (England's army in London to Yorkshire, with a fleet in the North Sea) Then the order is legal
- [ ] **AC-4.3** Given a fleet Then the result is `[:not_army]`, even for a destination it could reach. Given an army and its own province Then `[:own_province]`. Given an army and a province it can't reach by land (even with a chain to it) Then `[:not_adjacent]`. Given an army, a neighboring destination and no chain Then `[:no_convoy_route]`
- [ ] **AC-4.4** Given an order that fails two conditions Then the earlier in the order `:not_army`, `:own_province`, `:not_adjacent`, `:no_convoy_route` is reported. The specs pin each pair

### Story 5: Check a support

**As an** app developer
**I want** a support offered only when the supporter could really give it
**So that** a player can't order a support that could never matter

**Acceptance criteria:**

- [ ] **AC-5.1** Given the interface examples for supports (Germany's Munich supporting Berlin, and the same naming Silesia, which is empty; Austria's Vienna supporting Russia's Warsaw to Galicia) Then they give `legal: true`, `[:no_unit]` and `legal: true` as the document shows
- [ ] **AC-5.2** Given a support to hold for a province the supporter can reach and a unit stands in, whoever owns it Then it is legal. Given its own province Then `[:own_province]`. Given an empty province Then `[:no_unit]`. Given a province it can't reach Then `[:not_reachable]`
- [ ] **AC-5.3** Given a support to move When the origin or the destination is the supporter's own province Then `[:own_province]`. Given an origin equal to the destination Then `[:same_province]`. Given an empty origin Then `[:no_unit]`. Given a destination the supporter can't reach Then `[:not_reachable]`. A fleet supporter that stands on a split coast judges reach from that coast
- [ ] **AC-5.4** Given a support to move for a unit that couldn't make the move itself as a plain move, to any coast of the destination (an army that doesn't touch the destination and has no chain, a fleet that can't reach it) Then `[:move_impossible]`. Given a unit that could, to a coast the supporter can't reach itself, Then the order is legal, and the supported fleet's coast plays no part
- [ ] **AC-5.5** Given a supported army that can reach the destination only by a convoy chain Then the order is legal when the chain doesn't need the supporter's province, and `[:move_impossible]` when it does, because the chain is judged without the supporter's fleet (DATC 6.D.31)
- [ ] **AC-5.6** Given a support order, whatever the other powers' units, Then supporting a foreign unit is legal, and a support never names a coast (there is no field for one)
- [ ] **AC-5.7** Given orders that fail two conditions Then the earlier in the order of the table is reported. For a support to hold, `:own_province` and `:no_unit` never fail together (the supporter stands in its own province), and the other two pairs are pinned. For a support to move, every pair that can fail together is pinned: `:own_province` with `:no_unit` only for a destination that is the supporter's province and an empty origin, and `:no_unit` with `:move_impossible` never, because an empty origin has no unit to judge (any `:no_unit` case covers it)

### Story 6: Check a convoy

**As an** app developer
**I want** a convoy offered only to a fleet that really carries an army
**So that** a player can't order a convoy that no route needs

**Acceptance criteria:**

- [ ] **AC-6.1** Given the interface example for England's fleet in London convoying Liverpool to Belgium Then the result is `[:not_fleet_at_sea]`
- [ ] **AC-6.2** Given a fleet in a sea province, an army in the origin, two different coastal provinces, and the fleet part of a minimal convoy chain between them Then the order is legal, whoever owns the army and the other fleets in the chain
- [ ] **AC-6.3** Given an army, or a fleet that is not in a sea province, ordered to convoy Then `[:not_fleet_at_sea]`. Given an origin equal to the destination, or an origin or destination that is not coastal (sea or inland) Then `[:bad_endpoints]`. Given an origin with no army (empty, or holding a fleet) Then `[:no_unit]`
- [ ] **AC-6.4** Given a fleet that is in no minimal convoy chain between the origin and the destination Then `[:not_on_chain]`. The specs show three positions: a sea fleet that touches a chain fleet but neither endpoint, so no chain through it reaches the origin (the shape of 6.F.12); two fleets that form the only chain, where each is legal; and a fleet that a one-fleet chain bypasses (DATC 6.G.19), which is refused while the fleet on the short chain is legal
- [ ] **AC-6.5** Given a convoy whose endpoints are on a split-coast province Then the coast plays no part (DATC 6.B.18, 6.B.19)
- [ ] **AC-6.6** Given a convoy that fails two conditions Then the earlier in the order `:not_fleet_at_sea`, `:bad_endpoints`, `:no_unit`, `:not_on_chain` is reported. The specs pin each pair

### Story 7: Every reason is reachable and ordered

**As** James
**I want** the table in `docs/interface.md` to be the table the code follows
**So that** the contract and the code can't drift apart

**Acceptance criteria:**

- [ ] **AC-7.1** Given the 17 reason symbols in the table of `docs/interface.md` `### Rejection reasons`, read from the document itself When the specs run Then the set is equal to the set `TA::CheckResult` accepts, and a single table in the specs, with one position and one order for each reason, gives each of the 17 when checked. The table's reasons are asserted equal to the 17 read from the document, so a reason added to the document and not to the specs fails
- [ ] **AC-7.2** Given every unit in the starting position, and in a position that adds fleets at sea and units on every split coast, and every order that can be built from them (each order type, every province and coast, own and foreign power) When each is checked Then none raises, every result is a `TA::CheckResult` whose `legal` and `reasons` agree, and for every order that is `legal: false` exactly one reason is given
- [ ] **AC-7.3** Given the order of the reasons in each row of the table of `docs/interface.md` When the specs run Then the pair specs of AC-3.8, AC-4.4, AC-5.7 and AC-6.6 take their reason order from the rows read from the document, so a row reordered in the document and not in the code fails

### Story 8: The DATC fixtures pass

**As** James
**I want** the cases that concern legality to be fixtures named by section number
**So that** I can trace each rule to the DATC and #14 can build on the same files

**Acceptance criteria:**

- [ ] **AC-8.1** Given a file `spec/datc/<section>.yml` for each case in "Cases encoded" When the specs run Then each file builds a valid position and valid orders, runs `TA.check` on each order that has a `check:`, and every result equals the expected `legal` and `reason` (no `reason` meaning `reasons` is `[]`)
- [ ] **AC-8.2** Given the directory `spec/datc/` When the specs run Then the set of `*.yml` files is exactly the list of cases kept in the runner, which starts as "Cases encoded": none missing, none extra, none for a case in "Cases left out", and each file's `case:` equals its file name. #14 adds its cases to that list, which is the one edit the runner needs
- [ ] **AC-8.3** (review) Given the fixtures Then none carries text copied from the DATC: each `summary` is our own wording, and the one reference copy of the DATC is read only
- [ ] **AC-8.4** Given a fixture marked `departure: true` Then it is one of 6.B.2 and 6.B.12, the two checking departures named in `docs/ruleset.md`, and the specs check that no other fixture is marked
- [ ] **AC-8.5** Given a fixture with a `result:` or an `after:` key, or an order with no `check:` Then the checking runner ignores them, so #14 can add them without editing the loader. They are the two keys the "Keys" list reserves for #14. A spec shows this with an in-memory case
- [ ] **AC-8.6** Given a malformed fixture (an unknown key, an unknown reason, a case id that doesn't match its file) Then the loader raises a clear error naming the file. A spec shows each, including a key that is neither ours nor reserved for #14

### Story 9: The examples and the record

**As** James
**I want** every example in the interface to run, and the change recorded
**So that** the document stays true

**Acceptance criteria:**

- [ ] **AC-9.1** Given every Ruby example under `### TA::CheckResult` and under `## Checking an order` (every `TA.check` call with its result), and the three `CheckResult` lines at the end of "Impossible objects" When the specs run Then each is a passing example, built as the document builds it
- [ ] **AC-9.2** (review) Given `interface_examples_spec.rb` Then its header comment no longer lists the `CheckResult` examples as excluded and says where they run now
- [ ] **AC-9.3** (review) Given `adjudicator/CHANGELOG.md` Then "Unreleased → Added" has an entry for `TA::CheckResult` and `TA.check`, citing #11, and the #10 entry no longer says `TA::CheckResult` arrives with #11 as a future item (it has arrived)
- [ ] **AC-9.4** (review) Given `docs/ruleset.md` Then, beside its 4.E.1 row, it records in our own words and citing the section the two choices that the contract takes from that row and the table doesn't yet hold: 6.D.31 (a support is illegal when the move it supports needs a chain through the supporter's province) and 6.G.19 (a convoy order is illegal for a fleet that no minimal chain needs). Nothing already recorded is restated, and the own-province cases (6.A.4, 6.A.5, 6.A.8, 6.D.34) are not open choices, so they get no row
- [ ] **AC-9.5** (review) Given the pull request Then `git diff --name-only main...HEAD` lists only paths under `adjudicator/`, and `docs/interface.md` is unchanged
- [ ] **AC-9.6** Given the internal helpers of FR-3 When they are referenced from outside the gem's module Then none is reachable (a private constant raises `NameError`, a private method `NoMethodError`, as the plan chooses), and `docs/interface.md` doesn't name them

## Functional Requirements

### FR-1: `TA::CheckResult`

A `Data` class in `Trucebearer::Adjudicator`, with two fields, `legal` and `reasons`, in that order. It is a storable object, so its hash form carries `format`.

**Must:**
- `legal` is `true` or `false`. `reasons` is an `Array` of the 17 reason symbols, frozen.
- `legal: true` goes with `[]`. `legal: false` goes with exactly one reason.
- `new` takes symbols. `from_h` takes strings and nothing else, with exactly the keys `format`, `legal` and `reasons`, and a `format` of the gem's one value (reuse the shared helper).
- `to_h` gives string keys, with `"format"` first, `reasons` as strings.
- Copy `reasons`, so the caller's array is never frozen or changed.
- Require both keywords, with Ruby's `ArgumentError` for a missing or unknown one.
- Raise `TA::InvalidInput` for a wrong type, an unknown reason, and a `legal` and `reasons` that disagree.

**Must not:**
- Carry anything but the three keys in its hash form.
- Decide anything about the rules (it is only a value).

### FR-2: `TA.check`

A module function of `Trucebearer::Adjudicator`, `TA.check(position, order)`. It returns a `TA::CheckResult`.

**Must:**
- Raise `TA::InvalidInput` for a position that is not a `TA::Position`, or an order that is not one of the six order classes. Nothing else raises, for any position and order that were built without raising.
- Apply the conditions in the order of the table, per order type, as `docs/interface.md` gives them. A condition shared by several order types gives the same symbol in each. The first condition that fails gives the one reason.
- Judge by the position and the order alone.
- Treat the position's `units` as the units on the board.
- Judge a fleet's reach from the coast it is on, and an army's with no coast. Judge a convoy chain over the fleets in sea provinces, of any power, with the origin and destination coasts ignored.
- Judge the support to move's "could make the move itself" with convoy chains computed without the supporter's province.
- Judge the convoy order's "part of a minimal convoy chain" as defined above.

**Must not:**
- Look at any other order, or at who owns a province's supply center.
- Raise or return anything but a `TA::CheckResult` for a broken rule.
- Offer a second spelling of any order, or correct an order (a coast is never supplied or changed).

### FR-3: Internal helpers for #12

**Must:**
- Provide, as internal code that is not in `docs/interface.md`, the questions the check asks and #12 will ask too: whether a unit can reach a province (and which of its coasts), whether a convoy chain exists between two provinces (optionally leaving out one province's fleet), and whether a fleet is on a minimal convoy chain between two provinces.
- Name and place them so #12 can reuse them (the plan chooses the names), and keep them private to the gem, like `Shape`.

**Must not:**
- Be part of the public interface, or build `TA.legal_orders`.

### FR-4: The record and packaging

**Must:**
- Add "Unreleased → Added" to `adjudicator/CHANGELOG.md` (AC-9.3), and update the #10 line that said `TA::CheckResult` was still to come.
- Add the `docs/ruleset.md` entries of AC-9.4.
- Update the header comment of `interface_examples_spec.rb` (AC-9.2).
- Require the new files from `lib/trucebearer/adjudicator.rb`.

**Must not:**
- Change `docs/interface.md`, or any file outside `adjudicator/`.
- Add a runtime dependency. Development uses `rspec` and `rake` only, and fixtures are read with Ruby's own `yaml` (already used by the map).

## Non-Functional Requirements

### Performance

- No promise in the contract. A check is a few lookups and, for convoys, a search over at most the 19 sea provinces. The sweep of AC-7.2 runs inside the ordinary suite without slowing it noticeably.

### Security

- Fixtures are read with `YAML.safe_load` with no permitted classes and no aliases, so a fixture can only be plain data.
- `TA.check` raises only `TA::InvalidInput`, never `NoMethodError` or `TypeError`, for a wrong argument.

### Reliability

- A result is immutable and checking is deterministic: the same position and order always give an equal result.
- `legal` and `reasons` can never disagree, because `CheckResult` refuses to be built that way.

## Error Scenarios

| Scenario | Expected Behavior |
|----------|-------------------|
| An order that breaks a rule of the game | A `TA::CheckResult` with `legal: false` and one reason. Never an exception |
| A position not in the movement phase | `[:wrong_phase]` |
| No unit in the order's `at` province | `[:no_such_unit]` |
| The unit belongs to another power | `[:foreign_unit]` |
| An order that fails several conditions | Only the first in the order of its table is reported |
| `TA.check` gets something that is not a position, or not an order | Raises `TA::InvalidInput`, and the message includes the argument |
| `CheckResult.new` with a `legal` and `reasons` that disagree, or a bad type | Raises `TA::InvalidInput` |
| `CheckResult.from_h` with a bad hash, key, `format` or value | Raises `TA::InvalidInput` |
| `CheckResult.new` without a keyword | Raises Ruby's `ArgumentError` |
| A fixture that doesn't match the format | The loader raises, and the spec fails with the file name |

## Open Questions

None blocking. These are decisions made in this spec, put to the maintainer at Gate A so approval settles them.

1. **Is the contract consistent?** While writing the spec, every reason of the table was traced against its precedence order and the conditions in "When each order type is legal". Every reason can be returned (the pairs that can never fail together are named in AC-3.8 and AC-5.7, and none is a reason that is unreachable), and all the interface examples were traced by hand and match. No defect was found, so `docs/interface.md` is unchanged. If the specs find one, work stops and goes to the coordinator.
2. **Fixtures outside 6.A and 6.B.** The Issue names 6.A and 6.B. This spec adds 6.D.31, 6.D.34 and 6.G.19, because the contract cites each as the source of a checking condition. Other cases in 6.D to 6.G also hold orders the DATC calls illegal (listed above, with the reasons the contract gives). **Recommendation: encode the three, and leave the rest to the issue that needs them.** Encoding the whole list now (6.D.22 to 6.D.24, 6.D.28 to 6.D.30, 6.D.32, 6.E.14, 6.F.1, 6.F.12, 6.G.7 would be 11 more small files) is the alternative, and would give `move_impossible` and `not_fleet_at_sea` a DATC source. Drop the three if you want the fixtures strictly to the Issue; the conditions are then covered by unit specs alone (AC-5.3, AC-5.5, AC-6.4).
3. **`Marshal` (#77).** #77 runs in parallel. If it merges before this pull request is done, `CheckResult` gets the same handling it adds. If this merges first, the #77 worker adds it. Nothing of its own is built here.
4. **`docs/ruleset.md` rows (AC-9.4).** The contract already states the choices, so the rows only record them under their DATC section, as `AGENTS.md` asks. Only 6.D.31 and 6.G.19 get rows, beside 4.E.1: they follow the DATC's own remarks about programs that offer only possible orders. The own-province cases are the DATC's preferred results and no choice is open.
5. **Fixture notation.** Locations are written `"spa/nc"` in the short notation, as in `data/maps/classic.yml`, and the loader expands them to the hash forms. This keeps hand-written fixtures readable and is the only departure from the hash forms.
6. **Dislodged units.** The position's `units` list is the board, and a dislodged unit isn't on it. A movement position can't hold dislodged units, so this only matters in a retreat position, which is `:wrong_phase` first.

## Out of Scope (Future Considerations)

- `TA.legal_orders` (#12).
- Adjudication and the DATC results of cases 6.A.11, 6.A.12 and 6.C to 6.H (#14, #15).
- Retreat and adjustment orders and their checks (0.3).
- Reporting several reasons at once.
- A second map.

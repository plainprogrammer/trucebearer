# Feature 005: Public interface for movement phases

**Status:** Approved
**Version:** 4.2.0
**Created:** 2026-11-25
**Last Updated:** 2026-11-25
**Issue:** #5
**Branch:** `adjudicator/5-movement-phase-interface`

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 1.0.0 | 2026-11-25 | Initial approved spec |
| 2.0.0 | 2026-11-25 | Rewritten after an independent review. Each order type now has one accepted form, including coast rules. Plain moves and moves via convoy are separated. A format version is on every storable object, including orders. Dislodged units record whether the attack came by convoy, and standoff provinces are recorded. Every outcome situation is defined, as are implied holds, duplicate orders, malformed positions, and legal orders outside a movement phase. The check result becomes a value object |
| 3.0.0 | 2026-11-25 | Rewritten after a second independent review, against DATC v3.4. Convoys now follow the DATC's preferred results:<br>• a plain move may go by convoy;<br>• "move via convoy" is a tag used only for adjacent destinations.<br>Also changed:<br>• support legality is added;<br>• each order field is typed as a province or a location, so a coast in a province field is an error, not a check reason;<br>• convoy legality uses minimal chains;<br>• rejection reasons have a precedence;<br>• outcome conditions have a precedence and cover every order type;<br>• the order of the outcome list and the dislodged flag are defined;<br>• the result reports whether a convoy paradox was found;<br>• season and phase values are listed, and `format` is one value for the whole gem;<br>• deliberate departures from the DATC are listed, and citations corrected |
| 4.0.0 | 2026-11-25 | Rewritten after a third independent review.<br>• AC-5.9 now excludes the paradox cases (pending #39), 6.B.14 and the retreat step of 6.F.7, and defines "matches" by results, not labels.<br>• Checking returns exactly one reason, the first by a documented precedence.<br>• Matching, moving and convoy paradox are defined, and the paradox flag is defined.<br>• Convoy routing never falls back to land, and needs a legal intent order.<br>• Outcome conditions may share a symbol only within one bullet.<br>• Value objects are validated against the classic map.<br>• Identifier lists come from map queries, including a powers query.<br>• #56 is decided: hash forms cover what the app stores.<br>• Citations and the departures list are corrected, and "void" is used throughout |
| 4.1.0 | 2026-11-25 | Tightened after a fourth independent review, which found nothing blocking.<br>• AC-5.9 now requires 6.F.19, 6.F.20, 6.F.21, 6.F.25 and 6.F.29, which have no paradox under the DATC's preferred rules.<br>• When the paradox flag is set, the whole result is unspecified apart from validity.<br>• The rejection reasons for each order type are given in one table.<br>• "Working convoy route" is defined, and the convoy paradox definition is narrowed.<br>• Outcome symbols are shared by condition name.<br>• A powers acceptance criterion is added, along with the input-contract choice for the via-convoy tag and the remaining citations |
| 4.2.0 | 2026-11-25 | Two promises added after the plan review. Value objects put their list fields into a documented canonical order when built, so equality and the hash form don't depend on input order (AC-2.5). The legal-orders list comes in a documented, stable order (AC-4.7) |

## Problem Statement

The gem and the app are about to be built in parallel. On the gem side that means the map, the value objects, order checking, legal orders and adjudication (#9 to #15). On the app side it means order pickers and the reveal. Neither side can start safely until something says in writing what crosses the boundary between them. Today `adjudicator/docs/interface.md` lists only section headings, and `adjudicator/AGENTS.md` still describes the boundary as "plain data". `docs/architecture.md` has since replaced that with immutable value objects that have a versioned hash form. This feature turns `interface.md` into a promise that covers everything the playtest needs.

## Goals

- `adjudicator/docs/interface.md` documents every call and value the app needs for the playtest:
  - loading the classic map and querying it
  - the value objects and their hash form
  - checking one order
  - listing a unit's legal orders
  - adjudicating a movement phase
  - errors
- Each documented call and value object has at least one Ruby example showing input and expected output.
- The document names every call, field, rejection reason, outcome value and error the app uses, so nothing about the boundary has to be learned from the gem's code.
- Each order has exactly one accepted form, so the checker, the legal-orders list and the app all agree on how an order is written.
- Adjudication gives the results the DATC (v3.4) prefers in the movement sections of chapter 6 (6.A to 6.G). The only exceptions are the departures and pending cases listed in AC-5.9, each recorded in `docs/ruleset.md`.
- `adjudicator/AGENTS.md` and `adjudicator/CHANGELOG.md` agree with the document.

## Non-Goals

- Writing any gem code: the skeleton (#6), map data (#9), value objects (#10), checking (#11), legal orders (#12) or adjudication (#14, #15).
- Specifying retreat or adjustment phases beyond a "coming in 0.3" stub.
- Working out the real next phase, supply-center changes after fall, or solo victory (#38).
- Resolving convoy paradoxes (#39).
- Deciding DATC options beyond those this spec names. The rest are recorded in `docs/ruleset.md` as the engine is built.
- Fixing the interface for good. Before 1.0 a minor version may change it, and one revision is expected after the engine exists.

## Users and Context

**Primary users:**
- agents implementing the gem Issues that say "matches `docs/interface.md`"
- agents building the app's order entry and reveal against a tagged gem release

**Secondary users:** James, who approves the pull request and settles any later interface changes.

**Usage context:** The document is read before starting any Issue that touches the boundary. It is the reference when a gem spec and an app expectation disagree.

**User mental model:** Players think in terms of the board:
- powers, provinces and coasts
- armies and fleets
- hold, move, support and convoy
- outcomes such as "bounced" or "dislodged"

The interface uses the same vocabulary, and the game's standard abbreviations as identifiers. Players pick orders from lists rather than typing them, so a strict, single form for each order costs them nothing.

## Definitions

These terms are used throughout the acceptance criteria. `interface.md` must define them in its own words.

- **Province field:** an order field that holds a province identifier and never a coast. A coast there is malformed input.
- **Location field:** an order field that holds a province, plus a coast when the province has split coasts.
- **Can reach:** a unit can reach a province when the map's adjacency for its unit type connects its current location to that province, or, for a fleet, to at least one coast of it. A fleet's current coast counts (DATC tests 6.A.9, 6.A.10, 6.B.4, 6.B.5).
- **Convoy chain:** an ordered list of distinct sea provinces, each holding a fleet of any power. The first is adjacent to the origin, each is adjacent to the next, and the last is adjacent to the destination. Adjacency to the origin and destination ignores coasts (DATC tests 6.B.18, 6.B.19). Origin and destination are different coastal provinces.
- **Minimal convoy chain:** a convoy chain from which no set of one or more fleets can be removed while leaving a chain between the same origin and destination (DATC 4.E.1, test 6.G.19).
- **Matching:** a support to move or a convoy matches a move when they name the same origin and destination provinces. Coasts are ignored, and so is whether the move is plain or via convoy (DATC tests 6.G.10, 6.G.14, 6.G.17). A support to hold matches a unit that does not move.
- **Moves:** a unit moves when the order it follows is a move or a move via convoy, whatever the outcome (DATC test 6.D.8). The order a unit follows is its owner's legal order, or its implied hold.
- **Working convoy route:** for a move that goes by convoy, a convoy chain in which every fleet gives a legal convoy order matching that move and no fleet is dislodged. One working route is enough. The move loses its route only when every chain is broken (DATC 4.A.1).
- **Convoy paradox:** a set of orders that has no consistent resolution, or more than one, because whether a convoying fleet is dislodged depends, directly or through other orders, on the move of an army it convoys (DATC 4.A.2). Circular movement without such a dependency is not a paradox (DATC tests 6.C.4, 6.C.6).

## User Stories

Every acceptance criterion describes behavior that `interface.md` must promise. Each one is verified twice:
- in review of this pull request, by finding the promise and an example of it in the document
- later, as a passing spec in the gem Issue named in brackets

### Story 1: Load the map and ask it questions

**As an** app developer
**I want** to get the classic map and query it
**So that** I can show provinces, units and choices without hard-coding geography

**Acceptance criteria:**

- [ ] **AC-1.1** Given the gem is loaded When a caller asks for the classic map Then it receives a map object, using the one documented call, without passing a file path. The map has a string identifier [#9]
- [ ] **AC-1.2** Given the classic map When a caller lists provinces Then it receives 75 provinces, each with its identifier, full name and type (inland, coastal or sea) [#9]
- [ ] **AC-1.3** Given the classic map When a caller asks for the coasts of a province Then the three provinces with split coasts each return their named coasts, and every other province returns none [#9]
- [ ] **AC-1.4** Given the classic map When a caller asks whether two locations are adjacent for an army, or for a fleet Then the answer accounts for unit type and, for fleets, for the specific coast [#9]
- [ ] **AC-1.5** Given the classic map When a caller lists supply centers, or the home centers of a power Then it receives 34 supply centers in total, and 22 home centers across the seven powers [#9]
- [ ] **AC-1.6** Given the classic map When a caller asks for the starting position Then it receives a position for spring 1901, in the movement phase, with:
  - each power's starting units
  - each power's home centers owned by that power
  - the other twelve supply centers unowned, in the documented representation for an unowned center

  [#9, #10]
- [ ] **AC-1.7** Given the classic map When a caller lists powers Then it receives seven powers, each with its identifier and name [#9]

### Story 2: Store a value and replay it later

**As an** app developer
**I want** every value that crosses the boundary to have a stable hash form
**So that** I can save it as JSON and rebuild it exactly for any later phase

**Acceptance criteria:**

- [ ] **AC-2.1** Given any documented value object When it is converted with `to_h`, serialized to JSON, parsed back, and rebuilt with `from_h` Then the rebuilt object equals the original. This covers:
  - position and unit
  - dislodged unit
  - each of the six movement order types
  - check result, order outcome and adjudication result

  [#10]
- [ ] **AC-2.2** Given a storable object (a position, any order, a check result, an adjudication result) When it is converted with `to_h` Then the hash includes a `format` key. Its value is the single documented format value for the whole gem, which changes whenever any hash form changes. The object's hash form is the same wherever it appears, including when nested inside another object [#10]
- [ ] **AC-2.3** Given a hash whose `format` is missing or unknown When it is passed to `from_h` Then the documented error class is raised [#10]
- [ ] **AC-2.4** Given the document When a reader looks up any value object Then they find:
  - its fields
  - the type and allowed values of each field
  - whether each order field is a province field or a location field
  - whether it carries `format`
  - an example of its hash form

  [this PR]
- [ ] **AC-2.5** Given two value objects built from the same contents, with their list fields given in different orders When they are compared, and when each is converted with `to_h` Then:
  - they are equal
  - both hash forms list the entries in the same documented canonical order

  The list fields are a position's units, dislodged units, standoff provinces and supply-center ownership [#10]

### Story 3: Check an order as it is entered

**As an** app developer
**I want** to check one order against a position
**So that** a player learns straight away whether the order is legal, and if not, why

**Acceptance criteria:**

- [ ] **AC-3.1** Given a movement-phase position and a legal order When the order is checked Then the result says the order is legal and lists no reasons [#11]
- [ ] **AC-3.2** Given an order that breaks one or more rules When the order is checked Then the result says it is not legal, and its list of reasons holds exactly one reason: the first that applies, in the precedence for that order type given in FR-4. The result keeps a list so that later versions may report more than one reason [#11]
- [ ] **AC-3.3** Given an order naming a power that does not own the ordered unit When the order is checked Then it is not legal, with the foreign-unit reason (DATC 6.A.6) [#11]
- [ ] **AC-3.4** Given a fleet move into a province with split coasts that names no coast When the order is checked Then it is not legal, with the missing-coast reason. This holds even when only one coast is reachable. It is the strict option in DATC 4.B.2, against the DATC's preference, and departs from test 6.B.2 [#11]
- [ ] **AC-3.5** Given a position that is not in a movement phase When a movement order is checked Then it is not legal, with the wrong-phase reason only [#11]
- [ ] **AC-3.6** Given a fleet move that names a coast of the destination which the fleet cannot reach When the order is checked Then it is not legal, with the unreachable-coast reason. The coast is never quietly corrected (DATC 4.B.3, test 6.B.3) [#11]
- [ ] **AC-3.7** Given an army move whose destination names a coast When it is checked Then it is not legal, with the documented reason for a coast where none belongs. This is the strict option in DATC 4.B.6, and departs from test 6.B.12 [#11]
- [ ] **AC-3.8** Given a plain move When it is checked Then it is legal only if the destination is not the unit's own province (DATC tests 6.A.4, 6.A.5), and either:
  - the unit can reach the destination; or
  - the unit is an army and a convoy chain exists, in the position, from its province to the destination.

  Otherwise it is not legal, with the own-province or the not-reachable reason. A fleet can never use a convoy chain (DATC tests 6.A.1, 6.A.7) [#11]
- [ ] **AC-3.9** Given a move via convoy When it is checked Then it is legal only if all of these hold:
  - the unit is an army
  - the destination is not the army's own province
  - the army could reach the destination by land. The tag exists only to choose the convoy route to an adjacent province. That restriction is this spec's input-contract choice: DATC 4.A.3 doesn't require it, but every tag in its tests is on an adjacent move
  - a convoy chain exists from the army's province to the destination

  Otherwise it is not legal, with the matching documented reason [#11]
- [ ] **AC-3.10** Given a convoy order When it is checked Then it is legal only if all of these hold:
  - the ordered unit is a fleet in a sea province
  - an army stands in the named origin
  - the fleet belongs to at least one minimal convoy chain from that origin to the named destination (DATC test 6.G.19)

  Otherwise it is not legal, with the matching documented reason [#11]
- [ ] **AC-3.11** Given an order whose ordered unit is not on the board When the order is checked Then it is not legal, with the no-such-unit reason only [#11]
- [ ] **AC-3.12** Given a support to hold When it is checked Then it is legal only if all of these hold:
  - a unit stands in the supported province
  - the supported province is not the supporter's own (DATC test 6.A.8)
  - the supporter can reach the supported province

  Otherwise it is not legal, with the matching reason from FR-4 [#11]
- [ ] **AC-3.13** Given a support to move When it is checked Then it is legal only if all of these hold:
  - a unit stands in the origin
  - origin and destination differ
  - the origin is not the supporter's own province, since a unit cannot support its own move
  - the destination is not the supporter's own province (DATC test 6.D.34)
  - the supporter can reach the destination
  - the unit in the origin could legally make that move as a plain move, to any coast of the destination, judged as in AC-3.8, using no convoy chain that passes through the supporter's province (DATC test 6.D.31)

  Otherwise it is not legal, with the matching reason from FR-4 [#11]
- [ ] **AC-3.14** Given supports and convoys When they are checked Then the supported or convoyed unit may belong to any power, and nothing about other submitted orders is consulted [#11]

### Story 4: Offer only legal orders

**As an** app developer
**I want** a list of every legal order for one unit
**So that** players pick from lists and can never build an illegal order

**Acceptance criteria:**

- [ ] **AC-4.1** Given a movement-phase position and one of its units When the legal orders for that unit are listed Then every order in the list passes checking, and each one names the unit's owner as the power giving it [#12]
- [ ] **AC-4.2** Given the same position and unit When any order for that unit passes checking Then that order appears in the list. The single form for each order keeps the set of orders finite [#12]
- [ ] **AC-4.3** Given a unit that could support a move nobody is ordering When its legal orders are listed Then that support is included [#12]
- [ ] **AC-4.4** Given a fleet that can reach more than one coast of a province When its legal orders are listed Then there is one move per reachable coast, and no move without a coast [#12]
- [ ] **AC-4.5** Given a position that is not in a movement phase, or a unit not on the board When the legal orders are listed Then the list is empty, and no exception is raised. A unit is on the board only when the position holds a unit with the same power, type and location [#12]
- [ ] **AC-4.6** Given an army with a convoy chain to a province When its legal orders are listed Then:
  - a non-adjacent destination appears as a plain move only
  - an adjacent destination appears as both a plain move and a move via convoy

  [#12]
- [ ] **AC-4.7** Given a position and a unit When the legal orders are listed Then they appear in this documented order, the same on every call:
  1. the hold
  2. moves, by destination province and then coast
  3. moves via convoy, by destination
  4. supports to hold, by supported province
  5. supports to move, by origin and then destination
  6. convoys, by origin and then destination

  Provinces and coasts sort by identifier [#12]

### Story 5: Adjudicate a movement phase

**As an** app developer
**I want** to hand over a position and every submitted order and get the result back
**So that** revealing a phase shows each player what happened and where the board now stands

**Acceptance criteria:**

- [ ] **AC-5.1** Given a movement-phase position and a set of orders When the phase is adjudicated Then the result holds one outcome for every submitted order. It also holds one outcome for each unit whose owner submitted no legal order for it: an implied hold, given by the owner and marked as not submitted [#14]
- [ ] **AC-5.2** Given an adjudicated phase When the outcomes are listed Then they come in this order: submitted orders in the order given, then implied holds ordered by province identifier [#14]
- [ ] **AC-5.3** Given any outcome When a reader inspects it Then its value is one symbol from the documented list. The document gives every condition for each order type, and applies them in the precedence below. The first condition that matches decides the value. Each named condition gets its own symbol. The plan may not merge two conditions, but a condition with the same name under different order types shares one symbol: void, unmatched and given. The cases inside one bullet also share a symbol, such as a bounce, a standoff and a lost head-to-head battle. Matching and working convoy route are as defined above.
  - **Every order type:** the order failed checking (void). This always comes first.
  - **Hold:** the unit held.
  - **Move and move via convoy, in order:**
    - no working convoy route when one was needed, because none was ordered or it was disrupted
    - the move failed (a bounce, a standoff or a lost head-to-head battle)
    - the move succeeded
  - **Support to hold and support to move, in order:**
    - unmatched: the supported unit is not following a matching order (a hold support for a unit that moves is unmatched)
    - cut, which includes a supporter that is dislodged (DATC test 6.D.17)
    - given

    A support's value never depends on whether the supported unit's move succeeded.
  - **Convoy, in order:**
    - unmatched: no matching army move went by convoy, including when the army went by land
    - disrupted: this fleet was dislodged. Other fleets on the same route are not marked. 0.3 may widen this when paradoxes are resolved (#39)
    - given

    A convoy's value never depends on whether the convoyed army's move succeeded.

  [#14, #15]
- [ ] **AC-5.4** Given a unit that was dislodged When the result is inspected Then the dislodged flag is set on the outcome of the order the unit actually followed: its owner's legal order, or its implied hold. Outcomes of orders that failed checking always have the flag clear [#14]
- [ ] **AC-5.5** Given an adjudicated phase When the next position is inspected Then it has:
  - the same season and year, with the phase type set to retreat, whether or not any unit was dislodged
  - every unit that wasn't dislodged, at its location after the moves
  - each dislodged unit listed separately from the units on the board, with the province its attacker came from (no coast), and whether the attack came by convoy (DATC 4.A.5, tests 6.H.11, 6.H.12)
  - every province left empty by a standoff
  - supply-center ownership unchanged

  [#14, #15]
- [ ] **AC-5.6** Given a unit that only other powers ordered, or whose owner's only order fails checking When the phase is adjudicated Then each of those orders is void. The unit gets the implied hold from AC-5.1, which can still receive support (DATC 4.E.1). An order for a unit that is not on the board is also void, and no exception is raised [#14]
- [ ] **AC-5.7** Given an army's move to a province When the phase is adjudicated Then:
  - if the move is to a non-adjacent province, it goes by convoy
  - if it is a move via convoy, it uses only the convoy route and never falls back to the land route
  - if it is a plain move to an adjacent province, it goes by convoy when a fleet of the same power gives a matching convoy order that passes checking (DATC tests 6.G.1, 6.G.7, 6.G.19). Otherwise it goes by land
  - a move that goes by convoy never falls back to the land route, even if the convoy is disrupted or was never ordered (DATC tests 6.G.8, 6.G.11, 6.G.20)
  - the route may use fleets of any power, and need not pass through the fleet whose order showed the intent (DATC test 6.G.6)

  These are the DATC's preferred results for 4.A.3 [#15]
- [ ] **AC-5.8** Given a set of orders that creates a convoy paradox When the phase is adjudicated Then:
  - the call returns a result without raising
  - the result's paradox flag is set; this holds for every pending case named in AC-5.9
  - the next position is valid under AC-6.4
  - every outcome value, and where units end up, is documented as unspecified until 0.3, including for orders unrelated to the paradox (DATC 4.A.2)

  The paradox flag is clear for every scenario that AC-5.9 requires [#15, #39]
- [ ] **AC-5.9** Given the DATC chapter 6 scenarios for movement (6.A to 6.G), with:
  - each "via convoy" in the DATC's notation encoded as a move via convoy
  - every other move encoded as a plain move

  When they are adjudicated Then every result matches the DATC's preferred result, apart from:
  - the departures listed in FR-9
  - 6.B.14, which is a build
  - the retreat step of 6.F.7 (its movement step is still required)
  - the paradox cases, which are pending #39: 6.F.14 to 6.F.18, 6.F.22 to 6.F.24, 6.F.26 to 6.F.28, and 6.G.11. Within 6.F.14 to 6.F.29, the cases 6.F.19, 6.F.20, 6.F.21, 6.F.25 and 6.F.29 have no paradox under the DATC's preferred rules, so they are required

  "Matches" means:
  - the same moves succeed and fail
  - the same units are dislodged
  - the next position has the same units in the same places

  Outcome labels may differ, since DATC 4.E.2 leaves terminology free [#11, #14, #15]

### Story 6: Tell malformed input apart from failed orders

**As an** app developer
**I want** an exception only when my input is broken, never because a player gave a bad order
**So that** a phase reveal never crashes because of what a player chose

**Acceptance criteria:**

- [ ] **AC-6.1** Given a hash with a missing field, an unknown identifier, a wrong type, or a coast in a province field When it is passed to any `from_h` Then the documented error class is raised, and its message includes the offending key or value. The document shows an example hash for each of these four cases [#10]
- [ ] **AC-6.2** Given a set of orders in which one power gives two orders for units in the same province, whether or not the two are identical When the phase is adjudicated Then the documented error class is raised. This is an input-contract choice: the app holds one order per unit. It is none of the options in DATC 4.D.3 [#14]
- [ ] **AC-6.3** Given a position that is not in a movement phase When movement adjudication is called Then the documented error class is raised [#14]
- [ ] **AC-6.4** Given an impossible value object When it is built, through `new` or through `from_h` Then the documented error class is raised. Every value object is validated against the classic map, the only map the gem has; this is revisited when variants arrive. Impossible value objects include:
  - two units on the board in one province (dislodged units are listed separately and don't count)
  - a fleet in an inland province, or an army in a sea province
  - an army with a coast
  - a fleet in a province with split coasts but no coast given
  - a coast that the province doesn't have, in any location
  - an unknown identifier, or a map identifier other than the classic map's
  - ownership recorded for a province that isn't a supply center
  - a movement-phase position with dislodged units or standoff provinces

  [#10]
- [ ] **AC-6.5** Given positions and orders that were all built without raising When a phase is checked, has its legal orders listed, or is adjudicated Then no exception is raised other than those in AC-6.2 and AC-6.3, and every rules failure shows up as a rejection reason or an outcome [#11, #12, #14]

## Functional Requirements

### FR-1: Map

**Must:**
- Document the one call that returns the classic map. No path or file argument is needed.
- Document the map's string identifier, and each query with its return shape:
  - powers (identifier, name)
  - provinces (identifier, name, type)
  - coasts of a province
  - army adjacency, and fleet adjacency by coast
  - supply centers
  - home centers by power
  - the starting position
- State that the map and its province records are query-only. They are not value objects and have no hash form, because a position refers to its map only by identifier. This follows the decision in #56.

**Must not:**
- Promise any map other than the classic map, or any way to load a custom map.

### FR-2: Identifiers

**Must:**
- Choose and document one identifier scheme each for maps, provinces, coasts and powers.
- Use the game's standard three-letter province abbreviations and coast abbreviations.
- State how identifiers appear in Ruby objects and in the hash form, including case and whether they are symbols or strings.
- Make every identifier survive the JSON round trip in AC-2.1.
- Make the full lists of power, province and coast identifiers available through the map queries in FR-1. Show each list, or a documented query for it, in `interface.md`, never only in the gem's data files.

**Must not:**
- Use any name containing or echoing "Diplomacy" or "Dip".

### FR-3: Value objects

**Must:**
- Define each value object as an immutable Ruby `Data` class, following `docs/architecture.md`:
  - **Position:** map identifier, season (spring or fall), year, phase type (movement, retreat or adjustment), units, supply-center ownership (with a documented representation for unowned centers), dislodged units, standoff provinces
  - **Unit:** power, army or fleet, and location (province, plus a coast only for a fleet on a split-coast province)
  - **Dislodged unit:** the unit, its attacker's origin province, and whether the attack came by convoy
  - **Order types**, each with the power giving it and the ordered unit's province (a province field):
    - **hold:** nothing more
    - **move:** destination (a location field)
    - **move via convoy:** destination (a province field)
    - **support to hold:** the supported province (a province field)
    - **support to move:** origin and destination (province fields)
    - **convoy:** origin and destination (province fields)
  - **Check result:** legal or not, and the list of reasons
  - **Order outcome:** the order, its outcome value, whether the order was submitted or implied, and the dislodged flag
  - **Adjudication result:** the outcomes, whether a convoy paradox was found, and the next position
- Document `to_h` and `from_h` for each value object, with an example of the hash form.
- Put a `format` key on the hash form of every storable object (position, each order, check result, adjudication result). Its value is the single format value for the whole gem. Keep each object's hash form the same wherever it appears.
- Use only strings, integers, booleans, nil, arrays and hashes in the hash form, so it can be stored as JSON without custom handling.
- Validate on construction, through `new` and `from_h` alike, and raise the documented error for the cases listed in AC-6.1 and AC-6.4.
- Put list fields into a documented canonical order on construction (AC-2.5). The outcome list is the exception: it keeps the order AC-5.2 gives it.

**Must not:**
- Give value objects behavior beyond construction, validation, equality and conversion.
- Quietly correct a coast or any other field.

### FR-4: Checking one order

**Must:**
- Document the call: it takes a position and one order and returns a check result.
- Document the full list of rejection reasons as symbols, each with a one-line meaning in our own words and, where it applies, the DATC section number.
- Document, for each order type, its conditions in precedence order, since checking reports only the first that fails (AC-3.2). A condition with the same name under different order types gives the same reason symbol. The precedence is:

  | Order type | Conditions, in precedence order (each failing one gives its own reason) |
  |---|---|
  | Every order, first | wrong phase; no such unit; foreign unit |
  | Hold | none further |
  | Move | own province; not reachable (AC-3.8); coast where none belongs (army); missing coast; unreachable coast |
  | Move via convoy | not an army; own province; not adjacent by land; no convoy chain |
  | Support to hold | own province (the supported province is the supporter's); no unit there; not reachable (the supporter can't reach the supported province) |
  | Support to move | own province (origin or destination is the supporter's); same origin and destination; no unit there (none in the origin); not reachable (the supporter can't reach the destination); supported move impossible (AC-3.13, last bullet) |
  | Convoy | not a fleet at sea; same origin and destination, or either not coastal; no unit there (no army in the origin); not on a minimal chain |
- Define legality exactly as in AC-3.8 to AC-3.14, judged from the position alone, using the definitions in this spec.

**Must not:**
- Raise because an order breaks a rule.
- Consult other submitted orders.

### FR-5: Legal orders for a unit

**Must:**
- Document the call: it takes a position and a unit and returns a list of orders.
- State the promise that every listed order passes checking, and every order that passes checking is listed.
- State that the list depends only on the position, never on other submitted orders.
- State that the list is empty, without raising, in the cases in AC-4.5.
- Document the order of the list, as in AC-4.7.

### FR-6: Adjudicating a movement phase

**Must:**
- Document the call: it takes a movement-phase position and a list of orders and returns an adjudication result.
- Document the full list of outcome values, each with a one-line meaning in our own words. Map every condition in AC-5.3 to exactly one value using its precedence, with one value for each bullet.
- Define the paradox flag as set exactly when the orders contain a convoy paradox, as defined above.
- Document:
  - implied holds and the order of the outcome list (AC-5.1, AC-5.2)
  - the dislodged flag (AC-5.4)
  - void orders (AC-5.6)
  - convoy routing (AC-5.7)
  - the paradox flag (AC-5.8)
  - duplicate orders (AC-6.2)
- Document the next position as described in AC-5.5, and say that 0.3 will replace it with the real next phase.
- State that until 0.3 the app builds the next movement position itself, from the retreat position and the host's edits, because movement adjudication rejects a retreat position (AC-6.3).

### FR-7: Errors

**Must:**
- Document one error class that every malformed-input exception descends from, so a caller can rescue them all in one place.
- Document which situations raise:
  - a bad hash, or a missing or unknown `format`
  - a coast in a province field
  - an impossible value object (AC-6.4)
  - one power giving two orders for units in the same province
  - movement adjudication on a position that isn't in a movement phase
- Require every error message to include the offending key or value.
- Say plainly that a rules failure is never an exception.

### FR-8: Stubs for 0.3

**Must:**
- Include "Retreats" and "Adjustments" sections in `interface.md` that say only "coming in 0.3", and name the Issues that will fill them (#36, #37).

### FR-9: Supporting changes

**Must:**
- Add an entry under "Added" in `adjudicator/CHANGELOG.md` for the documented interface.
- In `adjudicator/AGENTS.md`, replace the "plain data" wording: what crosses the boundary is the gem's value objects, with their hash form.
- Replace the "Shape" and "Sections to fill in" text in `interface.md`, since both contradict `docs/architecture.md`.
- Record in `adjudicator/docs/ruleset.md`, in our own words and citing DATC v3.4, the options this spec takes:
  - 4.A.1, 4.A.4 and 4.A.7: the DATC's preferred options, which AC-5.9 requires. 4.A.1 is also captured by the working-route definition
  - 4.A.3: convoy routing as in AC-5.7, the DATC's preferred option. In addition, the via-convoy tag is accepted only for adjacent destinations, as an input-contract choice (AC-3.9)
  - 4.B.2: strict, so a coast is always required
  - 4.B.3: an unreachable coast is rejected
  - 4.B.4: supports name provinces only. This is none of the options 4.B.4 lists, so it is a deliberate departure and an input-contract choice
  - 4.B.5: the ordered unit is identified by province, so its coast is never given, which gives the preferred results
  - 4.B.6: an army move with a coast is rejected
  - 4.D.3: duplicate orders raise
  - 4.E.1: illegal orders are void, and the unit holds
- List the deliberate departures from the DATC's preferred results:
  - **6.B.2:** the order is rejected rather than moving to the only coast
  - **6.B.12:** the army move is rejected
  - **6.B.9:** can't be expressed, since supports carry no coast
  - **4.D.3, duplicate orders:** these raise. There is no chapter 6 test for this

  Note also:
  - 6.B.10 and 6.B.11 can't be expressed as written, since a unit is identified by province. Encoded without the unit's coast, both give the DATC's preferred results.
  - 6.B.7, 6.B.8 and 6.B.15 to 6.B.17 give the DATC's preferred results under the province-only rule.

The rest of the ruleset is filled in by #11, #14 and #15.

**Must not:**
- Change any file outside `adjudicator/`.

## Non-Functional Requirements

### Clarity

- Write the document as a promise, not a design essay: what callers may rely on, with an example, and nothing about how it is implemented.
- Every section has at least one Ruby example showing the call and its result.

### Legal

- Quote no text from the rulebook or the DATC. Explain behavior in our own words, and cite section numbers (DATC v3.4) where behavior depends on them.

### Stability

- The document says which release each section arrives in: 0.1.0 for the map, value objects, checking and legal orders, and 0.2.0 for adjudication. It also says that any 0.x minor version may change it, following the change rules in `adjudicator/AGENTS.md`.

### Performance

- No promise in this document. The speed of listing legal orders is handled in #12.

## Error Scenarios

| Scenario | Expected behavior |
|----------|-------------------|
| `from_h` gets a hash with a missing or unknown `format` | Raises the documented error class |
| `from_h` gets an unknown identifier, or a coast in a province field | Raises the documented error class, naming the offending value |
| An impossible value object is built (AC-6.4) | Raises the documented error class |
| One power gives two orders for units in the same province, identical or not | Raises the documented error class |
| Two powers each order the same unit | No error. The foreign order is void and the owner's order stands |
| Movement adjudication on a retreat or adjustment position | Raises the documented error class |
| Checking a movement order against a position that isn't in a movement phase | Not legal, with the wrong-phase reason only |
| An order that breaks several rules | Not legal, with only the first reason by precedence |
| An order for a unit not on the board | Checking: not legal, with the no-such-unit reason only. Adjudication: void |
| An order names a power that doesn't own the unit | Checking: not legal, with the foreign-unit reason. Adjudication: void |
| An order that fails checking reaches adjudication | Void. The unit gets an implied hold if its owner gave no legal order |
| A coast is missing, unreachable, or on an army move | Not legal, with the matching reason. Never corrected |
| A convoy order from a fleet on no minimal chain | Not legal, with the matching reason. Void at adjudication |
| Listing legal orders outside a movement phase, or for a unit not on the board | An empty list |
| A convoy paradox | A result is returned, with the paradox flag set. Outcomes and unit placement are unspecified until 0.3, but the next position is valid |

## Open Questions

None. Decided on 2026-11-25:
- The 0.2 next position is a post-move snapshot (AC-5.5).
- Orders name the power giving them (FR-3).
- An order for a missing unit is void, and duplicate orders raise (AC-5.6, AC-6.2).
- **From v2.0.0:**
  - each order type has one strict form
  - every storable object carries `format`
  - standoff provinces and convoy-attack flags are recorded now
  - listing legal orders returns an empty list rather than raising
- **From v3.0.0:**
  - convoy routing follows the DATC's preferred results (AC-5.7, AC-5.9)
  - coasts in supports and duplicate orders keep the strict choices, as input-contract rules recorded as departures (FR-9)
- **From v4.0.0:**
  - checking returns one reason, by precedence (AC-3.2)
  - value objects are validated against the classic map (AC-6.4)
  - #56 is decided: hash forms with `format` cover what the app stores, and the map and nested-only objects don't need their own. The root pull request that rewords `docs/architecture.md` follows separately.

Identifier spelling, class names and the exact lists of rejection reasons and outcome symbols are left to the plan, within the limits of FR-2, FR-4 and FR-6.

## Out of Scope (Future Considerations)

- Retreat phases, adjustment phases and the real next phase (0.3: #36, #37, #38).
- How convoy paradoxes are resolved (0.3: #39).
- Map variants, or loading a map from a caller's own file.
- An interface-change Issue for the app. This feature only adds to the interface, so none is needed.
- A reference copy of the DATC in the repository (#57, #58).

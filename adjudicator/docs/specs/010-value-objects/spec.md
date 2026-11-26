# Feature 010: Value objects for positions, units and orders

**Status:** Draft
**Version:** 1.0.1
**Created:** 2026-11-25
**Last Updated:** 2026-11-25
**Issue:** #10
**Branch:** `adjudicator/10-value-objects`

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 1.0.0 | 2026-11-25 | Initial draft |
| 1.0.1 | 2026-11-25 | Recorded James's two decisions (keep `ArgumentError` for a missing keyword, with AC-1.10; reject duplicate standoff provinces) |

## Problem Statement

`docs/interface.md` (merged in #5) promises a set of value objects: units, dislodged units, positions and the six movement orders, each with a hash form that can be saved as JSON and rebuilt into an equal object. Checking (#11), legal orders (#12) and adjudication (#14, #15) all take and return these objects, and the app stores their hash form. Nothing implements them yet, and `Map#starting_position`, which returns a position, was deferred from #9 to this Issue. This feature builds the objects exactly as the contract describes them, so that everything after it has real values to work with.

## Goals

- These exist as immutable `Data` classes, with the names, fields, hash shapes and sort orders that `docs/interface.md` gives:
  - `TA::Unit`, `TA::DislodgedUnit` and `TA::Position`;
  - the `TA::Order` module, with `TA::Order.from_h` choosing the class from `"type"`;
  - the six order classes `TA::Order::Hold`, `Move`, `MoveViaConvoy`, `SupportHold`, `SupportMove` and `Convoy`.
- `from_h(obj.to_h) == obj` holds for every one of these types, including after the hash form has been through `JSON.generate` and `JSON.parse`.
- `from_h` rejects malformed input with `TA::InvalidInput`: a bad shape, a missing or unknown key, a wrong type, a coast in a province field, and a missing or unknown `format`.
- Every impossible object listed in `docs/interface.md` under "Impossible objects" raises `TA::InvalidInput`, from `new` and from `from_h` alike.
- `TA::Map#starting_position` returns the spring 1901 position, built from the map's own data.
- Every Ruby example in `docs/interface.md` that is about these objects runs as a passing spec.

## Non-Goals

- **`TA::CheckResult` is not built here.** It arrives with checking, in #11. The `CheckResult` example lines in `docs/interface.md` are therefore not covered here.
- **`TA::Outcome` and `TA::Adjudication` are not built here.** They arrive with adjudication, in #14. Their sections and examples are not covered here.
- Checking an order (#11), listing legal orders (#12) and adjudicating a phase (#14, #15). A value object is checked only for being well formed. A move to a province the unit can't reach is a valid order object, and judging it is the job of checking.
- Any behavior on these objects beyond construction, validation against the classic map, canonical ordering, freezing, equality and conversion.
- Rebuilding `TA::Location` or `TA::InvalidInput`. Both exist from #9 and are reused as they are.
- Any change to `docs/interface.md`. This feature implements the contract as it stands. If building it shows a defect in the contract, work stops and the defect goes to the coordinator, because changing the contract is an interface change with its own rules in `adjudicator/AGENTS.md`.
- Any map other than the classic one.
- Giving `TA::Location.new`, or any class built here, a different error for a missing keyword. That stays Ruby's `ArgumentError` (Open Question 1, decided by James).

## Users and Context

**Primary users:** agents building #11 (checking), #12 (legal orders) and #14, #15 (adjudication), who need real positions and orders to build on; and the app developer, who stores the hash forms as JSON and rebuilds them later.

**Secondary users:** James, who reads the examples in `docs/interface.md` and expects them to be true.

**Usage context:** the app builds orders from player choices with `new`, or with `from_h` when it reads stored JSON. It stores positions and orders in `to_h` form and replays any phase from them. The gem builds the same objects while adjudicating. A value object that exists is always well formed, so later code never re-checks it.

**User mental model:** the board. A position is who stands where and who owns what, at one moment. An order is what one unit is told to do. The words are the game's: hold, move, support, convoy, dislodged, standoff.

## Definitions

- **Identifier:** a lowercase `Symbol` in Ruby, and the same text as a `String` in the hash form (`docs/interface.md` `## Identifiers`). The map identifier is the `String` `"classic"` in both.
- **Province field:** an order field that holds a province identifier and never a coast. In orders, `at`, `target`, `from` and `to` are province fields.
- **Location field:** a field that holds a `TA::Location`. `Move#destination` is the only one in an order, and `Unit#location` is the other.
- **Hash form:** the result of `to_h`. Its keys are strings all the way down, and its values are only strings, integers, booleans, `nil`, arrays and hashes.
- **Storable object:** a position or an order. It carries `"format"` in its hash form. Units, dislodged units and locations only ever appear nested, and carry none.
- **Canonical order:** the fixed order that list fields are put into when an object is built (`docs/interface.md` `## Value objects`, "Canonical order").
- **Well formed:** every field has the right type, every identifier exists on the classic map, and the object is not one of the impossible objects.

## User Stories

Every acceptance criterion is verified by a passing spec in this pull request unless it says otherwise. "Valid objects" in a round trip means built with `new` from valid parts.

### Story 1: Describe a unit, and a dislodged unit

**As an** app developer
**I want** a unit and a dislodged unit that I can build, save as JSON and rebuild
**So that** I can put units on the board and keep the ones waiting to retreat

**Acceptance criteria:**

- [ ] **AC-1.1** Given a power, a unit type and a `TA::Location` When `TA::Unit.new(power:, type:, location:)` is called Then it returns a frozen object with those three fields, and two units with the same contents are equal and have the same `hash`
- [ ] **AC-1.2** Given a unit When `to_h` is called Then the result is `{"power" => ..., "type" => ..., "location" => {"province" => ..., "coast" => ...}}` with string keys and string or `nil` values only, and no `"format"` key, as in the interface example for Russia's fleet on the south coast of St Petersburg
- [ ] **AC-1.3** Given every valid unit on the classic map, that is each of the 7 powers with an army in each of the 56 non-sea provinces and a fleet in each of the 64 fleet locations When it is converted with `to_h`, written with `JSON.generate`, read with `JSON.parse` and passed to `TA::Unit.from_h` Then the result equals the original, for all 840 units
- [ ] **AC-1.4** Given `new` called with a power or type that is not a symbol, an unknown power (`:atlantis`), an unknown type (`:ship`), or a `location` that is not a `TA::Location` (a `Hash`, a `Symbol`, `nil`) Then it raises `TA::InvalidInput`, and the message includes the offending value
- [ ] **AC-1.5** Given `TA::Unit.from_h` called with a symbol where a string is required, an unknown power or type, a `"location"` that is not a valid location hash, a missing key, an unknown key, symbol keys, or an argument that is not a hash Then it raises `TA::InvalidInput`, and the message includes the offending key or value
- [ ] **AC-1.6** Given a unit, a province with no coast and `by_convoy` of `true` or `false` When `TA::DislodgedUnit.new(unit:, attacker_from:, by_convoy:)` is called Then it returns a frozen object with those fields, equal to another built from the same contents, and `to_h` gives exactly the hash in the interface example (an Austrian army dislodged from `ser` by an attack from `bul`), with no `"format"` key
- [ ] **AC-1.7** Given dislodged units with `by_convoy` `true` and `false`, and attackers from every one of the 75 provinces When each is converted with `to_h`, written as JSON, parsed and passed to `TA::DislodgedUnit.from_h` Then the result equals the original
- [ ] **AC-1.8** Given `TA::DislodgedUnit.new` called with a `unit` that is not a `TA::Unit`, an `attacker_from` that is a string, a `TA::Location`, `nil` or an unknown province, or a `by_convoy` that is not `true` or `false` (`nil`, `"false"`, `0`) Then it raises `TA::InvalidInput`, and the message includes the offending value
- [ ] **AC-1.9** Given `TA::DislodgedUnit.from_h` called with an `"attacker_from"` that is a symbol, or a location hash with a coast (`{"province" => "spa", "coast" => "nc"}`), a `"by_convoy"` that is a string, a missing key, an unknown key or a non-hash Then it raises `TA::InvalidInput`, and the message includes the offending key or value
- [ ] **AC-1.10** Given `new` of any class built here, and `TA::Location.new`, called with a missing required keyword (`TA::Unit.new(power: :france, type: :army)`) or an unknown keyword Then it raises Ruby's `ArgumentError`, not `TA::InvalidInput`. This pins the decision of Open Question 1, and the #9 specs for `TA::Location` are unchanged

### Story 2: Describe a position

**As an** app developer
**I want** a position that holds the whole state of the board at one moment, in a fixed order
**So that** two positions with the same contents are equal and store the same way

**Acceptance criteria:**

- [ ] **AC-2.1** Given a map, season, year, phase, units, ownership, dislodged units and standoffs When `TA::Position.new(...)` is called with keywords Then it returns a frozen object with those eight fields, and `units`, `dislodged_units`, `standoffs` and `ownership` are each frozen. The caller's own arrays and hash are neither frozen nor changed
- [ ] **AC-2.2** Given the position in the interface example (Austria's army in `bud`, Russia's fleet in `stp` on `:sc`, with `bud` owned by Austria and `stp` by Russia) When `to_h` is called Then the result equals the hash in the interface example exactly, and `TA::Position.from_h(JSON.parse(JSON.generate(position.to_h))) == position`
- [ ] **AC-2.3** Given the `army`, `fleet` and `spring` objects of the interface "Canonical order" example When two positions are built from the same contents with `units` and `ownership` given in different orders Then they are equal, their `to_h` are equal, `b.units.map { _1.location.province }` is `[:bud, :stp]` and `b.to_h["ownership"].keys` is `["bud", "stp"]`
- [ ] **AC-2.4** Given units, dislodged units and standoffs given out of order When a position is built Then `units` and `dislodged_units` are sorted by the unit's province, `standoffs` are sorted by identifier, and the same holds after `from_h`. Sorting uses the province identifier alone, so a unit on `stp/sc` and a unit on `spa` sort by `:spa`, then `:stp`
- [ ] **AC-2.5** Given valid positions in each phase: the starting position, a retreat-phase position with two dislodged units (one by convoy, one not) and two standoffs, and an adjustment-phase position in fall 1901 with fewer units than centers, and a position with no units at all When each is converted with `to_h`, written as JSON, parsed and passed to `TA::Position.from_h` Then the result equals the original
- [ ] **AC-2.6** Given `new` called with a map that is not the `String` `"classic"` (including `:classic` and `"modern"`), a season other than `:spring` or `:fall` (including `"spring"`), a phase other than `:movement`, `:retreat` or `:adjustment`, a year that is not an `Integer` (`"1901"`, `1901.0`, `nil`), a list field that is not an `Array`, an element of `units` that is not a `TA::Unit`, an element of `dislodged_units` that is not a `TA::DislodgedUnit`, a standoff that is a string or an unknown province, or an `ownership` that is not a `Hash` Then it raises `TA::InvalidInput`, and the message includes the offending value
- [ ] **AC-2.7** Given `new` called with ownership whose key is a string, whose key is an unknown province, whose value is a string, or whose value is an unknown power Then it raises `TA::InvalidInput`, and the message includes the offending value
- [ ] **AC-2.8** Given `TA::Position.from_h` called with a symbol where a string is required, an `"ownership"` value that is not a string, an `"ownership"` that is not a hash, a `"units"` that is not an array, a `"year"` that is a string or a float, a missing key, an unknown key, symbol keys, or an argument that is not a hash Then it raises `TA::InvalidInput`, and the message includes the offending key or value. This includes the interface error example `TA::Position.from_h(start.to_h.merge("year" => "1901"))`
- [ ] **AC-2.9** Given any position hash handed to `from_h`, whether it is accepted or refused When the call returns or raises Then the hash handed in, and every hash and array inside it, is unchanged, and a frozen hash is accepted

### Story 3: Describe an order

**As an** app developer
**I want** each movement order as its own class, with a single accepted form
**So that** the app, the checker and the adjudicator all write an order the same way

**Acceptance criteria:**

- [ ] **AC-3.1** Given the six order classes When each is built with the keywords of its interface example and converted with `to_h` Then the result equals the hash in that example exactly:
  - `Hold(power, at)`, type `"hold"`;
  - `Move(power, at, destination)`, type `"move"`, where `destination` is a `TA::Location` and appears in the hash as a location hash;
  - `MoveViaConvoy(power, at, to)`, type `"move_via_convoy"`;
  - `SupportHold(power, at, target)`, type `"support_hold"`;
  - `SupportMove(power, at, from, to)`, type `"support_move"`;
  - `Convoy(power, at, from, to)`, type `"convoy"`
- [ ] **AC-3.2** Given any order Then it is frozen, its fields are exactly the ones listed in AC-3.1 and no others, and two orders of the same class with the same contents are equal and have the same `hash`, while the same fields in two different classes are not equal
- [ ] **AC-3.3** Given a hash with `"type"` of each of the six values When `TA::Order.from_h` is called Then it returns an instance of the matching class, equal to the order the hash came from. The interface example `O.from_h({"format" => 1, "type" => "hold", "power" => "england", "at" => "lon"})` gives `O::Hold.new(power: :england, at: :lon)`
- [ ] **AC-3.4** Given `TA::Order.from_h` called with an unknown `"type"` (`"teleport"`, `"Hold"`), a `"type"` that is not a string (`:hold`, `nil`, `1`), no `"type"` key, or an argument that is not a hash Then it raises `TA::InvalidInput`, and the message includes the offending key or value
- [ ] **AC-3.5** Given the valid hash of each order class When it is passed to the `from_h` of each of the other five classes Then every one of those thirty calls raises `TA::InvalidInput`. The interface example `O::Move.from_h({... "type" => "hold" ...})` is one of them
- [ ] **AC-3.6** Given a province field (`at`, `target`, `from` or `to`) in a hash that holds a location hash with a coast (`{"province" => "spa", "coast" => "nc"}`), one without a coast, a symbol, `nil` or an unknown province When `from_h` is called, for each field of each class that has it Then it raises `TA::InvalidInput`, and the message includes the offending value. The interface example for a coast in `"at"` is one of them
- [ ] **AC-3.7** Given `new` called with a `TA::Location` or a string in a province field, a symbol or `nil` for `Move#destination`, or a `Location` field that is not a `TA::Location` Then it raises `TA::InvalidInput`, and the message includes the offending value. A `Move` whose `destination` is a split-coast location with a coast is valid
- [ ] **AC-3.8** Given orders that break a rule of the game but are well formed (a `Move` to the unit's own province, a fleet's `Move` to an inland province, a `Convoy` from an inland province to itself, a `SupportMove` with the same origin and destination, an order for a province where no unit stands) When they are built with `new` or with `from_h` Then they are built, with no error. Judging them is for checking (#11)
- [ ] **AC-3.9** Given every one of the 81 locations as a `Move` destination, and each of the 75 provinces in each province field of each class When each order is converted with `to_h`, written as JSON, parsed and passed to its class's `from_h` and to `TA::Order.from_h` Then both results equal the original
- [ ] **AC-3.10** Given `new` called with a `power` that is not a symbol or is unknown, or an `at` that is an unknown province Then it raises `TA::InvalidInput`, and the message includes the offending value
- [ ] **AC-3.11** Given `from_h` of any order class called with a missing key (each key of each class in turn), an unknown extra key, symbol keys, a symbol where a string is required, or an argument that is not a hash Then it raises `TA::InvalidInput`, and the message includes the offending key or value

### Story 4: Store and replay with a format version

**As an** app developer
**I want** every stored object to say which format it is in, and every hash form to be plain JSON data
**So that** I can save phases and rebuild them in a later release

**Acceptance criteria:**

- [ ] **AC-4.1** Given a position and each of the six orders When `to_h` is called Then the hash has `"format"` with the `Integer` `1`. The hash form of a unit, a dislodged unit and a location has no `"format"`, including when nested inside a position or an order. An order inside any other hash form would carry its own `"format"` too, since a storable object's hash form is the same wherever it appears
- [ ] **AC-4.2** Given a hash with no `"format"` key, or with a `"format"` of `2`, `0`, `"1"`, `1.0` or `nil` When it is passed to `TA::Position.from_h`, to `TA::Order.from_h`, or to the `from_h` of each order class Then it raises `TA::InvalidInput`, and the message includes `"format"` (when missing) or the offending value (when unknown). The two interface examples (missing `"format"`, and `"format" => 2`) are among them
- [ ] **AC-4.3** Given a position and each order When `to_h` is walked all the way down Then every key is a `String`, and every value is a `String`, an `Integer`, `true`, `false`, `nil`, an `Array` or a `Hash`, so `JSON.generate` writes it with no custom handling
- [ ] **AC-4.4** Given the gem's code When it is read Then the format value is written in one place only, and `Position` and every order class read it from there [verified in review]
- [ ] **AC-4.5** Given a hash with a `"format"` of `1` and one other fault When `from_h` is called Then it raises `TA::InvalidInput`. A hash is never accepted because its `"format"` is right

### Story 5: Impossible objects can't be built

**As an** app developer
**I want** an object that can't exist on the map to refuse to be built
**So that** every object I hold is one I can trust

**Acceptance criteria:**

Each criterion holds whether the object is built with `new`, with `from_h`, or by changing a field of a valid object with `with`. In every case the error is `TA::InvalidInput` and its message includes the offending value.

- [ ] **AC-5.1** Given two units on the board in one province When a position is built Then it raises. This covers two armies in `bur`, and an army in `stp` with a fleet on `stp/sc`. A unit that is dislodged does not count: a position with a board unit and a dislodged unit in the same province is valid
- [ ] **AC-5.2** Given a fleet in an inland province, or an army in a sea province When a unit is built Then it raises. This is checked for each of the 14 inland provinces with a fleet, and each of the 19 sea provinces with an army
- [ ] **AC-5.3** Given an army with a coast (`spa/nc`) When a unit is built Then it raises
- [ ] **AC-5.4** Given a fleet in each of the three split-coast provinces `bul`, `spa` and `stp`, with no coast When a unit is built Then it raises. A fleet in each of the six split coasts is valid, and so is a fleet in a coastal province with no split
- [ ] **AC-5.5** Given a coast the province doesn't have (`par` with `:nc`, `bul` with `:nc`), an unknown identifier (`:xyz`) or a map other than `"classic"` (`"modern"`, from `new` and from `from_h`) When a location, unit or position is built Then it raises
- [ ] **AC-5.6** Given ownership of a province that is not a supply center When a position is built Then it raises. This is checked for each of the 41 provinces that are not supply centers (`bur` is the interface example), and each of the 34 supply centers is accepted as an owned province
- [ ] **AC-5.7** Given a position in the movement phase with a standoff province, or with a dislodged unit When it is built Then it raises, both interface examples. A position in the retreat or the adjustment phase with standoffs or dislodged units is valid
- [ ] **AC-5.8** Given an unknown identifier anywhere an identifier is accepted (a power in a unit, an order or ownership; a province in a standoff, an `attacker_from`, an order field or an ownership key) When the object is built Then it raises
- [ ] **AC-5.9** Given the same province twice in `standoffs`, or two dislodged units whose units stand in the same province When a position is built Then it raises. A list never holds the same standoff twice, and one province never holds two dislodged units
- [ ] **AC-5.10** Given each impossible Position, Unit, DislodgedUnit and order of AC-5.1 to AC-5.9, written as the hash form it would have if it could exist When it is passed to the matching `from_h` Then it raises. The interface example `TA::Position.from_h(JSON.parse(JSON.generate(a.to_h)).merge("map" => "modern"))` is one of them
- [ ] **AC-5.11** Given a valid unit or position When `with` is called to change a field to a value that would make an impossible object (a unit's `type` to `:fleet` in an inland province; a position's `phase` to `:movement` when it holds standoffs) Then it raises. No call can make an object that `new` would refuse

### Story 6: Start from the 1901 position

**As an** app developer
**I want** the starting position from the map
**So that** a new game starts from the board as the rules set it up

**Acceptance criteria:**

- [ ] **AC-6.1** Given the classic map When `starting_position` is called Then it returns a `TA::Position` whose `map` is `"classic"`, `season` is `:spring`, `year` is `1901` and `phase` is `:movement`
- [ ] **AC-6.2** Given the starting position When its `units` are read Then there are 22, sorted by province, each equal to the `TA::Unit` for the matching entry of `Map#starting_units`, and they are exactly the units listed per power in the #9 spec (AC-4.2 there), including Russia's fleet on `stp/sc`
- [ ] **AC-6.3** Given the starting position When its `ownership` is read Then it has 22 entries, each home center of each of the seven powers is owned by that power, `ownership[:lon]` is `:england`, `ownership.key?(:bel)` is `false`, and none of the 12 neutral supply centers is present
- [ ] **AC-6.4** Given the starting position When `dislodged_units` and `standoffs` are read Then both are empty
- [ ] **AC-6.5** Given the starting position When it is converted with `to_h`, written as JSON, parsed and passed to `TA::Position.from_h` Then the result equals the original, and it holds 22 units and 22 owned centers. This is the first spec written, and it fails until `TA::Position` exists
- [ ] **AC-6.6** Given the data file read with the standard library's safe YAML loader, without `TA::Map` When its `starting_units` are compared with the starting position Then they agree in power, type, province and coast for all 22 units, and each unit's province is owned by its power in the position. The units come from the map data, and no unit is written down in Ruby code [the second half verified in review]
- [ ] **AC-6.7** Given the classic map When `starting_position` is called twice Then the two results are equal and each is a valid, frozen position
- [ ] **AC-6.8** Given `docs/interface.md` When it is read Then it does not mention `starting_units`, and the code still marks `Map#starting_units` internal [verified in review]

### Story 7: The interface examples run

**As** James
**I want** the examples in `docs/interface.md` to be passing specs
**So that** the contract can't drift from the code

**Acceptance criteria:**

- [ ] **AC-7.1** Given every Ruby example in `docs/interface.md` under `## Value objects` for `TA::Location`, `TA::Unit`, `TA::DislodgedUnit`, `TA::Position`, `TA::Order` and its six classes, under "Canonical order", under "Impossible objects", and the two `format` examples at the head of the section When each is run as a spec Then it gives the value or raises the error that the example's comment says
- [ ] **AC-7.2** Given the `starting_position` examples under `## Map` (the overview block and the `Map#starting_position` subsection) and the `from_h` examples under `## Errors` When each is run as a spec Then it gives the value or raises the error its comment says
- [ ] **AC-7.3** Given the examples this feature does not cover Then the spec for this feature says exactly which they are, and the specs name them as excluded: the `TA::CheckResult` example and the three `CheckResult` lines at the end of "Impossible objects" (#11), the `TA::Outcome` and `TA::Adjudication` examples (#14), and the examples under checking, legal orders and adjudication
- [ ] **AC-7.4** Given the specs for AC-7.1 and AC-7.2 When they build their inputs Then they build them as the examples do (with the same `army`, `fleet`, `spring` and `a` objects) and do not substitute simpler ones

### Story 8: The change is recorded and the old line is updated

**As** James
**I want** the changelog to match what was built and the #9 spec line that said `starting_position` wasn't built to stop saying so
**So that** a release can be cut without archaeology

**Acceptance criteria:**

- [ ] **AC-8.1** Given this pull request When `adjudicator/CHANGELOG.md` is read Then "Unreleased" → "Added" has an entry for the unit, dislodged unit, position and order value objects, `TA::Order.from_h` and `Map#starting_position`, citing #10, and it says `TA::CheckResult` arrives with #11, and `TA::Outcome` and `TA::Adjudication` with #14 [verified in review]
- [ ] **AC-8.2** Given `spec/trucebearer/adjudicator/map_spec.rb` When it is read Then no example says `starting_position` is not built. The example that checks `starting_units` is not in the interface now says only that, and the part that asserted `not_to respond_to(:starting_position)` is gone
- [ ] **AC-8.3** Given this pull request When `bundle exec rspec` and `bundle exec rake` are run from `adjudicator/` Then both pass, with no spec skipped or marked pending [verified by the commands, in the pull request]
- [ ] **AC-8.4** Given this pull request When `git diff --name-only main...HEAD` is run Then every path starts with `adjudicator/`, and `adjudicator/docs/interface.md` is not among them [verified by the command, in the pull request]
- [ ] **AC-8.5** Given the gem's code When it is read Then it defines no `TA::CheckResult`, `TA::Outcome` or `TA::Adjudication`, and does not require the existing #9 specs to change, other than AC-8.2 [verified in review]

## Functional Requirements

### FR-1: `TA::Unit` and `TA::DislodgedUnit`

`Data` classes with the fields, types and hash forms in `docs/interface.md`, neither with `format`.

**Must:**
- `Unit`: `power`, `type` (`:army` or `:fleet`) and `location` (a `TA::Location`). An army's location never names a coast. A fleet's location names a coast exactly when its province has split coasts.
- `DislodgedUnit`: `unit` (a `TA::Unit`, at the location it was dislodged from), `attacker_from` (a province identifier, no coast) and `by_convoy` (`true` or `false`).
- `to_h` gives string keys all the way down, with a unit's `location` as a location hash and a dislodged unit's `unit` as a unit hash. This replaces the symbol-keyed `to_h` that `Data` provides.
- `from_h` takes exactly that shape, with strings for identifiers, and nothing else.

**Must not:**
- Carry `format`.
- Judge anything about where a unit may go. A unit is only checked for being a possible unit.

### FR-2: `TA::Position`

A `Data` class with eight fields in the order the interface gives them: `map`, `season`, `year`, `phase`, `units`, `ownership`, `dislodged_units`, `standoffs`.

**Must:**
- `map` is the `String` `"classic"`. `season` is `:spring` or `:fall`. `phase` is `:movement`, `:retreat` or `:adjustment`. `year` is an `Integer`.
- Put the list fields into canonical order and freeze them when the object is built: `units` and `dislodged_units` by the unit's province, `standoffs` by identifier, and `ownership` by province identifier, which is also the order `to_h` writes it in.
- Copy the lists and the ownership hash it is given, so that the caller's own are never frozen or changed.
- Carry `"format"` in `to_h`, with the value `1`, and refuse a missing or unknown `"format"` in `from_h`.
- Raise `TA::InvalidInput` for each impossible position in Story 5.

**Must not:**
- Correct anything, such as dropping a duplicate or removing a standoff from a movement position. A position that can't exist raises.
- Decide anything about the rules of the game, such as whether the standoff provinces are empty or whether an owned center has a unit on it.

### FR-3: `TA::Order` and the six order classes

`TA::Order` is a module. Each of `Hold`, `Move`, `MoveViaConvoy`, `SupportHold`, `SupportMove` and `Convoy` is a `Data` class inside it, with the fields in Story 3.

**Must:**
- Every order has `power` and `at`. `at`, `target`, `from` and `to` are province fields: a province identifier and never a coast. `Move#destination` is a `TA::Location`.
- `to_h` gives `"format"`, `"type"`, `"power"`, `"at"` and the class's own fields, in that hash form, with `destination` as a location hash.
- `TA::Order.from_h` reads `"type"`, builds the matching class, and raises `TA::InvalidInput` for any other `"type"`. Each class's own `from_h` raises for a hash of another type.
- A coast in a province field raises, in `new` and in `from_h`.

**Must not:**
- Check an order against a position, or against the rules. Any well formed order can be built.
- Accept a second form of the same order.

### FR-4: Hash forms, `format` and strictness

These rules hold for every class above.

**Must:**
- `new` takes symbols only. `from_h` takes strings only (and `nil` where a field may be absent, which only `Location#coast` does). Anything else raises `TA::InvalidInput`.
- `from_h` takes a `Hash` with exactly the documented string keys. A missing key, an unknown key, a symbol key or a value of the wrong type raises `TA::InvalidInput`, and so does an argument that is not a hash.
- `format` is a single value for the whole gem, defined once. It is the `Integer` `1`.
- Every error message includes the offending key or value.
- `from_h` leaves its argument unchanged, and accepts a frozen one.
- Check every identifier against the classic map's known identifiers before making a `Symbol` of it, so that the message shows the caller's own string and unchecked text never becomes a symbol.

**Must not:**
- Change the hash form of `TA::Location`.
- Accept a symbol key, a symbol value or a number where a string is required, to be kind.

### FR-5: Validation

Every value object is validated against the classic map when it is built, by `new`, by `from_h` and by `with`.

**Must:**
- Raise `TA::InvalidInput` for every impossible object in Story 5.
- Reject a wrong type in any field with `TA::InvalidInput` (not Ruby's `TypeError` or `NoMethodError`).

**Must not:**
- Raise `TA::InvalidInput` for an order that merely breaks a rule of the game.

### FR-6: `Map#starting_position`

Returns the position the game starts from, a `TA::Position`, as `docs/interface.md` `## Map` describes it.

**Must:**
- Build it from `Map#starting_units`, turning each entry into a `TA::Unit`.
- Give each power ownership of its own home centers (`Map#home_centers`), and leave the 12 neutral centers out of `ownership`.
- Set season `:spring`, year `1901`, phase `:movement`, map `"classic"`, no dislodged units and no standoffs.
- Be an ordinary public query of the map, with no argument.

**Must not:**
- Write any unit or center in Ruby. The map data is the only place they are written.
- Change the existing queries, or `Map#starting_units`.

### FR-7: Packaging and the record

**Must:**
- Add "Unreleased" → "Added" to `adjudicator/CHANGELOG.md`, as in AC-8.1.
- Update the `starting_units` example in `map_spec.rb` as in AC-8.2.
- Update the comment on `Map#starting_units` so that it no longer says `starting_position` is still to come.
- Leave `docs/interface.md` unchanged.

**Must not:**
- Edit the #9 spec and plan documents. They record what #9 decided at the time. Only the executable spec that asserted `starting_position` was missing changes.
- Change a file outside `adjudicator/`.

## Non-Functional Requirements

### Performance

- No promise in the contract. Building the starting position and converting it both ways is a small, one-off piece of work, and the specs run it many times without slowing the suite noticeably.

### Security

- `from_h` reads stored or received JSON, so it assumes nothing about it. Every field is type-checked and checked against the map before use, and no unchecked text is turned into a symbol (FR-4).
- No call raises anything but `TA::InvalidInput` for a bad value: no `NoMethodError` or `TypeError` from a field of the wrong type (FR-5). The one exception is Ruby's own `ArgumentError` for a call that doesn't pass the right keywords to `new` (see Open Questions).

### Reliability

- Objects are immutable. There is no way to build or derive an object that `new` would refuse (AC-5.11).
- Round trips are exact: two objects with the same contents are equal and have equal hash forms, whatever order their lists were given in.

## Error Scenarios

| Scenario | Expected Behavior |
|----------|-------------------|
| `from_h` gets an argument that is not a `Hash` | Raises `TA::InvalidInput`, and the message includes the argument |
| `from_h` gets a missing key, an unknown key or a symbol key | Raises `TA::InvalidInput`, and the message includes the key |
| `from_h` gets a missing or unknown `"format"` | Raises `TA::InvalidInput`, and the message includes `"format"` or the value |
| `TA::Order.from_h` gets an unknown or missing `"type"` | Raises `TA::InvalidInput`, and the message includes the value or `"type"` |
| An order class's `from_h` gets a hash of another type | Raises `TA::InvalidInput` |
| A coast in a province field (`at`, `target`, `from`, `to`) | Raises `TA::InvalidInput`, and the message includes the value |
| `new` gets a string where a symbol is required, or `from_h` a symbol where a string is required | Raises `TA::InvalidInput`, and the message includes the value |
| An impossible object (Story 5), by `new`, `from_h` or `with` | Raises `TA::InvalidInput`, and the message includes the offending value |
| A well formed order that breaks a rule of the game | Builds. Checking (#11) judges it |
| `new` called without a required keyword, or with an unknown one | Raises Ruby's `ArgumentError`, as `TA::Location.new` already does |
| Calling `from_h` with a hash that is later changed by the caller | The object is unaffected. It holds no reference to the hash |

## Open Questions

None blocking. Points 1 and 2 were put to James and are decided. The rest are decisions made in this spec, put to the reviewer at Gate A so that approval settles them.

1. **A missing keyword in `new` (the #9 nit). Decided by James on 2026-11-25.** `TA::Location.new(province: nil)` raises `TA::InvalidInput`, but `TA::Location.new` with no keywords raises Ruby's `ArgumentError`. **Decision: keep Ruby's `ArgumentError`, for every class.** A missing or unknown keyword is a coding mistake in the code that calls `new`, not bad input, and `ArgumentError` is Ruby's own signal for that. `TA::InvalidInput` stays for bad values, and `from_h` still raises it for a missing key, so an app that rescues it around `from_h` catches everything a stored hash can do wrong. `docs/interface.md` doesn't promise either, so nothing changes for the app. #9's specs stay as they are, and this feature adds a spec that pins the behavior (AC-1.10).
2. **Duplicate standoff provinces (AC-5.9). Decided by James on 2026-11-25.** The interface lists no impossible object for the same standoff province twice. **Decision: it raises `TA::InvalidInput`, with a spec.** A standoff list is a set, and a list with a duplicate would give two objects for one situation, which breaks "same contents, same hash form" unless the duplicate were quietly dropped, and quiet correction is forbidden. This is a stricter validation within the existing promise that an impossible object raises (`docs/interface.md` `## Value objects`, "Validated on construction"). It is not an interface change, so `docs/interface.md` is unchanged and no Interface change Issue is needed. **Not yet decided:** the same stricter rule for two dislodged units in one province, which this spec also includes in AC-5.9 because a province held one unit. It is put to the reviewer at Gate A. If it is dropped, only that clause of AC-5.9 and FR-2 go.
3. **Not checked: standoffs, ownership and units against each other.** A standoff province that has a unit on it, an owned center with no unit, and a dislodged unit that no unit attacked from a neighbor are all valid objects here. The interface lists none of them as impossible, and whether they make sense depends on rules that belong to adjudication. They are left to #14 and later.
4. **Any `Integer` is a valid `year`.** The interface says `Integer`, such as `1901`, and names no range, so none is imposed.
5. **The #9 spec and plan documents are not edited.** They record what #9 decided. Only `map_spec.rb`, the executable spec that asserted `starting_position` was missing, changes (AC-8.2).
6. **`TA::CheckResult`, `TA::Outcome` and `TA::Adjudication` are not built here**, as ruled by the coordinator before work began. Each arrives with the behavior that produces it (#11, #14). The reasons are the Issue's own: building them now would give three classes with no behavior and nothing to test them against but themselves. After Gate A this is commented on #11 and #14.

## Out of Scope (Future Considerations)

- `TA::CheckResult` (#11), `TA::Outcome` and `TA::Adjudication` (#14).
- Checking orders, legal orders and adjudication.
- Retreat and adjustment rules, and the real next phase (0.3).
- Relating standoffs, ownership and units to each other (Open Question 3).
- A second map, and the map identifier being anything but `"classic"`.
- A `TA::Order` class for adjustments or retreats, which arrive in 0.3 with their own order types.

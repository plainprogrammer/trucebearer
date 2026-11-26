# Feature 009: The classic map as a data file

**Status:** Draft
**Version:** 1.1.0
**Created:** 2026-11-25
**Last Updated:** 2026-11-25
**Issue:** #9
**Branch:** `adjudicator/9-classic-map`

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 1.0.0 | 2026-11-25 | Initial draft |
| 1.1.0 | 2026-11-25 | Folded in the first independent review.<br>• Data integrity of the raw file now has its own acceptance criteria (Story 5), checked without the loader.<br>• The reliability bullet no longer contradicts AC-2.10.<br>• `adjacent?` argument checks run before the answer, on `from` and `to` alike.<br>• All seven power names are listed.<br>• The internal reader is named, with its entry shape.<br>• The thread-safety wording leaves the mechanism to the plan.<br>• Error messages are pinned per case.<br>• More `Location` failure cases.<br>• A wider sample of adjacencies, and the set sizes are stated |

## Problem Statement

The gem has no map yet. Checking orders, listing legal orders and adjudicating all need to ask where provinces are, what type they are, which are supply centers, and which locations touch which. `docs/interface.md` (merged in #5) promises a set of map queries and a `TA::Location` value object, but nothing implements them. This feature writes the classic map as a data file, loads it, and builds the queries and the two small types they depend on, so that #10 to #15 can build on a working map.

## Goals

- The classic map exists as one data file in `adjudicator/data/maps/`, with:
  - 75 provinces, each with its type (inland, coastal or sea);
  - 34 supply centers;
  - 22 home centers, grouped by power;
  - the three provinces with split coasts;
  - adjacency for armies, and for fleets by coast where a coast is split;
  - the starting units for spring 1901.
- `TA::Map.classic` loads it, and the queries `docs/interface.md` promises work exactly as written there: `id`, `powers`, `power`, `provinces`, `province`, `coasts`, `adjacent?`, `supply_centers` and `home_centers`.
- `TA::Location` is complete as `docs/interface.md` describes it: province, optional coast, `to_h`, `from_h`, and validation against the classic map.
- `TA::InvalidInput` exists as the gem's one error class.
- Specs prove the counts, adjacency symmetry for armies and for fleets by coast, a sample of known adjacencies that includes each split coast, and that the data agrees with the province table in `docs/interface.md`.
- The starting units are stored in the data file and reachable through an internal reader, ready for #10.

## Non-Goals

- **`Map#starting_position` is deferred to #10.** It returns a `TA::Position`, and `TA::Position` belongs to #10. This feature stores the 1901 starting units in the data file and exposes them through an internal reader only. #10 builds `starting_position` on that reader. Once this spec is approved, the deferral is also commented on Issue #10 (an action for after approval, not part of the pull request). The example lines for `starting_position` in `docs/interface.md` `## Map` are therefore not covered here.
- `TA::Unit`, `TA::DislodgedUnit`, `TA::Position`, orders and results. Those are #10 and later.
- Checking orders (#11), legal orders (#12) and adjudication (#14, #15). That includes knowing which provinces are reachable by convoy.
- Any map other than the classic one, and any way for a caller to pass a map file path.
- Changing `docs/interface.md`. This feature implements the contract as it stands. If building it shows a defect in the contract, the defect goes into an Issue.
- Rendering, coordinates, or anything about how the map looks.

## Users and Context

**Primary users:** agents building #10 (position and units), #11 (checking), #12 (legal orders) and #14 (adjudication), and the app developer, who will call the map queries to build order pickers.

**Secondary users:** James, who reads the data file when a geography question comes up, and anyone who later proposes a variant map.

**Usage context:** `TA::Map.classic` is called often and from anywhere, so it must be cheap after the first call. The data file is read by humans as often as by code.

**User mental model:** the board. Provinces have three-letter abbreviations, armies walk on land, fleets sail on seas and coasts, and a few provinces have two coasts, each with its own neighbors.

## Definitions

- **Location:** a province plus, for a province with split coasts, optionally a coast.
- **Army adjacency:** a pair of provinces an army can step between in one move, by land. Coasts play no part.
- **Fleet adjacency:** a pair of locations a fleet can step between in one move. Where a province has split coasts, each coast is a separate location with its own neighbors.
- **Split-coast province:** `bul` (coasts `:ec` and `:sc`), `spa` and `stp` (each `:nc` and `:sc`).
- **Home center:** a supply center that belongs to one of the seven powers at the start.
- **Internal reader:** a method that is not documented in `docs/interface.md`, is marked internal in the code, and may change in any release.

## User Stories

Every acceptance criterion is verified by a passing spec in this pull request unless it says otherwise.

### Story 1: Know what is on the map

**As an** app developer
**I want** to load the classic map and list its powers and provinces
**So that** I can show them without hard-coding geography

**Acceptance criteria:**

- [ ] **AC-1.1** Given the gem is loaded When a caller calls `TA::Map.classic` with no arguments Then it receives a `TA::Map` whose `id` is the `String` `"classic"`, and every later call returns the same object, including when several threads make the first call at the same moment
- [ ] **AC-1.2** Given the classic map When `provinces` is called Then it returns 75 `TA::Map::Province` records sorted by identifier, of which 14 have type `:inland`, 42 `:coastal` and 19 `:sea`
- [ ] **AC-1.3** Given the classic map and the province table in `docs/interface.md` When the table is read by the spec Then for each of the 75 rows the map's province has the same identifier, name, type, supply-center flag and home power, and the map has no province the table lacks. The spec fails if it reads other than 75 rows
- [ ] **AC-1.4** Given the classic map When `supply_centers` is called Then it returns 34 identifiers sorted ascending, and its first three are `[:ank, :bel, :ber]`
- [ ] **AC-1.5** Given the classic map When `home_centers` is called for each of the seven powers Then the lists are sorted, the total length is 22, `home_centers(:england)` is `[:edi, :lon, :lvp]`, `home_centers(:russia)` is `[:mos, :sev, :stp, :war]`, and each other power has three centers (the 12 supply centers with no home power are the neutral ones)
- [ ] **AC-1.6** Given the classic map When `powers` is called Then it returns seven `TA::Map::Power` records sorted by identifier, namely `:austria`, `:england`, `:france`, `:germany`, `:italy`, `:russia` and `:turkey`, with the names `"Austria"`, `"England"`, `"France"`, `"Germany"`, `"Italy"`, `"Russia"` and `"Turkey"` respectively, and `power(:england).name` is `"England"`
- [ ] **AC-1.7** Given the classic map When `province(id)` is called Then it returns that `TA::Map::Province` with `id`, `name`, `type`, `coasts`, `supply_center` and `home`. For example `province(:spa)` gives `["Spain", :coastal, true, nil]` for name, type, supply center and home, and `province(:lon).home` is `:england`
- [ ] **AC-1.8** Given the classic map When `coasts` is called Then `coasts(:bul)` is `[:ec, :sc]`, `coasts(:spa)` and `coasts(:stp)` are each `[:nc, :sc]`, every other province returns `[]`, and `province(id).coasts` agrees with `coasts(id)` for all 75
- [ ] **AC-1.9** Given the data file When it is read by a spec with the standard library alone, without the loader Then it is found at `data/maps/classic.yml`, it parses, and the gemspec's file list includes it

### Story 2: Ask whether two locations touch

**As a** developer of checking and legal-order listing
**I want** an adjacency query that knows unit type and coast
**So that** I never have to hard-code which fleet can reach which coast

**Acceptance criteria:**

- [ ] **AC-2.1** Given the classic map When `adjacent?(:army, from, to)` is called for every ordered pair of provinces with no coast named Then the answer for `(a, b)` equals the answer for `(b, a)`, and no province is adjacent to itself
- [ ] **AC-2.2** Given the classic map When `adjacent?(:fleet, from, to)` is called for every ordered pair of the 64 fleet locations (the 19 sea provinces, the 39 coastal provinces with no split coast, and the six coasts of the three split-coast provinces) Then the answer for `(a, b)` equals the answer for `(b, a)`, and no location is adjacent to itself
- [ ] **AC-2.3** Given the classic map When `adjacent?` is called with the examples in `docs/interface.md` `## Map` Then it returns `true` for a fleet from `mao` to `spa/nc`, `false` for a fleet from `gol` to `spa/nc`, and `true` for an army from `par` to `bur`
- [ ] **AC-2.4** Given the classic map When a fleet is asked about each coast of each split-coast province Then the answers are as follows. Each line names the coast being entered, and the provinces a fleet starts from, listed without a coast because none of them has split coasts:
  - `spa/nc`: true from `mao`, `gas` and `por`; false from `gol`, `wes` and `mar`
  - `spa/sc`: true from `mao`, `por`, `gol`, `wes` and `mar`; false from `gas`
  - `stp/nc`: true from `bar` and `nwy`; false from `bot`, `fin` and `lvn`
  - `stp/sc`: true from `bot`, `fin` and `lvn`; false from `bar` and `nwy`
  - `bul/ec`: true from `bla`, `con` and `rum`; false from `aeg` and `gre`
  - `bul/sc`: true from `aeg`, `con` and `gre`; false from `bla` and `rum`
  - the two coasts of one province are not adjacent to each other
- [ ] **AC-2.5** Given the classic map When army adjacency is asked about a sample of land borders Then it is `true` for `par`–`bur`, `par`–`pic`, `par`–`gas`, `par`–`bre`, `spa`–`por`, `spa`–`gas`, `spa`–`mar`, `stp`–`fin`, `stp`–`nwy`, `stp`–`lvn`, `stp`–`mos`, `bul`–`con`, `bul`–`gre`, `bul`–`rum`, `bul`–`ser`, `vie`–`boh`, `ber`–`sil`, `kie`–`den`, `rom`–`apu`, `lon`–`wal`, `rom`–`tus`, `tun`–`naf`, `fin`–`nwy`, `ank`–`smy`, `arm`–`smy`, `arm`–`syr`, `lvp`–`yor`, `wal`–`yor`, `edi`–`lvp`, `pie`–`ven`, `tus`–`ven` and `gas`–`mar`, and `false` for `par`–`mar`, `par`–`lon`, `spa`–`bre`, `lon`–`bel` and `rom`–`pie`, and for every pair that has a sea province on either side
- [ ] **AC-2.6** Given the classic map When fleet adjacency is asked about a sample of plain locations Then it is `true` for `lon`–`nth`, `lon`–`eng`, `kie`–`den`, `kie`–`hol`, `kie`–`ber`, `kie`–`hel`, `kie`–`bal`, `ven`–`adr`, `con`–`bla`, `con`–`aeg`, `con`–`smy`, `nth`–`nwg`, `bal`–`bot`, `bar`–`nwy`, `adr`–`ion`, `naf`–`mao`, `den`–`swe`, `nwy`–`swe`, `den`–`bal`, `ion`–`tun` and `mao`–`wes`, and `false` for `par`–`bur`, `mun`–`boh`, `rom`–`ven`, `adr`–`tys`, `lon`–`bel`, `fin`–`nwy`, `ank`–`smy`, `arm`–`syr`, `lvp`–`yor`, `wal`–`yor`, `edi`–`lvp`, `pie`–`ven`, `tus`–`ven`, `gas`–`mar`, `ska`–`bal`, `hel`–`bal`, `aeg`–`bla` and `mao`–`gol` (inland provinces never have fleet neighbors, and two coastal provinces are fleet-adjacent only when they share a stretch of coast)
- [ ] **AC-2.7** Given the classic map When every province is checked Then each of the 64 fleet locations has at least one fleet neighbor (so each of the six split coasts has one), no inland province has a fleet neighbor, every non-sea province has at least one army neighbor, no sea province has one, and every pair of non-sea provinces that are fleet-adjacent (on any coast) is also army-adjacent
- [ ] **AC-2.8** Given the classic map When `adjacent?` is called with a location that breaks the coast rules, in `from` or in `to` Then it raises `TA::InvalidInput`, before any answer is worked out, so a call whose other location is also unreachable still raises rather than returning `false`:
  - an army location that names a coast, such as `(:army, par, spa/nc)` and `(:army, spa/nc, par)`;
  - a fleet location on a split-coast province that names no coast, such as `(:fleet, mao, spa)` and `(:fleet, spa, mao)`;
  - either rule, with a partner that would otherwise give `false`, such as `(:army, spa/nc, nth)` and `(:fleet, spa, par)`;
  - the message names the offending location in `inspect` form
- [ ] **AC-2.9** Given the classic map When `adjacent?` is called with a unit type other than `:army` or `:fleet` (including the strings `"army"` and `"fleet"`), or with a `from` or `to` that is not a `TA::Location` Then it raises `TA::InvalidInput`, and the message names the offending argument in `inspect` form
- [ ] **AC-2.10** Given the classic map When an army is asked about a location in a sea province, or a fleet about a location in an inland province Then it returns `false`, and raises nothing

### Story 3: Build and store a location

**As an** app developer
**I want** a `TA::Location` that names a province and, where needed, a coast
**So that** I can name where a unit is or is going, and save that as JSON

**Acceptance criteria:**

- [ ] **AC-3.1** Given a province and optional coast as symbols When `TA::Location.new(province:, coast:)` is called Then it returns an immutable object with `province` and `coast`, `coast` defaults to `nil`, and two locations with the same contents are equal and have the same `hash`. Keywords are the documented way to build one. Positional arguments are neither promised nor tested
- [ ] **AC-3.2** Given a location When `to_h` is called Then the result is `{"province" => "spa", "coast" => "nc"}` for `spa/nc`, `{"province" => "bud", "coast" => nil}` for `bud`, with string keys and string or `nil` values only, and no `"format"` key
- [ ] **AC-3.3** Given the hash form When it is written as JSON, parsed back and passed to `TA::Location.from_h` Then the result equals the original, for every one of the 81 locations the classic map allows (75 provinces with no coast, plus the six coasts of the three split-coast provinces)
- [ ] **AC-3.4** Given `new` called with a string where a symbol is required, or `from_h` called with a symbol where a string is required Then it raises `TA::InvalidInput`, for example `L.new(province: "stp")`, `L.new(province: :stp, coast: "sc")`, `L.from_h({"province" => :stp, "coast" => nil})` and `L.from_h({"province" => "stp", "coast" => :sc})`. A province that is `nil` or not an identifier at all (an `Integer`) raises the same way, in `new` and in `from_h`
- [ ] **AC-3.5** Given a province or coast that cannot exist When a location is built with `new` or `from_h` Then it raises `TA::InvalidInput`. The cases are: an unknown province (`:xyz`), an unknown coast (`:xx`), a coast on a province that has none (`par` with `:nc`), and a coast that the province does not have (`bul` with `:nc`, `spa` with `:ec`)
- [ ] **AC-3.6** Given a province with split coasts When a location is built with no coast Then it is valid. A location is only a place; whether a unit may stand there is the unit's concern (#10)
- [ ] **AC-3.7** Given a hash that is not exactly `{"province" => ..., "coast" => ...}` When it is passed to `from_h` Then it raises `TA::InvalidInput`. The cases are: a missing `"province"` key, a missing `"coast"` key, an unknown extra key, symbol keys instead of string keys (`{province: "spa", coast: nil}`), and an argument that is not a hash
- [ ] **AC-3.8** Given any of the failures above When the error is rescued Then its message includes, in `inspect` form, the offending item: the key name for a missing or unknown key (such as `"coast"`), the value for a bad value (such as `:xyz`, `"spa"` or `nil`), and the argument for a non-hash

### Story 4: Keep the starting units for #10

**As the** developer of #10
**I want** the 1901 starting units to come from the map data
**So that** `Map#starting_position` can be built without writing the units down again

**Acceptance criteria:**

- [ ] **AC-4.1** Given the classic map When the internal reader `Map#starting_units` is called Then it returns 22 entries sorted by province. Each entry is a `Hash` with exactly the symbol keys `:power`, `:type` (`:army` or `:fleet`) and `:location` (a `TA::Location`). The list and every entry are frozen
- [ ] **AC-4.2** Given the starting units When they are read by power Then they are:
  - `:austria`: army `vie`, army `bud`, fleet `tri`
  - `:england`: fleet `lon`, fleet `edi`, army `lvp`
  - `:france`: army `par`, army `mar`, fleet `bre`
  - `:germany`: army `ber`, army `mun`, fleet `kie`
  - `:italy`: army `rom`, army `ven`, fleet `nap`
  - `:russia`: army `mos`, army `war`, fleet `sev`, fleet `stp` on coast `:sc`
  - `:turkey`: army `con`, army `smy`, fleet `ank`
- [ ] **AC-4.3** Given the starting units When they are compared with the map Then each unit stands on a home center of its own power, each power has exactly one unit per home center, no two units share a province, no army stands on a sea province, no fleet stands on an inland province, and a fleet's location names a coast exactly when its province has split coasts
- [ ] **AC-4.4** Given `docs/interface.md` When it is read Then it does not mention `starting_units`, and the code marks it internal [verified in review]. `Map#starting_position` is not built here; it arrives with #10

### Story 5: The data file is sound

**As the** maintainer
**I want** the raw data checked without going through the loader
**So that** a typo in the file shows up as a failing spec, and not as a wrong answer later

**Acceptance criteria:**

All of these read the file with the standard library's safe YAML loader, without `TA::Map`.

- [ ] **AC-5.1** Given the raw file When it is loaded with the safe loader, with no permitted classes and no aliases Then it loads, and every identifier in it (provinces, coasts, powers, unit types, the neighbors in every adjacency list, and the starting units) is a `String`
- [ ] **AC-5.2** Given the raw army-adjacency lists When each entry `a` lists `b` Then `b` also lists `a`, no list names its own province, no list has a duplicate, every name is a known province, and no list names a sea province
- [ ] **AC-5.3** Given the raw fleet-adjacency lists When each entry `a` lists `b` Then `b` also lists `a`, no list names its own location, no list has a duplicate, every entry's province is known, and no list names an inland province
- [ ] **AC-5.4** Given the raw fleet-adjacency lists When every location in them is read Then a location names a coast exactly when its province is `bul`, `spa` or `stp`, and the coast is one of that province's own, so a fleet location on a split-coast province is never written without its coast
- [ ] **AC-5.5** Given the raw file When the starting units are read Then every one names a known power, a known unit type, a known province and, where it names a coast, one the province has
- [ ] **AC-5.6** Given the loader When it uses the file Then it reads it with the safe loader [verified in review]

### Story 6: Unknown names are rejected the same way everywhere

**As an** app developer
**I want** one error class for bad input
**So that** one `rescue` is enough

**Acceptance criteria:**

- [ ] **AC-6.1** Given the gem is loaded When `TA::InvalidInput` is inspected Then it is a subclass of `StandardError` directly, and it has no subclasses of its own
- [ ] **AC-6.2** Given the classic map When `province`, `coasts`, `power` or `home_centers` is called with an identifier the map does not know (`:xyz`, the string `"spa"`, `nil`) Then it raises `TA::InvalidInput`, and the message includes the offending value in `inspect` form (`:xyz`, `"spa"`, `nil`)
- [ ] **AC-6.3** Given the classic map When any list is returned by a query Then the list is frozen, and the sort order is by identifier (`provinces`, `powers`, `supply_centers`, `home_centers`, `coasts`). Every `Power` and `Province` record is frozen too, and so is `Province#coasts`

### Story 7: The change is recorded

**As** James
**I want** the changelog and the docs to match what was built
**So that** a release can be cut without archaeology

**Acceptance criteria:**

- [ ] **AC-7.1** Given this pull request When `adjudicator/CHANGELOG.md` is read Then "Unreleased" → "Added" has an entry for the classic map, the loader, the queries, `TA::Location` and `TA::InvalidInput`, citing #9, and the entry says `Map#starting_position` arrives with #10 [verified in review]
- [ ] **AC-7.2** Given this pull request When `bundle exec rspec` and `bundle exec rake` are run from `adjudicator/` Then both pass [verified by the commands, in the pull request]

## Functional Requirements

### FR-1: The data file

The classic map is a single data file, `adjudicator/data/maps/classic.yml`. Maps are data, never code: no province, adjacency or unit appears in a Ruby file.

**Format decision.** The file is YAML, read with the Ruby standard library. The reasons are:
- **Comments.** A map of 75 provinces, written by hand, benefits from notes next to the entries that need them, such as why a fleet can pass between two coastal provinces. JSON has no comments.
- **Readable adjacency.** A neighbor list reads as one line per province.
- **Nothing to add.** YAML and JSON are both in the standard library, so there is no new dependency either way.

The cost of YAML is that it reads some bare words as booleans or numbers. The file protects against that with two rules: every identifier is quoted, so that it parses as a `String` (a spec checks this, AC-5.1), and the file is read only with a safe loader that allows plain data types and nothing else (verified in review, AC-5.6). The data file never contains Ruby symbols; the loader turns identifiers into symbols.

**Must:**
- Hold, for each province: identifier, name, type, supply-center flag, home power (if any), and coasts (if split).
- Hold the seven powers: identifier and name.
- Hold army adjacency as neighbor lists between provinces.
- Hold fleet adjacency as neighbor lists between locations, naming a coast wherever a province has split coasts.
- List each adjacency from both sides, so a spec can check symmetry against the data rather than against code that made it symmetric.
- Hold the 22 starting units: power, unit type, province and, where needed, coast.
- Use exactly the identifiers, names, types, supply centers and home powers of the province table in `docs/interface.md`.
- Be written independently from public geographic knowledge and the game's terms of art. A comment at the head of the file says so.

**Must not:**
- Be derived from a scan or image of any edition's board.
- Be copied or translated from any other engine's data files.
- Contain text from the rulebook or the DATC.
- Contain a name that includes or echoes the game's trademarked name or its three-letter prefix.

### FR-2: The loader

`TA::Map.classic` reads the data file once, builds an immutable map, and returns that same map on every call. It takes no path argument.

**Must:**
- Find the file relative to the gem's own `lib` directory, so it works from a checkout and from an installed gem.
- Build `TA::Map::Power` and `TA::Map::Province` records that are immutable (frozen, with a frozen `coasts` list) and are query results, not value objects: they have no `from_h`, and any `to_h` they happen to have is not part of the contract.
- Turn every identifier into a `Symbol`, except the map identifier, which stays the `String` `"classic"`.
- Return the same map object to concurrent first callers, and avoid building a `TA::Location` in a way that re-enters the first load (a `Location` checks itself against the loaded map). How is left to the plan.

**Must not:**
- Offer a way to load another file through the public interface.
- Validate the file beyond what reading it needs. Data integrity is the job of the specs, which run in the gem's own test run. A corrupt file is a gem defect, and `TA::InvalidInput` is for bad caller input, so the loader does not raise it for the file.

### FR-3: The map queries

All queries are as `docs/interface.md` `## Map` describes them. In particular:

**Must:**
- `Map#id` returns `"classic"`.
- `Map#powers`, `Map#provinces`, `Map#supply_centers`, `Map#home_centers(power_id)` and `Map#coasts(province_id)` return lists sorted by identifier.
- `Map#power(id)` and `Map#province(id)` return one record.
- `Map#adjacent?(unit_type, from, to)` follows the rules in AC-2.1 to AC-2.10, and checks its arguments (unit type, the two locations, the coast rules for each) before it works out an answer. For a fleet the answer depends on the exact coast. For an army coasts play no part, and naming one is an error.
- A fleet moving between a split-coast province's two coasts is never adjacent, since both coasts belong to one province.
- Return lists that are frozen.
- Raise `TA::InvalidInput` for any identifier the map does not know, including a `String` where a `Symbol` is required.

**Must not:**
- Define `Map#starting_position`. It arrives with #10.
- Change the contract: no new public query, and no change to the result of an existing one.

### FR-4: `TA::Location`

A `Data` class, as `docs/interface.md` describes, with `province` and `coast`.

**Must:**
- Validate on construction, with `new` and with `from_h`, against the classic map: the province must exist, and a coast, when given, must be one of that province's own coasts.
- Accept symbols only in `new`, and strings only in `from_h` (the one exception being `nil` for an absent coast).
- Give the hash form `{"province" => String, "coast" => String or nil}`, with no `"format"`. This replaces the symbol-keyed `to_h` that `Data` provides.
- Make `from_h` take exactly that shape: a missing or unknown key raises.
- Round-trip through JSON.

**Must not:**
- Decide whether a unit may stand at the location. A fleet needing a coast on a split-coast province is a rule for `TA::Unit` (#10) and for `Map#adjacent?`.
- Carry `format`.

### FR-5: `TA::InvalidInput`

The gem's one error class: a direct subclass of `StandardError`, with no subclasses. Every message includes the offending key or value. This feature raises it from the places listed above. Later features add their own uses, and `docs/interface.md` `## Errors` already lists them.

### FR-6: The internal starting-units reader

One internal method, `Map#starting_units`, returns the 22 starting units as a frozen list of frozen hashes, each with the symbol keys `:power`, `:type` and `:location` (a `TA::Location`), sorted by province. It is marked internal in a code comment, and is absent from `docs/interface.md`. #10 turns each entry into a `TA::Unit` when it builds `starting_position`.

### FR-7: Packaging and the changelog

The data file ships in the gem, because the gemspec already includes `data/**/*`. The changelog entry is as in AC-7.1. `docs/interface.md` is unchanged.

## Non-Functional Requirements

### Performance

- The data file is parsed at most once per process. A repeated `TA::Map.classic` costs no more than returning an existing object.
- `adjacent?` does not scan the whole map. It answers from a lookup built when the map was loaded [verified in review].

### Security

- The file is read with a safe loader that builds plain data only, never arbitrary objects.
- The gem reads only its own data file, never a caller-supplied path, and makes no network calls.
- Specs that read `docs/interface.md` read it only from the repository checkout.

### Reliability

- The map is immutable once built, and safe to share between threads. Threads that call `TA::Map.classic` at the same moment all receive the same object (checked by a spec that starts several threads and compares with `equal?`).
- `adjacent?` raises only for the cases in AC-2.8 and AC-2.9. Every other pair of locations gets `true` or `false`, so a caller can always tell "not adjacent" from "malformed question".

## Error Scenarios

| Scenario | Expected Behavior |
|----------|-------------------|
| `province(:xyz)`, `coasts(:xyz)`, `power(:xyz)` or `home_centers(:xyz)` | Raises `TA::InvalidInput`, and the message includes `:xyz` |
| A `String` where a `Symbol` is required, such as `province("spa")` | Raises `TA::InvalidInput`, and the message includes the value |
| `adjacent?` with an army location that names a coast, in `from` or `to` | Raises `TA::InvalidInput`, and the message names the location |
| `adjacent?` with a fleet location on a split-coast province that names no coast, in `from` or `to` | Raises `TA::InvalidInput`, and the message names the location |
| `adjacent?` with a unit type other than `:army` or `:fleet` | Raises `TA::InvalidInput`, and the message names the value |
| `adjacent?` with a `from` or `to` that is not a `TA::Location` | Raises `TA::InvalidInput`, and the message names the value |
| An army asked about a sea location, or a fleet about an inland one | Returns `false` |
| `TA::Location.new` with an unknown province, an unknown coast, or a coast the province lacks | Raises `TA::InvalidInput`, and the message includes the offending value |
| `TA::Location.new` with a `String` | Raises `TA::InvalidInput`, and the message includes the value |
| `TA::Location.from_h` with a missing key, an unknown key, a symbol value or a non-hash | Raises `TA::InvalidInput`, and the message includes the offending key or value |
| The data file is missing or not valid YAML | The underlying read or parse error propagates. It is a gem defect, not caller input, so `TA::InvalidInput` is not used |

## Open Questions

None. The coordinator ruled on the points that were open before work started: the cycle between `adjacent?` and `TA::Location` (this Issue builds `TA::Location` and `TA::InvalidInput`), the deferral of `Map#starting_position` to #10, and the requirement to choose and justify the data format (YAML, above).

## Out of Scope (Future Considerations)

- `Map#starting_position` (#10).
- A second map, or loading a map from a caller-supplied path.
- Convoy reachability, or any adjacency between non-adjacent locations.
- A schema or a validating loader for map files. This becomes worth doing if variant maps arrive.
- Display names in other languages.

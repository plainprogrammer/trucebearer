# Feature 019: The adjudicator boundary and a stand-in adjudicator

**Status:** Draft
**Version:** 1.1.0
**Created:** 2026-11-26
**Last Updated:** 2026-11-26
**Issue:** #19
**Branch:** `web/19-adjudicator-boundary`

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 1.0.0 | 2026-11-26 | First draft |
| 1.1.0 | 2026-11-26 | Changed after the first independent review.<br>• The boundary gets four loaders (`load_position`, `load_order`, `load_check_result`, `load_adjudication`) that take a gem object, a string-keyed hash or nil, so the attribute types never name a gem class.<br>• The attribute types subclass `ActiveRecord::Type::Value`, never `Type::Json`, and let errors out. Unparsable JSON text is stated.<br>• Rule 4 of the stand-in is now a stated procedure with one result, and the swap, rotation, chain and coast cases get ACs, plus a sweep over legal orders.<br>• The guard gets exact patterns, negatives and a wider file set. The gem is declared `require: false`.<br>• "One file" is reworded to what really changes at 0.2.0. The stand-in's result classes are `Data` classes with fixed names.<br>• Verification fixes: no timing number, drop-table check, pin spec reads `Gemfile` text only |

## Problem Statement

The rules live in the `trucebearer-adjudicator` gem, and the app has to use them without being tied to how the gem changes. Release 0.1.0 can build the starting position, check one order and list a unit's legal orders, but it cannot adjudicate a phase: `TA::Outcome`, `TA::Adjudication` and `TA.adjudicate` arrive in 0.2.0 (`adjudicator/docs/interface.md`, "Releases"). The screens that follow (#21 onwards) need all four calls today, and they need to store and replay what the gem produces. Without one place that owns the gem, gem calls spread through the app and the 0.2.0 upgrade (#29) turns into a hunt.

## Goals

- The app depends on the gem at the git tag `adjudicator-v0.1.0`, and the committed `Gemfile.lock` installs frozen with no extra steps.
- One switch (`ADJUDICATOR_PATH`) points the app at a local checkout of the gem for the early-warning job, as set out in the comment on Issue #19.
- One boundary object is the only place in the app that touches the gem. It offers the starting position, checking an order, a unit's legal orders and adjudicating a phase.
- Until 0.2.0, adjudication is answered by a stand-in, inside the boundary object's own file, that returns results in the documented shape. At 0.2.0 the only app source file that changes is that one, and callers that use the documented readers change not at all (see Story 5 for what else moves).
- Positions, orders, check results and adjudication results can be saved in JSON columns as the gem's hash form and loaded back into equal objects. #21 and #22 reuse this without redesigning it.
- A spec fails if any other app code reaches for the gem.

## Non-Goals

- The game, seat and phase tables. Those are #21 and #22, and this feature adds no table to the app's schema.
- Real adjudication. The stand-in's outcomes are **fake** and must never be shown to players as real results. No screen uses them yet.
- Supports, convoys, cuts, dislodgements, retreats, adjustments or the next phase.
- Any screen, route, controller or Stimulus code.
- Upgrading the pin to 0.2.0 (#29), or editing anything in `adjudicator/`, `.github/` or the root files.
- Storing the map. The map is queried, never stored (`docs/architecture.md`).

## Users and Context

**Primary users:** Developers and agents building #21 onwards, who call the boundary object and declare stored columns.
**Secondary users:** The maintainer, who runs the early-warning job against the gem's latest code, and whoever does the 0.2.0 upgrade.
**Usage context:** Server-side Ruby only. Nothing in this feature is visible to a player.
**User mental model:** "Ask the rules engine." The caller knows nothing of the gem's classes. It gets values back, passes them in again, and saves them.

## Decisions

These were chosen for this spec, with the alternatives that were left out.

**D1. The boundary object is `RulesEngine`.** It is a plain Ruby module with module functions, in one file, `app/models/rules_engine.rb`. The name says what it is: the app's single door to the rules engine. It contains no "Dip" or "Diplomacy". The gem's own module is `Trucebearer::Adjudicator`, so the boundary does not reuse the name `Adjudicator`, which would confuse the guard spec in FR-7.

**D2. What the stand-in returns.** 0.1.0 has no adjudication classes, so the stand-in cannot return gem objects. Options:

| Option | Trade-off |
|---|---|
| **A. A bare hash in the documented form** | Least code. But callers would index a hash, and when 0.2.0 returns `TA::Adjudication` every caller changes, so the upgrade is not a one-file change. |
| **B. An app-side value object that matches the readers of `TA::Adjudication` and `TA::Outcome`** (`outcomes`, `paradox`, `position`; `order`, `result`, `submitted`, `dislodged`) and has `to_h` and `from_h` producing the documented hash form | A few dozen lines. Callers read the same names before and after 0.2.0, and stored rows stay valid. **Chosen.** |
| C. Leave adjudication out until 0.2.0 | Breaks the Issue's "Done when", and blocks #21's end-to-end flow. |

Option B lives inside `app/models/rules_engine.rb`, as the nested classes `RulesEngine::StandInAdjudication` and `RulesEngine::StandInOutcome`, both built with `Data.define` so equality, `to_h` and pattern matching behave as the gem's do. The 0.2.0 upgrade deletes them. Their `position` is a real gem position, and their orders are real gem orders. `load_adjudication` for a hash validates as the gem documents for value objects: exactly the documented keys, `format` 1, `result` one of the nine symbols, booleans where booleans belong.

**D3. How storage is proved.** A table that exists only while the specs run, built in `spec/support/` and never in `db/`. The alternative, one minimal real table, would put a table in the production schema that #21 and #22 then have to migrate away. The attribute types are real app code (`app/models/`) and are the part #21 and #22 reuse.

**D4. Attribute types.** One ActiveRecord attribute type per stored kind: position, order, check result and adjudication result. Each subclasses `ActiveRecord::Type::Value` (not `Type::Json`, whose `deserialize` swallows decode errors and whose in-place change check re-reads the raw value). Each serializes with `to_h` as JSON text, and loads through the boundary's matching loader. The types never name a gem class.

## User Stories

### Story 1: The gem is pinned and can be swapped for a local copy

**As a** developer or the CI job
**I want** the gem pinned to a released tag, with a switch to use a local checkout
**So that** a gem change cannot reach the app before a deliberate upgrade, and the early-warning job can still try the gem's latest code

**Acceptance criteria:**

- [ ] **AC-1.1** Given `web/Gemfile` When `ADJUDICATOR_PATH` is unset or an empty string Then it declares `trucebearer-adjudicator` from the repository `https://github.com/plainprogrammer/trucebearer.git` at the tag `adjudicator-v0.1.0` with the glob `adjudicator/*.gemspec`, and declares no `path:` for it
- [ ] **AC-1.2** Given the committed `web/Gemfile.lock` and `ADJUDICATOR_PATH` unset When `BUNDLE_FROZEN=true bundle install` runs in `web/` Then it succeeds and leaves `Gemfile.lock` unchanged
- [ ] **AC-1.3** Given `ADJUDICATOR_PATH` set to the gem's folder (`../adjudicator` from `web/`) and `BUNDLE_FROZEN=false` When `bundle install` runs Then it resolves the gem as a path source at that folder, and `bundle exec rspec` passes
- [ ] **AC-1.4** Given a working copy on which AC-1.3 has just run When `git checkout -- Gemfile.lock` restores the committed lockfile Then AC-1.2 still passes, so the switch never needs a hand edit of the committed lockfile
- [ ] **AC-1.5** Given `web/Dockerfile` When its build stage is read Then it installs `git` before running `bundle install`, so a git source builds. No Dockerfile change is made if it already does

### Story 2: One boundary object for every gem call

**As a** developer building a screen
**I want** one object that offers the starting position, checking, legal orders and adjudication
**So that** I never touch the gem directly and the app has one place to upgrade

**Acceptance criteria:**

- [ ] **AC-2.1** Given the boundary object When `RulesEngine.starting_position` is called Then it returns a position of the classic map in spring 1901, in the movement phase, with 22 units
- [ ] **AC-2.2** Given the starting position When England's hold in London is checked (`RulesEngine.check`) Then the result is legal and has no reasons
- [ ] **AC-2.3** Given the starting position When France's hold in London is checked Then the result is not legal and its reasons are `[:foreign_unit]`
- [ ] **AC-2.4** Given the starting position and England's fleet in London (taken from the position's own units) When `RulesEngine.legal_orders` is called Then the list starts with England's hold in London, and every order in it passes `RulesEngine.check`
- [ ] **AC-2.5** Given hash forms of a position, an order (each of the six types), a check result and an adjudication result as `JSON.parse` returns them When each is passed to the boundary's matching loader (`load_position`, `load_order`, `load_check_result`, `load_adjudication`) Then each returns an object equal to the original
- [ ] **AC-2.5a** Given an object already of the right kind, or nil When it is passed to its loader Then the same object, or nil, comes back
- [ ] **AC-2.5b** Given a value that is neither of the right kind, a hash nor nil (an Integer, a String, an array, or an object of another kind such as an order given to `load_position`) When it is passed to a loader Then `InvalidInput` is raised and its message names the value
- [ ] **AC-2.6** Given any hash form with a `format` other than `1`, or without one, or with symbol keys, or with a missing or unknown key When it is passed to a loader Then the gem's `InvalidInput` error is raised, and it is the same class as `RulesEngine::InvalidInput`
- [ ] **AC-2.7** Given the app's code (every file under `app/`, `lib/`, `config/`, `db/` and `bin/`, plus `config.ru` and `Rakefile`) When it is scanned Then no file other than `app/models/rules_engine.rb` matches the guard patterns of FR-7
- [ ] **AC-2.8** Given the guard's matcher When it is run on strings Then it flags `Trucebearer::Adjudicator`, `Trucebearer.const_get`, `TA::Order`, `require "trucebearer/adjudicator"` and `RulesEngine::StandInOutcome`, and it does not flag the page title `Trucebearer`, `TABLE`, `DATA`, `STATUS`, `RulesEngine::InvalidInput` or `RulesEngine.check`
- [ ] **AC-2.8a** Given `web/Gemfile` When it is read Then the gem is declared with `require: false`, and the only `require` of the gem in the app is in the boundary file
- [ ] **AC-2.9** Given the boundary object When it is read Then its name, its methods and its nested classes contain no "Dip" and no "Diplomacy" (the existing words spec already covers this)

### Story 3: A stand-in adjudicator in the documented shape

**As a** developer building order entry and reveal before 0.2.0
**I want** `RulesEngine.adjudicate(position, orders)` to return a result shaped like the real one
**So that** I can build and test the flow now, and nothing changes for me when the real adjudicator arrives

**Acceptance criteria:**

- [ ] **AC-3.1** Given the starting position and England's move from London to the North Sea and Germany's move from Kiel to Holland When adjudicated Then both outcomes are `:succeeded`, the other 20 units get implied holds with `submitted` false and result `:held`, and `paradox` is false
- [ ] **AC-3.2** Given Russia's Warsaw to Galicia and Austria's Vienna to Galicia When adjudicated Then both outcomes are `:bounced`, no unit enters Galicia, and the next position lists `gal` in `standoffs`
- [ ] **AC-3.3** Given an order that fails `RulesEngine.check` (France ordering a hold for the unit in London) When adjudicated Then its outcome is `:void` with `submitted` true, and England's unit in London gets an implied hold
- [ ] **AC-3.4** Given a legal support or convoy order When adjudicated Then its outcome is `:given`, and it changes nothing about any other order
- [ ] **AC-3.5** Given a legal move into a province whose unit stays put (it holds, is void, supports, convoys, or its own move bounced) When adjudicated Then the move is `:bounced` and the province is not in `standoffs`
- [ ] **AC-3.6** Given a legal move into a province whose unit moves away successfully When adjudicated Then the move is `:succeeded`
- [ ] **AC-3.6a** Given two units that swap provinces, and three units that rotate through three provinces When adjudicated Then all the moves are `:succeeded`
- [ ] **AC-3.6b** Given a move into a province whose unit has a blocked move, behind which a second move waits (a chain of two moves behind a move that bounces) When adjudicated Then all three moves are `:bounced`
- [ ] **AC-3.6c** Given three units that move to one empty province When adjudicated Then all three are `:bounced` and the province is in `standoffs`
- [ ] **AC-3.6d** Given a fleet that moves into Spain's north coast, and a fleet that moves out of St Petersburg's south coast to a province with no coasts When adjudicated Then the first unit ends on that coast and the second ends with no coast
- [ ] **AC-3.6e** Given a legal move via convoy When adjudicated Then it is treated as a move to its `to` province under rule 4, with the unit ending there with no coast
- [ ] **AC-3.6f** Given a fixed set of seeded random picks, one legal order per unit chosen from `RulesEngine.legal_orders` for each unit of several positions (the starting position and positions with fleets at sea and split coasts), several hundred phases in all When each is adjudicated Then `adjudicate` never raises and the next position it returns equals `load_position` of its own `to_h`
- [ ] **AC-3.7** Given any adjudication When the result is read Then no outcome has `dislodged` true, `position.dislodged_units` is empty, the season, year and ownership are the same as before, and the phase is `:retreat`
- [ ] **AC-3.8** Given the outcomes of a result Then the submitted orders come first, in the order given, followed by the implied holds sorted by province, and every `result` is one of the nine documented symbols
- [ ] **AC-3.9** Given a position that isn't in the movement phase, or two orders from one power for units in the same province, or an argument that isn't a position or an array of orders When adjudicated Then `InvalidInput` is raised, as the gem's documented 0.2.0 interface does for the first two
- [ ] **AC-3.10** Given any result When `to_h` is called Then it has exactly the keys `format` (1), `outcomes`, `paradox` and `position`, with string keys and values all the way down. Each outcome hash has exactly `order`, `result`, `submitted` and `dislodged`, with no `format` of its own and with the nested order carrying its own `format`. The `position` hash is one that `RulesEngine.load_position` loads
- [ ] **AC-3.11** (Review check, not a spec.) Given the stand-in's source When it is read Then a comment at its head says that its outcomes are fake and lists its rules, and FR-3 below lists them exactly

### Story 4: Gem objects stored in JSON columns and loaded back

**As a** developer of the game and phase models
**I want** to declare a column as a position, an order, a check result or an adjudication result
**So that** any phase can be replayed from what was saved

**Acceptance criteria:**

- [ ] **AC-4.1** Given a record with a position attribute When it is saved and reloaded from the database Then the loaded position equals the original, for the starting position and for a position with a split-coast fleet
- [ ] **AC-4.2** Given records with an order attribute holding each of the six order types When saved and reloaded Then each loaded order equals the original and has its original class
- [ ] **AC-4.3** Given records with a check result attribute, legal and not legal When saved and reloaded Then each loaded result equals the original
- [ ] **AC-4.4** Given a record with an adjudication result attribute holding a stand-in result When saved and reloaded Then the loaded result equals the original
- [ ] **AC-4.5** Given a saved record When its raw column text is read Then it is the JSON text of the object's `to_h` and contains `"format":1`, so any reader of the database can see the version
- [ ] **AC-4.6** Given a column that is nil When loaded Then the attribute is nil, and saving a nil writes SQL NULL
- [ ] **AC-4.7** Given a record assigned a hash form (string keys) instead of an object When saved and reloaded Then the attribute is the equal object
- [ ] **AC-4.7a** Given a record assigned a symbol-keyed hash, a String, an Integer, or an object of another kind When it is assigned Then `InvalidInput` is raised at assignment
- [ ] **AC-4.8** Given a stored row whose JSON has an unknown `format` (for example 2) When the record is loaded and the attribute read Then `InvalidInput` is raised, nothing is rescued, and no empty or partial object is returned
- [ ] **AC-4.9** Given the same stored row When loaded through the model Then the error message contains the offending value, and the type neither rescues nor rewrites it
- [ ] **AC-4.9a** Given a stored row whose column text is not JSON When the attribute is read Then `JSON::ParserError` is raised, and a row holding JSON that is not an object (such as `[]`) raises `InvalidInput`
- [ ] **AC-4.9b** Given a stored row that won't load When the record is saved without touching that attribute Then the save does not re-read or alter the bad column
- [ ] **AC-4.10** Given the spec-only table When the suite has run Then the table is dropped after its examples, and `git status --porcelain web/db` is empty

### Story 5: The 0.2.0 upgrade changes one source file

**As a** developer doing #29
**I want** the stand-in and every gem call in one place
**So that** the upgrade replaces the stand-in with the real adjudicator in one app source file. The pull request also moves the pin and the lockfile, rewrites the stand-in's spec, drops the stand-in class names from the guard, and decides what to do with any stored stand-in rows (they hold fake outcomes in the real shape)

**Acceptance criteria:**

- [ ] **AC-5.1** Given the app's code When it is scanned for `StandInAdjudication` and `StandInOutcome` Then they appear only in `app/models/rules_engine.rb`
- [ ] **AC-5.2** Given `RulesEngine.adjudicate`, `load_adjudication` and the adjudication attribute type When read Then they hand back objects with the readers `outcomes`, `paradox` and `position` (and `order`, `result`, `submitted`, `dislodged` on each outcome), so callers that use only those readers need no change when the gem's own classes take over. (The stand-in only ever produces five of the nine result symbols, so a caller that matches on results must handle all nine)
- [ ] **AC-5.3** Given `web/AGENTS.md` When read Then it says that every gem call goes through `RulesEngine`

## Functional Requirements

### FR-1: Pin and switch

**Must:**
- Pin `trucebearer-adjudicator` to `adjudicator-v0.1.0` with `glob: "adjudicator/*.gemspec"` (the `github:` shorthand is allowed if it produces the same lock entry).
- When `ADJUDICATOR_PATH` is set to a non-empty value, declare it as a path source at that folder instead. When it is unset or empty, use the git tag.
- Commit a `Gemfile.lock` that installs frozen with the variable unset.
- Leave `.github/workflows/` untouched. The workflows already set the variable as Issue #19's comment describes.

**Must not:**
- Point the default at the local `../adjudicator` folder.
- Change `adjudicator/` or any root file.

### FR-2: The boundary object

`RulesEngine`, in `app/models/rules_engine.rb`, offers:

| Call | Returns |
|---|---|
| `starting_position` | the classic starting position |
| `check(position, order)` | a check result with `legal` and `reasons` |
| `legal_orders(position, unit)` | an array of orders, in the gem's documented order |
| `adjudicate(position, orders)` | an adjudication result (the stand-in until 0.2.0) |
| `load_position(value)`, `load_order(value)`, `load_check_result(value)`, `load_adjudication(value)` | the object of that kind. A gem object of the right kind (an adjudication, the stand-in's before 0.2.0) comes back as it is, nil comes back as nil, a string-keyed hash is rebuilt with the gem's `from_h`, and anything else raises `InvalidInput` naming the value |
| `InvalidInput` | the gem's error class, under the app's own constant |

**Must:**
- Be the only app file that requires the gem or names its constants. The gem is declared `require: false` in the Gemfile, and the boundary file requires it. Its `TA` alias is a private constant of `RulesEngine`.
- Pass the gem's own errors through unchanged. It adds no rescue and no new error class.
- Hand back the gem's immutable objects as they are, except for the adjudication result before 0.2.0 (FR-3).
- Offer no map queries and no unit constructor. A caller gets a unit from `position.units`.

**Must not:**
- Cache, memoize or mutate anything it returns.
- Add behavior that the gem's `docs/interface.md` doesn't document.

### FR-3: The stand-in adjudicator

The stand-in is a private part of `app/models/rules_engine.rb`. **Its outcomes are fake.** It answers in the documented shape, using only gem calls that 0.1.0 documents, and follows exactly these rules:

1. The position must be in the movement phase, and one power may not give two orders for units in the same province. Otherwise `InvalidInput` is raised.
2. Each submitted order is checked with `check`. An order that fails is `:void`.
3. A legal hold is `:held`. A legal support or convoy is `:given`. Supports and convoys have no other effect.
4. A legal move (`Move` or `MoveViaConvoy`) targets a province (the move's destination, or the via-convoy move's `to`). Its result is found like this:
   1. Every legal move starts as `:succeeded`.
   2. Every move whose target is also the target of another legal move becomes `:bounced`.
   3. Repeat until nothing changes: a move that is still `:succeeded` becomes `:bounced` when its target province holds a unit that is not making a move that is still `:succeeded`.
   Each step only turns moves into bounces, so it ends, and it has one answer. Moves that swap two units, or rotate three or more, succeed. A convoy chain is not looked at.
5. A unit stays when its order is a hold, a support, a convoy, is void, or is a move that is `:bounced`. A unit with no legal order from its owner gets an implied hold.
6. The outcome list is the submitted orders in the order given, then one implied hold per remaining unit, sorted by province, with `submitted` false. No outcome is ever dislodged. `paradox` is always false.
7. The next position keeps the season, year and ownership, has the phase `:retreat`, moves each unit whose move succeeded (an army keeps no coast, a fleet takes the destination's coast), has no dislodged units, and lists in `standoffs` every province that two or more legal moves targeted and that is empty afterward.
8. The result's `to_h` is the documented form, with `format` 1.

**Must not:**
- Count support, work out a convoy route, decide who is stronger, or dislodge any unit.
- Be shown to a player as a real result.

### FR-4: Attribute types

**Must:**
- Provide one ActiveRecord attribute type each for a position, an order, a check result and an adjudication result, in `app/models/`.
- Subclass `ActiveRecord::Type::Value`. `cast` is the boundary's loader for that kind, so assignment accepts an object, a string-keyed hash or nil, and raises `InvalidInput` for anything else (a String is not parsed on assignment).
- `serialize` returns nil for nil, else the JSON text of the loaded object's `to_h`. `deserialize` returns nil for nil, else parses the column text with `JSON.parse` and passes it to the loader, which is not the same method as `cast`.
- Leave `changed_in_place?` false: the objects are immutable, and a save must not re-read an untouched column.
- Let a loader's `InvalidInput`, and `JSON::ParserError` for text that is not JSON, reach the caller.
- Work on a JSON column (SQLite stores it as text).

**Must not:**
- Name or require any gem class. They call only the boundary object.
- Rescue, retry or repair a stored value, or fall back to an empty object.
- Store the map.

### FR-5: What the app does when stored data won't load

A stored value that the gem refuses (an unknown or missing `format`, or any other hash the gem rejects) is a data problem that needs a person. The type lets `InvalidInput` out at the moment the attribute is read. It does not guess, skip or blank it. Because attributes load lazily, anything that reads the bad attribute raises, including `inspect`, `attributes` and `as_json` on that record. In a request it ends as a server error with the gem's message in the log. Showing something kinder, and any migration of old stored data, belong to the screen that reads it and to the pull request that upgrades the pin, which can match on the new `format`.

### FR-6: Specs for the round trip

**Must:**
- Cover the boundary, the stand-in, the attribute types and the guard, test first.
- Prove the database round trip with a table that exists only during the specs, created in `spec/support/` and dropped after, with its own model class defined there.
- Build spec data (custom positions, the six order types, a legal convoy, a fleet in Spain's north coast) with `RulesEngine.load_position` and `load_order` from hand-written string-keyed hashes, so specs need no gem constants.
- Read only `web/Gemfile` text in the pin spec. The early-warning job's unfrozen install rewrites `Gemfile.lock` to a path source, so a spec that read the lockfile or the loaded gem's source would fail there.

### FR-7: The guard spec

**Must:**
- Scan every file, of any extension, under `app/`, `lib/`, `config/`, `db/` and `bin/`, plus `config.ru` and `Rakefile`, and fail on any match outside `app/models/rules_engine.rb` of:
  - `\bTrucebearer\s*(::|\.)` (the module, including `Trucebearer.const_get`);
  - `(?<![A-Za-z0-9_])TA(?![A-Za-z0-9_])` (the alias);
  - `require\s*\(?\s*["']trucebearer` (the gem);
  - `StandInAdjudication` or `StandInOutcome`.
- Say in its own comment that it is textual: building a constant name from pieces would pass it, so review still matters.

**Must not:**
- Flag the word "Trucebearer" in plain text, such as a page title.
- Scan `spec/` (specs use `RulesEngine::InvalidInput` and otherwise need no gem constants).

### FR-8: Documentation

**Must:**
- Add one line to `web/AGENTS.md`, under "The adjudicator gem", saying every gem call goes through `RulesEngine`.
- Ship this spec and its plan in the same pull request.

## Non-Functional Requirements

### Performance

- `RulesEngine.starting_position`, `check` and `legal_orders` cost what the gem costs. The stand-in does one pass over the orders plus a loop that ends in at most as many rounds as there are moves. No timing target is set, and no timing spec is written.

### Security

- The pinned source is the public repository over HTTPS. No credential, token or deploy key is added.
- Stored hash forms are parsed with `JSON.parse` and rebuilt by the gem's `from_h`, which validates them. Nothing is loaded with `Marshal` or `YAML`.
- `ADJUDICATOR_PATH` is read when Bundler loads the Gemfile and is never read at run time by the app. In production it is unset.

### Reliability

- The default install is frozen and reproducible: the lockfile pins the commit that the tag points at.
- A stored value that doesn't load stops at the read with the gem's error, so bad data is never silently replaced.

## Error Scenarios

| Scenario | Expected Behavior |
|----------|-------------------|
| `ADJUDICATOR_PATH` names a folder that doesn't exist or holds no gemspec | Bundler fails at `bundle install` with its own message. The app doesn't try to recover |
| `ADJUDICATOR_PATH` is set to an empty string | Treated as unset: the git tag is used |
| `RulesEngine.adjudicate` is given a retreat-phase position | `InvalidInput`, as in the gem's documented 0.2.0 interface |
| `RulesEngine.adjudicate` is given two orders from one power for the unit in one province | `InvalidInput` |
| A loader gets a hash with an unknown `format` | `InvalidInput`, with the gem's message |
| A loader gets a hash with a missing or unknown key | `InvalidInput`, with the gem's message |
| A stored column holds text that isn't JSON | `JSON::ParserError` from the read, not rescued |
| A stored column holds JSON that isn't an object | `InvalidInput` naming the value |
| `RulesEngine.adjudicate` gets something that isn't a position or an array of orders | `InvalidInput` |
| A loader gets a hash with symbol keys | `InvalidInput`, because the gem's `from_h` takes strings only |
| An attribute is assigned something that is neither a gem object of its kind, a string-keyed hash nor nil | `InvalidInput` naming the value |
| A stored row won't load | `InvalidInput` when the attribute is read; see FR-5 |
| A foreign power orders someone else's unit | That order is `:void`, and the owner's unit holds |

## Open Questions

None. The choices in D1 to D4 are the maintainer's to confirm at Gate A.

## Out of Scope (Future Considerations)

- Real adjudication, convoys and paradoxes (#29, then 0.3.0 work).
- The game, seat and phase tables, and how phases are linked to stored positions (#21, #22).
- A list-of-orders attribute type. A phase's orders can be stored as an array of order hashes, and the type for that arrives with the table that needs it.
- Showing a friendly page when stored data won't load.
- Upgrading the pin. Each upgrade is its own pull request after reading the gem's CHANGELOG.

## Verification

| Item | How it is checked |
|------|-------------------|
| AC-1.1 | A spec reads `web/Gemfile` as text only and checks the tag, glob and the `ADJUDICATOR_PATH` branch. It never reads the lockfile or the loaded gem, so it passes in the early-warning job too |
| AC-1.2 (manual and CI; needs the network) | `BUNDLE_FROZEN=true bundle install` in `web/` with `ADJUDICATOR_PATH` unset, then `git diff --exit-code Gemfile.lock` |
| AC-1.3, AC-1.4 (manual; the early-warning job repeats AC-1.3) | `ADJUDICATOR_PATH=../adjudicator BUNDLE_FROZEN=false bundle install && bundle exec rspec`, then the committed lockfile is restored with `git checkout Gemfile.lock` |
| AC-1.5 | Read `web/Dockerfile`: the build stage's package list holds `git` |
| AC-2.1 to AC-2.6, AC-5.2 | `spec/models/rules_engine_spec.rb` (the first spec written, red until the pin and the boundary exist) |
| AC-2.7 to AC-2.9, AC-2.8a, AC-5.1 | `spec/models/rules_engine_boundary_spec.rb`, the guard |
| AC-3.x | `spec/models/rules_engine_stand_in_spec.rb` |
| AC-4.x | `spec/models/stored_gem_objects_spec.rb` with a spec-only table |
| AC-3.11, AC-5.3 | Review: read the stand-in's head comment and `web/AGENTS.md` |
| CI | The `Web specs` job is green. The early-warning job is started by hand on the branch and runs the same specs against `ADJUDICATOR_PATH` |
| Scope | `git diff --name-only main...HEAD` lists only paths under `web/` |

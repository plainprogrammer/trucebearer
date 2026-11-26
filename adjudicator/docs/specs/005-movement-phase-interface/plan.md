# Implementation Plan: Public interface for movement phases

**Spec:** adjudicator/docs/specs/005-movement-phase-interface/spec.md (v4.2.0, Approved)
**Decisions:** none in `docs/adr/`. The recorded decisions are `docs/architecture.md`, plus the decision in #56: hash forms with `format` cover what the app stores, and the map and nested-only objects need none.
**Created:** 2026-11-25
**Revised:** 2026-11-25, after an independent plan review. Changes: a branch step, a naming-check allowlist, a full province table, renamed fields (`destination`, `dislodged_units`), self-contained phases and a ruleset question column.

## Context

Issue #5 asks for the written contract between the gem and the app, so the two sides can be built in parallel. The spec fixes *what* `adjudicator/docs/interface.md` must promise. This plan settles the rest:
- identifier spellings
- class, method and field names
- the exact rejection-reason and outcome symbols
- the shape of the hash form
- the `format` value
- the error class

It then writes four documents. The deliverable is documentation only, because the gem skeleton (#6) does not exist yet. So the "tests" for this pull request are an acceptance checklist and four mechanical checks. They are written before the documents and run again at the end. The Ruby examples in `interface.md` become RSpec cases in #9 to #15.

## Global Constraints

- **Read `spec.md` in full before starting any phase.** Where a phase cites an AC or FR, the spec's wording is what `interface.md` must promise.
- Change files in `adjudicator/` only. The pull request touches one side. The spec and plan ship in the same pull request.
- Never give anything a name that contains or echoes "Diplomacy" or "Dip".
- No copied rules text. Never paste text from the rulebook or the DATC into code, comments, tests, fixtures or docs. Explain in our own words, and cite section numbers from DATC v3.4.
- Additions go under "Added" in `CHANGELOG.md`. No interface-change Issue is needed.
- Use the Ruby standard library only; add no dependencies.
- Write `interface.md` as a promise, not a design essay. Each section names the release it arrives in.
- Commit messages are plain imperative sentences, matching the repository's history. Examples: "Document the classic map and identifiers".
- **Scratchpad.** "The scratchpad" means your session's scratchpad directory. Recreate `datc_overlap.py` and `pr-body.md` there from this plan if they are missing.
- **The DATC file.** Its path is `/Users/james/Downloads/Diplomacy Adjudicator Test Cases.html`. If it isn't there, ask James for it. Don't download another copy.

## Goal

Open one adjudicator pull request that:
- turns `interface.md` into the complete movement-phase contract;
- records the spec's DATC choices in `ruleset.md`;
- updates `AGENTS.md` and `CHANGELOG.md` to match.

---

## Interface decisions

These are the choices that `interface.md` must state exactly. In the examples, `TA = Trucebearer::Adjudicator`, `L = TA::Location` and `O = TA::Order`.

### Calls

| Call | Returns | Release | Spec |
|---|---|---|---|
| `TA::Map.classic` | `TA::Map` | 0.1.0 | FR-1 |
| `TA.check(position, order)` | `TA::CheckResult` | 0.1.0 | FR-4 |
| `TA.legal_orders(position, unit)` | `Array` of orders, in the AC-4.7 order | 0.1.0 | FR-5 |
| `TA.adjudicate(position, orders)` | `TA::Adjudication` | 0.2.0 | FR-6 |

### Map queries (FR-1)

The map and its records are query-only and have no hash form. Every list is sorted by identifier.

| Query | Returns |
|---|---|
| `Map#id` | `"classic"` |
| `Map#powers` | `Array<TA::Map::Power>`. Each power has `id` and `name` |
| `Map#provinces` | `Array<TA::Map::Province>`. Each province has:<br>• `id` and `name`<br>• `type`: `:inland`, `:coastal` or `:sea`<br>• `coasts`: `[]` unless the coast is split<br>• `supply_center`: boolean<br>• `home`: a power id, or nil |
| `Map#power(id)`, `Map#province(id)` | the record. An unknown id raises `TA::InvalidInput` |
| `Map#coasts(province_id)` | `Array<Symbol>` |
| `Map#adjacent?(unit_type, from, to)` | boolean. `from` and `to` are `Location`s. An army location with a coast, or a fleet on a split coast without one, raises `InvalidInput` |
| `Map#supply_centers` | `Array<Symbol>` (34) |
| `Map#home_centers(power_id)` | `Array<Symbol>` |
| `Map#starting_position` | `Position` |

### Identifiers (FR-2)

- In Ruby, an identifier is a lowercase `Symbol`. In the hash form it is the same text as a `String`. `new` accepts symbols only; `from_h` accepts strings only.
- **Map:** `"classic"`, a `String` in both Ruby and the hash form.
- **Powers:** `:austria`, `:england`, `:france`, `:germany`, `:italy`, `:russia`, `:turkey`.
- **Coasts:** `:ec`, `:nc` and `:sc`. The split-coast provinces are `bul` (`ec`, `sc`), `spa` (`nc`, `sc`) and `stp` (`nc`, `sc`).
- **Seasons:** `:spring`, `:fall`. **Phases:** `:movement`, `:retreat`, `:adjustment`. **Unit types:** `:army`, `:fleet`.
- **Provinces:** the 75 below. They are sorted by identifier, and this is the table `interface.md` carries. "SC" marks a supply center, and "Home" gives the power whose home center it is.

| id | Name | Type | SC | Home |
|---|---|---|---|---|
| adr | Adriatic Sea | sea | | |
| aeg | Aegean Sea | sea | | |
| alb | Albania | coastal | | |
| ank | Ankara | coastal | SC | turkey |
| apu | Apulia | coastal | | |
| arm | Armenia | coastal | | |
| bal | Baltic Sea | sea | | |
| bar | Barents Sea | sea | | |
| bel | Belgium | coastal | SC | |
| ber | Berlin | coastal | SC | germany |
| bla | Black Sea | sea | | |
| boh | Bohemia | inland | | |
| bot | Gulf of Bothnia | sea | | |
| bre | Brest | coastal | SC | france |
| bud | Budapest | inland | SC | austria |
| bul | Bulgaria | coastal | SC | |
| bur | Burgundy | inland | | |
| cly | Clyde | coastal | | |
| con | Constantinople | coastal | SC | turkey |
| den | Denmark | coastal | SC | |
| eas | Eastern Mediterranean | sea | | |
| edi | Edinburgh | coastal | SC | england |
| eng | English Channel | sea | | |
| fin | Finland | coastal | | |
| gal | Galicia | inland | | |
| gas | Gascony | coastal | | |
| gol | Gulf of Lyon | sea | | |
| gre | Greece | coastal | SC | |
| hel | Helgoland Bight | sea | | |
| hol | Holland | coastal | SC | |
| ion | Ionian Sea | sea | | |
| iri | Irish Sea | sea | | |
| kie | Kiel | coastal | SC | germany |
| lon | London | coastal | SC | england |
| lvn | Livonia | coastal | | |
| lvp | Liverpool | coastal | SC | england |
| mao | Mid-Atlantic Ocean | sea | | |
| mar | Marseilles | coastal | SC | france |
| mos | Moscow | inland | SC | russia |
| mun | Munich | inland | SC | germany |
| naf | North Africa | coastal | | |
| nao | North Atlantic Ocean | sea | | |
| nap | Naples | coastal | SC | italy |
| nth | North Sea | sea | | |
| nwg | Norwegian Sea | sea | | |
| nwy | Norway | coastal | SC | |
| par | Paris | inland | SC | france |
| pic | Picardy | coastal | | |
| pie | Piedmont | coastal | | |
| por | Portugal | coastal | SC | |
| pru | Prussia | coastal | | |
| rom | Rome | coastal | SC | italy |
| ruh | Ruhr | inland | | |
| rum | Rumania | coastal | SC | |
| ser | Serbia | inland | SC | |
| sev | Sevastopol | coastal | SC | russia |
| sil | Silesia | inland | | |
| ska | Skagerrak | sea | | |
| smy | Smyrna | coastal | SC | turkey |
| spa | Spain | coastal | SC | |
| stp | St Petersburg | coastal | SC | russia |
| swe | Sweden | coastal | SC | |
| syr | Syria | coastal | | |
| tri | Trieste | coastal | SC | austria |
| tun | Tunis | coastal | SC | |
| tus | Tuscany | coastal | | |
| tyr | Tyrolia | inland | | |
| tys | Tyrrhenian Sea | sea | | |
| ukr | Ukraine | inland | | |
| ven | Venice | coastal | SC | italy |
| vie | Vienna | inland | SC | austria |
| wal | Wales | coastal | | |
| war | Warsaw | inland | SC | russia |
| wes | Western Mediterranean | sea | | |
| yor | Yorkshire | coastal | | |

The expected totals are: 75 rows; 14 inland, 42 coastal and 19 sea; 34 supply centers; 22 home centers. Phase 1 checks these totals mechanically.

### Value objects (FR-3)

**Rules for every value object:**
- Each is a `Data` class.
- **`to_h`** returns string keys, recursively.
- **`from_h`** accepts exactly that shape, which is what `JSON.parse` returns:
  - an unknown or missing key raises `InvalidInput`;
  - so does a wrong `"type"` given to a specific order class.
- **Construction:**
  - validates against the classic map (AC-6.4);
  - freezes array and hash fields;
  - sorts list fields into canonical order (AC-2.5).
- **Canonical order:**
  - units and dislodged units by the unit's province;
  - standoffs by identifier;
  - ownership keys by province in `to_h`.
- **Hash equality** is already independent of order.
- **`format`** is the integer `1`, one value for the whole gem, carried by storable objects only.

| Class | Fields | `format` |
|---|---|---|
| `TA::Location` | `province`; `coast`, which defaults to nil and is set only for a fleet on a split coast | no |
| `TA::Unit` | `power`, `type`, `location` | no |
| `TA::DislodgedUnit` | `unit`, `attacker_from` (a province), `by_convoy` (boolean) | no |
| `TA::Position` | `map`, `season`, `year`, `phase`, `units`, `ownership` (a `Hash` from supply center to power; unowned centers are absent), `dislodged_units`, `standoffs` | yes |
| `TA::Order::Hold` | `power`, `at` | yes |
| `TA::Order::Move` | `power`, `at`, `destination` (a `Location`; the only location field in any order) | yes |
| `TA::Order::MoveViaConvoy` | `power`, `at`, `to` (a province) | yes |
| `TA::Order::SupportHold` | `power`, `at`, `target` (a province) | yes |
| `TA::Order::SupportMove` | `power`, `at`, `from`, `to` (provinces) | yes |
| `TA::Order::Convoy` | `power`, `at`, `from`, `to` (provinces) | yes |
| `TA::CheckResult` | `legal` (boolean), `reasons` (`Array<Symbol>`). `legal: true` with reasons, or `legal: false` without exactly one reason, is impossible and raises | yes |
| `TA::Outcome` | `order`, `result` (a `Symbol`), `submitted` (boolean), `dislodged` (boolean) | no (it only appears nested) |
| `TA::Adjudication` | `outcomes` (kept in the AC-5.2 order), `paradox` (boolean), `position` | yes |

- `TA::Order` is a module. `TA::Order.from_h` dispatches on `"type"`, which is one of:
  - `"hold"`
  - `"move"`
  - `"move_via_convoy"`
  - `"support_hold"`
  - `"support_move"`
  - `"convoy"`
- The province fields are `at`, `target`, `from` and `to`. A location hash in any of them is AC-6.1's case of a coast in a province field.
- After the rename, every `to` field is a province. Only `Move#destination` is a location.

### Errors (FR-7)

- There is one error class, `TA::InvalidInput < StandardError`, with no subclasses.
- Every message names the offending key or value. For example: `unknown province "xyz" in "at"`.

### Rejection reasons (FR-4, AC-3.2)

Checking returns the first condition that fails, in the order below.
- A condition with the same name under different order types uses the same symbol.
- `:no_such_unit` means the *ordered* unit isn't on the board.
- `:no_unit` means the province the order refers to has no suitable unit.
- A convoy's endpoint problems (the same origin and destination, or either one not coastal) are one condition in FR-4, so they get one symbol, `:bad_endpoints`.
- A support's "same origin and destination" is its own condition, `:same_province`.

| Order type | Reasons, in precedence order |
|---|---|
| every order, checked first | `:wrong_phase`, `:no_such_unit`, `:foreign_unit` |
| Hold | none further |
| Move | `:own_province`, `:not_reachable`, `:coast_not_allowed`, `:coast_required`, `:coast_unreachable` |
| MoveViaConvoy | `:not_army`, `:own_province`, `:not_adjacent`, `:no_convoy_route` |
| SupportHold | `:own_province`, `:no_unit`, `:not_reachable` |
| SupportMove | `:own_province`, `:same_province`, `:no_unit`, `:not_reachable`, `:move_impossible` |
| Convoy | `:not_fleet_at_sea`, `:bad_endpoints`, `:no_unit`, `:not_on_chain` |

### Outcomes (FR-6, AC-5.3)

There are nine symbols. A condition with the same name shares one symbol across order types.

| Order type | Outcomes, in precedence order |
|---|---|
| every order, checked first | `:void` |
| Hold | `:held` |
| Move, MoveViaConvoy | `:no_route`, `:bounced` (a bounce, a standoff or a lost head-to-head battle), `:succeeded` |
| SupportHold, SupportMove | `:unmatched`, `:cut`, `:given` |
| Convoy | `:unmatched`, `:disrupted`, `:given` |

### Legal-orders list order (AC-4.7)

1. the hold
2. moves, by destination province and then coast
3. moves via convoy, by destination
4. supports to hold, by target
5. supports to move, by origin and then destination
6. convoys, by origin and then destination

---

## Phase 0: Branch, checks and checklist first

**Implements:** verification for FR-1 to FR-9 | **Satisfies:** sets up the check for every AC
**Files:**
- committed: `adjudicator/docs/specs/005-movement-phase-interface/spec.md` and `plan.md`
- in the scratchpad: `datc_overlap.py` and `pr-body.md`

**Interfaces:**
- *Consumes:* nothing.
- *Produces:* the branch, the draft pull request (whose body is the checklist), and the four check commands that Phases 1 to 6 rerun.

Write down how "done" is judged before writing any document. The checks and the checklist stand in for the failing tests a code feature would have.

- [ ] Create the branch: `git switch -c adjudicator/5-movement-phase-interface`
- [ ] Write `<scratchpad>/datc_overlap.py`:
  ```python
  import html, re, sys
  def words(text):
      text = re.sub(r'<[^>]+>', ' ', text)
      text = html.unescape(text).lower().replace('’', "'").replace('‘', "'")
      return re.findall(r"[a-z0-9']+", text)
  def shingles(ws, n=8):
      return {' '.join(ws[i:i+n]) for i in range(len(ws) - n + 1)}
  datc = shingles(words(open(sys.argv[1], encoding='utf-8', errors='replace').read()))
  hits = 0
  for path in sys.argv[2:]:
      for s in sorted(shingles(words(open(path, encoding='utf-8').read())) & datc):
          print(f'{path}: {s}'); hits += 1
  print(f'{hits} overlapping 8-word runs'); sys.exit(1 if hits else 0)
  ```
- [ ] **Check A, DATC overlap.** Run:
  `python3 -I <scratchpad>/datc_overlap.py "/Users/james/Downloads/Diplomacy Adjudicator Test Cases.html" adjudicator/docs/specs/005-movement-phase-interface/spec.md adjudicator/docs/specs/005-movement-phase-interface/plan.md adjudicator/docs/ruleset.md`
  Expected: `0 overlapping 8-word runs`. If there are hits, reword them before going on. A hit in the spec needs a PATCH spec update.
- [ ] **Check B, naming.** List every line containing the forbidden three letters, in any case, then drop the three allowed contexts:
  - the DATC's title and file name;
  - the naming rule's own sentence;
  - this check command itself.

  Run:
  `grep -rniE 'dip' adjudicator/docs/interface.md adjudicator/docs/ruleset.md adjudicator/AGENTS.md adjudicator/CHANGELOG.md adjudicator/docs/specs/005-movement-phase-interface/ | grep -vE 'Diplomacy Adjudicator Test Cases|"Diplomacy" or "Dip"'`
  Expected: no output. Any line printed is a violation, whether a class, method, word or file name, and must be renamed.
- [ ] **Check C, headings.** Run:
  ```sh
  for h in "Releases" "Identifiers" "Map" "Value objects" "Checking an order" "Legal orders" "Adjudicating a movement phase" "Errors" "Retreats" "Adjustments" "Change rules"; do grep -qx "## $h" adjudicator/docs/interface.md || echo "missing: $h"; done
  ```
  Expected now: ten `missing:` lines (all except "Change rules"). Expected after Phase 4: no output.
- [ ] **Check D, provinces.** Run:
  ```sh
  python3 -I -c "
  import re,sys,collections
  rows=[r for r in open('adjudicator/docs/interface.md') if re.match(r'\| \`[a-z]{3}\` \|',r)]
  c=[ [x.strip() for x in r.strip().strip('|').split('|')] for r in rows]
  ids=[x[0] for x in c]; t=collections.Counter(x[2] for x in c)
  ok=len(ids)==75==len(set(ids)) and t=={'inland':14,'coastal':42,'sea':19} and sum(x[3]=='SC' for x in c)==34 and sum(bool(x[4]) for x in c)==22
  print(len(ids),dict(t),sum(x[3]=='SC' for x in c),sum(bool(x[4]) for x in c),'OK' if ok else 'FAIL'); sys.exit(0 if ok else 1)"
  ```
  Expected now: `0 {} 0 0 FAIL`. Expected after Phase 1: `75 {'inland': 14, 'coastal': 42, 'sea': 19} 34 22 OK`.
- [ ] Write `<scratchpad>/pr-body.md`, following `.github/pull_request_template.md`.
  - **Side:** tick `adjudicator/`.
  - **What and why:** `Closes #5`. Then a short summary, and a note that the hash-form rule follows the decision in #56.
  - **Checklist,** from the template:
    - "Tests were written first and pass": not applicable. Explain that this pull request only changes documents, and that Checks A to D and the acceptance checklist stand in for tests.
    - "No rulebook or DATC text…" and "No name contains…": tick these after Check A and Check B pass.
    - "Changed entry and Interface change Issue": not applicable. This pull request only adds to the interface; see #56 for the `docs/architecture.md` wording.
  - **Acceptance checklist,** one line per row below. Tick each line as its phase completes.
    ```
    - [ ] FR-1, AC-1.1–1.7   ## Map: call, id, powers, provinces, coasts, adjacency, centers, starting position
    - [ ] FR-2               ## Identifiers: case, Symbol vs String, powers, coasts, 75-province table (Check D)
    - [ ] FR-3, AC-2.1–2.5   ## Value objects: every class, fields, types, province/location fields, format, hash example, canonical order
    - [ ] AC-6.4             ## Value objects: impossible objects, one example each
    - [ ] FR-4, AC-3.1–3.14  ## Checking an order: definitions, reason table, one-reason rule, examples
    - [ ] FR-5, AC-4.1–4.7   ## Legal orders: agreement with check, empty cases, owner named, coasts, convoy forms, list order
    - [ ] FR-6, AC-5.1–5.9   ## Adjudicating a movement phase: outcomes, holds, flag, void, routing, paradox, next position, DATC scope
    - [ ] FR-7, AC-6.1–6.3, 6.5  ## Errors: class, raise list, four AC-6.1 example hashes, rules failures never raise
    - [ ] FR-8               ## Retreats, ## Adjustments: stubs naming #36, #37
    - [ ] FR-9               CHANGELOG Added; AGENTS.md wording; ruleset.md rows and departures
    - [ ] NFRs               every section names its release; Ruby example per section; Checks A–D clean
    ```
- [ ] Commit the spec and plan: "Add the spec and plan for the movement-phase interface"
- [ ] Push, and open a draft pull request with the body: `gh pr create --draft --title "Define the public interface for movement phases" --body-file <scratchpad>/pr-body.md`

---

## Phase 1: Front matter, identifiers and the map

**Implements:** FR-1, FR-2, Stability NFR | **Satisfies:** AC-1.1 to AC-1.7
**Files:** `adjudicator/docs/interface.md`
**Interfaces:**
- *Consumes:* the Calls, Map queries and Identifiers decisions above.
- *Produces:* the headings `## Releases`, `## Identifiers` and `## Map`, and the identifier conventions Phases 2 to 4 use.

Replace the "Shape" and "Sections to fill in" text, which contradicts `docs/architecture.md`.

- [ ] **Intro.** Keep the first paragraph. Add three things:
  - everything that crosses the boundary is an immutable value object with a hash form;
  - the abbreviations used in examples: `TA = Trucebearer::Adjudicator`, `L = TA::Location`, `O = TA::Order`;
  - a pointer to `## Change rules`.
- [ ] **`## Releases`:** a table mapping each section to its release:
  - 0.1.0: Identifiers, Map, Value objects, Checking an order, Legal orders, and the parts of Errors about construction and checking;
  - 0.2.0: Adjudicating a movement phase, and the parts of Errors about adjudication;
  - 0.3: Retreats and Adjustments.

  Add a sentence saying that any 0.x minor version may change the interface, and a patch version never does.
- [ ] **`## Identifiers`:** the Identifiers decisions above, including the full 75-row province table, copied exactly. Then run Check D; expect `OK`.
- [ ] **`## Map`:** one short subsection per query, plus the statement that the map and its records are query-only and have no hash form, and that positions name the map as `"classic"` (decided in #56). Examples:
  ```ruby
  map = TA::Map.classic
  map.id                                   # => "classic"
  map.powers.map(&:id)                     # => [:austria, :england, :france, :germany, :italy, :russia, :turkey]
  map.provinces.size                       # => 75
  map.province(:spa).coasts                # => [:nc, :sc]
  map.coasts(:par)                         # => []
  map.adjacent?(:fleet, L.new(province: :mao), L.new(province: :spa, coast: :nc))   # => true
  map.adjacent?(:fleet, L.new(province: :gol), L.new(province: :spa, coast: :nc))   # => false
  map.adjacent?(:army,  L.new(province: :par), L.new(province: :bur))               # => true
  map.supply_centers.size                  # => 34
  map.home_centers(:england)               # => [:edi, :lon, :lvp]
  start = map.starting_position
  [start.season, start.year, start.phase]  # => [:spring, 1901, :movement]
  start.units.size                         # => 22
  start.ownership.size                     # => 22 (the 12 other centers are unowned, so absent)
  ```
- [ ] Run Check B; expect no output.
- [ ] Tick the FR-1 and FR-2 lines in the pull-request body (`gh pr edit --body-file`).
- [ ] Commit: "Document the identifiers and the classic map"

---

## Phase 2: Value objects and their hash form

**Implements:** FR-3, and the construction half of FR-7 | **Satisfies:** AC-2.1 to AC-2.5, AC-6.4
**Files:** `adjudicator/docs/interface.md`
**Interfaces:**
- *Consumes:* the identifiers from Phase 1.
- *Produces:* `## Value objects`, which defines `Location`, `Unit`, `DislodgedUnit`, `Position`, the six `Order` classes, `CheckResult`, `Outcome` and `Adjudication`.

- [ ] **Opening rules** (from "Rules for every value object" above):
  - immutable `Data`;
  - `to_h` returns string keys, and `from_h` takes the same shape; unknown keys raise;
  - `new` takes symbols;
  - the JSON round trip returns an equal object (AC-2.1);
  - `format` is `1` on storable objects only (AC-2.2);
  - canonical order and frozen collections (AC-2.5);
  - validation against the classic map, through `new` and `from_h` alike.
- [ ] **One subsection per class** from the value-object table. Each gives:
  - its fields, with type and allowed values;
  - for each order field, whether it is a province field or a location field;
  - whether it carries `format`;
  - one hash example.

  The Position example, shortened to two units:
  ```ruby
  position.to_h
  # => {"format" => 1, "map" => "classic", "season" => "spring", "year" => 1901, "phase" => "movement",
  #     "units" => [{"power" => "austria", "type" => "army", "location" => {"province" => "bud", "coast" => nil}},
  #                 {"power" => "russia", "type" => "fleet", "location" => {"province" => "stp", "coast" => "sc"}}],
  #     "ownership" => {"bud" => "austria", "stp" => "russia"},
  #     "dislodged_units" => [], "standoffs" => []}
  TA::Position.from_h(JSON.parse(JSON.generate(position.to_h))) == position   # => true
  ```
  Orders:
  ```ruby
  O::Move.new(power: :france, at: :mao, destination: L.new(province: :spa, coast: :nc)).to_h
  # => {"format" => 1, "type" => "move", "power" => "france", "at" => "mao", "destination" => {"province" => "spa", "coast" => "nc"}}
  O::SupportMove.new(power: :france, at: :por, from: :mao, to: :spa).to_h
  # => {"format" => 1, "type" => "support_move", "power" => "france", "at" => "por", "from" => "mao", "to" => "spa"}
  O.from_h({"format" => 1, "type" => "hold", "power" => "england", "at" => "lon"})
  # => #<data Trucebearer::Adjudicator::Order::Hold power=:england, at=:lon>
  ```
  Canonical order (AC-2.5): two positions built with their units in opposite orders are `==`, and their `to_h` output is identical.
- [ ] **Impossible objects (AC-6.4).** Each of these raises `InvalidInput`, with one Ruby example each:
  - two units on the board in one province (dislodged units don't count)
  - a fleet inland, or an army at sea
  - an army with a coast
  - a fleet on `bul`, `spa` or `stp` without a coast
  - a coast the province doesn't have, for example `L.new(province: :par, coast: :nc)`
  - an unknown identifier, or a map other than `"classic"`
  - ownership of a province that isn't a supply center
  - a movement-phase position with dislodged units or standoffs
  - a `CheckResult` whose `legal` and `reasons` disagree
- [ ] Run Check B; expect no output. Tick the FR-3 and AC-6.4 lines.
- [ ] Commit: "Document the value objects and their hash form"

---

## Phase 3: Checking an order and listing legal orders

**Implements:** FR-4, FR-5 | **Satisfies:** AC-3.1 to AC-3.14, AC-4.1 to AC-4.7
**Files:** `adjudicator/docs/interface.md`
**Interfaces:**
- *Consumes:* `Position`, `Unit`, the `Order` classes and `CheckResult` from Phase 2.
- *Produces:* `## Checking an order` and `## Legal orders`. Their reason symbols are cited in Phase 5.

- [ ] **`## Checking an order`** (0.1.0) covers:
  - the signature;
  - "judged from the position alone; other submitted orders are never consulted";
  - a supported or convoyed unit may belong to any power (AC-3.14);
  - at most one reason is returned, the first by precedence, though `reasons` stays a list.

  Then, in our own words, the spec's definitions:
  - **can reach:** adjacency for the unit's type, from its current location, including a fleet's coast, to at least one coast of the province;
  - **convoy chain:** distinct sea provinces holding fleets of any power, linking two different coastal provinces, ignoring coasts at the ends;
  - **minimal convoy chain:** one from which no set of fleets can be removed with a chain still remaining.

  Then the rejection-reason table above, with a one-line meaning and a DATC citation for each symbol:
  - `:coast_required` cites 4.B.2 and test 6.B.2 (a departure)
  - `:coast_unreachable` cites 4.B.3 and 6.B.3
  - `:coast_not_allowed` cites 4.B.6 and 6.B.12 (a departure)
  - `:own_province` cites 6.A.4, 6.A.5, 6.A.8 and 6.D.34
  - `:not_reachable` cites 6.A.1, 6.A.7 and 6.A.10
  - `:not_adjacent` cites 4.A.3
  - `:not_on_chain` cites 6.G.19
  - `:move_impossible` cites 6.D.31
  - `:foreign_unit` cites 6.A.6

  Examples:
  ```ruby
  start = TA::Map.classic.starting_position
  TA.check(start, O::Hold.new(power: :england, at: :lon))
  # => #<data Trucebearer::Adjudicator::CheckResult legal=true, reasons=[]>
  TA.check(start, O::Hold.new(power: :france, at: :lon))
  # => #<data Trucebearer::Adjudicator::CheckResult legal=false, reasons=[:foreign_unit]>
  TA.check(start, O::Move.new(power: :england, at: :lon, destination: L.new(province: :bel)))
  # => #<data Trucebearer::Adjudicator::CheckResult legal=false, reasons=[:not_reachable]>   # London holds a fleet, which can't reach Belgium
  TA.check(start, O::Move.new(power: :russia, at: :sev, destination: L.new(province: :rum)))
  # => #<data Trucebearer::Adjudicator::CheckResult legal=true, reasons=[]>
  ```
- [ ] **`## Legal orders`** (0.1.0) covers:
  - the signature;
  - the two-way promise with `check`: every listed order passes it, and every order that passes it is listed;
  - "depends only on the position";
  - every listed order names the unit's owner as its power (AC-4.1);
  - supports for moves nobody is ordering are included (AC-4.3);
  - one move per reachable coast, and none without a coast (AC-4.4);
  - an empty list outside a movement phase, or for a unit not on the board, meaning no unit with the same power, type and location (AC-4.5);
  - for an army with a convoy chain: a plain move only for a non-adjacent destination, and both forms for an adjacent one (AC-4.6);
  - the list order above (AC-4.7).

  Example:
  ```ruby
  fleet = TA::Unit.new(power: :england, type: :fleet, location: L.new(province: :lon))
  TA.legal_orders(start, fleet).first(3)
  # => [O::Hold.new(power: :england, at: :lon),
  #     O::Move.new(power: :england, at: :lon, destination: L.new(province: :eng)),
  #     O::Move.new(power: :england, at: :lon, destination: L.new(province: :nth))]
  ```
- [ ] Run Check B; expect no output. Tick the FR-4 and FR-5 lines.
- [ ] Commit: "Document order checking and legal orders"

---

## Phase 4: Adjudication, errors and the 0.3 stubs

**Implements:** FR-6, FR-7, FR-8 | **Satisfies:** AC-5.1 to AC-5.9, AC-6.1 to AC-6.3, AC-6.5
**Files:** `adjudicator/docs/interface.md`
**Interfaces:**
- *Consumes:* `Outcome`, `Adjudication` and `Position` from Phase 2, and the definitions from Phase 3.
- *Produces:* `## Adjudicating a movement phase`, `## Errors`, `## Retreats` and `## Adjustments`, and keeps `## Change rules`. The outcome symbols are cited in Phase 5.

- [ ] **`## Adjudicating a movement phase`** (0.2.0) covers:
  - **The call and errors:** the signature. It raises `InvalidInput` for a position that isn't in the movement phase (AC-6.3), and when one power gives two orders for units in the same province, identical or not (AC-6.2).
  - **Outcome list (AC-5.1, AC-5.2):** one outcome per submitted order, in the order given. Then one implied hold, with `submitted: false`, for each unit whose owner gave no legal order, sorted by province.
  - **Definitions,** in our own words:
    - **matching:** the same origin and destination provinces, ignoring coasts and whether the move is plain or via convoy; a support to hold matches a unit that doesn't move;
    - **moves:** the order the unit follows is a move or a move via convoy;
    - **working convoy route:** a chain where every fleet gives a legal, matching convoy order and none is dislodged; one route is enough (4.A.1);
    - **convoy paradox:** a convoying fleet's dislodgement depends on the army it convoys, leaving zero or several consistent results (4.A.2); circular movement is not one.
  - **Outcomes (AC-5.3):** the outcome table above, applied in precedence order. Add:
    - `:cut` includes a supporter that was dislodged (6.D.17);
    - a support's or a convoy's result never depends on whether the supported or convoyed move succeeded;
    - `:disrupted` marks only the dislodged fleet, and may widen in 0.3.
  - **Dislodged flag (AC-5.4):** set only on the outcome of the order the unit actually followed. Void orders always have it clear.
  - **Void orders (AC-5.6):** an order that fails checking, a foreign order and an order for a missing unit are all `:void`. The unit gets an implied hold, which can still receive support (4.E.1).
  - **Convoy routing (AC-5.7):**
    - a move to a non-adjacent province goes by convoy;
    - a move via convoy never falls back to land;
    - a plain move to an adjacent province goes by convoy when a same-power fleet gives a matching legal convoy, otherwise by land (6.G.1, 6.G.7, 6.G.19);
    - once a move goes by convoy, it never falls back (6.G.8, 6.G.11, 6.G.20);
    - the route may use any power's fleets (6.G.6).
  - **Paradox (AC-5.8):** the result is still returned and the flag is set. When the flag is set, every outcome and unit placement is unspecified until 0.3, but the next position is valid. The flag is clear for every required DATC case.
  - **Next position (AC-5.5):**
    - the same season and year, phase `:retreat`;
    - units that weren't dislodged, in their new places;
    - `dislodged_units`, each with `attacker_from` and `by_convoy` (4.A.5, 6.H.11, 6.H.12);
    - `standoffs`;
    - ownership unchanged.

    0.3 will replace this with the real next phase. Until then the app builds the next movement position itself.
  - **DATC scope (AC-5.9):**
    - DATC 6.A to 6.G give the DATC's preferred results. "Via convoy" in the DATC notation is encoded as `MoveViaConvoy`, and any other move as `Move`.
    - "Matches" means the same moves succeed and fail, the same units are dislodged, and the units end in the same places. Outcome labels may differ (4.E.2).
    - Excluded are:
      - the departures in `ruleset.md`;
      - 6.B.14;
      - the retreat step of 6.F.7;
      - the paradox cases pending #39: 6.F.14 to 6.F.18, 6.F.22 to 6.F.24, 6.F.26 to 6.F.28, and 6.G.11.

  Example:
  ```ruby
  orders = [O::Move.new(power: :england, at: :lon, destination: L.new(province: :nth)),
            O::Move.new(power: :germany, at: :kie, destination: L.new(province: :hol))]
  result = TA.adjudicate(start, orders)
  result.outcomes.first(2).map(&:result)   # => [:succeeded, :succeeded]
  result.outcomes.count { !_1.submitted }  # => 20   (implied holds for the other units)
  result.paradox                           # => false
  result.position.phase                    # => :retreat
  result.position.dislodged_units          # => []
  ```
- [ ] **`## Errors`** covers:
  - `TA::InvalidInput < StandardError`, the only error class; rescuing it catches every input error.
  - The full list of what raises:
    - a bad hash, or a missing or unknown `format`;
    - a coast in a province field;
    - an impossible value object (see `## Value objects`);
    - two orders from one power for the same unit;
    - adjudicating outside the movement phase.
  - Every message includes the offending key or value.
  - A plain sentence: a rules failure is never an exception (AC-6.5).
  - Example hashes for the four AC-6.1 cases:
  ```ruby
  O.from_h({"format" => 1, "type" => "hold", "power" => "england"})                            # missing "at"
  O.from_h({"format" => 1, "type" => "hold", "power" => "england", "at" => "xyz"})             # unknown identifier
  TA::Position.from_h(start.to_h.merge("year" => "1901"))                                      # wrong type
  O.from_h({"format" => 1, "type" => "hold", "power" => "england",
            "at" => {"province" => "spa", "coast" => "nc"}})                                   # coast in a province field
  # each raises TA::InvalidInput, for example: "at" must be a province identifier, got {"province" => "spa", "coast" => "nc"}
  ```
- [ ] **`## Retreats` and `## Adjustments`:** each says only "Coming in 0.3", naming #36 and #37 respectively.
- [ ] Keep `## Change rules` unchanged.
- [ ] Run Check B and Check C; expect no output from either. Tick the FR-6, FR-7 and FR-8 lines.
- [ ] Commit: "Document movement adjudication, errors and the 0.3 stubs"

---

## Phase 5: Ruleset, changelog and agent instructions

**Implements:** FR-9 | **Satisfies:** the FR-9 checklist line
**Files:** `adjudicator/docs/ruleset.md`, `adjudicator/CHANGELOG.md`, `adjudicator/AGENTS.md`
**Interfaces:**
- *Consumes:* the reason and outcome symbols from Phases 3 and 4.
- *Produces:* nothing that later phases need.

- [ ] **`ruleset.md`.** Add a line after the intro: "Citations refer to DATC v3.4." Then fill the existing four-column Choices table with these rows:

  | DATC section | Question, in our words | Option taken | Why |
  |---|---|---|---|
  | 4.A.1 | When does a convoy with several possible routes fail? | Only when every route is broken | The DATC's preferred option |
  | 4.A.3 | When does a move to a neighboring province go by sea? | When a fleet of the same power orders the convoy, or the move is tagged "via convoy". It never falls back to land. The tag is accepted only for neighboring destinations | Preferred; the tag restriction is our input-contract choice |
  | 4.A.4 | Where does an attack carried by sea count as coming from? | From the army's own starting province | Preferred |
  | 4.A.5 | May a unit dislodged by a sea-borne attack retreat to where the attacker started? | Yes. The result records `by_convoy` so the 0.3 retreat logic can allow it | Preferred |
  | 4.A.7 | Does a dislodged unit still contest the province its attacker left? | It stops contesting only if it lost a head-to-head battle | Preferred |
  | 4.B.2 | Is a fleet move to a split-coast province valid without a coast when only one coast can be reached? | No; the coast is always required | Strict, against the preference. Orders are picked from lists |
  | 4.B.3 | What if the named coast can't be reached? | The order is rejected | Preferred |
  | 4.B.4 | May a support name a coast? | No; supports name provinces only | Not one of the listed options. It is an input-contract choice |
  | 4.B.5 | What if an order gives the wrong coast for the ordered unit? | It can't happen, since the unit is named by province | Gives the preferred results |
  | 4.B.6 | What about a coast on an army move, or an unknown coast? | The army move is rejected. An unknown coast raises `InvalidInput` | Strict, against the preference |
  | 4.D.3 | What if one power gives the same unit two orders? | `InvalidInput` is raised | Not one of the listed options. The app keeps one order per unit |
  | 4.E.1 | What happens to an order that breaks the rules? | It is void, and the unit holds and can still be supported | Preferred |

  Then add a section, `## Departures from preferred results`:
  - **6.B.2:** the order is rejected, because 4.B.2 is taken strictly.
  - **6.B.12:** the order is rejected, because 4.B.6 is taken strictly.
  - **6.B.9:** can't be expressed, since supports carry no coast.
  - **Duplicate orders (4.D.3):** they raise. There is no chapter 6 test for this.
  - **Note:** 6.B.10 and 6.B.11 are encoded without the unit's coast and give the preferred results. 6.B.7, 6.B.8 and 6.B.15 to 6.B.17 give the preferred results under the province-only rule.
- [ ] **`CHANGELOG.md`.** Add under "Unreleased", in "Added":
  ```
  - `docs/interface.md` now defines the movement-phase interface. It covers the classic map and its queries; the value objects and their hash form (`format` 1); checking one order; listing a unit's legal orders; adjudicating a movement phase; and the `InvalidInput` error. Retreats and adjustments are placeholders until 0.3. (#5)
  - `docs/ruleset.md` records the DATC v3.4 options the interface relies on, and where it departs from the preferred results. (#5)
  ```
- [ ] **`AGENTS.md`.** Under "The boundary", replace this line:
  "- Inputs and outputs are plain data that can be stored and replayed. `docs/interface.md` is the contract with the app."
  with:
  "- What crosses the boundary is the gem's value objects: immutable `Data` classes with a documented hash form (`to_h` and `from_h`). Anything the app stores carries a `format` version, so any phase can be replayed. `docs/interface.md` is the contract with the app."
- [ ] Run Check A and Check B. Expect `0 overlapping 8-word runs`, and no output from Check B. Tick the FR-9 line.
- [ ] Commit: "Record the ruleset choices and update the changelog and agent notes"

---

## Phase 6: Integration verification

**Implements:** every FR | **Satisfies:** every AC, at the "verified in review of this pull request" level

- [ ] Check A, run over every changed file:
  `python3 -I <scratchpad>/datc_overlap.py "/Users/james/Downloads/Diplomacy Adjudicator Test Cases.html" adjudicator/docs/interface.md adjudicator/docs/ruleset.md adjudicator/CHANGELOG.md adjudicator/AGENTS.md adjudicator/docs/specs/005-movement-phase-interface/spec.md adjudicator/docs/specs/005-movement-phase-interface/plan.md`
  Expected: `0 overlapping 8-word runs`.
- [ ] Check B: no output. Check C: no output. Check D: `OK`.
- [ ] One-side check: `git diff --name-only main...HEAD`. Expected: only paths under `adjudicator/`.
- [ ] Walk the acceptance checklist in the pull-request body against `interface.md`. Every line must be ticked.
- [ ] Run `sdd-superpowers:sdd-review` (implementation mode) for spec alignment, and fix what it finds.
- [ ] Mark the pull request ready: `gh pr ready`. Then ask James to review. Issue #5's last "Done when" item is his approval.

---

## Quickstart Validation

1. `git switch adjudicator/5-movement-phase-interface`, then open `adjudicator/docs/interface.md`.
2. Read it top to bottom, the way an app agent would. You should be able to build the order picker, the stored JSON and the reveal screen without opening any gem code.
3. Pick three acceptance criteria at random, for example AC-3.13, AC-5.4 and AC-6.1. Find each one's promise and example by heading in under a minute.
4. Run Checks A to D. All four are clean.

## Pre-implementation gates

- **Simplicity:** four documents, no code and no dependencies. Pass.
- **Anti-abstraction:** one model, the `Data` classes, with one hash form. Pass.
- **Integration first:** the contract *is* the deliverable, and the checks and checklist come before it (Phase 0). Pass.

## Self-review

- **Coverage:** every FR maps to a phase: FR-1 and FR-2 to Phase 1, FR-3 to Phase 2, FR-4 and FR-5 to Phase 3, FR-6 to FR-8 to Phase 4, FR-9 to Phase 5. Every AC appears on a checklist line. AC-3.14, AC-4.1, AC-4.3, the paradox definition, the duplicate-order raise and the 0.3 replacement each have an explicit bullet.
- **Traceability:** every decision cites the FR or AC it settles. The two promises a reviewer flagged as going beyond the spec, the list order and the canonical order, are now spec v4.2.0 (AC-4.7, AC-2.5).
- **No placeholders:** every province, symbol, class, field and signature is named in this plan.

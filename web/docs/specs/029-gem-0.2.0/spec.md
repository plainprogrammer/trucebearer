# Feature 029: Upgrade to adjudicator-v0.2.0 and retire the stand-in

**Status:** Draft
**Version:** 0.1.0
**Created:** 2026-11-26
**Last Updated:** 2026-11-26
**Issue:** #29
**Branch:** `web/29-gem-0.2.0`

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 0.1.0 | 2026-11-26 | First draft, for Gate A |

## Problem Statement

Since spec 019 the app has answered `RulesEngine.adjudicate` with a stand-in whose outcomes are fake: it never counts a support, never dislodges a unit, never works out a convoy, and lets a swap succeed. Spec 025 made the results visible and, to stay honest, says so with a "Practice results" note above every results view. The gem's 0.2.0 release, tagged `adjudicator-v0.2.0`, adjudicates a movement phase for real (DATC 6.A to 6.G, minus the paradox cases waiting for #39). The playtest (milestone 1) needs real results, and the practice note would now be a lie in the other direction.

This feature moves the pin to the tag, answers `RulesEngine.adjudicate` and the adjudication loader with the gem, and removes the stand-in, `RulesEngine.stand_in?` and the practice note.

## Goals

- `Gemfile` and `Gemfile.lock` pin `adjudicator-v0.2.0`.
- Revealing a phase adjudicates it with `TA.adjudicate`, and the stored result is the gem's `TA::Adjudication` hash form, loaded back through `TA::Adjudication.from_h`.
- Nothing under `app/` (or `lib/`, `config/`, `db/`, `bin/`) names the stand-in any more, and a spec fails if anything does.
- The dislodged-unit banners and the paradox warning are shown to be right with real gem output, one spec each, from a real DATC position adjudicated through `RulesEngine`.
- The change stays in `app/models/rules_engine.rb` as far as it can. Every other file touched is listed in D6 with its reason.

## Non-Goals

- Retreats and adjustments (gem 0.3, #39 and later). `RulesEngine.next_movement_position` stays as the playtest's own rule (spec 022 D3).
- Any change to `PhaseResults`, the results helpers or the results controllers. They read only the documented hash form (spec 025 AC-7.2), so a real result should draw with no change. If a spec proves otherwise, this spec is amended and the reason recorded.
- A data migration (D5).
- Any change to `adjudicator/`, `.github/` or the root files.

## Users and Context

**Primary users:** The table at the playtest: a host who reveals and reads the results aloud, and players who read them on phones and move pieces by them. Until now those results were fake.
**Secondary users:** The next agent to upgrade the pin (the "app upgrades" step of `docs/repository-layout.md`).

## Decisions

**D1. `RulesEngine` is the change.** `adjudicate` calls `TA.adjudicate(position, orders)`. `load_adjudication` coerces with `TA::Adjudication` and `TA::Adjudication.from_h`, like the other three loaders. The stand-in's three constants and its module are deleted, with `RESULTS`, `OUTCOME_KEYS` and `ADJUDICATION_KEYS`, which only they used. `RulesObjectType.adjudication` needs no change: it already stores `object.to_h` as JSON and loads through `RulesEngine.load_adjudication`. `Phase#reveal!` needs no change: it passes the result to `update_all` and gives `result.position` to `next_movement_position`.

**D2. No test double.** The stand-in does not survive under `spec/`. The Issue allows a double "if specs need fast fixed outcomes". They do not. Run with the real engine in place of the stand-in, the whole suite (768 examples) fails in only seven examples: the stand-in's own spec and the pin spec. Every other spec, system specs included, passes unchanged, in the same minute as before. Fixed outcomes already come from `spec/support/results_fixtures.rb`, which builds results from hand-written hash forms and loads them through `RulesEngine.load_adjudication`. A fake engine kept for tests could drift from the real one and hide the very bugs this upgrade is for, and it would be one more moving part. The stand-in's own spec (`spec/models/rules_engine_stand_in_spec.rb`) is deleted with it; a smaller spec of the real wiring replaces it (Story 2).

**D3. The practice note and `stand_in?` go.** `RulesEngine.stand_in?`, the partial `results/_practice_note` and the line in `results/_section` that renders it are deleted, as spec 025 D6 said #29 would. The note has no stylesheet rule of its own (it used `text-muted`), so nothing is removed from the stylesheets. The style guide's results sample stops rendering the note. Nothing replaces it: real results need no disclaimer, and the paradox warning (spec 025 D6) stays as it is.

**D4. The paradox and dislodged displays are checked, not changed.** Spec 025 built both from hand-made hashes because the stand-in never produced either. This feature proves them on real output with two specs, each from a position in the DATC adjudicated through `RulesEngine` and revealed on a stored phase:

- Dislodged unit: DATC 6.D.9 (an Italian army in Venice moves into Trieste with support from Tyrolia, while Austria's army in Albania gives a support that matches no move and Austria's army in Trieste holds). The result has one dislodged unit, the Austrian army in Trieste. The host page's banner count equals the number of dislodged units in the stored position and equals the number of Dislodged tags (spec 025 AC-2.2), the held row carries the Dislodged tag and no Held tag, and the unmatched support reads "Not used".
- Paradox: DATC 6.F.14 (the simplest convoy paradox). The result has `paradox` true, the host page and the seat page show the one paradox warning, marked `data-paradox`, and the stored position is valid, so the reveal completes and opens the next phase. The outcome values are unspecified by the gem while the flag is set, so the spec asserts the flag, the warning and the next phase, and no outcome.

The positions are written as data (units and orders) with the section number cited. No DATC text is copied.

**D5. Stored stand-in rows.** The app has never been deployed (#30 comes later), so no production data holds a stand-in result. No migration is written. A development database that holds a revealed phase from before this change fails to load that row, because the stand-in's output may not pass the gem's `from_h` checks. `RulesObjectType` documents that such a row is repaired by hand, never by the model, and a development database may simply be reset (`bin/rails db:reset`). The upgrade pull request says so.

**D6. Files touched besides `app/models/rules_engine.rb`, each with its reason.**

| File | Reason |
|---|---|
| `Gemfile`, `Gemfile.lock` | The tag, with the lockfile regenerated by `bundle install`. |
| `app/views/results/_practice_note.html.erb` | Deleted (D3). |
| `app/views/results/_section.html.erb` | The one line that renders the note (D3). |
| `app/views/styleguide/show.html.erb` | The style guide's results sample renders the note (D3). |
| `AGENTS.md` (in `web/`) | Its "Until gem 0.2.0, `RulesEngine.adjudicate` is a stand-in" sentence is no longer true. |
| `docs/design-system.md` | The "Result group" row names the practice note among `results/_section`'s contents. |
| `docs/specs/019-adjudicator-boundary/spec.md`, `docs/specs/022-phase-lifecycle/spec.md`, `docs/specs/025-reveal-results/spec.md` | Changelog rows and version bumps recording what this feature changes in them (Story 5), as specs 024 and 025 did for their predecessors. |
| `spec/config/gemfile_pin_spec.rb` | The tag in its expected line. |
| `spec/models/rules_engine_boundary_spec.rb` | Its stand-in guard (spec 019 AC-5.1) becomes the guard of AC-3.1. |
| `spec/models/rules_engine_stand_in_spec.rb` | Deleted (D2). |
| `spec/docs/spec_amendments_spec.rb` | One example per amended spec, as for specs 024 and 025. |
| `spec/requests/results_spec.rb`, `spec/views/results_partials_spec.rb`, `spec/requests/styleguide_spec.rb`, `spec/system/reveal_results_spec.rb` | Their practice-note assertions (spec 025 AC-7.1, AC-8.1, AC-8.4) become assertions that the note is gone. |
| `spec/models/rules_engine_next_phase_spec.rb`, `spec/requests/order_secrecy_spec.rb` | Example names and comments that say "stand-in" (no assertion changes). |
| `spec/support/results_fixtures.rb` | One helper that reveals a phase from a position and orders through `RulesEngine` (D4). |
| New specs | Listed in the traceability table. |

The stale comment Issue #29's comment names ("two cases only" in the stand-in's error wording) disappears with the stand-in. The real error wording is the gem's, and no app spec asserts it beyond the exception class.

**D7. The early-warning job.** It runs the app's specs against the gem's code from the same checkout. After this upgrade the checkout and the pinned tag adjudicate alike, so the job should pass. It is started by hand on this branch (`gh workflow run early-warning.yml --ref web/29-gem-0.2.0`) and its run is linked in the pull request. It never blocks a merge.

**D8. Parallel work.** #27 (the position editor) may add a position-validation helper to `rules_engine.rb`, and #105 touches the channel code. The edits here to `rules_engine.rb` are one contiguous deletion (the stand-in, from its header comment to its `private_constant`) and two changed lines in `class << self`, plus the removal of `stand_in?`. When told that `main` moved, merge it and keep both sides.

## User Stories and Acceptance Criteria

### Story 1: The app uses the released gem

**As a** maintainer **I want** the pin on the 0.2.0 tag **So that** the app runs what was released

- [ ] **AC-1.1** Given `Gemfile` When read Then the tag is `adjudicator-v0.2.0` in the pinned branch, and the `ADJUDICATOR_PATH` branch is unchanged (`spec/config/gemfile_pin_spec.rb`).
- [ ] **AC-1.2** Given `Gemfile.lock` When `BUNDLE_FROZEN=true bundle install` runs Then it succeeds and resolves `trucebearer-adjudicator (0.2.0)` (a proof command, not a spec).

### Story 2: Revealing a phase adjudicates it for real

**As a** player **I want** the reveal to apply the rules **So that** I can move my pieces by the result

- [ ] **AC-2.1** (the first test written) Given a phase in which Germany moves Munich to Burgundy with support from Ruhr, and France's army in Burgundy holds When the host reveals Then the stored result has France's hold with `result` "held" and `dislodged` true, Germany's move with `result` "succeeded" and Germany's support with `result` "given"; the stored position's `dislodged_units` holds France's army in Burgundy with `attacker_from` "mun"; and the next phase's position has Germany's army in Burgundy and no unit of France there. It fails against the stand-in, which never dislodges.
- [ ] **AC-2.2** Given any revealed phase When it is reloaded from the database Then its adjudication equals the one the reveal stored, and its stored text is the JSON of the gem's documented hash form with `format` 1 (the existing storage specs, run against the real engine).
- [ ] **AC-2.3** Given `RulesEngine.load_adjudication` When given an adjudication, a string-keyed hash or nil Then it returns the object, the object built with `from_h`, or nil; and When given a hash the gem refuses (a wrong or missing `format`, a missing or unknown key, a result a hash form cannot have, or an impossible object such as a dislodged void order) or a value that is neither a hash nor an adjudication Then it raises `RulesEngine::InvalidInput`.
- [ ] **AC-2.4** Given a position that is not in the movement phase, a position or orders of the wrong class, or one power giving two orders for one province When `RulesEngine.adjudicate` runs Then it raises `RulesEngine::InvalidInput`, and a reveal that hits it changes nothing (spec 022's rollback behavior, unchanged and covered by its existing specs).
- [ ] **AC-2.5** Given two armies ordered to swap places with no convoy When adjudicated Then both moves bounce (the stand-in let both succeed), and a support that is cut or unmatched is reported as such.

### Story 3: The stand-in is gone from the production path

**As a** maintainer **I want** no trace of the fake engine in the app **So that** nobody can call it by mistake

- [ ] **AC-3.1** Given every file under `app/`, `lib/`, `config/`, `db/` and `bin/` When scanned for `StandIn`, `stand_in` and `practice-note` or `practice_note` Then none matches, `rules_engine.rb` included (`spec/models/rules_engine_boundary_spec.rb`, replacing spec 019 AC-5.1).
- [ ] **AC-3.2** Given `RulesEngine` When asked `respond_to?(:stand_in?)` Then it answers false.
- [ ] **AC-3.3** Given a revealed phase When the seat page, the host page and both results pages are fetched Then none contains a `.practice-note` or the words "Practice results" (replacing spec 025 AC-7.1).
- [ ] **AC-3.4** Given `/styleguide` When fetched Then its results section has no practice note (replacing the note's part of spec 025 AC-8.1).
- [ ] **AC-3.5** Given the repository When `rules_engine_stand_in_spec.rb` is looked for Then it is gone, and no file under `spec/` defines a stand-in or a double of `RulesEngine.adjudicate` that returns a made-up result. (Spec files may still stub `RulesEngine` for error paths.)

### Story 4: Real results show correctly

**As a** host **I want** the warnings to match what the engine found **So that** I settle by hand exactly the units that need it

- [ ] **AC-4.1** Given the DATC 6.D.9 position adjudicated through `RulesEngine` and stored on a revealed phase When the host page and a seat page are fetched Then the host page has one `data-dislodged` banner, for Austria's army in TRI; the banner count equals the stored dislodged units and the Dislodged tag count; the dislodged row has no Held tag; and the unmatched support reads "Not used".
- [ ] **AC-4.2** Given the DATC 6.F.14 position adjudicated through `RulesEngine` and revealed on a stored phase When the host page and a seat page are fetched Then each has exactly one `data-paradox` warning, the reveal completed, and the next phase is open.
- [ ] **AC-4.3** Given any real result When `PhaseResults` reads it Then it needs no change: this feature edits neither `app/models/phase_results.rb` nor a results view other than D3's one line. If a spec in this feature shows that it does need one, this spec is amended with the reason before that code changes.

### Story 5: Earlier specs are brought up to date

**As a** reader of specs 019, 022 and 025 **I want** them to say what changed **So that** no spec describes a stand-in that no longer exists

- [ ] **AC-5.1** Given spec 019 When read Then its version moves to the next minor and a changelog row says that Story 3 and FR-3 (the stand-in) and AC-5.1's stand-in half are retired by spec 029, that `adjudicate` and `load_adjudication` call the gem, and that the stand-in has no test double.
- [ ] **AC-5.2** Given spec 022 When read Then a changelog row says its Non-Goal and D-text that call adjudication a stand-in are read as the real engine, and that `next_movement_position` is unchanged.
- [ ] **AC-5.3** Given spec 025 When read Then a changelog row says D6's stand-in note, Story 7's AC-7.1, AC-8.1's and AC-8.4's note, and the Known limits entries that mention fake results are retired by spec 029, and that the paradox warning and every other behavior stand.
- [ ] **AC-5.4** Given those three specs When `spec/docs/spec_amendments_spec.rb` runs Then one example each checks the version line and the row, as for specs 024 and 025.

## Functional Requirements

### FR-1: The boundary

**Must:** `RulesEngine.adjudicate` returns the gem's `TA::Adjudication`; `RulesEngine.load_adjudication` builds one from its hash form; both raise `RulesEngine::InvalidInput` on what the gem refuses; no other file names a gem class (the existing guard still holds).
**Must not:** keep a second adjudicator, a flag that says which engine answers, or a rescue that turns a gem error into a result.

### FR-2: The results views

**Must:** draw a real result as they drew a stand-in's, from `phase.adjudication.to_h` only.
**Must not:** show any text that calls the results practice or made up.

## Non-Functional Requirements

- **Performance.** `TA.adjudicate` is a pure computation on a board of at most 34 units. The reveal's transaction and lock (spec 022 D8) are unchanged; the full suite runs in about the same time as before.
- **Compatibility.** The stored column's text keeps the gem's `format` 1. A future gem that changes the format fails loudly through `from_h`, as spec 019 FR-5 set.

## Error Scenarios

| Situation | Behavior |
|---|---|
| The gem refuses a reveal's input (`InvalidInput`) | Unchanged from spec 022: the transaction rolls back, nothing is revealed, the host sees the existing error page. |
| A development row holds a stand-in result the gem refuses | It raises `InvalidInput` on load. Repair by hand or reset the development database (D5). |
| The result has `paradox` true | The reveal completes, the next phase opens from the gem's valid position, and the results views carry the paradox warning (spec 025 D6). |

## Known limits

- While `paradox` is true the gem says every outcome and unit placement is unspecified until 0.3 (#39). The playtest's host settles such a phase by hand, as the warning says.
- The gem has no retreat or build phase until 0.3, so the host still settles retreats and builds with the position editor (#27).
- A convoy-disrupted fleet is shown "Convoy disrupted" and carries the Dislodged tag (spec 025 D6), which now happens for real.

## Open Questions

None. The test double is decided in D2 for Gate A.

## Traceability

| AC | Where it is checked |
|---|---|
| AC-1.1 | `spec/config/gemfile_pin_spec.rb` |
| AC-1.2 | `BUNDLE_FROZEN=true bundle install` |
| AC-2.1 | `spec/models/phase_reveal_real_engine_spec.rb` (written first) |
| AC-2.2 | `spec/models/stored_gem_objects_spec.rb` and `spec/models/phase_reveal_real_engine_spec.rb` |
| AC-2.3, AC-2.4, AC-2.5 | `spec/models/rules_engine_adjudicate_spec.rb` (replaces the stand-in's spec) |
| AC-3.1, AC-3.2, AC-3.5 | `spec/models/rules_engine_boundary_spec.rb` |
| AC-3.3 | `spec/requests/results_spec.rb` |
| AC-3.4 | `spec/requests/styleguide_spec.rb` |
| AC-4.1, AC-4.2 | `spec/requests/real_results_spec.rb` |
| AC-4.3 | The whole results suite, unchanged, and review |
| AC-5.1 to AC-5.4 | `spec/docs/spec_amendments_spec.rb` |

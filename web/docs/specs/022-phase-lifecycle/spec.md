# Feature 022: The phase lifecycle, open until the host reveals

**Status:** Approved
**Version:** 1.5.0
**Created:** 2026-11-26
**Last Updated:** 2026-11-26
**Issue:** #22
**Branch:** `web/22-phase-lifecycle`

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 1.5.0 | 2026-11-26 | Amended by spec 025 (reveal results to every phone, #25).<br>• AC-6.3 and FR-6 are read as: a `GET` of a revealed phase's orders URL, on a seat's own address, is a 303 to that phase's results page (spec 025 D5), so a phone that was looking at its orders when the host revealed lands on the results. A `PUT` keeps its 409 and its sentence (AC-6.1, AC-6.2), and a stepped-in URL keeps the 409 page.<br>• AC-7.9 ("no page shows an order or an outcome after a reveal") is replaced by spec 025 Story 5: after a reveal, every seat and the host read every power's orders and outcomes for the revealed phase; the open phase's orders stay secret (the AC-7.2 sweep is run again after a reveal); a stranger sees nothing.<br>• The FR-9 route table gains `GET /games/:id/phases/:n/results` (a seat) and `GET /games/:id/host/phases/:n/results` (the host), both the stranger response for a phase that is not revealed, and its rows for the seat page and the host page add the latest revealed phase's results. Each entry now says whether it can show a revealed phase's orders (`revealed:`). The seat page and the host page now always send `Cache-Control: no-store`.<br>• AC-5.4's banners are drawn by spec 025's results section, once each, for the latest revealed phase only.<br>• Every other criterion holds unchanged. |
| 1.4.0 | 2026-11-26 | Amended by spec 024 (live submission status, #24).<br>• AC-1.5 and the FR-9 table's rows for the seat page and the host page are read as: the seat page shows the seven powers and their submitted state (a `.seat-status` list), the seat's own count and the link to the orders page; the host page shows the same list in its host section. The seat's own single "Not submitted" line is replaced by its row of the list. The seat page names every power, but shows no order, no count and no link of any power but its own.<br>• AC-7.4 is read the same way: England's seat page shows England's own count, and the status list of the seven powers.<br>• AC-7.5 is read as: the per-seat fact the host can read before the reveal is which powers have submitted, which is the same set as the names of those that have not.<br>• AC-7.2's sanctioned difference is extended: when England's submitted state changes, the seat page and the host page may differ inside the status list, in England's row only, and nowhere else (spec 024 AC-3.5).<br>• The route table classifies the `/cable` mount as showing no order data (spec 024 AC-4.6), and its framework entry that said #24 must classify it is removed.<br>• "Out of Scope" for #24 is met. Every other criterion holds unchanged |
| 1.3.1 | 2026-11-26 | Amended by spec 026 (#26): the open question at the end of D9 is closed. A host who reissues a seat and opens the new link on a phone that holds the host cookie is sent to the step-in confirmation, which is recorded and announced to the seat's owner. FR-9's route table gains the six step-in routes, classified in `spec/support/secrecy_routes.rb` |
| 1.3.0 | 2026-11-26 | Amended by spec 023 (the order pickers, #23), which replaces the plain form this spec's Non-Goals named.<br>• D5 and FR-4 (the plain orders form) are replaced by spec 023's order screen and picker steps; the `PUT` endpoint, its partial-update meaning and every refusal are unchanged.<br>• AC-2.11 (a select for each unit) is replaced by spec 023 AC-1.1 to AC-1.9: a `.unit-row` for each unit.<br>• AC-2.1's "Orders saved." banner is replaced by `.save-status` reading "Saved" (spec 023 D4): a plain save sets no flash. The "Submitted." banner stays. The endpoint examples that read the old banner or flash, and the 422 example that counted selects, are rewritten.<br>• The "n of m units ordered" line leaves the orders page for the submit bar, and "Submitted" and "Not submitted" (AC-3.1, AC-3.2, AC-7.10) are read from the submit bar.<br>• Orders are worded with full province names and abbreviations (`OrderLabelHelper#order_words` replaces `order_label`).<br>• Turbo frames are not used: each step is a whole small page (spec 023 D5, the ruling on the Issue's "pages and frames").<br>• This spec's Non-Goal for #23 ("the order pickers") is met.<br>• The orders page and the new picker route (`GET .../orders/:province`) are classified in the route table (FR-9) as showing the seat's own orders only. The seat page and every other criterion hold unchanged |
| 1.2.1 | 2026-11-26 | Patch from the plan review: the `/cable` mount is an internal route entry (an empty verb), so the route table lists it; production logs at `info` by default because a debug-level SQL log writes bind values, a saved order's content included, and the model's own filter cannot hide those (FR-9). No behavior changes |
| 1.2.0 | 2026-11-26 | Approved at Gate A (two Fable review rounds), with these rulings.<br>• **Stylesheet caps raised.** The total goes from 24 KB (24,576 bytes) to 32 KB (32,768 bytes), and `styleguide.css` from 4 KB (4,096) to 6 KB (6,144). Reason: the screen components the design-system catalog plans (#22 to #28), which spec 020 sized its 24 KB for before they were listed. The limits are enforced by `spec/styles/stylesheet_rules_spec.rb`, which changes with them. Specs 020 and 021 carry a changelog row for the new numbers; no Issue.<br>• **Reissue** (D9) is approved. Spec 021 is amended in this pull request (its changelog has a row).<br>• A host who reissues a seat and then enters orders on it is acting as that seat, unrecorded. That is #26's ground (D9). This feature does not solve it.<br>• The Gate A note for #27 (D3, "Handed to later issues") is posted on #27 after this pull request merges, and the note on unrecorded acting is posted on #26 |
| 1.1.0 | 2026-11-26 | Changed after the first independent review.<br>• Reissuing a seat clears that seat's saved orders and submission for the open phase (D9, AC-7.10), because a reissue was a way for the host to read a seat's orders.<br>• D8 names the write lock as the arbiter and the conditional write as a backstop. The concurrency ACs are model-level specs with a forced interleaving.<br>• The orders table and model are `saved_orders` and `SavedOrder`, so the source scan has an unambiguous name. The scan, the route table (framework routes included) and the invariance sweep are defined exactly.<br>• Failure messages never carry an exception message. `.confirm` takes a danger variant. The seat page text changes (spec 021 AC-4.10). A stylesheet budget is stated. Smaller fixes to AC-2.x, 4.6, 4.10, 6.4 and 7.9 |
| 1.0.0 | 2026-11-26 | First draft |

## Problem Statement

The table's rhythm is: talk, enter orders, reveal, move pieces. Today the app has games and seats (spec 021) but no notion of a turn. A game has no current phase, a player has nowhere to save orders, the host has no way to end the turn, and nothing is adjudicated. The reveal must also be safe: no one may see anyone else's orders before it (the host included), a double tap or a second tab must never adjudicate twice, and an order saved after the reveal must be refused rather than lost or attached to the wrong turn.

## Goals

- Every game has a current phase (season, year, phase type) that is open, and a history of the phases already revealed.
- While a phase is open, each seat can save orders for its own power's units and mark itself submitted. Submitting never locks anything: editing afterwards puts the seat back to "not submitted".
- Only the host can reveal. A confirmation page names every power that hasn't submitted, with "their unordered units will hold".
- The reveal is one atomic step: lock, adjudicate through `RulesEngine`, store the outcomes, and open the next phase. Repeating it, doing it in two tabs, or doing it twice at once adjudicates once.
- An order saved after the reveal is refused with a clear message.
- Before the reveal, no response shows any seat's orders to anyone but that seat, the host included, and the database has no listing that joins all seats' orders before the reveal.
- The three components `.phase-header`, `.banner` and `.confirm` are built to the catalog in `web/docs/design-system.md` and added to `/styleguide`.
- Every screen is a normal page with its own URL.

## Non-Goals

- The order pickers (#23). This feature ships the plainest form that can exercise the saving endpoint (D5). #23 replaces the form and keeps the endpoint.
- Live status of who has submitted, shown to every phone (#24). No page in this feature shows one seat the submitted state of another. The host's confirmation page names the powers that haven't submitted, because the host needs it to decide.
- Showing results to every phone (#25). The results are stored, and the host sees a plain confirmation that the reveal happened.
- Stepping into another seat (#26) and the position editor (#27).
- Retreat phases, adjustment phases and any automatic change of supply-center ownership (D3).
- A phase clock, a shared display, undo of a reveal, reopening a revealed phase, deleting a phase.
- Any change to `adjudicator/`, `.github/` or the root files. The app stays pinned to gem 0.1.0, so adjudication is the stand-in of spec 019 (its outcomes are fake). #29 swaps in 0.2.0 and changes only `RulesEngine`.

## Users and Context

**Primary users:** A host who runs a game at a physical table, and up to six players, each on a phone, holding one seat each.
**Secondary users:** A player whose phone is slow or stale (a second tab, a page left open across a reveal). A stranger who has found the instance.
**Usage context:** Phones are about 360 pixels wide. The host's phone is often passed around, or shown. Players enter orders while talking, then the host says "reveal".
**User mental model:** "I write my orders and tap submit. I can still change them until the host reveals. When the host reveals, it's final."

## Decisions

Gate A asks about D2, D3, D4, D5, D6 and D9.

**D1. A phase is a row of a game, and the app never edits one.** A phase is created with its starting position and is open until it is revealed. The reveal writes the adjudication and a revealed time onto it, in the same step that creates the next phase. A phase never changes after that. The position column holds the gem's hash form through `RulesObjectType.position`, and season, year and phase type are read from it (one source, so they cannot drift).

**D2. Table design: `phases`, `saved_orders`, `submissions`.** Three tables, each keyed so the database itself refuses the states the rules forbid.

| Table | Columns | Keys and checks |
|---|---|---|
| `phases` | `game_id`, `number` (1, 2, 3 ... within the game), `position` (position, not null), `adjudication` (adjudication, null until revealed), `revealed_at` (null until revealed) | Unique `[game_id, number]`. Unique `[game_id]` where `revealed_at IS NULL`, so a game has at most one open phase. Check: `revealed_at` is null exactly when `adjudication` is null, so a half-stored reveal cannot be written |
| `saved_orders` (model `SavedOrder`) | `phase_id`, `seat_id`, `province` (the ordered unit's province), `content` (order, not null) | Unique `[phase_id, seat_id, province]`: one order per unit. Both ids are foreign keys |
| `submissions` | `phase_id`, `seat_id`, `created_at` | Unique `[phase_id, seat_id]`. A row means "submitted"; no row means "not submitted". Both ids are foreign keys |

`Seat` exposes the saved orders to everything else through methods with other names: read its own orders for a phase, save a set of them, clear them. The orders controller and view use only those, and the reissue (D9) is done by `Seat` (`Game#reissue_seat!` calls it), in the same transaction as the new token and under the phase lock of D8. A saved order belongs to its seat and its phase. The name `SavedOrder` is chosen so a source scan can match it without also matching the gem's order classes, `.order(...)` or the word in view text. `Phase` has no association that returns every seat's saved orders, and `has_many :saved_orders` exists on `Seat` only (FR-9). Be plain about what that buys: `SavedOrder.where(phase_id: ...)` is still a one-line query, so the protection is the missing association, the scan (AC-7.8) and review. The alternative of one `phases` row per seat or a JSON column of all orders on the phase was left out: either would make a listing of all orders a one-line query. A `submitted` flag column on `seats` was left out because it would need resetting at every reveal.

**D3. What follows a reveal: the next movement phase, straight away.** The options were:
- **A (chosen).** The game moves at once to the next movement phase, open, with a position the app builds itself. Retreat and adjustment phases are not built (the Issue forbids it, and the playtest has the host make retreats and builds by hand in the position editor, `docs/architecture.md` "Targets").
- **B.** The game enters a holding state with no open phase until the host presses "start next phase". It would give the host a moment to fix the position before players order. It was left out because it adds a state, a page and a rule ("a phase stays open until the host reveals" would need a second clause), for a problem #27 can solve itself (see "Handed to later issues").
- **C.** Create retreat phases as real rows and wait for #27. Left out: it builds a phase kind the Issue rules out.

*What happens to dislodged units until #27 exists:* they are taken off the board in the next position, and they stay in the position stored on the revealed phase's adjudication. The host's page names them ("Dislodged: ...") with a note that the host settles them by hand. With the stand-in nobody is ever dislodged (spec 019); the rule matters from #29 on, and is tested now with a hand-built result.

*How the season and year advance:* the next phase after spring of a year is fall of the same year. The next phase after fall of a year is spring of the following year. Ownership of supply centers is left as it was: the host corrects it by hand in #27, as the playtest has it for builds. Standoffs are cleared and the phase type is movement.

The next position is built by `RulesEngine.next_movement_position` from the position in the adjudication. It lives in `RulesEngine`, so the gem stays behind its one door. It is not part of the stand-in: it is the app's own playtest rule, and it stays until 1.0 uses what gem 0.3.0 works out.

**D4. A saved order is checked when it is saved, and checked again at the reveal.** The options were: (a) check when saving and refuse an illegal order; (b) store anything well formed and let the adjudication void what is illegal; (c) both. (c) is chosen. Checking one order looks at the position alone, never at other orders (`interface.md`, "Checking an order"), and an open phase's position never changes, so an order that passes when saved will pass at the reveal. Refusing at save time therefore costs nothing and tells the player at once. The adjudication still checks every order it receives and voids an illegal one, and that is not dead code: the app can be upgraded to a gem whose rules differ while a phase is open (#29), and #27 can edit a position, so a stored order can become illegal after it was saved. The two fit like this: the stored orders are legal when saved; the contract's voiding is the backstop for anything that stopped being legal since.

On top of the check, the app refuses what the check cannot know: the order's `power` must be the seat's own power (a check passes for another power's order that names the right owner), the order must be for a unit of that power, and the key it was posted under must match the order's own province.

**D5. The plain form (what #23 replaces).** *Replaced by spec 023 (changelog 1.3.0).* One page per open phase, `/games/:public_id/phases/:number/orders`. For each unit the seat holds, one row with the unit's icon, a label naming the type and province, and a single `<select>`. Its first choice is "No order (holds)", with a blank value. The other choices are the unit's legal orders from `RulesEngine.legal_orders`, one per choice, in plain words with provinces by abbreviation ("Hold", "Move to BEL", "Move to SPA (north coast)", "Move to BEL by convoy", "Support hold in BER", "Support BUR to MUN", "Convoy LON to NWY"). The value of a choice is the order's hash form as JSON, so the server always re-checks. The page has two buttons: "Save orders" and "Save and submit". There is no picker, no step, no draft and no per-unit page. #23 replaces the page and keeps the endpoint: its `orders` parameter is a partial update, so a picker can save one unit at a time, and `submit` can be sent with no orders to submit alone.

**D6. Secrecy is enforced by structure, and proved by a sweep.** Three checks, so the list of places orders could leak is shown to be complete and not only believed to be (FR-9): a route table the specs force to be classified (a new route fails the suite until someone classifies it), an invariance sweep (every readable page, for every kind of viewer, is the same before and after a seat changes its orders), and a source scan that limits which files may name the saved-orders model and table.

**D7. The reveal is pinned to the phase the host saw.** Every reveal and order URL carries the phase number. A "reveal" that carried no number would, after a double tap, reveal the next phase and not the one the host was looking at. A number that is no longer the open one is never acted on (FR-7, FR-6).

**D8. The write lock is the arbiter; the conditional write is a backstop.** SQLite has no row locks: `lock!` adds nothing to the query there. What serializes two reveals, and a save against a reveal, is the transaction: Rails 8.1's SQLite adapter starts every write transaction in immediate mode, so a second writer waits (up to the connection's 5-second timeout) until the first commits. So every reveal and every save runs in a transaction, and its first statement is `phase.lock!` (a reload with a lock: a real row lock on a database that has them, and a fresh read of the phase on SQLite, past the request's query cache). It then re-reads whether the phase is still open. Whoever gets the lock second sees the phase revealed and stops. The reveal also writes the revealed time with a conditional write (only where it is still null) and raises, rolling everything back, if not exactly one row changed. That is a backstop: it can only fire if the lock failed, so it is loud (a 500, AC-4.10), and it turns a broken lock into a failure and never into a second stored result. A spec asserts the adapter's default mode (it reads the configuration, since an example inside a fixture transaction issues no `BEGIN` of its own).

**D9. Reissuing a seat clears its saved orders.** Spec 021 lets the host reissue a seat and open the new seat link on the host's own phone. Without this decision that is a way for the host to read any seat's saved orders: the reissue, the link, then the orders page. It is not the step-in that `docs/architecture.md` describes (confirmed, recorded, the owner told). So a reissue, in the same transaction that replaces the token, deletes that seat's saved orders and its submission for the open phase. The cost is that a player whose phone died enters their orders again. Revealed phases are untouched. The confirmation page says so. Left out: keeping the orders (leaves the hole open until #26) and recording and announcing it (that is #26). What remains open is plain: a host who reissues a seat and then enters orders on it is acting as that seat, unrecorded and unannounced. That is the step-in of #26, which must record and announce it; this feature does not solve it.

## URLs

All under `/games/:public_id`, `format: false`, as in spec 021. The existing routes are unchanged.

| Method and path | Who | What |
|---|---|---|
| `GET /` (the seat page) | seat | Existing page, now with the phase header, the seat's own state and a link to the orders page |
| `GET /host` | host | Existing page, now with the phase header, a "Reveal" button, the history and any dislodged units |
| `GET /phases/:number/orders` | seat | The plain orders form for an open phase. A revealed phase gives the refusal page (409) |
| `PUT /phases/:number/orders` | seat | Saves orders, optionally with `submit=1`. Parameters: `orders` (province to the order's JSON, or blank to clear), `submit` |
| `GET /host/phases/:number/reveal` | host | The confirmation page |
| `POST /host/phases/:number/reveal` | host | The reveal |

The number is matched strictly in the controller (digits only, no leading zero: `1` is a number, `01` and `1abc` are not), not by a route constraint. A number that names no phase of the game, a phase later than the open one, or is not a number, gives the stranger response (404).

## User Stories

### Story 1: A game has a current phase and a history

**As a** host or a player
**I want** the game to say which phase it is in
**So that** everyone at the table is ordering the same turn

**Acceptance criteria:**

- [ ] **AC-1.1** Given a game has just been created When its phases are read Then it has exactly one phase, number 1, whose position equals `RulesEngine.starting_position` (spring, 1901, movement), with no adjudication and no revealed time (so it is open), and `Game#current_phase` returns it
- [ ] **AC-1.2** Given a game was just created by the host (the first test, a request spec) When the host opens `/games/:public_id/host/phases/1/reveal` Then the response is 200, and the page names every power as not submitted: the host's own power, and each of the six other powers marked as having no seat ("no one has joined")
- [ ] **AC-1.3** Given a game with an open phase When another open phase is inserted for the same game, or a phase with a repeated number, or a phase with a revealed time and no adjudication (or the reverse) Then the database refuses it
- [ ] **AC-1.4** Given a game whose first phase was revealed When the history is read Then it lists the revealed phases oldest first, and `current_phase` is the open phase that follows
- [ ] **AC-1.5** Given a seated player When they open the seat page Then a `.phase-header` reads "Spring 1901 · Movement" (capitals are drawn by the stylesheet, not in the source text) with the player's power badge, and the page shows the seat's own state ("Not submitted") and a link to the orders page, and the text "Keep this page. The host reveals each phase when the table is ready." (this replaces "The host will start the game." of spec 021 AC-4.10, and that spec changes with it)
- [ ] **AC-1.6** Given the host When they open the host page before any reveal Then it shows the phase header, a "Reveal" button that leads to the confirmation page, and "No phase has been revealed yet"; after one reveal it lists "Spring 1901 · Movement" as revealed

### Story 2: A seat saves orders for its own units

**As a** player
**I want** to save an order for each of my units
**So that** my power's turn is ready when the host reveals

**Acceptance criteria:**

- [ ] **AC-2.1** Given England's seat and an open phase When it sends `PUT` with a legal order for each of its own units Then the response is a 303 redirect to the orders page, each order is stored once with that seat and that phase and the unit's province, and the page says "Orders saved"
- [ ] **AC-2.2** Given England's seat When it sends an order for a unit that belongs to another power Then the response is 422 with "You have no unit in XXX." (XXX the province, in capitals; the same sentence for a province where England has no unit at all), and no order of that request is stored (all or nothing)
- [ ] **AC-2.3** Given England's seat When it sends an order for one of England's own units, posted under that unit's province, whose `power` is another power Then the response is 422 with "That order isn't for your power." and nothing is stored
- [ ] **AC-2.4** Given England's seat When it sends an order that fails `RulesEngine.check` Then the response is 422 and a sentence in plain words gives the reason (each reason the gem reports has its own sentence, and any other reason gets "That order isn't legal."); nothing is stored
- [ ] **AC-2.5** Given England's seat When `orders` is not a hash, a value is not valid JSON, an order is malformed (the gem raises its invalid-input error), or the posted key is not a province of one of its units Then the response is 422 with "That order couldn't be read." (a key that is a province but not one of its units gets the sentence of AC-2.2), and nothing is stored
- [ ] **AC-2.6** Given England's seat When an order is posted under one of England's provinces but its own `at` names another Then the response is 422 with "That order couldn't be read." and nothing is stored
- [ ] **AC-2.7** Given a stored order for a unit When `PUT` sends a blank value for that unit's province Then the stored order is removed and the unit has no order (it will hold)
- [ ] **AC-2.8** Given a stored order for a unit When `PUT` sends a different legal order for it Then the unit still has exactly one stored order, the new one
- [ ] **AC-2.9** Given stored orders for two units When `PUT` names only one of them Then the other is unchanged
- [ ] **AC-2.10** Given a stored order When it is read back Then it equals the order that was saved, and the stored text is the order's hash form with its `format` (the `RulesObjectType` round trip)
- [ ] **AC-2.11** *(replaced by spec 023 AC-1.1 to AC-1.9)* Given England's seat When it opens the orders page of the open phase Then each of its units has one row with a select holding "No order (holds)" and its legal orders, the stored order is selected, and no unit of another power appears
- [ ] **AC-2.12** Given a phone with no seat cookie, or the host's phone with the host cookie only, or a seat cookie of another game When it sends `GET` or `PUT` to the orders URL Then it gets the stranger response and nothing is stored

### Story 3: A seat marks itself submitted, and can still change its mind

**As a** player
**I want** to mark my orders as done, and still be able to edit
**So that** the host knows I am ready without locking me out

**Acceptance criteria:**

- [ ] **AC-3.1** Given a seat with an open phase When it sends `PUT` with `submit=1` (with orders, or with none) Then its orders are saved first, a submission is recorded for that seat and phase, and the page says "Submitted"
- [ ] **AC-3.2** Given a submitted seat When it saves an order that differs from the stored one, or clears one Then the response is 303, the change is stored, the submission is removed, and the orders page says "Not submitted"
- [ ] **AC-3.3** Given a submitted seat When it saves orders that change nothing Then the submission stays
- [ ] **AC-3.4** Given a seat When it sends `submit=1` twice Then there is one submission
- [ ] **AC-3.5** Given a seat When it sends `submit=1` with an order that is refused Then nothing is saved and no submission is recorded
- [ ] **AC-3.6** Given a submitted seat When the phase is still open Then no response refuses its next edit (submitting never locks)

### Story 4: The host reveals

**As a** host
**I want** to reveal a phase after I have seen who is not ready
**So that** the table gets its results without anyone being surprised

**Acceptance criteria:**

- [ ] **AC-4.1** Given a phase where England and France submitted When the host opens the confirmation page Then it names each power that has not submitted by name, ends the list with "their unordered units will hold", and does not name England or France as unsubmitted
- [ ] **AC-4.2** Given a phase where every power has submitted When the host opens the confirmation page Then it says every power has submitted and does not contain "will hold"
- [ ] **AC-4.3** Given the host When they open the confirmation page Then it is a full page (not a dialog) built from the `.confirm` partial with a heading, the consequences in plain words ("Orders for Spring 1901 · Movement are locked and adjudicated. This cannot be undone."), a confirm button and a cancel link back to the host page, and opening it changes nothing in the database
- [ ] **AC-4.4** Given a seat cookie only, or no cookie, or another game's host cookie When it sends `GET` or `POST` to a reveal URL Then it gets the stranger response and the phase is unchanged
- [ ] **AC-4.5** Given an open phase When the host confirms Then in one step the phase gets its adjudication and revealed time, the next phase is created open with the next number, and the host is redirected to the host page, which says the phase was revealed and what the game is on now
- [ ] **AC-4.6** Given orders saved by several seats When the host confirms Then `RulesEngine.adjudicate` is called once with the phase's position and exactly the stored orders of all seats (submitted or not), listed by power and then province so the same orders always give the same result list, and every unit without an order appears in the stored adjudication as an implied hold
- [ ] **AC-4.7** Given a seat that saved orders but never submitted When the host confirms Then its saved orders are adjudicated (a submission is a mark, not a lock)
- [ ] **AC-4.8** Given a phase that was just revealed When `POST` to its reveal URL is sent again (a double tap, a second tab, a retry) Then `RulesEngine.adjudicate` is not called again, no further phase is created, nothing changes, and the host is redirected to the host page with "That phase was already revealed."
- [ ] **AC-4.9** Given two reveals of the same phase on two database connections, the first held inside `RulesEngine.adjudicate` (a stub that waits) while the second starts When the first is let go Then the second has waited for it, `RulesEngine.adjudicate` was called once, exactly one next phase exists, the phase is revealed once, the second returns the model's "already revealed" result without adjudicating, and neither raised an error. This is a model-level spec with transactional fixtures off and its own clean-up (D8)
- [ ] **AC-4.10** Given an open phase When the reveal fails after it started because the gem's invalid-input error was raised (by the adjudication or by building the next position) Then the whole step is rolled back: the phase is still open, has no adjudication, no next phase exists, the host sees a 422 page saying "Nothing was changed. The phase is still open." without the error's message (that message can hold an order's text), the log names the error class and no message, and a retry is possible. Given any other error (storing the next phase fails, the conditional write changes no row) Then the same rollback happens and the error is not hidden: it reaches the host as a 500, never as a partial reveal
- [ ] **AC-4.11** Given a reveal URL whose number names a revealed phase When the host sends `GET` to it Then the host is redirected to the host page with the "That phase was already revealed." banner; and given a number that is later than the open phase or names no phase, `GET` and `POST` both give the stranger response
- [ ] **AC-4.12** Given any state When the routes are listed Then none reopens, undoes or deletes a revealed phase, and no page offers it
- [ ] **AC-4.13** Given joining is still open When the host reveals Then the reveal works (a power nobody holds is named on the confirmation page as having no seat, and its units hold)

### Story 5: The next phase is built

**As a** host
**I want** the game to move on to the next turn by itself
**So that** the table can continue without setup, until the position editor exists

**Acceptance criteria:**

- [ ] **AC-5.1** Given a revealed spring phase of any year When the next phase is created Then it is fall of the same year; given a revealed fall phase it is spring of the following year; both are movement phases and open
- [ ] **AC-5.2** Given the stand-in's result for a spring phase When the next phase's position is read Then its units stand where the adjudication's position put them, its ownership equals the adjudicated position's, its standoffs and dislodged units are empty, and its phase is movement
- [ ] **AC-5.3** Given an adjudication whose position has dislodged units and standoffs (a hand-built result) When the next position is built Then the dislodged units are not on the board, the standoffs are empty, nothing else changes, and the revealed phase's stored adjudication still holds the dislodged units
- [ ] **AC-5.4** Given a revealed phase whose stored result has dislodged units When the host opens the host page Then one `warning` `.banner` for each such unit says, in one sentence, which unit it was ("Warning: Austria's army in SER was dislodged. Settle it by hand."); only the latest revealed phase's units are shown
- [ ] **AC-5.5** Given any number of reveals When the phases are read Then every phase is a movement phase: no retreat or adjustment phase is created
- [ ] **AC-5.6** Given the position the adjudication returns is not a retreat position (the gem may change this at 0.3.0) When the next position is built Then `RulesEngine` raises its invalid-input error, and the reveal rolls back as in AC-4.10
- [ ] **AC-5.7** Given the boundary spec of spec 019 When it runs Then it still passes: the next-position rule lives in `RulesEngine`, and no other file names a gem constant

### Story 6: An order saved after the reveal is refused

**As a** player
**I want** to be told clearly when my orders came too late
**So that** I don't think they were counted

**Acceptance criteria:**

- [ ] **AC-6.1** Given a seat holding the orders page of phase 1 open When the host reveals phase 1 and the seat then sends `PUT` to phase 1's orders URL Then the response is 409, nothing is stored, and the page says "The host has already revealed this phase. Your orders were not saved." with a link to the current phase
- [ ] **AC-6.2** Given the same When the seat sends `PUT` with `submit=1` Then it is refused the same way and no submission is recorded
- [ ] **AC-6.3** Given a revealed phase When the seat opens its orders page with `GET` Then it gets the same 409 refusal page, not the form
- [ ] **AC-6.4** Given a reveal held inside `RulesEngine.adjudicate` on one connection, and a seat's save started on another When the reveal is let go Then the save was waiting, is then refused as in AC-6.1, and nothing was stored. And given the save finishes first When the reveal runs Then the saved order is among the orders adjudicated. In both cases the stored orders of the phase equal the outcomes with `submitted: true` in its adjudication. These are model-level specs like AC-4.9
- [ ] **AC-6.5** Given a phase that has been revealed When any request tries to write an order or a submission for it Then the model refuses it (not only the controller)

### Story 7: Nobody sees an order before the reveal

**As a** player
**I want** my orders to stay secret until the host reveals
**So that** the table's negotiation means something

**Acceptance criteria:**

- [ ] **AC-7.1** Given the classification of FR-9, held in code When the suite lists every route the app answers (the app's own and those the framework engines add) Then a route that is not classified fails the spec, naming it, so a later Issue that adds a page must classify it; and the classification lists no route that doesn't exist
- [ ] **AC-7.2** Given England and the other viewers (a second seat; the host with no seat of its own; the host with a seat of its own; a stranger) When England's orders go through each of these states, with the submitted state the same in the compared pair: none; some; all of its units; different orders for the same units Then for every viewer other than England, every readable route of the classification (FR-9) answers identically in each state. "Identically" means the same status, the same body once whitespace and the page's request-specific tokens (CSRF token, nonces) are normalized, and the same `Content-Type`, `Cache-Control`, `Referrer-Policy` and `host_` and `seat_` cookie lines (the comparison of spec 021 AC-5.5). The one sanctioned difference is the list of unsubmitted powers on the host's confirmation page when England's submitted state changes (AC-4.1), and a second pair of states compares England submitted with England not submitted, for every route except the host's confirmation page. The sweep clears the rate-limit cache between states, so a later state cannot get a 429 where an earlier one got a 200. The host with a seat of its own holds a power other than England. The routes that need a token or a flash (`host-link`, `seat-link`, the QR page) are requested the way their own specs do, with the token the setup holds
- [ ] **AC-7.3** Given the same viewers When England saves, clears or submits, and when another seat sends a `PUT` for a province where England has a unit Then no response to anyone but England (the replies, the redirects, the refusals, the stranger pages) contains any of England's order text, order JSON or a count of its orders
- [ ] **AC-7.4** Given England's own pages When it reads the orders page or the seat page Then the orders page shows only England's own orders and the seat page only England's own state and count; neither shows any other power's orders, saved or not
- [ ] **AC-7.5** Given any pages the host can open (host page, confirmation page, reveal reply) Then none shows an order, a count of orders or a count of ordered units for any seat; the only per-seat fact the host can read before the reveal is the names of the powers that have not submitted
- [ ] **AC-7.6** Given a response that shows a seat's own orders Then it has `Cache-Control: no-store` and the Turbo no-cache meta, so Back and snapshots don't bring them out
- [ ] **AC-7.7** Given the log filter When the `orders` parameter is filtered Then its value is `[FILTERED]`; the `content` of a saved order is filtered from a model's `inspect` (through the model's own `filter_attributes`, not a global parameter filter that would match any `content` parameter); the flash holds no order text; and a refused or failed reveal puts no order text in its page or its log (AC-4.10)
- [ ] **AC-7.8** Given the code under `app/`, `lib/` and `db/` When it is scanned Then the constant `SavedOrder` and the name `saved_orders` appear only in the model's file, `seat.rb`, `phase.rb` and the migration and schema; `has_many :saved_orders` appears in `seat.rb` only; no association with `through:` reaches saved orders from `Game` or `Phase`; and the name appears in `phase.rb` once, in the reveal's read of a whole phase's orders
- [ ] **AC-7.9** Given a revealed phase Then no page built in this feature shows its orders or outcomes to anyone (#25); only the host's page shows that the reveal happened, and names any dislodged units (AC-5.4), which is the host reading the reveal. #25 shows results to every phone at once
- [ ] **AC-7.10** Given England's seat holds saved orders and a submission for the open phase When the host reissues England's seat Then in the same transaction as the new token England's saved orders and submission for the open phase are deleted, and a phone that opens the new seat link sees an empty orders page and "Not submitted"; the orders and submissions of revealed phases are not touched, and no other seat is affected
- [ ] **AC-7.11** Given the reissue confirmation page When the host opens it Then it says the seat's saved orders for this phase are deleted with the old phone's seat, and it is built from the `.confirm` partial with the danger variant

### Story 8: The three components exist and match the catalog

**As a** designer or a later screen's author
**I want** `.phase-header`, `.banner` and `.confirm` built once
**So that** every screen uses the same parts

**Acceptance criteria:**

- [ ] **AC-8.1** Given a `.phase-header` When it is laid out at 360 pixels Then season, year and phase type are in the mono face and drawn in capitals by CSS, the power badge sits on the right, nothing scrolls sideways, and the source text is in sentence case
- [ ] **AC-8.2** Given the `.banner` partial When it is rendered with `info`, `warning` or `danger` Then it is one sentence on its own ground (`info` on `ice-pale`; `warning` and `danger` on `surface` with a `border` or `danger` edge), `warning` starts with "Warning:" and `danger` with "Error:" so colour is never the only signal, and no view writes a `.banner` element outside the partial (a scan)
- [ ] **AC-8.3** Given the `.confirm` partial When a page uses it Then it is a full page (no `<dialog>`, no overlay), the confirm button is a `.button` (`.button--danger` when the page passes the danger local), the cancel link is a `.button--secondary`, both are at least 44 by 44 pixels at 360 pixels, and the reveal, close-joining and reissue pages all use it
- [ ] **AC-8.4** Given `/styleguide` When it is opened Then it has one section for each of `phase-header`, `banner` (all three variants) and `confirm`, at 360 and 768 pixels there is no sideways scroll and every tappable part is at least 44 by 44 pixels, and the existing style-guide specs pass with the three sections added
- [ ] **AC-8.5** Given `web/docs/design-system.md` When it is read Then the catalog lines for the three components say they are built by #22, with the partial names, and the design-system document spec passes
- [ ] **AC-8.6** Given the stylesheet Then the three components add no color token and no contrast pair: they use tokens already documented (the contrast spec still passes)

## Functional Requirements

### FR-1: Phases

Each game has phases as in D2. `Game.start!` creates phase 1 from the starting position in the same transaction as the game and its first seat. `Game#current_phase` is the one phase with no revealed time; `Game#history` is the revealed phases ordered by number. Season, year and phase type are read from the phase's position. This departs from spec 021 D1, which expected #22 to treat a game with no phase as "not started": no game exists without a phase, and a game with none is an error state. There is no deployed data to backfill (#30 has not deployed).

**Must:**
- Create phase 1 inside `Game.start!`, so no game exists without a current phase.
- Store the position through `RulesObjectType.position` and the adjudication through `RulesObjectType.adjudication`.

**Must not:**
- Edit a phase's position after it is created.
- Store season, year or phase type in a second place.

### FR-2: Saving orders

`PUT /games/:public_id/phases/:number/orders` takes `orders` (a hash from province to the order's JSON, or blank) and `submit`. All of one request is one transaction and one answer: either every change is stored, or none.

**Must:**
- Require a valid seat cookie of this game (the stranger response otherwise, spec 021 FR-6) and an open phase with that number (FR-6).
- For each posted province, apply D4's rule: a blank value removes that unit's stored order, and any other value must pass the tests below, in that order.
- Test each posted entry in this order, and give the first refusal: the key is a province where the seat has a unit ("You have no unit in XXX."); the value loads as an order ("That order couldn't be read."); its `at` equals the key ("That order couldn't be read."); its `power` is the seat's ("That order isn't for your power."); `RulesEngine.check` says legal (the reason's sentence).
- Treat the `orders` parameter as a partial update: provinces not named keep their orders.
- Remove the seat's submission when the request changed any stored order (added, replaced or removed), and leave it alone when it changed nothing.
- When `submit` is `1`, record the seat's submission last, after the orders, in the same transaction.
- Answer a success with a 303 to the orders page, and a refusal with the same page and a banner (422, or 409 for a revealed phase).
- Run in one transaction whose first statement is `phase.lock!`, then re-read that the phase is still open (D8; FR-7 has the same step), and re-read the seat's token digest, refusing with the stranger response if it changed. That closes the race in which a save from a phone that was just reissued authenticated before the reissue and would commit after it (D9).

**Must not:**
- Use the power the client sends for anything except to refuse a wrong one: the seat decides the power.
- Reveal in its replies anything about another seat.

### FR-3: Submissions

A submission is a row, per D2. Saving and submitting are the only things that touch it. It has no effect on what the reveal adjudicates (AC-4.7).

### FR-4: The orders page (the plain form)

*Replaced by spec 023 (changelog 1.3.0).*

As in D5. It is built from `RulesEngine.legal_orders` for each of the seat's units in the phase's position, and from the seat's stored orders, nothing else. It carries the phase number in its URL, so a stale page posts to the phase it was drawn for (D7).

**Must:**
- Show the phase header, the seat's own state ("Not submitted" or "Submitted") and "n of m units ordered" (the seat's own count), the form, and the two buttons.
- Put the buttons in the sticky `.app-actions` area.

**Must not:**
- Be built as a picker: no step pages, no draft, no per-unit pages (#23).

### FR-5: The saving rule

As in D4. Messages for refusals are one sentence each, written in plain words, naming the unit by type and province. Every reason the gem reports (`interface.md`, "Rejection reasons") has its own sentence, and an unlisted reason gets "That order isn't legal."

### FR-6: Refusal after the reveal

A request whose phase number is a revealed phase gets the refusal page described in AC-6.1 with status 409, for `GET` and `PUT` alike. The check is made inside the transaction after the lock (FR-7), and again by the models (AC-6.5): an order or a submission cannot be created for a phase that has a revealed time.

### FR-7: The reveal

`POST /games/:public_id/host/phases/:number/reveal`, host only.

**Must, in one transaction:**
1. Find the phase by number and take its lock with `lock!` as the transaction's first statement (D8).
2. If it is already revealed, change nothing and answer as AC-4.8.
3. Read every stored order of the phase (the one place that reads them all), ordered by power and then province, call `RulesEngine.adjudicate` with the phase's position and those orders, and build the next position (FR-8).
4. Set the phase's adjudication and revealed time with a conditional write that only succeeds while the revealed time is null. If exactly one row did not change, raise and roll back (a backstop, D8): this can only happen if the lock failed, and it surfaces as a 500, not as the already-revealed answer.
5. Create the next phase.
6. Commit, and redirect.

**Must:**
- Roll everything back on any error after step 1 (AC-4.10). Only the gem's invalid-input error is turned into the 422 page, without its message; any other error is not hidden.
- Give the same answer to a retry as to a second tab.

**Must not:**
- Offer or perform undo.
- Call `RulesEngine.adjudicate` more than once per phase, however many requests arrive.

### FR-8: The next phase

As in D3, built by `RulesEngine.next_movement_position(position)`: the position must be a retreat position (else invalid-input error); units as given; dislodged units dropped; standoffs cleared; ownership unchanged; spring becomes fall of the same year; fall becomes spring of the next year; phase movement.

### FR-9: Order secrecy

**The route table.** Every route of the app, and what it can show about orders. The route-table spec (AC-7.1) holds this classification in code and fails on any route missing from it.

| Route | Can it show orders? |
|---|---|
| `GET /up`, `GET /`, `GET /styleguide` | No. Static, no game data |
| `GET /games/new`, `POST /games` | No. A form, and a redirect to the host page |
| `GET /join`, `POST /join`, `GET /join/:code`, `POST /join/:code/seat` | No. Codes and open powers only |
| `GET /games/:id` (seat page) | **Own state and own count only** ("Not submitted", "2 of 3 ordered"); never the content of an order |
| `GET /games/:id/host` | No orders. Phase header, history, dislodged units of a revealed phase, the Reveal button |
| `GET /games/:id/host-link`, `GET /games/:id/seat-link` | No. They set a cookie and redirect |
| `GET` and `POST /games/:id/host/close` | No |
| `GET` and `POST /games/:id/host/seats/:power/reissue`, `GET .../qr` | No orders shown. **But a reissue is a path to a seat's orders**, closed by D9: the reissue deletes that seat's saved orders and submission for the open phase |
| `GET /games/:id/phases/:n/orders` | **Own orders only** |
| `PUT /games/:id/phases/:n/orders` | **Own orders only** in the reply and the redirect target |
| `GET` and `POST /games/:id/host/phases/:n/reveal` | No orders. The names of powers that have not submitted; after the reveal, that it happened |
| Unknown route, stranger and rate-limit pages | No |
| Framework routes: the Turbo historical-location routes; Action Mailbox ingress and conductor; Active Storage | No. They have no game data and no model that attaches to a game. They are classified by prefix in the route-table spec, with this reason, so the spec doesn't fail on day one and does fail if a game route is later added under one of those prefixes |
| The `/cable` mount (an internal route entry with an empty verb) | No channel exists yet. #24 adds the first stream and must classify it |

**How the list is shown to be complete** (D6): the route-table spec enumerates the app's routes and fails when one is unclassified; the invariance sweep (AC-7.2) then requests every readable route as each kind of viewer, so a route classified "No" that in fact depended on orders would show a difference; the source scan (AC-7.8) limits which code can name the saved-orders model and table. Logs are covered by the parameter and attribute filters (AC-7.7). What the checks cannot see (a live stream, an email) does not exist yet. Turbo Streams arrive with #24, which must classify them.

**Must:**
- Derive the sweep's list of readable routes (AC-7.2) from this classification, so a new `GET` is swept without anyone editing the sweep.
- Show a seat's orders only to that seat, before and after the reveal, by this feature's pages.
- Keep orders out of the flash, out of logs (the `orders` parameter and a saved order's `content` are filtered), out of error messages (AC-4.10), and out of cached pages, and out of the production log at its default level (see the limit below): the orders page and its redirect carry `Cache-Control: no-store` (AC-7.6). The seat page shows no order content, so it needs no such header.
- Store each order with its seat and phase, with no association from `Phase` to all its orders, and read all of a phase's orders only inside the reveal.

**Known limit.** Rails writes SQL bind values to the log at the `debug` level through its own global filter, which a model's `filter_attributes` doesn't reach. A saved order's content can therefore appear in a debug-level SQL log (development, test, or production if `RAILS_LOG_LEVEL=debug` is set). Production logs at `info` by default, and a spec asserts that default. This is stated in the pull request.

**Must not:**
- Show the host, or any seat, another seat's orders, a count of its orders or a count of its ordered units before the reveal.
- Build a listing, a query method, a scope or a view that joins all seats' orders for an open phase.

### FR-10: The three components

As in the catalog and in Story 8. Each is one partial: `phases/_header` (locals: the phase, an optional power), `shared/_banner` (locals: kind, text), `shared/_confirm` (locals: title, consequences, confirm label and path, cancel path, and `danger`, which makes the confirm button `.button--danger`). The reveal page is not danger (it is the table's normal step, and the page says it cannot be undone); the close-joining and reissue pages stay danger, as spec 021 AC-6.1 and AC-7.2 require. Success messages travel in the flash as a banner's kind and text only, and the layout renders `flash[:banner]` through the banner partial; the layout's existing `flash[:notice]` line is left as it is. `.phase-header` uses the mono face through the `.mono` class and CSS capitals. The banner partial is the only place a `.banner` is written, so #82 can add a glyph in one place. `.confirm` is also used by the close-joining and reissue pages (spec 021 D7).

## Non-Functional Requirements

### Performance

- Opening the orders page makes no write, and saving and revealing each take one database transaction. The reveal holds the database's write lock while the stand-in runs, which is plain Ruby with no input or output, so the wait for a second writer stays far under the 5-second timeout. No timing is asserted by a spec.
- **Stylesheet budget.** The caps are raised to 32,768 bytes in total and 6,144 for `styleguide.css` (changelog 1.2.0). The stylesheets stand at 23,378 and 3,716 bytes. This feature's CSS stays within the new caps, and `spec/styles/stylesheet_rules_spec.rb` enforces them.

### Security

- Every page and action needs the right cookie, checked as in spec 021 (`GameAccess`). A seat can act only on its own power's units. Only the host can reveal. A phase number in a URL grants nothing.
- CSRF protection applies to the `PUT` and the reveal `POST`.
- The stranger response is unchanged for an unknown game, a wrong cookie, an unknown phase number and a future number.

### Reliability

- The reveal is atomic, idempotent and pinned to a phase number (D7, D8). The database refuses a second open phase, a repeated number and a half-stored reveal (AC-1.3).
- Saving an order can't be lost: it is stored, or refused with a message. A save and a reveal at the same moment end in one of those two states (AC-6.4).

### Accessibility and layout

- Every control is at least 44 by 44 pixels at 360 pixels wide and nothing scrolls sideways (spec 020). Each select has a label. The submitted state is words, not color. Screenshots at 360 pixels are in the pull request.

## Error Scenarios

| Scenario | Expected Behavior |
|----------|-------------------|
| A seat saves an order for another power's unit, or with another power's name | 422, a sentence, nothing stored (AC-2.2, 2.3) |
| A seat saves an illegal order | 422, the reason in words, nothing stored (AC-2.4) |
| A seat posts text that is not a valid order | 422, "That order couldn't be read.", nothing stored (AC-2.5) |
| A seat saves after the host revealed | 409, "The host has already revealed this phase. Your orders were not saved.", link to the current phase (AC-6.1) |
| The host taps Reveal twice, or in two tabs, or retries | One reveal; later requests get "That phase was already revealed." (AC-4.8) |
| Two reveals arrive at once | One wins; the other behaves as a retry (AC-4.9) |
| The gem rejects the adjudication or the next position (its invalid-input error) | Rolled back; 422 "Nothing was changed. The phase is still open." (AC-4.10) |
| Any other failure during the reveal | Rolled back; a 500, never a partial reveal (AC-4.10) |
| A seat or a stranger asks for a reveal URL | The stranger response (AC-4.4) |
| A phase number that doesn't exist or is in the future | The stranger response (AC-4.11) |
| The host opens a reveal URL for an already revealed phase | Redirect to the host page, "That phase was already revealed." (AC-4.11) |
| A stale orders page is submitted after the next phase opened | Refused by its phase number (AC-6.1); the order never lands in the new phase |
| The host reissues a seat that holds saved orders | The seat's saved orders and submission for the open phase are deleted with the old token (AC-7.10) |
| A dislodged unit appears (from #29 on) | It is off the board in the next position, named on the host page (AC-5.3, 5.4) |

## Open Questions

Nothing in the spec is unresolved. The maintainer is asked about D2, D3, D4, D5, D6 and D9, and about the stylesheet limit (answered in changelog 1.2.0).

## Out of Scope (Future Considerations)

**Handed to later issues:**
- **#23** replaces the plain form (D5) with the pickers, keeping the `PUT` endpoint, its partial-update meaning and its refusals. It adds the `.unit-row`, `.picker` and `.submit-bar` components, and its submit bar replaces the plain form's "n of m units ordered" line.
- **#24** shows who has submitted to every phone, live. It must classify its new routes and streams in the route table (FR-9).
- **#25** shows the stored results to every phone, grouped by power, and decides what a seat sees of a revealed phase's orders.
- **#26** reuses `.confirm` and `.banner` for stepping in. Stepping into a seat is the only way the host may ever see that seat's orders, and the sweep (AC-7.2) will need that exception written down.
- **#27**, the position editor, edits an open phase's position by hand (retreats, builds, ownership, dislodged units, D3). Because an order is checked against the phase's position, #27 must re-check or clear saved orders and submissions when it changes the position of an open phase. This spec doesn't decide that; it notes that the phase's position is the one thing D4's reasoning relies on.
- **#29** swaps in gem 0.2.0 and changes only `RulesEngine`: it deletes the stand-in and keeps `next_movement_position` until 1.0.
- Retreat and adjustment phases, automatic ownership changes after fall, a phase clock, and a shared display.

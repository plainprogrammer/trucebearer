# Feature 027: The host's position editor

**Status:** Draft
**Version:** 1.0.2
**Created:** 2026-11-26
**Last Updated:** 2026-11-26
**Issue:** #27
**Branch:** `web/27-position-editor`

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 1.0.2 | 2026-11-26 | Minor fixes from the second Fable review (approved with minor fixes): the "Choose ..." checks run before any gem call and unknown identifiers are `other` (D5); `RulesEngine.coast_name` added; AC-1.5 and AC-1.9 agree with the stage order; the unit that vanishes under the lock is the stranger response (D7, AC-7.12); AC-3.3 covers a non-province value; spec 023's note is amended too (AC-10.2); stale Open Question references and the status-scan wording corrected. |
| 1.0.1 | 2026-11-26 | Changed after the first Fable review (verdict: changes required).<br>• **D5/D8:** the plain words no longer rest on the gem's message text, which `web/AGENTS.md` forbids using. `RulesEngine` builds each edit in stages and explains a refusal from the documented map queries (province type, coasts, occupied provinces), only after the gem has refused. Open Question 1 is gone.<br>• **D3:** the clearing rule is now "an edit that changes where units stand". A season-and-year edit keeps orders, as an ownership edit does (orders are keyed to the phase and checked against units); the notice shows only the latest clearing time.<br>• **D7:** the guard on `Phase#position` is new behaviour (a model validation) and has ACs; `edit_position!` compares the locked open phase with the phase the URL named; stale and in-lock cases both go to the host page like the reveal.<br>• **D4:** `change` becomes `detail`, `kind` becomes `action`, moves carry `from_coast` and `to_coast`, removals carry the coast, years are integers; one `Game` method reads the notice's times.<br>• **D6/D8/AC-1.x:** coast field and the "Choose ..." sentences defined; which reason wins; both "set" forms use PUT.<br>• **Story 7/10:** route-table entries (`revealed: :none`, not `numbered`) and the `why` texts of three existing entries; named versions for the amended specs and the amendments spec; the stylesheet budget; ACs rewritten as Given/When/Then and the untestable ones replaced. |
| 1.0.0 | 2026-11-26 | First draft |

## Problem Statement

During the playtest the host makes retreats and builds by hand, and later uses the same tool to fix drift between the board on the table and the board in the app (`docs/architecture.md`, "Game rules in the app" and "Targets"). Today nothing lets the host touch the position: after a reveal the game goes straight to the next movement phase (spec 022 D3), dislodged units are off the board, and supply-center ownership is carried over unchanged. The host needs a way to put units where the table says they are, with the map's rules still enforced, and a record the table can read afterwards.

Players can already save orders in the next phase before the host has fixed the board (the comment from #22 on this Issue). So an edit must also say what happens to the orders saved against the old board.

## Goals

- The host can add a unit, move a unit, remove a unit, set who owns a supply center, and set the season and year, all for the **open phase's position**.
- Every edit is built as a new position by the rules engine, so an impossible board (two units in one province, a fleet inland, an army at sea, a missing or wrong coast) is refused by the engine, with a plain-word reason (D5), and nothing is stored.
- An edit that changes where units stand clears every seat's saved orders and submission for the open phase. An edit of ownership, or of the season and year, clears nothing. Each seat is told on its own pages, and the submitted states on every phone follow through the existing status stream.
- Every edit is recorded in the game's history: what changed, the phase and the time. The host's Seat history list shows it, in the order spec 026 D10 set.
- Only the host reaches the editor. No page of it shows any saved order, and every new route is classified in the secrecy table and covered by the sweep.
- Every step is a normal page with its own URL, works without JavaScript, and fits a phone 360 pixels wide.
- The page set adds the `.segmented` component (army or fleet), used with `supply_center_icon`, and lists both in `/styleguide` and the design-system catalog.

## Non-Goals

- Re-implementing any map rule in the app. The engine decides what a possible position is (D5).
- A "position being fixed" state that stops players saving orders until the host says go. D2 explains the choice and the alternatives.
- Editing a revealed phase, or any phase other than the open one.
- Editing dislodged units or standoffs. A movement-phase position has none (the gem refuses them), and every open phase of the playtest is a movement phase. (Spec 022 mentions this as work for #27 "later"; this spec leaves it to the retreat and adjustment phases of gem 0.3.0.)
- Changing a phase's type (movement, retreat, adjustment).
- Undoing an edit. The host edits again.
- Showing the history to anyone but the host. The seats see only that the board changed, and when (D3).
- A live reload of order screens that are already open on a phone (Open Question 1).
- Folding the host page's lists into one (#112), the shared display, the phase clock, any rendered map.
- Any change to `adjudicator/`, `.github/` or the root files.

## Users and Context

**Primary users:** The host, at a physical table, on a phone about 360 pixels wide, moving a retreating army, adding the builds after a fall phase, or fixing a unit that is in the wrong place on the app's board.
**Secondary users:** The players, whose saved orders are cleared by edits that move units and who are told so.
**Usage context:** Most often right after a reveal, before the players have entered orders for the new phase. Sometimes in the middle of a phase, to correct a mistake.
**User mental model:** "The app's board must match the table. I fix it here, the app refuses anything the map doesn't allow, and everyone re-enters orders if I moved units."

## Decisions

Gate A asks about D2, D3 and D4. D5 is the validation ruling from the maintainer's brief.

**D1. What is edited: the open phase's position, one change at a time.**

- The editor works on `Game#current_phase` and nothing else. Every URL carries the phase number, as the reveal's does (spec 022 D7). A number that is a revealed phase redirects (303) to the host page with the `info` banner "That phase was already revealed.", as `RevealsController` does, and nothing is written. A later, unknown or malformed number is the stranger response.
- **One edit is one change, one form, one record.** The editor's pages are small forms:

| Edit | What the host picks | What changes in the position |
|---|---|---|
| Add a unit | the power, army or fleet, the province, a coast | one unit joins `units` |
| Move a unit | the new province, a coast | the unit's location changes; its power and type do not |
| Remove a unit | (a button on the unit's page) | the unit leaves `units` |
| Set a supply center's owner | the center, and a power or "nobody" | one entry of `ownership` is set or removed |
| Set the season and year | spring or fall, a year | `season` and `year` change |

- Changing a unit's power or type is a removal and an addition: two edits, two records.
- A province is named by its full name with its abbreviation in the lists ("Burgundy (BUR)"), as spec 023 does.
- **The coast field** offers "No coast" and the three coasts the map has anywhere (North, South, East), for every province, because a page with no JavaScript can't change the list as the province changes. A value that is not one of those four is refused as "Choose a coast." before it reaches the engine. A coast the chosen province lacks is the engine's refusal (D8).
- The editor never touches `phase` (it stays what it is), `dislodged_units` or `standoffs`.

**D2. "Set the next phase": the game already starts the next movement phase at the reveal, so the editor edits it in place. There is no separate "start" step and no hold. (Gate A)**

The Issue says the host can "set the next phase" and "start the next movement phase after making retreats and builds". Since spec 022 D3 the reveal itself opens the next movement phase at once, so there is nothing left to start. Three readings, argued:

- **(a) Edit in place, no new state. Recommended.** After a reveal, the open phase is the next movement phase (spring becomes fall of the same year, fall becomes spring of the next). The host opens the editor, makes the retreats and builds, and the phase is ready: "set the next phase" is the season-and-year form, for a host whose table is at a different date than the app, and "start the next movement phase" is met by the reveal that opened it. The risk is the one the comment from #22 describes: a player can save orders before the host has fixed the board. D3 handles that with a rule that needs no new state. **The cost:** each edit that moves units clears everyone's orders again, so a host who makes six builds after players have started ordering wipes them six times. The notice shows only the latest time, so it stays short. The cure is a habit the page says out loud ("Fix the board before the players order"); the table still can't be stopped from ordering early.
- **(b) A "position being fixed" state.** The reveal would open the next phase on hold. While it is held, saving orders is refused with a plain page and the host page shows "Edit the board" and a "Start Spring 1902 · Movement" button. This matches the Issue's wording most literally and means no player ever saves against a stale board. It costs: a new column and state on `Phase`; a change to `Phase#reveal!` (spec 022 FR-7, D3, and the specs that build on it, 023 and 026); a refusal page on every order route; a second thing the status list and the live refresh must explain; and a button the host must press after **every** reveal, including the ones that need no fixing, which is most of them in the playtest, where the stand-in adjudicator never dislodges anything and no phase needs builds until fall. It also leaves a game stuck on hold if the host forgets.
- **(c) A host-chosen hold: a "hold orders" switch on the editor.** The host switches the hold on, edits, switches it off. It needs no change to `reveal!` and is the only option that avoids the repeated wipes of (a). It costs a new state on `Phase`, a refusal page on every order route, and a new way for a game to be stuck on hold. It is the first thing to build if the playtest shows (a)'s cost is real, and is listed in Out of Scope for that reason.

If the maintainer prefers (b) or (c), this spec is amended (spec-update) and the plan grows a lifecycle step. Nothing in D1, D3, D4 or D5 changes.

- After a reveal, the host page's flash already says which phase is open now. The host section gets an "Edit the board" link that is always there (D6), and the banner of the reveal does not change.
- The year is a whole number from 1901 to 1999. This is a sanity range for an input, not a rule of the map.

**D3. Saved orders after an edit: an edit that changes where units stand (add, move, remove) clears every seat's saved orders and submission for the open phase. An edit of ownership, or of the season and year, clears nothing. (Gate A)**

- **What is cleared and when.** In the same transaction as the edit, `Seat#clear_orders!` (the method the reissue uses, spec 022 D9) runs for every seat of the game for the open phase.
- **Why ownership and date keep orders.** An order is checked against the units and the phase type, never against ownership, the season or the year, and a saved order is keyed to its phase, not to its date. So these two edits change nothing a saved order depends on, and wiping the table's orders for them would cost the players for no reason.
- **Options not chosen: re-check every saved order against the new position and keep the legal ones.** It keeps more work for the players, and it was weighed seriously. It loses on two grounds:
  1. *Secrecy.* The host causes every edit. A re-check would drop only the orders the edit broke, so what each seat sees afterwards (and, through the live status, what every phone sees) would depend on what each seat had ordered: France's "Submitted" turning into "Not submitted" after the host moves a French army tells everyone France had an order for it. Clearing everything changes every seat's state the same way, whatever it ordered, so the host and the table learn nothing new. Spec 026 and spec 022 FR-9 make "no one learns an order before the reveal, the host included" the rule that decides.
  2. *Meaning.* A kept order can be legal and still mean something else: a support for a unit that moved, or a convoy whose chain was changed by the edit. A player who looks away from the screen for a minute would reveal an order they did not mean. "Everyone re-enters after the board changes" is a rule the table can say out loud.
- **What the host sees.** Every editor page that clears says, before the host saves, "Saving this clears every seat's saved orders for this phase." The page after a save says the same in the past tense, whether or not any order existed ("Saved. Saved orders for this phase were cleared."). The sentence does not depend on the orders: the host learns nothing about them. After an ownership or date edit it says "Saved. Orders are kept." The host sees no count, no name, no seat.
- **What a player sees.** On the seat page and on the order screen of the seat's own phone, a `.banner` (kind `warning`) when the open phase has had at least one clearing edit: "The host changed the board at 8:42 PM UTC. Orders saved before then were cleared, so check yours." The time is the **latest** clearing edit's. It is drawn from the edit records (D4) through one `Game` method, carries only a time (the `table_time` helper of spec 026 D6) and is the same for every seat, so it says nothing about whether that seat had ordered. Like the step-in notice, it is not drawn on a stepped-in page.
- **The status stream.** If the edit withdrew at least one submission, `Game#broadcast_seat_status` is called once after the transaction, as `reissue_seat!` does (spec 024 D3): only a flip of a submitted state is news. A failed cable call never fails a stored edit.
- **What an open order screen does.** A phone that still shows the old board can send a save. `Seat#save_orders!` reads the phase under its lock, so it checks the order against the **new** position and refuses an illegal order with the existing sentence ("You have no unit in BUR."). Nothing changes there. Open Question 1 asks whether to reload open screens.
- **An edit that changes nothing is refused** ("That is already the position."), writes no record and clears nothing, so an accidental double tap does not wipe the table's orders twice.

**D4. History: a third append-only table, `position_edits`, read into the existing Seat history list. (Gate A)**

| Table | Columns | Keys and checks |
|---|---|---|
| `position_edits` (model `PositionEdit`) | `phase_id`, `detail` (JSON), `created_at` | `phase_id` is a foreign key, indexed. No `updated_at`. A row never changes and is never deleted (the model refuses both, as `StepIn` and `Reissue` do). `detail` is required and is one of the five shapes below |

The five shapes of `detail`, plain data like the position's own hash form. Every value is a string or null, except the two years, which are integers:

| `action` | other keys |
|---|---|
| `unit_added` | `power`, `type`, `province`, `coast` |
| `unit_moved` | `power`, `type`, `from`, `from_coast`, `to`, `to_coast` |
| `unit_removed` | `power`, `type`, `province`, `coast` |
| `owner_set` | `center`, `from` (the old owner, or null), `to` (the new owner, or null) |
| `date_set` | `from_season`, `from_year`, `to_season`, `to_year` |

- **Why a table of its own, and why this shape.** This follows #104's pattern: an append-only table whose rows hold facts and no order, merged into one list in Ruby. The alternatives: a `kind` column on `reissues` or `step_ins` (rejected for the reasons spec 026 D10 gives: those tables mean something different and have a cookie and a lifetime); one `seat_events` table replacing both (a rewrite of #104 and #26 for a gain nobody has asked for yet; #112 or a later Issue may fold the three when it folds the lists); and a text column of finished sentences (it cannot be listed, filtered or re-worded later by #47 and #50; a structured `detail` can). The JSON column is the fewest parts that keep the facts as facts: a Rails JSON attribute, no second table. The names `detail` and `action` avoid Rails' dirty-tracking names and the `kind` that every history entry answers.
- **What it holds.** Board facts only: which power's unit, which provinces, which owner, which date. No order, no count of orders, no seat's submitted state, no token. A row says nothing about whether the edit cleared orders: that follows from its `action` (D3), so the row cannot differ with what players had ordered.
- **Written in the edit's transaction.** `Game#edit_position!` takes the phase lock (as a save and a reissue do), builds the new position, stores it, clears the orders when D3 says so, and writes the row, in one transaction. A row that can't be written rolls the whole edit back. A refused edit writes nothing.
- **Which phase** is the open phase the edit ran in. **When** is `created_at`, in UTC.
- **Reads.** `Game#position_edit_history` reads every row whose phase belongs to the game, oldest first, through the game's phases and with no `through:` association, as `step_in_history` and `reissue_history` do. `Game#seat_history` merges it with the other two. Each entry answers `kind` (`:position_edit` here; `:step_in` and `:reissue` as today) and its own `phase`, `created_at` and `id`, so the list partial names no constant. **The notice's reader** is one more `Game` method, `Game#board_cleared_at(phase)`, that returns the time of the latest clearing edit of a phase or nil, so no view or controller reads the table.
- **Order of the list: #104's order, extended.** Oldest first by `created_at`; at the same instant a reissue comes before a step-in (spec 026 D10), and a position edit comes after both, then by id. The order is stable.
- **The row on the host page.** In the Seat history list: the phase title, the words "board changed", and the change in words, then the time: "Fall 1901 · Movement · board changed: France's army added in BUR · 8:42 PM UTC". The list keeps its heading, "Seat history", its hook `data-seat-history` and its empty text, so #104's specs stand. Its name is now a little narrow, since it also holds board edits; #112 can rename it when it folds the host page's lists (Open Question 2).
- **A changed date and old titles.** A row shows its phase's title as it is when the page is drawn. After a date edit, earlier rows of the same phase carry the new title, and the date edit's own row says "season and year set from Spring 1901 to Fall 1901". The phase's number never changes.
- **Who sees the history: only the host**, on the host page. Seats see only the notice of D3.

**D5. Validation comes from the rules engine. Each edit builds a new position there, and a refusal is explained from the documented map queries.**

- `RulesEngine` gets a small set of methods and nothing else in the app names a gem class. Each takes the open position and plain values (strings) and returns the new position, or raises `RulesEngine::EditRefused`, a new error that carries a **reason** (a symbol of D8):
  - `RulesEngine.add_unit(position, power:, type:, province:, coast:)`
  - `RulesEngine.move_unit(position, from:, province:, coast:)`
  - `RulesEngine.remove_unit(position, province:)`
  - `RulesEngine.set_owner(position, center:, power:)` (a nil power removes the entry)
  - `RulesEngine.set_date(position, season:, year:)`
  - the lists the forms need: `RulesEngine.provinces` (each with its id, full name and coasts), `RulesEngine.supply_centers` (identifiers) and `RulesEngine.coast_name(id)` ("north", "south", "east", the app's own labels for the three coast identifiers), read from the map or its identifiers; the province list in the forms is sorted by name in the view.
- These are **new methods in `rules_engine.rb`**. #29 (the gem upgrade) also edits that file, so the pull request says so, and `main` is merged when told. The methods use only what gem 0.1.0 documents (`TA::Position.new`, `TA::Unit.new`, `TA::Location.new`, `Map#province`, `Map#provinces`, `Map#supply_centers`) and need nothing from 0.2.0, so #29 should keep them as they are.
- **No map rule is written in the app, and the engine decides.** The gem builds the position: one unit per province, no fleet inland, no army at sea, a coast exactly when a fleet is in a split-coast province, an owner only for a supply center. The forms offer every province and let the engine refuse, instead of the app filtering lists by rules it would have to know.
- **The reason is found without reading the gem's messages.** The gem documents only that an error message "includes the offending key or value", so the app does not read it (`web/AGENTS.md`: use nothing beyond the interface). Each method builds in the documented stages, and the stage that raises names the reason, with the documented map queries used only to word a refusal the gem has already made:
  0. *Before any gem call* the controller's "Choose ..." checks (D8) refuse a power, type, province, coast or season that is not one of the offered values, using the engine's lists (`RulesEngine.powers`, `provinces`, `coasts`, `supply_centers`). The engine's methods called directly with an unknown identifier (not through a form) raise `EditRefused` with the reason `other`.
  1. `Location.new` raises for a known province: the province has no such coast (the reason is `no_such_coast`; with no coast given it is `other`).
  2. `Unit.new` raises: the reason is read from `Map#province(id)`: an army on a sea province is `army_at_sea`; an army with a coast is `army_coast`; a fleet on an inland province is `fleet_inland`; a fleet with no coast on a province that has coasts is `fleet_needs_coast`; anything else is `other`.
  3. `Position.new` raises: `province_taken` when the target province already holds a unit in the old position (`units` is documented), `not_a_center` for an owner of a province that is not a supply center (`Map#province(id).supply_center`), otherwise `other`.
  When two rules break at once, the earlier stage wins (a fleet put with the north coast in an occupied Paris gets the coast sentence, not the occupied one).
- **A reason is never a rule.** If the table of reasons were wrong, a position the gem accepts would still be accepted and one it refuses would still be refused; only the sentence would be off. A spec drives each impossible position of the gem's "Impossible objects" that an edit can reach and checks both the refusal and the reason.

**D6. The pages: a host-only editor under `/host/phases/:number/position`.**

| Page | Address (under `/games/:public_id/host/phases/:number/position`) | Method | What it does |
|---|---|---|---|
| The board | `` (the position itself) | GET | The position: units grouped by power, supply centers by owner. Links to the other pages. The sentence about clearing orders |
| Add a unit | `/units/new` | GET | The form: power, army or fleet (`.segmented`), province, coast |
| | `/units` | POST | Adds it, or shows the form again with the reason (422) |
| A unit | `/units/:province` | GET | The unit's page: a form to move it, a button to remove it |
| | `/units/:province` | PATCH | Moves it, or shows the page again with the reason |
| | `/units/:province` | DELETE | Removes it |
| Owners | `/owners` | GET | The form: a supply center and an owner |
| | `/owners` | PUT | Sets it, or shows the form again with the reason |
| Season and year | `/date` | GET | The form |
| | `/date` | PUT | Sets it, or shows the form again with the reason |

- A successful edit redirects (303) to the board page with a `.banner` of kind `info` that says what changed in words and the sentence of D3.
- A refused edit answers 422 with the same page and a `.banner` of kind `danger` holding the plain sentence, and keeps what the host picked in the form.
- **The host's way in.** The host section of the host page gets one link, "Edit the board", beside "Reveal orders". It is there in every state. The host page's other lists are not changed (#112).
- **Every page** carries `Cache-Control: no-store`, the Turbo no-cache meta and `Referrer-Policy: no-referrer`.
- **Host only.** Every route behind `require_host`: a stranger, a seat or another game's host gets the stranger response and nothing is written (spec 021 D4).
- Phone and Native: each is a normal Turbo Drive page with a meaningful URL. No Stimulus controller and no JavaScript are added.

**D7. Concurrency: the phase lock decides, the reveal wins.**

- `Game#edit_position!(number, change)` takes the phase lock first and reads the open phase under it, as `Seat#save_orders!` and `Game#reissue_seat!` do, and **compares the locked open phase's number with the number the URL named**. If they differ (the phase was revealed in the meantime, so the open phase is the next one) it raises `Phase::Revealed`, the host is sent to the host page with "That phase was already revealed.", and nothing is written. A stale form for phase N can never edit phase N+1.
- Two edits at the same moment run one after the other: the second is built from the position the first stored. If the first removed or moved the unit the second names (the unit's page was opened before), the second finds no unit under the lock and is the stranger response with nothing written.
- **A guard on the model, new in this spec:** `Phase` refuses (a validation) to change `position` once `revealed_at` is set. A revealed phase's position is what it was adjudicated from and can be replayed from.

**D8. The words.** Every sentence below is original wording for this app, cites no rulebook and names no section. A province is its full name.

| Reason | Sentence |
|---|---|
| `army_at_sea` | "An army can't stand in %{province}: it is a sea province." |
| `fleet_inland` | "A fleet can't stand in %{province}: it is inland." |
| `fleet_needs_coast` | "A fleet in %{province} must say which coast it is on." |
| `army_coast` | "An army doesn't stand on a coast. Leave the coast blank." |
| `no_such_coast` | "%{province} has no %{coast} coast." |
| `province_taken` | "%{province} already holds a unit. A province holds one unit." |
| `not_a_center` | "%{province} is not a supply center." |
| `no_change` | "That is already the position." |
| `other` (anything else the engine refuses) | "That isn't possible on the map." |
| a missing or unknown power, type, province, coast or season | "Choose a power.", "Choose army or fleet.", "Choose a province.", "Choose a coast.", "Choose a season." |
| a year out of range or not a whole number | "The year must be a whole number from 1901 to 1999." |

The "Choose ..." sentences are the app's own check that a field holds one of the offered values; they are not map rules. Everything else is the engine's.

**D9. The `.segmented` component and the stylesheet budget.** A fieldset with a legend and two or more radio inputs, each in a label, drawn as joined buttons. It is built in `shared/_segmented` with locals `legend`, `name`, `options` (value and label pairs) and `selected`. The radios stay real radios (keyboard, form post and screen readers work with no script). The selected option uses the `primary` fill with `on-primary` text; the others use `surface` with `text` and the `border` edge; each is at least 44 pixels tall; the focus ring is the `focus` token. It adds no color token and no pair: it uses documented ones. It is added to `/styleguide` and to the catalog line for #27 in `web/docs/design-system.md`, which says "built". **Budget:** spec 022 1.2.0 caps the stylesheets at 32,768 bytes in total and `styleguide.css` at 6,144. They stand at 28,400 and 3,716, so `.segmented`, the board page's rows and the style-guide samples must fit in 4,368 bytes together (and 2,428 in `styleguide.css`). If they don't, the plan stops and asks for a ruling rather than raising the cap.

**D10. The screens, at 360 pixels.** The screenshots are saved to `web/docs/specs/027-position-editor/screens/` and shown in the pull request:

1. The board (units and centers, after one edit, with its banner).
2. Add a unit, with `.segmented`.
3. Add a unit refused (a fleet in Burgundy), showing the plain reason.
4. A unit's page (move and remove).
5. Supply-center owner.
6. Season and year.
7. The host page with "Edit the board" and the Seat history list holding a board change.
8. A seat page with the "board changed" notice.

## URLs

All under `/games/:public_id/host/phases/:number/position` (D6). No new query parameter is read. A province in a path (`/units/:province`) is matched strictly: it must be a province of the map and hold a unit, or the page is the stranger response.

## User Stories

### Story 1: The host adds an army (the first test)

**As a** host
**I want** to put a unit on the board
**So that** the app matches the table

**Acceptance criteria:**

- [ ] **AC-1.1** *(the first test, a request spec)* Given a new game whose host is signed in, in the open phase When the host adds an army in Burgundy to France Then the response redirects to the board page and the open phase's stored position holds a French army in BUR
- [ ] **AC-1.2** *(the second half of the first test)* Given that position When the host adds a fleet in Burgundy for France Then the response is 422, its banner reads "A fleet can't stand in Burgundy: it is inland.", and the stored position is unchanged
- [ ] **AC-1.3** Given the add form When the host opens it Then its fields are `unit[power]`, `unit[type]` (a `.segmented` of army and fleet, army selected), `unit[province]` and `unit[coast]` ("No coast" selected), every field is labelled, and the page needs no JavaScript
- [ ] **AC-1.4** Given a fleet and Spain When the host adds it with the south coast chosen Then the unit is stored with that coast; with "No coast" the response is 422 with "A fleet in Spain must say which coast it is on."
- [ ] **AC-1.5** Given an army When the host adds it in Spain with the north coast chosen Then the response is 422 with "An army doesn't stand on a coast. Leave the coast blank."; and given an army or a fleet in Paris with the north coast chosen Then the response is 422 with "Paris has no north coast."
- [ ] **AC-1.6** Given a province that already holds a unit (any power) When the host adds a unit there Then the response is 422 with "Paris already holds a unit. A province holds one unit." and the position is unchanged
- [ ] **AC-1.7** Given a sea province When the host adds an army Then the response is 422 with "An army can't stand in North Sea: it is a sea province."
- [ ] **AC-1.8** Given a power, type, province, coast or season field that is missing, not one of the offered values, or not a string (a nested hash, an array) When the host submits Then the response is 422 with the matching "Choose ..." sentence of D8, nothing is stored, and no request raises a 500
- [ ] **AC-1.9** Given a fleet and an occupied Paris When the host submits it with the north coast chosen Then the response is "Paris has no north coast.", not the occupied sentence (the earlier stage wins, D5)

### Story 2: The host moves and removes a unit

**As a** host
**I want** to move a unit that is in the wrong place, and remove one that should not be there
**So that** retreats and disbands are in the app

**Acceptance criteria:**

- [ ] **AC-2.1** Given a unit on the board When the host opens its page and moves it to a free province it can stand in Then the stored position holds it there with its power and type unchanged, and the old province is empty
- [ ] **AC-2.2** Given a unit When the host moves it to a province that holds a unit, to a province that can't hold its type, or with a missing or wrong coast Then the response is 422 with the matching sentence of D8 and the position is unchanged
- [ ] **AC-2.3** Given a fleet in Spain on its north coast When the host moves it to Spain's south coast Then the position changes and the record says the coast changed ("from SPA (north coast) to SPA (south coast)"); and When the host moves any unit to where it already is with the same coast Then the response is 422 with "That is already the position." and no record is written
- [ ] **AC-2.4** Given a unit When the host removes it Then it is gone from the stored position, and opening its page again, or removing it again, is the stranger response (there is no unit there)
- [ ] **AC-2.5** Given a province in the path that is not a province of the map, or holds no unit When the host opens it, moves it or removes it Then the response is the stranger response and nothing is written
- [ ] **AC-2.6** Given a fixed sequence of valid and refused edits (adds, moves, removes, owner changes) driven through the forms When each step is made Then after every step the stored position round-trips through the engine's loader unchanged, and every refused step left it unchanged

### Story 3: The host sets who owns a supply center

**As a** host
**I want** to set a supply center's owner
**So that** builds, disbands and captures are right before the next phase

**Acceptance criteria:**

- [ ] **AC-3.1** Given the owners form When the host picks a center and a power Then the stored ownership holds that entry and nothing else changed
- [ ] **AC-3.2** Given the owners form When the host picks a center and "Nobody" Then the entry is removed from the stored ownership
- [ ] **AC-3.3** Given a real province that is not a supply center, a value that is not a province at all, or an unknown power When the host submits Then the response is 422 with "%{province} is not a supply center.", "Choose a province." or "Choose a power." respectively, and nothing is stored
- [ ] **AC-3.4** Given a center already owned by that power (or already unowned) When the host sets it again Then the response is 422 with "That is already the position."
- [ ] **AC-3.5** Given the owners form When the host opens it Then its center list holds exactly the map's 34 supply centers, each by name and abbreviation

### Story 4: The host sets the season and year

**As a** host
**I want** to set the date of the open phase
**So that** the app's turn matches the table's

**Acceptance criteria:**

- [ ] **AC-4.1** Given the date form When the host picks fall and 1901 Then the stored position's season and year change, the phase's `number` does not, and the title the pages show is "Fall 1901 · Movement"
- [ ] **AC-4.2** Given a year that is blank, not a whole number, under 1901 or over 1999 When the host submits Then the response is 422 with the year sentence and nothing is stored
- [ ] **AC-4.3** Given a season that is not spring or fall When the host submits Then the response is 422 with "Choose a season."
- [ ] **AC-4.4** Given the same season and year When the host submits Then the response is 422 with "That is already the position."
- [ ] **AC-4.5** Given a date the host set When the open phase is later revealed Then the next phase follows it (fall becomes spring of the next year)

### Story 5: What the edit does to saved orders

**As a** player
**I want** my orders cleared when the host moves units under them, and to be told
**So that** nothing I entered means something I did not mean

**Acceptance criteria:**

- [ ] **AC-5.1** Given three seats with saved orders, two of them submitted, in the open phase When the host adds, moves or removes a unit Then every seat's saved orders and submissions for the open phase are gone, in the same transaction as the edit, and the revealed phases and their orders are untouched
- [ ] **AC-5.2** Given the same saved orders When the host sets a supply center's owner, or the season and year Then every saved order and every submission is exactly as it was, and no notice is drawn
- [ ] **AC-5.3** Given the same saved orders When an edit is refused (any of Stories 1 to 4) Then no order or submission is cleared
- [ ] **AC-5.4** Given an edit whose record can't be written (the row is forced to fail) When the host submits it Then the position, the orders and the submissions are exactly as they were (the whole edit rolled back)
- [ ] **AC-5.5** Given the status stream When an edit withdraws at least one submission Then one status message is sent after the commit, from `Game#broadcast_seat_status`; when it withdraws none, none is sent; and when the cable call raises the edit still stands
- [ ] **AC-5.6** Given a seat's page and order screen in a phase with one clearing edit When the seat's own phone opens them Then each carries a `.banner` of kind `warning` reading "The host changed the board at <time>. Orders saved before then were cleared, so check yours.", the time from `table_time` inside `<time datetime>`; with two clearing edits it shows the later time only; and a stepped-in page does not draw it
- [ ] **AC-5.7** Given a seat that had saved orders and a seat that had none, in the same phase When each opens its seat page Then the notice's text and markup are identical
- [ ] **AC-5.8** Given a phone that still shows the old board When it saves an order for a unit that an edit moved or removed Then the save is refused with the existing sentence of spec 022 and nothing is stored

### Story 6: Every edit is in the game's history

**As a** table
**I want** the host page to say what was changed, when
**So that** a changed board is never a mystery

**Acceptance criteria:**

- [ ] **AC-6.1** Given a successful edit of each of the five kinds When it is made Then exactly one `position_edits` row exists for it with the phase, the time and the `detail` of D4, and a refused edit writes none
- [ ] **AC-6.2** Given edits, reissues and step-ins in one game, some made in a phase that has since been revealed When the host opens the host page Then the Seat history lists them all together, oldest first, with the order of D4 at the same instant (reissue, step-in, then position edit, then id)
- [ ] **AC-6.3** Given an edit row When the host page draws it Then its line reads the phase title, "board changed", the change in words (for example "France's army added in BUR", "Italy's fleet moved from NAP to ION", "Italy's army in ROM removed", "VEN given to Austria", "VEN set to nobody", "season and year set from Spring 1901 to Fall 1901") and the time in `<time datetime>`
- [ ] **AC-6.4** Given the list When the host page draws it Then its heading, hook and empty text are the ones of spec 026 1.1.0 ("Seat history", `data-seat-history`, "Nothing has happened to a seat yet.") and the existing specs for them pass unchanged
- [ ] **AC-6.5** Given a `PositionEdit` row When a spec updates or destroys it Then it raises (append-only), and a row whose `detail` is not one of the five shapes of D4 is invalid
- [ ] **AC-6.6** Given the history with edits in it, and seats that had ordered different things When the host page draws it Then the page carries no order, count of orders, token, link or submitted state of a seat, and is identical whatever the seats had ordered
- [ ] **AC-6.7** *(source scan, in the step-in boundary spec)* Given the source When the scan runs Then the constant `PositionEdit` is used only in its model, `Game`, the migration and the schema; `Game` has no `through: :position_edits` association; `position_edit.rb` names no `saved_order` or `orders_for`; no view or controller reads `position_edits`; and the table has no column that could hold an order

### Story 7: Only the host, and only the board

**As a** player
**I want** the editor closed to everyone but the host, and showing no order
**So that** order secrecy stays as it is

**Acceptance criteria:**

- [ ] **AC-7.1** Given a stranger, a seat's phone (the host's own seat included, without the host cookie) and another game's host When any editor URL is requested with any of its methods Then the response is the stranger response and nothing is written
- [ ] **AC-7.2** Given the host cookie When a POST, PATCH, PUT or DELETE of the editor is sent with a forged or missing form token Then it is refused and nothing changes
- [ ] **AC-7.3** Given a phase number that is later than, or unknown to, the game, or malformed When the host requests any editor URL Then the response is the stranger response; and given the number of a revealed phase Then the host is redirected (303) to the host page with the `info` banner "That phase was already revealed." and nothing is written
- [ ] **AC-7.4** Given seats that have ordered, submitted, or done neither When the host opens the board page, every form page and every refusal page Then none carries a saved order, a count of orders, an ordered unit, or a submitted state of any seat
- [ ] **AC-7.5** *(route table)* Given the editor's ten routes When the route-table spec runs Then each is classified in `spec/support/secrecy_routes.rb` with `shows: :none` and `revealed: :none`; the board, the add form, a unit's page (for a unit the sweep's context holds), the owners form and the date form are swept as readable GETs and are **not** `numbered` (a revealed number answers a redirect with a flash that a sweep can't compare, as the file's own comment says for the confirmations); the entries for the host page, the seat page and the order screens have their `why` texts updated (board edits in the history; the "board changed" notice); and the routes that may show orders are exactly the same as before
- [ ] **AC-7.6** *(invariance sweep)* Given England's orders go through none, some, all and different, and the viewers of spec 026 (another seat, the host with a seat, the host with no seat, a stranger, the host with France's seat cookie, the host stepped into France) When every editor GET is requested as each viewer Then each viewer's answer is the same whatever England has ordered, and the host page's answer too with a position edit in the history
- [ ] **AC-7.7** Given the stranger comparison of spec 021 When a stranger requests an editor URL and any other unknown path Then the two responses are indistinguishable
- [ ] **AC-7.8** Given each editor page When it is rendered Then its response carries `Cache-Control: no-store` and `Referrer-Policy: no-referrer` and its markup carries the Turbo no-cache meta
- [ ] **AC-7.9** Given the saved-orders boundary spec of spec 022, the order-write scan of spec 023 (`seat_write_scan_spec`) and the status scan of spec 024 When they run Then they pass; the status scan's count of calls to `broadcast_seat_status` changes from two in `game.rb` to three (the edit's call) and no other count changes; and `Game#edit_position!` reads and clears orders only through `Seat#clear_orders!`
- [ ] **AC-7.10** Given the host is stepped into a seat When the host makes an edit Then it is recorded as a position edit like any other, and the step-in bar still shows on the editor pages
- [ ] **AC-7.11** Given an edit and a reveal When the reveal wins the lock first Then the edit raises `Phase::Revealed`, writes nothing, and the host is sent to the host page with "That phase was already revealed."; and given a form for phase N submitted after phase N was revealed (phase N+1 now open) Then phase N+1's position is unchanged
- [ ] **AC-7.12** Given two edits made at once When both run Then the second is built from the position the first stored, and when the first removed the unit the second names, the second is refused as the stranger response and writes nothing (a spec in the style of `spec/models/phase_concurrency_spec.rb`)
- [ ] **AC-7.13** Given a revealed phase When something assigns a different `position` and saves Then the `Phase` model refuses it

### Story 8: The validation and the words come from the engine

**As a** maintainer
**I want** the editor to carry no map rule of its own
**So that** a new map or a gem upgrade needs no change in the editor

**Acceptance criteria:**

- [ ] **AC-8.1** Given each new engine method When it is called with valid arguments Then it returns a position that `RulesEngine.load_position` accepts (a round trip through `to_h`) and leaves the argument position unchanged; and When it is called with each impossible object of the gem's "Impossible objects" that an edit can reach Then it raises `RulesEngine::EditRefused`
- [ ] **AC-8.2** Given each reason of D8 When the matching impossible edit is made Then the error's reason is the one named in D5's stages, and a refusal the stages don't name has the reason `other`
- [ ] **AC-8.3** Given the source When the boundary spec runs Then no file but `rules_engine.rb` names a gem constant, and no view, controller or model other than `RulesEngine` holds a list of provinces, coasts or supply centers (the lists come from `RulesEngine.provinces`, `RulesEngine.supply_centers` and `RulesEngine.coast_name`)
- [ ] **AC-8.4** Given a refusal When the host sees the page Then it shows the sentence of D8 only; the gem's message is neither shown nor logged

### Story 9: The screens at 360 pixels

**As a** host
**I want** every editor page to fit a phone
**So that** I can use them at the table

**Acceptance criteria:**

- [ ] **AC-9.1** *(system spec)* Given a viewport 360 pixels wide, 800 tall When the host opens the board, the add form, the add form refused, a unit's page, the owners form, the date form, the host page with the Seat history and a seat page with the notice Then none scrolls sideways, every button, link, select, input and radio option is at least 44 pixels high, and the page's primary button is visible without scrolling on each form page
- [ ] **AC-9.2** *(system spec)* Given the add form When the host taps "Fleet" Then the Fleet option shows the selected state and the Army option does not, the radio is reachable with the keyboard, a keyboard focus shows a ring from the `focus` token, and the form posts the chosen value with no JavaScript
- [ ] **AC-9.3** Given the eight pages of D10 When the screenshots are taken Then they are saved at 360 pixels to `web/docs/specs/027-position-editor/screens/`, and the pull request shows them
- [ ] **AC-9.4** Given `/styleguide` When the style-guide system spec opens it at 360 and 768 pixels Then it shows `.segmented` (one option selected, and one option focused) and a row of `supply_center_icon` samples without sideways scroll
- [ ] **AC-9.5** Given the stylesheets When the size spec runs Then the total is at most 32,768 bytes and `styleguide.css` at most 6,144 (spec 022 1.2.0's caps)

### Story 10: The documents

**As a** maintainer
**I want** the specs that this feature changes to say so
**So that** no spec lies about what it says

**Acceptance criteria:**

- [ ] **AC-10.1** Given spec 022 When this feature ships Then it is version 1.6.0 and its new changelog row names spec 027 and AC-5.1, and its notes on the editor ("re-checks or clears" and "dislodged units, later") say what this spec decided (clear for units that move; dislodged units left to gem 0.3.0)
- [ ] **AC-10.3** Given spec 024 When this feature ships Then it is version 1.2.0 and its new changelog row names spec 027 and AC-7.9 (`Game#edit_position!` is a third caller of `broadcast_seat_status`), and its AC-2.7(b) is amended to add `Game#edit_position!` to the callers of `broadcast_seat_status` in `game.rb`, and the status scan's example title and its `reissue_seat!` body check stand, with only the count hash going to three
- [ ] **AC-10.2** Given spec 023 When this feature ships Then it is version 1.2.0 and its new changelog row names spec 027 and AC-5.1, and its line about #27 "re-check or clear" says what this spec decided
- [ ] **AC-10.4** Given spec 026 When this feature ships Then it is version 1.2.0 and its new changelog row says its Seat history also lists position edits (spec 027 D4) and its Out of Scope line for #27 now says orders are cleared by edits that move units
- [ ] **AC-10.5** Given `spec/docs/spec_amendments_spec.rb` When this feature ships Then its version assertions for specs 022, 023 and 024 (1.5.0, 1.1.0 and 1.1.0) are changed to the new versions, and examples for the rows of AC-10.1 to AC-10.4 are added
- [ ] **AC-10.6** Given `web/docs/design-system.md` When this feature ships Then the catalog line for `.segmented` says "built" with #27 and its partial `shared/_segmented`, and the design-system spec checks it
- [ ] **AC-10.7** Given `web/README.md` When this feature ships Then it tells the host where the editor is and that an edit that moves units clears everyone's orders

## Functional Requirements

### FR-1: Editing one change

`Game#edit_position!(number, change)` takes the phase lock, rejects a phase that is not the open phase under the lock or is not the number named (D7), asks `RulesEngine` for the new position (D5), refuses a change that changes nothing, stores the position, clears every seat's orders when the change moves units (D3), and writes the `PositionEdit` row. After the commit, if a submission was withdrawn, it calls `broadcast_seat_status` itself, as `reissue_seat!` does. A refused change raises `RulesEngine::EditRefused` with its reason, which the controller turns into the sentence of D8.

### FR-2: The record

`PositionEdit` belongs to a phase and is append-only (D4). `Game#position_edit_history`, `Game#seat_history` and `Game#board_cleared_at` read it.

### FR-3: The pages

The ten routes of D6, behind `require_host`, with the headers of AC-7.8. A page names no gem class and no constant other than its own models.

### FR-4: The engine

The methods and the error of D5, in `RulesEngine`.

### FR-5: Secrecy

Every route is classified. The sweep is extended. The scans are updated (AC-6.7, AC-7.9). No editor page, record, flash, log line or URL carries an order.

## Non-Functional Requirements

### Security

- Host cookie required on every route (spec 021 FR-2). Every write is a POST, PATCH, PUT or DELETE form behind the forgery token.
- The forms' fields are strings; a non-string, a nested hash, or an array in a field is a refusal, not an error.
- An unknown or hostile value never reaches the gem as anything but a string the engine refuses; the host sees only D8's sentences.
- No order appears in the record, the notice, the flash, the log or any URL.

### Reliability

- One edit is one transaction; the lock makes two edits, or an edit and a reveal, happen one after the other (D7).
- A failed cable call never fails a stored edit.
- A stored phase position that can't be loaded is not repaired here (spec 019 FR-5).

### Accessibility and layout

- Every page is a normal page with a heading, a labelled field for every input, and an error banner whose words begin "Error:" (the shared banner partial's own lead for kind `danger`).
- Words carry the meaning: the selected option of `.segmented` is also marked by its radio state, never by colour alone.
- Tap targets are at least 44 pixels. The text is at least 16 pixels. No JavaScript is added.

## Error Scenarios

| Scenario | Expected Behavior |
|----------|-------------------|
| An impossible position (D5, D8) | 422, the same page with D8's sentence, nothing stored, nothing cleared, no record |
| An edit that changes nothing | 422, "That is already the position.", nothing stored, no record |
| The phase was revealed while the host was editing, or the URL names a revealed phase | Redirect (303) to the host page, info banner "That phase was already revealed.", nothing written (D1, D7) |
| A later, unknown or malformed phase number, or a unit page for a province with no unit | The stranger response |
| A stranger, seat or another game's host | The stranger response, nothing written |
| A forged or missing form token | Refused, nothing changes |
| The record can't be written | The whole edit rolls back; the host sees the server error page (it is a bug, not a user mistake) |
| The cable fails after the commit | The edit stands; the failure is logged by class only (spec 024 D7) |
| A phone with an old board saves an order for a unit that moved | The existing refusal of spec 022 |

## Open Questions

1. **Reloading an open order screen after an edit.** The reveal sends a contentless refresh (spec 025 D3). The same message after a clearing edit would reload every open page and show the notice and the new unit lists at once. It would need a second caller of `broadcast_results_refresh` and a change to spec 025's scan (AC-4.6) and to channel code that #105 is editing. Left out; the existing refusal of spec 022 covers a stale save.
2. **The history's name.** "Seat history" now also lists board edits. #112 folds the host page's lists and can rename it. Left alone here so #104's specs stand.
3. **The maintainer's choice at Gate A:** D2 (edit in place, recommended, or a hold), D3 (clear everything that moves units, recommended, or re-check) and D4 (a third table, recommended).

## Out of Scope (Future Considerations)

- A hold state while the host fixes the board (D2 options b and c), if the playtest shows players saving orders too early or the repeated wipes are too costly.
- Re-checking orders instead of clearing them (D3), if clearing proves too costly at a real table.
- Editing dislodged units and standoffs, retreat and adjustment phases (gem 0.3.0, 1.0).
- A reason code on the gem's errors, so the app need not explain a refusal from map queries (an "Adjudicator request", if the maintainer wants one).
- Showing a seat the history of edits to its own units, or any history to every phone.
- A drift check against the board a photo shows (#49) and the changed-after-reveal marker (#47), which can read the `position_edits` rows.
- Folding the three history tables and the host page's lists (#112).

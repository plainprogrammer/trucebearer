# Feature 027: The host's position editor

**Status:** Draft
**Version:** 1.0.0
**Created:** 2026-11-26
**Last Updated:** 2026-11-26
**Issue:** #27
**Branch:** `web/27-position-editor`

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 1.0.0 | 2026-11-26 | First draft |

## Problem Statement

During the playtest the host makes retreats and builds by hand, and later uses the same tool to fix drift between the board on the table and the board in the app (`docs/architecture.md`, "Game rules in the app" and "Targets"). Today nothing lets the host touch the position: after a reveal the game goes straight to the next movement phase (spec 022 D3), dislodged units are off the board, and supply-center ownership is carried over unchanged. The host needs a way to put units where the table says they are, with the map's rules still enforced, and a record the table can read afterwards.

Players can already save orders in the next phase before the host has fixed the board (the comment from #22 on this Issue). So an edit must also say what happens to the orders saved against the old board.

## Goals

- The host can add a unit, move a unit, remove a unit, set who owns a supply center, and set the season and year, all for the **open phase's position**.
- Every edit is built as a new position by the rules engine, so an impossible board (two units in one province, a fleet inland, an army at sea, a missing or wrong coast) is refused with the engine's reason put in plain words, and nothing is stored.
- An edit that changes the units, the season or the year clears every seat's saved orders and submission for the open phase. An edit that only changes who owns a supply center clears nothing. Each seat is told on its own pages. The submitted states on every phone follow through the existing status stream.
- Every edit is recorded in the game's history: what changed, the phase and the time. The host's Seat history list shows it, in the order spec 026 D10 set.
- Only the host reaches the editor. No page of it shows any saved order, and every new route is classified in the secrecy table and covered by the sweep.
- Every step is a normal page with its own URL, works without JavaScript, and fits a phone 360 pixels wide.
- The page set adds the `.segmented` component (army or fleet), used with `supply_center_icon`, and lists both in `/styleguide` and the design-system catalog.

## Non-Goals

- Re-implementing any map rule in the app. The engine decides what a possible position is (D5).
- A "position being fixed" state that stops players saving orders until the host says go. D2 explains the choice and the alternative.
- Editing a revealed phase, or any phase other than the open one.
- Editing dislodged units or standoffs. A movement-phase position has none (the gem refuses them), and every open phase of the playtest is a movement phase.
- Changing a phase's type (movement, retreat, adjustment). Retreat and adjustment phases arrive with gem 0.3.0 and 1.0.
- Undoing an edit. The host edits again.
- Showing the history to anyone but the host. The seats see only that the board changed, and when (D3).
- A live reload of order screens that are already open on a phone (Open Question 2).
- Folding the host page's lists into one (#112), the shared display, the phase clock, any rendered map.
- Any change to `adjudicator/`, `.github/` or the root files.

## Users and Context

**Primary users:** The host, at a physical table, on a phone about 360 pixels wide, moving a retreating army, adding the builds after a fall phase, or fixing a unit that is in the wrong place on the app's board.
**Secondary users:** The players, whose saved orders are cleared by some edits and who are told so.
**Usage context:** Most often right after a reveal, before the players have entered orders for the new phase. Sometimes in the middle of a phase, to correct a mistake.
**User mental model:** "The app's board must match the table. I fix it here, the app refuses anything the map doesn't allow, and everyone re-enters orders if I moved units."

## Decisions

Gate A asks about D2, D3 and D4. D5 is the validation ruling from the maintainer's brief.

**D1. What is edited: the open phase's position, one change at a time.**

- The editor works on `Game#current_phase` and nothing else. Every URL carries the phase number, as the reveal's does (spec 022 D7): a number that is no longer the open phase redirects to the editor of the open phase with a banner, and nothing is written. A later or unknown number is the stranger response.
- **One edit is one change, one form, one record.** The editor's pages are small forms:

| Edit | What the host picks | What changes in the position |
|---|---|---|
| Add a unit | the power, army or fleet, the province, a coast when it needs one | one unit joins `units` |
| Move a unit | the new province, a coast when it needs one | the unit's location changes; its power and type do not |
| Remove a unit | (a button on the unit's page) | the unit leaves `units` |
| Set a supply center's owner | the center, and a power or "nobody" | one entry of `ownership` is set or removed |
| Set the season and year | spring or fall, a year | `season` and `year` change |

- Changing a unit's power or type is a removal and an addition: two edits, two records.
- A province is named by its full name with its abbreviation in the lists ("Burgundy (BUR)"), as spec 023 does.
- The editor never touches `phase` (it stays what it is), `dislodged_units` or `standoffs`.

**D2. "Set the next phase": the game already starts the next movement phase at the reveal, so the editor edits it in place. There is no separate "start" step and no hold. (Gate A)**

The Issue says the host can "set the next phase" and "start the next movement phase after making retreats and builds". Since spec 022 D3 the reveal itself opens the next movement phase at once, so there is nothing left to start. Three readings, argued:

- **(a) Edit in place, no new state. Recommended.** After a reveal, the open phase is the next movement phase (spring becomes fall of the same year, fall becomes spring of the next). The host opens the editor, makes the retreats and builds, and the phase is ready: "set the next phase" is the season-and-year form, for a host whose table is at a different date than the app, and "start the next movement phase" is met by the reveal that opened it. The risk is the one the comment from #22 describes: a player can save orders before the host has fixed the board. D3 handles that with a rule that needs no new state: an edit that changes units, season or year clears the orders. The cost to the table is a player re-entering orders, and only when the host edits after they ordered.
- **(b) A "position being fixed" state.** The reveal would open the next phase on hold. While it is held, saving orders is refused with a plain page and the host page shows "Edit the board" and a "Start Spring 1902 · Movement" button. This matches the Issue's wording most literally and means no player ever saves against a stale board. It costs: a new column and state on `Phase`; a change to `Phase#reveal!` (spec 022 FR-7, D3, and the specs that build on it, 023 and 026); a refusal page on every order route; a second thing the status list and the live refresh must explain; and a button the host must press after **every** reveal, including the ones that need no fixing, which is most of them in the playtest, where the stand-in adjudicator never dislodges anything and no phase needs builds until fall. It also leaves a game stuck on hold if the host forgets.
- **(c) A host-chosen hold: a "hold orders" toggle on the editor.** The host switches the hold on, edits, switches it off. Same costs as (b) except the extra press after every reveal, and a new way for a game to be stuck. Not recommended.

If the maintainer prefers (b), this spec is amended (spec-update) and the plan grows a lifecycle step. Nothing in D1, D3, D4 or D5 changes.

- After a reveal, the host page's flash already says which phase is open now. The host section gets an "Edit the board" link that is always there (D6), and the banner of the reveal does not change.
- The year is a whole number from 1901 to 1999. This is a sanity range for an input, not a rule of the map.

**D3. Saved orders after an edit: an edit that changes units, season or year clears every seat's saved orders and submission for the open phase. An edit that only changes ownership clears nothing. (Gate A)**

- **What is cleared and when.** In the same transaction as the edit, `Seat#clear_orders!` (the method the reissue uses, spec 022 D9) runs for every seat of the game for the open phase. This applies to: add a unit, move a unit, remove a unit, set the season and year. Setting a supply center's owner changes no order's legality (an order is checked against the units and the phase, never against ownership), so it clears nothing and leaves every submission in place.
- **Options not chosen: re-check every saved order against the new position and keep the legal ones.** It keeps more work for the players, and it was weighed seriously. It loses on three grounds:
  1. *Secrecy.* The host causes every edit. A re-check would drop only the orders the edit broke, so what each seat sees afterwards (and, through the live status, what every phone sees) would depend on what each seat had ordered: France's "Submitted" turning into "Not submitted" after the host moves a French army tells everyone France had an order for it. Clearing everything changes every seat's state the same way, whatever it ordered, so the host and the table learn nothing new. Spec 026 and spec 022 FR-9 make "no one learns an order before the reveal, the host included" the rule that decides.
  2. *Meaning.* A kept order can be legal and still mean something else: a support for a unit that moved, or a convoy whose chain was changed by the edit. A player who looks away from the screen for a minute would reveal an order they did not mean. "Everyone re-enters after the board changes" is a rule the table can say out loud.
  3. *Parts.* A re-check needs code that reads every seat's orders in one place before the reveal, which spec 022 FR-9 forbids outside the reveal. Clearing needs only the deletes the reissue already uses.
- **What the host sees.** Every editor page that can clear says, before the host saves, "Saving this clears every seat's saved orders for this phase." The page after a save says the same in the past tense, whether or not any order existed ("Saved. Saved orders for this phase were cleared."). The sentence does not depend on the orders: the host learns nothing about them. An ownership edit's page says "Saved. Orders are kept." The host sees no count, no name, no seat.
- **What a player sees.** On the seat page and on the order screen, a `.banner` (kind `warning`) when the open phase has had at least one clearing edit: "The host changed the board at 8:42 PM UTC. Orders saved before then were cleared, so check yours." It is drawn from the edit records (D4), carries only times (the same `table_time` helper as spec 026 D6) and is the same for every seat, so it says nothing about whether that seat had ordered. Several edits list several times. Seats with the unit count "0 of 3 units ordered" see it too.
- **The status stream.** If the edit withdrew at least one submission, `Game#broadcast_seat_status` is called once after the transaction, as `reissue_seat!` does (spec 024 D3): only a flip of a submitted state is news. A failed cable call never fails a stored edit.
- **What an open order screen does.** A phone that still shows the old board can send a save. `Seat#save_orders!` reads the phase under its lock, so it checks the order against the **new** position and refuses an illegal order with the existing sentence ("You have no unit in BUR."). Nothing changes there. Open Question 2 asks whether to reload open screens.
- **An edit that changes nothing is refused** ("That is already the position."), writes no record and clears nothing, so an accidental double tap does not wipe the table's orders twice.

**D4. History: a third append-only table, `position_edits`, read into the existing Seat history list. (Gate A)**

| Table | Columns | Keys and checks |
|---|---|---|
| `position_edits` (model `PositionEdit`) | `phase_id`, `change` (JSON), `created_at` | `phase_id` is a foreign key, indexed. No `updated_at`. A row never changes and is never deleted (the model refuses both, as `StepIn` and `Reissue` do). `change` is required and is one of the five shapes below |

The five shapes of `change`, written as the same plain data the app stores positions in. Every value is a string or null:

| `kind` | other keys |
|---|---|
| `unit_added` | `power`, `type`, `province`, `coast` |
| `unit_moved` | `power`, `type`, `from`, `to`, `coast` |
| `unit_removed` | `power`, `type`, `province` |
| `owner_set` | `center`, `from` (the old owner, or null), `to` (the new owner, or null) |
| `date_set` | `from_season`, `from_year`, `to_season`, `to_year` |

- **Why a table of its own, and why this shape.** This follows #104's pattern: an append-only table whose rows hold facts and no order, merged into one list in Ruby. The alternatives: a `kind` column on `reissues` or `step_ins` (rejected for the reasons spec 026 D10 gives: those tables mean something different and have a cookie and a lifetime); one `seat_events` table replacing both (a rewrite of #104 and #26 for a gain nobody has asked for yet; #112 or a later Issue may fold the three when it folds the lists); and a text column of finished sentences (it cannot be listed, filtered or re-worded later by #47 and #50; a structured `change` can). The `change` JSON is the fewest parts that keep the facts as facts: a Rails JSON attribute, no second table.
- **What it holds.** Board facts only: which power's unit, which provinces, which owner. No order, no count of orders, no seat's submitted state, no token. A row says nothing about whether the edit cleared orders: whether it did follows from its `kind` (D3), so the row cannot differ with what players had ordered.
- **Written in the edit's transaction.** `Game#edit_position!` takes the phase lock (as a save and a reissue do), builds the new position, stores it, clears the orders when D3 says so, and writes the row, in one transaction. A row that can't be written rolls the whole edit back. A refused edit writes nothing.
- **Which phase** is the open phase the edit ran in. **When** is `created_at`, in UTC.
- **Reads.** `Game#position_edit_history` reads every row whose phase belongs to the game, oldest first, through the game's phases and with no `through:` association, as `step_in_history` and `reissue_history` do. `Game#seat_history` merges it with the other two. Each entry answers `kind` (`:position_edit` here; `:step_in` and `:reissue` as today) and its own `phase`, `created_at` and `id`, so the list partial names no constant.
- **Order of the list: #104's order, extended.** Oldest first by `created_at`; at the same instant a reissue comes before a step-in (spec 026 D10), and a position edit comes after both, then by id. The order is stable.
- **The row on the host page.** In the Seat history list: the phase title, the words "board changed", and the change in words, then the time: "Fall 1901 · Movement · board changed: France's army added in BUR · 8:42 PM UTC". The list keeps its heading, "Seat history", its hook `data-seat-history` and its empty text, so #104's specs stand. Its name is now a little narrow, since it also holds board edits; #112 can rename it when it folds the host page's lists (Open Question 3).
- **A changed date and old titles.** A row shows its phase's title as it is when the page is drawn. After a date edit, earlier rows of the same phase carry the new title, and the date edit's own row says "season and year set from Spring 1901 to Fall 1901". The phase's number never changes.
- **Who sees the history: only the host**, on the host page. Seats see only the notice of D3.

**D5. Validation comes from the rules engine. Each edit builds a new position there.**

- `RulesEngine` gets a small set of methods and nothing else in the app names a gem class. Each takes the open position and plain values (strings) and returns the new position, or raises `RulesEngine::InvalidInput` with the engine's message:
  - `RulesEngine.add_unit(position, power:, type:, province:, coast:)`
  - `RulesEngine.move_unit(position, from:, province:, coast:)`
  - `RulesEngine.remove_unit(position, province:)`
  - `RulesEngine.set_owner(position, center:, power:)` (a nil power removes the entry)
  - `RulesEngine.set_date(position, season:, year:)`
  - the lists the forms need: `RulesEngine.provinces` (each with its id, full name and coasts) and `RulesEngine.supply_centers` (identifiers), both read from the map, in the map's order, which is by identifier; the province list shown in the forms is sorted by name in the view.
- These are **new methods in `rules_engine.rb`**. #29 (the gem upgrade) also edits that file, so the pull request says so, and `main` is merged when told. The methods use only what gem 0.1.0 documents (`TA::Position.new`, `TA::Unit.new`, `TA::Location.new`, `Map#provinces`, `Map#supply_centers`) and need nothing from 0.2.0, so #29 should keep them as they are.
- **No map rule is written in the app.** The position the gem builds is the one rule: one unit per province, no fleet inland, no army at sea, a coast exactly when a fleet is in a split-coast province, an owner only for a supply center. The forms offer every province and let the engine refuse (the host sees why), instead of the app filtering lists by rules it would have to know.
- **Plain words from the engine's reason (D8).** An `InvalidInput` message is turned into a short sentence by one function in `RulesEngine` that returns a **reason symbol** and one table in the app that turns a symbol and the names the host picked into words. The messages are not part of the gem's documented contract, so a spec builds each impossible position listed in the gem's "Impossible objects" and checks that each message maps to its own reason; a message the table does not know becomes the generic sentence. A gem upgrade that rewords a message fails that spec, which is what #29 needs to see. Open Question 1 asks the maintainer for structured reasons from the gem.

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
| | `/owners` | POST | Sets it, or shows the form again with the reason |
| Season and year | `/date` | GET | The form |
| | `/date` | PUT | Sets it, or shows the form again with the reason |

- A successful edit redirects (303) to the board page with a `.banner` of kind `info` that says what changed in words and the sentence of D3.
- A refused edit answers 422 with the same page and a `.banner` of kind `danger` holding the plain sentence, and keeps what the host picked in the form.
- **The host's way in.** The host section of the host page gets one link, "Edit the board", beside "Reveal orders". It is there in every state. The host page's other lists are not changed (#112).
- **Every page** carries `Cache-Control: no-store`, the Turbo no-cache meta and `Referrer-Policy: no-referrer`, like the other host pages that sit under the seat history.
- **Host only.** Every route behind `require_host`: a stranger, a seat or another game's host gets the stranger response and nothing is written (spec 021 D4).
- Phone and Native: each is a normal Turbo Drive page with a meaningful URL. No Stimulus controller and no JavaScript are added.

**D7. Concurrency: the phase lock decides, the reveal wins.**

An edit and a reveal, or two edits, at the same moment: `Game#edit_position!` takes the phase lock first and reads the open phase under it, as `Seat#save_orders!` and `Game#reissue_seat!` do. If the phase was revealed in the meantime it raises `Phase::Revealed`, the host is sent to the host page with "That phase was already revealed." and nothing is written. A saved order can't be written to a revealed phase, and a position can't be changed on one: the `Phase` model refuses a changed `position` once `revealed_at` is set.

**D8. The words.** Every sentence below is original wording for this app, cites no rulebook and names no section. `%{unit}` is "an army" or "a fleet", and a province is its full name.

| Reason | Sentence |
|---|---|
| unit on a sea province (army) | "An army can't stand in %{province}: it is a sea province." |
| fleet inland | "A fleet can't stand in %{province}: it is inland." |
| fleet needs a coast | "A fleet in %{province} must say which coast it is on." |
| army with a coast | "An army doesn't stand on a coast. Leave the coast blank." |
| coast not in that province | "%{province} has no %{coast} coast." |
| province taken | "%{province} already holds a unit. A province holds one unit." |
| owner of a non-center | "%{province} is not a supply center." |
| nothing changed | "That is already the position." |
| anything else the engine refuses | "That isn't possible on the map." |
| an unknown or missing choice | "Choose a power." (or "Choose a province.", "Choose a season.") |
| a year out of range | "The year must be a whole number from 1901 to 1999." |

**D9. The `.segmented` component.** A fieldset with a legend and two or more radio inputs, each in a label, drawn as joined buttons. It is built in `shared/_segmented` with locals `legend`, `name`, `options` (value and label pairs) and `selected`. The radios stay real radios (keyboard, form post and screen readers work with no script). The selected option uses the `primary` fill with `on-primary` text; the others use `surface` with `text` and the `border` edge; each is at least 44 pixels tall; the focus ring is the `focus` token. It adds no color token and no pair: it uses documented ones. It is added to `/styleguide` and to the catalog line for #27 in `web/docs/design-system.md`, which says "built".

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

- [ ] **AC-1.1** *(the first test, a request spec)* Given a new game whose host is signed in on the open phase When the host adds an army in Burgundy to France Then the response redirects to the board page, the open phase's stored position holds a French army in BUR, and when the host then adds a fleet in Burgundy for France the response is 422, the page's banner reads "A fleet can't stand in Burgundy: it is inland.", and the stored position is unchanged
- [ ] **AC-1.2** Given the add form When the host adds a unit Then the form's fields are `unit[power]`, `unit[type]` (a `.segmented` of army and fleet, army selected by default), `unit[province]` and `unit[coast]` (blank by default), and the page works with no JavaScript
- [ ] **AC-1.3** Given a fleet added to a province with split coasts (Spain) with the south coast chosen Then the unit is stored with that coast; with no coast chosen the response is 422 with "A fleet in Spain must say which coast it is on."
- [ ] **AC-1.4** Given an army added with a coast chosen Then the response is 422 with the army sentence, and a coast that the province doesn't have gives "%{province} has no %{coast} coast."
- [ ] **AC-1.5** Given a province that already holds a unit (any power) When a unit is added there Then the response is 422 with "Paris already holds a unit. A province holds one unit." and the position is unchanged
- [ ] **AC-1.6** Given a sea province When an army is added Then the response is 422 with the sea sentence
- [ ] **AC-1.7** Given a power, type, province or coast that is missing, not one of the choices, or not a string Then the response is 422 with the "Choose ..." sentence and nothing is stored, and no request raises a 500

### Story 2: The host moves and removes a unit

**As a** host
**I want** to move a unit that is in the wrong place, and remove one that should not be there
**So that** retreats and disbands are in the app

**Acceptance criteria:**

- [ ] **AC-2.1** Given a unit on the board When the host opens its page and moves it to a free province it can stand in Then the stored position holds it there with its power and type unchanged, and the old province is empty
- [ ] **AC-2.2** Given a move to a province that holds a unit, to a province that can't hold its type, or with a missing or wrong coast Then the response is 422 with the matching sentence of D8 and the position is unchanged
- [ ] **AC-2.3** Given a move to the unit's own province with the same coast Then the response is 422 with "That is already the position." and no record is written
- [ ] **AC-2.4** Given a unit When the host removes it Then it is gone from the stored position, and removing it again is the stranger response (the page is for a unit that is no longer there)
- [ ] **AC-2.5** Given a province in the path that is not a province of the map, or holds no unit Then the page and the PATCH and DELETE give the stranger response and write nothing
- [ ] **AC-2.6** Given a seeded sequence of valid and invalid edits (adds, moves, removes, owner changes) driven through the forms Then after every step the stored position is one the engine can load (`load_position` of its `to_h` equals it), and every refused step left it unchanged; no map rule is repeated in the spec's expectations beyond what the gem's documentation lists

### Story 3: The host sets who owns a supply center

**As a** host
**I want** to set a supply center's owner
**So that** builds, disbands and captures are right before the next phase

**Acceptance criteria:**

- [ ] **AC-3.1** Given the owners form When the host picks a center and a power Then the stored ownership holds that entry and nothing else changed
- [ ] **AC-3.2** Given the owners form When the host picks a center and "Nobody" Then the entry is removed from the stored ownership
- [ ] **AC-3.3** Given a province that is not a supply center, or an unknown power Then the response is 422 with "%{province} is not a supply center." or "Choose a power." and nothing is stored
- [ ] **AC-3.4** Given a center already owned by that power (or already unowned) When the host sets it again Then the response is 422 with "That is already the position."
- [ ] **AC-3.5** Given the owner form's list Then it lists exactly the map's 34 supply centers, each by name and abbreviation

### Story 4: The host sets the season and year

**As a** host
**I want** to set the date of the open phase
**So that** the app's turn matches the table's

**Acceptance criteria:**

- [ ] **AC-4.1** Given the date form When the host picks fall and 1901 Then the stored position's season and year change, the phase's `number` does not, and the title the pages show is "Fall 1901 · Movement"
- [ ] **AC-4.2** Given a year that is blank, not a whole number, under 1901 or over 1999 Then the response is 422 with the year sentence and nothing is stored
- [ ] **AC-4.3** Given a season that is not spring or fall Then the response is 422 with "Choose a season."
- [ ] **AC-4.4** Given the same season and year Then the response is 422 with "That is already the position."
- [ ] **AC-4.5** Given the open phase is later revealed Then the next phase follows the date the host set (fall becomes spring of the next year), as it does for any position

### Story 5: What the edit does to saved orders

**As a** player
**I want** my orders cleared when the host changes the board under them, and to be told
**So that** nothing I entered means something I did not mean

**Acceptance criteria:**

- [ ] **AC-5.1** Given three seats with saved orders, two of them submitted, in the open phase When the host adds, moves or removes a unit, or sets the season and year Then every seat's saved orders and submissions for the open phase are gone, in the same transaction as the edit, and the revealed phases and their orders are untouched
- [ ] **AC-5.2** Given the same saved orders When the host only sets a supply center's owner Then every saved order and every submission is exactly as it was
- [ ] **AC-5.3** Given an edit that is refused (any of Stories 1 to 4) Then no order or submission is cleared
- [ ] **AC-5.4** Given an edit whose record can't be written Then the position, the orders and the submissions are exactly as they were (the whole edit rolled back)
- [ ] **AC-5.5** Given the status stream When an edit withdrew at least one submission Then one status message is sent after the commit, from `Game#broadcast_seat_status`; when it withdrew none, none is sent; and a failing cable call does not fail the edit
- [ ] **AC-5.6** Given a seat's page and order screen in a phase with one clearing edit Then each carries a `.banner` of kind `warning` reading "The host changed the board at <time>. Orders saved before then were cleared, so check yours.", with the time from `table_time` inside `<time datetime>`, and a phase with two clearing edits lists both times
- [ ] **AC-5.7** Given an ownership-only edit Then no notice is drawn
- [ ] **AC-5.8** Given the notice Then its text and markup are identical for a seat that had saved orders and a seat that had none
- [ ] **AC-5.9** Given a phone that still shows the old board When it saves an order for a unit that the edit moved or removed Then the save is refused with the existing sentence of spec 022 and nothing is stored

### Story 6: Every edit is in the game's history

**As a** table
**I want** the host page to say what was changed, when
**So that** a changed board is never a mystery

**Acceptance criteria:**

- [ ] **AC-6.1** Given a successful edit of each of the five kinds Then exactly one `position_edits` row exists for it with the phase, the time and the `change` of D4, and a refused edit writes none
- [ ] **AC-6.2** Given edits, reissues and step-ins in one game Then the host page's Seat history lists them together, oldest first, with the order of D4 at the same instant (reissue, step-in, then position edit, then id), and an edit in a revealed phase stays in the list
- [ ] **AC-6.3** Given an edit row Then its line reads the phase title, "board changed", the change in words (for example "France's army added in BUR", "Italy's fleet moved from NAP to ION", "Italy's army in ROM removed", "VEN given to Austria", "VEN set to nobody", "season and year set from Spring 1901 to Fall 1901") and the time in `<time datetime>`
- [ ] **AC-6.4** Given the list's heading, hook and empty text Then they are the ones of spec 026 1.1.0 ("Seat history", `data-seat-history`, "Nothing has happened to a seat yet.") and its existing specs pass unchanged
- [ ] **AC-6.5** Given a `PositionEdit` row Then updating or destroying it raises (append-only), its `change` must be one of the five shapes with string or null values, and its phase must belong to a game
- [ ] **AC-6.6** Given the history Then it carries no order, count of orders, token, link, or submitted state, whatever the seats had ordered
- [ ] **AC-6.7** *(source scan, in the step-in boundary spec)* Given the source Then the constant `PositionEdit` is used only in its model, `Game`, the migration and the schema; `Game` has no `through: :position_edits` association; `position_edit.rb` names no `saved_order` or `orders_for`; no view or controller reads `position_edits`; and the table has no column that could hold an order

### Story 7: Only the host, and only the board

**As a** player
**I want** the editor closed to everyone but the host, and showing no order
**So that** order secrecy stays as it is

**Acceptance criteria:**

- [ ] **AC-7.1** Given a stranger, a seat's phone (the host's own seat included, without the host cookie) and another game's host When any editor URL is requested with any method Then the response is the stranger response and nothing is written
- [ ] **AC-7.2** Given the host cookie and a forged or missing form token on a POST, PATCH, PUT or DELETE Then it is refused and nothing changes
- [ ] **AC-7.3** Given a phase number that is later than, or unknown to, the game, or malformed Then the response is the stranger response; given the number of a revealed phase Then the host is redirected to the editor of the open phase with "That phase was already revealed." and nothing is written
- [ ] **AC-7.4** Given the board page, every form page and every refusal page Then none carries a saved order, a count of orders, an ordered unit, or a submitted state of any seat, whatever the seats had ordered
- [ ] **AC-7.5** *(route table)* Given the editor's ten routes Then each is classified in `spec/support/secrecy_routes.rb` with `shows: :none`; the board, the add form, a unit's page, the owners form and the date form are swept as readable GETs; the route table spec still lists exactly the same routes that may show orders as before
- [ ] **AC-7.6** *(invariance sweep)* Given England's orders go through none, some, all and different, and the viewers of spec 026 (another seat, the host with a seat, the host with no seat, a stranger, the host with France's seat cookie, the host stepped into France) Then every editor GET answers each viewer identically whatever England has ordered
- [ ] **AC-7.7** Given the stranger comparison of spec 021 Then it sees no difference between a stranger asking for an editor URL and any other unknown path, as for the other host pages
- [ ] **AC-7.8** Given the source Then every editor page carries `Cache-Control: no-store`, `Referrer-Policy: no-referrer` and the Turbo no-cache meta
- [ ] **AC-7.9** Given the saved-orders boundary spec of spec 022, the order-write scan of spec 023 (`seat_write_scan_spec`) and the status scan of spec 024 Then they pass; the status scan's count of calls to `broadcast_seat_status` changes from two in `game.rb` to three (the edit's call) and no other count changes; and `Game#edit_position!` reads and clears orders only through `Seat#clear_orders!`
- [ ] **AC-7.10** Given the step-in of spec 026 Then an edit made while the host is stepped into a seat is the host's edit, not the seat's: it is recorded as a position edit and the step-in bar still shows

### Story 8: The validation and the words come from the engine

**As a** maintainer
**I want** the editor to carry no map rule of its own
**So that** a new map or a gem upgrade needs no change in the editor

**Acceptance criteria:**

- [ ] **AC-8.1** Given the engine's new methods Then each returns a position that `RulesEngine.load_position` accepts (round trip through `to_h`), leaves the argument position unchanged, and raises `RulesEngine::InvalidInput` for each impossible object of the gem's "Impossible objects" that an edit can reach
- [ ] **AC-8.2** Given each of those reasons Then the reason function maps the gem 0.1.0 message to the reason of D8, and a message it doesn't know to the generic reason, and a spec lists each pair so a gem upgrade that rewords one fails
- [ ] **AC-8.3** Given the source Then no file but `rules_engine.rb` names a gem constant (the boundary spec passes), and no view, controller or model other than `RulesEngine` lists provinces, coasts, or which provinces are inland, coastal, sea or supply centers
- [ ] **AC-8.4** Given a message from the engine Then the host never sees it: the pages show the sentence of D8 only, and no log line carries a position or a message

### Story 9: The screens at 360 pixels

**As a** host
**I want** every editor page to fit a phone
**So that** I can use them at the table

**Acceptance criteria:**

- [ ] **AC-9.1** *(system spec)* Given a viewport 360 pixels wide When the host opens the board, the add form, the add form refused, a unit's page, the owners form, the date form, the host page with the Seat history and a seat page with the notice Then none scrolls sideways, every button, link, select, input and radio option is at least 44 pixels high, and the page's primary button is visible without scrolling on each form page
- [ ] **AC-9.2** *(system spec)* Given the add form When the host chooses army or fleet with a tap Then the selected option shows the selected state, the radio is reachable by keyboard, and the form posts the chosen value with no JavaScript; `.segmented` has a visible focus ring from the `focus` token
- [ ] **AC-9.3** Given the eight pages of D10 Then screenshots at 360 pixels are saved to `web/docs/specs/027-position-editor/screens/`, and the pull request shows them
- [ ] **AC-9.4** Given `/styleguide` Then it shows `.segmented` (with, selected, and focused options) and a `supply_center_icon` row, and the style-guide system spec checks them at 360 and 768 pixels

### Story 10: The documents

**As a** maintainer
**I want** the specs that this feature changes to say so
**So that** no spec lies about what it says

**Acceptance criteria:**

- [ ] **AC-10.1** Given spec 022 Then its note that an edit "re-checks or clears" the open phase's orders (D3 and the Issue comment) records the answer: a clearing edit clears every seat's orders (this spec's D3), in a new changelog row that names spec 027 and AC-5.1
- [ ] **AC-10.2** Given spec 024 Then its AC-2.7 records that `Game#edit_position!` is a third caller of `broadcast_seat_status`, in a new changelog row that names spec 027 and AC-7.9
- [ ] **AC-10.3** Given spec 026 Then its Out of Scope line for #27 and its seat-history description record that the list now also holds position edits (spec 027 D4), in a new changelog row
- [ ] **AC-10.4** Given `web/docs/design-system.md` Then the catalog line for `.segmented` says "built" with #27, its partial `shared/_segmented`, and a design-system spec checks it
- [ ] **AC-10.5** Given `web/README.md` Then it tells the host where the editor is and that a clearing edit clears everyone's orders

## Functional Requirements

### FR-1: Editing one change

`Game#edit_position!(phase, change)` takes the phase lock, rejects a revealed phase (D7), asks `RulesEngine` for the new position (D5), refuses a change that changes nothing, stores the position, clears every seat's orders when the change is a clearing kind (D3), writes the `PositionEdit` row, and returns what the controller needs (the new position, and whether a submission was withdrawn). After the commit, if a submission was withdrawn, it calls `broadcast_seat_status`. A refused change raises one error class that carries the sentence of D8.

### FR-2: The record

`PositionEdit` belongs to a phase and is append-only (D4). `Game#position_edit_history` and `Game#seat_history` read it.

### FR-3: The pages

The ten routes of D6, behind `require_host`, with the headers of AC-7.8. A page names no gem class and no constant other than its own models.

### FR-4: The engine

The methods of D5 and the reason function, in `RulesEngine`.

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

- Every page is a normal page with a heading, a labelled field for every input, and an error banner that begins with the word "Error:" for the screen reader (the shared banner partial's own lead for kind `danger`).
- Words carry the meaning: the selected option of `.segmented` is also marked by its radio state, never by colour alone.
- Tap targets are at least 44 pixels. The text is at least 16 pixels. No JavaScript is added.

## Error Scenarios

| Scenario | Expected Behavior |
|----------|-------------------|
| An impossible position (D5, D8) | 422, the same page with D8's sentence, nothing stored, nothing cleared, no record |
| An edit that changes nothing | 422, "That is already the position.", nothing stored, no record |
| The phase was revealed while the host was editing | Redirect to the host page, "That phase was already revealed.", nothing written (D7) |
| A stale phase number that is now a revealed phase | Redirect to the editor of the open phase with a banner, nothing written |
| A later, unknown or malformed phase number, or a unit page for a province with no unit | The stranger response |
| A stranger, seat or another game's host | The stranger response, nothing written |
| A forged or missing form token | Refused, nothing changes |
| The record can't be written | The whole edit rolls back; the host sees the server error page (it is a bug, not a user mistake) |
| The cable fails after the commit | The edit stands; the failure is logged by class only (spec 024 D7) |
| A phone with an old board saves an order for a unit that moved | The existing refusal of spec 022 |

## Open Questions

1. **Structured reasons from the gem.** The plain words rest on matching the gem's 0.1.0 messages (D5), which the gem does not document. Should an "Adjudicator request" Issue ask for a reason code on `InvalidInput` for impossible objects? Not needed to close this Issue; the pinned spec makes a reworded message fail loudly.
2. **Reloading an open order screen after an edit.** The reveal sends a contentless refresh (spec 025 D3). The same message after a clearing edit would reload every open page and show the notice and the new unit lists at once. It would need a second caller of `broadcast_results_refresh` and a change to spec 025's scan (AC-4.6) and to channel code that #105 is editing. Left out; the existing refusal of spec 022 covers a stale save.
3. **The history's name.** "Seat history" now also lists board edits. #112 folds the host page's lists and can rename it. Left alone here so #104's specs stand.
4. **The maintainer's choice at Gate A:** D2 (edit in place, recommended, or a hold) and D3 (clear everything, recommended, or re-check).

## Out of Scope (Future Considerations)

- A hold state while the host fixes the board (D2 option b), if the playtest shows players saving orders too early.
- Re-checking orders instead of clearing them (D3), if clearing proves too costly at a real table.
- Editing dislodged units and standoffs, retreat and adjustment phases (gem 0.3.0, 1.0).
- Showing a seat the history of edits to its own units, or any history to every phone.
- A drift check against the board a photo shows (#49) and the changed-after-reveal marker (#47), which can read the `position_edits` rows.
- Folding the three history tables and the host page's lists (#112).

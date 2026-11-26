# Feature 023: Enter movement orders with pickers

**Status:** Approved
**Version:** 1.2.0
**Created:** 2026-11-26
**Last Updated:** 2026-11-26
**Issue:** #23
**Branch:** `web/23-order-pickers`

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 1.2.0 | 2026-11-26 | Amended by spec 027 (the position editor, #27).<br>• The note about #27 is decided (spec 027 D3, AC-5.1): an edit that moves units clears every seat's saved orders and submission, so a phone that still shows the old board is refused by the existing save check (spec 022 D4). The order screen gains one banner, spec 027's notice that the host moved units (`positions/_notice`, drawn only on a seat's own screen); no picker, endpoint or other screen changes. |
| 1.1.0 | 2026-11-26 | Amended by spec 025 (reveal results to every phone, #25): AC-2.13 is read as "given a revealed phase, a `GET` of any step URL on a seat's own address is a 303 to that phase's results page, before the province is looked at" (it was the 409 page). A `PUT` keeps its 409, a stepped-in step URL keeps the 409 page, and a phase number later than the open one or unknown is still the stranger response. The order screen and the picker also subscribe to the results stream (spec 025 D2). Every other criterion holds unchanged |
| 1.0.3 | 2026-11-26 | Refinements found while planning, within what Gate A approved: the draft has three keys, `draft[kind]`, `draft[target]` and `draft[to]` (the coast step and the by-land-or-convoy step are reached from `kind=move&to=...`, and their choices are the final saves, so `draft[coast]` and `draft[via]` are not needed); a fleet's move to a split-coast province with exactly one reachable coast still saves from the destination row, and the row's note names the coast so the player sees what will be saved |
| 1.0.2 | 2026-11-26 | Changed after the second Fable review: the list's `.save-status` has a defined resting text (D6, AC-1.8); the "needs a convoy" mark is applied by an order helper that is given the unit, armies only (FR-3, AC-1.9); the two new `RulesEngine` methods are named as added by this feature and covered by the boundary spec (FR-3); "Saving…" without `:has` leaves the resting text (D6); the deploy-note claim is dropped; smaller wording fixes |
| 1.0.1 | 2026-11-26 | Changed after the first Fable review: the draft's log and referrer limits are stated (FR-8); the "Not submitted" words stay in the submit bar (D9, AC-8.1); the sweep may list several paths per route (AC-5.2); the walk-through is a mixed set with its per-order costs, 18 taps and 45 seconds (D7); "needs a convoy" and "by convoy" mean different things (D3); "Saving…" is two spans (D6); a complete draft is sent back to step 1 (D2); choice order is fixed (D1) |
| 1.0.0 | 2026-11-26 | First draft |

## Problem Statement

Spec 022 gave a seat a working but plain way to save orders: one `<select>` per unit on one page. It proves the saving rules and nothing more. At a table, a player has a phone, one hand free and a conversation going. The screen must let them order a whole power in about a minute, with only legal choices on offer, and with nothing lost if the connection drops halfway. This is the screen that has to beat paper.

## Goals

- A seat sees its own units in a list, each with its current order, and a unit with no order says "holds".
- A player picks an order a step at a time: the unit; then hold, move, support or convoy; then the destination. For a support, the supported unit comes first and then its destination or "hold". Every choice offered is one of the gem's legal orders for that unit, so an illegal order cannot be built.
- Each order is saved the moment it is picked, one unit at a time, through the saving rules of spec 022.
- A submit bar shows how many units have orders ("3 of 5 ordered") and submits the seat. Changing an order after submitting returns the seat to "not submitted" (spec 022, unchanged).
- The player stays on the order screen until they submit.
- No page shows another power's orders. Every new route is classified, swept and scanned as spec 022 requires.
- Every step is a normal page with its own URL, works without JavaScript, and is ready for a Hotwire Native path configuration.
- A full set of orders for a five-unit power can be entered at 360 pixels in a system-spec walk-through, within a stated number of taps and a stated time.

## Non-Goals

- Live status of who has submitted (#24), the reveal screen (#25) and stepping into another seat (#26).
- Any change to `adjudicator/`. The app stays pinned to gem 0.1.0, and every choice comes from `RulesEngine.legal_orders`.
- A saved draft of an unfinished order. A half-built order is not an order and is never stored (D2).
- A map, a drag-and-drop interface, undo history, or any bridge component for Hotwire Native.
- Showing the supported or convoyed unit's own order to anyone. The pickers show where units stand (public, from the position), never what anyone has ordered but the viewer (FR-8).

## Users and Context

**Primary users:** A player, on a phone about 360 pixels wide, entering orders for their power while the table talks.
**Secondary users:** A host who also holds a seat. A player on a poor connection. A player who uses a screen reader or zooms the text.
**User mental model:** "I tap a unit, say what it does, say where. It's saved. When all my units are set I tap submit. I can still change my mind until the host reveals."

## Decisions

Gate A asks about D1, D3, D4, D5 and D7.

**D1. The picker steps.** The order screen is the list of the seat's units. Each unit leads into a short chain of pages. Each page is a `GET`; only the last pick of a chain is a write.

| Step | Page asks | Choices (all from `legal_orders` for the unit) | Next |
|---|---|---|---|
| 0. The list | (the order screen) | One `.unit-row` per unit, with the current order or "holds" | A unit row leads to step 1 |
| 1. Action | "What should it do?" | **Hold**; **Move**, **Support** and **Convoy**, each only if the unit has at least one such legal order; **No order (holds)**, only when the unit has a saved order | Hold and No order save. The others lead on |
| 2m. Move: where | "Move where?" | Each destination province the unit's moves reach, once | See 3m and 3v. Saves when there is only one way to get there |
| 3m. Move: which coast | "Which coast?" | The coasts the unit can reach in that province | Saves |
| 3v. Move: by land or by convoy | "How does it get there?" | "By land" (the plain move) and "By convoy" (the move via convoy) | Saves |
| 2s. Support: which unit | "Support which unit?" | Each unit that appears as a supported unit in the unit's support orders, once, with its type, province and power | 3s |
| 3s. Support: how | "Support it how?" | "Hold in place" (a support to hold) when that order is legal, then each destination of a support to move | Saves |
| 2c. Convoy: which army | "Convoy which army?" | Each army that appears as the convoyed unit in the unit's convoy orders, once | 3c |
| 3c. Convoy: where | "Convoy it where?" | Each destination for that army | Saves |

The six order shapes of the gem (hold, move, move via convoy, support hold, support move, convoy) are all there is, so these steps cover every legal order. Steps 2m to 3c appear only when the unit's own `legal_orders` has something to choose from. A step with exactly one choice is still shown, because skipping it would hide a decision and it costs one tap. A destination row whose province has exactly one order is a button that saves it; a row whose province has several orders is a link to step 3m (coasts) or 3v (land or convoy), as D3 sets out.

**Order of choices.** On every step the choices come in the order of their first appearance in the gem's `legal_orders` list (`interface.md`, "List order"), after Hold on step 1, which is fixed as Hold, Move, Support, Convoy, then No order. So the order is deterministic and follows the abbreviation order the gem uses.

Every option shows the province's full name with its abbreviation, as "Liverpool (LVP)", the abbreviation in the mono face. The saved value of the final choice is the legal order's hash form as JSON, the same value the plain form of spec 022 posted.

**D2. How a step knows what has been chosen: the draft is in the URL, not in the database.** The unit is in the path, `/games/:public_id/phases/:number/orders/:province`. The choices so far are in the query as `draft[kind]`, `draft[target]` and `draft[to]`. Nothing is stored until the last pick, so a dropped connection loses at most one half-made order, and a half-made order is never counted, shown to anyone, or adjudicated. The options were: a draft row per seat (a new table, a second write path and a second thing the reveal must ignore: rejected), a cookie or the session (invisible to a Turbo Native route and lost across tabs: rejected), and the URL (chosen: every step is a normal link, shareable only with oneself, and back-button correct). The draft is the viewer's own and is filtered from Rails' logs (FR-8, which also states what that does not reach). A draft value that does not name a legal choice is never trusted or echoed: the page sends the player back to step 1 (AC-2.11). A draft that already names a whole order (a hold, or a move whose destination has one order) is also sent back to step 1: a `GET` never saves.

**D3. Convoys and split coasts each get a clear step.** The gem lists, for one unit, plain moves, moves via convoy, and one move per reachable coast (`interface.md`, "Legal orders"). The app groups them by destination province:

- **A split-coast province** (Bulgaria, Spain, St Petersburg) reached by a fleet has two or one coast options. The destination step lists the province once. If the unit has more than one move to that province, a step "Which coast?" follows, listing "North coast (NC)", "South coast (SC)" or "East coast (EC)". If the unit has exactly one move to it, that step is skipped and the pick saves straight from the destination row, whose note names the coast ("north coast") (the gem offers only coasts the fleet can reach, so the player is never asked to choose an impossible coast).
- **A province an army can reach by land and by a convoy chain** has two orders: a plain move and a move via convoy. The destination step lists the province once and a step "How does it get there?" follows, with "By land" and "By convoy". "By convoy" is the move via convoy. Armies never meet coasts, and fleets never meet this step, so no destination needs both.
- **A province an army can reach only through a convoy chain** has only a plain move in the gem's list (it is legal because a chain exists). Its row on the destination step is marked "needs a convoy" in plain words (and its order reads "Move to Norway (NWY), needs a convoy" in the list), so the player knows the move depends on fleets, and picking it saves the plain move. "By convoy" is kept for the one thing it means, the move via convoy. The mark needs to know whether the army could walk there, which is one adjacency query on the map, added to `RulesEngine` as `army_adjacent?` (the interface has `Map#adjacent?`, so nothing beyond it is used).

The saved order is always exactly one of the gem's orders for the unit. The player is never shown a choice the gem would not list, and every order the gem lists can be reached (AC-2.10 proves both).

**D4. The plain form is removed.** Spec 022 D5 and its Non-Goals say #23 replaces it. Keeping two ways to enter orders would double the screens to test, review for secrecy, and explain. The `<select>` form, its two buttons ("Save orders", "Save and submit") and its "n of m units ordered" line go. Reasons not to keep it as a fallback: every picker step already works without JavaScript (D5), so the form's one claim, a no-frills path, is already covered; and a form that posts many orders at once is the shape a half-made order could come from. What stays: the `PUT /games/:public_id/phases/:number/orders` endpoint with its partial-update meaning and every refusal, which is how every pick is saved. One behavior of spec 022 changes with the removal and is amended there (changelog 1.3.0): a plain save no longer sets a flash banner "Orders saved."; the saved state is shown by `.save-status` instead (D6). The "Submitted." banner stays.

**D5. JavaScript: none is needed, and none is added.** Every pick that is not the last is a link. The last pick, and Submit, are small forms that the browser submits (Rails writes the `PUT` as a hidden `_method` field in a `POST` form). There is no new Stimulus controller, no new import-map pin and no Turbo Frame: a frame would only make a step replace part of a page, and each step is already a whole, small page, so Turbo Drive (already in the app, and what makes navigation quick) is enough. That means the screens work in a browser with JavaScript off, and they are Hotwire Native ready by construction: each step is a URL a path configuration can route (to a modal later, if wanted), and nothing depends on a feature a web view lacks. The one thing that needs Turbo is the word "Saving…" (D6), and it degrades to nothing.

**D6. "Saved" and "Saving…".** Saving happens on each pick: the last pick of a chain is a form, and it saves, then redirects to the list. `.save-status` is a short line of words (never colour alone), in the submit bar on the list and in the action area of each picker page.

- **Without JavaScript.** Page navigation is the browser's. The server renders the state it knows, and it needs no flash to know it: every pick is saved the moment it is made, so whenever the list is opened (after a save, on a cold open, with zero orders) its `.save-status` reads "Saved". On a picker step it reads "Saves when you pick". When the list is the answer to a refused save (a 422, with its refusal banner) it reads "Not saved". The browser's own loading indicator shows progress; "Saving…" never appears. Nothing is lost by that.
- **With Turbo.** Turbo sets `aria-busy="true"` on a form while it submits. The status holds two sibling spans, the resting text and "Saving…", and a CSS rule (`.app:has(form[aria-busy="true"]) .save-status`) swaps which is displayed (`display`, not generated `content`, so tests and assistive technology read real text). No script of ours runs. While the form is in flight the browser has not yet navigated; when the redirect lands, the new page's resting text shows, so a short flash back is possible and accepted. Browsers without `:has()` (the app already requires modern browsers) would simply keep the resting text. The status is a `role="status"` region; whether a screen reader announces a region that arrives with a new page is up to the reader, so nothing relies on it: the order's words in the list are the confirmation.

**D7. "Under a minute", and how it is tested.** A system spec at 360 pixels drives a power with five units through a full, mixed set of orders and submits. The position has five English units, so the spec writes it onto the phase directly (the app never edits a phase; a spec may). It asserts two numbers.

- **At most 18 taps**, counting every click on a link or button, from opening the order screen to the submitted state. A tap is one click, and every click in the spec goes through one counting helper. The costs are: Hold 2 taps (unit, Hold); Move 3 (unit, Move, destination); Move with a coast or a by-land-or-convoy choice 4; Support 4 (unit, Support, supported unit, how); Convoy 4; and Submit 1. The walk is two moves (6), a hold (2), a support (4) and a split-coast move (4), then Submit: 17 taps, with one tap of headroom. A unit left unordered costs nothing. The worst legal set, five orders of 4 taps and Submit, is 21 taps, which the spec states as the ceiling and does not walk.
- **At most 45 seconds of wall-clock time**, from the first visit of the order screen to the submitted state. This number only has to catch a screen that has become slow or broken: the same walk takes about 10 seconds on a laptop, so 45 is generous enough not to flake in CI. It is not a claim about a person.
- **The human side** is the tap count, and the spec says so honestly: a tap with reading and aiming takes about 2 to 3 seconds, so 17 taps is 34 to 51 seconds and the worst case of 21 is 42 to 63. "Under a minute" is therefore met by the planned walk and by nearly every real set, and a worst case sits at the edge. It is the Issue's number; the spec reports both rather than claiming more than the tests show.

**D8. The saving path is unchanged.** Every pick posts to the endpoint of spec 022 and so goes through `Seat#save_orders!`: one unit at a time (`orders[lon]=...`), checked at save, all or nothing, refused with a 409 once the phase is revealed. This feature adds no second path (AC-3.1 and the source scan). If the endpoint needs anything it is the one change in D4.

**D9. What the submit bar says and does.**

- Not submitted: a `.submit-bar` in the sticky `.app-actions` with the words "Not submitted", one button, "Submit orders", that carries the count on a second line, "3 of 5 ordered", and the `.save-status`. A seat with no orders can submit ("0 of 5 ordered"; all its units will hold, as the host's confirmation page already says).
- Submitted: the button is replaced by the words "Submitted · 5 of 5 ordered" and a secondary link "Back to your seat". Nothing is locked: tapping a unit and changing an order returns the seat to "not submitted", and the bar shows the button again (spec 022 AC-3.2).
- The player stays on the order screen until they submit. A pick, a refusal and a clear all return to the list; the list never forwards to the seat page by itself.

## URLs

All under `/games/:public_id`, `format: false`. Existing routes are unchanged. One route is added.

| Method and path | Who | What |
|---|---|---|
| `GET /phases/:number/orders` | seat | The order screen: the unit list and the submit bar (replaces the plain form). A revealed phase gives the 409 refusal page, as before |
| `PUT /phases/:number/orders` | seat | Unchanged. Every pick and Submit post here. A success redirects to the order screen |
| `GET /phases/:number/orders/:province` | seat | One picker step for the seat's unit in that province, chosen by the query (D1, D2). Not a seat's unit, or a phase that is not the open one or an earlier one, gives the stranger response; a revealed phase gives the 409 page |

## User Stories

### Story 1: The order screen lists my units and their orders

**As a** player
**I want** to see my units and what each is ordered to do
**So that** I know what is left to order

**Acceptance criteria:**

- [ ] **AC-1.1** *(the first test, a request spec)* Given England's seat in spring 1901 with no saved orders When it opens `/games/:public_id/phases/1/orders` Then the response is 200, the page has three `.unit-row`s for "Fleet in Edinburgh (EDI)", "Fleet in London (LON)" and "Army in Liverpool (LVP)" (province names in full with the abbreviation), each says "holds", and the `.submit-bar` says "0 of 3 ordered"
- [ ] **AC-1.2** Given a saved move for the unit in London When the screen is opened Then its row reads the order in words with full names ("Move to North Sea (NTH)"), the other rows still say "holds", and the bar says "1 of 3 ordered"
- [ ] **AC-1.3** Given a saved hold for a unit When the screen is opened Then its row reads "Hold", the count includes it, and an unordered unit still reads "holds"
- [ ] **AC-1.4** Given the screen When it is read Then each `.unit-row` is a link to step 1 for that unit (`/phases/1/orders/lon`), the rows are in the order of spec 022 (by province abbreviation), each shows the unit's `unit_icon` (decorative: a visible name sits beside it), and no other power's unit appears
- [ ] **AC-1.5** Given the screen Then it carries the phase header with the seat's power badge, and `Cache-Control: no-store` with the Turbo no-cache meta (spec 022 AC-7.6)
- [ ] **AC-1.6** Given the screen Then there is no `<select>` and no "Save orders" or "Save and submit" button, and the plain form's "n of m units ordered" line is gone (D4)
- [ ] **AC-1.8** Given the screen is opened cold (no earlier save, zero orders) or after any save Then its `.save-status` reads "Saved"; given it is the answer to a refused save (422) Then it reads "Not saved"
- [ ] **AC-1.9** Given a fleet's move to a sea province and an army's plain move to a province it can walk to Then their rows read plainly ("Move to North Sea (NTH)"); given an army's plain move to a province only a convoy chain reaches Then the row reads "Move to Norway (NWY), needs a convoy"
- [ ] **AC-1.7** Given a phone with no seat cookie, a host cookie only, or a seat cookie of another game When it opens the screen Then it gets the stranger response (spec 022 AC-2.12 holds unchanged)

### Story 2: Pick an order a step at a time, from legal choices only

**As a** player
**I want** each step to offer only what my unit can do
**So that** I cannot enter an illegal order

**Acceptance criteria:**

- [ ] **AC-2.1** Given a unit When step 1 opens Then it offers Hold always, Move, Support and Convoy only when the unit has such a legal order, and "No order (holds)" only when the unit has a saved order. England's fleet in London in spring 1901 offers Hold, Move and Support, not Convoy; an army never offers Convoy
- [ ] **AC-2.2** Given step 1 When "Hold" is chosen Then the hold is saved through the endpoint, the response is a 303 to the order screen, the unit's row reads "Hold", and the count includes it
- [ ] **AC-2.3** Given a unit with a saved order When "No order (holds)" is chosen Then the stored order is removed (the endpoint's blank value), and the row reads "holds"
- [ ] **AC-2.4** Given "Move" When the destination step opens Then each destination province of the unit's legal moves is listed once, in the order of D1, by full name and abbreviation, and choosing one whose province has exactly one legal order saves that order
- [ ] **AC-2.5** Given a fleet with moves to both coasts of a split-coast province When that destination is chosen Then "Which coast?" lists exactly the coasts the gem offered, each as "North coast (NC)" style, and choosing one saves the move with that coast. A fleet with one reachable coast is not asked (D3)
- [ ] **AC-2.6** Given an army whose destination has both a plain move and a move via convoy When that destination is chosen Then "How does it get there?" offers "By land" and "By convoy", saving the plain move and the move via convoy
- [ ] **AC-2.7** Given an army whose destination can only be reached by a convoy chain When the destination step opens Then that row says "needs a convoy", and choosing it saves the plain move the gem lists
- [ ] **AC-2.8** Given "Support" When "Support which unit?" opens Then each unit appearing as supported in the unit's support orders is listed once, as "Army in Burgundy (BUR)" with its power, and choosing one opens "Support it how?" with "Hold in place" first when a support to hold is legal, then each legal destination of a support to move, and choosing one saves that order
- [ ] **AC-2.9** Given "Convoy" When "Convoy which army?" opens Then each army in the unit's convoy orders is listed once, and choosing one opens "Convoy it where?" with that army's destinations, and choosing one saves the convoy
- [ ] **AC-2.10** Given a set of positions (the starting position; a position with a fleet at sea and armies on the coast; a position with split coasts; a position with an army that has both a land route and a convoy chain; units that can support a neighbour's hold but none of its moves, and the reverse, so both branches of step 3s are walked) When every possible chain of picks is walked for every unit of every power by following the page's own links and buttons (a crawler in a spec) Then the set of orders it can save equals, for each unit, exactly the set of `RulesEngine.legal_orders` for that unit: none missing, none extra, none twice
- [ ] **AC-2.11** Given a step URL whose `draft` values do not name a legal choice (an unknown kind, a destination the unit cannot reach, a supported unit that is not on the list, a coast the unit cannot reach, a `draft` that is not a hash), or that already names a whole order Then the response is a 303 to step 1 for that unit with no write, and no `draft` value appears in the response body or in Rails' log
- [ ] **AC-2.12** Given a province that is not one of the seat's units (empty, another power's, or not a province) When its step URL is opened Then the response is the stranger response and nothing is stored
- [ ] **AC-2.13** Given a revealed phase When any step URL is opened Then the response is the 409 refusal page of spec 022 AC-6.3. Given a phase number that is later than the open one or names no phase, the stranger response
- [ ] **AC-2.14** Given any step Then the page has a `.picker__draft` at the top that says, in words, the unit and the choices made so far ("Army in Liverpool (LVP)", then "Move", then "to Belgium (BEL)"), a `.list` of choices, and a "Back" link in the action area to the step before (step 1's Back goes to the order screen)
- [ ] **AC-2.15** Given any step page Then it carries `Cache-Control: no-store` with the Turbo no-cache meta, and every choice is at least 44 by 44 pixels at 360 pixels wide

### Story 3: Each order is saved as soon as it is picked

**As a** player
**I want** my pick saved at once
**So that** a dropped connection loses nothing

**Acceptance criteria:**

- [ ] **AC-3.1** Given any final pick Then it is one `PUT /phases/:number/orders` with the single entry `orders[province]` and no `submit`, handled by `Seat#save_orders!`; the code for a pick has no other write to saved orders (a scan in `spec/models/saved_order_boundary_spec.rb`'s style: `save_orders!` is called only from `seat_orders_controller.rb`, and no picker file names it)
- [ ] **AC-3.2** Given a pick whose order is illegal or foreign (a hand-crafted `PUT` of the same endpoint) Then the refusals of spec 022 AC-2.2 to 2.6 apply unchanged: 422, a sentence, nothing stored, and the screen is rendered again with the banner and `.save-status` reading "Not saved"
- [ ] **AC-3.3** Given a pick When the phase was revealed in the meantime Then the 409 page of spec 022 AC-6.1 is shown, and nothing is stored
- [ ] **AC-3.4** Given a save When it succeeds Then the response is a 303 to the order screen, whose `.save-status` reads "Saved", with no "Orders saved." banner (D4)
- [ ] **AC-3.5** Given the picker pages and the order screen When their HTML is read Then every interactive part is a link with an `href` or a form with an `action` and a real `method`: no `onclick`, no `data-action`, no `<script>` in the page body and no new import-map pin, so each screen works with JavaScript off. A request spec walks one full order (list, unit, Move, destination, save) using only the hrefs and form actions it finds
- [ ] **AC-3.6** Given Turbo Drive When a form is submitting (`aria-busy="true"` on it) Then `.save-status` shows "Saving…" and hides the other text, and when it is not submitting it shows the resting text (a system spec sets the attribute and reads the visible text)
- [ ] **AC-3.7** Given a deep draft in a request When Rails logs it Then neither the "Started GET" line (with its percent-encoded brackets) nor the parameters line contains a draft value: `draft` is in the filtered parameters (spec 022 AC-7.7 extended). Given any picker page Then it sets `Referrer-Policy: no-referrer`, and carries no link off the app

### Story 4: The submit bar

**As a** player
**I want** to submit when my units are set
**So that** the host knows I am ready

**Acceptance criteria:**

- [ ] **AC-4.1** Given the order screen When it is open and the seat is not submitted Then the sticky `.app-actions` holds a `.submit-bar` with the words "Not submitted", a "Submit orders" button whose second line is "k of n ordered", and the `.save-status`
- [ ] **AC-4.2** Given the button When it is tapped Then it is one `PUT` with `submit=1` and no orders, the seat is marked submitted, the response is a 303 to the order screen with the "Submitted." banner, and the bar shows "Submitted · k of n ordered" and a "Back to your seat" link, with no Submit button
- [ ] **AC-4.3** Given a submitted seat When it changes or clears an order through a picker Then the seat is "not submitted" again (spec 022 AC-3.2), and the bar says "Not submitted" and shows the Submit button again. A pick that changes nothing keeps the submission (AC-3.3 of 022)
- [ ] **AC-4.4** Given a seat with no saved orders When it submits Then the submission is recorded and the bar says "Submitted · 0 of n ordered"
- [ ] **AC-4.5** Given any pick, clear, refusal or submit Then the player lands on the order screen, never on another page, until the revealed-phase refusal (the player stays on the order screen until they submit)
- [ ] **AC-4.6** Given the bar at 360 pixels Then it is inside the viewport in the sticky action area, the button is at least 44 pixels tall, nothing scrolls sideways, and the count is words, never colour alone

### Story 5: Nobody sees another power's orders

**As a** player
**I want** my orders to stay secret
**So that** the table's negotiation means something

**Acceptance criteria:**

- [ ] **AC-5.1** Given the route classification of spec 022 FR-9 When this feature's route is added Then `GET /games/:public_id/phases/:number/orders/:province` is classified "own orders only", the route-table spec passes, and the spec that lists the routes that show orders lists it
- [ ] **AC-5.2** Given the invariance sweep of spec 022 AC-7.2 When it runs Then it requests the new route for England's unit (`/orders/lon`) and for the second seat's own unit (`/orders/par`), each with a `draft` that reaches a deep step, as every kind of viewer (the sweep also asserts, as a guard against a vacuous pass, that England gets a 200 on `/orders/lon` and France a 200 on `/orders/par` with the deep draft; the classification's `sweep` entry may now return a list of paths, and the sweep spec and the check that every readable route is swept change with it; for any viewer but France, `/orders/par` is the stranger page, and for France it is its own page), and for every viewer other than England the answer does not change as England's orders change
- [ ] **AC-5.3** Given France has saved orders When England opens any step, including "Support which unit?" and a support's destinations Then no page contains a France order, France's saved order text, or a count of France's orders; the supported unit appears only as a unit standing on the board (type, province, power), which is public (the position)
- [ ] **AC-5.4** Given a step page or the list Then the page shows only the viewer's own units' saved orders, and the picker's "No order (holds)" and the unit rows are driven by `Seat#orders_for` alone (the seat's own)
- [ ] **AC-5.5** Given the source scan of spec 022 AC-7.8 When it runs Then it still passes unchanged: the picker names neither `SavedOrder` nor `saved_orders`
- [ ] **AC-5.6** Given any response to a viewer other than England, a picker step included, Then it contains no order text of England's, as in spec 022 AC-7.3 (the sweep's second check is extended to the new route)

### Story 6: The five parts are built and match the catalog

**As a** later screen's author
**I want** `.unit-row`, `.picker`, `.picker__draft`, `.submit-bar` and `.save-status` built once
**So that** every screen uses the same parts

**Acceptance criteria:**

- [ ] **AC-6.1** Given a `.unit-row` When it is laid out at 360 pixels Then it extends `.list__row`: unit icon (32 pixels, decorative), province name with the mono abbreviation, the current order or "holds", and a chevron drawn by CSS; the row is at least 44 pixels tall, and long names and orders wrap without sideways scroll
- [ ] **AC-6.2** Given `.picker` and `.picker__draft` Then the draft sits at the top above a `.list` of choices, each choice is a `.list__row` (a link, or a button inside a form for the last pick), and the draft is words only
- [ ] **AC-6.3** Given `.submit-bar` and `.save-status` Then the submit bar is in `.app-actions`, the status is a polite live region, and the words (not colour) carry every state: "Saved" (the list's resting text, also at zero orders), "Saves when you pick" (picker steps), "Saving…", "Not saved", "Not submitted", "Submitted"
- [ ] **AC-6.4** Given `/styleguide` Then it has one section for each of `unit-row`, `picker` (with `picker__draft`) and `submit-bar` (with every status state and the submitted state), the existing style-guide specs pass with them added, at 360 and 768 pixels there is no sideways scroll, and every tappable part is at least 44 by 44 pixels
- [ ] **AC-6.5** Given `web/docs/design-system.md` Then its catalog lines for the three rows say they are built by #23 with their partial names, and the design-system spec passes
- [ ] **AC-6.6** Given the stylesheets Then they stay within the caps of spec 022 (32,768 bytes in total and 6,144 for `styleguide.css`), the parts add no color token and no contrast pair, and the contrast and stylesheet-rules specs pass

### Story 7: A full set of orders takes under a minute

**As a** player
**I want** the screen to be fast
**So that** it beats paper

**Acceptance criteria:**

- [ ] **AC-7.1** Given a game whose open phase has five English units and a phone at 360 pixels wide When a system spec enters an order for every unit through the pickers and submits Then every order is saved, the seat is submitted, the whole walk has made at most **18 taps** (17 planned) and took at most **45 seconds** of wall-clock time (D7). Taps are counted by one helper that every click in the spec goes through. The position (two moves, a hold, a support and a split-coast move are possible in it) is written onto the phase by the spec
- [ ] **AC-7.2** Given the same spec Then at each step it checks there is no sideways scroll and no control under 44 by 44 pixels
- [ ] **AC-7.3** Given a second system spec at 360 pixels Then a fleet's move to a split-coast province (with the coast step) and an army's move by convoy (with the "How" step) can be completed, and both land in the stored orders as the gem's own orders
- [ ] **AC-7.4** Given a spec run with `SCREENSHOTS=<dir>` set Then it writes a 360-pixel screenshot of each step (list, action, destination, coast, how, support unit, support how, convoy, submitted bar) for the pull request. Without the variable it writes nothing

### Story 8: Spec 022 is amended where this feature changes it

**Acceptance criteria:**

- [ ] **AC-8.1** Given spec 022 When this pull request merges Then it has a changelog row (1.3.0) saying: D5 and FR-4 (the plain form) are replaced by this spec; AC-2.11 is replaced by AC-1.1 to AC-1.4 of this spec; the "Orders saved." banner of AC-2.1 is replaced by `.save-status` reading "Saved"; the "n of m units ordered" line leaves the orders page for the submit bar; the words "Submitted" and "Not submitted" (AC-3.1, AC-3.2, AC-7.10) move into the submit bar (D9) and the criteria are read as about the bar; the order labels of D5 use full names with abbreviations (FR-3); Turbo frames are not used (D5, a ruling on the Issue's note "pages and frames"); its Non-Goal for #23 is met. Every other criterion of 022 holds unchanged, and its specs for the endpoint pass unchanged
- [ ] **AC-8.2** Given the repository When the work is done Then every spec of spec 022 that asserted the plain form's markup is rewritten to this spec's screen, and none is deleted without an equivalent

## Functional Requirements

### FR-1: The order screen

`GET /phases/:number/orders` renders the seat's units in the order of spec 022, each as a `.unit-row` linking to its step 1, with the current order's words or "holds". It reads the seat's own saved orders through `Seat#orders_for` and the position's units, and calls the gem (through `RulesEngine`) only for province names and, in the pickers, `legal_orders`.

**Must:** show the phase header with the power badge; the refusal banner and "Not saved" status when the page is the answer to a refused save (422); the Submit bar in `.app-actions`; the 409 page for a revealed phase.
**Must not:** show another power's units or any order but the seat's own; contain a form with a `<select>`.

### FR-2: The picker

`GET /phases/:number/orders/:province` takes the unit at that province from the seat's own units, asks `RulesEngine.legal_orders(position, unit)`, and chooses the step from the `draft` as in D1. A pure object (`OrderChoices`, built from the position and the unit) groups the legal orders into the steps and answers: which kinds exist, the destinations, the coast options, the "how" options, the supported units and the convoyable armies. It reads each order's hash form only and names no gem constant.

**Must:** build every choice from a legal order, and give the final choices as a form posting that order's JSON; re-derive the step from the draft on every request and trust nothing in it (AC-2.11).
**Must not:** store a draft; accept an order, a power or a coast from the query; offer a choice that is not in `legal_orders`.

### FR-3: Labels

Province names come from the gem's map through `RulesEngine.province_name(id)` and `RulesEngine.army_adjacent?(from, to)`, two methods this feature adds to `RulesEngine` (the existing boundary spec covers them: no other file names the gem). The order helper reads an order's hash form and is given the unit as well, because a move's hash has no unit type: only an army's plain move to a province it cannot walk to gets the "needs a convoy" mark. A province reads "Liverpool (LVP)" with the abbreviation in `.mono`. The helper writes an order in words with full names ("Move to Belgium (BEL)", "Move to Spain (SPA), north coast", "Move to Belgium (BEL) by convoy", "Move to Norway (NWY), needs a convoy" (a plain move of an army to a province it cannot walk to), "Support hold in Berlin (BER)", "Support Burgundy (BUR) to Munich (MUN)", "Convoy London (LON) to Norway (NWY)").

### FR-4: Saving

As D8. The order screen, and each pick, post to the existing endpoint, and that is the only write. The endpoint's change is only that a plain save sets no "Orders saved." banner (D4).

### FR-5: The submit bar and save status

As D6 and D9, each in one partial (`seat_orders/_submit_bar`, `shared/_save_status`), so #24 and later screens can reuse them.

### FR-6: Components

`.unit-row`, `.picker`, `.picker__draft`, `.submit-bar` and `.save-status` are plain CSS in `components.css` and `styleguide.css`, using tokens only, in the base layers, with the rows extending `.list__row`. Nothing is drawn by an image.

### FR-7: Hotwire Native readiness

Every step has a URL; there are no modals, no frames, no new controllers. Each picker URL has one place in the route table, so a path configuration can later present all `/orders/:province` pages as a sheet.

### FR-8: Secrecy

As spec 022 FR-9, with these additions: the new route is classified "own"; the draft parameters are filtered from Rails' logs and picker pages send `Referrer-Policy: no-referrer` (AC-3.7); every picker page and the screen are `no-store`; the supported unit's power is public from the position, but no order of any power is ever shown to anyone but its seat.

**Known limit.** A deep draft in a query string is an order minus its last pick, and it is the viewer's own. Rails' filter does not reach a reverse proxy's access log (Cloudflare's tunnel and kamal-proxy keep their own) or the phone's browser history, which `no-store` does not clear. This is the same kind of limit as spec 022's debug-level SQL log. It is accepted because a draft is never an order (nothing is stored until the last pick, which is a `PUT` body), the history is the player's own phone, and the pull request states it plainly for operators. The unit's province is in the path, which is logged, and is not secret (units are public on the board).

## Non-Functional Requirements

### Performance

- A step page makes no write and reads the seat's own orders once (`orders_for`) and the unit's legal orders once. The final pick makes one transaction (spec 022 D8).
- **Stylesheet budget.** The caps are 32,768 bytes in total and 6,144 for `styleguide.css`. The stylesheets stand at 24,621 and 3,716 bytes before this feature, so this feature has about 8,100 and 2,400 bytes. The five parts are expected to take about 2,000 and 1,200. If they do not fit, the maintainer is asked before any cap changes.

### Accessibility and layout

- Every control is at least 44 by 44 pixels at 360 pixels wide and nothing scrolls sideways (spec 020). Every state is words. The save status is a polite live region. A unit's icon is decorative because its name is beside it.
- Screenshots of each step at 360 pixels go in the pull request (AC-7.4).

### Security

- CSRF protection applies to every pick (a real form with a token). The query is untrusted: it is matched against what the gem listed, never used as an order.

## Error Scenarios

| Scenario | Expected Behavior |
|----------|-------------------|
| A step URL with a bad `draft` | 303 to step 1, nothing echoed (AC-2.11) |
| A step URL for a province that is not the seat's unit | The stranger response (AC-2.12) |
| A pick after the host revealed | The 409 page, nothing stored (AC-3.3) |
| A hand-crafted illegal or foreign order | 422, a sentence, "Not saved" (AC-3.2) |
| The connection drops during a pick | The pick is stored or not; the player sees the list on the next load, with the true state |
| A stale list after another tab changed an order | The list is read fresh on each load, and tapping Submit submits the stored state |
| A seat reissued by the host mid-pick | The stranger response (spec 022 FR-2, `Seat::Stale`) |
| JavaScript is off | Everything works; "Saving…" never shows (D5, D6) |

## Open Questions

None unresolved. The maintainer is asked about D1, D3, D4, D5 and D7.

## Out of Scope (Future Considerations)

- **#24** shows who has submitted, live, and reuses `.save-status` and the seat-status partial's neighbours.
- **#26** steps into a seat: the host would see these same screens as that seat. It needs the sweep's exception of spec 022.
- **#27** may change an open phase's position. A saved order is checked at save time (spec 022 D4), so spec 027 decided it: an edit that moves units clears every seat's orders and submissions. Nothing here changes that.
- **#82** adds glyphs (the chevron, "Saved") in one place per component.
- A phase clock, a shared display, undo of an order, and a map.

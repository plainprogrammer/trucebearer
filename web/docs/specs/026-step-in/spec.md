# Feature 026: The host steps into another seat

**Status:** Approved
**Version:** 1.3.0
**Created:** 2026-11-26
**Last Updated:** 2026-11-26
**Issue:** #26 (amended by #104, #112)
**Branch:** `web/26-step-in` (amendments: `web/104-reissue-history`, `web/112-one-history`)

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 1.3.0 | 2026-11-26 | Amended by #112 (one history on the host page). **MINOR**: adds behavior and renames the list; the approved acceptance criteria that name it are read as stated in D11 (AC-6.4, AC-6.6, AC-8.5, AC-9.1, AC-10.1, AC-10.4, AC-10.6, AC-10.8).<br>• **D11 (new):** the host page has one list, headed "History", that replaces three: the "Revealed phases" list, the host's copy of spec 025's "Earlier results" and the "Seat history" list. It holds, in time order, the reveals (each a link to that phase's host results page), the step-ins, the reissues and the position edits of spec 027. Its partial (`step_ins/_history`) and its hook (`data-seat-history`) stay, so the specs that use them follow.<br>• **Order:** oldest first, by time, then by phase number, then by kind (a reissue, a step-in, a position edit, then the reveal that closes the phase), then by id. Rows of one phase keep the order they had; rows of different phases at one instant now sort by phase (so a later phase's row never precedes an earlier phase's reveal), and the reveal comes last in its own phase because it ends it.<br>• **The no-reveal sentence:** while the game has no reveal row, the section opens with the sentence "No phase has been revealed yet." (spec 022 AC-1.6's sentence, true whatever else the list holds, so that AC stands unamended). "Nothing has happened to a seat yet." is retired.<br>• **Story 11 (new):** AC-11.1 to AC-11.8. No table, column, route or controller change; the seat page keeps its "Earlier results" (spec 025 D7), and who else sees the history stays Open Question 1 |
| 1.2.0 | 2026-11-26 | Amended by spec 027 (the position editor, #27).<br>• The host page's Seat history list also holds the position edits of spec 027 D4, in the order "a reissue, then a step-in, then a position edit" at the same instant; its heading, hook and empty text are unchanged. The list's partial draws a row of words for a position edit, and the secrecy sweep keeps a position-edit row in the history it compares.<br>• The Out of Scope line for #27 is decided: edits that move units clear every seat's orders (spec 027 D3); a step-in sees what is left, which is none until the seat orders again. |
| 1.1.0 | 2026-11-26 | Amended by #104 (record seat reissues). **MINOR**: adds behavior; the approved acceptance criteria that change are only the ones that name the list (AC-6.4, AC-6.6, AC-8.5, AC-8.6, AC-9.1).<br>• **D10 (new):** every reissue writes one append-only row in a second table, `reissues` (`phase_id`, `seat_id`, `created_at`), in the same transaction as the new token. A separate table, not a `seat_events` table with a kind; `step_ins` and its behavior do not change.<br>• **D6 / AC-6.4:** the host page's "Step-ins" list becomes "Seat history": step-ins and reissues together, oldest first, each row the phase title, the power and the time, with the words "stepped in" or "seat reissued". Its empty text is "Nothing has happened to a seat yet." and its hook is `data-seat-history` (the existing list specs follow).<br>• **D5:** option (c) (record every reissue) is now built, by D10. The stated residual (a browser that never holds the host cookie) is still not blocked, but it now leaves a row.<br>• **Story 10 (new):** AC-10.1 to AC-10.8. **AC-8.5** adds the history; **AC-8.6** also scans the constant `Reissue`; **AC-9.1** also checks the history at 360 pixels.<br>• Found at the first Fable review: the write order must not change what `reissue_seat!` returns (spec 024 D3); the sweep's setup is named; the scan pattern is a constant use, not the word<br>• Out of Scope and Open Question 1 updated. Who sees the history stays with the maintainer: only the host, as before |
| 1.0.3 | 2026-11-26 | Found while building, within what Gate A approved: the layout draws the bar and the page inside one `.stack` while stepped in (the bar sits under any flash banner), because `.banner` sets its own margin to 0 and no new CSS is allowed, so the bar and the page need a stack of their own to be spaced (D7); the resolver's redirect for a host browser that holds another seat's cookie is a 303, so a `PUT` never repeats as a `PUT` (D5); the 409 page is headed with the seat's name while stepped in; the entry list is in the Seats list's order |
| 1.0.2 | 2026-11-26 | Approved at Gate A (the maintainer's delegate: the record, option (b) of D5, the cookie, and `TRUCEBEARER_TIME_ZONE` kept, also in `config/deploy.yml`; recording every reissue, option (c), is a follow-up Issue and not built here). Minor fixes from the second Fable review (approved with minor fixes): the resolver's redirect goes to the open phase's confirmation and deletes the foreign seat cookie (D5); Leave and the own-seat link fall back to the host page when the browser holds no seat of its own (D7, AC-3.9); a revealed number redirects, a later or unknown one is a stranger (AC-1.7); where the bar's flag is set is named (D7, AC-3.4); the scan looks for the constant `StepIn` (AC-8.6); a host-only browser that joins as another power is a Non-Goal; FR wording |
| 1.0.1 | 2026-11-26 | Changed after the first Fable review: the rule that a host cookie plus another seat's cookie is not that seat moves from the seat link into the resolver (D5, AC-7.5, AC-8.2); D4 lists the real edits and the stepped-in screen says whose orders it shows (AC-4.6); Leave and switching are client-side and say so (D2); the bar is set by the controller and never on a stranger page (D7, AC-3.8); the confirmation is pinned to a phase number (D9); the time zone is read when the page is drawn, with no boot setting (D6); the owner's notice is one banner and not shown to the host (D6); the sweep's details are stated (Story 8); smaller wording fixes |
| 1.0.0 | 2026-11-26 | First draft |

## Problem Statement

At a real table a phone dies, a player is in the other room, or someone simply can't work the screen. The host needs a way to enter or fix that seat's orders. But order secrecy is the point of the app (`docs/architecture.md`, "Order secrecy"): nobody sees an order before the reveal, the host included, and the host is usually also a player. So the override must never be quiet. It needs a confirmation that is hard to miss, a record the table keeps, a notice the seat's owner can't miss, and a screen that can't be mistaken for the host's own.

Spec 022 left one hole open on purpose (D9): a host who reissues a seat and opens the new seat link is acting as that seat with no record. This feature closes it.

## Goals

- The host can step into any other held seat, after a `.confirm` page that names the power and says plainly what it means.
- The moment the host confirms, a record is written (which seat, which phase, when). It is written before any order of that seat is shown, and it is kept in the game's history.
- While stepped in, every game page the host opens carries a `.banner` naming the power and a button back to the host's own seat. The host's own seat stays the main screen, and host controls stay in their own section.
- The host sees and changes only that one seat's orders, through the same order screen, pickers and `Seat#save_orders!` the player uses. There is no second way to save.
- The seat's owner sees "The host entered your orders at 8:42 PM UTC" on the seat page and the order screen.
- The step-in ends when the host leaves, when the phase is revealed, or after a short time. It never hands the host the seat's own token, and the real player's cookie keeps working.
- The reissue gap is closed: opening a reissued seat link on a phone that holds the host cookie is a step-in, not a seat takeover.
- The secrecy specs (route table, invariance sweep, source scans) are updated and prove all of the above.

## Non-Goals

- Any new component or stylesheet. The page is `.confirm`, `.banner`, `.button`, `.list`, `.host-section`, `.stack` and the order screen of spec 023 (`web/docs/design-system.md`).
- Live status (#24), results (#25), the position editor (#27).
- Showing the step-in history, or the reissues, to every seat. The owner is told about their own seat's step-ins (Open Question 1); the full list is on the host page.
- Stopping a host who deliberately works round the app, for example by opening a reissued link in a browser that does not hold the host cookie (D5 says exactly what is and isn't covered).
- A host-only browser (no seat cookie) that joins as an extra power through a join code. It holds a second seat of its own, which the resolver then treats as another seat's (a redirect to its confirmation). Joining does not check the host cookie today, and this feature does not change that.
- Accounts: "who" is the host, the one person who holds the host link. Accounts replace that in 1.0.
- Stepping into a power nobody holds (it has no seat, so no orders), and stepping into the host's own seat (it is already theirs). A host who hands their own seat to another player by reissue keeps it as the host's own seat in the app (D5).
- Any change to `adjudicator/`, `.github/` or the root files.

## Users and Context

**Primary users:** A host at a physical table, on a phone about 360 pixels wide, fixing one player's orders.
**Secondary users:** The player whose seat it is. The other players, who are told nothing and see nothing (Open Question 1).
**User mental model:** "I tell the app I'm stepping into France. It warns me, writes it down, and tells France. I do what I need to, tap Leave, and I'm back on my own seat."

## Decisions

Gate A asks about D1, D2, D4, D5 and D6. The 1.1.0 amendment (D10) asks about the table choice.

**D1. What is recorded: one row per confirmed entry, in a table `step_ins`.**

| Table | Columns | Keys and checks |
|---|---|---|
| `step_ins` (model `StepIn`) | `phase_id`, `seat_id`, `created_at` | Both ids are foreign keys, indexed. No `updated_at`. A row never changes and is never deleted (the model refuses both) |

- **What counts as one step-in: the host entering the seat**, that is, one confirmation. Not each save made while stepped in. The reason is what the rule protects: seeing the seat's orders is the breach, and the host sees them the moment they enter, before any save. A step-in in which the host only looked is as serious as one in which they changed something. The record has to exist before the first page that shows an order, so it can only be written at the entry. Saves made while stepped in go through the one save path and need no record of their own: the entry row covers them, and the owner's notice reads the same either way.
- **Who** is the host. A game has one host, and the only way to reach a step-in is the host cookie. The table needs no actor column: it would hold one constant. When accounts arrive (1.0) it gets one.
- **Which seat** is `seat_id`; **which phase** is `phase_id` (the open phase at the moment of confirming, never a later one); **when** is `created_at`, stored in UTC.
- **Leaving and re-entering** is a second step-in and a second row. Each row is one notice.
- A game's step-in history is every `step_ins` row whose phase belongs to the game, oldest first. It is read through the game's phases (`Game#step_in_history`, with no `through:` association, which `saved_order_boundary_spec` forbids on `Game`) for the host page, and through `Seat` for the owner's notice. The table holds no order, no count of orders and nothing about what was saved.

**D2. How a step-in is held and how it ends: a signed session cookie that names the row, and the row is checked on every request.**

- The cookie is `step_in_<public_id>`, signed, `httponly`, `same_site: :lax`, `secure` as the host and seat cookies are (spec 021 FR-2), **with no expiry** (a session cookie, gone when the browser closes). Its value is the `step_ins` row's id and nothing else. It never contains a token of any kind, so the seat's own token is never handed to the host and the player's cookie, which is the player's token, is untouched and keeps working.
- A request is stepped in only if **all** of these hold: the request holds a valid host cookie for this game; the cookie verifies and names a row; the row's seat is a seat of this game; the row's phase is the game's open phase (read from the database, so a reveal ends it at once); the row is younger than 30 minutes; and, on a seat-scoped URL, the URL's power is the row's seat. Otherwise the request is not stepped in, and the cookie is ignored.
- It **ends** when: the host taps Leave (the cookie is deleted); the phase is revealed (the row's phase is no longer open); 30 minutes pass since entering (a host who needs longer confirms again, which is a new record, a new notice and a new 30 minutes); the browser session ends; or the host steps into a different seat (the cookie now names the new row).
- **Leave, and switching seats, work on this browser only.** A row never changes, so a copy of the cookie replayed after Leave still works until 30 minutes pass or the phase is revealed. That copy still needs a valid host cookie and still sits under the row's record, so nothing is quiet. The spec says "this browser no longer reaches", not "no one can".
- `stranger!` never sets or deletes the `step_in_<id>` cookie. An unusable cookie is ignored.
- Options not chosen: a Rails session value (it would also work, and the app already uses the session for the flash and the CSRF token; the signed cookie is chosen because it matches the host and seat cookies, is scoped to one game and can be named and checked like them); a column on the seat or game (it would be state shared by every browser that holds the host cookie, so a second phone would be stepped in without confirming); a cookie holding the seat's token (it would hand the host the seat for good and break reissue's guarantee).
- 30 minutes is a deliberate cap. It is long enough to fix a seat and short enough that a forgotten step-in on a passed-around phone ends itself. It is a constant, not a setting.

**D3. Where the stepped-in pages live: their own URLs, under the host's path.** The order screen, the picker and the orders endpoint are reused (D4) but answer at `/games/:public_id/host/seats/:power/phases/:number/orders...`. The host's own orders stay at `/phases/:number/orders...` and are always the host's own seat. The alternative, one URL that changes meaning when a step-in is active, was left out: the same address would show the host's own orders at one moment and France's at the next, and a refresh or a bookmark would act on the wrong seat. With separate URLs, a page is either the host's own or a stepped-in seat's, never both, and the route table can classify them apart.

**D4. One save path: the same controllers, the same `Seat#save_orders!`.** The seat-scoped routes point at the existing `seat_orders` and `order_pickers` controllers. A before-action resolves who is acting: on a seat-scoped URL, the stepped-in seat (D2); otherwise the cookie's seat as today (and D5's rule). It reads the URL's path parameter, never a query parameter, so `?power=france` on the host's own URL does nothing. The phase check, the headers, the refusals and `@seat.save_orders!` are unchanged code. No controller, model method or query is added for saving, so `seat_write_scan_spec` and `saved_order_boundary_spec` stay as they are and keep proving it. The refusal sentences stay as spec 022 wrote them.

The edits to existing code are these, and no others:
- `GameAccess` gets the resolver (`require_acting_seat`), the stepped-in lookup and the two path helpers (the own URL or the seat-scoped one). `require_seat` gets D5's rule.
- `SeatOrdersController#update` and `OrderPickersController#show` build their redirects with the helpers, so a stepped-in save returns to the stepped-in screen.
- `_unit_row`, `_submit_bar`, `order_pickers/show` and `seat_orders/revealed` build their order links with the helpers.
- When stepped in, the order screen is headed "France's orders" (not "Your orders"), and the submit bar's link to the host's own seat reads "Your own seat" (not "Back to your seat"). The picker's page title and heading already name the step.

**D5. The reissue gap: opening a reissued link on the host's phone is a step-in (option b), and the reissue itself stays as spec 022 made it.**

The three options, argued:

- **(a) Refuse to reissue while a phase is open.** Rejected. A game always has an open phase, because the next one opens at the moment of the reveal (spec 022 D3). So (a) would mean a seat can never be reissued, which kills the one tool the host has for a dead phone.
- **(b) Treat opening a reissued seat link on a phone that holds the host cookie as a step-in. Chosen.** Two rules, so the invariant holds whichever link or cookie came first. **At the link:** when a request for the seat link holds a valid host cookie and the token is for a seat other than the host's own, the app does not store a seat cookie. It verifies the token and sends the host to the step-in confirmation for that seat. **At the resolver:** a browser that holds a valid host cookie *and* a seat cookie for a seat other than the host's own is not that seat. On the seat page, the order screen, the picker and the orders endpoint it is sent to that seat's confirmation for the open phase (always the open phase, whatever number the request named), the foreign seat cookie is deleted in the same response, and nothing is shown or saved. The cookie goes because the step-in needs only the host cookie and the row, and it is the same reason the seat link never stores that seat's token on a host browser. This covers the other order of events (the seat link opened first in a clean browser, the host link opened there afterwards). The token is used to find the seat and is never stored. Confirming is a step-in: recorded, noticed, ended as D2 says. This also stops the link from silently replacing the host's own seat cookie, which it does today (one seat cookie per game). It closes exactly the gap the Issue comment names: reissue, open the link, act as that seat.
- **(c) Also record every reissue** (a second kind of row and a second notice). Not chosen in 1.0, **built in 1.1.0 (D10, Issue #104)** as a history record only, with no notice to the seat's owner.

**What (b) covers and what it can't.** A request that carries the host cookie and either asks for another seat's orders, holds another seat's cookie or presents another seat's token ends at a recorded step-in or a redirect to the confirmation: no page shows another seat's orders to a browser that holds the host cookie without a record. What no design can cover while the host sees the new QR code is a browser that never holds the host cookie, such as a private window that opens only the reissued link. That browser is not the host's as far as the server can tell. The reissue cleared the seat's orders (spec 022 D9), so nothing secret was exposed, and the real player's old phone stops working at once, which is not quiet. Since 1.1.0 it also leaves a row: the reissue was recorded when the host made it (D10), so the table can see that a seat was reissued, in which phase and when, even though the app can't tell who then opened the link. The spec says so plainly instead of claiming more.

The host's own seat is needed to tell "the host reopening their own reissued seat" from "the host opening another seat". `Game#host_seat` is the seat with the lowest id: `Game.start!` creates it in the same transaction as the game, and no path deletes a seat. A spec pins it. A host who reissues their own seat and gives it to another player has handed the seat over: it stays the host's own seat in the app, so it can't be stepped into (a Non-Goal).

**D6. The notice, the history, and the time.**

- **The owner's notice** is one `.banner` (kind `warning`) on the seat page (`GET /games/:public_id`) and on the order screen, where it matters most because the orders may have changed under the player. It lists the open phase's step-ins into that seat: "The host entered your orders at 8:42 PM UTC." for one, "The host entered your orders at 8:42 PM UTC, 9:05 PM UTC." for more. It is not drawn for the stepped-in host on France's own order screen (the bar says it already). A new phase has no notices; the older ones stay in the history.
- **The history** is a list on the host page, at the foot of the page (since 1.3.0 the one "History" list, D11; before it, under the "Revealed phases" list): one row for each step-in, with the phase title, the power (badge and name) and the time. It sits in its own partial, so #24's changes to the host page don't touch it. No order, no count. **Since 1.1.0 (D10) the list is headed "Seat history" and also holds the reissues; since 1.3.0 (D11) it is headed "History" and also holds the reveals.**
- **Time format:** the 12-hour clock with minutes, a space, AM or PM, a space, and the zone abbreviation, from `%-l:%M %p %Z`: "8:42 PM UTC". The Issue's "8:42" has no AM or PM and a table session runs into the night, so the notice carries both. The time is written inside `<time datetime="…Z">` so a later change can show the viewer's local time without touching the markup.
- **Time zone:** the app has no time zone setting. Rows are stored in UTC (the Rails default, unchanged). A small helper turns a time into text in the zone named by the environment variable `TRUCEBEARER_TIME_ZONE` (a Rails zone name such as `America/New_York`), read each time a page is drawn, looked up with `ActiveSupport::TimeZone[]`, and `UTC` when it is unset or unknown. `config.time_zone` does not change, so nothing else in the app moves. The abbreviation is always shown, so an unset zone reads honestly ("8:42 PM UTC") and never looks like local time. A zone with no abbreviation shows a numeric offset ("-03"). The variable is listed in the README with the other one, and set in `config/deploy.yml` as a clear env value (a zone name is not a secret). The choice for Gate A: this (a notice at the table's own time) or UTC only with no variable (the smallest, and the notice at 1:42 AM for a table sitting at 8:42 PM is the cost). Rejected: guessing the zone from the browser (it needs a script and a cookie, neither of which the app has).

**D7. The step-in bar.** While stepped in, every game page (a page with a game id in its path, shown to the stepped-in host) opens with the same partial, rendered from the layout so no page can forget it. It is a `.banner` (kind `warning`) and a button, built from existing components. The layout draws it (one conditional, which also wraps the page in a `.stack` while stepped in so the bar and the page are spaced like any two blocks, because `.banner` sets its own margin to 0 and no CSS is added). A controller decides whether it is drawn, by setting `@step_in` in the three places that verify a host or a seat (`require_host`, the seat resolver of D4 and D5, and `games#show`), so any page behind one of them has it. It appears only when the request is a verified host with an active step-in, and `stranger!` marks the request so it is never drawn on a stranger page, which spec 021 D4 keeps one answer for everyone. The 429 and 409 pages and the stepped-in pages of an ended step-in have none.

- **On the stepped-in seat's own pages** (the order screen and picker steps): "Acting as France. What you save here is France's, and France is told." and a secondary button "Leave France's seat" (a `DELETE` of the step-in, then the redirect to the host's own seat page, or to the host page when this browser holds no seat of its own, because the seat page would be the stranger page there; the submit bar's own-seat link follows the same rule).
- **On any other game page** (the host's own seat, the host controls, the reveal page): "Still stepped into France's seat." with a link "France's orders" back to the stepped-in orders and the same Leave button.
- The phase header on the stepped-in pages shows France's power badge, so the power's name is also in the page itself.
- Placement for #24's sake: the layout gets one line at the top of `<main>`; `hosts/show` gets one render at the end of the `.host-section` (the entry list) and one after the history section; `games/show` gets one render (the notices). Nothing else in those views changes.
- The host's own seat page (`GET /games/:public_id`) and the host page are unchanged otherwise: the host's own seat stays the main screen and host controls stay in the `.host-section`.

**D8. Where the host starts a step-in.** A "Step into a seat" list in the `.host-section` of the host page (its own partial): one `.list__row` for each held seat that is not the host's own, with the power badge and the words "Step in". The link goes to the confirmation page. No order, count or submitted state is shown there.

**D9. The confirmation page** is the `.confirm` partial, danger variant: heading "Step into France's seat", a body in plain words ("You will be able to see and change France's orders for Spring 1901 · Movement. This is recorded. France will see: The host entered your orders at <time>. It ends when you tap Leave, when you reveal the phase, or after 30 minutes."), the confirm button "Step into France" and a "Back" link to the host page. The page shows no order. It names the phase it was drawn for, and its address carries that phase's number (spec 022 D7). If the number is no longer the open phase, the page and the confirmation redirect to the confirmation for the open phase with a banner, and nothing is written.

**D10. Reissues are recorded too, in their own table, and the host page's history shows both (added in 1.1.0, Issue #104).**

- **What is recorded: one row per completed reissue, in a table `reissues`.**

| Table | Columns | Keys and checks |
|---|---|---|
| `reissues` (model `Reissue`) | `phase_id`, `seat_id`, `created_at` | Both ids are foreign keys, indexed. No `updated_at`. A row never changes and is never deleted (the model refuses both, as `StepIn` does). The seat belongs to the phase's game (a validation, as in `StepIn`) |

- **One table or two. Chosen: two, a separate `reissues` table next to `step_ins`.** The other option was one `seat_events` table with a `kind`. Why separate: (1) `step_ins` is untouched, so its rows, its cookie (which names a `step_ins` row id, D2), its `active?` rule and the owner's notice keep working with no migration or backfill. In a shared table the cookie's lookup (`StepIn.find_by(id:)`) and every reader would need a kind filter, or a reissue row's id could satisfy `active?` and open a seat's orders; keeping the two tables apart makes that mistake impossible. A shared `seat_events` table would either rewrite `step_ins` or leave two sources anyway, and the cheaper variant (a `kind` column on `step_ins`) has the same filter problem and would also make `StepIn` hold a row with no cookie. (2) The two rows mean different things: a step-in has a lifetime, an `active?` rule and a cookie; a reissue has none of these. A `kind` column would hold one rule for each kind, which is a table doing two jobs. (3) It matches the Rails default and the fewest moving parts: one more small table and model of the same shape as `StepIn`, and no enum. The cost is two reads that the history merges (below). If a third kind of seat event ever arrives, one table can replace both then.
- **Written in the same transaction as the reissue.** `Game#reissue_seat!` writes the row inside its existing transaction, after the new token and the cleared orders, for the phase it holds the lock on. **The block still returns what `clear_orders!` returned** (whether a submission was withdrawn), so the status broadcast of spec 024 D3 is sent only when the submitted set changed, as before. If the row can't be written, the whole reissue rolls back: the token isn't replaced and no row exists. A reissue that is refused or fails (a stranger, a seat that is not held, a phone that is not the host's, a missing form token) writes nothing. **Every** reissue is recorded, the host's own seat included (spec 021 AC-7.10).
- **Which phase** is the open phase the reissue ran in (the one locked in the transaction), as with a step-in. **When** is `created_at`, in UTC. **Who** is the host, as in D1, so no actor column.
- **Reads.** `Game#reissue_history` is every `reissues` row whose phase belongs to the game (read through the game's phases, with no `through:` association, as `Game#step_in_history` is, D1), and `Game#seat_history` merges it with `step_in_history` into one list, each entry answering `kind` (`:step_in` or `:reissue`; each model defines it) so the partial names neither constant. Nothing else reads the table. The table holds no order, no count of orders and no token, digest or link.
- **The history on the host page** (the partial `step_ins/_history`, D6) is headed "Seat history" (until 1.3.0, see D11) and lists the game's step-ins and reissues together, **oldest first by time** (ties broken by kind, a reissue before a step-in, then by id, so the order is stable: a reissue, the link and the step-in are the causal order). Each row: the phase title, the power's badge, the words "seat reissued" or "stepped in", and the time from the helper of D6 (`TRUCEBEARER_TIME_ZONE`, in `<time datetime>`). So a reissue reads, for France: "Spring 1901 · Movement [France] seat reissued 8:40 PM UTC". With no rows the list says "Nothing has happened to a seat yet." (this replaces the empty text of 1.0.x, and the section's hook is `data-seat-history`) The merge is done in Ruby over the two relations and is a small list for one game.
- **Who sees it: only the host, on the host page**, as the step-in list is today. No notice is added to the seat's owner. Whether every seat should see the history is Open Question 1, and the maintainer decides it.
- **Boundary.** No route, controller or reissue behavior changes. The reissue still deletes the seat's orders (spec 022 D9) and the QR page is unchanged. The `step_ins` table, model, cookie, notice and the step-in behavior of 1.0.x do not change.

**D11. One history on the host page (added in 1.3.0, Issue #112).**

- **What it replaces.** Before this the host page drew three lists of the same game: "Revealed phases" (the phase titles and the word "revealed", hook `data-history`, from spec 022), "Earlier results" (links to the earlier phases' results, inside the results section, from spec 025 D7) and "Seat history" (D6 and D10, with spec 027's board changes). They become one section headed **"History"**, drawn by the partial `step_ins/_history` and carrying the hook `data-seat-history`. The hook keeps its old name so that every existing spec and the sweep find the list where they did; `data-history` is retired, and the two specs that used it (`phase_pages_spec` and `reveal_post_spec`) read the new hook.
- **The rows.** Four kinds, one line each, all drawn as `.list__row`:
  - **a reveal**: the phase title, the word "revealed" and the time of the reveal (`<time datetime>`, the helper of D6). The whole row is a link to that phase's host results page (`/games/:public_id/host/phases/:number/results`, spec 025). A reveal row never shows an outcome or an order;
  - **a step-in**: the title, the power's badge, "stepped in" and the time (D6);
  - **a reissue**: the title, the badge, "seat reissued" and the time (D10);
  - **a board change**: the title, "board changed: …" and the time (spec 027 D4).
  The labels are plain words, never colour alone, and a row's phase title is the phase it was recorded in, as before.
- **The order.** Oldest first, as the list always was, so the page reads as the game's log. The sort key is the time (a reveal's is `revealed_at`, the others' `created_at`), then the phase number, then the kind (reissue 0, step-in 1, position edit 2, reveal 3), then the id. The kind order among the three seat kinds is that of D10 and spec 027 D4, unchanged, and so is the order of any rows of one phase. The phase number matters only at one instant and only across phases: a row of phase 2 never sorts before the reveal of phase 1. (In real time a reveal always lies between the two phases' rows; under a frozen clock the old key could put a phase 2 reissue before a phase 1 step-in, which is causally wrong, and this key does not. So `host_history` and `seat_history` can differ for such a fixture.) The reveal comes after the other kinds of its own phase because it closes the phase: reissues and board changes are written under the phase lock that the reveal takes, so none can land after it. A step-in is not written under that lock, so one that races a reveal can carry a later time and sort after the reveal; that is true to the clock and is kept. The id is compared only between rows of one kind, since a reveal's id is its phase's.
- **Where the reveals come from.** From the revealed phases (`Game#history`, which is every phase with a `revealed_at`), so the open phase is never a reveal row. No table, no column, no migration. `Game#host_history` merges the three seat-event relations and the reveals in Ruby, as `seat_history` merges its three, and returns entries that answer `kind`, `phase`, `created_at` and `id` so the partial names no constant. A reveal's entry is a small value object (`Game::RevealEntry`, `kind` `:reveal`, `created_at` the phase's `revealed_at`, `id` the phase's id); it holds the phase and nothing else. `Game#seat_history` is unchanged, and `host_history` is built from it.
- **The no-reveal sentence.** While no reveal row exists, the section's first line is the paragraph "No phase has been revealed yet.", above any seat-event rows; with no row at all it is the whole section body. It is spec 022 AC-1.6's sentence, true whatever else the list holds, so that AC stands unamended (after one reveal the list shows "Spring 1901 · Movement" as revealed, now as a link, and the sentence is gone). "Nothing has happened to a seat yet." is retired.
- **Secrecy.** A reveal row names a phase that is already revealed and links to a page that already shows its orders to the host (spec 025). The rows of the other kinds are as before: phases, powers and times. The history shows no order, count, ordered unit, token, link or submitted state of the open phase, and nothing in it depends on what any seat has ordered. `host_history` is read only by the partial; the scan of AC-10.7 adds the name, and the route table's reason for the host page (`spec/support/secrecy_routes.rb`) mentions the reveal rows. The controller drops its `@earlier` (nothing reads it) and keeps `@history` only to find the latest phase.
- **Not changed.** The seat page's "Earlier results" (spec 025 D7), every route, controller action and access rule, the reveal, the notices of D6, and who sees the history (Open Question 1). The host page's results section stays for the latest phase and loses only the earlier list; it is passed an empty one.

## URLs

All under `/games/:public_id`, `format: false`, as in spec 021. Six routes are added and one is changed. The confirmation and the record carry the phase number (D9).

| Method and path | Who | What |
|---|---|---|
| `GET /host/seats/:power/phases/:number/step-in` | host | The confirmation page (D9). Writes nothing |
| `POST /host/seats/:power/phases/:number/step-in` | host | Writes the `step_ins` row, sets the cookie, redirects (303) to the stepped-in order screen |
| `DELETE /host/seats/:power/step-in` | host | Leaves: for a host, whatever the power, deletes the cookie and redirects (303) to the host's own seat page, so a repeat is harmless. Not a host: the stranger response |
| `GET /host/seats/:power/phases/:number/orders` | host, stepped in | The order screen of that seat |
| `PUT /host/seats/:power/phases/:number/orders` | host, stepped in | The orders endpoint, for that seat |
| `GET /host/seats/:power/phases/:number/orders/:province` | host, stepped in | A picker step for that seat's unit |
| `GET /seat-link` | seat token | Changed. With the host cookie and the token of a seat other than the host's own, it redirects to that seat's confirmation and stores nothing (D5) |

A power that is not one of the seven, one nobody holds, or the host's own is the stranger response (404) on every step-in route but Leave. A request that holds no host cookie, or a host that is not stepped in on one of the three order routes, is also the stranger response. A phase number is matched as spec 022 does.

## User Stories

### Story 1: The host is asked to confirm, and nothing is recorded until they do

**As a** host
**I want** a confirmation that names the power before anything happens
**So that** I never step in by accident

**Acceptance criteria:**

- [ ] **AC-1.1** *(the first test, a request spec)* Given a game where France holds a seat and the host holds Germany When the host opens `/games/:public_id/host/seats/france/phases/1/step-in` Then the response is 200, the page has a `.confirm` whose heading names France, the confirm button reads "Step into France", `StepIn.count` is 0, and no step-in cookie was set
- [ ] **AC-1.2** Given the confirmation page Then it is built from the `shared/confirm` partial in its danger variant, names the phase, says it is recorded, says France will be told, and says how it ends (Leave, reveal, 30 minutes); it shows no order, no count and no submitted state
- [ ] **AC-1.3** Given the host leaves the page with Back Then still no row exists and the cookie is unset
- [ ] **AC-1.4** Given a seat's phone, a stranger, or a host cookie of another game When any of them opens or posts the step-in routes Then each gets the stranger response and nothing is written
- [ ] **AC-1.5** Given the host's own power, a power nobody holds, or a name that is not a power When the host opens the confirmation page Then the response is the stranger response
- [ ] **AC-1.6** Given the host page When it is read Then a "Step into a seat" list in the `.host-section` has one row for each held seat but the host's own, each linking to its confirmation page, and the list shows no order, count or submitted state
- [ ] **AC-1.7** Given the phase number in the address is a revealed phase (the host revealed after the page was drawn) When the host opens or confirms it Then the host is redirected to the confirmation for the open phase with a banner, and nothing is written; a later, unknown or malformed number is the stranger response

### Story 2: Confirming records the step-in before any order is shown

**As a** table
**I want** every step-in written down before the host sees anything
**So that** the host can never look first and be recorded later

**Acceptance criteria:**

- [ ] **AC-2.1** Given the confirmation page When the host confirms Then in one request one `step_ins` row is written for the phase of the address and France's seat, the step-in cookie is set (signed, session, httponly), and the response redirects (303) to `/games/:public_id/host/seats/france/phases/1/orders`
- [ ] **AC-2.2** Given France has saved orders and the host has confirmed no step-in When the host requests the stepped-in order screen, a picker step or the orders endpoint for France Then each gets the stranger response, no France order is in any body, and no row is written by the request
- [ ] **AC-2.3** Given the row exists When the host opens the stepped-in order screen Then it shows France's own orders as France sees them (the unit rows, the submit bar), under the phase header with France's badge
- [ ] **AC-2.4** Given a step-in is in force When the cookie's value is read Then it is only the row's id, signed; it contains neither France's token nor its digest; and France's own phone, which holds the player's token, still opens its seat and saves orders
- [ ] **AC-2.5** Given a second confirmation for the same seat in the same phase (the host left and came back, or tapped confirm twice) Then each is its own row, and the notices list both
- [ ] **AC-2.6** Given the host steps into France and then confirms a step-in into England Then the cookie names England's row, this browser no longer reaches France's orders, and does reach England's
- [ ] **AC-2.7** Given the rows Then a row can't be changed or deleted (the model refuses both) and holds no order, count or order text

### Story 3: While stepped in, the screen can't be mistaken for the host's own

**As a** host
**I want** every page to say whose seat I am in
**So that** I never enter an order for the wrong power

**Acceptance criteria:**

- [ ] **AC-3.1** Given a step-in into France When the host opens the stepped-in order screen or a picker step Then the page opens with a `.banner` reading "Acting as France. …" (the power's name) and a "Leave France's seat" button
- [ ] **AC-3.2** Given a step-in into France When the host opens their own seat page, the host page, the reveal confirmation or the close and reissue pages Then each opens with a `.banner` reading "Still stepped into France's seat." with a link back to France's orders and the same Leave button; and the page is otherwise what it was
- [ ] **AC-3.3** Given a host with no step-in, or a step-in that ended Then no page has the bar
- [ ] **AC-3.4** Given the bar Then it is rendered by the layout from `@step_in`, which the three verifying places set (D7), so any page behind them has it; the banner is the `shared/banner` partial (kind `warning`), the confirmation is `shared/confirm`, and no new CSS class is added
- [ ] **AC-3.5** Given Leave When the host taps it Then this browser's cookie is deleted, the redirect (303) goes to `/games/:public_id` (the host's own seat page), the page has no bar, and the stepped-in order URLs give the stranger response again; a second Leave also redirects
- [ ] **AC-3.6** Given the host's own orders URLs (`/phases/:number/orders...`) while stepped in into France Then they show the host's own seat's orders, never France's, with or without `?power=france` in the query
- [ ] **AC-3.7** Given the host's own seat page and the host page Then the host's own seat page is still the page the host lands on after leaving, and host controls are still only in the `.host-section`
- [ ] **AC-3.8** Given a stepped-in host who opens a stranger page of their own game (a province that is not a unit, a phase that doesn't exist) Then the page is byte for byte the stranger page everyone gets (status, body, headers, cookies; spec 021 AC-5.5), with no bar, and the `step_in_` cookie is neither set nor deleted by it; and the 409 page of a revealed phase has no bar
- [ ] **AC-3.9** Given the host is stepped in on a browser that holds no seat cookie of its own (the host link opened on a second phone) When the host taps Leave, or the submit bar's own-seat link Then the redirect goes to the host page, never to a stranger page

### Story 4: Saving while stepped in is the player's save, nothing else

**As a** host
**I want** to enter France's orders the way France would
**So that** they are checked, atomic and refused after the reveal like any other

**Acceptance criteria:**

- [ ] **AC-4.1** Given a step-in into France When the host picks an order through the stepped-in pickers Then it is saved by `Seat#save_orders!` for France's seat, France's own phone then shows it on its order screen, and the redirect goes back to the stepped-in order screen
- [ ] **AC-4.2** Given a step-in into France When the host saves another power's unit, an illegal order or an unreadable one Then it is refused with the sentences of spec 022 and nothing is stored
- [ ] **AC-4.3** Given a step-in into France When the host submits Then France is marked submitted; and when a pick later changes an order, France is "not submitted" again (spec 022 AC-3.2)
- [ ] **AC-4.4** Given the source Then `save_orders!` is called from `seat.rb` and `seat_orders_controller.rb` only, as today: no second path, no step-in-specific writer of orders (`seat_write_scan_spec` is unchanged and passes)
- [ ] **AC-4.5** Given the host steps into France and tries to save through England's seat-scoped URL Then it is the stranger response and nothing is saved
- [ ] **AC-4.6** Given a step-in into France Then the order screen is headed "France's orders" (never "Your orders"), the submit bar's link to the host's own seat reads "Your own seat", the picker pages' links and forms stay on the stepped-in URLs, and the own-seat order screen is still headed "Your orders"

### Story 5: The step-in ends

**As a** table
**I want** a step-in to end on its own
**So that** a forgotten step-in can't be used later

**Acceptance criteria:**

- [ ] **AC-5.1** Given a step-in When the host reveals the phase Then the stepped-in order URLs give the stranger response, no page has the bar, and the new phase has no step-in
- [ ] **AC-5.2** Given a step-in row 31 minutes old (time travelled) Then the stepped-in URLs give the stranger response and no page has the bar; at 29 minutes it still works
- [ ] **AC-5.3** Given a cookie that is forged, signed for another game, names a row of another game, names a row of another seat than the URL's, names a missing row, or is presented without the host cookie Then it is ignored, and the stranger response follows on a stepped-in URL
- [ ] **AC-5.4** Given a host who holds the cookie but whose phase has been revealed and a new one opened Then they must confirm again for the new phase, and that is a new row

### Story 6: The seat's owner is told, and the game's history keeps it

**As a** player
**I want** to see that the host has been in my seat
**So that** the table stays honest

**Acceptance criteria:**

- [ ] **AC-6.1** Given a step-in into France in the open phase When France's phone opens its seat page Then one `.banner` reads "The host entered your orders at 8:42 PM UTC." with the time in `<time datetime>`; with two step-ins it lists both times in the one banner
- [ ] **AC-6.2** Given the same When France's phone opens its order screen Then the same banner shows there
- [ ] **AC-6.3** Given a step-in into France Then the stepped-in host's own view of France's order screen has no such banner, England's seat page and order screen show no such banner, and nobody's page shows which seats the host has entered
- [ ] **AC-6.4** Given a step-in made in an earlier phase Then France's pages don't show it, and the host page's history list ("Seat history" until 1.3.0, "History" since D11) does (phase title, power badge and name, the words "stepped in", time), oldest first, together with any reissues (D10, changed in 1.1.0)
- [ ] **AC-6.5** Given the time zone Then (a helper spec sets the variable around the call, as the passphrase specs do) a row made at 20:42 UTC reads "8:42 PM UTC" with no zone set, and "3:42 PM EST" with `TRUCEBEARER_TIME_ZONE=America/New_York` in November; an unknown zone name falls back to UTC
- [ ] **AC-6.6** Given the host page's history list Then it shows no order, count or submitted state, and it is its own partial (a step-in row and a reissue row alike, AC-10.6)

### Story 7: The reissue gap is closed

**As a** table
**I want** a reissued seat link to give the host no quiet way in
**So that** the host can never act as a seat without a record

**Acceptance criteria:**

- [ ] **AC-7.1** Given the host reissues France's seat and opens the new seat link on the phone that holds the host cookie Then the response redirects to France's confirmation page (not to the seat page), no seat cookie is set or replaced, the host's own seat cookie is untouched, no step-in is recorded yet, and France's orders are not shown
- [ ] **AC-7.2** Given the same When the host confirms Then it is an ordinary step-in: a row, the cookie, the bar, and France's notice (Story 2, 3 and 6); the seat link's token is not stored anywhere
- [ ] **AC-7.3** Given the host reissues their own seat and opens that new link on the host's phone Then the seat cookie is set as today, and it is not a step-in
- [ ] **AC-7.4** Given a phone with no host cookie and no step-in opens a reissued seat link Then it is the seat's new holder as today: the cookie is set and the redirect goes to the seat page
- [ ] **AC-7.5** Given a browser that holds the host cookie and France's seat cookie (France's link opened first in a clean browser, the host link afterwards) When it opens its seat page, the order screen, a picker step or the orders endpoint Then it is redirected to France's confirmation for the open phase, France's seat cookie is deleted by that response, no order of France's is shown, nothing is saved, and no row is written; after confirming it is an ordinary step-in
- [ ] **AC-7.6** Given a wrong, old or malformed token Then the stranger response is the same for the host cookie as for any other (spec 021 AC-5.5)
- [ ] **AC-7.7** Given the reissue confirmation page Then it still says the seat's saved orders for this phase are deleted with it, and its text adds that opening the new link on the host's own phone counts as stepping in

### Story 8: Order secrecy still holds, and the exception is written down

**As a** player
**I want** the secrecy proofs to know about the step-in
**So that** the one sanctioned way in is the only way in

**Acceptance criteria:**

- [ ] **AC-8.1** *(route table)* Given the three kinds of new route Then each is classified in `spec/support/secrecy_routes.rb`: the confirmation, the record and Leave as `shows: :none`; the stepped-in screen, picker and endpoint as `shows: :stepped_in` (one seat's orders to the host inside a recorded step-in, and no one else); the route table spec lists exactly the routes that may show orders: the four `:own` routes of spec 023 (its existing assertion is unchanged) and, in a new assertion, the three `:stepped_in` routes; the changed seat-link entry says it may redirect a host to a confirmation
- [ ] **AC-8.2** *(invariance sweep)* Given England's orders go through none, some, all and different, and the viewers are another seat, the host with a seat of its own, the host with no seat, a stranger, the host with France's seat cookie, and the host stepped into France (each its own session, the step-in made when the viewers are set up and before the baseline, so its banner is the same in every snapshot) Then every readable route, including the two stepped-in GET routes swept for England and for France (a Hash of paths, as spec 023 does), answers each of these viewers identically whatever England has ordered; in particular the host **without** a step-in gets the stranger response on England's stepped-in URLs, the host with France's seat cookie is redirected on the own-seat routes, and the host stepped into France gets the stranger response on England's. The seat-link entry stays `fresh`, so its host-cookie branch is covered by AC-7.1, not the sweep
- [ ] **AC-8.3** Given the host stepped into England Then the host sees only England's orders: England's stepped-in screen shows England's orders (a positive control that the sweep isn't comparing four copies of one page), France's stepped-in URLs give the stranger response, and no other page for the host (own seat, host page, reveal page) changes with England's orders
- [ ] **AC-8.4** Given a request log of the three steps (open the confirmation, confirm, open the screen) Then the confirmation page and the stepped-in URLs before confirming show no order, and the first request that shows France's order is made after a `StepIn` row exists for it
- [ ] **AC-8.5** Given the host page, the reveal page and the confirmation page Then none carries an order, a count, an ordered unit or a submitted state of any seat other than what spec 022 AC-4.1 already allows (the powers that have not submitted), and the same holds for the host page's history with reissue rows in it (AC-10.6)
- [ ] **AC-8.6** Given the source Then the stepped-in order screen and picker carry `Cache-Control: no-store`, `Referrer-Policy: no-referrer` and the Turbo no-cache meta (spec 022 AC-7.6); the constant `StepIn` is named only by its model, `Game`, `Seat`, the step-in controller, the access concern, the seat link controller, the step-in partials and helper, and the migration and schema (a scan spec); a use of the constant `Reissue` appears only in its model, `Game`, and the migration and schema (the same scan spec, AC-10.7); and the saved-orders boundary spec of spec 022 is unchanged and passes
- [ ] **AC-8.7** Given forgery protection on When a step-in is confirmed or left without a token Then it is refused and nothing changes
- [ ] **AC-8.8** Given the stranger comparison of spec 021 (`comparable` in `spec/support/responses.rb`) Then it also compares any `step_in_` cookie line, so a stranger page that set or deleted one would fail

### Story 9: The screens at 360 pixels

**As a** host
**I want** the pages to fit a phone
**So that** I can use them at the table

**Acceptance criteria:**

- [ ] **AC-9.1** *(system spec)* Given a viewport 360 pixels wide When the host opens the confirmation page, the stepped-in order screen with the bar, the host page with the seat history (a step-in row and a reissue row in it), and France's seat page with the notice Then none scrolls sideways, every button and link is at least 44 pixels high, and the bar's Leave button is visible without scrolling on the stepped-in order screen
- [ ] **AC-9.2** Given those four pages Then screenshots at 360 pixels are saved to `web/docs/specs/026-step-in/screens/`, and the pull request shows them

### Story 10: The game's history records every reissue (added in 1.1.0, Issue #104)

**As a** table
**I want** the host page to show every reissue next to the step-ins
**So that** a seat that changed hands leaves a trace, even when nobody stepped in

**Acceptance criteria:**

- [ ] **AC-10.1** *(the first test)* Given a game in which the host holds a seat and France holds a seat When the host reissues France's seat and opens the host page Then the page's history has one row for France, whose text says "seat reissued" with the open phase's title and a time in `<time datetime>`, and no order text appears anywhere in the history
- [ ] **AC-10.2** Given a reissue Then exactly one `reissues` row exists for that phase and seat, written in the same transaction as the new token and the cleared orders; a second reissue of the same seat writes a second row; a reissue that is refused (a stranger, a seat that is not held, a phone that is not the host's, a missing form token) writes none; a reissue whose row can't be written leaves the old token in place; and a reissue of a seat with no submission still sends no status broadcast, while one that withdrew a submission sends one, as before (spec 024 D3)
- [ ] **AC-10.3** Given the host's own seat When the host reissues it Then a row is written for it as for any seat (spec 021 AC-7.10)
- [ ] **AC-10.4** Given a step-in and two reissues made at known times in one phase and a later phase Then the history lists all three rows in time order, oldest first, with the phase of each, and a row in an earlier phase stays after that phase is revealed
- [ ] **AC-10.5** Given a `Reissue` row Then updating or destroying it raises (append-only, as `StepIn`), and its seat must belong to its phase's game
- [ ] **AC-10.6** Given the host page's history with a reissue row and a step-in row in it Then it carries no order, count, ordered unit, token, link or submitted state, whatever the seats had ordered, and the invariance sweep of Story 8 is run with a reissue row and a step-in row in the history before its baseline: England is reissued once, before any session opens and before England's orders vary, and England's viewer uses the new token (so no viewer's cookie or link is invalidated by it)
- [ ] **AC-10.7** *(source scan, in the step-in boundary spec)* Given the source Then a use of the constant `Reissue` (`Reissue.`, `Reissue::`, `Reissue <`, matched as a constant, never the word in text) appears only in its model and `Game`, plus the migration and schema; `Game` has no `through: :reissues` association; `reissue.rb` names no `saved_order` or `orders_for`; no view or controller reads `reissues`; and `reissues` has no column that could hold an order
- [ ] **AC-10.8** Given France's phone and England's phone after a reissue of France Then neither seat's page nor order screen shows the history (no `[data-seat-history]`, whatever its heading) or any new banner (no notice is added), and the stranger response and every existing step-in behavior are unchanged

### Story 11: The host page has one history (added in 1.3.0, Issue #112)

**As the** host **I want** one list of what has happened in the game **So that** I read the game's log in one place and not in three

**Acceptance criteria:**

- [ ] **AC-11.1** *(the first test, a request spec)* Given a game with one reveal, one step-in and one reissue made at known times When the host opens the host page Then the page has exactly one `[data-seat-history]` section, headed "History", whose rows are the reissue, the step-in and the reveal in the order of their times (the page has no heading "Earlier results", "Revealed phases" or "Seat history", and no `[data-history]`)
- [ ] **AC-11.2** Given a reissue, a step-in and a position edit of phase 1 and the reveal of phase 1, all made at one frozen instant, and a reissue and a position edit of phase 2 at the same instant Then `Game#host_history` lists them phase 1's reissue, step-in, position edit, the reveal, then phase 2's reissue and edit; `Game#seat_history` is unchanged (it holds no reveal)
- [ ] **AC-11.3** Given a reveal row Then it is a link to `/games/:public_id/host/phases/:number/results`, which is 200 for the host, and the row reads the phase title, "revealed" and the time in `<time datetime>`, and no outcome, order or tag
- [ ] **AC-11.4** Given two revealed phases When the host opens the host page Then it has no "Earlier results" heading, both phases are reveal rows linking to their results pages, and the latest phase's results section is still drawn; and the seat page of the same game still has its "Earlier results" list (spec 025 AC-6.1)
- [ ] **AC-11.5** Given no reveal and no seat event Then the section is just the sentence "No phase has been revealed yet."; given a reissue and no reveal Then the sentence is above one row; given a reveal and no seat event Then it has one row and no sentence; and (a model example) the open phase is never a reveal row, even with saved orders and submissions in it
- [ ] **AC-11.6** Given the history with a reveal row, a reissue row, a step-in row and a position edit row in it Then the page carries no order, count, ordered unit, token, link or submitted state of the open phase, and the invariance sweep of Story 8, in its "after one reveal" context (spec 025), compares the host page with all four rows present, before its baseline; a control example, like AC-10.6's, asserts that the swept History holds a reveal row
- [ ] **AC-11.7** *(source scan, in the step-in boundary spec)* Given the source Then `host_history` is read only in the history partial and `Game` (the readers pattern of AC-10.7 gains it), and the constant `Game::RevealEntry` is named only in `game.rb`
- [ ] **AC-11.8** *(system spec)* Given a viewport 360 pixels wide When the host opens the host page with a History holding a reveal, a step-in, a reissue and a board change Then the page does not scroll sideways, every row's link and button is at least 44 pixels high, and a long board-change row wraps and does not overflow, and the screenshots in `docs/specs/026-step-in/screens/` (the seat-history one) and `docs/specs/027-position-editor/screens/` (the host-history one) are retaken so they show the new heading

## Functional Requirements

### FR-1: The record
`StepIn` belongs to a phase and a seat and is append-only (D1). `StepIn.record!(phase:, seat:)` writes a row. A step-in is **active** under the rules of D2, in one place (`StepIn#active?`, read against the database so a reveal ends it at once). `Reissue` (D10) belongs to a phase and a seat and is append-only; `Game#reissue_seat!` writes it in its own transaction.

### FR-2: Who is acting
A single access helper decides who acts on a seat-scoped URL: the host, with a valid host cookie, whose step-in cookie names an active row for that seat. It sets `@seat` and `@step_in` for the shared order controllers (D4) and gives the stranger response otherwise. A seat's own URLs never consult the step-in cookie.

### FR-3: The seat link
The two rules of D5: the seat link and the resolver (`require_seat`, and the seat page). The decision uses the token only to find a seat and never writes it. It happens after the rate limit and has the same `Referrer-Policy` as before.

### FR-4: The bar, the notices and the list
Three small partials: `step_ins/_bar` (layout, D7), `step_ins/_notices` (the owner's banner, D6, on the seat page and the order screen), `step_ins/_history` and `step_ins/_entry` (the host page's list and entry, D6 and D8). A view helper formats a time (D6).

### FR-5: Secrecy
Every new route is classified. The sweep and the scans are updated (Story 8). The classification gets one new value, `:stepped_in`.

## Non-Functional Requirements

### Security
- The step-in cookie holds a row id only and is signed. A forged cookie, or one without a valid host cookie, does nothing.
- The confirm and leave routes are `POST` and `DELETE` forms and need the CSRF token.
- No order appears in the record, the notice, the flash, the log or any URL (spec 022 FR-9 holds). The step-in routes' `orders` parameter is filtered like the others.
- The seat link reveals nothing new to a stranger: a request without the host cookie behaves exactly as before.

### Reliability
- The row is written in one statement before the redirect. If it fails the request fails and no cookie is set.
- A reveal at the same moment as a confirmation can leave a row for a phase that is already revealed. It is inactive at once (D2) and records the truth: the phase it names.

### Accessibility and layout
- The bar's words say the state (never colour alone). The pages are normal pages with their own URLs and work without JavaScript (the app adds none for this feature). Tap targets are at least 44 pixels.

## Error Scenarios

| Situation | Result |
|-----------|--------|
| A stranger, a seat or another game's host opens a step-in URL | Stranger response, nothing written (AC-1.4) |
| The host opens a step-in URL for their own seat, an empty seat, or a non-power | Stranger response (AC-1.5) |
| The host opens a stepped-in order URL before confirming | Stranger response, no order shown (AC-2.2) |
| The host confirms after the phase was revealed in the meantime | Redirect to the confirmation for the open phase, nothing written (AC-1.7) |
| The 30 minutes pass, the phase is revealed or the cookie is forged | Stranger response on stepped-in URLs, no bar (Story 5) |
| The host saves a bad order while stepped in | The refusal of spec 022, nothing stored (AC-4.2) |
| The host saves after the reveal | The 409 page of spec 022; the step-in has ended too |
| The host presents a reissued link on their own phone, or holds another seat's cookie | Redirect to the confirmation page, nothing stored (AC-7.1, AC-7.5) |
| The host confirms twice | Two rows (AC-2.5) |

## Open Questions

1. **Should every seat see the history (step-ins, and since 1.1.0 reissues), not only the one entered?** This spec tells the owner and keeps the list on the host page, as the Issue asks. A list on every phone would be a stronger deterrent and costs one partial; it would also tell the table which seats the host entered. Handed to the maintainer. It is not needed to close this Issue.
2. **A time zone setting for the game.** `TRUCEBEARER_TIME_ZONE` is per instance. A game-level or viewer-local zone needs a setting or a script (D6) and is left to a later Issue.

## Out of Scope (Future Considerations)

- ~~Recording every reissue~~ Done in 1.1.0 (D10, Issue #104) as a host-page history record. **Still out of scope:** telling a seat's owner that their seat was reissued (a notice like D6's), which only the maintainer can ask for.
- **Showing the step-in and reissue history to every phone**, and in the results of #25.
- **#24** (live status) and **#25** (results) must classify their routes in the table; neither shows a step-in.
- **#27** (the position editor, spec 027) clears every seat's orders when units move; a step-in sees what is left.
- A game-level time zone and a viewer-local time (D6).

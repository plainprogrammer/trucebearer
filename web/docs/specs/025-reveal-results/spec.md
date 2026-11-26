# Feature 025: Reveal results to every phone at once

**Status:** Approved
**Version:** 1.1.0
**Created:** 2026-11-26
**Last Updated:** 2026-11-26
**Issue:** #25
**Branch:** `web/25-reveal-results`

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 1.1.0 | 2026-11-26 | Amended by spec 024 version 1.2.0 (catch up when a phone wakes or reconnects, #105). Approved at Gate A with spec 024 1.2.0.<br>• The signed results name on the four pages of D2 carries the phase the page was drawn for: it verifies to `results:<public id>:<number>` and not `results:<public id>`. AC-3.4 and AC-4.3 are read that way. The **stream** is still `results:<public id>`, and the broadcast, its one message, its one attribute and every proof of AC-4.1, AC-4.2, AC-4.4 and AC-4.5 are unchanged. The message is now built by `Game#results_refresh_message` and sent with `broadcast_stream_to` (the same bytes as `broadcast_refresh_to(…, request_id: nil)`). AC-4.6 is read as spec 024 AC-2.7(c) and AC-9.7 now say: `Turbo::StreamsChannel` is also named by the two channel files as their parent, and `transmit` only there.<br>• The four pages name `ResultsChannel` (a small subclass of `Turbo::StreamsChannel`) through `turbo_stream_from`'s `channel:` option. When it subscribes with the name of a phase that has been revealed, it transmits the same one refresh a reveal broadcasts, so a phone that slept through the reveal is redrawn when it reconnects (spec 024 D10, AC-9.4).<br>• The Known limit "missed messages" is closed for pages that carry the stream; the dropped-refresh-during-navigation case stays. The Non-Goal on replaying a missed message, the last sentence of D3, the error row "A phone was offline for the reveal", FR-3's `broadcast_refresh_to` sentence (now `broadcast_stream_to` with `results_refresh_message`), D2's `turbo_stream_from :results, @game.public_id` (now with the phase number and `channel: ResultsChannel`) and the Known limit "Missed messages" (which says the catch-up is not added here) are read the same way: such a phone is refreshed when its socket resubscribes, and a reload is still always right. Every other criterion holds unchanged. |
| 1.0.0 | 2026-11-26 | Approved at Gate A by the coordinator under the maintainer's delegation, with D5 (the 303) and its amendments to specs 022, 023 and 024. The follow-up that folds "Earlier results" into #104's history list is opened by the coordinator after both merge, not by this pull request |
| 0.3.0 | 2026-11-26 | Changed after the second Fable review (2 blocking, 11 non-blocking, all taken; not re-reviewed, round 2 being the last): AC-1.4 is a per-row mapping with the pairs stated; AC-5.3 names the two allowed differences, keeps the swept pickers occupied and sweeps the stepped-in screens for both numbers; `PhaseResults` also returns the dislodged units' banner data from the hash form; a dislodged implied hold's note drops "so it held"; the paradox and dislodged banners are told apart by a data attribute; AC-3.1 waits for the right number of sources; D1 states that production delivery is batched and the test adapter is not Solid Cable; D9 and AC-9.2 list the specs that the always-`no-store` and the 303 break |
| 0.2.0 | 2026-11-26 | Changed after the first Fable review (5 blocking, 12 non-blocking, all taken): the sweep's second world requests the open phase's own pages, with phase numbers in its context (AC-5.2 to AC-5.5); void orders, foreign units and units off the board have stated rows, and an implied hold's note is true when a void order exists (D8, FR-1, AC-1.3, AC-1.6, AC-1.9); a convoy paradox gets one warning line (D6, AC-7.4); the banner source is the stored position, only for the latest phase (D8, AC-2.2, AC-2.6); the amendments to spec 024's AC-4.1 and AC-4.5 are named (AC-9.1, AC-9.2); the refresh is sent with no request id, so it is exactly one attribute, and the host's banner is protected by timing, not by request-id suppression (D1, AC-3.3, AC-4.2); the host with France's seat cookie, header order, the stepped-in revealed GET, a refresh dropped mid-navigation, a skip link, the follow-up to fold the two host lists, the wording of `void` and `disrupted`, fixture rules, word lists |
| 0.1.0 | 2026-11-26 | First draft, for Gate A |

## Problem Statement

The table's rhythm is: talk, enter orders, reveal, move pieces. Spec 022 made the reveal real (it adjudicates, stores the result, opens the next phase) but shows nobody the result: the host sees one sentence, and every phone keeps its old page. Spec 024 left the seat page "half stale" after a reveal on purpose and named this Issue as the owner. Players need to read every power's orders and what became of them, off their own phones, at the same moment, so that someone can move the pieces on the physical board. The host needs a view built to be read aloud and to guide the moving of pieces, with dislodged units first.

This feature makes the stored result visible, to the people entitled to it and no one else, only after the reveal, and makes every phone switch to it when the host reveals.

## Goals

- When the host reveals, every open seat page, order screen, picker step and host page for that game switches to the new state within about a second, with no tap, through Turbo Streams over Solid Cable.
- After a reveal, every seat and the host can read every power's orders for the revealed phase, each with its outcome in plain words of our own.
- The host gets a reading view of the same results: grouped by power, dislodged units first, in larger type.
- Past phases' results stay readable, from a plain list.
- Nothing about an order is ever broadcast, and the open phase's orders stay as secret as before; the proof of both is a test.
- A stranger sees nothing.
- The results are drawn only from the documented hash form of the stored adjudication, so the gem's 0.2.0 results work unchanged (#29).
- The three components `.result-row`, `.outcome-tag` and `.result-group` are built to `web/docs/design-system.md` and added to `/styleguide`.

## Non-Goals

- A map, or any picture of the position: text only.
- Real adjudication. Until #29 the results come from the stand-in and are fake; this feature says so (D6) and does not improve them.
- The host's position editor (#27), retreats and builds, a phase clock, notifications, sound or vibration.
- Replaying a message a phone missed while offline (Issue #105 tracks it; a reload is always right).
- Any JavaScript beyond `turbo-rails`: no Stimulus controller, no custom channel class, no new gem.
- Showing a step-in in the results (spec 026 says neither this feature nor #24 may).
- Changing how adjudication, the reveal, or the next phase is computed.

## Users and Context

**Primary users:** Players at a table, each on their own phone, who read the results and move pieces. The host, who reveals, reads the results aloud and settles dislodged units by hand.
**Secondary users:** A screen-reader user (outcomes are words, never colour alone). A player on a poor connection, whose page must still be right when it loads.
**Usage context:** Seconds after the host taps "Reveal" at the table. Phones are in hands, screens are 360 pixels wide, and half the table is looking at the board, not the phone.
**User mental model:** "The host revealed. My phone now shows what everybody ordered and what happened to each order."

## Decisions

Gate A is asked about D1, D3, D4, D5, D6 and D7.

**D1. A phone switches by a page refresh that carries nothing.** The reveal broadcasts one Turbo **refresh** (`<turbo-stream action="refresh">`, with no content and no children) to a stream of its own, `results:<public id>`. Each subscribed phone then reloads its own page through its normal, authorized request, so what it shows is decided by the same access checks as any page load, and the broadcast carries no order, no result, no phase number and no count. Rendered results are never streamed. The refresh is morphed (`turbo_refreshes_with method: :morph, scroll: :preserve`, on the pages that subscribe) so a phone keeps its scroll position and focus. The refresh is sent with **no request id** (`request_id: nil`; Turbo would otherwise copy the client's own `X-Turbo-Request-Id` header into the message, a string a client chose), so the message is exactly one attribute, `action="refresh"`. The browser that made the reveal request is on the reveal confirmation page, which does not subscribe (D2), and its redirect target subscribes only after the message was sent (Solid Cable delivers a subscriber only messages sent after it subscribed), so the "was revealed" banner on the host page is not lost to a second load. A host's other tab on the host page does refresh, as it should. Two facts limit what the tests prove: in production Solid Cable writes broadcasts through a short batch delay (1 millisecond by default), so "sent before the redirect" is a margin of a whole HTTP round trip and not an ordering guarantee; and the test environment uses the in-process test adapter, so the system specs exercise Turbo and the page, not Solid Cable's own delivery (spec 024 made the same choice).

*Why not stream the rendered results:* every payload would have to be proved free of anything a stranger holding a stolen stream name must not read, for markup that will change with every gem release (#29, 0.3.0). A refresh makes the secrecy of the results the secrecy of an ordinary page, which this app already proves with the route table, the invariance sweep and the source scans.

*Why a second stream and not #24's:* spec 024 proves that stream's payload is exactly one `update`/`morph` of the seven rows, byte for byte, and that only one method broadcasts (its AC-3.1, AC-2.7). A refresh on it would change that proof. A leaked `results` name receives only "a phase was revealed" (the time of a reveal, no content).

**D2. Which pages subscribe.** `turbo_stream_from :results, @game.public_id`, and the refresh meta, are in one partial, `results/_live`, rendered by exactly these pages: the seat page (`GET /games/:public_id`), the host page (`GET /games/:public_id/host`), the order screen (`GET .../phases/:number/orders`) and the picker step (`GET .../orders/:province`), the last two on the seat's own URLs only, never on a stepped-in URL (a step-in ends at the reveal, and its refresh would be a stranger page). This is a change to spec 024, which said the signed status name is only on the seat page and the host page: the **results** name is also on the order screen and the picker, and the status name is not (AC-3.4, AC-9.1). Every other page is correct on load and does not subscribe: the reveal confirmation (a refresh would only be redirected to the host page, and the page already redirects when loaded for a revealed phase), the results pages themselves (they are about a finished phase), the join, close, reissue and step-in pages. The signed name appears in no other response, and never to a stranger. It names one game's `results` stream, which carries nothing but the refresh. The name never expires (Turbo's verifier has no expiry); a copy gives its holder the fact that a reveal happened, and nothing else.

**D3. When the broadcast is sent.** From one place: `Phase#reveal!`, after its transaction has committed and only when this call revealed (`status == :revealed`), as `game.broadcast_results_refresh`, beside the existing `broadcast_seat_status`. A reveal that finds the phase already revealed (`:already`), a reveal that fails (the gem raises `InvalidInput`), a stale request, and every save, submit and reissue send nothing on this stream. The call to the channel is rescued (`StandardError`): it logs one warning with the exception's class only and carries on, because the reveal has been committed and an error page for it would invite a second tap. A phone that misses the message (asleep, offline, or in the middle of a navigation, when Turbo drops a refresh) shows the old page until it is reloaded or touched; a reload is always right (Known limits).

**D4. What a viewer reads after the reveal.** The stored adjudication is the only source (never the saved orders, so the saved-orders boundary of spec 022 AC-7.8 does not move). A viewer sees results only of a **revealed** phase:

| Viewer | Revealed phase | The open phase or a later one |
|---|---|---|
| A seat (including the host's own seat) | Every power's orders, with outcomes, on the seat's results page and on the seat page | Its own orders only, as before |
| The host | The same, as the reading view, on the host page and the host results page | Nothing about orders (spec 022 AC-7.5), as before |
| A stranger | Nothing: the stranger response | Nothing |

A results URL for the open phase, a later phase, an unknown or malformed number is the stranger response for everybody, so a results page can never exist for an open phase. The host reads the reading view without a seat; the host's own seat page shows the player version.

**D5. The routes, and the pages that change.**

| Route | Who | Shows |
|---|---|---|
| `GET /games/:public_id/phases/:number/results` (new) | A seat | The player version of one revealed phase's results |
| `GET /games/:public_id/host/phases/:number/results` (new) | The host | The reading view of one revealed phase's results |
| `GET /games/:public_id` | A seat | Adds the latest revealed phase's results (player version) above everything else on the page but the heading and the phase header (FR-3), and the list of earlier ones |
| `GET /games/:public_id/host` | The host | Adds the latest revealed phase's reading view and the list of earlier ones, in a section of its own that leaves the "Revealed phases" list alone (Issue #104 changes it) |
| `GET /games/:public_id/phases/:number/orders` and `.../orders/:province` | A seat, own URL | For a **revealed** phase: a 303 to that phase's results page, instead of spec 022's 409 page. On the picker the redirect comes before the province check, as the 409 page does today. `PUT` keeps its 409 and its sentence |
| `GET /games/:public_id/host/seats/:power/phases/:number/orders` and `.../orders/:province` | The host, stepped in | Unchanged: a revealed phase's stepped-in URL is still the 409 page (spec 026 AC-3.8); spec 026 is not amended |

Both new routes are plain Turbo Drive pages with meaningful URLs (Hotwire Native). They have no write verb. A phase number is matched strictly, as everywhere (`find_phase`).

**D6. Wording, and the stand-in note.** One table maps each outcome symbol of the gem's contract (`:void`, `:held`, `:no_route`, `:bounced`, `:succeeded`, `:unmatched`, `:cut`, `:disrupted`, `:given`) and the flag `dislodged` to words of our own, shown in a tag in the mono face. The table is a constant in a helper, read with `fetch`, so a symbol the table lacks fails loudly in a spec and never silently on a phone.

| Symbol | Tag | Meaning in words (for the spec; not shown) |
|---|---|---|
| `succeeded` | Succeeded | The unit moved |
| `bounced` | Bounced | The move did not happen |
| `no_route` | No route | A move that needed a convoy had no working route |
| `held` | Held | The unit stayed |
| `given` | Given | The support or the convoy was given |
| `cut` | Support cut | The support was cut |
| `unmatched` | Not used | The support or convoy matched no move, so it did nothing |
| `disrupted` | Convoy disrupted | This convoying fleet was dislodged (so the unit also carries the Dislodged tag) |
| `void` | Not a legal order | The order did not count: it failed the checks, or was for a unit that is not the power's own or is not on the board |
| `dislodged` flag | Dislodged | The unit was forced out |

A dislodged outcome shows the **Dislodged** tag first, in the danger tone, followed by its result's tag, except that a `held` result's tag is dropped (a unit shown as both "Dislodged" and "Held" reads as a contradiction). A unit with no legal order shows its implied hold with the words "No valid order, so it held" in muted text (true whether the power gave no order or gave a void one; a void order gives two rows, the order and the implied hold, as the gem says). When that implied hold was dislodged the note reads "No valid order" alone, so it does not contradict the Dislodged tag. Colour is never the only signal: every tag is words.

*The stand-in note.* While the stand-in adjudicates (until #29), every results view carries one quiet line, in muted text, above the groups: "Practice results. The rules engine isn't connected yet, so these outcomes are made up and can be wrong. Don't move pieces by them." It appears when `RulesEngine.stand_in?` is true. That method is defined next to the stand-in, and #29 deletes it, the partial `results/_practice_note`, and the note's rule together. The display itself reads only `phase.adjudication.to_h`, whatever produced it.

*A paradox.* When the stored `paradox` is true, the gem says every outcome and unit placement is unspecified (0.2.0, "Convoy paradoxes"). Every results view then carries one `warning` banner above the groups, marked `data-paradox` so it can be told from the dislodged-unit banners (which are marked `data-dislodged`): "The rules engine found a convoy paradox in this phase, so these outcomes can't be trusted. Settle this phase by hand." The rows are still drawn. The stand-in never sets it; the tests use a hand-built hash.

**D7. The history.** A plain list, no separate page: on the seat page and on the host page, under the latest results, a list "Earlier results" (shown only when at least two phases have been revealed) with one link per earlier revealed phase, newest first, each to that phase's results page for the viewer's kind (the player version for a seat, the reading view for the host). A results page links back to the viewer's own seat page, or the host page.

**D8. Row, group and the reading view.** `.result-row` is one outcome: the unit's icon (decorative, a visible name beside it), the unit as "Fleet in London (LON)", the order in words (`order_words`), then the tags. The unit is the one standing in the order's `at` province in the phase's starting position **when it belongs to the order's power**. When no unit stands there, or one belongs to another power (a void order for a unit that is not the power's own), the row has no icon and reads "Order for LON", is drawn under the order's own power, and `order_words` is given no unit (it then adds no "needs a convoy" remark). `.result-group` is one power: its badge as a heading and its rows, in the order the stored result gives them (submitted orders, then implied holds), except that dislodged rows come first. Groups are in the gem's power order, except in the reading view, where groups holding a dislodged unit come first. A power with no orders and no units has no group. `.result-group--reading` has larger type and looser rows. The reading view's dislodged units are the host's existing warning banners from spec 022 AC-5.4 (one per unit, "Settle it by hand."), moved to the top of the results section and not repeated in other words. The latest revealed phase's stored `adjudication.position.dislodged_units` is the authority for the banners, and only the **latest** revealed phase has banners: an earlier phase's host results page keeps its `Dislodged` tags and has no banner, because "settle it by hand" is no longer true of it. The rows' tags come from the outcomes' flags. `PhaseResults` returns the banner data (power, unit type, province) from that hash form too, so no view reads a gem object. The gem does not validate that the two agree, so the tests build every dislodged fixture with one builder that sets both, and a spec asserts the banner count equals the tag count for it.

**D9. The page after a reveal is a normal page.** The seat page, the host page and the results pages send `Cache-Control: no-store` always (not only after a reveal, so the sweep sees one header whatever the state), and the seat page and host page keep spec 024's `turbo-cache-control: no-cache`. They carry orders of a revealed phase, which the table may read but a shared computer's Back button should not bring out. On the results pages, the seat page and the host page the header is set after the access check, so the stranger response stays byte for byte the one everyone gets (the filter order of `SeatOrdersController`). This breaks one example of `spec/requests/host_spec.rb`, which asserts the host page is not `no-store` without the token (AC-9.2).

## User Stories and Acceptance Criteria

### Story 1: A player reads the results after the reveal

**As a** player **I want** to see what everyone ordered and what happened **So that** I can move the pieces

- [ ] **AC-1.1** Given England moved London to the North Sea and the host revealed the phase When France opens its seat page Then the page has a results section for that phase (its title, "Spring 1901 · Movement") with a `.result-group` for England holding a `.result-row` whose text includes "Move to North Sea (NTH)" and an `.outcome-tag` reading "Succeeded". This is the first test written
- [ ] **AC-1.2** Given the same state When France opens `GET /games/:public_id/phases/1/results` Then it is 200 and shows the same groups for the player version (AC-1.1's assertions hold), with the phase title, a link back to the seat page and no `.result-group--reading`
- [ ] **AC-1.3** Given a revealed phase in which every order kind occurs (a hand-built stored result: a hold, a move, a convoyed move, a support, a convoy, an implied hold) Then each `.result-row` shows the order in words with full province names and the abbreviation in mono, exactly as spec 023 FR-3 words them. An order for a unit that is not on the board, and one for a unit that is another power's, read "Order for LON" under the order's own power, without an icon, whatever the order kind (a plain move included, so `order_words` never meets a missing unit type)
- [ ] **AC-1.4** Given a hand-built stored result built by the one fixture builder (which obeys the gem's "Impossible objects" rules: a result that suits its order class, no dislodged void order, submitted outcomes before implied holds, implied holds sorted by province) in which each of the nine symbols occurs once, with `dislodged` set on the `disrupted` fleet, on one `held` unit and on one `bounced` move Then, row by row, the tags read: `void` "Not a legal order"; `held` "Held"; `no_route` "No route"; `bounced` "Bounced"; `succeeded` "Succeeded"; `unmatched` "Not used"; `cut` "Support cut"; `given` "Given"; the dislodged `disrupted` row "Dislodged" then "Convoy disrupted"; the dislodged `held` row "Dislodged" alone (its "Held" tag dropped); and the dislodged `bounced` row "Dislodged" then "Bounced". The order of the rows is AC-1.5's, not the symbols'
- [ ] **AC-1.5** Given a revealed phase Then every power with a unit or an order has a `.result-group` headed by its badge (name beside colour), in the gem's power order, and a group's dislodged rows come first
- [ ] **AC-1.6** Given an implied hold (a unit with no legal order) Then its row reads "Hold", carries "No valid order, so it held" in muted text, and shows the "Held" tag; given a void order whose unit then holds Then there are two rows for the unit, the void order with "Not a legal order" and the implied hold; and given a dislodged implied hold Then its note reads "No valid order" and its tags are "Dislodged" alone
- [ ] **AC-1.7** Given a game in which no phase has been revealed Then the seat page and the host page have no results section and no "Earlier results" list
- [ ] **AC-1.8** Given a phase number that is the open phase, a later one, unknown, or not digits with no leading zero When a seat requests its results URL Then the response is the stranger response (404, byte for byte what a stranger gets)
- [ ] **AC-1.9** Given a revealed phase When a seat opens its seat page Then the results section starts with a link "Skip to orders" (an in-page anchor to the "Enter orders" button, at least 44 by 44 pixels) so a phone is not made to scroll the whole result

### Story 2: The host reads the results aloud

**As the** host **I want** a view built for reading **So that** I can say what happened and settle the dislodged units

- [ ] **AC-2.1** Given a revealed phase When the host opens the host page Then above the "Host" section there is a results section whose groups are `.result-group.result-group--reading`, and whose type size is larger than the player version's (measured in a system spec)
- [ ] **AC-2.2** Given the latest revealed phase has a dislodged unit (one fixture builder sets both the stored position and the outcome's flag) When the host opens the host page Then the results section starts with the spec 022 warning banners, one per dislodged unit and each once on the page (not repeated as a second warning in the rows), their count (the elements marked `data-dislodged`) equals the count of `Dislodged` tags, groups holding a dislodged unit come before the others, and a dislodged row comes first inside its group
- [ ] **AC-2.3** Given a revealed phase When the host opens `GET /games/:public_id/host/phases/1/results` Then it is 200 with the reading view for that phase, a link back to the host page; for an open, later, unknown or malformed number, or for a viewer who is not the host (a seat, a stranger, a junk cookie), it is the stranger response
- [ ] **AC-2.4** Given the host's own seat page Then it shows the player version (AC-1.1), never the reading view
- [ ] **AC-2.5** Given the host has not stepped into any seat Then the host page shows the results of every power and none of the open phase's orders (the spec 022 AC-7.5 assertions on the host's pages still hold for the open phase)
- [ ] **AC-2.6** Given two revealed phases the earlier of which had a dislodged unit When the host opens the earlier phase's results page Then it shows that phase's `Dislodged` tags and no `data-dislodged` banner, and the latest phase's page and the host page show banners for the latest phase only (spec 022 AC-5.4 unchanged)

### Story 3: Every phone switches at the reveal

**As a** player **I want** my phone to move to the results when the host reveals **So that** I never have to ask whether it happened

- [ ] **AC-3.1** Given two Capybara sessions at 360 pixels, the host's on the host page and France's on its seat page, both subscribed (every `turbo-cable-stream-source` present is `[connected]`: two on the seat page and the host page, one on the order screen and the picker, waited for by count) When the host reveals from a third session Then within 5 seconds France's seat page shows the results section and the new phase's header, without a reload, and the host's other session shows the reading view. Nothing scrolls sideways and no control is under 44 by 44 pixels on any of these pages
- [ ] **AC-3.2** Given a phone on the order screen or a picker step of the phase (its own URL) When the host reveals Then within 5 seconds the phone is on that phase's results page (the refresh meets the 303 of D5)
- [ ] **AC-3.3** Given the host browser that made the reveal request from the confirmation page Then it ends on the host page with the "was revealed" banner showing, and a system spec checks the banner is still there after 2 seconds (D1: the message was sent before the redirect target subscribed)
- [ ] **AC-3.4** Given the seat page, the host page, the order screen and the picker step Then each contains exactly one signed stream name that `Turbo.signed_stream_verifier.verified` resolves to `results:<that game's public id>` (never by a substring test, which cannot tell the two streams apart), and `turbo-refresh-method` set to morph, through `results/_live`; the seat page and the host page keep their one status name as well, so each holds exactly two `turbo-cable-stream-source` elements, and the order screen and the picker hold one; no other page of the app, a stepped-in orders page included, contains either name, and a stranger's page never does
- [ ] **AC-3.5** Given a page loaded or reloaded without any live connection after a reveal Then it shows the results (page-load correctness; the broadcast is a convenience, never the way a page learns)

### Story 4: Nothing about an order is ever broadcast

**As a** player **I want** the broadcast to say nothing about my orders **So that** they stay secret until the reveal, and are never in a message at all

- [ ] **AC-4.1** Given a game and the test cable adapter When a seat saves, submits, edits, is reissued, the host reveals once, and the host (or another request) reveals the same phase again Then exactly one message is on the game's `results` stream, it is the one the reveal sent, and no message was on it before the reveal, after a save, a submit, a reissue, a failed reveal (the stand-in is made to raise) or a repeated reveal
- [ ] **AC-4.2** Given that message decoded from the adapter's raw store (not Turbo's parsed helper) Then it parses to exactly one element, `turbo-stream`, whose only attribute is `action="refresh"` (so no `request-id`, even when the reveal request carries an `X-Turbo-Request-Id` header, which a request spec sends), with no child, no text and no `template`; and its text is identical, byte for byte, between a game with no orders and a game in which every seat ordered different things
- [ ] **AC-4.3** Given the stream's name and the response set Then the name is `results:<public id>`, appears (as a verified name, AC-3.4) in no response but the four pages of AC-3.4 for a seat or the host, and is not the name of the status stream, the game's general stream, or any stream spec 024 proves
- [ ] **AC-4.4** Given a broadcast to `results:<A's public id>` Then nothing appears on any other stream, and a change of submitted state or a broadcast of the status sends nothing to the `results` stream (the streams do not share a name)
- [ ] **AC-4.5** Given the cable adapter raises When the host reveals Then the reveal is stored (the phase has its adjudication and revealed time, the next phase exists), the response is the same redirect as without the failure, and one warning line naming only the exception class is logged
- [ ] **AC-4.6** Given the app code Then, by a scan spec in the style of spec 024 AC-2.7 (which this feature amends): `broadcast_results_refresh` is named only in `app/models/game.rb` (its definition) and `app/models/phase.rb` (inside `reveal!`, once); `Turbo::StreamsChannel`, `broadcasts…` and every other `broadcast…` method are named in `app/` and `lib/` only in `app/models/game.rb`, inside the two broadcast methods; and the scan's patterns catch `broadcasts_to`, `broadcasts_refreshes` and `broadcast_refresh_to` outside those places (a control example)

### Story 5: The open phase stays secret, and a stranger sees nothing

**As a** player **I want** my open-phase orders to stay mine **So that** adding results never opens a way to read them

- [ ] **AC-5.1** Given the route table (spec 022 FR-9) When the app's routes are listed Then both new routes are classified in `spec/support/secrecy_routes.rb`, with each entry now saying whether it can show the orders of a **revealed** phase (a new key, `revealed:`, with `:all` for the two results routes, the seat page and the host page and `:none` for every other); a spec lists exactly those four routes, and fails on an entry that lacks the key. The `shows:` lists of spec 022, 023 and 026 are unchanged
- [ ] **AC-5.2** Given the invariance sweep of spec 022 AC-7.2 (every readable route, every kind of viewer but England) in its present world, before any reveal When England's orders change Then every page, including both new routes (swept for the open phase, where they are the stranger page), answers identically, as before; and both new routes answer 404 to every viewer, except that the host with France's seat cookie is sent to the step-in confirmation (303) on the seat results route, as on every seat route (spec 026 D5)
- [ ] **AC-5.3** Given the same sweep in a second world, after the first phase has been revealed and with the second phase open, where the sweep's context carries two numbers (the revealed one and the open one) and every numbered route is requested for both: orders and picker, the open number is 200 and the revealed number a 303 to its results page; both results routes, the revealed number 200 and the open number 404; the reveal confirmation and the step-in confirmation, for the open number; the stepped-in screen and picker, for **both** numbers (the open number 200 for the host stepped into France and 404 for every other viewer, the revealed number the 409 page for the host stepped into France and 404 for every other viewer). Every viewer is rebuilt for the second phase (the stepped-in host steps in for phase 2). The first-phase control orders leave the swept picker provinces occupied in phase 2 (the sweep's controls assert France's `par` picker and the stepped-in France screen are 200, so a swept page can never silently become a stranger page). When England's orders for the **open** phase change, and when its submitted state changes Then every page is identical for every viewer but England, with exactly the two differences the existing example already allows when the submitted state changes: England's row of the status list (spec 024 AC-3.5), and the reveal confirmation page for the open number, which lists who has not submitted, for the four host viewers. Everything else stays strictly equal, and the pages that show the revealed phase's results are identical in both
- [ ] **AC-5.4** Given the second world Then each viewer's answers are as D4 says: the seat page of another seat, the host page, and both results pages show the revealed phase's results (200) to the viewers entitled to them, while a stranger gets the stranger response on every results route and on both pages, with status controls for each viewer on the routes the first world already controls (the sweep's existing 200 and 404 expectations, extended to the second world); the host with no seat and the host with France's seat cookie are as spec 026 D5 says for the seat routes
- [ ] **AC-5.5** Given the second world, with England's second-phase orders chosen to differ in their words and their JSON from every first-phase order of every power Then the results of the revealed phase contain, as a positive control, England's order from the first phase, and no page of any viewer but England contains an order of the **open** phase (England's second-phase orders, by their words and their JSON)
- [ ] **AC-5.6** Given the app code Then the results code (the helper, the partials, the presenter) names neither `SavedOrder`, `saved_orders` nor `orders_for`; spec 022 AC-7.8's scan and the saved-orders boundary spec pass unchanged
- [ ] **AC-5.7** Given the existing example that says no page shows an order or an outcome after the reveal (spec 022 AC-7.9) Then it is rewritten to this feature: strangers and the pages with no right to results show none; the pages with the right show them; none is deleted without an equivalent

### Story 6: Past phases stay readable

**As a** player **I want** to look back **So that** I can check what happened two phases ago

- [ ] **AC-6.1** Given two or more revealed phases When a seat opens its seat page Then under the latest results there is an "Earlier results" list with one link per earlier phase, newest first, each titled by the phase ("Spring 1901 · Movement") and leading to that phase's results page, which is 200; the host page has the same list linking to the host results pages
- [ ] **AC-6.2** Given exactly one revealed phase Then there is no "Earlier results" list
- [ ] **AC-6.3** Given the host page and Issue #104 Then, as a review check on the diff and not a test, this feature's edits to `hosts/show.html.erb` are: the dislodged banner loop moves into the results partial, one `render` of that partial, and one `render` of `results/_live`; and no line inside `[data-history]` and none of `step_ins/_history` changes. The coordinator opens a follow-up Issue to fold "Earlier results" into the "Revealed phases" list once #104 and this feature have both merged (this pull request only leaves this note)

### Story 7: Honest about practice results

**As a** table **I want** to be told when the results are a stand-in **So that** nobody moves a piece by a made-up outcome

- [ ] **AC-7.1** Given `RulesEngine.stand_in?` is true Then every results view (the seat page's section, the host page's section, and both results pages) has the practice note of D6 above its groups, as a muted paragraph; and given the method is stubbed to return false Then none shows it
- [ ] **AC-7.2** Given a stored adjudication Then the presenter and every view read only its `to_h` (the documented hash form): a spec feeds a hash shaped exactly as the gem's 0.2.0 `to_h` (an outcome with every field, a `format` of 1) through the stand-in's loader and a second hand-written hash with a different key order, and both draw the same page. No view, helper or presenter names a stand-in class or a gem constant, and none reads a gem object: the dislodged banners are drawn from the presenter's hash-form data (the existing boundary spec passes)
- [ ] **AC-7.3** Given the note Then no results view contains, case-insensitively, any of "official", "licensed", "authorized", "confirmed", "verified", "final" or "real results", and the practice note is present whenever `stand_in?` is true (a words scan of the rendered pages, in the style of `spec/styles/words_spec.rb`)
- [ ] **AC-7.4** Given a stored result whose `paradox` is true (a hand-built hash) Then each results view has one `warning` banner with the paradox sentence of D6 above its groups, and given `paradox` false it has none

### Story 8: The design system

- [ ] **AC-8.1** Given `/styleguide` Then it has a Results section with a result group in the player version, one in the reading version with a dislodged row, one row for each tag, and the practice note, rendered through the real partials with made-up data, and `design-system.md`'s rows for `.result-row`, `.outcome-tag` and `.result-group` read "#25 (built)", naming the partials
- [ ] **AC-8.2** Given the tags Then they are drawn through one partial, `results/_outcome_tag`, and no other file writes `outcome-tag` (a scan)
- [ ] **AC-8.3** Given the stylesheets Then the total stays within spec 020's cap of 32,768 bytes and `components.css` within its cap, with sizes before and after in the plan; the contrast spec covers every new colour pair, on the existing tokens (no new token unless the plan says why)
- [ ] **AC-8.4** Given a spec run with `SCREENSHOTS=<dir>` set Then it writes 360-pixel screenshots of the seat page and the host page after a reveal (a mix of outcomes, a dislodged row, the practice note) and of a results page, for the pull request; without the variable it writes nothing

### Story 9: Earlier specs are brought up to date

- [ ] **AC-9.1** Given spec 022 When this pull request merges Then it has a changelog row (1.5.0): AC-6.3 and FR-6 are read as "a `GET` for a revealed phase's orders is a 303 to its results page, a `PUT` keeps the 409"; AC-7.9 is replaced by this feature's Story 5; the FR-9 table's rows for the seat page and the host page add the results of a revealed phase and the two new routes are added; and the "half stale" limit of spec 024 is closed. Spec 023 gets the same for AC-2.13 (`GET` of a step URL of a revealed phase), and spec 024's Known limits and AC-2.7 are amended as AC-4.6 says; spec 024's AC-4.1 ("exactly one `turbo-cable-stream-source`" on the seat page and the host page) is read as "exactly one **status** source, and one results source", and its AC-4.5 ("the signed name appears only on the seat page and the host page") as "the signed status name appears only there; the signed results name also appears on the order screen and the picker"
- [ ] **AC-9.2** Given the repository Then every existing spec that asserted the 409 page for a `GET` of a revealed phase's orders or picker step, or that no page shows an outcome after a reveal, is rewritten to this feature, none deleted without an equivalent. They are at least `spec/requests/phase_pages_spec.rb`, `spec/requests/order_screen_spec.rb`, `spec/requests/order_pickers_spec.rb`, `spec/requests/order_secrecy_spec.rb`, `spec/models/status_broadcast_scan_spec.rb`, `spec/requests/seat_status_pages_spec.rb` (its AC-4.1 example), `spec/requests/reveal_post_spec.rb` (its dislodged fixture, which sets the position and no flag), `spec/requests/host_spec.rb` (the host page is no longer without `no-store`), `spec/requests/orders_spec.rb` (the `GET` 409 example), `spec/system/phase_screens_spec.rb` (the refusal banner on a revealed orders URL), `spec/requests/order_secrecy_spec.rb` (its signed-name example, which tests by the substring `signed-stream-name` and is rewritten to verified names, AC-3.4) and `spec/requests/styleguide_spec.rb`, found by running the suite

## Functional Requirements

### FR-1: The results presenter

`PhaseResults.new(phase)` is a plain Ruby object in `app/models/`. It reads the revealed phase's `adjudication.to_h` and `position.units` only, and returns the groups of D8: for each power, rows with the order's hash, the unit's type (nil when no unit of the order's power stood there), the province, the result string, the dislodged flag and whether the order was submitted, and the stored `paradox` flag. It is not built for an open phase (it raises). It names no gem class (hash form only, as the boundary spec requires), and no saved order.

**Must:** group by power in the gem's order; put dislodged rows first within a group; offer the reading order (groups with a dislodged unit first); raise on a result the tag table lacks.
**Must not:** read anything but the stored adjudication and the phase's starting position; compute an outcome.

### FR-2: The tag, the row, the group

`results/_outcome_tag` (locals: the symbol or `:dislodged`) writes `<span class="outcome-tag outcome-tag--<symbol>">Succeeded</span>` and is the only writer of the class. `results/_row` writes the `.result-row` of D8. `results/_group` writes a `.result-group`, with `--reading` when told. `results/_section` writes a viewer-kind section: a heading, the skip link (seat page only), the paradox banner (`data-paradox`) and the dislodged-unit banners (`data-dislodged`, host, latest phase only) when due, the practice note when due, the groups, and the "Earlier results" list. A helper, `OutcomeHelper`, holds the word table.

### FR-3: The pages

- The seat page gets the section for the latest revealed phase directly under its phase header, above the order count, the "Enter orders" link and "Who has submitted", so the first thing a phone shows after a reveal is the results; the section's heading is an `h2` ("Results: Spring 1901 · Movement").
- The host page gets the reading section above the "Host" section, in its own `<section>`, heading `h2`, with the dislodged banners at its top (moved from the page head, drawn as before).
- `results/_live` is rendered by the four pages of D2.
- `ResultsController` (seat) and `HostResultsController` (host) are the two new pages; both strict about the number, both stranger on anything but a revealed phase.

### FR-4: The broadcast

`Game#broadcast_results_refresh` calls `Turbo::StreamsChannel.broadcast_refresh_to(:results, public_id, request_id: nil)` inside a rescue that logs the exception's class and returns (D3). It is called from `Phase#reveal!` and nowhere else.

### FR-5: Secrecy classification

As Story 5: the two routes are classified, the route table gains `revealed:`, `/cable`'s reason names both streams, and the sweep runs in two worlds.

## Non-Functional Requirements

### Performance
- A reveal sends one small message. A seat page, host page or results page loads the one phase's adjudication (a JSON column) and its starting position, and renders at most a few dozen rows; no query per row.

### Accessibility and layout
- Tags are words. Dislodged uses the `danger` tone and the word. Headings run in order: `h1`, then `h2` for the results section, `h3` for each power's group. At 360 pixels nothing scrolls sideways; rows wrap; tap targets (the history links, the back links) are at least 44 by 44 pixels. Text is at least 16 pixels in the player version (the mono tag may use `--text-sm`, as the status state does), larger in the reading version.

### Security
- See D1, D2, D4 and Stories 4 and 5. No new write route, so no CSRF concern. A results name is a capability that carries nothing.

### Reliability
- A failed broadcast never fails a reveal (AC-4.5). A phone that missed the message is correct on reload (AC-3.5).

### Stylesheet budget
- 5,749 bytes remain under the 32,768-byte total today (27,019 used). The plan records the size before and after; if the components do not fit, the maintainer is asked before any cap changes.

## Error Scenarios

| Scenario | Expected Behavior |
|----------|-------------------|
| A seat or the host asks for results of the open phase, a later phase, an unknown number or `01`, `1.5`, `abc` | The stranger response (404), identical for everyone (AC-1.8, AC-2.3) |
| A stranger or a junk cookie asks for either results page | The stranger response, and the junk cookie is deleted as for any page (spec 021) |
| The host reveals and a phone is on the order screen | The phone refreshes to that phase's results page via the 303 (AC-3.2) |
| A phone sends `PUT` orders for a revealed phase | 409 and the sentence of spec 022 AC-6.1, unchanged |
| A phone was offline for the reveal | Stale until it reloads or is touched; a reload is right (Known limits) |
| The broadcast fails | The reveal stands, one warning with the class, the host is redirected as usual |
| A stored result has a symbol the tag table lacks | Cannot be stored (the loader refuses an unknown symbol); a spec holds the table's keys equal to the nine documented symbols, so a gem release that adds one fails the suite first |
| The host reveals twice | One reveal, one message (spec 022 AC-4.8); the second gets "That phase was already revealed." |

## Known limits

- **Missed messages.** Action Cable does not replay. A phone that sleeps through the reveal, or is in the middle of a navigation when the refresh arrives (Turbo drops it), shows the old page until a tap or reload. Issue #105 tracks a catch-up message on subscribe; a refresh makes that repair trivial (the same one-line refresh), but it is a custom channel and is not added here.
- **The stand-in's results are fake** until #29 and the page says so (D6). The practice note is the only difference #29 makes to the display.
- **The seat page is long after a reveal.** The results section comes first on the seat page and stays there until the next reveal, above the "Enter orders" link. A seat that wants to enter the next phase's orders follows the "Skip to orders" link at the top of the section (AC-1.9). Putting results on their own page only is the alternative, rejected because the table is looking for them.
- **A stepped-in host screen does not switch.** A step-in ends at the reveal (spec 026), and the page it showed does not subscribe (D2).
- **A copied results stream name never expires** and tells its holder when a reveal happened (D2).
- **Dislodged units** are never produced by the stand-in; the tests use hand-built results until #29.

## Open Questions

None unresolved. The maintainer is asked about D1, D3, D4, D5, D6 and D7 (Gate A).

## Out of Scope (Future Considerations)

- **#27** the host's position editor: the host reads the reading view and settles the position there.
- **#29** the 0.2.0 upgrade: removes `RulesEngine.stand_in?`, the practice note and the stand-in, and changes nothing else here.
- A map of the results, retreats and builds, a catch-up message on reconnect (#105), a phase clock and notifications.

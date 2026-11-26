# Feature 024: Show live submission status

**Status:** Approved
**Version:** 1.2.0
**Created:** 2026-11-26
**Last Updated:** 2026-11-26
**Issue:** #24, #105
**Branch:** `web/24-live-status`; amended on `web/105-status-catch-up`

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 1.2.0 | 2026-11-26 | Amended for Issue #105 (catch up the live status when a phone wakes or reconnects). Approved at Gate A by the coordinator under the maintainer's delegation, with the results catch-up included.<br>• New D10 and FR-7: a subscriber is caught up as it subscribes. Two small channel classes, `SeatStatusChannel` and `ResultsChannel`, subclass `Turbo::StreamsChannel` and are named by the pages through turbo-rails' own `channel:` option, so no JavaScript is added. `SeatStatusChannel` transmits the current seven-row snapshot, built by the same `Game` method as the broadcast; `ResultsChannel` transmits a refresh when the phase the page was drawn for has been revealed since.<br>• D1 and D4 no longer say "no custom channel class": the maintainer's ruling at Gate A of 1.0.0 deferred it to #105, and D10 states the rule every channel line carries (valid signed name only, same partial and same seven inputs, same allowlist and byte-equality proof, one more allowed sender in the scan).<br>• The payload proof (AC-3.1, AC-3.2, AC-3.4) is extended to every transmission, the scan spec (AC-2.7) names the two channel files as the only other senders, and AC-4.1 and AC-4.3 are rewritten for the new channel. New Story 9 (AC-9.1 to AC-9.8).<br>• The results stream name inside the signed name gains the phase number (`results:<public id>:<number>`); the stream itself, `results:<public id>`, and every broadcast on it are unchanged, so spec 025's payload proof holds. Spec 025 gets its own changelog row (1.1.0).<br>• The Known limits "missed messages" is closed for the two streams; what stays open is listed there. Every other criterion holds unchanged. |
| 1.1.0 | 2026-11-26 | Amended by spec 025 (reveal results to every phone, #25).<br>• AC-2.7 allows a second broadcast method, `broadcast_results_refresh` in `app/models/game.rb`, called once from `Phase#reveal!`, on a stream of its own (`results:<public id>`); the status stream and its payload proof (AC-3.1) are unchanged, and nothing else broadcasts.<br>• AC-4.1 is read as "each of the seat page and the host page holds exactly one **status** source and one results source"; the order screen and the picker hold the results source only.<br>• AC-4.5 is read as "the signed **status** name appears only on the seat page and the host page; the signed **results** name also appears on the seat's own order screen and picker", and the sweep verifies each name rather than matching the text.<br>• The Known limit "after a reveal the seat page is half stale" is closed: a reveal refreshes every subscribed page, and the seat page then shows the new phase and the results (spec 025 D1). Every other criterion holds unchanged. |
| 1.0.2 | 2026-11-26 | Found by the implementation review, wording only: AC-8.2 also lists spec 022's AC-7.4 (the seat page shows its own count and the seven-power status list), which the amendment already does; origins are lowercased as well as stripped of a trailing slash (D5), because a browser writes the Origin header in lowercase |
| 1.0.1 | 2026-11-26 | Found while planning, within what Gate A approved: whitespace between a row's two elements is allowed by the payload allowlist (AC-3.1) |
| 1.0.0 | 2026-11-26 | Approved at Gate A. The maintainer ruled that the stale list after a phone wakes stays a stated known limit with no custom channel, and opened Issue #105 for it (Known limits). Origins are named in `docs/architecture.md` by a root pull request, not by this one |
| 0.2.1 | 2026-11-26 | Changed after the second Fable review (wording only, no design change): the scan of AC-2.7 is stated as patterns that can pass; AC-3.4 checks text nodes and whole words, on JSON-decoded payloads; `.seat-status` shares `.list`'s rules without the `list` class (FR-1); the cache-control change is stated (D9); the specs that change are listed in full (AC-8.3); AC-4.4 is stated as an observable; D5 names the explicit `require`; D3 names what the writers must report |
| 0.2.0 | 2026-11-26 | Changed after the first Fable review: the stream is a dedicated status stream named by the game's public id, not the game's general stream (D1, D4); the name is a permanent capability, said plainly (D4); the live region is an `aria-live` list updated by morph, so only a changed row is announced (D6); the payload allowlist is exact (AC-3.1); the helper takes the statuses, so `/styleguide` can show samples (D6, AC-8.1); a failed cable call is rescued, a broken render is not (D7); origin parsing is a small module (D5, AC-7); named the existing specs that change (AC-8.3); heading levels, reconnect and half-stale-after-reveal limits stated |
| 0.1.0 | 2026-11-26 | First draft |

## Problem Statement

The host reveals a phase when the table is ready, and "ready" means every power has submitted. Today the only way to know is to ask around the table, or to open the reveal confirmation page, which lists who is missing but does not update. Players have the same question ("are we waiting on me?"). Spec 022 made submitting an editable state (a seat that changes its orders goes back to "not submitted"), so the answer changes and a static page goes stale.

This feature shows, on every seat page and on the host's controls, seven rows: each power and whether it has submitted. The rows update on every phone without a reload. They show nothing else. In particular they show nothing that could hint at an order.

## Goals

- A seat page and the host page show a `.seat-status` list of the seven powers, each with "Submitted" or "Not submitted".
- When a seat's submitted state changes, every open seat page and host page for that game updates within about a second, through Turbo Streams over Solid Cable.
- A seat that edits its orders after submitting goes back to "Not submitted" on everyone's screen.
- A page that is loaded (or reloaded) without a live connection is correct.
- A broadcast carries the seven submitted states and nothing else, and the proof of that is a test, not a claim.
- Only a viewer who can already see the status page gets the signed stream name.
- A phone that wakes from sleep or reconnects is shown the current state as it resubscribes, without waiting for the next change (D10, Issue #105), and gets exactly the state-only content a broadcast carries.

## Non-Goals

- Showing results to every phone at the reveal (#25). The status does follow the new phase after a reveal (D3), because a stale "Submitted" would be wrong; the results are #25's.
- Stepping into a seat (#26), the absent-seat state (#48: until then a power nobody holds reads "Not submitted"), a phase clock, notifications, sound or vibration.
- Any JavaScript beyond `turbo-rails`: no Stimulus controller, no new gem. (Version 1.2.0 adds two small server-side channel classes, D10; still no JavaScript.)
- A count of how many have submitted. The rows are the information.
- Replaying the messages a phone missed while offline. The catch-up sends the current state, never the history (D10).

## Users and Context

**Primary users:** The host, watching the table's phones to know when to reveal. Players, glancing at who is still ordering.
**Secondary users:** A screen-reader user (the list is a live region). A player on a poor connection, whose page must still be right when it loads.
**User mental model:** "A list of the seven powers. A power turns to Submitted when it submits and back when it changes its mind."

## Decisions

Gate A settled D1, D2, D4, D5 and D7, and ruled that the reconnect snapshot is Issue #105 (Known limits; now D10).

**D1. A dedicated stream per game.** The seat page and the host page each contain `turbo_stream_from :seat_status, @game.public_id, channel: SeatStatusChannel`, which renders `<turbo-cable-stream-source channel="SeatStatusChannel">` with a signed name for the stream `seat_status:<public id>`. The server side is `SeatStatusChannel`, a small subclass of `Turbo::StreamsChannel` (D10; version 1.0.0 used the unmodified parent). It rejects a subscription whose signed name does not verify, and also one that verifies to anything but this game stream. The stream is not the game's general stream (`turbo_stream_from @game`), so a later broadcast to the game itself can never reach a status subscriber, and the name carries the public id (which every seat already holds) and not the game's sequential database id. Broadcasting is `Turbo::StreamsChannel.broadcast_stream_to(:seat_status, public_id, content: seat_status_message)`, where `Game#seat_status_message` is the one place the message is built (the `update`/`morph` stream tag around the rendered rows, made by `turbo_stream_action_tag`), so a broadcast and a catch-up (D10) cannot differ; the broadcast is in one method (D3). The stream is per game and not per phase, so one subscription lasts through every phase of a sitting.

**D2. The payload is a snapshot of the seven states, and nothing else.** Every broadcast is one `<turbo-stream action="update" method="morph" target="seat-status">` whose template is the seven rows rendered by one partial, `shared/_seat_status`. The partial receives seven `Phase::Status` values (`power`, `submitted`), built by `Phase#seat_statuses` from the `submissions` table and the list of powers. That is the only input. It receives no seat, no order, no count, no phase number and no time, and the markup carries no game id. A snapshot (not "England changed") is chosen so that a phone that missed a message is corrected by the next one, and so that the payload is a function of seven booleans.

**D3. When a broadcast is sent.** Only when a game's set of submitted seats actually changes, from three places, each after its transaction has committed (the rows themselves are written only by `Seat#save_orders!` and `Seat#clear_orders!`, and removed with a deleted seat or phase; `Phase#reveal!` writes none but opens a phase with none):

| Writer | Broadcasts when |
|---|---|
| `Seat#save_orders!` | The seat's submitted state after the call differs from before it. A save that changes orders of an unsubmitted seat sends nothing. An edit of a submitted seat that is not re-submitted in the same call sends one (now "Not submitted"). An edit plus a re-submit in one call ends where it began and sends nothing |
| `Game#reissue_seat!` | The reissued seat had submitted (its submission is deleted, spec 022 D9) |
| `Phase#reveal!` | It revealed (the new phase has no submissions, so all seven read "Not submitted") |

`Seat#save_orders!` takes the seat's submitted state inside the phase lock before it changes anything, and `Game#reissue_seat!` learns whether a submission was removed (`clear_orders!` is changed to report it). So the number and timing of broadcasts is a function of submitted-state flips only. It is not a function of how many orders a seat saved, which, or when. Broadcasting is called explicitly from these three places (a scan spec enforces this, AC-2.7), not from `after_commit` callbacks on `Submission`, because an edit-and-resubmit would otherwise be a destroy plus a create and so two messages, which tells a watcher "this seat changed something".

**D4. Who may subscribe.**
- The signed stream name appears in exactly two responses: the seat page (`GET /games/:public_id`, which requires a seat) and the host page (`GET /games/:public_id/host`, which requires the host). A stranger gets the stranger response, which has no stream element. The name appears in no other page, header, JSON body or flash.
- `/cable` itself does no sign-in: the connection is anonymous, as Turbo expects. The signed name is the capability, and it names one thing: the status stream of one game. Nothing else is broadcast to that stream (a scan spec enforces that only `broadcast_seat_status` sends to this stream and only `SeatStatusChannel` transmits its message, AC-2.7, AC-9.7), so a later feature that broadcasts to the game cannot reach status subscribers by accident, and #25 uses a stream of its own.
- **If the name leaks** (a screenshot of page source, a browser extension), the holder can subscribe and receives exactly what the page shows: the seven rows. D2 makes that the whole content of every message. The name is not a cookie or a token and no controller accepts it.
- **Limit: the name never expires.** Turbo's verifier is a plain signed message with no expiry, so a name copied once works for as long as the app's secret key base stays the same, and a subscription lasts as long as the page that opened it. A seat that the host reissues keeps receiving the status on its old page, or on a name it saved. From 1.2.0 a saved name also catches up: a saved status name gets the current seven rows on every subscribe, and a saved results name for a revealed phase gets one refresh on every subscribe (bounded by reconnects, and with the content it always had: that a reveal happened). What it receives is the seven rows, which any seat sees; no order or count of its own is in it. This is stated here, not closed.
- **Not added:** a custom connection or channel that checks the seat cookie. The two cookies are named per game, a connection cannot know which game a subscription means. The decision stays: the signed name is the capability, a dedicated stream, and the payload proof of D2. Version 1.0.0 also added no channel class of any kind and ruled the catch-up out (Issue #105); version 1.2.0 adds the two classes of D10, which check nothing but the signed name and carry the same secrecy rule.

**D5. Allowed origins.** `config/environments/production.rb` sets `config.action_cable.allowed_request_origins` from the environment variable **`TRUCEBEARER_CABLE_ORIGINS`** (named for the project, like `TRUCEBEARER_PASSPHRASE`): origins such as `https://play.example.org`, separated by commas or spaces. A trailing slash is dropped from each, each is lowercased (a browser writes the `Origin` header in lowercase), and blank entries are ignored. The parsing is one small module, `CableOrigins.parse(value)` in `lib/cable_origins.rb`, required by `production.rb` with an explicit `require_relative` (the autoloader is not set up when that file runs; the module has no dependency), so it can be tested without booting production (the way `Passphrase` is a plain model).
- **Unset or blank:** the list is empty, which is Rails' own default. Action Cable then accepts a connection only when the browser's `Origin` equals the request's own scheme and host (`allow_same_origin_as_host` stays on). A deployment where players reach the app at the same address the app sees works with no setting. Because the app assumes SSL behind its proxy, "same origin" means `https://<the Host header>`; a plain-http deployment must list its origin. A deployment where players do not reach the app at the address the app sees (a proxy that rewrites the `Host` header, or a second public name) has its sockets refused: Action Cable logs "Request origin not allowed", nothing is shown to the player, pages are still correct on every load, and only the live updates are missing. The README says so. No boot-time warning is logged, because an unset variable is correct for a plain single-host deployment.
- **Set:** each listed origin is accepted in addition to the same-origin case. Matching is exact (strings, never patterns).
- The variable is not secret: it goes under `env.clear` in `config/deploy.yml`, with a placeholder origin that matches the template's commented proxy host, `https://app.example.com` (an origin that is never used is harmless), and the README has a paragraph beside the passphrase's.
- Forgery protection (`disable_request_forgery_protection`) is never set to true in any environment file.

**D6. The markup, and the live region.** Pages render the list through one helper, `seat_status(statuses, id: "seat-status")` (in a new `SeatStatusHelper`), which writes `<ul id="seat-status" class="seat-status" aria-live="polite">` around `render "shared/seat_status", statuses: statuses`. The pages pass `phase.seat_statuses`; `/styleguide` passes made-up statuses and an `id:` of its own so that three samples are three ids. The broadcast `update`s the inside of the real `<ul>` (the target is always `seat-status`) with `method="morph"`, so the live region persists (replacing it would not be announced) and only a row whose text changed is touched, which is what a screen reader announces. The list keeps its list role (no `role="status"`, which would replace it and would make the whole list re-read). A short visible heading "Who has submitted" sits before the list, outside the live region: an `<h2>` on the seat page and an `<h3>` on the host page, where the list is inside the section headed "Host". Each row is `<li class="seat-status__row" data-power="england">`: the power's badge (`power_badge`, so colour is never alone), then `<span class="seat-status__state">Submitted</span>` or "Not submitted". The state is words, not colour or an icon alone.

**D7. A failed cable call never fails a save, and a broken render is never hidden.** The partial is rendered first, outside any rescue, so a broken template raises in every environment and a spec catches it. The call to `Turbo::StreamsChannel` after it is rescued (`StandardError`): it writes one warning line with the exception's class only (no payload, no message) and carries on. Solid Cable's broadcast hands the message to a writer thread and reports its own failures, so this should be rare; the rescue guards against an adapter that raises (a stopped adapter, a different adapter later) turning a stored save into a 500. The next flip sends the whole snapshot, so a failure repairs itself.

**D8. The host page.** The host's controls show the same `seat_status` list directly above the "Reveal orders" button, inside the host section. The host reads the same seven rows as a seat, from the same helper.

**D9. Phones that go back or reconnect.** Both pages send `turbo-cache-control: no-cache` always (the host page sends it today only while it shows the one-time host link, and the seat page not at all), so Turbo never restores them from its snapshot cache on a Back visit and always fetches them fresh. A page whose socket dropped and reconnected is caught up as it resubscribes (D10).

**D10. A subscriber is caught up as it subscribes (new in 1.2.0, Issue #105).** Action Cable does not replay, but the browser's client resubscribes by itself when a phone wakes or its connection returns, and the server's `subscribed` runs again each time. So the catch-up is server code only: two small classes in `app/channels/`, each a subclass of `Turbo::StreamsChannel`, named by the pages through turbo-rails' own `channel:` option on `turbo_stream_from` (documented in the gem's helper). No JavaScript, no gem, no Stimulus controller.

*`SeatStatusChannel`.* `subscribed` takes the name that `Turbo::StreamsChannel` verifies (`verified_stream_name_from_params`) and accepts it only when it is exactly `seat_status:<public id>` of an existing game; otherwise it rejects and transmits nothing. It then streams from that name and calls `transmit` once with `game.seat_status_message`, the message that every broadcast of D2 carries (rendered through `shared/_seat_status` from `Phase#seat_statuses`, the seven `(power, submitted)` values and nothing else). The channel renders nothing itself: it looks up the game by public id (and, in `ResultsChannel`, the phase by number and its `revealed_at`) and reads nothing else, and it names no submission and no order.

*`ResultsChannel`* (the results stream of spec 025). The pages' signed results name becomes `results:<public id>:<number>`, where the number is the phase the page was drawn for (a number the page already shows in its header). `subscribed` accepts exactly that shape for an existing game and phase, streams from `results:<public id>` (the stream, and every broadcast on it, are unchanged: spec 025's payload proof holds), and, only if that phase has been revealed by now, transmits once the same content-free refresh a reveal broadcasts (`Game#results_refresh_message`: one `turbo-stream` element, the one attribute `action="refresh"`). A phone that slept through a reveal is therefore refreshed when it reconnects; a phone whose page is current gets nothing. After a refresh the page carries the new phase's number in its name, so Turbo's element (which watches `signed-stream-name`) resubscribes to it, and a refresh cannot loop: a page that the server draws and that subscribes carries an unrevealed phase's number (AC-9.5), and a request for a revealed phase's orders is a 303 to a results page, which does not subscribe (spec 025 D2). Two cases that this does not cover, both harmless: the order screen and the picker do not set `turbo-cache-control`, so Back, or a cached preview, can restore a snapshot carrying a revealed phase's name, which gets one refresh and so one 303 to the results page; and a phone that reconnects at the very moment of a reveal may get both the catch-up and the broadcast, two refreshes that do the same.

*The rule that every line of channel code carries* (the maintainer's, restated):
1. **Only a valid signed name gets anything.** An unsigned name, a name signed with another key, no name, a verified name for a different stream, or a name for a game or phase that does not exist is rejected, and nothing is transmitted (AC-9.2). The parse is strict: the verified value must be a `String` (the verifier's serializer is JSON, so it can return anything that was signed) and match `\Aseat_status:(<id>)\z` or `\Aresults:(<id>):([1-9]\d*)\z`, anchored at both ends, where `<id>` is the shape `Game.start!` generates for `public_id` (12 letters and digits, `SecureRandom.alphanumeric(12)`).
2. **Same partial, same seven inputs.** The status snapshot comes from `Game#seat_status_message`, which the broadcast also uses, so there is one builder and no second rendering path (AC-9.3).
3. **Same proof.** Every transmission is added to the payloads that AC-3.1 (exact allowlist), AC-3.2 (byte equality across games with different orders) and AC-3.4 (no order word, no digit) examine, and is compared byte for byte with the broadcast for the same state (AC-9.3).
4. **One more allowed sender, and no more.** The scan spec of AC-2.7 allows the two channel files, and only them, to name `transmit`, and lets them name `Turbo::StreamsChannel` only as their parent (AC-9.7).

*What a subscriber now sees.* Every subscribe, including the first one after a page load, transmits the current seven rows. On a first connect they normally equal the rows the page was drawn with, so morph changes nothing and a screen reader announces nothing (the live region announces changed text only, D6); if a flip fell between the page's render and its subscribe, the morph corrects the row, which is the repair wanted. `transmit` writes straight to the one connection and not through the adapter, so catch-ups are not stored in Solid Cable and there is nothing for AC-3.6 to add. The snapshot is read when `subscribed` runs, and on Solid Cable the stream starts listening asynchronously, so a flip that commits between that read and the stream going live can be missed by this subscriber: the catch-up's own, millisecond-wide window, which the next flip or a reload repairs (Known limits).

*Failure.* The snapshot is rendered with no rescue, like the broadcast's (D7): a broken template is a bug that a spec catches in every environment, and in production Action Cable logs it, the subscription is never confirmed (it stays registered and may still receive broadcasts, which carry the same state-only content), and the page stays correct as loaded.

*Why not the alternatives.* A Stimulus controller that reloads the list when the page becomes visible or the socket reconnects is new JavaScript, which the ruling for #105 allows only when unavoidable, and it is avoidable. A periodic `<meta http-equiv="refresh">` needs no code but reloads whole pages, loses the open picker and the screen-reader position, and still lags by its interval. Leaving results out would leave a phone that slept through the reveal on the open phase's screen with a stale status list and an "Enter orders" link that answers 409; the reveal is the one moment a table is all looking at its phones, so it is included.

## User Stories and Acceptance Criteria

### Story 1: The host sees who has submitted

**As a** host **I want** the reveal button's neighbourhood to show who has submitted **So that** I know when to reveal

- [ ] **AC-1.1** Given the host page When the host opens it Then `#seat-status.seat-status` is in the host section above the "Reveal orders" button, holds seven `li.seat-status__row[data-power]` in the gem's power order, each with that power's `.power-badge` and a `.seat-status__state` reading "Not submitted" or "Submitted", and a heading "Who has submitted" (an `h3`, inside the host section) is before it
- [ ] **AC-1.2** Given England has submitted and France has not When the host page loads without any live connection Then England's row says "Submitted" and France's says "Not submitted" (page-load correctness, FR-5)
- [ ] **AC-1.3** Given a second session on the host page When England submits Then within 5 seconds England's row there says "Submitted", with no reload (system spec, AC-6.1)

### Story 2: A player sees the table's state

**As a** player **I want** to see which powers have submitted **So that** I know whether the table waits on me

- [ ] **AC-2.1** Given a seat page When it loads Then it shows the same `#seat-status` list, through the same helper and partial, under an `h2` "Who has submitted", and the old single line "Submitted"/"Not submitted" is removed from the page (the own seat's state is its row; the submit bar on the orders screen keeps its words)
- [ ] **AC-2.2** Given England's seat page open When France submits Then England's page shows France as "Submitted" without a reload
- [ ] **AC-2.3** Given England has submitted When England edits an order so that its submission is cleared (spec 022 FR-3) Then one broadcast goes out and every open page, England's own and the host's included, shows England as "Not submitted"
- [ ] **AC-2.4** Given the host reissues England's seat while England has submitted Then one broadcast goes out, and the list reads England "Not submitted"
- [ ] **AC-2.5** Given the host reveals When the next phase opens Then one broadcast goes out and all seven rows read "Not submitted"; a reveal that finds the phase already revealed (`:already`) sends none
- [ ] **AC-2.6** Given Seat#save_orders! runs and raises (stale seat, revealed phase, refused order) Then nothing is broadcast
- [ ] **AC-2.7** Given the app code Then, enforced by a scan spec in the style of `seat_write_scan_spec`: (a) `Submission` rows are created or destroyed (`Submission.create/new/delete/destroy`, or `submissions.` followed by `create`, `find_or_create_by`, `destroy` or `delete`) only in `app/models/seat.rb`, the `has_many :submissions, dependent: :destroy` associations being the only other mention; (b) `broadcast_seat_status` is named only in `app/models/game.rb` (its definition and `reissue_seat!`), `app/models/seat.rb` (`save_orders!`) and `app/models/phase.rb` (`reveal!`); and (c) `Turbo::StreamsChannel`, `broadcasts` and any other `broadcast_…` method are named in `app/` and `lib/` only in `app/models/game.rb`, inside `broadcast_seat_status` (and, from spec 025 and version 1.2.0, `broadcast_results_refresh` and the two message builders `seat_status_message` and `results_refresh_message`), apart from the two channel files that AC-9.7 allows

### Story 3: Nothing about an order is ever in a broadcast

**As a** player **I want** the table to learn only that I submitted **So that** my orders stay secret until the reveal

- [ ] **AC-3.1** Given a game and the test adapter When England saves, submits and edits orders, and France does the same (the model spec drives `Seat#save_orders!`) Then every raw payload on the game's stream (read from `ActionCable.server.pubsub.broadcasts(name)`, not from Turbo's parsed helper, and JSON-decoded: Action Cable stores the string JSON-encoded) is parsed and matches this allowlist exactly: one `<turbo-stream>` with `action="update"`, `method="morph"` and `target="seat-status"`, whose one `<template>` holds exactly seven `li.seat-status__row` in power order; each `li` has the attributes `class` and `data-power` (a power's id) and exactly two children, a `span.power-badge.power-badge--<id>` whose text is the power's name and a `span.seat-status__state` whose text is "Submitted" or "Not submitted". No other element, attribute, id, number or text appears (whitespace between elements aside: a space separates the badge from the state, so a row reads "England Not submitted" to a reader that ignores markup). From 1.2.0 the payloads examined are the broadcasts and every message that `SeatStatusChannel` transmits on subscribing (AC-9.3)
- [ ] **AC-3.2** Given two games with the same sequence of submitted-state flips but different orders (different units ordered, different order kinds and provinces, 0 and 3 orders at the moment of submitting, a mid-sequence edit that changes one order and one that changes three) When the same flips are driven through `save_orders!` in each Then the list of captured payloads is byte-for-byte equal between the games, in count and in order (the stream names differ and are not compared); from 1.2.0 a subscription made after each flip, in each game, is added to the list and its transmission is equal across the games too, and equal to the broadcast for that state
- [ ] **AC-3.3** Given a seat that saves orders and does not submit, or edits a submitted seat's orders and re-submits in the same call Then no broadcast is captured, in either game (so the message count cannot hint at editing)
- [ ] **AC-3.4** Given the decoded payloads of AC-3.1 and AC-3.2 Then the text nodes of the template contain, as whole words and case-insensitively, no province abbreviation or name, no order word ("Move", "Hold", "Support", "Convoy", "by convoy") and none of "ordered", "units"; and the whole decoded payload contains no digit, no phase title and no game public id. (The markup's own attribute values and class names are not text nodes and are covered by the allowlist of AC-3.1.) The same rules are applied to every transmission of AC-9.3.
- [ ] **AC-3.5** Given the secrecy sweep of spec 022 AC-7.2 (every readable route, every kind of viewer but England) When England's orders change and the submitted state stays the same Then every page is identical, the two pages with a status list included. When England's submitted state changes, the only difference allowed anywhere is inside `#seat-status`, on the seat page and the host page, and the only change inside it is England's row text (AC-5.3)
- [ ] **AC-3.6** Given Solid Cable stores each message for a day (`message_retention` in `config/cable.yml`) Then the stored payload is the same state-only payload, and the README's note on this feature says so (documentation, not a test: the allowlist test covers the content)
- [ ] **AC-3.7** Given the app code Then neither `Phase#seat_statuses`, the partial, the helper, the broadcast, `Game#seat_status_message` nor either channel file names `SavedOrder`, `saved_orders` or `orders_for` (the scan reads the whole bodies of the four `Game` methods of AC-2.7 and the two channel files, not only the two `broadcast_…` bodies) (the existing saved-orders boundary scan stays in force and passes unchanged)

### Story 4: Only those who may see the status get the stream

**As the** table **I want** a stranger not to be able to listen in **So that** a game is private to its players

- [ ] **AC-4.1** Given a seat page and the host page Then each contains exactly one status `turbo-cable-stream-source`, with `channel="SeatStatusChannel"`, whose `signed-stream-name` verifies (`Turbo.signed_stream_verifier.verified`) to `seat_status:<that game's public id>`, never to the game's general stream, and the page of game B holds game B's name, never game A's
- [ ] **AC-4.2** Given a stranger, a junk cookie, a valid cookie of another game, and a seat cookie on the host page When each asks for the page Then the response is the stranger response and its body contains no `turbo-cable-stream-source` (the stranger bodies of spec 021 AC-5.5 stay identical for a game that exists and one that does not)
- [ ] **AC-4.3** Given a channel spec When a client subscribes to `SeatStatusChannel` with a signed name for the game Then it is confirmed and streams from that game's status stream; with an unsigned name, a name signed with another key, or no name Then the subscription is rejected, and so is a verified name for any other stream (AC-9.2). (A client can still subscribe to `Turbo::StreamsChannel` itself with the status name, as before, and would hear the broadcasts without the catch-up; that is the same capability, so it gives nothing new.)
- [ ] **AC-4.4** Given a signed name for game A When a client subscribes with it and game B's status changes, or a broadcast goes to game A itself (not its status stream) Then nothing is broadcast to `seat_status:<A's public id>` (read from the test adapter's list for that name)
- [ ] **AC-4.5** Given the response set Then the signed name appears in no response but those two pages: a scan of the sweep's responses for every viewer finds it only in `GET /games/:public_id` and `GET /games/:public_id/host`, in the bodies of viewers who have the right to them
- [ ] **AC-4.6** Given the route table (spec 022 FR-9) Then `MOUNT /cable` is classified in `APP` (not in the framework list) as `shows: :none`, with the reason "state-only stream; the signed name is only in pages behind a seat or the host cookie", and the framework entry that said #24 must classify it is removed. The two pages' `why` text in the table now mentions the status list. No new HTTP route is added

### Story 5: A page is correct without a live connection

**As a** player on a poor connection **I want** a freshly loaded page to be right **So that** I never depend on the socket

- [ ] **AC-5.1** Given a request spec (no browser, no cable) When England has submitted and the page is fetched Then the list is correct. With England not submitted Then it is
- [ ] **AC-5.2** Given the seat page and the host page Then both carry `<meta name="turbo-cache-control" content="no-cache">` (D9), and a system spec shows that leaving to the orders screen, another seat submitting, and pressing Back, shows the current state
- [ ] **AC-5.3** Given a seat page and a host page rendered for the same game state Then the `#seat-status` element is byte-identical between them, and between a viewer and the broadcast's template once wrapped (one partial: the broadcast's template equals the page's list contents)
- [ ] **AC-5.4** Given a broadcast fails (the adapter raises) When England submits Then the submission is stored, the response is the same as without the failure, and one warning line naming only the exception class is logged; and a partial that raises still raises (D7)

### Story 6: It works at a table, on a phone

- [ ] **AC-6.1** Given two Capybara sessions at 360 pixels wide, the host's and England's When England submits through the order screen Then the host's page shows England as "Submitted" without a reload, within 5 seconds; and when England then changes an order, the host's page shows "Not submitted" again. Measured on that page: nothing scrolls sideways and no control is under 44 by 44 pixels
- [ ] **AC-6.2** Given a spec run with `SCREENSHOTS=<dir>` set Then it writes 360-pixel screenshots of the host page and the seat page with some rows submitted, for the pull request. Without the variable it writes nothing

### Story 7: The origins setting

- [ ] **AC-7.1** Given `CableOrigins.parse` When it is given nil, blank, `"https://a.example"`, `"https://a.example/, https://b.example"` and `" ,, "` Then it returns `[]`, `[]`, `["https://a.example"]`, `["https://a.example", "https://b.example"]` and `[]`; and `production.rb` has the one live line `config.action_cable.allowed_request_origins = CableOrigins.parse(ENV[...])` naming `TRUCEBEARER_CABLE_ORIGINS`, checked the way `production_config_spec` checks its lines
- [ ] **AC-7.2** Given Action Cable's own origin check, run on a connection with each of those lists Then an `Origin` equal to the request's own scheme and host is allowed in every case, a listed origin is allowed, and an unlisted foreign origin is refused. `disable_request_forgery_protection` is not set to true in any file under `config/environments/` or `config/initializers/`
- [ ] **AC-7.3** Given `config/deploy.yml` and the README Then the variable is under `env.clear` and the README says what it is, an example, and what happens when it is unset (D5)

### Story 8: The design system and earlier specs

- [ ] **AC-8.1** Given `/styleguide` Then it has a Seat status section showing the list with all submitted, none submitted and a mix, rendered through the real helper with made-up statuses and an id of its own for each sample (the page is static, the helper takes the statuses), and `design-system.md`'s row for `.seat-status` reads "#24 (built)", naming the helper and the partial
- [ ] **AC-8.2** Given spec 022 When this pull request merges Then it has a changelog row (1.4.0): AC-1.5, AC-7.4 and the FR-9 table's rows for the seat page ("own state and own count only") and the host page are read as "the seat page shows the seven powers and their submitted state, and the seat's own count and orders link"; AC-7.5 is read as "the host can read, before the reveal, which powers have submitted (the same set as the names of those that have not)"; AC-7.2's sanctioned difference is extended as AC-3.5 here says; the route table classifies `/cable`. Every other criterion holds unchanged
- [ ] **AC-8.3** Given the repository Then every existing spec that asserted the seat page's single "Submitted"/"Not submitted" line, or that the seat page does not name another power, is rewritten to this feature's page, none deleted without an equivalent. They are at least `spec/requests/phase_pages_spec.rb` (the seat page's "France" and "Not submitted" examples), `spec/requests/player_spec.rb` (the seat page does not name France), `spec/requests/styleguide_spec.rb` (its exact list of components gains `seat-status`), `spec/docs/design_system_spec.rb` (a "#24 (built)" example, as for #21 to #23), and the "answers the same whether England has submitted or not" example in `spec/requests/order_secrecy_spec.rb`, which excepts the seat and host pages for the viewers who get them, with the difference confined to `#seat-status`

### Story 9: A phone that wakes or reconnects is caught up (new in 1.2.0, Issue #105)

**As a** player whose phone slept **I want** the list, and the reveal, to be current as soon as the phone is back **So that** I never act on an old screen

- [ ] **AC-9.1** Given a channel spec, a game in which England has submitted and France has not When a client subscribes to `SeatStatusChannel` with the game's signed status name Then the subscription is confirmed and streams from `seat_status:<public id>`, and exactly one message is transmitted: a `turbo-stream` whose seven rows read, England "Submitted", France "Not submitted" and the others "Not submitted"; with nobody submitted all seven read "Not submitted". Subscribing again (a resubscribe) transmits exactly one more
- [ ] **AC-9.2** Given `SeatStatusChannel` and `ResultsChannel` When a client subscribes with an unsigned name, a name signed with another key, no name, a name that verifies to a different stream (the game's general stream; the status name given to `ResultsChannel` and the results name given to `SeatStatusChannel`; `results:<public id>` without a number), a status name for a game that does not exist, or a results name for a phase that does not exist, or a name of the wrong shape (`seat_status:<id>:x`, `results:<id>:1x`, `results:<id>:1:2`, `results:<id>:01`, a name ending in a newline, a verified value that is not a string) Then the subscription is rejected and nothing is transmitted, for each
- [ ] **AC-9.3** Given the payload specs of Story 3 and a subscription made after each flip Then (a) every transmission is, byte for byte, the message a broadcast sends for the same game state (compared with the JSON-decoded broadcast from the adapter's list, since the adapter stores it JSON-encoded; the subscriptions are made in `type: :channel` specs that also drive the model flips), and is equal to the transmission of the other game in AC-3.2; (b) each passes the exact allowlist of AC-3.1 and the word and digit rules of AC-3.4; (c) one subscribe transmits one message, and a subscribe never causes a broadcast on any stream, so the stored cable messages (AC-3.6) are unchanged by catch-ups; (d) `Game#seat_status_message` is the only method that builds a status message, used by the broadcast and by the channel (the scan of AC-9.7)
- [ ] **AC-9.4** Given `ResultsChannel`, a game with phase 1 open and a signed results name for phase 1 When a client subscribes Then it is confirmed, streams from `results:<public id>`, and transmits nothing; after the host reveals phase 1, a subscription with the same name transmits exactly one message, equal byte for byte to the JSON-decoded one the reveal broadcast on that stream (one `turbo-stream` element whose only attribute is `action="refresh"`, no `request-id`), and a subscription with the name for phase 2 (open) transmits nothing. A reveal still broadcasts exactly the one message of spec 025 AC-4.1 and AC-4.2 on `results:<public id>`
- [ ] **AC-9.5** Given the seat page, the host page, the order screen and the picker step (spec 025 D2) Then the results `turbo-cable-stream-source` on each has `channel="ResultsChannel"` and a signed name that verifies to `results:<that game's public id>:<the number of the phase the page was drawn for>`, which is the game's current, unrevealed phase; the status source on the seat page and the host page is as AC-4.1; and no page of any viewer carries a results name for a revealed phase, so a catch-up refresh is never answered by a page that asks for another
- [ ] **AC-9.6** Given two Capybara sessions at 360 pixels, England's page open and its socket closed through the Action Cable consumer (the system spec does it from the test alone, with `execute_script` running `import("@hotwired/turbo-rails")`, then `cable.getConsumer()` and `consumer.disconnect()` and later `consumer.connect()`, and waits for `turbo-cable-stream-source[connected]` to leave and return; no hook is added to `app/javascript`) When France submits and the socket is then reconnected Then England's page shows France as "Submitted" without any reload and within 5 seconds; and, with the socket closed again, when the host reveals the phase and the socket reconnects Then England's page refreshes to the next phase's page and shows the results (spec 025). A reconnect with nothing missed leaves the list unchanged
- [ ] **AC-9.7** Given the app code Then, by the scan spec of AC-2.7, which this version amends: `transmit` is named in `app/` and `lib/` only in `app/channels/seat_status_channel.rb` and `app/channels/results_channel.rb`, once in each, and in no other file; `Turbo::StreamsChannel` is named in those two files only as the parent class; neither file names `render`, `broadcast…`, `Submission`, `submissions`, `SavedOrder`, `saved_orders` or `orders_for` (AC-3.7 covers them); `seat_status_message` and `results_refresh_message` are defined only in `app/models/game.rb`, and `shared/seat_status` is rendered only by `SeatStatusHelper#seat_status` (the pages and `/styleguide`, D6) and by `Game#seat_status_message` (every message, broadcast or catch-up)
- [ ] **AC-9.8** Given the repository Then spec 025 has its changelog row (1.1.0: its signed results name carries the phase number, `ResultsChannel` is named by the four pages, its Known limit on missed messages is closed for subscribed pages), the README's note on live updates says a woken phone is caught up and what is still not (Known limits), no HTTP route is added and the route table is unchanged (`/cable` stays classified as AC-4.6 says), and every existing spec that asserts the plain `Turbo::StreamsChannel` subscription, the `results:<public id>` name on a page, or the stubs of `broadcast_update_to` is rewritten to this version, none deleted without an equivalent. They are at least `spec/channels/seat_status_subscription_spec.rb`, `spec/requests/results_stream_spec.rb`, the stream-name helpers in `spec/requests/order_secrecy_spec.rb`, `spec/requests/seat_status_pages_spec.rb`, `spec/models/seat_status_broadcast_spec.rb`, `spec/models/status_payload_secrecy_spec.rb`, `spec/models/status_broadcast_scan_spec.rb`, and the two specs that stub `broadcast_refresh_to`, `spec/models/results_broadcast_spec.rb` and `spec/requests/reveal_post_spec.rb`, which stub `broadcast_stream_to` instead

## Functional Requirements

### FR-1: The status list

`Phase#seat_statuses` returns seven `Phase::Status = Data.define(:power, :submitted)` in `RulesEngine.powers` order, from the game's seats and the phase's submissions (two queries, as `Phase#pending` does). `shared/_seat_status` renders the seven `li` rows (D6); `SeatStatusHelper#seat_status(statuses, id:)` wraps them in the `ul` live region. `.seat-status` is plain CSS in `components.css` using tokens: it shares `.list`'s rules by selector grouping (the element does not carry the `list` class, so the existing specs that count `.host-section ul.list > li` stay at seven), shows the badge with the state to its right, and adds only what it needs. Rows are not controls, so no 44-pixel minimum applies to them.

**Must:** carry the power's name beside its colour; be words; fit 360 pixels. **Must not:** carry any value from an order, a count or a time.

### FR-2: The broadcast

`Game#broadcast_seat_status` builds `seat_status_message` (version 1.2.0: `Game#seat_status_message` renders `shared/seat_status` for `current_phase.seat_statuses` with `ApplicationController.render` and wraps it with `Turbo::StreamsChannel.turbo_stream_action_tag(:update, target: "seat-status", template: html, method: :morph)`, the helper `broadcast_update_to` used, so the bytes are unchanged; D1, D2), then calls `Turbo::StreamsChannel.broadcast_stream_to(:seat_status, public_id, content: message)`. `Game#broadcast_results_refresh` likewise sends `results_refresh_message` (`Turbo::StreamsChannel.turbo_stream_refresh_tag(request_id: nil)`, spec 025 D1; the bytes `broadcast_refresh_to` sent) with `broadcast_stream_to(:results, public_id, content: message)` and the same rescue and warning; the builders are shared with the catch-up (D10), so a broadcast and a catch-up cannot differ. The render is outside the rescue; the call to the channel is inside it: it rescues `StandardError`, logs the class once, and returns (D7). `broadcast_seat_status` is called from the three writers of D3 and from nowhere else; `broadcast_results_refresh` only from `Phase#reveal!` (spec 025 D3; AC-2.7).

### FR-3: Subscribing

`turbo_stream_from :seat_status, @game.public_id, channel: SeatStatusChannel` is in the seat page and the host page only (D4). No connection and no JavaScript is added; the `turbo-rails` import already in `application.js` opens the socket and resubscribes after a drop. The channel is FR-7's.

### FR-4: Origins

As D5: one line of `production.rb`, the `env.clear` entry in `deploy.yml`, a README paragraph.

### FR-5: Page-load correctness

The lists are rendered on the server from `submissions` on every full page load (no cache, D9). No JavaScript is needed for a correct page.

### FR-6: Secrecy classification

As AC-4.6 and AC-3.5: `/cable` is classified, the sweep's submitted-state pair has the one sanctioned difference, and the saved-orders boundary and write scans stay in force and pass unchanged.

### FR-7: The catch-up

`SeatStatusChannel` and `ResultsChannel` (D10), in `app/channels/`, each a subclass of `Turbo::StreamsChannel` that overrides `subscribed` only: read `verified_stream_name_from_params`; reject unless it has exactly the expected shape and names an existing game (and, for results, phase); `stream_from` the game's stream; transmit the one message (`Game#seat_status_message`, or `Game#results_refresh_message` when the numbered phase is revealed). `Game#seat_status_message` renders `shared/_seat_status` for `current_phase.seat_statuses` and wraps it in the `update`/`morph` stream tag of D2, and the broadcast calls it too. `Game#results_refresh_message` is the refresh of spec 025 D1. The pages' two stream sources are named in `phases/_status` and `results/_live` (the latter now takes the phase).

**Must:** reject before transmitting; transmit only the output of the two `Game` builders; add no JavaScript, gem or route. **Must not:** query or name submissions, orders or counts in the channels; transmit anything on a rejected or a quiet subscription.

## Non-Functional Requirements

### Performance
- A broadcast renders seven rows and writes one Solid Cable row. A page load adds two queries (seats and submissions). Each subscribe (D10) costs one seven-row render and its two queries and writes no cable row, so seven phones waking together are seven renders. Solid Cable polls at 0.1 seconds; delivery is about that, so "within a second".

### Accessibility and layout
- The list is a polite live region (`aria-live="polite"`) updated by morph, so a changed row's text is what is announced; the list role is kept. The heading is an `h2` on the seat page and an `h3` on the host page, keeping the heading order of both. At 360 pixels nothing scrolls sideways.

### Security
- See D4 and Story 3 and 4. CSRF is not involved (no new write route). Forgery protection of Action Cable stays on (D5).

### Stylesheet budget
- `components.css` and the total stay within the caps spec 020 set (32,768 bytes total). The plan records the sizes before and after; if the rows do not fit, the maintainer is asked before a cap changes.

## Error Scenarios

| Scenario | Expected Behavior |
|----------|-------------------|
| The socket cannot connect (origin refused, offline) | Page is correct as loaded; no live updates; the player sees nothing wrong |
| A broadcast fails | The save stands; one warning line with the exception's class; the next flip sends a full snapshot |
| A phone was offline when a flip happened | It is caught up with the current list when its socket resubscribes (D10); until then the list is stale and a reload is right |
| A phone was offline for a reveal | The same resubscribe sends it a refresh, and the page is redrawn for the new phase (D10, spec 025) |
| A subscription with a name that is valid but for another stream, a game or a phase that does not exist | Rejected; nothing is transmitted (AC-9.2) |
| A signed name that does not verify | The subscription is rejected by the channel (the parent's verifier returns nil) |
| A broadcast to the game itself, not its status stream | Reaches no status subscriber (D1) |
| The host reveals | One broadcast: all seven "Not submitted" for the new phase |
| Two flips at the same moment | Each broadcast is a full snapshot read after commit, so the last one rendered is right; a stale one is replaced by the next flip |

## Known limits

- **Missed messages (closed for subscribed pages in 1.2.0, D10).** Action Cable does not replay, but a page whose socket resubscribes is sent the current state. What stays open: a phone that sleeps or reconnects is caught up only when its page carries a stream source (the pages of spec 025 D2 and the status pages; the reveal confirmation, the results pages and the stepped-in screens do not, and are correct as loaded); a refresh that Turbo drops because the phone is mid-navigation when it arrives (spec 025 Known limits) is not repaired, since the socket never dropped; and the catch-up sends the state now, not what happened in between.
- **After a reveal** the seat page is refreshed by spec 025 and, for a phone that missed that refresh, by the catch-up of D10 (this limit of 1.0.0 is closed).
- **A reissued seat's open page** keeps its subscription until closed, and a copied stream name never expires (D4).
- **Unseated powers** read "Not submitted" until #48.
- **Two writers racing** can render a snapshot just before another commit and broadcast it just after, showing a stale list until the next flip. The window is a few milliseconds and the cost is a stale row that the next flip or a reload repairs; no lock is added. A catch-up snapshot read at subscribe time races a flip in the same way, with the same repair; because the stream may go live after the read, a flip inside that millisecond window can be missed by that subscriber until the next flip or a reload.

## Open Questions

None unresolved. The maintainer is asked about D1, D2, D4, D5 and D7, (settled at Gate A).

For 1.2.0, Gate A is asked about D10: the channel subclass (the approach), the secrecy proof (AC-9.3, AC-9.7) and including the results stream with the phase number inside the signed name (AC-9.4, AC-9.5).

## Out of Scope (Future Considerations)

- **#25** reveals results to every phone on a stream of its own, not this one (D4), and must keep the rule that nothing broadcast before the reveal carries an order.
- **#26** step-in: a host stepped into a seat sees that seat's screens; the status list is unchanged by it.
- **#48** adds the absent-seat state (`.seat-status__absent`) to the same partial.
- A phase clock and notifications. (The catch-up on reconnect was these specs' Issue #105 and is D10.)

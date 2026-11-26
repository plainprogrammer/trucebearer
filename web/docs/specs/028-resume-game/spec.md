# Feature 028: Resume a game in a later session

**Status:** Approved
**Version:** 1.0.3
**Created:** 2026-11-26
**Last Updated:** 2026-11-26
**Issue:** #28
**Branch:** `web/28-resume-game`

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 1.0.3 | 2026-11-26 | Approved at Gate A (the maintainer's delegate): D1 to D6, the amendments to specs 021 and 022. The optional game name is follow-up Issue #121 (D4); the host page's dead "Your own seat" link for a browser with no seat is Issue #120, a known limit this feature does not fix. |
| 1.0.2 | 2026-11-26 | Minor fixes from the second Fable review (approved with minor fixes): AC-3.4 normalizes the CSRF token as the sweep does, AC-3.6 fixes the cookie order with a raw header, a stale AC number, "the queries", and AC-8.5 takes the next free minor. |
| 1.0.1 | 2026-11-26 | Changed after the first Fable review (verdict: changes required).<br>• **B1:** the layout's CSRF tags make Rails set its session cookie on `GET /`, so "no `Set-Cookie`" is gone: the page sets and deletes no `host_`, `seat_` or `step_in_` cookie (D7, AC-1.6, AC-2.3).<br>• **B2:** spec 022's route table (FR-9) calls `GET /` "no game data"; D10 and AC-8.6 amend it.<br>• **B3:** the host on a fresh phone reaches the host's own seat by reissuing it, which clears that seat's saved orders; D5, the Problem Statement, AC-7.3 and the Gate A question say so, and the dead "Your own seat" link on the host page is a follow-up Issue.<br>• Minors: an identity proof for the home page (AC-3.4), backdated games and distinct powers (AC-3.2), a seat cookie re-signed under another name (AC-3.3), the first 40 ids in request order and at most three queries (D2, AC-3.6), `PUBLIC_ID_SHAPE` reused, `own_seat_target` reused for hosts, the "Your games" heading defined, AC-3.12 and AC-4.4 reworded, `web/README.md`, `StepInsHelper#table_zone`, how a session end is simulated, and the shared stylesheet budget. |
| 1.0.0 | 2026-11-26 | First draft |

## Problem Statement

The group plays one game over several sessions. The cookies that bring a phone back already last for good (spec 021 FR-2: signed, permanent, `httponly`), but nothing uses them as a way in. Next week a player opens the app's home page, which offers only "Create a game" and "Join a game", and the game is nowhere in sight unless the player kept the page's address. A host who opens the host link on a new phone lands on the host page; the host's own seat can be had again only by reissuing it, which nothing on the page says. A player whose cookie is gone has no hint that the host can fix it.

## Goals

- Opening the home page with a valid seat or host cookie lists the games that browser belongs to, as `.game-card`s, and each card links to that game's current phase (D1, D3).
- The page finds a browser's games from the cookies it sends, reads only cookies that verify, and shows nothing about a game to a browser that holds no valid cookie for it (D2).
- A browser that holds the host's own seat is led to its seat page; a host browser with no seat is led to the host page, and its way back to the host's own seat is the reissue of that seat (D3, D5). The host link does the same (D5).
- A player who lost the cookie is told what to do, in a line that is the same for everyone and so reveals no game (D6).
- The home page is classified in the secrecy table, and the sweep and a new request spec prove that different cookie sets see only their own games (D8).
- The `.game-card` is built to the design system, listed in `/styleguide` and in the catalog (D9).
- A system spec covers leaving and resuming in real browsers.

## Non-Goals

- Accounts, "claim your seat" and any list of games tied to a person (1.0, Issues #42 to #44). This feature works from cookies only.
- A game name chosen by the host (D4). The card shows when the game started; a name is a follow-up.
- Redirecting the home page to a game (D1).
- A new way to recover a lost cookie. Reissue by the host (specs 021, 022, 026 D10) is the way; this feature makes it discoverable.
- Recovering a lost host link. The host token cannot be rotated in this release (`web/README.md`, "Playtest access").
- Deleting stale cookies from the home page (D2). `stranger!` still removes a failing cookie when its own game's page is asked for.
- Any change to `adjudicator/`, `.github/`, root files, the host page, the seat page or the channels. Issues #112 (folding the host page's lists) and #105 (catch-up) work there at the same time.

## Users and Context

**Primary users:** A player or the host, a week after the last session, opening the app on the phone that played before, at about 360 pixels wide.
**Secondary users:** The host, helping a player who lost a seat; the host on a second phone, with only the host link.
**Usage context:** Away from the table, on the way to it, or sitting down at it. One tap should be enough to be back in the game.
**User mental model:** "I open the app, I see my game, I tap it."

## Decisions

**D1. The home page lists the browser's games and never redirects.** The Issue says opening the app "lands on" the game's current phase. Two designs were weighed.

- **(a) List the games, never redirect. Chosen.** Cards sit under the intro line, above "Create a game" and "Join a game". A phone in one game lands on the game with one tap. It costs one tap and nothing else.
- **(b) Redirect when the browser holds exactly one game.** Saves that tap. Rejected: a player in one game could then never see "Create a game" or "Join a game" (the home page is the only page that links them), and the stranger page's "Back to the home page" link would bounce a player into a game they did not ask for. A redirect on a page that every other page links to is a trap, and the count of games is something the player can't see before it happens. Also, the page would answer 302 for one cookie set and 200 for another, which the secrecy sweep would have to treat as a special case.

The coordinator or maintainer may choose (b) at Gate A; it changes D1 and Story 1 only. The test written first holds for both: it follows the card's link (a) or the redirect (b) to the game's current phase.

**D2. Finding a browser's games: read the cookie names, verify each, show only what verifies.** Cookies are named `host_<public_id>` and `seat_<public_id>` (spec 021 FR-2). The home page:

1. Takes the names from the request's cookies that match `\A(?:host|seat)_(…)\z`, where the id part must match `GameAccess::PUBLIC_ID_SHAPE` (read from the existing constant, not copied), and no others (`step_in_<id>` is not a game cookie; any other name is ignored). It examines the first 40 distinct ids in the order the request sent them and ignores the rest, because a browser holds two cookies per game and keeps only a few hundred cookies per site.
2. Loads the games with those public ids, and their seats, which `host_seat` and `seat_for` read: two queries, and nothing else.
3. Verifies each game with the same two checks every game page uses: `host?(game)` (the signed cookie verifies and its token matches the host digest) and `seat_of(game)` (the signed cookie verifies and its token matches a seat's digest). A cookie that is unsigned, tampered, from another game, stale, reissued or for a game that does not exist fails and the game is dropped before anything is read about it.
4. Only for the games that verified, loads the open phase of each in one query and draws a card. The page therefore makes at most three queries, whatever the number of cookies.

The new code is a controller concern (`ResumableGames`) included by `HomeController` only; `GameAccess` is not edited. The home page deletes no cookie and sets none, so a stale cookie stays until its own game's page is asked for (`stranger!` then removes it). That keeps `GET /` free of side effects, and the stale cookie costs one row in a list the page does not draw.

Nothing a card shows comes from a game that failed verification: no count, no id, no phase, no text. The page for a browser with no valid cookie is the page it is today, plus the line of D6.

**D3. What a card shows and where it links.** An `h2` "Your games" opens the list; it is drawn only when there is at least one card, after the intro paragraph (so the intro stays the first paragraph of `main`) and before the buttons. Then one card for each verified game, newest game first. The card is one link (a single 44-pixel-or-taller target) holding:

- the title, "Started 26 Nov 2026", the date the game was created in the table's time zone (D4);
- the phase header partial (spec 022 FR-10): the open phase's title in mono capitals and, when the browser holds a seat in that game, that seat's power badge;
- for a game the browser hosts, the words "You host this game".

| What the browser holds for the game | Power shown | Words | Link |
|---|---|---|---|
| a valid seat cookie, no valid host cookie | the seat's power | none | the seat page `/games/<id>` |
| a valid host cookie and a valid cookie for the host's own seat (`Game#host_seat`) | the host's power | "You host this game" | the seat page `/games/<id>`, which holds the host's controls in their own section (spec 026) |
| a valid host cookie and no valid seat cookie | none | "You host this game" | the host page `/games/<id>/host` |
| a valid host cookie and a valid cookie for a seat that is not the host's own | none | "You host this game" | the host page. A host browser is not that other seat (spec 026 D5); the cookie is left alone here and the seat page removes it when it is asked for |
| neither | no card | | |

For a browser that holds the host cookie, the link is `own_seat_target(game)` (the same rule as spec 026 D7 and D5 of this spec); for a seat holder without it, the seat page. Both links lead to the game's current phase: each page draws `Game#current_phase`, so after a reveal the same link leads to the new phase. A card shows no order, no count of orders and no seat's submitted state: those belong to the pages behind it (`shows: :none`, D8).

**D4. The game name: no name this time; the card says when the game started. Recommended, to confirm at Gate A.** The catalog's `.game-card` lists a "game name", and #21 left names out. Options:

- **(a) An optional name at creation.** A new column, a form field, a length rule, escaping and a place to show it. The host picks "Friday group". It touches the create form and the games controller of spec 021, which this Issue leaves alone, and a game with no name still needs a fallback.
- **(b) The date the game started, in the table's time zone. Chosen.** No column, no form, no new input to escape. It tells two games apart when they started on different days, and the card also shows the phase and the power. Two games that started on one day with the same power are told apart by the phase only. This is not a name, so the catalog row is rewritten to say "Start date".
- **(c) The join code.** Rejected: the code lets anyone join while joining is open, so it is not shown outside the host's page.

If (a) is wanted, it is follow-up Issue #121: a nullable `games.name`, a field on the create form and the title falling back to the date.

The date is in `StepInsHelper#table_zone` (the zone `TRUCEBEARER_TIME_ZONE` names, or UTC, as spec 026 D6 does for times), so the variable is read in one place, and is drawn as a `<time datetime=...>` element.

**D5. The host link goes where the host's seat is.** Spec 021 AC-2.1 sends every verified host link to the host page. The Issue says it "lands on the host's seat with host controls". After the host cookie is set, `HostLinksController#show` redirects to `own_seat_target`, which `GameAccess` already defines: the seat page when the browser holds the host's own seat, the host page when it holds no seat of its own. A fresh browser with only the host link lands on the host page, as today. A rejected token is unchanged.

**What a fresh phone can and cannot do.** The server keeps only a digest of the host's seat token, so a host link alone can't give a browser the host's seat. A host on a spare phone reaches the host's own seat again the way any player does: on the host page, "Reissue seat" on the host's own row, then open the new link in that browser (spec 026 AC-7.3 stores the cookie because the seat is the host's own). That clears the host's saved orders for the open phase (spec 022 D9) and ends the seat cookie on the host's first phone, so it is for a lost phone, not a convenience. This is the reading of the Issue's "lands on the host's seat with host controls" that this spec builds, and Gate A confirms it. A fresh phone needs no seat to use the host controls. The host page's "Your own seat" link leads a browser with no seat to the stranger page; the host page is #112's and #105's ground, so Issue #120 records it and this feature does not touch it. The redirect that follows creating a game (`games#create`) stays on the host page, because that page shows the host link once.

**D6. A lost cookie: one static line, on the home page and the stranger page.** "Lost your seat? Ask the host for a new QR code." It is a partial (`shared/_lost_seat`) drawn on the home page for every browser, and on the stranger page, which is the page a player with no cookie meets at a saved game address. It is identical for every viewer and every request, so it tells nobody whether a game exists, whether the phone ever held a seat, or which games there are. The stranger page stays one answer for everyone (spec 021 D4, AC-5.5): the line is part of that one answer. The host's side of the path is the "Reissue seat" row that already exists on the host page; this feature adds no route.

**D7. The home page is never cached.** `GET /` now varies with the cookies, so it sends `Cache-Control: no-store` in every case, with or without cards. The page sets and deletes no `host_`, `seat_` or `step_in_` cookie. (Rails' own session cookie, which the layout's CSRF tags set, is outside this and outside every sameness comparison, as spec 021's 1.2.1 row records.)

**D8. Secrecy.** `GET /` stays `shows: :none, revealed: :none` in `spec/support/secrecy_routes.rb`, with a new `why` text that says it lists the games the cookies verify for and shows no order. No route is added, so the route table needs no new entry. Three checks prove it, working together:

1. The invariance sweep already requests `/` as each of its six viewers; it must keep passing, so the home page is shown not to change with England's orders.
2. A new part of the sweep, built from the same viewers, asserts what each one's home page lists (AC-3.9).
3. A new request spec, `spec/requests/resume_secrecy_spec.rb`, builds several games and several cookie sets, including every kind of bad cookie, and asserts that each browser's page names exactly its own games and contains nothing of the others (Story 3).

**D9. The component, its budget and the docs.** `.game-card` is built to the design system with existing tokens only: `surface` ground, `border` edge, `text` words, the `focus` ring, the base radius and spacing steps, a minimum height of 44 pixels, and the phase header partial inside. The partial is `home/_game_card`; a helper `GameCardsHelper#game_started(game)` formats the date. The stylesheet stands at 29,963 of 32,768 bytes; #112 and #105 draw on the same 2,805 bytes of headroom, so the budget is measured again after `main` is merged in. `.game-card` and its `/styleguide` sample must fit in 2,800 bytes together, and `styleguide.css` (3,716 of 6,144) takes none of it if the sample uses the existing `.sg-` rows. If they do not fit, the plan stops and asks for a ruling; the cap is not raised. The catalog row in `web/docs/design-system.md` becomes built, with the words "Start date, phase header, your power". `/styleguide` gets a `data-component="game-card"` section with the three variants of D3 (seat, host with seat, host only).

**D10. Specs and docs this feature amends.** Spec 021 (1.5.0): AC-2.1 (D5), the home page row of its URL table, and the stranger page line (D6). Spec 022 (the next free minor, 1.8.0 at this writing): FR-9's route table says `GET /` shows "no game data"; the row becomes "No order. Lists the games the request's cookies verify for (spec 028)". `web/README.md` gets a short section, "Coming back to a game". Each amended spec records the change in its own changelog, and `spec/docs/spec_amendments_spec.rb` checks the rows.

## URLs

| Path | Method | Change |
|---|---|---|
| `/` | GET | Lists the games the cookies verify for (D2, D3), then the two buttons, then the line of D6. `Cache-Control: no-store`. No game cookie set or deleted (D7). |
| `/games/<id>/host-link?token=` | GET | The redirect goes to `own_seat_target` (D5). |
| any stranger response | any | The line of D6 is added to the page. |

No route is added.

## User Stories

### Story 1: A phone with a seat is led back to the game (the first test)

**As a** player
**I want** the app to show my game when I open it
**So that** I am one tap from my phase

**Acceptance criteria:**

- [ ] **AC-1.1** *(the first test, a request spec)* Given a game and a browser that holds England's valid seat cookie for it and no other cookie When the browser requests `/` Then the response is 200 with one `.game-card` whose link is `/games/<id>` and whose text holds the open phase's title and "England"; and given a browser with no cookies Then the page has no `.game-card` and no "Your games" heading
- [ ] **AC-1.2** Given that card When the browser follows the link Then the seat page answers 200 and shows the same phase title
- [ ] **AC-1.3** Given the host reveals a phase When the same browser requests `/` again Then the card shows the new open phase's title, and its link is unchanged
- [ ] **AC-1.4** Given a browser in two games When it requests `/` Then it sees two cards, the game created later first, and each card shows its own phase title and power
- [ ] **AC-1.5** Given any browser When it requests `/` Then the page still holds its existing `h1`, its sentence as the first paragraph of `main`, and the "Create a game" and "Join a game" buttons, in that order after the cards (spec 020 AC-6.6 and the home page row of spec 021's URL table hold)
- [ ] **AC-1.6** Given any request for `/` Then the response carries `Cache-Control: no-store` and sets or deletes no `host_`, `seat_` or `step_in_` cookie (read with `cookie_lines`, as `comparable` does), with or without cards

### Story 2: The host's cards

**As a** host
**I want** my game to open on my own seat when I have one, and on the host controls when I don't
**So that** the same game works on my phone and on a spare phone

**Acceptance criteria:**

- [ ] **AC-2.1** Given a browser that holds a valid host cookie and a valid cookie for the host's own seat When it requests `/` Then its card links to `/games/<id>`, shows the host's power badge and the words "You host this game"
- [ ] **AC-2.2** Given a browser that holds only a valid host cookie When it requests `/` Then its card links to `/games/<id>/host`, shows no power badge and shows "You host this game"
- [ ] **AC-2.3** Given a browser that holds a valid host cookie and a valid cookie for another seat (France) When it requests `/` Then its card links to the host page, shows no power badge, and the response deletes no cookie, so France's cookie is still held
- [ ] **AC-2.4** Given a browser that holds only the host's own seat cookie, with the host cookie gone When it requests `/` Then its card links to `/games/<id>` and does not say "You host this game"
- [ ] **AC-2.5** Given a browser that holds a host cookie and a seat cookie of one game and a seat cookie of a second game Then it sees two cards, each following the table of D3 for its own game

### Story 3: A browser sees its own games and nothing else

**As a** player
**I want** nobody to learn about my games from the home page, and I from theirs
**So that** the page is no way to find a game

**Acceptance criteria:**

- [ ] **AC-3.1** Given three games A, B and C and four browsers: one with A's seat, one with B's seat and C's host cookie, one with no cookie, one with every cookie named for A, B and C holding junk When each requests `/` Then the first lists exactly A, the second exactly B and C, the third and fourth none; the list is read from the cards' hrefs. The games have distinct powers for their seats, and each game's `created_at` is set to a different day
- [ ] **AC-3.2** Given each of those pages Then the body contains no other game's public id, join code, phase title (the games' positions are edited so the titles differ), start date (the games are backdated to different days) or power name (the hosts and seats of A, B and C hold different powers, so a power that belongs to a game the viewer has no card for is absent), and contains no join code at all
- [ ] **AC-3.3** Given a cookie `seat_<A>` that holds B's raw `seat_<B>` value (it fails at the signature), or one freshly signed under A's name that carries B's seat token (it fails at the digest check), or `host_<A>` that holds A's seat token, or a seat cookie whose seat was reissued (the old token), or a cookie whose value is not signed, or a tampered signed value, or a cookie named for a game that does not exist When the browser requests `/` Then that cookie lists no game and the request does not fail
- [ ] **AC-3.4** Given `/` requested with junk cookies named for an existing game, with junk named for a game that does not exist (`MISSING_ID`), and with no cookie at all Then the three responses are identical under `comparable`, with the CSRF token normalized as the sweep's `normalized` does: status, body, the three headers and the cookie lines (`GameFlow#junk_session` builds the inputs)
- [ ] **AC-3.5** Given a cookie name that does not have the shape of a public id (`seat_short`, `host_` followed by 13 characters, `seat_<id>x`, `step_in_<id>`, a name with a dot or a slash) Then it is ignored and the request does not fail
- [ ] **AC-3.6** Given a browser that sends cookies for 60 distinct valid-shaped ids, the 41st of them a valid seat cookie Then the request answers 200 and the 41st game is not listed (the first 40 in request order are examined; the test sends a raw `Cookie` header, so the order is its own)
- [ ] **AC-3.7** Given any browser, with 0, 1 or 60 cookies Then the request makes at most three queries for games, seats and phases (counted with `ActiveSupport::Notifications`, the schema and transaction queries excluded)
- [ ] **AC-3.8** Given a reissued seat When the old phone requests `/` Then it lists no game for that seat, and the new phone, after the seat link, lists it
- [ ] **AC-3.9** Given the invariance sweep's six viewers (another seat, the host with a seat, the host with no seat, a stranger, the host wearing France's cookie, the host stepped into France) When each requests `/` Then it lists exactly: France's game for another seat; the game linked to the seat page with "You host this game" for the host with a seat; the game linked to the host page for the host with no seat; nothing for the stranger; the host page card for the host wearing France's cookie; the host page card for the host stepped into France
- [ ] **AC-3.10** Given a viewer's `/` response before and after England saves orders or submits Then the response is the same, apart from the CSRF token (the existing sweep, which already requests `/`, keeps passing)
- [ ] **AC-3.11** Given the route table Then `GET /` is still classified `shows: :none, revealed: :none`, its `why` names the cookies and says it shows no order, and the existing guards on which routes may show orders pass unchanged
- [ ] **AC-3.12** Given the source of the new concern, partial and helper Then a scan finds no read of `saved_orders`, `SavedOrder`, `Submission`, `submitted?`, `ordered_count` or `orders_for` in them, so a card cannot draw an order, a count or a submitted state (`spec/models/saved_order_boundary_spec.rb` and `seat_write_scan_spec.rb` keep passing)

### Story 4: A player whose cookie is gone

**As a** player on a new phone, or with cleared data
**I want** to be told what to do
**So that** I am not left on a page with nothing on it

**Acceptance criteria:**

- [ ] **AC-4.1** Given any browser When it requests `/` Then the page holds the line "Lost your seat? Ask the host for a new QR code." once, below the buttons
- [ ] **AC-4.2** Given a stranger response (no cookie, a junk cookie, a game that does not exist, the seat cookie on a host page) Then the page holds the same line once, and the stranger responses for an existing and a missing game are still identical in status, body, headers and cookies (spec 021 AC-5.5)
- [ ] **AC-4.3** Given a seat the host reissued When the replacement phone opens the new seat link Then it lands on the seat page and its `/` lists the game; the old phone lists no game and, on the game page, gets the stranger page (specs 021 AC-7.5, 7.6 and 026 AC-10.x keep passing)
- [ ] **AC-4.4** Given the home page Then the line names no particular game, power or person and has no link

### Story 5: The host link lands on the host's seat

**As a** host
**I want** my link to open the right screen on whichever phone I use
**So that** I can resume or step in from a spare phone

**Acceptance criteria:**

- [ ] **AC-5.1** Given a game and a fresh browser When it opens the host link Then the host cookie is set and the response redirects to `/games/<id>/host`, with `Referrer-Policy: no-referrer` (spec 021 AC-2.1)
- [ ] **AC-5.2** Given a browser that holds the host's own seat cookie When it opens the host link Then the response redirects to `/games/<id>`, whose page shows the "Host controls" link
- [ ] **AC-5.3** Given a browser that holds a seat cookie for a seat that is not the host's own When it opens the host link Then it redirects to the host page
- [ ] **AC-5.4** Given a wrong token Then the response is the stranger page and nothing changes (spec 021 AC-2.x)

### Story 6: The screens at 360 pixels

**Acceptance criteria:**

- [ ] **AC-6.1** Given the home page with three cards (a seat, the host with a seat, the host only) at 360 pixels Then there is no sideways scroll, every card is at least 44 pixels tall and wide enough to tap, the phase title and the badge do not overlap, and "Create a game" is below the cards
- [ ] **AC-6.2** Given the home page with no cards at 360 pixels Then it is the page of today plus the line of D6, with no sideways scroll
- [ ] **AC-6.3** Given the stranger page at 360 pixels Then the line is shown and nothing scrolls sideways
- [ ] **AC-6.4** With `SCREENSHOTS=<dir>` the spec writes screenshots of the three pages above at 360 pixels; the pull request holds them under `docs/specs/028-resume-game/screens/`

### Story 7: Leaving and resuming, in real browsers

**Acceptance criteria:**

- [ ] **AC-7.1** *(system spec, part one)* Given a host who creates a game and a player who joins it by code When the player's browser session ends (the spec deletes through the driver every cookie that has no expiry, such as the `step_in_` cookie and Rails' session cookie, and keeps the persistent ones, as a real browser does when it restarts) and the player opens `/` Then the player sees one card for the game with the open phase, taps it and is on the seat page "You hold France"
- [ ] **AC-7.2** *(part one, continued)* Given the host reveals a phase while the player is away When the player opens `/` again Then the card shows the new phase's title and the tap leads to the seat page of the new phase
- [ ] **AC-7.3** *(part two)* Given the host link of the game When it is opened in a fresh browser that has never held a cookie for it Then the page shows the host controls ("Reveal orders") and `/` lists the game with "You host this game", linked to the host page; and when that host then reissues the host's own seat and opens the new link in the same browser Then it lands on the seat page with the "Host controls" link, and `/` now links the card to `/games/<id>` (D5)
- [ ] **AC-7.4** *(part three)* Given a player who lost the cookie (a fresh browser) When it opens `/` Then it sees no card and the line of D6; and when the host reissues the seat and the player opens the new link Then the player is on the seat page again and `/` lists the game

### Story 8: The component and the docs

**Acceptance criteria:**

- [ ] **AC-8.1** Given `/styleguide` Then a section `data-component="game-card"` holds three cards (seat, host with seat, host only), and the components list of `spec/requests/styleguide_spec.rb` includes `game-card`
- [ ] **AC-8.2** Given `web/docs/design-system.md` Then the `.game-card` line names #28, says "built", names the partial `home/_game_card` and the helper, and reads "Start date, phase header, your power"
- [ ] **AC-8.3** Given the stylesheets Then `.game-card` uses tokens only (no raw color, `stylesheet_rules_spec` passes), the total stays at or under 32,768 bytes, and `.game-card` plus the sample use at most 2,800 bytes
- [ ] **AC-8.4** Given `web/README.md` Then a section "Coming back to a game" says what the home page lists, that it reads signed cookies only, that a lost cookie is fixed by the host reissuing the seat, and the optional `TRUCEBEARER_TIME_ZONE` for the date
- [ ] **AC-8.5** Given spec 021 Then its changelog has a row for spec 028 (1.5.0, or the next free minor if another amendment comes first) that names AC-2.1, the URL table's home page row and the stranger page, its version line is at least that row's, and `spec_amendments_spec.rb` checks the row
- [ ] **AC-8.6** Given spec 022 Then its changelog has a row for spec 028 (the next free minor) that names FR-9 and `GET /`, FR-9's table row for `/` reads "No order" and says it lists the games the cookies verify for, its version line is at least that row's, and `spec_amendments_spec.rb` checks the row

## Functional Requirements

### FR-1: Finding the games

`ResumableGames#resumable_games` returns the verified games as entries of the game, its open phase, the seat the browser acts as (or nil) and whether the browser hosts it. It follows D2 exactly, uses `host?` and `seat_of`, and never raises on a bad cookie. The link is `own_seat_target(game)` for a browser that holds the host cookie and the seat page for any other seat holder (D3).

### FR-2: The card

One partial, `home/_game_card`, with locals the entry. One link. Its words are the title of D4, the phase header, and "You host this game". The same partial draws the style guide's samples from plain data.

### FR-3: The line

One partial, `shared/_lost_seat`, with no locals.

### FR-4: The host link

`HostLinksController#show` redirects to `own_seat_target(game)` after it stores the host cookie.

## Non-Functional Requirements

### Security

- A cookie is trusted only after the existing signed-cookie and digest checks. The home page adds no new way to learn that a game exists: it lists a game only for a cookie that proves the right to it.
- The static line of D6 is the same for everyone.
- The home page draws no token, no join code and no order.

### Reliability

- A bad cookie never raises. A game that vanishes between the queries is dropped.

### Accessibility and layout

- A card is a real link whose accessible name is its text; the focus ring is the `focus` token; the target is at least 44 pixels tall. The "Your games" heading is an `h2`.

## Error Scenarios

| Situation | Result |
|---|---|
| No valid cookie | The home page as today, and the line of D6 |
| A cookie fails verification | Its game is not listed; nothing is deleted or reported |
| A cookie names a game that no longer exists | Not listed |
| Cookie names of the wrong shape | Ignored |
| A bad host-link token | The stranger page, as today |

## Open Questions

None. Gate A settled D1, D4 and D5.

## Out of Scope (Future Considerations)

- An optional game name (Issue #121, D4).
- A list of games tied to an account, and claiming a seat with one (#42 to #44).
- Removing stale cookies from the home page.
- The host page's "Your own seat" link, dead for a browser with no seat (Issue #120; #112 and #105 are on that page).
- Order counts or submitted states on a card.

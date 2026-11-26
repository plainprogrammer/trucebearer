# Feature 021: Create a game and join it by QR code

**Status:** Draft
**Version:** 1.0.0
**Created:** 2026-11-26
**Last Updated:** 2026-11-26
**Issue:** #21
**Branch:** `web/21-create-game-join-qr`

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 1.0.0 | 2026-11-26 | First draft |

## Problem Statement

A group around a physical board needs seven phones in one game within a minute, on an instance that strangers on the internet can reach. Today the app has no game and no seat. The host has to start a game without an account, every player has to claim one power from a QR code or a short code, and a stranger who finds the URL must be able to do neither of those things to someone else's game. The host also needs to stop new people joining, and to hand a seat to a different phone when a player's phone dies.

## Goals

- The host creates a game by giving the instance passphrase and taking a power. The host gets a secret host link and a host cookie.
- A game in which joining is open shows a QR code and a six-character join code. Seven players can join in under a minute: scan or type, tap a power.
- A player holds a seat by a secret token kept in a signed, permanent cookie. The server keeps only a digest of the token.
- The host can close joining, and can reissue any seat, which cancels that seat's old token at once.
- A stranger learns nothing about which codes, games or seats exist beyond what joining needs, and cannot guess a code, a token or the passphrase at any useful rate.
- The four components `.join-code`, `.qr-card`, `.power-tile` and `.host-section` are built to the catalog in `web/docs/design-system.md` and added to `/styleguide`.
- Every screen is a normal page with its own URL.

## Non-Goals

- Phases, orders, reveal, results, a position, or the position editor (#22 onwards). This feature adds no phase table and stores no position (D1).
- Accounts, passkeys, emailed links, or claiming a guest seat with an account (1.0).
- A name for a game, a display name for a player, or a list of "my games" (#28).
- Reopening a game whose joining was closed, deleting a game, or handing the host role to another phone.
- Updating the host's screen live as players join. The host reloads the page.
- Scanning a QR code from inside the app. Phones use their own camera.
- Any modal, sheet or overlay. A confirmation is a page.
- Any change to `adjudicator/`, `.github/` or the root files.

## Users and Context

**Primary users:** A host who runs a game at a physical table, and up to six other players, each on a phone.
**Secondary users:** A stranger who has found the instance's URL and may poke at it. Whoever runs the instance, who sets the passphrase.
**Usage context:** One host phone is passed or shown around a table. Phones are 360 pixels wide or so. Several phones share one network address at the table.
**User mental model:** "The host opens a game and shows a code. I scan it, tap my country, and I am in. If my phone dies, the host gives me a new code."

## Decisions

These were chosen for this spec, with the alternatives that were left out. Gate A is asked about D1, D3 and D4.

**D1. Two tables, `games` and `seats`, and nothing for phases.** #21 needs only to know that a game exists, who may host it, how to find it while joining is open, and who holds which power. A `phases` table, a position column or a game name would be guesses about #22 and #28. #22 adds a `phases` table that belongs to a game, and treats a game with no phase as "not started". The tables are in FR-9.

**D2. Tokens are random strings, stored only as SHA-256 digests.** A token is 24 bytes (192 bits) from `SecureRandom`, written as URL-safe base64. A fast digest is enough because the token is random and long: there is nothing to guess and no weak secret to stretch. Slow password hashes would only slow every request. Comparison uses `ActiveSupport::SecurityUtils.secure_compare`. Because the server keeps only a digest, it cannot show a token again: a token is shown once, when it is made.

**D3. The passphrase comes from the environment variable `TRUCEBEARER_PASSPHRASE`.** If it is unset or blank, creating a game is refused, the new-game page says so in plain words, and no game can be made. The instance does not fall back to "no passphrase": an instance that was deployed without setting it must not be open to strangers by accident. The alternative (allow creation when unset) was left out for that reason.

**D4. A wrong code and a closed game look the same (no probing).** A stranger who types or crawls codes gets one answer for "no such code" and "that game has closed", with the same status, message and page. A game that is open and a code that is right are the only things that look different, and the join page needs that. The same goes for host links, seat links, game pages and host pages: a wrong token, a missing cookie, a stale cookie and an unknown game all look the same. Taken powers are shown (the Issue needs them), but only to someone who already holds a valid code of an open game. Rate limits (FR-8) are the defense against guessing a code, with a code space far larger than the number of open games (FR-3).

**D5. Games are addressed by a random public identifier.** A game's URLs use a 12-character random identifier, never a counter, so URLs do not reveal how many games exist. The identifier is not a secret and grants nothing: every page that needs a right checks the host or seat cookie.

**D6. A token shown once travels in the flash.** After creating a game, or reissuing a seat, the page that follows shows the new link or QR code once. The token reaches that page in the one-request flash, held in the encrypted session cookie, so the browser can follow a normal redirect and a reload does not create a second game or a second token. Reloading shows no token.

**D7. Confirmation pages for the two actions that cannot be undone.** Closing joining and reissuing a seat each have a page that says what will happen, with a button and a cancel link. #22 builds the shared `.confirm` component, and these two pages adopt it then. Until then they use `.stack`, `.button` and `.button--danger`.

**D8. The QR code is drawn on the server as an inline SVG.** The gem `rqrcode` makes it. No JavaScript, no image request, no third party (FR-4). The reason for the gem is in FR-11.

## User Stories

### Story 1: The host creates a game

**As a** host
**I want** to create a game with the instance passphrase and take my power
**So that** the table has a game to join, and a stranger cannot make games on my instance

**Acceptance criteria:**

- [ ] **AC-1.1** Given an instance with a passphrase set When a person opens `/games/new` Then a page shows a passphrase field and seven power tiles, each an open button naming its power, and no game exists yet
- [ ] **AC-1.2** Given the right passphrase When it is posted with a power Then one game is created, one seat for that power is created for the host, the response redirects to the host page `/games/<id>/host`, and the host cookie and the seat cookie for that game are set
- [ ] **AC-1.3** Given a wrong passphrase When it is posted Then no game and no seat is created, no cookie is set, the page shows the one message "That passphrase isn't right.", and the status is 422
- [ ] **AC-1.4** Given an empty passphrase, a missing passphrase, a passphrase one character short, one character long, and one differing only in case When each is posted Then every one gives exactly the response of AC-1.3, with the same body apart from the page's own form token
- [ ] **AC-1.5** Given the right passphrase and a power that is not one of the seven (missing, blank, or unknown) When it is posted Then no game is created, the page says "Pick one of the seven powers.", and the status is 422
- [ ] **AC-1.6** Given the variable `TRUCEBEARER_PASSPHRASE` is unset or blank When a person opens `/games/new` or posts to `/games` with any passphrase Then no game is created, the page says "Creating games is turned off on this instance. Ask whoever runs it.", the status is 503, no passphrase field is shown, and the log records, once per request, that the variable is not set
- [ ] **AC-1.7** Given any passphrase When it is compared Then the comparison is made with `secure_compare` on equal-length digests of both values, and the passphrase value never appears in the log
- [ ] **AC-1.8** Given a game was just created When the host page `/games/<id>/host` first loads Then it shows the secret host link once, in a read-only field with a sentence saying anyone with it controls the game, and a reload shows no link

### Story 2: The host link and the host cookie

**As a** host
**I want** a secret link that gives me the host controls on any phone
**So that** I can carry on if I lose my cookie or switch phones

**Acceptance criteria:**

- [ ] **AC-2.1** Given a host link `/games/<id>/host-link?token=<token>` with the right token When it is opened Then the host cookie for that game is set and the response redirects to `/games/<id>/host`, a page that shows the host controls and not the token
- [ ] **AC-2.2** Given a host link with a wrong token, an empty token, or a game that does not exist When it is opened Then the response is the stranger page of FR-6 and no cookie is set
- [ ] **AC-2.3** Given a phone with the host cookie When it opens `/games/<id>/host` Then the host controls show. Given a phone without it, or with a cookie that does not match, or one for another game, Then the stranger page shows and a cookie that did not match is deleted
- [ ] **AC-2.4** Given the host token When the database is inspected Then only its digest is stored, and no column of any table contains the token

### Story 3: The game shows a QR code and a join code

**As a** host
**I want** a QR code and a short code on my screen
**So that** each player can join by scanning it or by typing the code

**Acceptance criteria:**

- [ ] **AC-3.1** Given a game with joining open When the host page loads Then it shows a QR card holding an inline SVG QR code, the six-character join code in two groups of three, and the join link as text under it
- [ ] **AC-3.2** Given a request with the host name `play.example.org` over https When the host page loads Then the QR code and the link text are for `https://play.example.org/join/<code>`, an absolute URL with no path other than the join page
- [ ] **AC-3.3** Given the same game requested with another host name and over http When the host page loads Then the URL follows the request. The QR code is never built from a stored or configured host name
- [ ] **AC-3.4** Given a join code When it is generated Then it has six characters, each from the 22-character alphabet in FR-3, which holds none of `0 O Q 1 I L 2 Z 5 S 8 B U V`
- [ ] **AC-3.5** Given 1,000 codes generated When they are inspected Then all six-character, all in the alphabet, and generated with `SecureRandom`
- [ ] **AC-3.6** Given an open game holds a code When another game is made, and the generator first returns the same code Then it tries again, and the new game has a different code
- [ ] **AC-3.7** Given a game whose joining is closed When another game is made Then the new game may hold the code the closed game had
- [ ] **AC-3.8** Given the page's HTML When it is read Then the QR code is inline `<svg>` with `role="img"` and a label, and the page has no `<img>`, no script that makes it, and no request to another host

### Story 4: A player joins by QR code or by code and picks a power

**As a** player
**I want** to scan the QR code or type the code and pick an open power
**So that** I hold that power's seat on my phone

**Acceptance criteria:**

- [ ] **AC-4.1** Given an open game When a phone opens `/join/<code>` (the QR code's URL) Then it shows seven power tiles. Open tiles are buttons that name their power, and taken tiles say "Taken" and are not links or buttons
- [ ] **AC-4.2** Given `/join` When a person types the code in lower case, with a space or a hyphen in the middle, or with spaces around it, and sends it Then the response redirects to `/join/<CODE>` for the open game
- [ ] **AC-4.3** Given an open game and an open power When a phone posts that power to `/join/<code>/seat` Then one seat is created for that power, the seat cookie for that game is set, and the response redirects to the player's page `/games/<id>`
- [ ] **AC-4.4** Given the seat token When the database is inspected Then only its digest is stored, and the cookie holds the token signed, not in the clear
- [ ] **AC-4.5** Given a power that another phone already holds When a phone posts that power Then no seat is created, no cookie is set, the page shows the tiles again with a message "<Power> has been taken. Pick another.", and the status is 422
- [ ] **AC-4.6** Given two phones post the same open power at the same moment When both are handled Then exactly one seat is created, and the other phone gets AC-4.5
- [ ] **AC-4.7** Given a power name that is not one of the seven When it is posted Then no seat is created and the response is as AC-4.5 without a power name
- [ ] **AC-4.8** Given a phone that holds a valid seat for the game When it opens `/join/<code>` Then it is redirected to `/games/<id>` and no second seat is offered
- [ ] **AC-4.9** Given all seven seats are taken When `/join/<code>` loads Then seven taken tiles show with a sentence saying every seat is taken
- [ ] **AC-4.10** Given a phone with a valid seat When it opens `/games/<id>` Then the page shows its power's badge with the name, and a sentence saying the host will start the game. It shows no other seat's details

### Story 5: A stranger gets nothing

**As a** host
**I want** an unknown code, a closed game and a bad token to look the same to a stranger
**So that** nobody can find my game by trying codes or URLs

**Acceptance criteria:**

- [ ] **AC-5.1** Given a code that matches no game and a code of a game whose joining is closed When each is posted to `/join` Then both responses have status 422 and the same body, the message "That code doesn't match a game that is open for joining.", and neither echoes the code
- [ ] **AC-5.2** Given the same two codes When each is requested at `/join/<code>` Then both give status 404 and the page of AC-5.1, with the same body
- [ ] **AC-5.3** Given a code that is not six characters from the alphabet (too short, too long, with a symbol) When it is posted or requested Then the response is the same as AC-5.1 and AC-5.2
- [ ] **AC-5.4** Given a closed game When a phone posts a power to `/join/<code>/seat` Then no seat is created and the response is the same as AC-5.1
- [ ] **AC-5.5** Given `/games/<id>` or `/games/<id>/host` for a game that does not exist, and for a game that does, requested with no cookie, with a bad cookie, and with the seat cookie on a host page Then every response is the stranger page of FR-6, with the same status and body
- [ ] **AC-5.6** Given a seat link `/games/<id>/seat-link?token=<token>` with a wrong token, no token, or an unknown game When it is opened Then the response is the stranger page and no cookie is set

### Story 6: The host closes joining

**As a** host
**I want** to close joining once everyone is in
**So that** nobody else can take a seat

**Acceptance criteria:**

- [ ] **AC-6.1** Given an open game When the host opens `/games/<id>/host/close` Then a page says closing cannot be undone and that the players who joined keep their seats, with a danger button and a link back
- [ ] **AC-6.2** Given the confirmation page When the host posts it Then joining is closed, the response redirects to the host page, and the host page says joining is closed and shows no QR code or join code
- [ ] **AC-6.3** Given a closed game When a phone opens `/join/<code>` or posts to `/join/<code>/seat` Then the response is as in Story 5, and seats already held keep working
- [ ] **AC-6.4** Given a request to close from a phone that is not the host When it is made Then the stranger page shows and joining stays open
- [ ] **AC-6.5** Given a game already closed When the host posts close again Then nothing changes and the response redirects to the host page

### Story 7: The host reissues a seat

**As a** host
**I want** to give a power to a new phone with a new QR code
**So that** a player whose phone is lost or broken can carry on, and the old phone cannot

**Acceptance criteria:**

- [ ] **AC-7.1** Given a game with seats When the host page loads Then it lists all seven powers, each taken power as a row that links to its reissue page and each open power as a row saying "Open"
- [ ] **AC-7.2** Given a taken seat When the host opens `/games/<id>/host/seats/<power>/reissue` Then a page says the old phone loses the seat at once, with a danger button and a link back
- [ ] **AC-7.3** Given the confirmation page When the host posts it Then the seat's stored digest is replaced by the digest of a new token, and the response redirects to `/games/<id>/host/seats/<power>/qr`
- [ ] **AC-7.4** Given that redirect When the page loads Then it shows a QR card for the seat, with the power's badge as its caption and the link `/games/<id>/seat-link?token=<token>` as absolute text and QR code, once. A reload shows no QR code and sends the host back to the host page with a sentence saying a new code can be issued
- [ ] **AC-7.5** Given the old seat cookie of that power When its phone makes its next request to `/games/<id>` Then it gets the stranger page, and the cookie is deleted
- [ ] **AC-7.6** Given the new link When a phone opens it with the right token Then the seat cookie for that game is set, the response redirects to `/games/<id>`, and the page shows that power
- [ ] **AC-7.7** Given a reissued seat When the old token is presented in a seat link Then the response is the stranger page and no cookie is set
- [ ] **AC-7.8** Given a power with no seat, or a power name that is not one of the seven When its reissue page or reissue is requested Then the stranger page shows and nothing changes
- [ ] **AC-7.9** Given a reissue request from a phone that is not the host When it is made Then the stranger page shows and the seat's digest is unchanged
- [ ] **AC-7.10** Given the host's own seat When the host reissues it Then it works as for any other seat

### Story 8: Guessing is slowed down

**As a** host
**I want** repeated wrong tries from one address to be refused
**So that** a stranger cannot find a code, a token or the passphrase by trying

**Acceptance criteria:**

- [ ] **AC-8.1** Given the test environment When the cache store is read Then it is a real store that remembers (not the null store), and a spec fails if it is the null store, because `rate_limit` does nothing with the null store
- [ ] **AC-8.2** Given one address that has made 30 requests in a minute to `/join` (post) and `/join/<code>` (get) together When it makes the 31st Then the response is 429 with the message "Too many tries. Wait a minute and try again.", and the same address is not refused earlier
- [ ] **AC-8.3** Given a different address When the first address is limited Then the second address is answered normally
- [ ] **AC-8.4** Given one address that has posted 30 times to `/join/<code>/seat` in a minute When it makes the 31st Then the response is 429
- [ ] **AC-8.5** Given one address that has posted 10 times to `/games` in five minutes, right or wrong, When it posts the 11th Then the response is 429, and no game is created even if the passphrase is right
- [ ] **AC-8.6** Given one address that has opened 20 host links and seat links in a minute together When it opens the 21st Then the response is 429
- [ ] **AC-8.7** Given the minute has passed When the same address tries again Then it is answered normally

### Story 9: The four components, on the style guide, at phone width

**As a** developer building the next screens
**I want** the join code, QR card, power tile and host section in the catalog and on `/styleguide`
**So that** #22 onwards reuse them

**Acceptance criteria:**

- [ ] **AC-9.1** Given `/styleguide` When it loads Then it shows sections `join-code`, `qr-card`, `power-tile` (open and taken tiles) and `host-section`, each with a heading
- [ ] **AC-9.2** Given `/styleguide` and every new screen at 360 and 768 pixels wide When each open `.power-tile` and every other tappable control is measured Then each is at least 44 by 44 pixels, and the page has no horizontal scroll at 360 pixels
- [ ] **AC-9.3** Given a power tile When it is read Then it shows the power's name as text, in open and in taken form, and a taken tile also says "Taken". No tile relies on color alone
- [ ] **AC-9.4** Given the stylesheets When they are scanned Then the existing rules hold: no raw color, no banned property, total weight within 24 KB and the style guide's own file within 4 KB
- [ ] **AC-9.5** Given the host section's ground, `ice-pale` When the controls on it are used Then the pairs `primary`, `primary-pressed`, `border`, `danger`, `danger-pressed` and `focus` against `ice-pale` (minimum 3), and `link` and `link-visited` on `ice-pale` (minimum 4.5), are in the documented pairs of `web/docs/design-system.md` and in the contrast spec, and pass
- [ ] **AC-9.6** Given `web/docs/design-system.md` When it is read Then the catalog marks the four components as built by #21, with their final class names and variants
- [ ] **AC-9.7** Given the join code on a 360-pixel screen When it is measured Then it is in mono type, at least `--text-2xl`, and fits without wrapping or scrolling
- [ ] **AC-9.8** Given a seat's QR card and a game's QR card When each is measured at 360 pixels Then the QR code is at least 200 pixels wide and has a quiet zone of at least four modules on a white ground

### Story 10: A game is created and joined in a real browser

**As a** maintainer
**I want** the whole flow tested in a real browser at phone width
**So that** layout and flow break loudly

**Acceptance criteria:**

- [ ] **AC-10.1** Given a browser session at 360 pixels wide When it creates a game with the right passphrase and takes a power Then it lands on the host page showing a QR code and a join code
- [ ] **AC-10.2** Given a second browser session with its own cookies When it opens `/join`, types the join code and picks a free power Then it lands on its player page for that power, and the first session's host page, reloaded, marks that power taken
- [ ] **AC-10.3** Given the host session When it closes joining and a third session opens the same code Then the third sees the page of AC-5.1
- [ ] **AC-10.4** Given a screen shown by these flows When it is measured Then it has no horizontal scroll at 360 pixels

## Functional Requirements

### FR-1: The pages

Every screen is a normal page with its own URL, and works without JavaScript.

| Path | Method | What it is |
|---|---|---|
| `/` | GET | The home page: its existing text, then two buttons: "Create a game" and "Join a game" |
| `/games/new` | GET | The passphrase field and the seven power tiles |
| `/games` | POST | Create a game |
| `/games/<id>` | GET | The player's page. Needs the seat cookie |
| `/games/<id>/host` | GET | The host page. Needs the host cookie |
| `/games/<id>/host-link?token=` | GET | Open a host link. Sets the host cookie |
| `/games/<id>/seat-link?token=` | GET | Open a seat link. Sets the seat cookie |
| `/games/<id>/host/close` | GET, POST | Confirm closing, and close |
| `/games/<id>/host/seats/<power>/reissue` | GET, POST | Confirm reissuing, and reissue |
| `/games/<id>/host/seats/<power>/qr` | GET | The reissued seat's QR code, shown once |
| `/join` | GET, POST | The code field, and the code lookup |
| `/join/<code>` | GET | The power tiles for an open game. The QR code's URL |
| `/join/<code>/seat` | POST | Take a power |

**Must:**
- Name every page with a `<title>` and one `<h1>`.
- Use `.stack`, `.field`, `.control`, `.button`, `.list`, `.power-badge` and the four new components, and no inline style.
- Show every error as text near the top of the page, with the status code given in the AC.

**Must not:**
- Use a modal, a sheet, a dialog or any overlay.
- Put the host token or a seat token in any page's HTML, except in the single page that shows it once, and never in a page that can be reloaded to show it again.

### FR-2: Tokens and cookies

**Must:**
- Make a host token and a seat token from `SecureRandom`: 24 bytes, URL-safe base64, 32 characters, at least 128 bits.
- Store only the SHA-256 digest of a token, as a hex string. No log line, flash value that outlives the next request, or column holds a token.
- Compare a presented token with the stored digest through `ActiveSupport::SecurityUtils.secure_compare`, on digests of equal length.
- Set the host cookie `host_<id>` and the seat cookie `seat_<id>` as signed, permanent cookies with `httponly: true` and `same_site: :lax`, and `secure: true` when the app runs in production. Their value is the token. A phone holds at most one of each per game.
- Treat a cookie whose token does not match the stored digest as a stranger's, and delete it.
- Filter `passphrase` and `token` from the log, so the passphrase and `?token=` values never appear there. (`token` is already filtered.)
- Make the session cookie that carries the one-time flash `httponly`, `same_site: :lax` and `secure` in production.

**Must not:**
- Put a token in a cookie in the clear, in a response header, or in a path (it is in a query string so the log filter hides it).
- Use `==` or `eql?` to compare a token, a digest or the passphrase.

### FR-3: The join code

**Must:**
- Have six characters, from this alphabet of 22: `A C D E F G H J K M N P R T W X Y 3 4 6 7 9`. The alphabet leaves out `0 O Q` (round), `1 I L` (upright strokes), `2 Z`, `5 S`, `8 B` and `U V`, so no two characters are easy to mistake for each other on a phone screen. 22 to the sixth power is 113,379,904 codes.
- Be made with `SecureRandom`.
- Be unique among games whose joining is open: the database refuses two open games with the same code, and the generator retries on a clash, up to five times, then fails the request.
- Be freed when joining is closed, so a closed game's code may belong to a new game. The database does not keep a closed game's code unique.
- Be read forgivingly: upper-cased, spaces and hyphens removed. Anything else that is not in the alphabet is a wrong code. It never converts one character into another.
- Show in two groups of three (`ABC DEF`), in mono type.

### FR-4: The QR code

**Must:**
- Hold the absolute join URL `<base URL>/join/<code>`, built from the request's base URL: the scheme and host the request arrived with.
- Be inline SVG made by the server, with module squares in one color from a token (`text`) on the card's `surface` ground, with a quiet zone of four modules, an error correction level of at least M, and an accessible name.
- Show the same URL as text under the code, so a person can copy it or read it out.

**Behind a proxy.** The scheme comes from `assume_ssl` or `X-Forwarded-Proto`, and the host from `X-Forwarded-Host` or `Host`, as Rails reads them. Behind the Cloudflare tunnel (`docs/architecture.md`, "Hosting") the tunnel keeps the public host name in `Host`, and `assume_ssl` makes the scheme `https`, so the code holds the public https URL. If the proxy rewrote `Host`, the QR code would be wrong, so the proxy must not. A host who opens the page by another name (for example the machine's address on the local network) gets a code for that name, which is right for a phone on that network.

**Must not:**
- Fetch a QR code or any asset from another host, or use JavaScript to draw it.
- Store the QR code or its URL.

### FR-5: The passphrase

**Must:**
- Read `TRUCEBEARER_PASSPHRASE` from the environment on each request.
- When it is unset or blank, refuse (AC-1.6). It is never treated as "no passphrase needed".
- Compare as set out in D2 and AC-1.7: digest both sides and compare with `secure_compare`, so the time taken does not depend on how much of the guess is right or on its length.
- Give one message for every wrong value (AC-1.4), and never say what was wrong with it.
- Document the variable in `web/README.md` and list it in the `env` block of `config/deploy.yml` as a secret.

**Must not:**
- Name the variable on screen. The log line names it, for whoever runs the instance.
- Log or echo the passphrase value.

### FR-6: Strangers

The stranger page is a page that says "We can't find that page.", with status 404 and a link to the home page. It is one page, shown for every request that has no right to a game page, host page or link (D4).

**Must:**
- Show it identically for an unknown game, a known game with no cookie, a cookie that does not match, a host cookie on a seat page and the reverse, a bad link token and a missing token.
- Show it for a reissued seat's old cookie, and delete that cookie.

**Must not:**
- Redirect a stranger to the code page, or say a game exists, is closed, or has seats.

### FR-7: Joining and seats

**Must:**
- Offer only the seven powers the rules engine reports for the classic map, with the names it reports. The app reads them through `RulesEngine` and names no gem constant elsewhere.
- Never let two seats hold one power in one game, even for requests made at the same moment: the database enforces it.
- Create the host's seat when the game is created, in the same step, so a game never exists without it.
- Close joining by setting a time on the game. A game with a time set is closed for good (D7).
- Reissue a seat by replacing its token digest, in one step. The old token stops working with that step.

**Must not:**
- Let a phone with a valid seat take another seat in the same game from the join page.
- Show a player any other seat's token, digest or phone.

### FR-8: Rate limits

Rails' `rate_limit` is used, keyed by `request.remote_ip`, with these limits. Each refusal is status 429 with the message "Too many tries. Wait a minute and try again." and no other detail.

| Bucket | Requests | Limit |
|---|---|---|
| Code lookup: `POST /join` and `GET /join/<code>` | together | 30 per minute |
| Taking a power: `POST /join/<code>/seat` | | 30 per minute |
| Creating a game: `POST /games` | right or wrong | 10 per 5 minutes |
| Opening a link: `host-link` and `seat-link` | together | 20 per minute |

**Must:**
- Count every request in a bucket, whether it succeeds or not.
- Use a cache store that remembers. In production this is the Solid Cache store. In the test environment it is set to the in-memory store, and each spec that tests a limit starts with an empty one. A spec fails if the store is the null store (AC-8.1).
- Leave room for seven phones behind one address to join in a minute (about 14 requests in the lookup bucket and 7 in the taking bucket, plus mistyped codes).

**Behind a proxy.** `remote_ip` is the address of the player, as Rails reads it from `X-Forwarded-For` through the proxies it trusts. Behind the tunnel, the trusted-proxy defaults of Rails cover the tunnel and the local proxy. If the proxy chain changed so every request seemed to come from one address, all strangers and players would share one bucket. The plan records how this is checked on the real instance.

### FR-9: What is kept

The tables are made for what #21 needs (D1).

**`games`**

| Column | Kind | Notes |
|---|---|---|
| `id` | integer | Primary key, never in a URL |
| `public_id` | string, 12 characters | Random. Unique. Used in every URL |
| `host_token_digest` | string | SHA-256, hex. Unique. Never the token |
| `join_code` | string, 6 characters | The code of FR-3 |
| `joining_closed_at` | datetime, null | Null while joining is open |
| `created_at`, `updated_at` | datetime | |

Indexes: unique on `public_id`; unique on `host_token_digest`; unique on `join_code` only where `joining_closed_at` is null (FR-3).

**`seats`**

| Column | Kind | Notes |
|---|---|---|
| `id` | integer | Primary key |
| `game_id` | reference | Required, with a foreign key |
| `power` | string | One of the seven power identifiers, as the rules engine reports them |
| `token_digest` | string | SHA-256, hex. Unique. Never the token |
| `created_at`, `updated_at` | datetime | |

Indexes: unique on `[game_id, power]`; unique on `token_digest`.

**Must:**
- Check `power` against the rules engine's list in the model, as well as the database's uniqueness.
- Keep games and seats in the primary database, with no new database file.

**Must not:**
- Add a phases table, a position column, a game name, a user reference or a "starts at" time. #22, #28 and 1.0 add those.
- Store a token, the passphrase, or a QR code.

### FR-10: The components

Built to `web/docs/design-system.md`, with the names in its catalog. The components' rules are in the stylesheet, `components.css`, using tokens only.

| Component | Class | Rule |
|---|---|---|
| Join code | `.join-code` | Six mono characters in two groups of three, at least `--text-2xl`. The element holds the text, so it can be selected and read aloud |
| QR card | `.qr-card` | `surface` ground and `border` edge, padding to give the quiet zone, the SVG centered at no more than 18rem, a caption slot under it (`.qr-card__caption`) for the join code or a power badge, and the link text under that, wrapping anywhere |
| Power tile | `.power-tile`, `--taken` | A grid of two columns at 360 pixels, more as the width allows. Each tile has the power's badge (`power_badge`) and, when taken, the text "Taken", a dashed edge and the disabled fill. An open tile is a `<button>` of at least 44 pixels in height and `touch-action: manipulation`. A taken tile is a `<div>` |
| Host section | `.host-section` | `ice-pale` ground, the heading "Host", apart from the player's own content. It holds the host's controls, and appears on the host page and, as a link back to it, on the host's own player page |

**Must:**
- Use `power_badge` for every power color. A power color is never drawn by the new CSS.
- Put each component on `/styleguide` with a section named by `data-component`, and keep the style guide's checks (tap size at 360 and 768, no sideways scroll, the focus check) green. The tap-size check's selector list gains `.power-tile:not(.power-tile--taken)`.
- Keep total stylesheet weight within 24 KB, and `styleguide.css` within 4 KB. The folder is about 21.0 KB now, so the four components together must take no more than about 3 KB. If they cannot, that is raised as an Issue before any limit is changed.
- Add the `ice-pale` pairs of AC-9.5 to the document, the style guide's pair list and the contrast spec.

**Must not:**
- Use a modal, a raw color, `!important`, `opacity` or a power color outside `power_badge`.

### FR-11: The dependency

Add the gem `rqrcode` and nothing else of the project's own choosing.

| Gem | Version | License | Why |
|---|---|---|---|
| `rqrcode` | 3.2.0 | MIT | Draws a QR code as inline SVG on the server |
| `rqrcode_core` | 2.1.0 | MIT | `rqrcode`'s encoder. Required by it |
| `chunky_png` | 1.4.0 | MIT | Required by `rqrcode` for its PNG output, which the app does not use |

All three are pure Ruby, with no native extension and no further runtime dependency. A QR code is a standard (ISO/IEC 18004) with error correction and mask scoring, and is not worth writing again. The alternative, a JavaScript library or a third-party image service, is ruled out: no JavaScript, and no request to a third party. The final versions and the lockfile's result are recorded in the pull request.

### FR-12: What changes elsewhere in the app

- `RulesEngine` gains one reader, `powers`, returning the map's powers (identifier and name). This is the only place a power list comes from. A spec checks that `PowerBadgeHelper::POWER_NAMES` has the same powers and names, so the two cannot drift.
- `config/routes.rb`, the home page, the style guide, the contrast spec, `web/docs/design-system.md`, `web/README.md`, `config/deploy.yml`, the test environment's cache store and the log filter change as set out above.
- Nothing outside `web/` changes.

## Non-Functional Requirements

### Performance

- Every page renders in one request with no JavaScript. The QR code is drawn within the request.
- The host page, with a QR code, is under 40 KB of HTML.

### Security

- The instance can be reached from the internet (`docs/architecture.md`, "Hosting"). Every control above is tested in a request spec: tokens, cookies, passphrase, stranger pages, code lookup, rate limits and reissue.
- No page reveals a token after the one page that shows it. No log holds a token or the passphrase.
- `bin/brakeman` is clean, with no warning ignored for this feature.
- Responses that show a token send `Cache-Control: no-store`, and the host-link and seat-link responses send `Referrer-Policy: no-referrer`.
- Forms keep Rails' forgery protection on, and every state-changing route is a POST.
- A stranger can still make requests that cost the server something, up to the limits of FR-8. This feature does not add a firewall.
- Code lookups do not take constant time. The defense is the rate limit and the size of the code space (FR-3), not timing.

### Reliability

- A game is never left without its host seat, and a code clash never creates a game with a duplicate code. Both happen in one database transaction.
- A cookie that cannot be verified, for any reason, shows the stranger page and never an error page.

### Accessibility and layout

- Every control is at least 44 by 44 pixels. Every power is shown with its name. No page scrolls sideways at 360 pixels. The existing focus ring is used.
- The QR code has an accessible name, and the join code and link are text beside it, so a person who cannot scan can still join.

## Error Scenarios

| Scenario | Expected behavior |
|---|---|
| Passphrase variable unset or blank | Page and POST refused with 503 and a plain message. No game. A log line names the variable |
| Wrong, empty or missing passphrase | 422, "That passphrase isn't right.", no game, no cookie |
| Right passphrase, no valid power | 422, "Pick one of the seven powers." |
| Unknown code, closed game's code, malformed code | `/join` POST 422 and `/join/<code>` GET 404, one message and one body |
| Power already taken | 422, tiles shown again, "<Power> has been taken. Pick another." |
| Two phones take one power at once | One seat. The other gets "taken" |
| All seven taken | Seven "Taken" tiles and a sentence |
| Stale, forged or missing host or seat cookie | Stranger page (404), stale cookie deleted |
| Reissued seat's old cookie | Stranger page, cookie deleted |
| Old seat token in a seat link | Stranger page |
| Join code clash on creation | Try another code, up to five times, then a 500 |
| Rate limit hit | 429, "Too many tries. Wait a minute and try again." |
| Reload of the one-time host link or QR page | No token. The host page, or a sentence on the host page |
| Closing joining twice | No change, redirect to the host page |
| QR gem cannot make a code for a URL | The page shows the link as text and no QR code. This is logged. (A URL this short always fits.) |

## Open Questions

None.

## Out of Scope (Future Considerations)

- Reopening a closed game's joining, and showing joiners on the host page as they arrive (live, with Turbo Streams). Both are small and need no change to the tables.
- A game name and a "my games" list (#28).
- Claiming a guest seat with an account (1.0).
- Removing a seat altogether (as opposed to reissuing it), and ending or deleting a game.
- Hardening `config.hosts` for the production host name. Production does not set it yet, and `assume_ssl` is commented out in `config/environments/production.rb` although `docs/architecture.md` says it is true. Both are for the maintainer.

## Verification

| What | How |
|---|---|
| 1.x, 2.x, 4.x, 5.x, 6.x, 7.x | Request specs, `spec/requests/`: games, host links, joining, strangers, closing, reissuing |
| 3.4 to 3.7 | Plain model specs for the join code and for the games table's constraints |
| 3.1 to 3.3, 3.8, 7.4 | Request specs that read the page's HTML, and compare the QR code's SVG with the one made for the expected URL |
| 8.x | Request specs against the in-memory cache store, with a limit test for each bucket, a second address, and a spec that fails on the null store |
| 1.7, 2.4, 4.4, FR-2 | Model and request specs on tokens, digests, cookie flags (read from the `Set-Cookie` header: signed, `HttpOnly`, `SameSite=Lax`, `Secure` in production) and the log filter |
| 9.1, 9.3, 9.4, 9.5, 9.6 | The style guide request spec, the stylesheet rules spec, the contrast spec and the design-system document spec |
| 9.2, 9.7, 9.8, 10.x | System specs in headless Chrome at 360 and 768 pixels: the style guide's layout spec, and a new spec in which one session creates a game and a second session joins it by code |
| Dependencies and the guard | `bundle exec rspec`, `bin/brakeman`, `bin/rubocop`, and the existing guard spec on the gem's name |

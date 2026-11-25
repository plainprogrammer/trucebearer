# Architecture

The technical decisions both sides of the repository build on. If new evidence suggests one of them is wrong, raise it in an Issue rather than working around it.

## Stack

| Area | Decision |
|---|---|
| Language | Ruby 4.x on both sides; the exact release is not pinned yet |
| App framework | Rails 8.1 with Turbo and Stimulus, built ready for a Hotwire Native wrapper |
| Front end | No build step: Propshaft, import maps, plain modern CSS |
| Database | SQLite, with Solid Queue, Solid Cache and Solid Cable |
| Live updates | Turbo Streams over Solid Cable |
| Deployment | Kamal to a single server; self-hosters run the same Docker image |
| Sign-in | Passkeys, with an emailed sign-in link as fallback; no passwords stored |
| Testing | RSpec on both sides |
| Licence | AGPL-3.0-or-later for the app (with a section 7(c) disclosure term) and the gem; MPL-2.0 for future native shells; CC BY-SA 4.0 for assets and docs. See `NOTICE` |

## The adjudicator

- Written in Ruby, test-first, as the gem `trucebearer-adjudicator` (module `Trucebearer::Adjudicator`) in `adjudicator/`.
- Classic map only at first, loaded from a data file, so variants remain possible without a rewrite.
- The current rulebook is the baseline, and the DATC decides edge cases. Every choice is recorded in `adjudicator/docs/ruleset.md`.
- DATC scenarios are encoded as original, data-driven specs. No text from the document is copied.
- The algorithm follows Kruijswijk's "The Math of Adjudication" (proposed).
- Orders are checked as they are entered, so the gem offers checking of a single order separately from adjudication (proposed).

## The boundary between the gem and the app

The gem knows maps as data, powers, provinces, coasts, units, order types, checking a single order against a position, adjudication of a full set of orders for a phase, retreat options, adjustment counts, and the resulting position.

The gem does not know games, seats, accounts, hosts, clocks, persistence, HTTP, or display.

The app passes in a position and a set of orders and gets back outcomes and the next position, all as plain data that can be stored and replayed. The contract is written down in `adjudicator/docs/interface.md`.

## Phase one

The app supports in-person play around a physical board: secret order entry on phones, adjudication, text-only results, host controls, an optional shared display, an optional phase clock, saved games, and guest seats joined by QR code that can be claimed with an account later.

Not in phase one: virtual or mixed-mode play, any rendered map, in-app chat, matchmaking or ratings, tournament tools, computer players.

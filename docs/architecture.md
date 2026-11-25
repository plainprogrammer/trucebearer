# Architecture

The technical decisions both sides of the repository build on. If new evidence suggests one of them is wrong, raise it in an Issue rather than working around it.

## Stack

| Area | Decision |
|---|---|
| Language | Ruby 4.0.10, pinned in the root `.ruby-version` |
| App framework | Rails 8.1 with Turbo and Stimulus, built ready for a Hotwire Native wrapper |
| Front end | No build step: Propshaft, import maps, plain modern CSS |
| Database | SQLite, with Solid Queue, Solid Cache and Solid Cable |
| Live updates | Turbo Streams over Solid Cable |
| Deployment | Kamal to a single server; self-hosters run the same Docker image |
| Sign-in | Passkeys, with an emailed sign-in link as fallback; no passwords stored. Arrives in 1.0 (see "Targets") |
| Testing | RSpec on both sides |
| License | AGPL-3.0-or-later for the app (with a section 7(c) disclosure term) and the gem; MPL-2.0 for future native shells; CC BY-SA 4.0 for assets and docs. See `NOTICE` |

### Ruby upgrades

Stay on the newest stable patch release of the current 4.x minor version. When a new minor version comes out, move to it within three months.

## Targets

| Target | What it covers |
|---|---|
| **Playtest** | Movement phases played at a real table and adjudicated by the gem. The host makes retreats and builds by hand in a position editor |
| **1.0** | Whole games, every phase adjudicated, run privately by a group |

Neither target includes the phase clock, the shared display or backups. Also out of scope for now: virtual or mixed-mode play, any rendered map, in-app chat, matchmaking or ratings, tournament tools and computer players.

## Hosting

- The instance runs on a VM in a home lab and is deployed with Kamal.
- A Cloudflare tunnel sits in front of it and terminates TLS. So Rails sets `config.assume_ssl = true`, and kamal-proxy runs with `ssl: false`.
- The allowed Action Cable origins and the passkey origin come from environment variables, not from code.
- The instance can be reached from the internet. Joining a game and every host action must stay safe when strangers find the URL.

## The adjudicator

- Written in Ruby, test-first, as the gem `trucebearer-adjudicator` (module `Trucebearer::Adjudicator`) in `adjudicator/`.
- Classic map only at first, loaded from a data file, so variants remain possible without a rewrite.
- The current rulebook is the baseline, and the DATC decides edge cases. Every choice is recorded in `adjudicator/docs/ruleset.md`.
- DATC scenarios are encoded as original, data-driven specs. No text from the document is copied.
- The algorithm follows Kruijswijk's "The Math of Adjudication" (proposed).
- Orders are checked as they are entered, so the gem offers checking of a single order separately from adjudication (proposed).

### Releases

| Version | Adds |
|---|---|
| 0.1.0 | The classic map, the value objects, checking a single order, and listing a unit's legal orders |
| 0.2.0 | Movement adjudication, convoys included |
| 0.3.0 | Retreats, adjustments, working out the next phase, and convoy paradoxes |

The playtest needs 0.2.0. 1.0 needs 0.3.0.

## The boundary between the gem and the app

The gem knows maps as data, powers, provinces, coasts, units, order types, checking a single order against a position, adjudication of a full set of orders for a phase, retreat options, adjustment counts, and the resulting position.

The gem does not know games, seats, accounts, hosts, clocks, persistence, HTTP, or display.

Everything that crosses the boundary is an immutable value object built on Ruby's `Data`. Each one has a documented hash form, reached through `to_h` and rebuilt through `from_h`, and that hash form carries a format version. The app stores the hash form as JSON, so any phase can be replayed from what was saved. The contract is written down in `adjudicator/docs/interface.md`.

## Game rules in the app

- **Playtest access.** There are no accounts in the playtest. Each game has a secret host link. Creating a game requires the instance passphrase, which is set in an environment variable. Accounts replace this in 1.0.
- **Guest seats.** A guest seat is held by a random token in a signed cookie, and the server stores only a digest of it. The host can reissue a seat's token and close joining. The join code is six characters, uses no characters that look alike, and is rate-limited.
- **Order secrecy.** No one sees an order before the reveal, and that includes the host. The host can step into another seat after a prominent confirmation. The step-in is recorded, the seat's owner is told, and the game history keeps it.
- **Phase lifecycle.** A phase stays open until the host reveals it. Submitting doesn't lock anything: if a seat edits its orders after submitting, it goes back to "not submitted". Revealing locks the phase, adjudicates it and shows the results on every phone at the same time.
- **Order entry.** Players pick orders from lists rather than typing them, choosing the unit first, and only legal orders are offered. A unit without an order holds.

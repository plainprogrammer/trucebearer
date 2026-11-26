# Trucebearer web app

The Rails app that players and hosts use at the table. Agent instructions are in `AGENTS.md`; the technical decisions are in `../docs/architecture.md`.

- Set up: `bin/setup`
- Run the tests: `bundle exec rspec`
- Run the app: `bin/rails server`

## Playtest access

Creating a game needs a shared passphrase. Set `TRUCEBEARER_PASSPHRASE` in the environment of the server (for Kamal deploys it is listed under `env.secret` in `config/deploy.yml` and read from the deploy machine's environment through `.kamal/secrets`). When it is unset or blank, creating a game is refused with a 403 and the app logs a warning. Joining and playing in a game that already exists does not need it.

When the host steps into another seat, the seat's owner is told the time ("The host entered your orders at 8:42 PM EST"). Set `TRUCEBEARER_TIME_ZONE` to a zone name such as `America/New_York` to show that time at the table's own clock. It is read each time a page is drawn, an unset or unknown name means UTC, and the zone's abbreviation is always shown. It is not a secret: for Kamal deploys it is under `env.clear` in `config/deploy.yml`.

Host and seat links carry a secret token in the query string. Proxy and tunnel logs, and browser history, may keep those links. In this release the host token cannot be rotated, so treat a host link like a password and share it only with the host.

## The position editor

The host fixes the board by hand: the host page has an "Edit the board" link next to "Reveal orders". It adds, moves and removes units, sets who owns a supply center, and sets the season and year of the open phase, one change at a time, each on its own page. The rules engine checks every change against the map and refuses an impossible board in plain words. An edit that moves units (add, move, remove) clears every seat's saved orders and submissions for the open phase, and each seat sees a notice with the time; an ownership or date edit keeps them. The host sees no order there, and never a count. Every edit is written to the game's history, in the host page's Seat history list.

## Live updates

The seat page and the host's controls show which powers have submitted, and update on every phone without a reload. The updates travel over Action Cable (Turbo Streams over Solid Cable). A message holds only the seven submitted states and nothing else; Solid Cable keeps each message for a day, so that is all it keeps.

When the host reveals a phase, every open seat page, host page, order screen and picker step also switches to the results without a tap. The message that does it is a Turbo refresh with no content at all, sent on a second stream per game (`results:<game id>`), and each phone then reloads its own page through its normal, authorized request, so what it shows is decided by the same checks as any page load. Solid Cable keeps that message for a day too, and it holds nothing. A phone that was asleep or offline shows the old page until it is touched or reloaded.

The browser opens the socket from the page's own address, and Action Cable accepts it only from the origins it knows. Set `TRUCEBEARER_CABLE_ORIGINS` to the other origins that may open it, separated by commas or spaces, for example `https://play.example.org` (written in lowercase, as a browser sends it). It is not a secret, so for Kamal deploys it is listed under `env.clear` in `config/deploy.yml`.

When it is unset or blank, Rails' own default applies: only a socket opened from the address the app is served at (`https://` plus the `Host` header, because the app assumes SSL behind its proxy) is accepted. A deployment where players reach the app at that address works with nothing set. Where they do not (a proxy that rewrites the `Host` header, or a second public name), the socket is refused and the log says "Request origin not allowed". Nothing is shown to the player: every page is still correct whenever it loads, and only the live updates are missing. Forgery protection is never switched off.

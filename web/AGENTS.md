# Trucebearer web app: instructions for agents

You are working on the Rails app that hosts and players use at the table. Read the root `AGENTS.md` too; its shared rules apply here.

The Rails app has not been generated yet. When it is, run `rails new` into this folder. Then delete the `.ruby-version` it creates (the root one applies) and move any generated `.github/` workflow into the root `.github/workflows/`, because GitHub only reads workflows from the root.

## Stack

- Rails 8.1 with Turbo and Stimulus.
- No build step: Propshaft, import maps, plain modern CSS. No Node, no Tailwind.
- SQLite with Solid Queue, Solid Cache and Solid Cable. Live updates are Turbo Streams over Solid Cable.
- Deployed with Kamal to a single server. Self-hosters run the same Docker image, so all configuration comes from environment variables. The Docker build context is this folder.
- Sign-in uses passkeys, with an emailed sign-in link as the fallback. No passwords are stored.

## Ready for Hotwire Native

Native apps come later through Hotwire Native, so build for it from the start:

- Every screen is a normal Turbo Drive page with a meaningful URL.
- Modals, sheets and tab-like sections are built so a path configuration can route them later.
- Nothing depends on a browser feature a web view lacks, unless it degrades cleanly.
- Keep Stimulus controllers small. Anything that would become a native bridge component (QR scanning, sharing a join link, haptics) goes behind its own controller.

## The adjudicator gem

- The app depends on `trucebearer-adjudicator` at a **git tag** (`adjudicator-vX.Y.Z`) of this repository, using Bundler's `glob:` option to find the gemspec in `adjudicator/`. Never point the Gemfile at the local `../adjudicator` folder.
- Never edit `adjudicator/`. If the app needs something the gem doesn't do, open an Issue with the "Adjudicator request" template. Give example input and the expected output as plain data, then carry on with other work.
- Upgrading the pinned version is its own pull request. Read the gem's `CHANGELOG.md` and any open "Interface change" Issues first.
- The gem's public interface is described in `adjudicator/docs/interface.md`. Use nothing beyond it.
- Store positions, orders and results as the plain data the gem returns, so any game can be replayed.

## Scope for phase one

In scope: secret order entry on phones, adjudication through the gem, text-only results, host controls, an optional shared display, an optional phase clock, saved games that resume across sessions, and guest seats joined by QR code that can be claimed with an account.

Not yet, and don't build towards these: virtual or mixed-mode play, any rendered map, in-app chat, matchmaking or ratings, tournament tools, computer players.

## Words on screen

- Never paste rulebook text into help screens or anywhere else. Write explanations from scratch and cite rule sections by number.
- "Diplomacy" may appear only in plain body text, to describe what the app is for. It is never the largest or most prominent word on a page. Never use words like "official", "licensed" or "authorized".
- No logos, artwork, board images or fonts from any edition of the game.
- Pick up Issues labeled `web`.

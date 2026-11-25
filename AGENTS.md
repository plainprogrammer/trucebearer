# Trucebearer: instructions for agents

Trucebearer is a mobile-first web app that helps a group around a physical board enter secret orders on their phones and have each turn adjudicated. This repository holds two separate projects that share only a name and a Ruby version.

| Folder | What it is | Its instructions |
|---|---|---|
| `adjudicator/` | The `trucebearer-adjudicator` gem: the rules engine, in plain Ruby | `adjudicator/AGENTS.md` |
| `web/` | The Rails app that players and hosts use | `web/AGENTS.md` |

## Work on one side only

- Start every task inside `adjudicator/` or `web/` and read that folder's `AGENTS.md` before doing anything else.
- Never change files in the other side's folder. If you need something from the other side, open an Issue with the matching template in `.github/ISSUE_TEMPLATE/` and carry on with what you can do.
- A pull request touches one side only. Changes to root files (this file, `docs/`, `.github/`, licence files) go in their own pull request.
- The app depends on a tagged release of the gem, never on the gem's working copy. See `docs/repository-layout.md`.

## Shared rules

- **Ruby 4.x** on both sides. The exact version will be pinned in a root `.ruby-version` once it is chosen. Don't add a `.ruby-version` inside either folder.
- **Test first, with RSpec**, on both sides.
- **The name.** "Trucebearer" is always one word. Never give anything (a class, a file, a branch, a gem, a label) a name that contains or echoes "Diplomacy" or "Dip".
- **No copied rules text.** Never paste text from the game's rulebook or from the DATC (Diplomacy Adjudicator Test Cases) document into code, comments, tests, fixtures or docs. Explain things in your own words and cite the section number.
- **No copied code.** Other open-source engines may be read as references only. Don't copy or translate their code.
- **Licence.** All code is AGPL-3.0-or-later (`LICENSE`). The name and logo are covered by `TRADEMARKS.md`, not by the code licence.
- **Fewest moving parts.** Prefer the Ruby standard library and Rails defaults. Adding a dependency needs a reason in the pull request.

## Where decisions live

- `docs/architecture.md`: the technical decisions both sides build on, and the boundary between the gem and the app.
- `docs/repository-layout.md`: how this repository is organised and how work moves between the two sides.

If something you find contradicts a decision there, say so in the Issue or pull request. Don't quietly work around it.

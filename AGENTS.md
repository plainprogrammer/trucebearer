# Trucebearer: instructions for agents

Trucebearer is a mobile-first web app that helps a group around a physical board enter secret orders on their phones and have each turn adjudicated. This repository holds two separate projects that share only a name and a Ruby version.

| Folder | What it is | Its instructions |
|---|---|---|
| `adjudicator/` | The `trucebearer-adjudicator` gem: the rules engine, in plain Ruby | `adjudicator/AGENTS.md` |
| `web/` | The Rails app that players and hosts use | `web/AGENTS.md` |

## Work on one side only

- Start every task inside `adjudicator/` or `web/` and read that folder's `AGENTS.md` before doing anything else.
- Never change files in the other side's folder. If you need something from the other side, open an Issue with the matching template in `.github/ISSUE_TEMPLATE/` and carry on with what you can do.
- A pull request touches one side only. Changes to root files (this file, `docs/`, `.github/`, license files) go in their own pull request.
- The app depends on a tagged release of the gem, never on the gem's working copy. See `docs/repository-layout.md`.

## Choosing an Issue

- Work only on Issues labeled for your side: `adjudicator` or `web`. Root files are labeled `repo`.
- Take an Issue only when every Issue listed under its "Needs" heading, and in GitHub's "blocked by" list, is closed.
- Never work on `decision` Issues. People settle those in planning.
- Leave `blocked` Issues alone until the release they wait for exists.
- Start with the lowest-numbered ready Issue in the current milestone.

## Shared rules

- **Ruby** is pinned in the root `.ruby-version` for both sides. Don't add a `.ruby-version` inside either folder. The upgrade policy is in `docs/architecture.md`.
- **Test first, with RSpec**, on both sides.
- **The name.** "Trucebearer" is always one word. Never give anything (a class, a file, a branch, a gem, a label) a name that contains or echoes "Diplomacy" or "Dip".
- **No copied rules text.** Never paste text from the game's rulebook or from the DATC (Diplomacy Adjudicator Test Cases) document into code, comments, tests, fixtures or docs. Explain things in your own words and cite the section number.
- **No copied code.** Other open-source engines may be read as references only. Don't copy or translate their code.
- **License.** Each folder has its own `LICENSE`: `web/` and `adjudicator/` are AGPL-3.0-or-later (the web app with an additional term in `web/NOTICE`), `assets/` and `docs/` are CC BY-SA 4.0, and a future native-shell folder will be MPL-2.0. See `NOTICE` for the map. Use of the name and logo follows `TRADEMARKS.md`.
- **Fewest moving parts.** Prefer the Ruby standard library and Rails defaults. Adding a dependency needs a reason in the pull request.

## Where decisions live

- `docs/architecture.md`: the technical decisions both sides build on, and the boundary between the gem and the app.
- `docs/repository-layout.md`: how this repository is organized and how work moves between the two sides.

If something you find contradicts a decision there, say so in the Issue or pull request. Don't quietly work around it.

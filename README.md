# Trucebearer

A mobile-first web app for a group playing the board game Diplomacy around a physical board. Each player enters secret orders on their own phone, the app adjudicates the turn and shows the results as text, and the game is saved so the group can pick up where it left off next time.

Status: planning. There is no working code yet.

## What's here

| Folder | What it is |
|---|---|
| `adjudicator/` | `trucebearer-adjudicator`, the rules engine, as a plain Ruby gem |
| `web/` | The Rails app |
| `docs/` | Architecture and repository layout |

The two folders are separate projects. The app depends on tagged releases of the gem. See `docs/repository-layout.md`.

## Licence

The code is licensed under the GNU Affero General Public License, version 3 or later (`LICENSE`). The name and logo are not covered by that licence; see `TRADEMARKS.md`.

---

Trucebearer is an independent, unofficial companion for playing the board game Diplomacy. Diplomacy® is a registered trademark of Hasbro, Inc. Trucebearer is not affiliated with, sponsored or endorsed by Hasbro, Avalon Hill or Renegade Game Studios. Please support the game by buying a copy.

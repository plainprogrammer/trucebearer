# Trucebearer™

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

Trucebearer is free software, and as much of it as possible is copyleft. Each folder carries its own `LICENSE`:

| Part | Licence |
|---|---|
| `web/` (the app) | AGPL-3.0-or-later, plus a requirement that modified versions say so in their interface (`web/NOTICE`) |
| `adjudicator/` (the gem) | AGPL-3.0-or-later |
| Native app shells (when they exist) | MPL-2.0 |
| `assets/` and `docs/` | CC BY-SA 4.0 |

You may run Trucebearer under its name and logo, modified or not, commercially or not, as long as you disclose modifications and don't present yourself as the official project. See `TRADEMARKS.md`.

Contributions are welcome and need no paperwork; see `CONTRIBUTING.md`.

---

Trucebearer is an independent, unofficial companion for playing the board game Diplomacy. Diplomacy® is a registered trademark of Hasbro, Inc. Trucebearer is not affiliated with, sponsored or endorsed by Hasbro, Avalon Hill or Renegade Game Studios. Please support the game by buying a copy.

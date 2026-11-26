# trucebearer-adjudicator: instructions for agents

You are working on the rules engine. It is a plain Ruby gem. It takes a position and a set of orders and returns the outcome of each order and the next position. Read the root `AGENTS.md` too; its shared rules apply here.

## The boundary

- **The gem knows:** maps as data, powers, provinces, coasts, units, order types, checking a single order against a position, adjudicating a full set of orders for a phase, retreat options, adjustment counts, and the resulting position.
- **The gem does not know:** games, seats, accounts, hosts, clocks, persistence, HTTP, or how anything is displayed.
- **No Rails.** Don't depend on Rails, ActiveSupport or anything in `web/`. Prefer the standard library. A runtime dependency needs an Issue that explains why first.
- What crosses the boundary is the gem's value objects: immutable `Data` classes with a documented hash form (`to_h` and `from_h`). Anything the app stores carries a `format` version, so any phase can be replayed. `docs/interface.md` is the contract with the app.

## Names

- Gem: `trucebearer-adjudicator`. Module: `Trucebearer::Adjudicator`. Require path: `trucebearer/adjudicator`.
- Code lives under `lib/trucebearer/adjudicator/`.

## Layout

| Path | Holds |
|---|---|
| `lib/trucebearer/adjudicator/` | The engine |
| `data/maps/` | Map definitions as data files: provinces, coasts, adjacencies, supply centers, home centers. The classic map comes first. Maps are never code |
| `spec/` | Unit specs |
| `spec/datc/` | DATC scenarios encoded as original, data-driven fixtures |
| `docs/interface.md` | The public interface the app relies on |
| `docs/ruleset.md` | Every rules choice the engine makes, with the DATC section that decides it |
| `CHANGELOG.md` | Changes since the last release, under "Unreleased" |
| `bin/` | Development and release scripts |

The gem skeleton (gemspec, Gemfile, Rakefile, version file) has not been written yet. Write it by hand to fit this layout. Don't run `bundle gem` over the folder.

## How to work

1. Pick up Issues labeled `adjudicator`. A request Issue gives example input and expected output. Turn that example into your first failing spec.
2. Write the test first. For rules behavior, the DATC scenario is the test.
3. **DATC fixtures** are written by hand from the scenario's position and expected result. Name each one by its DATC section number (for example `6.A.1`). Never copy the document's prose or commentary, not even in a comment.
4. Where the DATC leaves a choice open, record the option you chose and why in `docs/ruleset.md`.
5. The algorithm follows Kruijswijk's approach in "The Math of Adjudication": decision-based resolution with explicit handling of paradoxes. This choice is proposed, not final; raise it in an Issue if it doesn't hold up.

## Changing the interface

Anything in `docs/interface.md` is a promise to the app.

- If a pull request changes it, update `docs/interface.md`, add an entry under "Changed" in `CHANGELOG.md`, and open an Issue with the "Interface change" template so the app side knows what to do at the next upgrade.
- Additions go under "Added". They don't need an Issue for the app.

## Releases

The app uses tagged releases only, so it sees nothing until a release exists.

- Before 1.0, any minor version (0.x.0) may change the interface. Patch versions (0.x.y) never do.
- A release bumps the version, moves the "Unreleased" entries in `CHANGELOG.md` under the new version, commits, and tags `adjudicator-vX.Y.Z`. That will be a script in `bin/`. Until the script exists, do these steps by hand in that order.
- Don't publish to RubyGems. The name stays off public registries until it is final.

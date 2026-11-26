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
| `bin/` | Development and release scripts. `bin/release_tools/` is the release script's own code; it is not gem code and never ships |

The gem skeleton was written by hand to fit this layout. It holds the gemspec, `Gemfile`, `Gemfile.lock`, `Rakefile`, `.rspec`, `.gitignore`, the entry point `lib/trucebearer/adjudicator.rb` with its `version.rb`, and `spec/spec_helper.rb`. Don't run `bundle gem` over the folder.

Run the specs with `bundle exec rspec`; `bundle exec rake` does the same. Development dependencies are `rspec` and `rake` only, and they go in the `Gemfile`, not the gemspec, so the gem has no runtime dependencies. Commit `Gemfile.lock`. When the version changes, regenerate it with `bundle lock --local` (`bin/release` does this for you; run `bundle install` if a gem is missing locally). The gemspec reads the Ruby version from the root `.ruby-version` and refuses `gem push` to any real host.

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
- Release with `bin/release major|minor|patch|X.Y.Z`. It bumps the version, moves the "Unreleased" entries in `CHANGELOG.md` under `## X.Y.Z (date)` and leaves a fresh empty "Unreleased", regenerates `Gemfile.lock`, commits "Release adjudicator-vX.Y.Z", and creates the tag `adjudicator-vX.Y.Z`.
- It refuses to run when the working tree has any uncommitted change anywhere in the repository (a dry run is refused too), when "Unreleased" has no entries, or when the tag already exists. It warns when you are not on `main`.
- `bin/release --dry-run minor` prints the plan and writes nothing. Run it first.
- It never pushes. It prints the `git push --atomic` command; you run it after checking the commit.
- Don't publish to RubyGems. The name stays off public registries until it is final.

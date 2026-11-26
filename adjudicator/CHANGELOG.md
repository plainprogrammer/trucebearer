# Changelog

All notable changes to `trucebearer-adjudicator` are recorded here. Versions follow semantic versioning. Before 1.0, a minor version may change the public interface; a patch version never does.

Releases are git tags named `adjudicator-vX.Y.Z`.

## Unreleased

### Added

- The gem skeleton: gemspec, Gemfile, Rakefile, `Trucebearer::Adjudicator::VERSION` (`0.0.0`) and RSpec with a first passing spec. The gem has no runtime dependencies. (#6)
- `docs/interface.md` now defines the movement-phase interface. It covers the classic map and its queries; the value objects and their hash form (`format` 1); checking one order; listing a unit's legal orders; adjudicating a movement phase; and the `InvalidInput` error. Retreats and adjustments are placeholders until 0.3. (#5)
- `docs/ruleset.md` records the DATC v3.4 options the interface relies on, and where it departs from the preferred results. (#5)
- `docs/reference/datc-v3.4.html`, an unmodified copy of the DATC v3.4, so the section numbers cited in fixtures and `docs/ruleset.md` can be checked. It is for reading only and is not packaged in the gem. (#58)
- The classic map as a data file, `data/maps/classic.yml` (75 provinces, 34 supply centers, 22 home centers, army and fleet adjacency with split coasts, and the 1901 starting units), with `TA::Map.classic` and its queries, `TA::Location` and `TA::InvalidInput`. `Map#starting_position` arrives with #10; until then the starting units are available through an internal reader. (#9)

### Changed

### Fixed

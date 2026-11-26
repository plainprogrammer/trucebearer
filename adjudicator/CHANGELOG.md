# Changelog

All notable changes to `trucebearer-adjudicator` are recorded here. Versions follow semantic versioning. Before 1.0, a minor version may change the public interface; a patch version never does.

Releases are git tags named `adjudicator-vX.Y.Z`.

## Unreleased

### Added

- The gem skeleton: gemspec, Gemfile, Rakefile, `Trucebearer::Adjudicator::VERSION` (`0.0.0`) and RSpec with a first passing spec. The gem has no runtime dependencies. (#6)
- `docs/interface.md` now defines the movement-phase interface. It covers the classic map and its queries; the value objects and their hash form (`format` 1); checking one order; listing a unit's legal orders; adjudicating a movement phase; and the `InvalidInput` error. Retreats and adjustments are placeholders until 0.3. (#5)
- `docs/ruleset.md` records the DATC v3.4 options the interface relies on, and where it departs from the preferred results. (#5)
- `bin/release` releases the gem in one command: it bumps the version, moves the "Unreleased" entries under the new version, regenerates `Gemfile.lock`, commits and tags `adjudicator-vX.Y.Z`. It never pushes or publishes, and `--dry-run` shows the plan. (#8)
- `docs/reference/datc-v3.4.html`, an unmodified copy of the DATC v3.4, so the section numbers cited in fixtures and `docs/ruleset.md` can be checked. It is for reading only and is not packaged in the gem. (#58)
- The classic map as a data file, `data/maps/classic.yml` (75 provinces, 34 supply centers, 22 home centers, army and fleet adjacency with split coasts, and the 1901 starting units), with `TA::Map.classic` and its queries, `TA::Location` and `TA::InvalidInput`. (#9)
- The value objects of `docs/interface.md`: `TA::Unit`, `TA::DislodgedUnit`, `TA::Position`, the `TA::Order` module with `TA::Order.from_h`, and the six order classes `Hold`, `Move`, `MoveViaConvoy`, `SupportHold`, `SupportMove` and `Convoy`. Each is an immutable `Data` class with `to_h` and `from_h`, validated against the classic map, with list fields in canonical order; positions and orders carry `format` 1. `Map#starting_position` returns the spring 1901 position, built from the map data. `TA::Outcome` and `TA::Adjudication` arrive with #14. (#10)
- Value objects keep their guarantees through `Marshal`. A `Marshal.dump` and `Marshal.load` round trip of `TA::Location`, `TA::Unit`, `TA::DislodgedUnit`, `TA::Position` and the six orders returns an equal, deeply frozen object (before, a position's `units` and other lists came back unfrozen), and a payload in the form `Marshal.dump` writes, edited to describe an impossible object, raises `TA::InvalidInput` on load. `Marshal` now writes the hash form and reads it back through `from_h`; `to_h`, `from_h` and validation are unchanged. A payload built by hand in Ruby's plain struct format still skips the checks, as no Ruby code can stop that. (#77)
- `TA::CheckResult` and `TA.check(position, order)`: checking one movement order against a position, with the 17 rejection reasons and the precedence of `docs/interface.md`. A legal order has no reasons; an illegal one has exactly one. The DATC cases about legality (those of 6.A and 6.B, and 6.D.31, 6.D.34 and 6.G.19) are fixtures in `spec/datc/`, named by section number. `TA::CheckResult` keeps its guarantees through `Marshal`, like the other value objects. The helpers `legal_orders` (#12) will share are internal. (#11)

### Changed

- `docs/interface.md`: the "Impossible objects" list now names two more cases that raise `TA::InvalidInput`: the same province twice in `standoffs`, and two dislodged units in one province. No release carried the old list. (#10)

### Fixed

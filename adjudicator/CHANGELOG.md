# Changelog

All notable changes to `trucebearer-adjudicator` are recorded here. Versions follow semantic versioning. Before 1.0, a minor version may change the public interface; a patch version never does.

Releases are git tags named `adjudicator-vX.Y.Z`.

## Unreleased

### Added

- `docs/interface.md` now defines the movement-phase interface. It covers the classic map and its queries; the value objects and their hash form (`format` 1); checking one order; listing a unit's legal orders; adjudicating a movement phase; and the `InvalidInput` error. Retreats and adjustments are placeholders until 0.3. (#5)
- `docs/ruleset.md` records the DATC v3.4 options the interface relies on, and where it departs from the preferred results. (#5)

### Changed

### Fixed

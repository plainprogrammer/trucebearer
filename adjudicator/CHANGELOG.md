# Changelog

All notable changes to `trucebearer-adjudicator` are recorded here. Versions follow semantic versioning. Before 1.0, a minor version may change the public interface; a patch version never does.

Releases are git tags named `adjudicator-vX.Y.Z`.

## Unreleased

### Added

### Changed

### Fixed

## 0.2.0 (2026-11-26)

### Added

- `TA::Outcome`, `TA::Adjudication` and `TA.adjudicate(position, orders)`: adjudicating a movement phase, following the decision-based approach of Kruijswijk's "The Math of Adjudication". Every order gets an outcome; a unit with no legal order holds and can be supported; each dislodged unit records the province its attacker came from; and `position` is the retreat-phase snapshot of `docs/interface.md`. The DATC cases of 6.A to 6.E that need no convoy, and 6.F.1, are fixtures in `spec/datc/` with their results; every result is also checked against the DATC's conditions on seeded random boards. `TA.adjudicate` raises `TA::InvalidInput` for an argument of the wrong class, a position that isn't in the movement phase, and one power giving two orders that name the same province; a broken rule is an outcome, never an error. `TA::Outcome` and `TA::Adjudication` keep their guarantees through `Marshal`, like the other value objects. `docs/interface.md` now names the impossible `TA::Outcome` and `TA::Adjudication`. (#14)
- Convoys in `TA.adjudicate`: a move that goes by convoy needs a route of the fleets that convoy it and fails only when every route is broken; a convoy order is `:given`, `:disrupted` or `:unmatched`; a unit dislodged by a convoyed army has `by_convoy: true`; a swap by convoy and a circle that holds a convoyed army move; and `paradox` is set when the orders hold a convoy paradox, whose outcomes stay unspecified until #39. The DATC cases of 6.B to 6.G that need a convoy are fixtures with their results (126 adjudicated fixtures in all), the twelve paradox cases wait for #39 as fixtures that check the flag and a valid position, and a slow reference written in the specs, with seeded random boards that hold convoys, confirms them. (#15)

## 0.1.0 (2026-11-26)

### Added

- The gem skeleton: gemspec, Gemfile, Rakefile, `Trucebearer::Adjudicator::VERSION` (`0.0.0`) and RSpec with a first passing spec. The gem has no runtime dependencies. (#6)
- `docs/interface.md` now defines the movement-phase interface. It covers the classic map and its queries; the value objects and their hash form (`format` 1); checking one order; listing a unit's legal orders; and the `InvalidInput` error. Adjudicating a movement phase is documented for 0.2.0, and retreats and adjustments are placeholders until 0.3. (#5)
- `docs/ruleset.md` records the DATC v3.4 options the interface relies on, and where it departs from the preferred results. (#5)
- `bin/release` releases the gem in one command: it bumps the version, moves the "Unreleased" entries under the new version, regenerates `Gemfile.lock`, commits and tags `adjudicator-vX.Y.Z`. It never pushes or publishes, and `--dry-run` shows the plan. (#8)
- `docs/reference/datc-v3.4.html`, an unmodified copy of the DATC v3.4, so the section numbers cited in fixtures and `docs/ruleset.md` can be checked. It is for reading only and is not packaged in the gem. (#58)
- The classic map as a data file, `data/maps/classic.yml` (75 provinces, 34 supply centers, 22 home centers, army and fleet adjacency with split coasts, and the 1901 starting units), with `TA::Map.classic` and its queries, `TA::Location` and `TA::InvalidInput`. (#9)
- The value objects of `docs/interface.md`: `TA::Unit`, `TA::DislodgedUnit`, `TA::Position`, the `TA::Order` module with `TA::Order.from_h`, and the six order classes `Hold`, `Move`, `MoveViaConvoy`, `SupportHold`, `SupportMove` and `Convoy`. Each is an immutable `Data` class with `to_h` and `from_h`, validated against the classic map, with list fields in canonical order; positions and orders carry `format` 1. `Map#starting_position` returns the spring 1901 position, built from the map data. `TA::Outcome` and `TA::Adjudication` arrive with #14. (#10)
- Value objects keep their guarantees through `Marshal`. A `Marshal.dump` and `Marshal.load` round trip of `TA::Location`, `TA::Unit`, `TA::DislodgedUnit`, `TA::Position` and the six orders returns an equal, deeply frozen object (before, a position's `units` and other lists came back unfrozen), and a payload in the form `Marshal.dump` writes, edited to describe an impossible object, raises `TA::InvalidInput` on load. `Marshal` now writes the hash form and reads it back through `from_h`; `to_h`, `from_h` and validation are unchanged. A payload built by hand in Ruby's plain struct format still skips the checks, as no Ruby code can stop that. (#77)
- `TA::CheckResult` and `TA.check(position, order)`: checking one movement order against a position, with the 17 rejection reasons and the precedence of `docs/interface.md`. A legal order has no reasons; an illegal one has exactly one. The DATC cases about legality (the legality cases of 6.A and 6.B, and 6.D.31, 6.D.34 and 6.G.19) are fixtures in `spec/datc/`, named by section number. `TA::CheckResult` keeps its guarantees through `Marshal`, like the other value objects. The helpers `legal_orders` (#12) will share are internal. (#11)
- `TA.legal_orders(position, unit)`: every legal order for one unit, in the list order of `docs/interface.md` (hold, moves by destination and coast, moves via convoy, supports to hold, supports to move, convoys). It agrees with `TA.check` exactly, includes legal but pointless orders, and is empty for a position that isn't in a movement phase or a unit that isn't on the board. It builds only the orders a unit could possibly give and asks the checker about each, so it is fast enough to call for every unit on each page load. (#12)

### Changed

- `docs/interface.md`: the "Impossible objects" list now names two more cases that raise `TA::InvalidInput`: the same province twice in `standoffs`, and two dislodged units in one province. No release carried the old list. (#10)
- `docs/interface.md` now says in which release each part arrives, so that it matches what 0.1.0 ships. `TA::Outcome` and `TA::Adjudication` are marked as arriving in 0.2.0, with a matching row in the "Releases" table, and so are the rules that mention them (the `format` note, the canonical order of `outcomes`, and the two adjudication errors). The `Order::Move` text no longer points at adjudication for how an army moves by convoy, and the example error message for a coast in a province field now matches the gem. The "Errors" section now lists the map-query and argument-class errors, and says that `new` with a missing or unknown keyword raises `ArgumentError`. No release carried the old text, so this needs no Issue for the app. (#13)

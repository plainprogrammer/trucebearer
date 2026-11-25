# Public interface

This file is the contract between the gem and anything that uses it, including the Trucebearer web app. Whatever is described here, callers may rely on. Whatever isn't described here is internal and may change in any release.

Nothing is defined yet. The sections below are what the interface will cover.

## Shape

A caller passes in a **position** and a set of **orders**. It gets back the **outcome** of each order and the **next position**. All of these are plain data (hashes, arrays, strings, integers) that can be serialized, stored and replayed.

## Sections to fill in

- **Maps.** How a caller loads a map and what it can ask of one.
- **Position.** Season, year, phase, units and their locations, supply center ownership, dislodged units.
- **Orders.** How each order type is expressed for movement, retreat and adjustment phases.
- **Checking an order.** Checking a single order against a position before adjudication, with a reason when it is rejected.
- **Adjudication.** Input, output, and the outcome values for each order.
- **Retreats and adjustments.** Retreat options for each dislodged unit, and build and disband counts.
- **Errors.** What happens when the input itself is malformed, as opposed to an order that fails.

## Change rules

See `../AGENTS.md`, under "Changing the interface" and "Releases".

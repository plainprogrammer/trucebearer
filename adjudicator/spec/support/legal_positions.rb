# frozen_string_literal: true

require "trucebearer/adjudicator"
require_relative "board"

# The positions the legal-orders specs share, and the whole candidate space of a unit.
# Positions are built the way docs/interface.md builds its examples where it has one.
module LegalPositions
  module_function

  def start = TA::Map.classic.starting_position

  # French fleets in the Mid-Atlantic and the Gulf of Lyon (the interface's `at_sea`).
  def at_sea = Board.position(Board.unit(:france, :fleet, "mao"), Board.unit(:france, :fleet, "gol"))

  # England's army in London and fleet in the North Sea (the interface's `ln`).
  def ln = Board.position(Board.unit(:england, :army, "lon"), Board.unit(:england, :fleet, "nth"))

  # A fleet that a one-fleet chain bypasses (the shape of 6.G.19).
  def bypassed
    Board.position(Board.unit(:france, :army, "mar"), Board.unit(:france, :fleet, "wes"),
                   Board.unit(:italy, :fleet, "gol"), Board.unit(:italy, :army, "spa"))
  end

  # The only chain is two fleets, of two powers.
  def two_fleet_chain
    Board.position(Board.unit(:england, :army, "lon"), Board.unit(:england, :fleet, "eng"),
                   Board.unit(:france, :fleet, "mao"))
  end

  # A sea fleet that touches a chain fleet but neither end (the shape of 6.F.12).
  def no_chain_through
    Board.position(Board.unit(:england, :army, "lon"), Board.unit(:england, :fleet, "eng"),
                   Board.unit(:england, :fleet, "iri"), Board.unit(:england, :fleet, "nth"))
  end

  # Fleets on bul/ec, spa/nc and stp/nc, with neighbors. A position holds one unit per
  # province, so the six split coasts need two positions.
  def north_coasts
    Board.position(
      Board.unit(:turkey, :fleet, "bul/ec"), Board.unit(:turkey, :army, "con"), Board.unit(:russia, :fleet, "bla"),
      Board.unit(:austria, :army, "rum"), Board.unit(:france, :fleet, "spa/nc"), Board.unit(:france, :army, "gas"),
      Board.unit(:france, :fleet, "mao"), Board.unit(:italy, :army, "por"), Board.unit(:russia, :fleet, "stp/nc"),
      Board.unit(:england, :fleet, "bar"), Board.unit(:germany, :army, "nwy")
    )
  end

  # Fleets on bul/sc, spa/sc and stp/sc, with neighbors.
  def south_coasts
    Board.position(
      Board.unit(:turkey, :fleet, "bul/sc"), Board.unit(:turkey, :army, "gre"), Board.unit(:italy, :fleet, "aeg"),
      Board.unit(:austria, :army, "ser"), Board.unit(:france, :fleet, "spa/sc"), Board.unit(:france, :army, "mar"),
      Board.unit(:france, :fleet, "gol"), Board.unit(:italy, :fleet, "wes"), Board.unit(:russia, :fleet, "stp/sc"),
      Board.unit(:russia, :fleet, "bot"), Board.unit(:russia, :army, "fin"), Board.unit(:germany, :army, "lvn")
    )
  end
end

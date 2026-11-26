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

  # A fleet in each of the 19 sea provinces and an army in each of the first 20 coastal
  # provinces by identifier, the seven powers dealt in turn in identifier order.
  def stress
    powers = Board.powers.sort_by(&:to_s)
    seas = Board.sea.sort_by(&:to_s)
    coastal = Board.map.provinces.select { |province| province.type == :coastal }.map(&:id).sort_by(&:to_s).first(20)
    units = seas.each_with_index.map { |id, i| Board.unit(powers[i % 7], :fleet, id.to_s) } +
            coastal.each_with_index.map { |id, i| Board.unit(powers[i % 7], :army, id.to_s) }
    Board.position(*units)
  end

  # [seed, armies, fleets at sea, fleets on a coast]. The first board has 34 units and is
  # the mid-game board of the speed target.
  RANDOM_BOARDS = [[1, 22, 8, 4], [2, 18, 6, 4], [3, 12, 3, 3], [4, 8, 2, 2], [5, 3, 1, 1], [6, 3, 2, 0]].freeze

  def random_board(seed, armies, sea_fleets, coast_fleets)
    rng = Random.new(seed)
    powers = Board.powers.sort_by(&:to_s)
    seas = Board.sea.sort_by(&:to_s).shuffle(random: rng).first(sea_fleets)
    coastal = Board.map.provinces.select { |province| province.type == :coastal }.sort_by { _1.id.to_s }
    split, plain = coastal.partition { |province| !province.coasts.empty? }
    # The first coast fleet always stands on a split coast, so the boards exercise them.
    on_coast = split.shuffle(random: rng).first(coast_fleets.clamp(0, 1)) +
               plain.shuffle(random: rng).first([coast_fleets - 1, 0].max)
    land = (Board.army_provinces - on_coast.map(&:id)).sort_by(&:to_s).shuffle(random: rng).first(armies)
    coast_places = on_coast.map do |province|
      province.coasts.empty? ? province.id.to_s : "#{province.id}/#{province.coasts.sort.sample(random: rng)}"
    end
    units = (seas.map(&:to_s) + coast_places).map { |place| [:fleet, place] } + land.map { |id| [:army, id.to_s] }
    Board.position(*units.each_with_index.map { |(type, place), i| Board.unit(powers[i % 7], type, place) })
  end

  def random_boards = RANDOM_BOARDS.map { |seed, *counts| random_board(seed, *counts) }

  # The sampled positions of AC-5.3, by name.
  def samples
    { "the starting position" => start, "fleets on the north coasts" => north_coasts,
      "fleets on the south coasts" => south_coasts, "the interface's at_sea" => at_sea, "ln" => ln,
      "a fleet bypassed by a shorter chain" => bypassed, "a chain of two fleets" => two_fleet_chain,
      "a fleet with no chain through it" => no_chain_through, "the stress position" => stress }
      .merge(random_boards.each_with_index.to_h { |position, i| ["random board #{i + 1}", position] })
  end

  # Every order the six classes can form for the unit's owner and province, with every
  # province and every location: 11,482 orders. Built fresh each time.
  def candidates(unit)
    power = unit.power
    at = unit.location.province
    provinces = Board.provinces
    [O::Hold.new(power: power, at: at)] +
      Board.locations.map { |to| O::Move.new(power: power, at: at, destination: to) } +
      provinces.map { |to| O::MoveViaConvoy.new(power: power, at: at, to: to) } +
      provinces.map { |target| O::SupportHold.new(power: power, at: at, target: target) } +
      provinces.product(provinces).map { |from, to| O::SupportMove.new(power: power, at: at, from: from, to: to) } +
      provinces.product(provinces).map { |from, to| O::Convoy.new(power: power, at: at, from: from, to: to) }
  end
end

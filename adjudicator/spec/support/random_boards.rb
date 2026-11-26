# frozen_string_literal: true

require_relative "adjudicating"

# Random movement positions and orders for the adjudication specs (spec 014, Story 12). Every
# board is made from a seeded Random, so a failure is reproducible. A board is a plain one
# (units and orders chosen at random) or is built around a hard shape: a circle of moves, a
# head-to-head battle, a supporter attacked from the province its support aims at, or a unit
# attacked from three sides. Shaped boards are then filled with more units and orders.
#
# No board holds a convoy order, a move via convoy, or a move that only a convoy could make.
module RandomBoards
  MAP = TA::Map.classic
  POWERS = MAP.powers.map(&:id).freeze
  LAND = MAP.provinces.reject { |province| province.type == :sea }.map(&:id).freeze
  NEIGHBORS = LAND.to_h do |from|
    [from, LAND.select { |to| MAP.adjacent?(:army, L.new(province: from), L.new(province: to)) }.freeze]
  end.freeze
  FLEET_PLACES = MAP.provinces.reject { |province| province.type == :inland }.flat_map do |province|
    province.coasts.empty? ? [[province.id, nil]] : province.coasts.map { |coast| [province.id, coast] }
  end.freeze
  SHAPES = %i[plain circle pure_circle head_to_head supporter_attacked beleaguered].freeze
  CLASS_WEIGHTS = { O::Hold => 1, O::Move => 4, O::SupportHold => 1, O::SupportMove => 3 }.freeze

  module_function

  # [position, orders] for the given shape. `size` is the number of units to fill the board to
  # (the shaped part counts); by default a plain board has 2 to 34 units, a shaped one a few more.
  def board(rng, shape, size: nil)
    units = {}
    orders = []
    case shape
    when :circle, :pure_circle then circle(rng, units, orders)
    when :head_to_head then head_to_head(rng, units, orders)
    when :supporter_attacked then supporter_attacked(rng, units, orders)
    when :beleaguered then beleaguered(rng, units, orders)
    end
    fill(rng, units, size || (shape == :plain ? rng.rand(2..34) : units.size + rng.rand(0..14))) unless shape == :pure_circle
    position = Board.position(*units.values)
    [position, orders + chosen_orders(rng, position, units.values - shaped_units(units, orders))]
  end

  def army(rng, units, province, power = POWERS.sample(random: rng))
    units[province] = TA::Unit.new(power: power, type: :army, location: L.new(province: province))
  end

  def circle(rng, units, orders)
    path = nil
    200.times do
      candidate = [LAND.sample(random: rng)]
      rng.rand(3..5).pred.times do
        options = NEIGHBORS[candidate.last] - candidate
        break if options.empty?

        candidate << options.sample(random: rng)
      end
      path = candidate if candidate.size >= 3 && NEIGHBORS[candidate.last].include?(candidate.first)
      break if path
    end
    return unless path

    path.each_with_index do |province, index|
      unit = army(rng, units, province)
      orders << O::Move.new(power: unit.power, at: province, destination: L.new(province: path[(index + 1) % path.size]))
    end
  end

  def head_to_head(rng, units, orders)
    a = LAND.sample(random: rng)
    b = NEIGHBORS[a].sample(random: rng)
    [[a, b], [b, a]].each do |from, to|
      unit = army(rng, units, from)
      orders << O::Move.new(power: unit.power, at: from, destination: L.new(province: to))
    end
    [[a, b], [b, a]].each do |from, to|
      NEIGHBORS[to].reject { |c| units.key?(c) }.sample(rng.rand(0..2), random: rng).each do |supporter|
        unit = army(rng, units, supporter)
        orders << O::SupportMove.new(power: unit.power, at: supporter, from: from, to: to)
      end
    end
  end

  def supporter_attacked(rng, units, orders)
    y = LAND.select { |province| NEIGHBORS[province].size >= 2 }.sample(random: rng)
    s, x = NEIGHBORS[y].sample(2, random: rng)
    mover = army(rng, units, x)
    supporter = army(rng, units, s)
    attacker = army(rng, units, y)
    orders << O::Move.new(power: mover.power, at: x, destination: L.new(province: y))
    orders << O::SupportMove.new(power: supporter.power, at: s, from: x, to: y)
    orders << O::Move.new(power: attacker.power, at: y, destination: L.new(province: s))
  end

  def beleaguered(rng, units, orders)
    target = LAND.select { |province| NEIGHBORS[province].size >= 3 }.sample(random: rng)
    holder = army(rng, units, target)
    orders << O::Hold.new(power: holder.power, at: target)
    NEIGHBORS[target].sample(3, random: rng).each do |from|
      unit = army(rng, units, from)
      orders << O::Move.new(power: unit.power, at: from, destination: L.new(province: target))
    end
  end

  # More units on free provinces (armies and fleets, on any coast), up to 34 in all.
  def fill(rng, units, size)
    while units.size < [size, 34].min
      if rng.rand < 0.5
        army(rng, units, (LAND - units.keys).sample(random: rng))
      else
        province, coast = (FLEET_PLACES.reject { |(id, _)| units.key?(id) }).sample(random: rng)
        units[province] = TA::Unit.new(power: POWERS.sample(random: rng), type: :fleet, location: L.new(province: province, coast: coast))
      end
    end
  end

  # The units that already have an order from the shape.
  def shaped_units(units, orders) = orders.filter_map { |order| units[order.at] }

  # A random legal order for each of these units (a tenth are left without), and now and then
  # a hold from another power for a unit.
  def chosen_orders(rng, position, units)
    given = units.filter_map { |unit| choose(rng, position, unit) unless rng.rand < 0.1 }
    foreign = units.sample(rng.rand(0..2), random: rng).map do |unit|
      O::Hold.new(power: (POWERS - [unit.power]).sample(random: rng), at: unit.location.province)
    end
    given + foreign.reject { |order| given.any? { |other| other.power == order.power && other.at == order.at } }
  end

  def choose(rng, position, unit)
    legal = TA.legal_orders(position, unit).reject do |order|
      O::Convoy === order || O::MoveViaConvoy === order ||
        (O::Move === order && unit.type == :army && !TA.const_get(:Reach).reaches?(unit, order.destination.province))
    end
    weighted = CLASS_WEIGHTS.flat_map { |klass, weight| [klass] * weight }.sample(random: rng)
    pool = legal.select { |order| weighted === order }
    (pool.empty? ? legal : pool).sample(random: rng)
  end

  # ---- what a board holds, read from its orders ----

  def circle?(orders)
    moves = orders.grep(O::Move).to_h { |order| [order.at, order.destination.province] }
    moves.keys.any? do |start|
      path = [start]
      path << moves[path.last] until moves[path.last].nil? || path.include?(moves[path.last])
      follower = moves[path.last]
      follower && path.include?(follower) && path.size - path.index(follower) >= 3
    end
  end

  def head_to_head?(orders)
    moves = orders.grep(O::Move).map { |order| [order.at, order.destination.province] }
    moves.any? { |from, to| moves.include?([to, from]) }
  end

  def supporter_attacked?(orders)
    orders.grep(O::SupportMove).any? do |support|
      orders.any? { |order| O::Move === order && order.at == support.to && order.destination.province == support.at }
    end
  end

  def beleaguered?(position, orders)
    moves = orders.grep(O::Move)
    moves.group_by { |order| order.destination.province }.any? do |province, attackers|
      attackers.size >= 3 && position.units.any? { |unit| unit.location.province == province } &&
        moves.none? { |order| order.at == province }
    end
  end
end

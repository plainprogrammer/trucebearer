# frozen_string_literal: true

require_relative "random_boards"

# Random movement positions and orders that hold convoys (spec 015, Story 8). Every board is
# made from a seeded Random. A board starts with an army, a chain of one to three fleets at sea
# and a destination across them, and then gets some of: an attack on a carrying fleet with
# supports, a unit on the destination that supports that attack (the shape of the simplest
# paradox), a unit moving the other way (a swap), and random units with random legal orders.
module RandomConvoyBoards
  REACH = TA.const_get(:Reach)
  COASTAL = REACH::COASTAL
  POWERS = RandomBoards::POWERS

  module_function

  # [position, orders]. `size` is the number of units, 3 to 34.
  def board(rng, size: rng.rand(4..12))
    units = {}
    orders = []
    from, path, to = chain(rng)
    army = place(units, rng, :army, from)
    orders << (REACH.reaches?(army, to) && rng.rand < 0.5 ? O::MoveViaConvoy.new(power: army.power, at: from, to: to) :
                                                             O::Move.new(power: army.power, at: from, destination: L.new(province: to)))
    path.each do |sea|
      fleet = place(units, rng, :fleet, sea, power: rng.rand < 0.6 ? army.power : nil)
      orders << O::Convoy.new(power: fleet.power, at: sea, from: from, to: to) unless rng.rand < 0.1
    end
    path += alternative(rng, units, orders, army, from, path, to) if path.size == 1 && rng.rand < 0.5
    2.times { attack_carrier(rng, units, orders, path, to) if rng.rand < 0.7 }
    if rng.rand < 0.25
      swap(rng, units, orders, from, to)
    elsif rng.rand < 0.8
      circle(rng, units, orders, from, to)
    end
    fill(rng, units, size)
    position = Board.position(*units.values)
    given = orders.map(&:at)
    [position, orders + random_orders(rng, position, units.values.reject { |unit| given.include?(unit.location.province) })]
  end

  def chain(rng)
    loop do
      from = COASTAL.sample(random: rng)
      first = REACH::SEA_TOUCHES.fetch(from).to_a.sample(random: rng)
      next unless first

      path = [first]
      rng.rand(0..2).times do
        options = (REACH::SEA_LINKS.fetch(path.last) - path).reject { |sea| REACH.touches?(sea, from) }
        break if options.empty?

        path << options.to_a.sample(random: rng)
      end
      ends = COASTAL.select { |to| to != from && REACH.touches?(path.last, to) && path[0...-1].none? { |sea| REACH.touches?(sea, to) } }
      return [from, path, ends.sample(random: rng)] unless ends.empty?
    end
  end

  # A second sea that touches both ends is a second route. Returns it in an array, or none.
  def alternative(rng, units, orders, army, from, path, to)
    seas = REACH::SEAS.select { |sea| !units.key?(sea) && !path.include?(sea) && REACH.touches?(sea, from) && REACH.touches?(sea, to) }
    return [] if seas.empty?

    sea = seas.sample(random: rng)
    fleet = place(units, rng, :fleet, sea, power: rng.rand < 0.6 ? army.power : nil)
    orders << O::Convoy.new(power: fleet.power, at: sea, from: from, to: to) unless rng.rand < 0.1
    [sea]
  end

  def place(units, rng, type, province, power: nil)
    coast = type == :fleet && !TA::Map.classic.coasts(province).empty? ? TA::Map.classic.coasts(province).sample(random: rng) : nil
    units[province] = TA::Unit.new(power: power || POWERS.sample(random: rng), type: type, location: L.new(province: province, coast: coast))
  end

  # A fleet next to a carrying sea moves into it, with supports; a fleet on the destination may
  # support that move, which the convoyed army then attacks.
  def attack_carrier(rng, units, orders, path, to)
    sea = path.sample(random: rng)
    starts = REACH::FLEET_STEPS.keys.select do |(province, coast)|
      !units.key?(province) && REACH::FLEET_STEPS[[province, coast]].any? { |(next_province, _)| next_province == sea }
    end
    return if starts.empty?

    province, coast = starts.sample(random: rng)
    attacker = units[province] = TA::Unit.new(power: POWERS.sample(random: rng), type: :fleet, location: L.new(province: province, coast: coast))
    orders << O::Move.new(power: attacker.power, at: province, destination: L.new(province: sea))
    supporters = REACH::FLEET_STEPS.keys.select do |(p, c)|
      !units.key?(p) && p != province && REACH::FLEET_STEPS[[p, c]].any? { |(n, _)| n == sea }
    end
    supporters.sample(rng.rand(0..2), random: rng).each do |(p, c)|
      next if units.key?(p)

      support = units[p] = TA::Unit.new(power: POWERS.sample(random: rng), type: :fleet, location: L.new(province: p, coast: c))
      orders << O::SupportMove.new(power: support.power, at: p, from: province, to: sea)
    end
    return if units.key?(to) || rng.rand < 0.4

    near = REACH::FLEET_STEPS.keys.select { |(p, _)| p == to }.select { |key| REACH::FLEET_STEPS[key].any? { |(n, _)| n == sea } }
    return if near.empty?

    _, coast = near.sample(random: rng)
    mine = units[to] = TA::Unit.new(power: POWERS.sample(random: rng), type: :fleet, location: L.new(province: to, coast: coast))
    orders << O::SupportMove.new(power: mine.power, at: to, from: province, to: sea)
  end

  # An army on the destination moves the other way.
  def swap(rng, units, orders, from, to)
    return if units.key?(to)

    other = place(units, rng, :army, to)
    orders << O::Move.new(power: other.power, at: to, destination: L.new(province: from))
  end

  # The convoyed army's destination holds an army that moves to a province next to both ends
  # on land, whose army moves to the convoyed army's province: a circle of three.
  def circle(rng, units, orders, from, to)
    return if units.key?(to)

    options = RandomBoards::LAND.select do |other|
      !units.key?(other) && RandomBoards::NEIGHBORS[to].include?(other) && RandomBoards::NEIGHBORS[other].include?(from)
    end
    return if options.empty?

    other = options.sample(random: rng)
    second = place(units, rng, :army, to)
    third = place(units, rng, :army, other)
    orders << O::Move.new(power: second.power, at: to, destination: L.new(province: other))
    orders << O::Move.new(power: third.power, at: other, destination: L.new(province: from))
  end

  def fill(rng, units, size)
    while units.size < [size, 34].min
      if rng.rand < 0.5
        province = (RandomBoards::LAND - units.keys).sample(random: rng)
        place(units, rng, :army, province)
      else
        province, = RandomBoards::FLEET_PLACES.reject { |(id, _)| units.key?(id) }.sample(random: rng)
        place(units, rng, :fleet, province)
      end
    end
  end

  def random_orders(rng, position, units)
    weights = { O::Hold => 1, O::Move => 3, O::MoveViaConvoy => 1, O::SupportHold => 1, O::SupportMove => 3, O::Convoy => 3 }
    units.filter_map do |unit|
      next if rng.rand < 0.1

      legal = TA.legal_orders(position, unit)
      klass = weights.flat_map { |k, w| [k] * w }.sample(random: rng)
      pool = legal.select { |order| klass === order }
      (pool.empty? ? legal : pool).sample(random: rng)
    end
  end
end

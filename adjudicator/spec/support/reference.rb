# frozen_string_literal: true

require_relative "board"

# A slow reference for the conditions of the DATC, written in the spec from the contract
# (docs/interface.md) and the DATC's section 5, and not from the resolver (spec 015, AC-8.2
# and AC-8.3). Given a position, orders and a choice of which moves succeed, it works out
# every other fact (routes, cuts, strengths, dislodgements) and says whether the choice is
# consistent with the conditions. It tries every choice for a small board, applies circular
# movement, and says the board holds a convoy paradox when no consistent choice is left, or
# more than one.
module Reference
  Entry = Data.define(:unit, :order) do
    def province = unit.location.province
    def power = unit.power
    def move? = order.is_a?(O::Move) || order.is_a?(O::MoveViaConvoy)
    def destination = order.is_a?(O::Move) ? order.destination.province : order.to
  end

  MAP = TA::Map.classic
  SEAS = MAP.provinces.select { |province| province.type == :sea }.map(&:id)

  module_function

  # One entry per unit: the owner's order when it passes checking, else a hold.
  def entries(position, orders)
    legal = orders.select { |order| TA.check(position, order).legal }.to_h { |order| [order.at, order] }
    position.units.map do |unit|
      Entry.new(unit: unit, order: legal[unit.location.province] || O::Hold.new(power: unit.power, at: unit.location.province))
    end
  end

  def by_land?(entry)
    MAP.adjacent?(:army, entry.unit.location, L.new(province: entry.destination))
  end

  # Does the move go by convoy? An army's move does when it is tagged, when the army can't walk
  # there, or when a fleet of its own power orders a matching convoy.
  def convoy?(entry, entries)
    return false unless entry.move? && entry.unit.type == :army
    return true if entry.order.is_a?(O::MoveViaConvoy) || !by_land?(entry)

    entries.any? { |other| carries?(other, entry) && other.power == entry.power }
  end

  def carries?(fleet, move)
    fleet.order.is_a?(O::Convoy) && fleet.order.from == move.province && fleet.order.to == move.destination
  end

  # Every fact that follows from `success` ({move entry => true/false}).
  def facts(entries, success)
    at = entries.to_h { |entry| [entry.province, entry] }
    moves = entries.select(&:move?)
    into = moves.group_by(&:destination)
    convoyed = moves.select { |move| convoy?(move, entries) }
    dislodged = entries.to_h do |entry|
      stays = !(entry.move? && success[entry])
      [entry, stays && (into[entry.province] || []).any? { |move| success[move] }]
    end
    route = moves.to_h do |move|
      next [move, true] unless convoyed.include?(move)

      seas = entries.select { |fleet| carries?(fleet, move) && !dislodged[fleet] }.map(&:province)
      [move, linked?(seas, move.province, move.destination)]
    end
    facts = { at: at, moves: moves, into: into, convoyed: convoyed, dislodged: dislodged, route: route, success: success }
    facts[:given] = entries.select { |entry| support?(entry) }.to_h { |entry| [entry, given?(entry, facts)] }
    facts
  end

  # A chain of the given seas from `from` to `to`: each next to the one before.
  def linked?(seas, from, to)
    touching = ->(sea, province) { MAP.province(province).type == :coastal && fleet_steps(sea).include?(province) }
    frontier = seas.select { |sea| touching.call(sea, from) }
    reached = frontier.dup
    until frontier.empty?
      sea = frontier.pop
      return true if touching.call(sea, to)

      (seas - reached).select { |next_sea| fleet_steps(sea).include?(next_sea) }.each do |next_sea|
        reached << next_sea
        frontier << next_sea
      end
    end
    false
  end

  def fleet_steps(province)
    @steps ||= {}
    @steps[province] ||= MAP.province(province).then do |p|
      places = p.coasts.empty? ? [L.new(province: province)] : p.coasts.map { |c| L.new(province: province, coast: c) }
      MAP.provinces.flat_map do |other|
        spots = other.coasts.empty? ? [L.new(province: other.id)] : other.coasts.map { |c| L.new(province: other.id, coast: c) }
        spots.select { |spot| places.any? { |place| MAP.adjacent?(:fleet, place, spot) } }.map { |spot| spot.province }
      end.uniq
    end
  end

  def support?(entry) = entry.order.is_a?(O::SupportHold) || entry.order.is_a?(O::SupportMove)

  def matched?(entry, at)
    case entry.order
    when O::SupportHold then !at[entry.order.target].move?
    when O::SupportMove then at[entry.order.from].move? && at[entry.order.from].destination == entry.order.to
    end
  end

  def cut?(support, facts)
    return true if facts[:dislodged][support]

    (facts[:into][support.province] || []).any? do |move|
      move.power != support.power && facts[:route][move] &&
        (support.order.is_a?(O::SupportHold) || move.province != support.order.to)
    end
  end

  def given?(support, facts) = matched?(support, facts[:at]) && !cut?(support, facts)

  def move_supports(move, facts, entries, except_power: nil)
    entries.count do |entry|
      entry.order.is_a?(O::SupportMove) && entry.order.from == move.province && entry.order.to == move.destination &&
        facts[:given][entry] && entry.power != except_power
    end
  end

  def head_to_head?(move, facts)
    other = facts[:at][move.destination]
    other&.move? && other.destination == move.province && !facts[:convoyed].include?(move) && !facts[:convoyed].include?(other)
  end

  def hold_strength(province, facts, entries)
    entry = facts[:at][province]
    return 0 unless entry
    return facts[:success][entry] ? 0 : 1 if entry.move?

    1 + entries.count { |other| other.order.is_a?(O::SupportHold) && other.order.target == province && facts[:given][other] }
  end

  def attack(move, facts, entries)
    return 0 unless facts[:route][move]

    other = facts[:at][move.destination]
    leaving = other&.move? && !head_to_head?(move, facts) && facts[:success][other]
    return 1 + move_supports(move, facts, entries) if other.nil? || leaving
    return 0 if other.power == move.power

    1 + move_supports(move, facts, entries, except_power: other.power)
  end

  def prevent(move, facts, entries)
    return 0 unless facts[:route][move]
    return 0 if head_to_head?(move, facts) && facts[:success][facts[:at][move.destination]]

    1 + move_supports(move, facts, entries)
  end

  # The success each move's strengths demand, given the facts.
  def demanded(move, facts, entries)
    strength = attack(move, facts, entries)
    other = facts[:at][move.destination]
    against = head_to_head?(move, facts) ? 1 + move_supports(other, facts, entries) : hold_strength(move.destination, facts, entries)
    rivals = (facts[:into][move.destination] - [move]).map { |rival| prevent(rival, facts, entries) }
    strength > against && rivals.all? { |rival| strength > rival }
  end

  def consistent?(entries, success)
    facts = facts(entries, success)
    facts[:moves].all? { |move| success[move] == demanded(move, facts, entries) }
  end

  # Circles of moves, read from the orders: each move into the province the next one leaves,
  # three or more of them, or two when one goes by convoy.
  def circles(entries)
    moves = entries.select(&:move?).to_h { |move| [move.province, move] }
    found = []
    moves.each_value do |start|
      path = [start]
      path << moves[path.last.destination] while moves[path.last.destination] && !path.include?(moves[path.last.destination])
      follower = moves[path.last.destination]
      next unless follower && path.include?(follower)

      circle = path[path.index(follower)..]
      convoyed = circle.any? { |move| convoy?(move, entries) }
      found << circle if (circle.size >= 3 || (circle.size == 2 && convoyed)) && found.none? { |c| (c & circle).any? }
    end
    found
  end

  # Every consistent choice that circular movement leaves.
  def solutions(entries)
    moves = entries.select(&:move?)
    raise "too many moves (#{moves.size})" if moves.size > 12

    all = [true, false].repeated_permutation(moves.size).map { |values| moves.zip(values).to_h }
                       .select { |success| consistent?(entries, success) }
    circles = circles(entries)
    all.reject do |success|
      circles.any? do |circle|
        circle.none? { |move| success[move] } && consistent?(entries, success.merge(circle.to_h { |move| [move, true] }))
      end
    end
  end

  def paradox?(entries) = solutions(entries).size != 1

  # {dislodged province => [the attacker's province, whether it went by convoy]} under `success`.
  def attackers(entries, success)
    facts = facts(entries, success)
    facts[:dislodged].select { |_, dislodged| dislodged }.to_h do |entry, _|
      move = facts[:into][entry.province].find { |candidate| success[candidate] }
      [entry.province, [move.province, facts[:convoyed].include?(move)]]
    end
  end

  # The result symbol each entry's order must get, and whether it is dislodged, under `success`.
  def results(entries, success)
    facts = facts(entries, success)
    entries.to_h do |entry|
      result =
        case entry.order
        when O::Hold then :held
        when O::Move, O::MoveViaConvoy
          facts[:route][entry] ? (success[entry] ? :succeeded : :bounced) : :no_route
        when O::SupportHold, O::SupportMove
          matched?(entry, facts[:at]) ? (cut?(entry, facts) ? :cut : :given) : :unmatched
        when O::Convoy
          if facts[:convoyed].any? { |move| carries?(entry, move) }
            facts[:dislodged][entry] ? :disrupted : :given
          else
            :unmatched
          end
        end
      [entry, [result, facts[:dislodged][entry]]]
    end
  end
end

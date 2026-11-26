# frozen_string_literal: true

require_relative "adjudicating"

# The conditions of the DATC's section 5 (DATC 5.B), written again here, in the spec, from the
# contract and the DATC and not from the resolver: given the orders and the result that
# TA.adjudicate gave, does every result satisfy them? (spec 014, AC-12.3.) It is read from the
# final results only, so it checks a solution and doesn't pick one: it can't tell which of
# several consistent solutions a circle should have, which is what the circle specs are for.
#
# It covers boards with no convoy: every move has a route.
module Conditions
  Entry = Data.define(:order, :power, :type, :result, :dislodged) do
    def province = order.at
    def move? = O::Move === order
    def destination = order.destination.province
    def support? = O::SupportHold === order || O::SupportMove === order
  end

  module_function

  # An array of messages, empty when every condition holds.
  def violations(position, adjudication)
    entries = entries_of(position, adjudication)
    at = entries.to_h { |entry| [entry.province, entry] }
    into = entries.select(&:move?).group_by(&:destination)
    problems = []

    entries.each do |entry|
      problems << "#{label(entry)}: #{support_problem(entry, at, into)}" if entry.support? && support_problem(entry, at, into)
      problems << "#{label(entry)}: #{move_problem(entry, at, into, entries)}" if entry.move? && move_problem(entry, at, into, entries)
    end
    problems.concat(circle_problems(entries))
    problems.concat(dislodgement_problems(position, adjudication, entries, into))
    problems.concat(standoff_problems(position, adjudication, entries, at, into))
    problems
  end

  # Moves that go around a circle of three or more units, each into the province the next
  # one leaves, all succeed or all fail: each one succeeds only if the next unit leaves.
  def circle_problems(entries)
    moves = entries.select(&:move?).to_h { |move| [move.province, move] }
    seen = []
    moves.values.filter_map do |start|
      path = [start]
      path << moves[path.last.destination] while moves[path.last.destination] && !path.include?(moves[path.last.destination])
      follower = moves[path.last.destination]
      next unless follower && path.include?(follower)

      circle = path[path.index(follower)..]
      next if circle.size < 3 || circle.intersect?(seen)

      seen.concat(circle)
      "a circle of #{circle.map(&:province).inspect} moves only in part" if circle.map { |move| succeeded?(move) }.uniq.size > 1
    end
  end

  def entries_of(position, adjudication)
    owners = position.units.to_h { |unit| [unit.location.province, unit] }
    adjudication.outcomes.reject { |outcome| outcome.result == :void }.map do |outcome|
      unit = owners.fetch(outcome.order.at)
      Entry.new(order: outcome.order, power: unit.power, type: unit.type, result: outcome.result, dislodged: outcome.dislodged)
    end
  end

  def label(entry) = "#{entry.order.class.name.split("::").last} at #{entry.province}"

  def succeeded?(entry) = entry.result == :succeeded

  # A support that belongs to a move or a hold of the unit it names.
  def matched?(support, at)
    case support.order
    when O::SupportHold then at[support.order.target] && !at[support.order.target].move?
    when O::SupportMove
      supported = at[support.order.from]
      supported&.move? && supported.destination == support.order.to
    end
  end

  def cut?(support, into)
    attackers = into.fetch(support.province, [])
    attackers.any? do |attacker|
      (attacker.power != support.power && (O::SupportHold === support.order || attacker.province != support.order.to)) ||
        succeeded?(attacker)
    end
  end

  def support_problem(support, at, into)
    expected = if !matched?(support, at) then :unmatched
               elsif cut?(support, into) then :cut
               else :given
               end
    "result #{support.result.inspect}, expected #{expected.inspect}" unless support.result == expected
  end

  def given_move_supports(move, entries, except_power: nil)
    entries.count do |entry|
      O::SupportMove === entry.order && entry.result == :given && entry.order.from == move.province &&
        entry.order.to == move.destination && entry.power != except_power
    end
  end

  def head_to_head?(move, at)
    other = at[move.destination]
    other&.move? && other.destination == move.province
  end

  def hold_strength(province, at, entries)
    entry = at[province]
    return 0 unless entry
    return (succeeded?(entry) ? 0 : 1) if entry.move?

    1 + entries.count { |other| O::SupportHold === other.order && other.order.target == province && other.result == :given }
  end

  def attack_strength(move, at, entries)
    other = at[move.destination]
    return 1 + given_move_supports(move, entries) if other.nil? || (other.move? && !head_to_head?(move, at) && succeeded?(other))
    return 0 if other.power == move.power

    1 + given_move_supports(move, entries, except_power: other.power)
  end

  def prevent_strength(move, at, entries)
    return 0 if head_to_head?(move, at) && succeeded?(at[move.destination])

    1 + given_move_supports(move, entries)
  end

  def move_problem(move, at, into, entries)
    attack = attack_strength(move, at, entries)
    opposing = head_to_head?(move, at) ? 1 + given_move_supports(at[move.destination], entries) : hold_strength(move.destination, at, entries)
    rivals = (into.fetch(move.destination) - [move]).map { |rival| prevent_strength(rival, at, entries) }
    expected = attack > opposing && rivals.all? { |rival| attack > rival } ? :succeeded : :bounced
    "result #{move.result.inspect}, expected #{expected.inspect} (attack #{attack}, against #{opposing}, rivals #{rivals})" unless move.result == expected
  end

  def dislodgement_problems(position, adjudication, entries, into)
    problems = []
    into.each { |province, moves| problems << "two moves into #{province} succeeded" if moves.count { |move| succeeded?(move) } > 1 }
    dislodged = adjudication.position.dislodged_units.to_h { |entry| [entry.unit.location.province, entry] }
    entries.each do |entry|
      stays = !(entry.move? && succeeded?(entry))
      winner = into.fetch(entry.province, []).find { |move| succeeded?(move) }
      expected = stays && !winner.nil?
      problems << "#{label(entry)}: dislodged #{entry.dislodged}, expected #{expected}" unless entry.dislodged == expected
      problems << "#{label(entry)}: dislodged unit missing or wrong attacker" if expected && dislodged[entry.province]&.attacker_from != winner.province
      problems << "#{label(entry)}: a power dislodged its own unit" if expected && winner.power == entry.power
    end
    problems << "dislodged units differ from the flagged outcomes" unless dislodged.keys.sort == entries.select(&:dislodged).map(&:province).sort
    problems << "a unit is lost or doubled" unless adjudication.position.units.size + dislodged.size == position.units.size
    problems
  end

  # An empty province that two or more moves entered on equal terms (spec 014, "Standoffs").
  def standoff_problems(position, adjudication, entries, at, into)
    occupied = adjudication.position.units.map { |unit| unit.location.province }
    expected = into.filter_map do |province, moves|
      next if occupied.include?(province)

      strengths = moves.map { |move| prevent_strength(move, at, entries) }.select(&:positive?)
      province if strengths.any? && strengths.count(strengths.max) >= 2
    end.sort
    expected == adjudication.position.standoffs ? [] : ["standoffs #{adjudication.position.standoffs}, expected #{expected}"]
  end
end

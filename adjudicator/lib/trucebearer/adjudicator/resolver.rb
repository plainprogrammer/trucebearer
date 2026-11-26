# frozen_string_literal: true

require "set"

module Trucebearer
  module Adjudicator
    # Internal: decides every move of a movement phase, following the decision-based approach
    # of Kruijswijk's "The Math of Adjudication" (docs/specs/014-adjudicate-movement/spec.md,
    # "How the conditions are resolved"). Not part of docs/interface.md.
    #
    # It is given one followed order for each unit. A move's decision starts unknown. Each
    # strength is kept as a range [least, most] given what is already decided, and a move is
    # decided as soon as its range settles it. When nothing more can be decided, the moves
    # that remain wait on each other in a circle, and circular movement decides them.
    class Resolver
      Entry = Data.define(:order, :unit) do
        def province = unit.location.province
        def power = unit.power
        def move? = order.is_a?(Order::Move) || order.is_a?(Order::MoveViaConvoy)
        def destination = order.is_a?(Order::Move) ? order.destination.province : order.to
      end

      # True when the last-resort rule ran: moves still undecided after the circle rule all
      # failed. It can't run without convoys (docs/specs/014-adjudicate-movement/spec.md, "The
      # paradox flag"), and #15 decides what it becomes.
      attr_reader :paradox

      def initialize(position, orders)
        @position = position
        @entries = position.units.zip(orders).map { |unit, order| Entry.new(order: order, unit: unit) }
        @at = @entries.to_h { |entry| [entry.province, entry] }
        @moves = @entries.select(&:move?)
        @into = @moves.group_by(&:destination)
        @by_convoy = @moves.select { |move| goes_by_convoy?(move) }.to_set
        @state = {}
        @paradox = false
        resolve
      end

      def entry_at(province) = @at.fetch(province)
      def convoy?(move) = @by_convoy.include?(move)
      def succeeded?(move) = @state[move] == true

      # The result symbol of the order a unit follows (docs/interface.md `### Outcomes`).
      def result(entry)
        case entry.order
        when Order::Hold then :held
        when Order::Move, Order::MoveViaConvoy
          return :no_route if convoy?(entry)

          succeeded?(entry) ? :succeeded : :bounced
        when Order::SupportHold, Order::SupportMove then support_result(entry)
        when Order::Convoy then :unmatched
        end
      end

      # The move that dislodged this unit, or nil.
      def attacker_of(entry)
        return nil if entry.move? && succeeded?(entry)

        (@into[entry.province] || []).find { |move| succeeded?(move) }
      end

      def dislodged?(entry) = !attacker_of(entry).nil?

      # The units after the moves, the dislodged units and the standoffs.
      def next_units
        @entries.reject { |entry| dislodged?(entry) }.map do |entry|
          next entry.unit unless entry.move? && succeeded?(entry)

          Unit.new(power: entry.power, type: entry.unit.type, location: destination_location(entry))
        end
      end

      def dislodged_units
        @entries.filter_map do |entry|
          attacker = attacker_of(entry)
          next unless attacker

          DislodgedUnit.new(unit: entry.unit, attacker_from: attacker.province, by_convoy: convoy?(attacker))
        end
      end

      # Provinces left empty after a standoff: at least two moves into the province had a
      # route, had not lost a head-to-head battle, and shared the greatest prevent strength.
      def standoffs
        @into.filter_map do |province, moves|
          next if occupied_after?(province)

          strengths = moves.map { |move| prevent(move).first }.select(&:positive?)
          top = strengths.max
          province if top && strengths.count(top) >= 2
        end.sort
      end

      private

      # ---- what is fixed by the orders alone ----

      # A move goes by convoy when an army can't reach the province by land, when it is a
      # MoveViaConvoy, or when a fleet of its own power gives a matching convoy order that is
      # legal (docs/interface.md `### Convoy routing`). Fleets never do.
      def goes_by_convoy?(move)
        return false unless move.unit.type == :army
        return true if move.order.is_a?(Order::MoveViaConvoy)
        return true unless Reach.reaches?(move.unit, move.destination)

        @entries.any? do |entry|
          entry.order.is_a?(Order::Convoy) && entry.power == move.power &&
            entry.order.from == move.province && entry.order.to == move.destination
        end
      end

      # The one place a later release decides whether a convoy route works (#15).
      def path?(move) = !convoy?(move)

      def destination_location(entry)
        entry.order.is_a?(Order::Move) ? entry.order.destination : Location.new(province: entry.order.to)
      end

      def hold_supporters(province)
        @entries.select do |entry|
          entry.order.is_a?(Order::SupportHold) && entry.order.target == province && !@at[province].move?
        end
      end

      def move_supporters(move)
        @entries.select do |entry|
          entry.order.is_a?(Order::SupportMove) && entry.order.from == move.province && entry.order.to == move.destination
        end
      end

      def matched?(entry)
        case entry.order
        when Order::SupportHold then !@at[entry.order.target].move?
        when Order::SupportMove
          supported = @at[entry.order.from]
          supported.move? && supported.destination == entry.order.to
        end
      end

      def support_result(entry)
        return :unmatched unless matched?(entry)

        cut?(entry) ? :cut : :given
      end

      # ---- the decisions ----

      def resolve
        until @moves.none? { |move| @state[move].nil? }
          next if decide_pass
          next if circle_pass

          last_resort
        end
      end

      # Nothing can be decided and no circle of three or more is left. Without convoys this
      # can't happen (docs/specs/014-adjudicate-movement/spec.md, "The paradox flag"). The moves
      # on the cycles that are stuck fail, or every undecided move if there is no cycle, so the
      # loop always ends.
      def last_resort
        stuck = cycles.flatten
        stuck = @moves.select { |move| @state[move].nil? } if stuck.empty?
        stuck.each { |move| @state[move] = false }
        @paradox = true
      end

      def decide_pass
        progressed = false
        @moves.each do |move|
          next unless @state[move].nil?

          verdict = verdict(move)
          next if verdict.nil?

          @state[move] = verdict
          progressed = true
        end
        progressed
      end

      # Moves that wait on each other in a circle of three or more units, each into the
      # province the next one leaves, all succeed (circular movement).
      def circle_pass
        circles = cycles.select { |circle| circle.size >= 3 }
        circles.each { |circle| circle.each { |move| @state[move] = true } }
        !circles.empty?
      end

      # The cycles that the undecided moves form: each move waits on the undecided move of the
      # unit in its destination, so every move has at most one successor.
      def cycles
        seen = Set.new
        found = []
        @moves.select { |move| @state[move].nil? }.each do |start|
          path = []
          current = start
          while current && !seen.include?(current) && !path.include?(current)
            path << current
            current = waits_on(current)
          end
          found << path[path.index(current)..] if current && path.include?(current)
          path.each { |move| seen << move }
        end
        found
      end

      # The undecided move of the unit that stands in this move's destination, if any.
      def waits_on(move)
        other = @at[move.destination]
        other if other&.move? && @state[other].nil?
      end

      # true: the move surely succeeds; false: it surely fails; nil: not yet known.
      def verdict(move)
        attack = attack(move)
        against = head_to_head?(move) ? defend(@at[move.destination]) : hold(move.destination)
        rivals = (@into[move.destination] - [move]).map { |rival| prevent(rival) }
        return true if attack[0] > against[1] && rivals.all? { |rival| attack[0] > rival[1] }
        return false if attack[1] <= against[0] || rivals.any? { |rival| attack[1] <= rival[0] }

        nil
      end

      def head_to_head?(move)
        other = @at[move.destination]
        other&.move? && other.destination == move.province && !convoy?(move) && !convoy?(other)
      end

      # ---- strengths, each as [least, most] ----

      def hold(province)
        entry = @at[province]
        return [0, 0] unless entry

        if entry.move?
          case @state[entry]
          when true then [0, 0]
          when false then [1, 1]
          else [0, 1]
          end
        else
          range(1, hold_supporters(province))
        end
      end

      def attack(move)
        return [0, 0] unless path?(move)

        other = @at[move.destination]
        return range(1, move_supporters(move)) unless other
        return staying_attack(move, other) if !other.move? || head_to_head?(move)

        case @state[other]
        when true then range(1, move_supporters(move))
        when false then staying_attack(move, other)
        else
          leaving = range(1, move_supporters(move))
          staying = staying_attack(move, other)
          [[leaving[0], staying[0]].min, [leaving[1], staying[1]].max]
        end
      end

      # Against a unit that stays: nothing against its own power, and no help from its owner.
      def staying_attack(move, other)
        return [0, 0] if other.power == move.power

        range(1, move_supporters(move).reject { |support| support.power == other.power })
      end

      def prevent(move)
        return [0, 0] unless path?(move)

        if head_to_head?(move)
          case @state[@at[move.destination]]
          when true then return [0, 0]
          when nil then return [0, range(1, move_supporters(move))[1]]
          end
        end
        range(1, move_supporters(move))
      end

      def defend(move) = range(1, move_supporters(move))

      # base plus the supports that are given, as [least, most].
      def range(base, supporters)
        given = supporters.map { |support| given?(support) }
        [base + given.count(true), base + given.count { |state| !state.equal?(false) }]
      end

      def given?(support)
        cut = cut?(support)
        cut.nil? ? nil : !cut
      end

      # A support is cut by a move into its province from another power with a route, unless
      # the supported move goes to the province that move comes from; and by dislodgement.
      def cut?(support)
        attackers = @into[support.province] || []
        return true if attackers.any? { |move| cuts?(move, support) }

        states = attackers.map { |move| @state[move] }
        return true if states.any?(true)

        states.all?(false) ? false : nil
      end

      def cuts?(move, support)
        return false if !path?(move) || move.power == support.power

        support.order.is_a?(Order::SupportHold) || move.province != support.order.to
      end

      def occupied_after?(province)
        entry = @at[province]
        return true if entry && !(entry.move? && succeeded?(entry))

        (@into[province] || []).any? { |move| succeeded?(move) }
      end
    end
    private_constant :Resolver
  end
end

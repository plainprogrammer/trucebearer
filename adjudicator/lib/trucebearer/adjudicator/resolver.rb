# frozen_string_literal: true

require "set"

module Trucebearer
  module Adjudicator
    # Internal: decides every move of a movement phase, following the decision-based approach
    # of Kruijswijk's "The Math of Adjudication" (docs/specs/014-adjudicate-movement/spec.md,
    # "How the conditions are resolved"; convoys: docs/specs/015-convoys/spec.md). Not part of
    # docs/interface.md.
    #
    # It is given one followed order for each unit. A move's decision starts unknown. Each
    # strength is kept as a range [least, most] given what is already decided, and a move is
    # decided as soon as its range settles it. Whether a move that goes by convoy has a route
    # depends on whether its carrying fleets are dislodged, so it is sure, lost or open, and an
    # open route widens the ranges. When nothing more can be decided, circular movement decides
    # the circles, and whatever is still undecided is a convoy paradox: those moves fail and
    # `paradox` is set. Resolving a paradox properly is #39.
    class Resolver
      Entry = Data.define(:order, :unit) do
        def province = unit.location.province
        def power = unit.power
        def move? = order.is_a?(Order::Move) || order.is_a?(Order::MoveViaConvoy)
        def destination = order.is_a?(Order::Move) ? order.destination.province : order.to
      end

      # True when moves were left undecided after the ranges and circular movement: the orders
      # hold a convoy paradox (docs/specs/015-convoys/spec.md, "Detecting a paradox").
      attr_reader :paradox

      def initialize(position, orders)
        @position = position
        @entries = position.units.zip(orders).map { |unit, order| Entry.new(order: order, unit: unit) }
        @at = @entries.to_h { |entry| [entry.province, entry] }
        @moves = @entries.select(&:move?)
        @into = @moves.group_by(&:destination)
        @by_convoy = @moves.select { |move| goes_by_convoy?(move) }.to_set
        @carriers = @by_convoy.to_h { |move| [move, carriers_of(move)] }
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
          return :no_route unless path?(entry)

          succeeded?(entry) ? :succeeded : :bounced
        when Order::SupportHold, Order::SupportMove then support_result(entry)
        when Order::Convoy then convoy_result(entry)
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

      # The fleets that carry a move that goes by convoy: those whose followed order is a
      # Convoy that matches it, of any power.
      def carriers_of(move)
        @entries.select do |entry|
          entry.order.is_a?(Order::Convoy) && entry.order.from == move.province && entry.order.to == move.destination
        end
      end

      # Does the move have a working route? :sure when some chain of carrying fleets has no
      # fleet that might be dislodged, :lost when every chain has one that surely is (or there
      # is none), :open otherwise. A move that goes by land always has one.
      def route(move)
        return :sure unless convoy?(move)

        fleets = @carriers.fetch(move)
        safe = fleets.select { |fleet| dislodged_state(fleet) == false }.to_set(&:province)
        return :sure if Reach.linked?(safe, move.province, move.destination)

        possible = fleets.reject { |fleet| dislodged_state(fleet) == true }.to_set(&:province)
        Reach.linked?(possible, move.province, move.destination) ? :open : :lost
      end

      # Only called once everything is decided (by `result`).
      def path?(move) = route(move) == :sure

      # true when some move into the unit's province has succeeded, false when none can,
      # nil while that is not known.
      def dislodged_state(entry)
        states = (@into[entry.province] || []).map { |move| @state[move] }
        return true if states.any?(true)

        states.all?(false) ? false : nil
      end

      def convoy_result(entry)
        matched = @by_convoy.any? { |move| move.province == entry.order.from && move.destination == entry.order.to }
        return :unmatched unless matched

        dislodged_state(entry) ? :disrupted : :given
      end

      def destination_location(entry)
        entry.order.is_a?(Order::Move) ? entry.order.destination : Location.new(province: entry.order.to)
      end

      def hold_supporters(province)
        @entries.select do |entry|
          entry.order.is_a?(Order::SupportHold) && entry.order.target == province
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

          fail_residue
        end
      end

      # Nothing more can be decided and no circle is left: the moves still undecided are the
      # residue, which holds a convoy paradox. They all fail, and the flag is set.
      def fail_residue
        @moves.each { |move| @state[move] = false if @state[move].nil? }
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

      # Moves that wait on each other in a circle (see `circle?`), each into the
      # province the next one leaves, all succeed (circular movement).
      def circle_pass
        circles = cycles.select { |circle| circle?(circle) }
        circles.each { |circle| circle.each { |move| @state[move] = true } }
        !circles.empty?
      end

      # Three or more moves, or two when one of them goes by convoy (two plain moves are a
      # head-to-head battle), and every route sure.
      def circle?(moves)
        (moves.size >= 3 || moves.any? { |move| convoy?(move) }) && moves.all? { |move| route(move) == :sure }
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
        widen(move, attack_with_route(move))
      end

      def attack_with_route(move)
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

      # A move with no route has no strength; one whose route is open might have none.
      def widen(move, strength)
        case route(move)
        when :sure then strength
        when :lost then [0, 0]
        else [0, strength[1]]
        end
      end

      # Against a unit that stays: nothing against its own power, and no help from its owner.
      def staying_attack(move, other)
        return [0, 0] if other.power == move.power

        range(1, move_supporters(move).reject { |support| support.power == other.power })
      end

      def prevent(move)
        widen(move, prevent_with_route(move))
      end

      def prevent_with_route(move)
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
        cuts = attackers.map { |move| cuts?(move, support) }
        return true if cuts.any?(true)

        states = attackers.map { |move| @state[move] }
        return true if states.any?(true)

        cuts.all?(false) && states.all?(false) ? false : nil
      end

      # true, false, or nil while the move's route is open.
      def cuts?(move, support)
        return false if move.power == support.power
        return false unless support.order.is_a?(Order::SupportHold) || move.province != support.order.to

        case route(move)
        when :sure then true
        when :lost then false
        end
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

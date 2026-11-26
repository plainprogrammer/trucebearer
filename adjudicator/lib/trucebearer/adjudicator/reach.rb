# frozen_string_literal: true

require "set"

module Trucebearer
  module Adjudicator
    # Internal: the questions checking asks about the board, and that legal orders (#12)
    # asks too. Not part of docs/interface.md, and it may change in any release.
    # Everything is worked out once from the map when this file loads, so the map
    # data stays the only place adjacency is written.
    module Reach
      MAP = Map.classic
      SEAS = MAP.provinces.select { |province| province.type == :sea }.map(&:id).freeze
      COASTAL = MAP.provinces.select { |province| province.type == :coastal }.map(&:id).freeze
      LAND = MAP.provinces.reject { |province| province.type == :sea }.map(&:id).freeze

      # Every place a fleet can stand, as [province, coast] (the coast is nil off a split coast).
      FLEET_PLACES = MAP.provinces.reject { |province| province.type == :inland }.flat_map do |province|
        province.coasts.empty? ? [[province.id, nil]] : province.coasts.map { |coast| [province.id, coast] }
      end.freeze

      # province => the provinces an army there can step to
      ARMY_STEPS = LAND.to_h do |from|
        steps = LAND.select do |to|
          MAP.adjacent?(:army, Location.new(province: from), Location.new(province: to))
        end
        [from, steps.freeze]
      end.freeze

      # [province, coast] => the [province, coast] places a fleet there can step to
      FLEET_STEPS = FLEET_PLACES.to_h do |(from, from_coast)|
        from_location = Location.new(province: from, coast: from_coast)
        steps = FLEET_PLACES.select do |(to, to_coast)|
          MAP.adjacent?(:fleet, from_location, Location.new(province: to, coast: to_coast))
        end
        [[from, from_coast], steps.freeze]
      end.freeze

      # sea => the seas next to it
      SEA_LINKS = SEAS.to_h do |sea|
        [sea, FLEET_STEPS.fetch([sea, nil]).map(&:first).select { |to| SEAS.include?(to) }.to_set.freeze]
      end.freeze

      # coastal province => the seas that touch any coast of it
      SEA_TOUCHES = COASTAL.to_h do |province|
        seas = FLEET_PLACES.select { |(id, _)| id == province }.flat_map do |place|
          FLEET_STEPS.fetch(place).map(&:first).select { |to| SEAS.include?(to) }
        end
        [province, seas.to_set.freeze]
      end.freeze
      NO_SEAS = Set.new.freeze

      module_function

      # The coasts (nil for a province without split coasts) a unit can step to in this
      # province from where it stands. Empty when it can't reach the province.
      def step_coasts(unit, province)
        location = unit.location
        if unit.type == :army
          ARMY_STEPS.fetch(location.province, []).include?(province) ? [nil] : []
        else
          FLEET_STEPS.fetch([location.province, location.coast]).select { |(to, _)| to == province }.map(&:last)
        end
      end

      def reaches?(unit, province)
        !step_coasts(unit, province).empty?
      end

      # True when the position has a convoy chain from one coastal province to another
      # different one. `without` leaves out the fleet standing in that province.
      def chain?(position, from, to, without: nil)
        return false if from == to

        seas = fleet_seas(position, without)
        frontier = seas.select { |sea| touches?(sea, from) }
        reached = frontier.to_set
        until frontier.empty?
          sea = frontier.pop
          return true if touches?(sea, to)

          (SEA_LINKS.fetch(sea) & seas).each { |next_sea| frontier << next_sea if reached.add?(next_sea) }
        end
        false
      end

      # True when the fleet standing in `fleet_province` is part of at least one minimal
      # convoy chain from one coastal province to another: a chain with no shortcut, so
      # that no smaller set of the position's fleets is also a chain between the same two.
      def on_minimal_chain?(position, fleet_province, from, to)
        return false if from == to || !COASTAL.include?(from) || !COASTAL.include?(to)

        seas = fleet_seas(position, nil)
        return false unless seas.include?(fleet_province)

        seas.any? { |first| touches?(first, from) && extend_chain?([first], seas, fleet_province, from, to) }
      end

      def touches?(sea, province)
        SEA_TOUCHES.fetch(province, NO_SEAS).include?(sea)
      end

      # The sea provinces that hold a fleet of any power.
      def fleet_seas(position, without)
        position.units.select { |unit| unit.type == :fleet && SEAS.include?(unit.location.province) }
                .map { |unit| unit.location.province }.reject { |sea| sea == without }.to_set
      end

      # Grows a chain one sea at a time. A new sea may not touch the origin or any sea
      # before the last one, so every chain it completes is free of shortcuts. Completed
      # when the last sea touches the destination and no earlier one does.
      def extend_chain?(path, seas, wanted, from, to)
        last = path.last
        return true if touches?(last, to) && path[0...-1].none? { |sea| touches?(sea, to) } && path.include?(wanted)

        (SEA_LINKS.fetch(last) & seas).any? do |sea|
          next false if path.include?(sea) || touches?(sea, from)
          next false if path[0...-1].any? { |earlier| SEA_LINKS.fetch(earlier).include?(sea) }

          extend_chain?(path + [sea], seas, wanted, from, to)
        end
      end
    end
    private_constant :Reach
  end
end

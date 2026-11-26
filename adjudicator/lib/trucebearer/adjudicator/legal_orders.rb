# frozen_string_literal: true

module Trucebearer
  module Adjudicator
    # Internal: the legal orders of one unit (docs/interface.md `## Legal orders`).
    # It builds only the orders that could possibly be legal (the narrowings N1 to N4 of
    # spec 012), in the contract's list order, and `Check.reason_for` decides each one. So
    # the list can never hold an order that TA.check refuses, and the generator applies
    # no other test of its own.
    module LegalOrders
      SORTED_COASTAL = Reach::COASTAL.sort_by(&:to_s).freeze

      module_function

      def call(position, unit)
        Shape.instance_of!(position, Position, "position")
        Shape.instance_of!(unit, Unit, "unit")
        return [] unless position.phase == :movement && position.units.include?(unit)

        candidates(position, unit).select { |order| Check.reason_for(position, order).nil? }
      end

      # Every order that could be legal, grouped and sorted as the contract lists them.
      def candidates(position, unit)
        power = unit.power
        at = unit.location.province
        occupied = position.units.map { |other| other.location.province }.sort_by(&:to_s)
        steps = step_provinces(unit)

        [Order::Hold.new(power: power, at: at)] +
          move_destinations(unit).map { |to| Order::Move.new(power: power, at: at, destination: to) } +
          via_convoy_targets(unit, steps).map { |to| Order::MoveViaConvoy.new(power: power, at: at, to: to) } +
          occupied.map { |target| Order::SupportHold.new(power: power, at: at, target: target) } +
          occupied.product(steps).map { |from, to| Order::SupportMove.new(power: power, at: at, from: from, to: to) } +
          convoy_pairs(position, unit).map { |from, to| Order::Convoy.new(power: power, at: at, from: from, to: to) }
      end

      # N1: where a move could go, by destination province and then coast. An army on a
      # coastal province may also go to any coastal province, because a chain could carry it.
      def move_destinations(unit)
        location = unit.location
        places =
          if unit.type == :army
            provinces = Reach::ARMY_STEPS.fetch(location.province)
            provinces |= Reach::COASTAL if Reach::COASTAL.include?(location.province)
            provinces.map { |province| [province, nil] }
          else
            Reach::FLEET_STEPS.fetch([location.province, location.coast])
          end
        places.sort_by { |province, coast| [province.to_s, coast.to_s] }
              .map { |province, coast| Location.new(province: province, coast: coast) }
      end

      # The provinces the unit reaches in one step, by identifier.
      def step_provinces(unit)
        location = unit.location
        provinces =
          if unit.type == :army
            Reach::ARMY_STEPS.fetch(location.province)
          else
            Reach::FLEET_STEPS.fetch([location.province, location.coast]).map(&:first)
          end
        provinces.uniq.sort_by(&:to_s)
      end

      # N2: only an army, and only to a province it reaches by land.
      def via_convoy_targets(unit, steps)
        unit.type == :army ? steps : []
      end

      # N4: only a fleet in a sea province, from a province that holds an army, to a coastal province.
      def convoy_pairs(position, unit)
        return [] unless unit.type == :fleet && Reach::SEAS.include?(unit.location.province)

        armies = position.units.select { |other| other.type == :army }.map { |other| other.location.province }
        armies.sort_by(&:to_s).product(SORTED_COASTAL)
      end
    end
    private_constant :LegalOrders
  end
end

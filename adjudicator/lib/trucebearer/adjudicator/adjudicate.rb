# frozen_string_literal: true

module Trucebearer
  module Adjudicator
    # Internal: TA.adjudicate's one public door (docs/interface.md, "Adjudicating a movement
    # phase"). Sorts out which order each unit follows, asks the Resolver, and reads the
    # outcome list and the next position from its decisions.
    module Adjudicate
      module_function

      def call(position, orders)
        Shape.instance_of!(position, Position, "position")
        Shape.array!(orders, "orders").each do |order|
          next if Check::ORDERS.any? { |klass| order.is_a?(klass) }

          raise InvalidInput, "\"orders\" must hold only the six order classes, got #{order.inspect}"
        end
        raise InvalidInput, "adjudication needs a position in the movement phase, got #{position.phase.inspect}" unless position.phase == :movement

        repeated = orders.map { |order| [order.power, order.at] }.tally.find { |_, count| count > 1 }
        raise InvalidInput, "#{repeated.first[0]} gave two orders for the province #{repeated.first[1]}" if repeated

        build(position, orders)
      end

      def build(position, orders)
        reasons = orders.map { |order| Check.reason_for(position, order) }
        legal = orders.zip(reasons).filter_map { |order, reason| order unless reason }
        by_province = legal.to_h { |order| [order.at, order] }
        followed = position.units.map do |unit|
          by_province[unit.location.province] || Order::Hold.new(power: unit.power, at: unit.location.province)
        end
        resolver = Resolver.new(position, followed)

        Adjudication.new(outcomes: submitted_outcomes(orders, reasons, resolver) + implied_outcomes(position, by_province, resolver),
                         paradox: resolver.paradox, position: next_position(position, resolver))
      end

      def submitted_outcomes(orders, reasons, resolver)
        orders.zip(reasons).map do |order, reason|
          if reason
            Outcome.new(order: order, result: :void, submitted: true, dislodged: false)
          else
            entry = resolver.entry_at(order.at)
            Outcome.new(order: order, result: resolver.result(entry), submitted: true, dislodged: resolver.dislodged?(entry))
          end
        end
      end

      def implied_outcomes(position, by_province, resolver)
        position.units.reject { |unit| by_province.key?(unit.location.province) }.map do |unit|
          province = unit.location.province
          Outcome.new(order: Order::Hold.new(power: unit.power, at: province), result: :held, submitted: false,
                      dislodged: resolver.dislodged?(resolver.entry_at(province)))
        end
      end

      def next_position(position, resolver)
        Position.new(map: position.map, season: position.season, year: position.year, phase: :retreat,
                     units: resolver.next_units, ownership: position.ownership,
                     dislodged_units: resolver.dislodged_units, standoffs: resolver.standoffs)
      end
    end
    private_constant :Adjudicate
  end
end

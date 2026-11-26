# frozen_string_literal: true

module Trucebearer
  module Adjudicator
    # Internal: checks one order against a position, following the precedence tables of
    # docs/interface.md `## Checking an order`. TA.check is its one public door.
    module Check
      ORDERS = [Order::Hold, Order::Move, Order::MoveViaConvoy,
                Order::SupportHold, Order::SupportMove, Order::Convoy].freeze

      module_function

      def call(position, order)
        Shape.instance_of!(position, Position, "position")
        unless ORDERS.any? { |klass| order.is_a?(klass) }
          raise InvalidInput, "\"order\" must be one of the six order classes, got #{order.inspect}"
        end

        reason = reason_for(position, order)
        reason ? CheckResult.new(legal: false, reasons: [reason]) : CheckResult.new(legal: true, reasons: [])
      end

      # The first failing condition's reason, or nil when the order is legal.
      def reason_for(position, order)
        return :wrong_phase unless position.phase == :movement

        unit = unit_at(position, order.at)
        return :no_such_unit unless unit
        return :foreign_unit unless unit.power == order.power

        case order
        when Order::Hold then nil
        when Order::Move then move(position, unit, order)
        when Order::MoveViaConvoy then move_via_convoy(position, unit, order)
        when Order::SupportHold then support_hold(position, unit, order)
        when Order::SupportMove then support_move(position, unit, order)
        when Order::Convoy then convoy(position, unit, order)
        end
      end

      def move(position, unit, order)
        destination = order.destination
        return :own_province if destination.province == order.at

        coasts = Reach.step_coasts(unit, destination.province)
        by_chain = unit.type == :army && Reach.chain?(position, order.at, destination.province)
        return :not_reachable if coasts.empty? && !by_chain

        if unit.type == :army
          destination.coast ? :coast_not_allowed : nil
        elsif Map.classic.coasts(destination.province).empty?
          nil
        elsif destination.coast.nil?
          :coast_required
        elsif !coasts.include?(destination.coast)
          :coast_unreachable
        end
      end

      def move_via_convoy(position, unit, order)
        return :not_army unless unit.type == :army
        return :own_province if order.to == order.at
        return :not_adjacent unless Reach.reaches?(unit, order.to)

        :no_convoy_route unless Reach.chain?(position, order.at, order.to)
      end

      def support_hold(position, unit, order)
        return :own_province if order.target == order.at
        return :no_unit unless unit_at(position, order.target)

        :not_reachable unless Reach.reaches?(unit, order.target)
      end

      def support_move(position, unit, order)
        return :own_province if order.from == order.at || order.to == order.at
        return :same_province if order.from == order.to

        supported = unit_at(position, order.from)
        return :no_unit unless supported
        return :not_reachable unless Reach.reaches?(unit, order.to)

        :move_impossible unless could_move?(position, supported, order.to, order.at)
      end

      def convoy(position, unit, order)
        return :not_fleet_at_sea unless unit.type == :fleet && Map.classic.province(order.at).type == :sea
        return :bad_endpoints if order.from == order.to || !coastal?(order.from) || !coastal?(order.to)

        army = unit_at(position, order.from)
        return :no_unit unless army&.type == :army

        :not_on_chain unless Reach.on_minimal_chain?(position, order.at, order.from, order.to)
      end

      # Could this unit make a plain move into the province? An army may also go by a
      # convoy chain that doesn't need the supporter's fleet (6.D.31).
      def could_move?(position, unit, province, supporter_province)
        return true if Reach.reaches?(unit, province)

        unit.type == :army && Reach.chain?(position, unit.location.province, province, without: supporter_province)
      end

      def coastal?(province)
        Map.classic.province(province).type == :coastal
      end

      def unit_at(position, province)
        position.units.find { |unit| unit.location.province == province }
      end
    end
    private_constant :Check
  end
end

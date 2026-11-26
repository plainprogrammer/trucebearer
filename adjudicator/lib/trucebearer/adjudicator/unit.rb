# frozen_string_literal: true

module Trucebearer
  module Adjudicator
    # An army or a fleet on the board. Carries no format (it only appears nested).
    Unit = Data.define(:power, :type, :location) do
      include Shape::Marshalable

      def initialize(power:, type:, location:)
        Shape.symbol_of(power, Shape::POWERS, "power", "power")
        Shape.symbol_of(type, Shape::UNIT_TYPES, "type", "unit type")
        Shape.instance_of!(location, Location, "location")
        check_placement(type, location)
        super
      end

      def to_h
        { "power" => power.to_s, "type" => type.to_s, "location" => location.to_h }
      end

      def self.from_h(hash)
        Shape.keys!(hash, %w[power type location])
        new(power: Shape.text_of(hash["power"], Shape::POWERS, "power", "power"),
            type: Shape.text_of(hash["type"], Shape::UNIT_TYPES, "type", "unit type"),
            location: Location.from_h(hash["location"]))
      end

      private

      def check_placement(type, location)
        province = Map.classic.province(location.province)
        if type == :army
          raise InvalidInput, "an army cannot stand on a sea province: #{location.inspect}" if province.type == :sea
          raise InvalidInput, "an army's location must not name a coast: #{location.inspect}" if location.coast
        else
          raise InvalidInput, "a fleet cannot stand on an inland province: #{location.inspect}" if province.type == :inland
          if location.coast.nil? && !province.coasts.empty?
            raise InvalidInput, "a fleet on a split-coast province must name a coast: #{location.inspect}"
          end
        end
      end
    end
  end
end

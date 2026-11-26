# frozen_string_literal: true

module Trucebearer
  module Adjudicator
    # The state of the board at one moment. Storable: its hash form carries format.
    Position = Data.define(:map, :season, :year, :phase, :units, :ownership, :dislodged_units, :standoffs) do
      def initialize(map:, season:, year:, phase:, units:, ownership:, dislodged_units:, standoffs:)
        map = Shape.map!(map)
        Shape.symbol_of(season, Shape::SEASONS, "season", "season")
        Shape.symbol_of(phase, Shape::PHASES, "phase", "phase")
        Shape.integer!(year, "year")
        units = canonical_units(units)
        dislodged_units = canonical_dislodged(dislodged_units)
        standoffs = canonical_standoffs(standoffs)
        ownership = canonical_ownership(ownership)
        if phase == :movement && !(dislodged_units.empty? && standoffs.empty?)
          raise InvalidInput, "a position in phase #{phase.inspect} cannot hold dislodged units or standoffs"
        end

        super(map: map, season: season, year: year, phase: phase, units: units, ownership: ownership,
              dislodged_units: dislodged_units, standoffs: standoffs)
      end

      def to_h
        { "format" => Shape::FORMAT, "map" => map, "season" => season.to_s, "year" => year, "phase" => phase.to_s,
          "units" => units.map(&:to_h),
          "ownership" => ownership.to_h { |center, power| [center.to_s, power.to_s] },
          "dislodged_units" => dislodged_units.map(&:to_h),
          "standoffs" => standoffs.map(&:to_s) }
      end

      def self.from_h(hash)
        Shape.format!(hash)
        Shape.keys!(hash, %w[format map season year phase units ownership dislodged_units standoffs])
        new(map: hash["map"],
            season: Shape.text_of(hash["season"], Shape::SEASONS, "season", "season"),
            year: hash["year"],
            phase: Shape.text_of(hash["phase"], Shape::PHASES, "phase", "phase"),
            units: Shape.array!(hash["units"], "units").map { |unit| Unit.from_h(unit) },
            ownership: ownership_from(hash["ownership"]),
            dislodged_units: Shape.array!(hash["dislodged_units"], "dislodged_units").map { |entry| DislodgedUnit.from_h(entry) },
            standoffs: Shape.array!(hash["standoffs"], "standoffs").map do |province|
              Shape.text_of(province, Shape::PROVINCES, "standoffs", "province")
            end)
      end

      def self.ownership_from(value)
        Shape.hash!(value, "\"ownership\"").to_h do |center, power|
          [Shape.text_of(center, Shape::SUPPLY_CENTERS, "ownership key", "supply center"),
           Shape.text_of(power, Shape::POWERS, "ownership value", "power")]
        end
      end
      private_class_method :ownership_from

      private

      def canonical_units(units)
        list = Shape.list_of(units, Unit, "units")
        Shape.unique!(list.map { |unit| unit.location.province }, "two units share the province")
        list.sort_by { |unit| unit.location.province }.freeze
      end

      def canonical_dislodged(dislodged)
        list = Shape.list_of(dislodged, DislodgedUnit, "dislodged_units")
        Shape.unique!(list.map { |entry| entry.unit.location.province }, "two dislodged units share the province")
        list.sort_by { |entry| entry.unit.location.province }.freeze
      end

      def canonical_standoffs(standoffs)
        list = Shape.array!(standoffs, "standoffs").dup
        list.each { |province| Shape.symbol_of(province, Shape::PROVINCES, "standoffs", "province") }
        Shape.unique!(list, "the standoff province is listed twice:")
        list.sort.freeze
      end

      def canonical_ownership(ownership)
        Shape.hash!(ownership, "\"ownership\"").each do |center, power|
          Shape.symbol_of(center, Shape::SUPPLY_CENTERS, "ownership key", "supply center")
          Shape.symbol_of(power, Shape::POWERS, "ownership value", "power")
        end
        ownership.sort_by { |center, _| center }.to_h.freeze
      end
    end
  end
end

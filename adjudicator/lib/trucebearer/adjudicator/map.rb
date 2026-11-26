# frozen_string_literal: true

require "yaml"

module Trucebearer
  module Adjudicator
    # The map: provinces, powers and what touches what. Query-only, never stored.
    # Built once from data/maps/classic.yml when this file is required.
    class Map
      Power = Data.define(:id, :name)
      Province = Data.define(:id, :name, :type, :coasts, :supply_center, :home)

      DATA_PATH = File.expand_path("../../../data/maps/classic.yml", __dir__)
      NO_NEIGHBORS = Set.new.freeze

      class << self
        # The classic map. Takes no path: the gem has one map, built in. The loader
        # and the constructor are private, so there is no way to load another file.
        attr_reader :classic

        private

        def from_file(path)
          # freeze: true makes every string in the map immutable, names included.
          raw = YAML.safe_load_file(path, permitted_classes: [], aliases: false, freeze: true)
          starting_units = raw["starting_units"].map do |u|
            { power: u["power"].to_sym, type: u["type"].to_sym,
              province: u["province"].to_sym, coast: u["coast"]&.to_sym }.freeze
          end.sort_by { |u| u[:province] }.freeze
          new(
            id: raw["map"],
            powers: raw["powers"].map { |p| Power.new(id: p["id"].to_sym, name: p["name"]) },
            provinces: raw["provinces"].map { |p| build_province(p) },
            armies: raw["armies"].to_h { |from, tos| [from.to_sym, tos.map(&:to_sym).to_set.freeze] }.freeze,
            fleets: raw["fleets"].to_h { |from, tos| [fleet_key(from), tos.map { |to| fleet_key(to) }.to_set.freeze] }.freeze,
            starting_units: starting_units
          )
        end

        def build_province(entry)
          Province.new(
            id: entry["id"].to_sym,
            name: entry["name"],
            type: entry["type"].to_sym,
            coasts: entry.fetch("coasts", []).map(&:to_sym).freeze,
            supply_center: entry.fetch("supply_center", false),
            home: entry["home"]&.to_sym
          )
        end

        # "spa/nc" -> [:spa, :nc]; "alb" -> [:alb, nil]
        def fleet_key(text)
          province, coast = text.split("/")
          [province.to_sym, coast&.to_sym].freeze
        end
      end

      private_class_method :new

      attr_reader :id, :powers, :provinces, :supply_centers

      def initialize(id:, powers:, provinces:, armies:, fleets:, starting_units:)
        @id = id.freeze
        @powers = powers.sort_by(&:id).freeze
        @provinces = provinces.sort_by(&:id).freeze
        @powers_by_id = @powers.to_h { |power| [power.id, power] }.freeze
        @provinces_by_id = @provinces.to_h { |province| [province.id, province] }.freeze
        @supply_centers = @provinces.select(&:supply_center).map(&:id).freeze
        @home_centers = @powers.to_h do |power|
          [power.id, @provinces.select { |province| province.home == power.id }.map(&:id).freeze]
        end.freeze
        @armies = armies
        @fleets = fleets
        @starting_units = starting_units
        freeze
      end

      def power(id)
        @powers_by_id.fetch(id) { raise InvalidInput, "unknown power #{id.inspect}" }
      end

      def province(id)
        @provinces_by_id.fetch(id) { raise InvalidInput, "unknown province #{id.inspect}" }
      end

      def coasts(province_id)
        province(province_id).coasts
      end

      def home_centers(power_id)
        @home_centers.fetch(power_id) { raise InvalidInput, "unknown power #{power_id.inspect}" }
      end

      # True when a unit of this type can move between the two locations in one step.
      # Arguments are checked first, so a malformed question raises instead of answering false.
      def adjacent?(unit_type, from, to)
        unless %i[army fleet].include?(unit_type)
          raise InvalidInput, "unit type must be :army or :fleet, got #{unit_type.inspect}"
        end

        from_key = lookup_key(unit_type, from, "from")
        to_key = lookup_key(unit_type, to, "to")
        table = unit_type == :army ? @armies : @fleets
        table.fetch(from_key, NO_NEIGHBORS).include?(to_key)
      end

      # Internal: not part of docs/interface.md, and may change in any release.
      # The units a game starts with, which Map#starting_position turns into a TA::Position.
      # Each entry is a frozen Hash with :power, :type and :location (a TA::Location).
      # Built on each call so that no Location is made while the map is loading.
      def starting_units
        @starting_units.map do |u|
          { power: u[:power], type: u[:type],
            location: Location.new(province: u[:province], coast: u[:coast]) }.freeze
        end.freeze
      end

      # The position the game starts from: spring 1901, the movement phase, each power's
      # units, and each power owning its own home centers. The neutral centers are absent
      # from ownership. Built on each call: the map is frozen, and Position and Unit load after it.
      def starting_position
        Position.new(
          map: id, season: :spring, year: 1901, phase: :movement,
          units: starting_units.map { |u| Unit.new(power: u[:power], type: u[:type], location: u[:location]) },
          ownership: @powers.each_with_object({}) do |power, owned|
            home_centers(power.id).each { |center| owned[center] = power.id }
          end,
          dislodged_units: [], standoffs: []
        )
      end

      private

      # An army is looked up by province alone. A fleet by province and coast.
      def lookup_key(unit_type, location, label)
        raise InvalidInput, "#{label} must be a TA::Location, got #{location.inspect}" unless location.is_a?(Location)

        if unit_type == :army
          raise InvalidInput, "an army location must not name a coast, got #{location.inspect}" if location.coast

          location.province
        else
          if location.coast.nil? && !province(location.province).coasts.empty?
            raise InvalidInput, "a fleet location on a split-coast province must name a coast, got #{location.inspect}"
          end

          [location.province, location.coast]
        end
      end

      # Last statement of the class body: everything it needs is defined above.
      @classic = from_file(DATA_PATH)
    end
  end
end

# frozen_string_literal: true

require "yaml"
require "set"

module Trucebearer
  module Adjudicator
    # The map: provinces, powers and what touches what. Query-only, never stored.
    # Built once from data/maps/classic.yml when this file is required.
    class Map
      Power = Data.define(:id, :name)
      Province = Data.define(:id, :name, :type, :coasts, :supply_center, :home)

      DATA_PATH = File.expand_path("../../../data/maps/classic.yml", __dir__)

      class << self
        # The classic map. Takes no path: the gem has one map, built in. The loader
        # and the constructor are private, so there is no way to load another file.
        attr_reader :classic

        private

        def from_file(path)
          raw = YAML.safe_load_file(path, permitted_classes: [], aliases: false)
          new(
            id: raw["map"],
            powers: raw["powers"].map { |p| Power.new(id: p["id"].to_sym, name: p["name"]) },
            provinces: raw["provinces"].map { |p| build_province(p) }
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
      end

      private_class_method :new

      attr_reader :id, :powers, :provinces, :supply_centers

      def initialize(id:, powers:, provinces:)
        @id = id.freeze
        @powers = powers.sort_by(&:id).freeze
        @provinces = provinces.sort_by(&:id).freeze
        @powers_by_id = @powers.to_h { |power| [power.id, power] }.freeze
        @provinces_by_id = @provinces.to_h { |province| [province.id, province] }.freeze
        @supply_centers = @provinces.select(&:supply_center).map(&:id).freeze
        @home_centers = @powers.to_h do |power|
          [power.id, @provinces.select { |province| province.home == power.id }.map(&:id).freeze]
        end.freeze
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

      # Last statement of the class body: everything it needs is defined above.
      @classic = from_file(DATA_PATH)
    end
  end
end

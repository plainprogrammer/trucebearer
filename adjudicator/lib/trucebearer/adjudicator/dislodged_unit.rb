# frozen_string_literal: true

module Trucebearer
  module Adjudicator
    # A unit pushed out of its province, waiting to retreat. Carries no format.
    DislodgedUnit = Data.define(:unit, :attacker_from, :by_convoy) do
      def initialize(unit:, attacker_from:, by_convoy:)
        Shape.instance_of!(unit, Unit, "unit")
        Shape.symbol_of(attacker_from, Shape::PROVINCES, "attacker_from", "province")
        Shape.boolean!(by_convoy, "by_convoy")
        super
      end

      def to_h
        { "unit" => unit.to_h, "attacker_from" => attacker_from.to_s, "by_convoy" => by_convoy }
      end

      def self.from_h(hash)
        Shape.keys!(hash, %w[unit attacker_from by_convoy])
        new(unit: Unit.from_h(hash["unit"]),
            attacker_from: Shape.text_of(hash["attacker_from"], Shape::PROVINCES, "attacker_from", "province"),
            by_convoy: hash["by_convoy"])
      end
    end
  end
end

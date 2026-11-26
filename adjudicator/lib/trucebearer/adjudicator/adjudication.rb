# frozen_string_literal: true

module Trucebearer
  module Adjudicator
    # The result of adjudicating a phase. Storable: its hash form carries format.
    Adjudication = Data.define(:outcomes, :paradox, :position) do
      include Shape::Marshalable

      def initialize(outcomes:, paradox:, position:)
        list = Shape.list_of(outcomes, Outcome, "outcomes")
        Shape.boolean!(paradox, "paradox")
        Shape.instance_of!(position, Position, "position")
        Adjudication.check_list!(list)
        super(outcomes: list.dup.freeze, paradox: paradox, position: position)
      end

      def to_h
        { "format" => Shape::FORMAT, "outcomes" => outcomes.map(&:to_h), "paradox" => paradox, "position" => position.to_h }
      end

      def self.from_h(hash)
        Shape.format!(hash)
        Shape.keys!(hash, %w[format outcomes paradox position])
        new(outcomes: Shape.array!(hash["outcomes"], "outcomes").map { |outcome| Outcome.from_h(outcome) },
            paradox: Shape.boolean!(hash["paradox"], "paradox"),
            position: Position.from_h(hash["position"]))
      end

      # The impossible adjudications: a submitted outcome after an implied hold, implied holds
      # that are not in ascending order of province, and two submitted outcomes for one power
      # and province (adjudication refuses that input).
      def self.check_list!(list)
        submitted, implied = list.partition(&:submitted)
        first_implied = list.index { |outcome| !outcome.submitted }
        if first_implied && list[first_implied..].any?(&:submitted)
          raise InvalidInput, "an outcome of a submitted order comes after an implied hold"
        end
        Shape.unique!(submitted.map { |outcome| [outcome.order.power, outcome.order.at] },
                      "two submitted outcomes are for the same power and province")
        provinces = implied.map { |outcome| outcome.order.at }
        return if provinces.each_cons(2).all? { |a, b| a < b }

        raise InvalidInput, "implied holds must be in ascending order of province, got #{provinces.inspect}"
      end
    end
  end
end

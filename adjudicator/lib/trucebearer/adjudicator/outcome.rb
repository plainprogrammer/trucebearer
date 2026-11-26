# frozen_string_literal: true

module Trucebearer
  module Adjudicator
    # What happened to one order in an adjudicated phase. Carries no format of its own: it
    # only appears inside an Adjudication, and its order keeps the order's own format.
    Outcome = Data.define(:order, :result, :submitted, :dislodged) do
      include Shape::Marshalable

      def initialize(order:, result:, submitted:, dislodged:)
        unless Outcome::ALLOWED.key?(order.class)
          raise InvalidInput, "\"order\" must be one of the six order classes, got #{order.inspect}"
        end
        Shape.symbol_of(result, Outcome::RESULTS, "result", "result")
        Shape.boolean!(submitted, "submitted")
        Shape.boolean!(dislodged, "dislodged")
        Outcome.check_combination!(order, result, submitted, dislodged)
        super
      end

      def to_h
        { "order" => order.to_h, "result" => result.to_s, "submitted" => submitted, "dislodged" => dislodged }
      end

      def self.from_h(hash)
        Shape.keys!(hash, %w[order result submitted dislodged])
        new(order: Order.from_h(hash["order"]),
            result: Shape.text_of(hash["result"], Outcome::RESULTS, "result", "result"),
            submitted: Shape.boolean!(hash["submitted"], "submitted"),
            dislodged: Shape.boolean!(hash["dislodged"], "dislodged"))
      end

      # The impossible outcomes of docs/interface.md: a result the order class doesn't have,
      # a void order that is dislodged, an implied hold that is not a held Hold, and a
      # move that succeeded and was dislodged.
      def self.check_combination!(order, result, submitted, dislodged)
        unless Outcome::ALLOWED.fetch(order.class).include?(result)
          raise InvalidInput, "an order of class #{order.class.name.split("::").last} cannot have the result #{result.inspect}"
        end
        raise InvalidInput, "a void order cannot be dislodged" if result == :void && dislodged
        if !submitted && !(order.is_a?(Order::Hold) && result == :held)
          raise InvalidInput, "an implied hold is a Hold with the result :held, got #{order.inspect} with #{result.inspect}"
        end
        return unless result == :succeeded && dislodged

        raise InvalidInput, "a unit whose move succeeded cannot be dislodged"
      end
    end

    # The nine result symbols, in the order of docs/interface.md.
    Outcome::RESULTS = %i[void held no_route bounced succeeded unmatched cut given disrupted].freeze

    # Which results each order class can have (docs/interface.md `### Outcomes`).
    Outcome::ALLOWED = {
      Order::Hold => %i[void held],
      Order::Move => %i[void no_route bounced succeeded],
      Order::MoveViaConvoy => %i[void no_route bounced succeeded],
      Order::SupportHold => %i[void unmatched cut given],
      Order::SupportMove => %i[void unmatched cut given],
      Order::Convoy => %i[void unmatched disrupted given]
    }.freeze
  end
end

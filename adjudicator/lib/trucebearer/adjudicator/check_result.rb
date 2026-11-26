# frozen_string_literal: true

module Trucebearer
  module Adjudicator
    # The answer to checking one order. Storable: its hash form carries format.
    # A legal result has no reasons. An illegal one has exactly one.
    CheckResult = Data.define(:legal, :reasons) do
      include Shape::Marshalable

      def initialize(legal:, reasons:)
        Shape.boolean!(legal, "legal")
        list = Shape.array!(reasons, "reasons")
        list.each { |reason| Shape.symbol_of(reason, CheckResult::REASONS, "reason", "rejection-reason") }
        if legal && !list.empty?
          raise InvalidInput, "a legal result has no reasons, got #{list.inspect}"
        elsif !legal && list.size != 1
          raise InvalidInput, "an illegal result has exactly one reason, got #{list.inspect}"
        end

        super(legal: legal, reasons: list.dup.freeze)
      end

      def to_h
        { "format" => Shape::FORMAT, "legal" => legal, "reasons" => reasons.map(&:to_s) }
      end

      def self.from_h(hash)
        Shape.format!(hash)
        Shape.keys!(hash, %w[format legal reasons])
        new(legal: Shape.boolean!(hash["legal"], "legal"),
            reasons: Shape.array!(hash["reasons"], "reasons").map do |reason|
              Shape.text_of(reason, CheckResult::REASONS, "reasons", "rejection-reason")
            end)
      end
    end

    # Every rejection reason, in the order of the tables in docs/interface.md. Internal:
    # the contract is the document, and a spec keeps the two equal.
    CheckResult::REASONS = %i[
      wrong_phase no_such_unit foreign_unit
      own_province not_reachable coast_not_allowed coast_required coast_unreachable
      not_army not_adjacent no_convoy_route
      same_province no_unit move_impossible
      not_fleet_at_sea bad_endpoints not_on_chain
    ].freeze
  end
end

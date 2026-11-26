# frozen_string_literal: true

module Trucebearer
  module Adjudicator
    # A place on the board: a province and, for a split-coast province, optionally
    # a coast. `new` takes symbols, `from_h` takes strings. Checked against the
    # classic map when built. It carries no format (it only appears nested).
    Location = Data.define(:province, :coast) do
      def initialize(province:, coast: nil)
        raise InvalidInput, "province must be a Symbol, got #{province.inspect}" unless province.is_a?(Symbol)
        raise InvalidInput, "coast must be a Symbol or nil, got #{coast.inspect}" unless coast.nil? || coast.is_a?(Symbol)

        known = Map.classic.province(province)
        unless coast.nil? || known.coasts.include?(coast)
          raise InvalidInput, "province #{province.inspect} has no coast #{coast.inspect}"
        end

        super
      end

      def to_h
        { "province" => province.to_s, "coast" => coast&.to_s }
      end

      def self.from_h(hash)
        raise InvalidInput, "expected a Hash, got #{hash.inspect}" unless hash.is_a?(Hash)

        keys = %w[province coast]
        (keys - hash.keys).each { |key| raise InvalidInput, "missing key #{key.inspect}" }
        (hash.keys - keys).each { |key| raise InvalidInput, "unknown key #{key.inspect}" }
        province = hash["province"]
        coast = hash["coast"]
        raise InvalidInput, "\"province\" must be a String, got #{province.inspect}" unless province.is_a?(String)
        raise InvalidInput, "\"coast\" must be a String or nil, got #{coast.inspect}" unless coast.nil? || coast.is_a?(String)

        # Checked here, before any symbol is made, so the message shows the caller's own strings.
        known = Map.classic.provinces.find { |candidate| candidate.id.to_s == province }
        raise InvalidInput, "unknown province #{province.inspect}" unless known
        if coast && known.coasts.none? { |known_coast| known_coast.to_s == coast }
          raise InvalidInput, "province #{province.inspect} has no coast #{coast.inspect}"
        end

        new(province: province.to_sym, coast: coast&.to_sym)
      end
    end
  end
end

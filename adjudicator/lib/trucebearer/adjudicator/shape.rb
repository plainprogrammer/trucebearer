# frozen_string_literal: true

module Trucebearer
  module Adjudicator
    # Internal: the checks the value objects share. Not part of docs/interface.md,
    # and it may change in any release.
    module Shape
      # The one format value for the whole gem. It goes up whenever any hash form changes.
      FORMAT = 1

      SEASONS = %i[spring fall].freeze
      PHASES = %i[movement retreat adjustment].freeze
      UNIT_TYPES = %i[army fleet].freeze
      PROVINCES = Map.classic.provinces.map(&:id).freeze
      SUPPLY_CENTERS = Map.classic.supply_centers
      POWERS = Map.classic.powers.map(&:id).freeze

      module_function

      # `new` side: the value must be one of the allowed symbols.
      def symbol_of(value, allowed, name, noun)
        return value if allowed.include?(value)

        raise InvalidInput, "#{name.inspect} must be a #{noun} identifier (a Symbol), got #{value.inspect}"
      end

      # `from_h` side: the value must be the text of one of the allowed symbols. The
      # symbol returned is the existing one, so unchecked text never becomes a symbol.
      def text_of(value, allowed, name, noun)
        found = allowed.find { |candidate| candidate.to_s == value }
        return found if found

        raise InvalidInput, "#{name.inspect} must be a #{noun} identifier (a String), got #{value.inspect}"
      end

      def instance_of!(value, klass, name)
        return value if value.is_a?(klass)

        raise InvalidInput, "#{name.inspect} must be a #{klass}, got #{value.inspect}"
      end

      def integer!(value, name)
        return value if value.is_a?(Integer)

        raise InvalidInput, "#{name.inspect} must be an Integer, got #{value.inspect}"
      end

      def boolean!(value, name)
        return value if value == true || value == false

        raise InvalidInput, "#{name.inspect} must be true or false, got #{value.inspect}"
      end

      # The map identifier is the String "classic" in Ruby and in the hash form.
      # Returns a frozen copy, so the caller's string is never held or changed.
      def map!(value)
        unless value.is_a?(String) && value == "classic"
          raise InvalidInput, "\"map\" must be the String \"classic\", got #{value.inspect}"
        end

        -value
      end

      # Returns a new array, so the caller's array is never frozen or changed.
      def list_of(value, klass, name)
        array!(value, name).each { |element| instance_of!(element, klass, name) }.dup
      end

      def array!(value, name)
        raise InvalidInput, "#{name.inspect} must be an Array, got #{value.inspect}" unless value.is_a?(Array)

        value
      end

      def hash!(value, name)
        raise InvalidInput, "#{name} must be a Hash, got #{value.inspect}" unless value.is_a?(Hash)

        value
      end

      # A hash form has exactly these string keys.
      def keys!(hash, keys)
        hash!(hash, "hash form")
        (keys - hash.keys).each { |key| raise InvalidInput, "missing key #{key.inspect}" }
        (hash.keys - keys).each { |key| raise InvalidInput, "unknown key #{key.inspect}" }
      end

      # A storable hash form must carry the gem's format value. eql? so that 1.0 is refused.
      def format!(hash)
        hash!(hash, "hash form")
        raise InvalidInput, "missing key \"format\"" unless hash.key?("format")
        return if hash["format"].eql?(FORMAT)

        raise InvalidInput, "unknown format #{hash["format"].inspect}, expected #{FORMAT}"
      end

      def unique!(values, message)
        repeated = values.tally.find { |_, count| count > 1 }
        raise InvalidInput, "#{message} #{repeated.first.inspect}" if repeated
      end
    end
    private_constant :Shape
  end
end

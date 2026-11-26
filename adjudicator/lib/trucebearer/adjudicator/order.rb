# frozen_string_literal: true

module Trucebearer
  module Adjudicator
    # The six movement orders. Each is a Data class with the fields power and at
    # (a province field) first, then its own. Storable: the hash form carries format.
    module Order
      TYPES = {}

      def self.from_h(hash)
        Shape.hash!(hash, "order")
        raise InvalidInput, "missing key \"type\"" unless hash.key?("type")

        klass = TYPES[hash["type"]]
        raise InvalidInput, "unknown order type #{hash["type"].inspect}" unless klass

        klass.from_h(hash)
      end

      # Internal: builds one order class. Called only below.
      def self.define(type, *own_fields)
        klass = Data.define(:power, :at, *own_fields)
        klass.class_eval do
          include Shape::Marshalable
          define_method(:initialize) do |**given|
            super(**given)
            Order.validate!(self)
          end
          define_method(:to_h) { Order.hash_form(type, self) }
          define_singleton_method(:from_h) { |hash| Order.build(self, type, hash) }
        end
        TYPES[type] = klass
      end
      private_class_method :define

      # Internal: checks every field of a built order. The ordered unit and the
      # destination are the only fields that are not province fields.
      def self.validate!(order)
        order.class.members.each do |name|
          value = order.public_send(name)
          case name
          when :power then Shape.symbol_of(value, Shape::POWERS, "power", "power")
          when :destination then Shape.instance_of!(value, Location, "destination")
          else Shape.symbol_of(value, Shape::PROVINCES, name.to_s, "province")
          end
        end
      end

      # Internal: the hash form of an order, "format" and "type" first.
      def self.hash_form(type, order)
        fields = order.class.members.to_h do |name|
          value = order.public_send(name)
          [name.to_s, value.is_a?(Symbol) ? value.to_s : value.to_h]
        end
        { "format" => Shape::FORMAT, "type" => type }.merge(fields)
      end

      # Internal: the from_h every class shares. Checked in this order: format, type,
      # the key set, then each field in field order.
      def self.build(klass, type, hash)
        Shape.format!(hash)
        raise InvalidInput, "missing key \"type\"" unless hash.key?("type")
        raise InvalidInput, "expected order type #{type.inspect}, got #{hash["type"].inspect}" unless hash["type"] == type

        Shape.keys!(hash, %w[format type] + klass.members.map(&:to_s))
        values = klass.members.to_h { |name| [name, field_from(name, hash[name.to_s])] }
        klass.new(**values)
      end

      def self.field_from(name, value)
        case name
        when :power then Shape.text_of(value, Shape::POWERS, "power", "power")
        when :destination then Location.from_h(value)
        else Shape.text_of(value, Shape::PROVINCES, name.to_s, "province")
        end
      end

      Hold = define("hold")
      Move = define("move", :destination)
      MoveViaConvoy = define("move_via_convoy", :to)
      SupportHold = define("support_hold", :target)
      SupportMove = define("support_move", :from, :to)
      Convoy = define("convoy", :from, :to)

      TYPES.freeze
      private_constant :TYPES
    end
  end
end

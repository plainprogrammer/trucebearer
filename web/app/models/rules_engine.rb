require "trucebearer/adjudicator"

# The one door to the rules engine gem (spec 019). Every call to the gem is made here and nowhere
# else in the app. Callers get gem objects back, hand hash forms to the loaders, and never name a
# gem class. Before gem 0.2.0, adjudicate is answered by the stand-in at the end of this file.
module RulesEngine
  TA = Trucebearer::Adjudicator
  private_constant :TA

  # The gem's own error class under the app's constant: rescuing this catches what the gem raises.
  InvalidInput = TA::InvalidInput

  ORDER_CLASSES = [ TA::Order::Hold, TA::Order::Move, TA::Order::MoveViaConvoy,
                    TA::Order::SupportHold, TA::Order::SupportMove, TA::Order::Convoy ].freeze
  private_constant :ORDER_CLASSES

  class << self
    def starting_position = TA::Map.classic.starting_position

    def check(position, order) = TA.check(position, order)

    def legal_orders(position, unit) = TA.legal_orders(position, unit)

    # Each loader takes an object of its kind (returned as it is), a string-keyed hash (rebuilt with
    # from_h) or nil (returned as nil). Anything else raises InvalidInput naming the value.
    def load_position(value) = coerce(value, "position", TA::Position, ->(h) { TA::Position.from_h(h) })

    def load_order(value)
      coerce(value, "order", ->(v) { ORDER_CLASSES.any? { |c| c === v } }, ->(h) { TA::Order.from_h(h) })
    end

    def load_check_result(value) = coerce(value, "check result", TA::CheckResult, ->(h) { TA::CheckResult.from_h(h) })

    private

    def coerce(value, name, kind, build)
      return nil if value.nil?
      return value if kind === value
      raise InvalidInput, "a #{name} must be a #{name}, a Hash or nil, got #{value.inspect}" unless value.is_a?(Hash)

      build.call(value)
    end
  end
end

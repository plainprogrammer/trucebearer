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

    # The map's powers, each with an id (a symbol) and a name. The one place a power list comes from (spec 021 FR-12).
    def powers = TA::Map.classic.powers

    def check(position, order) = TA.check(position, order)

    # Whether an identifier names a province of the map. The one place a province list is read for the app (spec 022 AC-2.5).
    def province?(id) = province_ids.include?(id.to_s)

    # The full name of a province ("Liverpool"), for labels (spec 023 FR-3).
    def province_name(id) = TA::Map.classic.province(id.to_sym).name

    # Whether an army could walk between two provinces. It says a plain move of an army "needs a convoy" (spec 023 D3).
    def army_adjacent?(from, to)
      TA::Map.classic.adjacent?(:army, TA::Location.new(province: from.to_sym), TA::Location.new(province: to.to_sym))
    end

    def adjudicate(position, orders) = TA.adjudicate(position, orders)

    # STAND-IN, until gem 0.2.0 (#29): true while adjudicate is answered by the stand-in, so results views say they are practice results
    # (spec 025 D6). #29 deletes this with the stand-in and the note's partial.
    def stand_in? = true

    # The playtest's own rule for the phase that follows a reveal (spec 022 D3). It is not part of the stand-in: it stays
    # after #29 until 1.0 uses what gem 0.3.0 works out. Dislodged units leave the board, standoffs are cleared, and
    # ownership is kept. Spring becomes fall of the same year, and fall becomes spring of the next. The position must be the
    # retreat position an adjudication returns. The message names no order.
    def next_movement_position(position)
      unless position.is_a?(TA::Position) && position.phase == :retreat
        phase = position.respond_to?(:phase) ? position.phase.inspect : "none"
        raise InvalidInput, "the next phase is built from a retreat position, got #{position.class} with phase #{phase}"
      end

      season, year = position.season == :spring ? [ :fall, position.year ] : [ :spring, position.year + 1 ]
      TA::Position.new(map: position.map, season: season, year: year, phase: :movement, units: position.units,
                       ownership: position.ownership, dislodged_units: [], standoffs: [])
    end

    def legal_orders(position, unit) = TA.legal_orders(position, unit)

    # Each loader takes an object of its kind (returned as it is), a string-keyed hash (rebuilt with
    # from_h) or nil (returned as nil). Anything else raises InvalidInput naming the value.
    def load_position(value) = coerce(value, "position", TA::Position, ->(h) { TA::Position.from_h(h) })

    def load_order(value)
      coerce(value, "order", ->(v) { ORDER_CLASSES.any? { |c| c === v } }, ->(h) { TA::Order.from_h(h) })
    end

    def load_check_result(value) = coerce(value, "check result", TA::CheckResult, ->(h) { TA::CheckResult.from_h(h) })

    def load_adjudication(value) = coerce(value, "adjudication", TA::Adjudication, ->(h) { TA::Adjudication.from_h(h) })

    private

    def province_ids = @province_ids ||= TA::Map.classic.provinces.to_set { |province| province.id.to_s }

    def coerce(value, name, kind, build)
      return nil if value.nil?
      return value if kind === value
      raise InvalidInput, "a #{name} must be a #{name}, a Hash or nil, got #{value.inspect}" unless value.is_a?(Hash)

      build.call(value)
    end
  end
end

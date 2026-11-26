require "trucebearer/adjudicator"

# The one door to the rules engine gem (spec 019). Every call to the gem is made here and nowhere
# else in the app. Callers get gem objects back, hand hash forms to the loaders, and never name a
# gem class.
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

    # The playtest's own rule for the phase that follows a reveal (spec 022 D3). It stays until 1.0 uses what gem 0.3.0
    # works out. Dislodged units leave the board, standoffs are cleared, and ownership is kept. Spring becomes fall of the
    # same year, and fall becomes spring of the next. The position must be the retreat position an adjudication returns.
    # The message names no order.
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

  # ---- Editing a position (spec 027) ----
  # The host's hand edits of the open phase's position. Each builds a new position through the gem, which decides what is possible. A
  # refusal is explained from what the gem documents (the stage that raised, and the map's province types and coasts), never from the
  # text of its messages (spec 027 D5). One contiguous block, because #29 edits this file too.

  # A hand edit the gem refused or the app could not apply. The reason is a symbol of spec 027 D8 and the message is the symbol's
  # name: neither carries the gem's message, a position or an order.
  class EditRefused < StandardError
    attr_reader :reason

    def initialize(reason)
      @reason = reason
      super(reason.to_s)
    end
  end

  ProvinceInfo = Data.define(:id, :name, :coasts)

  module Editing
    def provinces = @provinces ||= TA::Map.classic.provinces.map { |p| ProvinceInfo.new(id: p.id.to_s, name: p.name, coasts: p.coasts.map(&:to_s)) }

    def supply_centers = @supply_centers ||= TA::Map.classic.supply_centers.map(&:to_s)

    def coasts = provinces.flat_map(&:coasts).uniq.sort

    def add_unit(position, power:, type:, province:, coast:)
      unit = build_unit(power, type, province, coast)
      rebuilt(position, units: position.units + [ unit ]) { taken?(position, province) ? :province_taken : :other }
    end

    def move_unit(position, from:, province:, coast:)
      old = unit_at(position, from)
      unit = build_unit(old.power.to_s, old.type.to_s, province, coast)
      rebuilt(position, units: position.units.reject { |u| u.equal?(old) } + [ unit ]) { taken?(position, province) ? :province_taken : :other }
    end

    def remove_unit(position, province:)
      old = unit_at(position, province)
      rebuilt(position, units: position.units.reject { |u| u.equal?(old) }) { :other }
    end

    # A nil power removes the entry (an unowned center is absent, interface.md "Position").
    def set_owner(position, center:, power:)
      text!(center)
      text!(power, nil_ok: true)
      raise EditRefused.new(:other) unless RulesEngine.province?(center) && (power.nil? || power?(power))

      ownership = position.ownership.dup
      power ? ownership[center.to_sym] = power.to_sym : ownership.delete(center.to_sym)
      rebuilt(position, ownership: ownership) { supply_centers.include?(center) ? :other : :not_a_center }
    end

    def set_date(position, season:, year:)
      text!(season)
      raise EditRefused.new(:other) unless year.is_a?(Integer)

      rebuilt(position, season: season.to_sym, year: year) { :other }
    end

    private

    # An argument that is not the text (or nil) it must be is a refusal, never a NoMethodError.
    def text!(value, nil_ok: false)
      raise EditRefused.new(:other) unless value.is_a?(String) || (nil_ok && value.nil?)
    end

    def power?(id) = RulesEngine.powers.any? { |power| power.id.to_s == id }

    def unit_at(position, province)
      text!(province)
      position.units.find { |u| u.location.province.to_s == province } || raise(EditRefused.new(:no_unit))
    end

    def taken?(position, province) = position.units.any? { |u| u.location.province.to_s == province }

    # Stage 0 (an unknown identifier) is :other; stage 1 builds the location; stage 2 builds the unit (spec 027 D5).
    def build_unit(power, type, province, coast)
      text!(power)
      text!(type)
      text!(province)
      text!(coast, nil_ok: true)
      raise EditRefused.new(:other) unless RulesEngine.province?(province) && power?(power) && %w[army fleet].include?(type)

      location = begin
        TA::Location.new(province: province.to_sym, coast: coast&.to_sym)
      rescue TA::InvalidInput
        raise EditRefused.new(coast ? :no_such_coast : :other)
      end
      begin
        TA::Unit.new(power: power.to_sym, type: type.to_sym, location: location)
      rescue TA::InvalidInput
        raise EditRefused.new(unit_reason(type, province, coast))
      end
    end

    def unit_reason(type, province, coast)
      info = TA::Map.classic.province(province.to_sym)
      if type == "army"
        return :army_at_sea if info.type == :sea
        return :army_coast if coast
      else
        return :fleet_inland if info.type == :inland
        return :fleet_needs_coast if coast.nil? && info.coasts.any?
      end
      :other
    end

    # Stage 3: the whole position. The block names the reason when the gem refuses it.
    def rebuilt(position, **changes)
      TA::Position.new(map: position.map, season: position.season, year: position.year, phase: position.phase, units: position.units,
                       ownership: position.ownership, dislodged_units: position.dislodged_units, standoffs: position.standoffs, **changes)
    rescue TA::InvalidInput
      raise EditRefused.new(yield)
    end
  end
  extend Editing
  private_constant :Editing
end

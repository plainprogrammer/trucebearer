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

    def adjudicate(position, orders) = StandIn.adjudicate(position, orders)

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

    def load_adjudication(value) = coerce(value, "adjudication", StandInAdjudication, ->(h) { StandInAdjudication.from_h(h) })

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

  RESULTS = %w[void held no_route bounced succeeded unmatched cut given disrupted].freeze
  OUTCOME_KEYS = %w[order result submitted dislodged].to_set.freeze
  ADJUDICATION_KEYS = %w[format outcomes paradox position].to_set.freeze
  private_constant :RESULTS, :OUTCOME_KEYS, :ADJUDICATION_KEYS

  # STAND-IN, until gem 0.2.0 (#29). Its outcomes are FAKE. It answers in the documented shape of
  # TA.adjudicate (interface.md, "Adjudicating a movement phase") and follows exactly these rules
  # (spec 019, FR-3):
  #  1. The position must be in the movement phase, and one power may not give two orders for units
  #     in the same province. Otherwise InvalidInput is raised.
  #  2. Each submitted order is checked with check. An order that fails is :void.
  #  3. A legal hold is :held. A legal support or convoy is :given. Supports and convoys have no
  #     other effect.
  #  4. A legal move (Move or MoveViaConvoy) targets a province (the move's destination, or the
  #     via-convoy move's to). Its result is found like this:
  #       1. Every legal move starts as :succeeded.
  #       2. Every move whose target is also the target of another legal move becomes :bounced.
  #       3. Repeat until nothing changes: a move that is still :succeeded becomes :bounced when its
  #          target province holds a unit that is not making a move that is still :succeeded.
  #     Each step only turns moves into bounces, so it ends, and it has one answer. Moves that swap
  #     two units, or rotate three or more, succeed. That is a fake result: under the real rules a
  #     swap bounces unless convoyed, and the real adjudicator in 0.2.0 corrects it. A convoy chain
  #     is not looked at.
  #  5. A unit stays when its order is a hold, a support, a convoy, is void, or is a bounced move. A
  #     unit with no legal order from its owner gets an implied hold.
  #  6. The outcome list is the submitted orders in the order given, then one implied hold per
  #     remaining unit sorted by province, submitted false. No outcome is dislodged. paradox is false.
  #  7. The next position keeps season, year and ownership, has phase :retreat, moves each unit whose
  #     move succeeded (an army keeps no coast, a fleet takes the destination's coast), has no
  #     dislodged units, and lists in standoffs, once each, every province that two or more legal
  #     moves targeted and that is empty afterward.
  #  8. The result's to_h is the documented form, with format 1.
  # No support is counted, no convoy route is worked out, no strength is compared, no unit is
  # dislodged. Only from_h validates a stand-in result (the gem's classes validate on construction).
  # At 0.2.0 delete this, and let adjudicate and load_adjudication call TA.
  StandInOutcome = Data.define(:order, :result, :submitted, :dislodged) do
    def self.from_h(hash)
      raise InvalidInput, "an outcome must be a Hash, got #{hash.inspect}" unless hash.is_a?(Hash)
      unless hash.keys.to_set == OUTCOME_KEYS
        raise InvalidInput, "an outcome needs exactly the keys #{OUTCOME_KEYS.to_a.inspect}, got #{hash.keys.inspect}"
      end
      unless RESULTS.include?(hash["result"])
        raise InvalidInput, "\"result\" must be one of #{RESULTS.inspect}, got #{hash["result"].inspect}"
      end
      %w[submitted dislodged].each do |key|
        raise InvalidInput, "#{key.inspect} must be true or false, got #{hash[key].inspect}" unless [ true, false ].include?(hash[key])
      end
      raise InvalidInput, "\"order\" must be a Hash, got #{hash["order"].inspect}" unless hash["order"].is_a?(Hash)

      new(order: RulesEngine.load_order(hash["order"]), result: hash["result"].to_sym,
          submitted: hash["submitted"], dislodged: hash["dislodged"])
    end

    def to_h = { "order" => order.to_h, "result" => result.to_s, "submitted" => submitted, "dislodged" => dislodged }
  end

  StandInAdjudication = Data.define(:outcomes, :paradox, :position) do
    def initialize(outcomes:, paradox:, position:) = super(outcomes: outcomes.dup.freeze, paradox: paradox, position: position)

    def self.from_h(hash)
      raise InvalidInput, "an adjudication must be a Hash, got #{hash.inspect}" unless hash.is_a?(Hash)
      unless hash.keys.to_set == ADJUDICATION_KEYS
        raise InvalidInput, "an adjudication needs exactly the keys #{ADJUDICATION_KEYS.to_a.inspect}, got #{hash.keys.inspect}"
      end
      raise InvalidInput, "\"format\" must be 1, got #{hash["format"].inspect}" unless hash["format"] == 1
      raise InvalidInput, "\"outcomes\" must be an Array, got #{hash["outcomes"].inspect}" unless hash["outcomes"].is_a?(Array)
      raise InvalidInput, "\"paradox\" must be true or false, got #{hash["paradox"].inspect}" unless [ true, false ].include?(hash["paradox"])
      raise InvalidInput, "\"position\" must be a Hash, got #{hash["position"].inspect}" unless hash["position"].is_a?(Hash)

      new(outcomes: hash["outcomes"].map { |h| StandInOutcome.from_h(h) }, paradox: hash["paradox"],
          position: RulesEngine.load_position(hash["position"]))
    end

    def to_h = { "format" => 1, "outcomes" => outcomes.map(&:to_h), "paradox" => paradox, "position" => position.to_h }
  end

  module StandIn
    MOVES = [ TA::Order::Move, TA::Order::MoveViaConvoy ].freeze
    SUPPORTS_AND_CONVOYS = [ TA::Order::SupportHold, TA::Order::SupportMove, TA::Order::Convoy ].freeze

    def self.adjudicate(position, orders)
      unless position.is_a?(TA::Position) && orders.is_a?(Array)
        raise InvalidInput, "adjudicate needs a position and an Array of orders, got #{position.class} and #{orders.class}"
      end
      raise InvalidInput, "the phase must be :movement, got #{position.phase.inspect}" unless position.phase == :movement

      legal = orders.map { |order| TA.check(position, order).legal }
      reject_duplicates(orders)
      units = position.units.to_h { |u| [ u.location.province, u ] }
      followed = orders.zip(legal).select(&:last).map(&:first)
      implied = units.values.reject { |u| followed.any? { |o| o.at == u.location.province } }
                     .sort_by { |u| u.location.province }
                     .map { |u| TA::Order::Hold.new(power: u.power, at: u.location.province) }

      targets = followed.select { |o| MOVES.any? { |c| c === o } }.to_h { |o| [ o.at, target_of(o) ] }
      succeeded = surviving_moves(targets, units)

      outcomes = orders.zip(legal).map { |order, ok| outcome(order, ok ? result_for(order, succeeded) : :void, true) } +
                 implied.map { |order| outcome(order, :held, false) }
      StandInAdjudication.new(outcomes: outcomes, paradox: false, position: next_position(position, targets, succeeded))
    end

    def self.reject_duplicates(orders)
      twice = orders.group_by { |o| [ o.power, o.at ] }.find { |_, list| list.size > 1 }
      raise InvalidInput, "#{twice.first.first} gave #{twice.last.size} orders for the unit in #{twice.first.last}" if twice
    end

    def self.target_of(order)
      order.is_a?(TA::Order::Move) ? order.destination : TA::Location.new(province: order.to)
    end

    # Rule 4: start with every move succeeding, bounce contested targets, then repeat bouncing any
    # move whose target holds a unit not making a move that still succeeds, until nothing changes.
    def self.surviving_moves(targets, units)
      succeeded = targets.keys.to_set
      contested = targets.group_by { |_, loc| loc.province }.select { |_, list| list.size > 1 }.keys
      succeeded.reject! { |from| contested.include?(targets[from].province) }
      loop do
        blocked = succeeded.select { |from| units.key?(targets[from].province) && !succeeded.include?(targets[from].province) }
        break if blocked.empty?

        succeeded.subtract(blocked)
      end
      succeeded
    end

    def self.result_for(order, succeeded)
      case order
      when TA::Order::Hold then :held
      when *SUPPORTS_AND_CONVOYS then :given
      else succeeded.include?(order.at) ? :succeeded : :bounced
      end
    end

    def self.outcome(order, result, submitted) = StandInOutcome.new(order: order, result: result, submitted: submitted, dislodged: false)

    def self.next_position(position, targets, succeeded)
      units = position.units.map do |unit|
        from = unit.location.province
        succeeded.include?(from) ? TA::Unit.new(power: unit.power, type: unit.type, location: targets[from]) : unit
      end
      occupied = units.map { |u| u.location.province }
      contested = targets.values.group_by(&:province).select { |_, list| list.size > 1 }.keys
      TA::Position.new(map: position.map, season: position.season, year: position.year, phase: :retreat, units: units,
                       ownership: position.ownership, dislodged_units: [], standoffs: contested - occupied)
    end

    private_class_method :reject_duplicates, :target_of, :surviving_moves, :result_for, :outcome, :next_position
  end
  private_constant :StandIn, :StandInOutcome, :StandInAdjudication
end

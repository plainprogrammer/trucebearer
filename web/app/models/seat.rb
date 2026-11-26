# One power held by one phone. The token is never kept, only its digest (spec D2).
class Seat < ApplicationRecord
  belongs_to :game
  has_many :saved_orders, dependent: :destroy
  has_many :submissions, dependent: :destroy

  class Refusal < StandardError; end # the message is the sentence the player sees
  class Stale < StandardError; end # the seat's token digest changed while a save was running (spec 022 D9)

  # %{unit} is "the army in LON" and %{Unit} is "The army in LON": the unit's type and province (spec 022 FR-5).
  REASONS = {
    wrong_phase: "Orders can only be given in a movement phase.", no_such_unit: "%{Unit} isn't on the board.",
    foreign_unit: "%{Unit} isn't yours.", own_province: "%{Unit} can't be ordered to its own province.",
    not_reachable: "%{Unit} can't reach there.", coast_not_allowed: "%{Unit} can't name a coast.",
    coast_required: "%{Unit} must name a coast to move there.", coast_unreachable: "%{Unit} can't reach that coast.",
    not_army: "%{Unit} can't move by convoy; only an army can.", not_adjacent: "%{Unit} can't reach there by land.",
    no_convoy_route: "There is no convoy route for %{unit}.", same_province: "A support by %{unit} can't start and end in the same province.",
    no_unit: "There is no suitable unit for %{unit} to support or convoy.", move_impossible: "%{Unit} can't support that move: the unit there couldn't make it.",
    not_fleet_at_sea: "%{Unit} isn't a fleet at sea, so it can't convoy.", bad_endpoints: "%{Unit} can't convoy between those provinces.",
    not_on_chain: "%{Unit} isn't part of a convoy route for that move."
  }.freeze
  GENERIC = "That order isn't legal.".freeze
  UNREADABLE = "That order couldn't be read.".freeze

  Saved = Data.define(:changed, :submitted)

  # This seat's own orders for a phase, { "lon" => order }. With save_orders! and clear_orders!, the only way anything
  # outside Phase reads or writes saved orders (spec 022 FR-9).
  def orders_for(phase) = saved_orders.where(phase_id: phase.id).to_h { |row| [ row.province, row.content ] }

  def submitted?(phase) = submissions.exists?(phase_id: phase.id)

  # How many units this seat has an order for, without reading or parsing the orders.
  def ordered_count(phase) = saved_orders.where(phase_id: phase.id).count

  # Saves a set of orders and, if asked, marks the seat submitted. entries is { province => the order's JSON text, or a
  # blank to clear that unit's order }; provinces not named keep what they have. All of one call is one transaction,
  # and either every change is stored or none is (spec 022 FR-2, D4, D8).
  def save_orders!(phase, entries, submit: false)
    Phase.transaction do
      phase.lock!
      raise Phase::Revealed unless phase.open?
      raise Stale unless Seat.exists?(id: id, token_digest: token_digest)

      parsed = entries.to_h do |province, text|
        unit = own_unit_at(phase, province.to_s) # every key is checked, a blank value included
        [ province.to_s, clearing?(text) ? nil : read_order(phase, province.to_s, text.to_s, unit) ]
      end
      stored = orders_for(phase)
      changed = false
      parsed.each do |province, order|
        if order.nil?
          changed |= saved_orders.where(phase_id: phase.id, province: province).destroy_all.any?
        elsif stored[province] != order
          row = saved_orders.find_or_initialize_by(phase_id: phase.id, province: province)
          row.content = order
          row.save!
          changed = true
        end
      end
      submissions.where(phase_id: phase.id).destroy_all if changed
      submissions.find_or_create_by!(phase_id: phase.id) if submit
      Saved.new(changed: changed, submitted: submitted?(phase))
    end
  end

  # Deletes this seat's saved orders and its submission for the phase (a reissue, spec 022 D9). The caller holds the phase lock.
  def clear_orders!(phase)
    removed = saved_orders.where(phase_id: phase.id).destroy_all + submissions.where(phase_id: phase.id).destroy_all
    raise Phase::Revealed unless removed.all?(&:destroyed?) # a guard refused: the phase was revealed under us
  end

  # Uniqueness is the database's job: the index on [game_id, power] is the only arbiter of "taken".
  validates :power, inclusion: { in: ->(_seat) { RulesEngine.powers.map { |power| power.id.to_s } } }

  private

  def clearing?(text) = text.to_s.strip.empty?

  # The seat's own unit in a province, or a refusal: a key that is not a province is unreadable, and a province where the
  # seat has no unit gets the same sentence whether it is empty or held by another power. The message echoes only a key
  # already known to be a province.
  def own_unit_at(phase, province)
    raise Refusal, UNREADABLE unless province.match?(/\A[a-z]{3}\z/) && RulesEngine.province?(province)

    unit = phase.position.units.find { |candidate| candidate.location.province.to_s == province && candidate.power.to_s == power }
    raise Refusal, "You have no unit in #{province.upcase}." unless unit

    unit
  end

  # The refusals in the order of FR-2: the key and unit (own_unit_at), then readable, then `at`, then power, then the check. A message never
  # carries what was sent, only the province key once it has been checked to be a province.
  def read_order(phase, province, text, unit)
    order = begin
      RulesEngine.load_order(JSON.parse(text))
    rescue JSON::ParserError, RulesEngine::InvalidInput
      raise Refusal, UNREADABLE
    end
    raise Refusal, UNREADABLE unless order && order.at.to_s == province
    raise Refusal, "That order isn't for your power." unless order.power.to_s == power

    check = RulesEngine.check(phase.position, order)
    return order if check.legal

    named = { unit: "the #{unit.type} in #{province.upcase}", Unit: "The #{unit.type} in #{province.upcase}" }
    raise Refusal, format(REASONS.fetch(check.reasons.first, GENERIC), **named)
  end
end

require_relative "rules_helpers"

# Builds the stored result of a revealed phase from hash forms, for the specs of spec 025. One builder sets both the outcomes' dislodged
# flags and the position's dislodged units, so a banner count and a tag count can be compared (spec 025 AC-2.2).
module ResultsFixtures
  include RulesHelpers

  # outcomes: [[order_hash, result, submitted, dislodged], ...]; dislodged: [[power, type, province], ...] for the position after the phase.
  # It obeys the gem's "Impossible objects" rules: a result that suits its order class, no dislodged void order, submitted outcomes before
  # implied holds, implied holds sorted by province. Returns the phase, revealed, with the next phase opened.
  def revealed_phase_with(game, outcomes:, dislodged: [], paradox: false, units: nil)
    phase = game.current_phase
    phase.update_columns(position: rules_position(units: units)) if units
    phase.reload
    after = phase.position.to_h.merge(
      "phase" => "retreat",
      "dislodged_units" => dislodged.map do |power, type, province|
        { "unit" => unit_hash(power, type, province), "attacker_from" => "bul", "by_convoy" => false }
      end
    )
    hash = { "format" => 1, "paradox" => paradox, "position" => after,
             "outcomes" => outcomes.map { |order, result, submitted, flag| { "order" => order, "result" => result.to_s, "submitted" => submitted, "dislodged" => flag } } }
    # One update_columns call sets both columns the check constraint ties together; the column's own type serialises the loaded result.
    phase.update_columns(adjudication: RulesEngine.load_adjudication(hash), revealed_at: Time.current)
    game.phases.create!(number: phase.number + 1, position: phase.position)
    phase.reload
  end

  # Reveals a phase from a position and orders, the way the host would (spec 029 D4): the open phase's position is set from
  # units ([[power, type, province], ...]), each power's orders are saved through its seat (the seat is taken when the game has
  # none), and Phase#reveal! adjudicates them. orders: [[type, power, at, {extra fields}], ...]. Returns the revealed phase.
  def reveal_position!(game, units:, orders:)
    phase = game.current_phase
    phase.update_columns(position: rules_position(units: units))
    phase.reload
    orders.map { |type, power, at, rest| rules_order(type, power, at, **(rest || {})) }
          .group_by { |order| order.to_h["power"] }.each do |power, list|
      seat = game.seats.find_by(power: power) || game.take_seat!(power).first
      seat.save_orders!(phase, list.to_h { |order| [ order.to_h["at"], json_of(order) ] }, submit: true)
    end
    phase.reveal!
    phase.reload
  end
end

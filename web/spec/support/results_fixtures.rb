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
end

# The words of our own for what became of an order (spec 025 D6). Keyed by the gem's documented result symbols as text (the hash form),
# and "dislodged" for the flag. Read with fetch, so a symbol the table lacks fails loudly in the suite, never silently on a phone.
module OutcomeHelper
  OUTCOME_WORDS = {
    "succeeded" => "Succeeded", "bounced" => "Bounced", "no_route" => "No route", "held" => "Held", "given" => "Given",
    "cut" => "Support cut", "unmatched" => "Not used", "disrupted" => "Convoy disrupted", "void" => "Not a legal order",
    "dislodged" => "Dislodged"
  }.freeze

  def outcome_words(kind) = OUTCOME_WORDS.fetch(kind.to_s)

  # The tags a row shows, in order: Dislodged first, then its result, except that "Held" beside "Dislodged" reads as a contradiction.
  def outcome_tags(row)
    return [ row.result ] unless row.dislodged

    [ "dislodged", *(row.result == "held" ? [] : [ row.result ]) ]
  end
end

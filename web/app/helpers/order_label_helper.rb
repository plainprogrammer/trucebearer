# Words for provinces and orders on the order screen and the picker (spec 023 FR-3). It reads an order's hash form, so it names
# no gem class.
module OrderLabelHelper
  COASTS = { "nc" => "north coast", "sc" => "south coast", "ec" => "east coast" }.freeze

  # "Liverpool (LVP)", the abbreviation in the mono face (spec 023 FR-3).
  def province_label(id)
    id = id.to_s
    safe_join([ RulesEngine.province_name(id), " (", tag.span(id.upcase, class: "mono"), ")" ])
  end

  # An order in words with full names. It is given the unit as well, because a move's hash has no unit type. The unit may be nil (a
  # result row for an order whose unit is not on the board, spec 025 D8): the move then has no "needs a convoy" remark.
  def order_words(order, unit)
    h = order.to_h
    case h["type"]
    when "hold" then "Hold"
    when "move" then move_words(h, unit)
    when "move_via_convoy" then safe_join([ "Move to ", province_label(h["to"]), " by convoy" ])
    when "support_hold" then safe_join([ "Support hold in ", province_label(h["target"]) ])
    when "support_move" then safe_join([ "Support ", province_label(h["from"]), " to ", province_label(h["to"]) ])
    when "convoy" then safe_join([ "Convoy ", province_label(h["from"]), " to ", province_label(h["to"]) ])
    end
  end

  private

  def move_words(h, unit)
    destination = h["destination"]
    parts = [ "Move to ", province_label(destination["province"]) ]
    parts << ", #{COASTS.fetch(destination["coast"])}" if destination["coast"]
    parts << ", needs a convoy" if unit&.type == :army && !RulesEngine.army_adjacent?(h["at"], destination["province"])
    safe_join(parts)
  end
end

# Words for an order, in the plain orders form (spec 022 D5). It reads the order's hash form, so it names no gem class.
module OrderLabelHelper
  COASTS = { "nc" => "north coast", "sc" => "south coast", "ec" => "east coast" }.freeze

  def order_label(order)
    h = order.to_h
    case h["type"]
    when "hold" then "Hold"
    when "move"
      coast = h["destination"]["coast"]
      "Move to #{h["destination"]["province"].upcase}#{" (#{COASTS.fetch(coast)})" if coast}"
    when "move_via_convoy" then "Move to #{h["to"].upcase} by convoy"
    when "support_hold" then "Support hold in #{h["target"].upcase}"
    when "support_move" then "Support #{h["from"].upcase} to #{h["to"].upcase}"
    when "convoy" then "Convoy #{h["from"].upcase} to #{h["to"].upcase}"
    end
  end
end

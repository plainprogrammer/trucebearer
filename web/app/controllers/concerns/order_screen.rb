# What the orders endpoint, the order screen and the picker share (spec 023 FR-1, FR-2).
module OrderScreen
  extend ActiveSupport::Concern

  private

  # A phase of this game that exists and is not later than the open one. Anything else is the stranger response.
  def find_phase_or_stranger
    @phase = find_phase(@game)
    stranger!(@game) unless @phase && @phase.number <= @game.current_phase.number
  end

  def render_revealed = render("seat_orders/revealed", status: :conflict)

  # A page about a seat's own orders is never cached and never leaks its address (spec 022 AC-7.6, spec 023 AC-3.7).
  def own_orders_headers
    no_store
    response.set_header("Referrer-Policy", "no-referrer")
  end
end

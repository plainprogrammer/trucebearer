# What the orders endpoint, the order screen and the picker share (spec 023 FR-1, FR-2).
module OrderScreen
  extend ActiveSupport::Concern

  private

  # A phase of this game that exists and is not later than the open one. Anything else is the stranger response.
  def find_phase_or_stranger
    @phase = find_phase(@game)
    stranger!(@game) unless @phase && @phase.number <= @game.current_phase.number
  end

  # A GET for a revealed phase's own orders URL is sent to that phase's results (spec 025 D5), so a phone that was looking at its orders
  # when the host revealed lands on the results. A stepped-in URL keeps the 409 page (spec 026 AC-3.8), and a PUT keeps it too.
  def revealed_get
    return render_revealed if @stepped_in_page

    redirect_to game_seat_results_path(@game.public_id, @phase.number), status: :see_other
  end

  def render_revealed
    @step_in = nil # a refusal page has no bar (spec 026 D7); its link still follows the stepped-in URLs
    render("seat_orders/revealed", status: :conflict)
  end

  # A page about a seat's own orders is never cached and never leaks its address (spec 022 AC-7.6, spec 023 AC-3.7).
  def own_orders_headers
    no_store
    response.set_header("Referrer-Policy", "no-referrer")
  end
end

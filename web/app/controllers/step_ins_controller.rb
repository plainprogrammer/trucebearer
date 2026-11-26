# The host's confirmation page for stepping into a seat, the record, and leaving (spec 026 D9, D2).
class StepInsController < ApplicationController
  before_action :require_host
  before_action :find_seat, only: %i[show create]
  before_action :find_phase_or_redirect, only: %i[show create]

  def show; end

  def create
    row = StepIn.record!(phase: @phase, seat: @seat) # written before the redirect, so before any page shows an order (AC-2.1)
    remember_step_in(@game, row)
    redirect_to game_step_in_orders_path(@game.public_id, @seat.power, @phase.number), status: :see_other
  end

  # Leaving ends this browser's step-in. It always redirects, so a repeat is harmless (AC-3.5).
  def destroy
    cookies.delete(step_in_cookie_name(@game.public_id))
    redirect_to own_seat_target(@game), status: :see_other
  end

  private

  # A seat the game has that is not the host's own. Anything else is the stranger response (AC-1.5).
  def find_seat
    @seat = @game.seats.find_by(power: params[:power])
    stranger!(@game) unless @seat && @seat != @game.host_seat
  end

  # A later, unknown or malformed number is a stranger; a revealed one goes to the open phase's confirmation (AC-1.7).
  def find_phase_or_redirect
    @phase = find_phase(@game)
    current = @game.current_phase
    return stranger!(@game) unless @phase && @phase.number <= current.number
    return if @phase.open?

    flash[:banner] = { "kind" => "info", "text" => "That phase was already revealed. Check the new phase and confirm again." }
    redirect_to game_step_in_path(@game.public_id, @seat.power, current.number), status: :see_other
  end
end

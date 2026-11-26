# The host's confirmation page for stepping into a seat, the record, and leaving (spec 026 D9, D2).
class StepInsController < ApplicationController
  before_action :require_host
  # `only:` names actions that exist: the test environment raises on a callback for a missing action. Phase 2 adds create.
  before_action :find_seat, only: :show
  before_action :find_phase_or_redirect, only: :show

  def show; end

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

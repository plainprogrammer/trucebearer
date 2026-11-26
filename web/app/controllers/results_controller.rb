# One revealed phase's results for a seat, the player version (spec 025 D4, D5). An open, later or unknown phase is the stranger
# response, and the no-store header is set after that check, so the stranger response is the one everyone gets (D9).
class ResultsController < ApplicationController
  before_action :require_seat
  before_action :find_revealed_or_stranger
  before_action :no_store

  def show
    @results = PhaseResults.new(@phase)
  end

  private

  def find_revealed_or_stranger
    @phase = find_phase(@game)
    stranger!(@game) unless @phase && !@phase.open?
  end
end

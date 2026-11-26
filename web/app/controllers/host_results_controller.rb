# One revealed phase's results for the host, the reading view (spec 025 D4, D5, D8). The banners for dislodged units are drawn only
# for the latest revealed phase, because "settle it by hand" is no longer true of an earlier one.
class HostResultsController < ApplicationController
  before_action :require_host
  before_action :find_revealed_or_stranger
  before_action :no_store

  def show
    @results = PhaseResults.new(@phase)
    @latest = @phase == @game.history.last
  end

  private

  def find_revealed_or_stranger
    @phase = find_phase(@game)
    stranger!(@game) unless @phase && !@phase.open?
  end
end

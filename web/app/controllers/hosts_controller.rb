class HostsController < ApplicationController
  before_action :require_host
  before_action :no_store # the page can carry the orders of a revealed phase (spec 025 D9), and the host link once (spec 021 D6)

  def show
    @host_token = flash[:host_token]
    @seats = @game.seats.index_by(&:power)
    @phase = @game.current_phase
    latest = @game.history.last
    @results = latest && PhaseResults.new(latest)
  end
end

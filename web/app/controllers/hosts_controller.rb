class HostsController < ApplicationController
  before_action :require_host

  def show
    @host_token = flash[:host_token]
    @seats = @game.seats.index_by(&:power)
    no_store if @host_token # the one page that shows the host link, once (spec D6)
  end
end

class ClosingsController < ApplicationController
  before_action :require_host

  def show; end

  def create
    @game.close_joining! # does nothing when it is already closed (AC-6.5)
    redirect_to game_host_path(@game.public_id)
  end
end

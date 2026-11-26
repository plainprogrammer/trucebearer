class ReissuesController < ApplicationController
  before_action :require_host
  before_action :find_seat

  def show; end

  def create
    flash[:seat_token] = @game.reissue_seat!(@seat)
    redirect_to game_seat_qr_path(@game.public_id, @seat.power)
  end

  # The new code, shown once (spec D6). A reload finds no token and goes back to the host page.
  def qr
    @token = flash[:seat_token]
    return redirect_to(game_host_path(@game.public_id), notice: "That QR code is shown once. Reissue the seat to make a new one.") unless @token

    no_store
  end

  private

  def find_seat
    @seat = @game.seats.find_by(power: params[:power])
    stranger!(@game) unless @seat
  end
end

class SeatLinksController < ApplicationController
  before_action { response.set_header("Referrer-Policy", "no-referrer") }
  rate_limit to: 20, within: 1.minute, scope: :links, by: -> { client_key }, with: -> { too_many_tries }

  def show
    game = find_game
    return stranger!(game) unless game&.seat_for(params[:token])

    remember(:seat, game, params[:token])
    redirect_to game_path(game.public_id)
  end
end

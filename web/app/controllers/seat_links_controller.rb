class SeatLinksController < ApplicationController
  before_action { response.set_header("Referrer-Policy", "no-referrer") }
  rate_limit to: 20, within: 1.minute, scope: :links, by: -> { client_key }, with: -> { too_many_tries }

  def show
    game = find_game
    seat = game&.seat_for(params[:token])
    return stranger!(game) unless seat
    # A host browser never takes another seat's token (spec 026 D5): the link leads to the confirmation and nothing is stored.
    return redirect_to(game_step_in_path(game.public_id, seat.power, game.current_phase.number)) if host?(game) && seat != game.host_seat

    remember(:seat, game, params[:token])
    redirect_to game_path(game.public_id)
  end
end

class HostLinksController < ApplicationController
  # Declared before the rate limit, so a 429 carries it too, and every outcome looks alike (spec D4).
  before_action { response.set_header("Referrer-Policy", "no-referrer") }
  rate_limit to: 20, within: 1.minute, scope: :links, by: -> { client_key }, with: -> { too_many_tries }

  def show
    game = find_game
    return stranger!(game) unless game&.host_token?(params[:token])

    remember(:host, game, params[:token])
    redirect_to game_host_path(game.public_id)
  end
end

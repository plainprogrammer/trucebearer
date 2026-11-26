# The join code form and the join page (spec FR-1, FR-6, FR-7).
class JoinsController < ApplicationController
  NOT_OPEN = "That code doesn't match a game that is open for joining.".freeze

  rate_limit to: 30, within: 1.minute, scope: :join_lookup, name: "lookup", by: -> { client_key },
             with: -> { too_many_tries }, only: %i[create show]

  def index; end

  def create
    game = Game.open_by_code(params[:code])
    return not_open(:unprocessable_content) unless game

    redirect_to join_game_path(game.join_code)
  end

  def show
    @game = Game.open_by_code(params[:code])
    return not_open(:not_found) unless @game
    return redirect_to(game_path(@game.public_id)) if seat_of(@game)

    @taken = @game.seats.map(&:power)
  end

  private

  # One page and one message for an unknown code, a closed game's code and a malformed one (spec D4). It never echoes the code.
  def not_open(status)
    @error = NOT_OPEN
    render :index, status: status
  end
end

# Takes a power from the join page (spec FR-1, FR-7).
class JoinSeatsController < ApplicationController
  rate_limit to: 30, within: 1.minute, scope: :join_seat, by: -> { client_key }, with: -> { too_many_tries }

  def create
    game = Game.open_by_code(params[:code])
    return not_open unless game
    return redirect_to(game_path(game.public_id)) if seat_of(game)

    power = RulesEngine.powers.find { |candidate| candidate.id.to_s == params[:power].to_s }
    return tiles_error(game, "Pick one of the seven powers.") unless power

    _seat, token = game.take_seat!(power.id.to_s)
    remember(:seat, game, token)
    redirect_to game_path(game.public_id)
  rescue Game::SeatTaken
    tiles_error(game, "#{power.name} has been taken. Pick another.")
  rescue Game::NotOpen
    not_open
  end

  private

  def not_open
    @error = JoinsController::NOT_OPEN
    render "joins/index", status: :unprocessable_content
  end

  def tiles_error(game, message)
    @game = game
    @taken = game.seats.reload.map(&:power)
    @error = message
    render "joins/show", status: :unprocessable_content
  end
end

class GamesController < ApplicationController
  rate_limit to: 10, within: 5.minutes, scope: :games_create, by: -> { client_key }, with: -> { too_many_tries }, only: :create
  before_action :require_passphrase_set, only: %i[new create]

  def new; end

  def create
    # The comparison always runs, so a missing guess takes the same path (spec AC-1.7).
    return form_error("That passphrase isn't right.") unless Passphrase.correct?(params[:passphrase])

    power = RulesEngine.powers.find { |candidate| candidate.id.to_s == params[:power].to_s }
    return form_error("Pick one of the seven powers.") unless power

    started = Game.start!(power: power.id.to_s)
    remember(:host, started.game, started.host_token)
    remember(:seat, started.game, started.seat_token)
    flash[:host_token] = started.host_token
    redirect_to game_host_path(started.game.public_id)
  end

  def show
    @game = find_game
    @seat = @game && seat_of(@game)
    return stranger!(@game) unless @seat

    return if send_to_step_in(@game, @seat)

    load_step_in(@game)
    @host = host?(@game)
    @phase = @game.current_phase
    @units = @phase.position.units.count { |unit| unit.power.to_s == @seat.power }
    @ordered = @seat.ordered_count(@phase)
  end

  private

  def require_passphrase_set
    return if Passphrase.configured?

    Rails.logger.warn("#{Passphrase::ENV_NAME} is not set: creating games is refused")
    render "games/turned_off", status: :forbidden
  end

  def form_error(message)
    @error = message
    render :new, status: :unprocessable_content
  end
end

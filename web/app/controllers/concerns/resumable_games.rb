# The games this browser can resume, read from its cookies (spec 028 D2, D3). A cookie is only a claim: a game is listed only when
# the same signed-cookie and digest checks every game page uses accept it, and nothing is read about a game before that.
module ResumableGames
  extend ActiveSupport::Concern

  LIMIT = 40 # distinct ids examined, in the order the request sent them (D2)
  NAME = /\A(?:host|seat)_(.+)\z/

  Entry = Data.define(:game, :phase, :power, :host, :href)

  private

  def resumable_games
    ids = request.cookies.keys.filter_map { |name| name[NAME, 1] }.select { |id| id.match?(GameAccess::PUBLIC_ID_SHAPE) }.uniq.first(LIMIT)
    return [] if ids.empty?

    held = Game.includes(:seats).where(public_id: ids).filter_map do |game|
      host = host?(game)
      seat = seat_of(game)
      [ game, host, seat ] if host || seat
    end
    return [] if held.empty?

    phases = Phase.where(game_id: held.map { |game, *| game.id }, revealed_at: nil).index_by(&:game_id)
    held.sort_by { |game, *| [ -game.created_at.to_f, -game.id ] }.filter_map do |game, host, seat|
      phase = phases[game.id]
      next unless phase # a game with no open phase is dropped, never an error

      own = host ? (seat if seat == game.host_seat) : seat
      Entry.new(game: game, phase: phase, power: own&.power, host: host,
                href: host ? own_seat_target(game) : game_path(game.public_id))
    end
  end
end

# The date a game started, as the table reads it (spec 028 D4): in the zone StepInsHelper#table_zone names.
module GameCardsHelper
  def game_started(game)
    tag.time(game.created_at.in_time_zone(table_zone).strftime("%-d %b %Y"), datetime: game.created_at.utc.iso8601)
  end
end

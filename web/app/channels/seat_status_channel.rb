# The status stream's channel (spec 024 D1, D10). It does what Turbo::StreamsChannel does, and two things more: it accepts only the
# status stream of a game that exists, and it sends the subscriber the current seven rows as it subscribes, so a phone that woke
# or reconnected is not left on an old list. Both go through the signed name alone: the name is the capability (D4). The message is
# Game#seat_status_message, the one the broadcast sends; this class renders nothing and reads nothing else.
class SeatStatusChannel < Turbo::StreamsChannel
  NAME = /\Aseat_status:(?<id>#{Game::PUBLIC_ID_PATTERN})\z/

  def subscribed
    name = verified_stream_name_from_params
    match = name.is_a?(String) && NAME.match(name)
    game = match && Game.find_by(public_id: match[:id])
    return reject unless game

    stream_from name
    transmit game.seat_status_message
  end
end

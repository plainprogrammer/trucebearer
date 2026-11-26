# The results stream's channel (spec 024 D10, spec 025 D1). The pages' signed name is results:<public id>:<number>, the number being
# the phase the page was drawn for. The channel streams from the game's results stream (which is unchanged: results:<public id>) and,
# when that phase has been revealed by now, sends the reveal's own content-free refresh to this subscriber, so a phone that slept
# through the reveal is redrawn when it reconnects. A page that is current is sent nothing. The message is Game#results_refresh_message;
# this class renders nothing and reads the game and the phase's revealed time only.
class ResultsChannel < Turbo::StreamsChannel
  NAME = /\Aresults:(?<id>#{Game::PUBLIC_ID_PATTERN}):(?<number>[1-9]\d*)\z/

  def subscribed
    name = verified_stream_name_from_params
    match = name.is_a?(String) && NAME.match(name)
    game = match && Game.find_by(public_id: match[:id])
    phase = game && game.phases.find_by(number: match[:number].to_i)
    return reject unless phase

    stream_from "results:#{game.public_id}"
    transmit game.results_refresh_message if phase.revealed_at
  end
end

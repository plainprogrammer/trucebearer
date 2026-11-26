class Game < ApplicationRecord
  has_many :seats, dependent: :destroy

  class SeatTaken < StandardError; end
  class NotOpen < StandardError; end

  Started = Data.define(:game, :host_token, :seat_token)

  CODE_TRIES = 5

  # Makes a game and the host's seat in one step. A clash on the join code (or the public id) is retried (spec FR-3).
  def self.start!(power:)
    tries = 0
    begin
      transaction(requires_new: true) do
        host_token = Token.generate
        seat_token = Token.generate
        game = create!(public_id: SecureRandom.alphanumeric(12), host_token_digest: Token.digest(host_token),
                       join_code: JoinCode.generate)
        game.seats.create!(power: power, token_digest: Token.digest(seat_token))
        Started.new(game: game, host_token: host_token, seat_token: seat_token)
      end
    rescue ActiveRecord::RecordNotUnique
      tries += 1
      retry if tries < CODE_TRIES
      raise
    end
  end

  # The one open game that holds this code, or nil. Unknown, closed and malformed codes are all nil (spec D4).
  def self.open_by_code(input)
    code = JoinCode.normalize(input)
    code && where(joining_closed_at: nil).find_by(join_code: code)
  end

  def open? = joining_closed_at.nil?

  def close_joining!
    update!(joining_closed_at: Time.current) if open?
  end

  def host_token?(token) = Token.match?(token, host_token_digest)

  # Compares against every seat (seven at most) and never looks one up by digest (spec FR-2).
  def seat_for(token)
    seats.to_a.find { |seat| Token.match?(token, seat.token_digest) }
  end

  # Takes a power for a new phone. Returns [seat, token]. Joining is checked inside the transaction (spec FR-7).
  def take_seat!(power)
    token = Token.generate
    seat = transaction do
      raise NotOpen unless Game.where(id: id, joining_closed_at: nil).exists?

      seats.create!(power: power, token_digest: Token.digest(token))
    end
    [ seat, token ]
  rescue ActiveRecord::RecordNotUnique
    raise SeatTaken
  end

  # Replaces the seat's digest. The old token stops working with this write. Returns the new token.
  def reissue_seat!(seat)
    token = Token.generate
    seat.update!(token_digest: Token.digest(token))
    token
  end
end

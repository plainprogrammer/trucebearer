class Game < ApplicationRecord
  has_many :seats, dependent: :destroy
  # Declared after seats. No destroy path for a game exists today, and a game with a revealed phase could not be
  # destroyed anyway: a saved order of a revealed phase refuses to be destroyed (spec 022 AC-6.5).
  has_many :phases, -> { order(:number) }, dependent: :destroy

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
        game.phases.create!(number: 1, position: RulesEngine.starting_position)
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

  # The one phase that has not been revealed. Every game has one from the moment it is created (spec 022 FR-1).
  def current_phase = phases.find_by(revealed_at: nil)

  # The phases already revealed, oldest first.
  def history = phases.where.not(revealed_at: nil)

  # Tells every open seat page and host page which seats have submitted. One snapshot of the seven states, rendered from
  # Phase#seat_statuses and nothing else, on a stream of its own that only the seat and host pages subscribe to (spec 024
  # D1, D2, D4). It is the only place the app talks to the cable; spec/models/status_broadcast_scan_spec.rb enforces that. The
  # render is outside the rescue so a broken template raises everywhere; the cable call is inside it so a stored save is
  # never answered with an error (D7).
  def broadcast_seat_status
    html = ApplicationController.render(partial: "shared/seat_status", locals: { statuses: current_phase.seat_statuses })
    begin
      Turbo::StreamsChannel.broadcast_update_to(:seat_status, public_id, target: "seat-status", content: html,
                                                attributes: { method: :morph })
    rescue StandardError => error
      Rails.logger.warn("seat status broadcast failed: #{error.class}")
    end
  end

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

  # Replaces the seat's digest. The old token stops working with this write. The seat's saved orders and its submission for
  # the open phase go with it, so the host can't read them by opening the new seat link (spec 022 D9). The phase lock comes
  # first, as in a save, so a save from the old phone can't slip in between. Returns the new token.
  def reissue_seat!(seat)
    token = Token.generate
    withdrew = transaction do
      phase = phases.lock.find_by!(revealed_at: nil) # read under the lock, so a reveal can't slip in between
      seat.update!(token_digest: Token.digest(token))
      seat.clear_orders!(phase)
    end
    broadcast_seat_status if withdrew # the seat had submitted and no longer has (spec 024 D3)
    token
  end
end

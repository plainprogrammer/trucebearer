# One turn of a game (spec 022 D1). It is created with its starting position and stays open until the host reveals it.
# Season, year and phase type are read from the position, so they live in one place.
class Phase < ApplicationRecord
  belongs_to :game
  has_many :submissions, dependent: :destroy # who has submitted is the one per-seat fact the host may read

  attribute :position, RulesObjectType.position
  attribute :adjudication, RulesObjectType.adjudication

  Pending = Data.define(:power, :seated)

  def open? = revealed_at.nil?

  # "Spring 1901 · Movement". Capitals are drawn by the stylesheet.
  def title = "#{position.season.to_s.capitalize} #{position.year} · #{position.phase.to_s.capitalize}"

  # Every power that has not submitted, each with whether anyone holds its seat (spec AC-4.1, AC-4.13).
  def pending
    seats = game.seats.index_by(&:power)
    done = submissions.pluck(:seat_id).to_set
    RulesEngine.powers.filter_map do |power|
      seat = seats[power.id.to_s]
      Pending.new(power: power.id.to_s, seated: !seat.nil?) unless seat && done.include?(seat.id)
    end
  end
end

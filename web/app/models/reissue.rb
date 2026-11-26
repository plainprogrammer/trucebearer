# One time the host reissued a seat, in the phase that was open (spec 026 D10). It never changes and is never deleted. It holds no
# order, no count of orders, and nothing about the token.
class Reissue < ApplicationRecord
  belongs_to :phase
  belongs_to :seat

  validate { errors.add(:seat, "is not in this game") unless seat && phase && seat.game_id == phase.game_id }

  # A written row can't be changed or removed: update and destroy raise ActiveRecord::ReadOnlyRecord.
  def readonly? = persisted? || super

  def self.record!(phase:, seat:) = create!(phase: phase, seat: seat)

  def kind = :reissue
end

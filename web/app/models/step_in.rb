# One time the host confirmed entering another seat for a phase (spec 026 D1). The row is the record, and it is also what the
# step-in cookie names (D2). It never changes and is never deleted. It holds no order and no count of orders.
class StepIn < ApplicationRecord
  LIFETIME = 30.minutes

  belongs_to :phase
  belongs_to :seat

  validate { errors.add(:seat, "is not in this game") unless seat && phase && seat.game_id == phase.game_id }

  # A written row can't be changed or removed: update and destroy raise ActiveRecord::ReadOnlyRecord.
  def readonly? = persisted? || super

  def self.record!(phase:, seat:) = create!(phase: phase, seat: seat)

  def kind = :step_in

  # Active while the phase is still open (read from the database, so a reveal ends it at once) and for LIFETIME after entering (D2).
  def active? = created_at > LIFETIME.ago && Phase.open?(phase_id)
end

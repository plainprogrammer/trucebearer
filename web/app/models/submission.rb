# A row means the seat has marked itself submitted for the phase. It never locks anything (spec 022 FR-3).
class Submission < ApplicationRecord
  belongs_to :phase
  belongs_to :seat

  validate { errors.add(:phase, "is no longer open") unless Phase.open?(phase_id) }
  before_destroy { throw :abort unless Phase.open?(phase_id) }
end

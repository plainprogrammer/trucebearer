# A row means the seat has marked itself submitted for the phase. It never locks anything (spec 022 FR-3).
class Submission < ApplicationRecord
  belongs_to :phase
  belongs_to :seat
end

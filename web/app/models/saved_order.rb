# One order a seat has saved for one of its units in one phase (spec 022 D2). Only Seat and Phase use this model, and
# nothing may list every seat's saved orders before the reveal (spec 022 FR-9, checked by a source scan).
class SavedOrder < ApplicationRecord
  self.filter_attributes += [ :content ]

  belongs_to :phase
  belongs_to :seat

  attribute :content, RulesObjectType.order

  # An order can't be written or removed once its phase is revealed (spec 022 AC-6.5). The check reads the database, so
  # a phase object loaded before the reveal doesn't fool it.
  validate { errors.add(:phase, "is no longer open") unless Phase.open?(phase_id) }
  before_destroy { throw :abort unless Phase.open?(phase_id) }
end

# One power held by one phone. The token is never kept, only its digest (spec D2).
class Seat < ApplicationRecord
  belongs_to :game
  has_many :saved_orders, dependent: :destroy
  has_many :submissions, dependent: :destroy

  def submitted?(phase) = submissions.exists?(phase_id: phase.id)

  # Uniqueness is the database's job: the index on [game_id, power] is the only arbiter of "taken".
  validates :power, inclusion: { in: ->(_seat) { RulesEngine.powers.map { |power| power.id.to_s } } }
end

# One turn of a game (spec 022 D1). It is created with its starting position and stays open until the host reveals it.
# Season, year and phase type are read from the position, so they live in one place.
class Phase < ApplicationRecord
  belongs_to :game
  has_many :submissions, dependent: :destroy # who has submitted is the one per-seat fact the host may read

  attribute :position, RulesObjectType.position
  attribute :adjudication, RulesObjectType.adjudication

  # A revealed phase's position is what it was adjudicated from, so it can be replayed and never changes (spec 027 D7). reveal! writes
  # with update_all, which skips this.
  validate { errors.add(:position, "can't change after the reveal") if revealed_at_in_database && position_changed? }

  Pending = Data.define(:power, :seated)
  Status = Data.define(:power, :submitted) # one power's row in the status list (spec 024 FR-1)

  class Revealed < StandardError; end # the phase is no longer open
  class Conflict < StandardError; end # the reveal's conditional write changed no row (spec 022 D8, a backstop)

  # True while no reveal has been committed, read from the database and not from this object (spec 022 AC-6.5).
  def self.open?(id) = uncached { where(id: id, revealed_at: nil).exists? }

  def open? = revealed_at.nil?

  Reveal = Data.define(:status) # :revealed, or :already when an earlier request did it

  # The reveal (spec 022 FR-7, D8). The transaction's first statement is the lock; whoever gets it second finds the phase
  # revealed and changes nothing. In one step: adjudicate the stored orders of every seat through RulesEngine, store the
  # outcomes with the revealed time, and open the next phase. Any error rolls all of it back. Callers rescue
  # RulesEngine::InvalidInput.
  def reveal!
    status = transaction do
      lock!
      next :already unless open?

      orders = SavedOrder.joins(:seat).where(phase_id: id).order("seats.power", :province).map(&:content)
      result = RulesEngine.adjudicate(position, orders)
      upcoming = RulesEngine.next_movement_position(result.position)
      # A backstop: with the lock held this changes exactly one row. If it ever does not, the lock failed, so it is loud.
      changed = Phase.where(id: id, revealed_at: nil).update_all(adjudication: result, revealed_at: Time.current, updated_at: Time.current)
      raise Conflict unless changed == 1

      game.phases.create!(number: number + 1, position: upcoming)
      :revealed
    end
    reload
    if status == :revealed
      game.broadcast_seat_status # the new phase has no submissions (spec 024 D3)
      game.broadcast_results_refresh # and every phone reloads (spec 025 D3)
    end
    Reveal.new(status: status)
  end

  # "Spring 1901 · Movement". Capitals are drawn by the stylesheet.
  def title = "#{position.season.to_s.capitalize} #{position.year} · #{position.phase.to_s.capitalize}"

  # The seven powers in the gem's order, each with whether its seat has submitted. It reads seats and submissions only
  # (spec 024 D2): the one input of the status partial, and so of every message the status stream carries.
  def seat_statuses
    seats = game.seats.index_by(&:power)
    done = submissions.pluck(:seat_id).to_set
    RulesEngine.powers.map do |power|
      seat = seats[power.id.to_s]
      Status.new(power: power.id.to_s, submitted: !seat.nil? && done.include?(seat.id))
    end
  end

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

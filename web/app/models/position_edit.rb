# One hand edit of the open phase's position by the host (spec 027 D4). It never changes and is never deleted. It holds board facts
# only: no order, no count of orders, nothing about who had ordered.
class PositionEdit < ApplicationRecord
  SHAPES = {
    "unit_added" => %w[power type province coast], "unit_moved" => %w[power type from from_coast to to_coast],
    "unit_removed" => %w[power type province coast], "owner_set" => %w[center from to],
    "date_set" => %w[from_season from_year to_season to_year]
  }.freeze
  INTEGERS = %w[from_year to_year].freeze
  CLEARING = %w[unit_added unit_moved unit_removed].freeze

  Result = Data.define(:position, :detail)

  belongs_to :phase

  validate :detail_has_a_known_shape

  # A written row can't be changed or removed: update and destroy raise ActiveRecord::ReadOnlyRecord.
  def readonly? = persisted? || super

  def kind = :position_edit

  # Whether this edit moved units, which is what clears the seats' orders (spec 027 D3). It follows from the action alone.
  def clears_orders? = detail.is_a?(Hash) && CLEARING.include?(detail["action"])

  # The new position and the record's detail for one intent (a string-keyed hash: "action" and the host's choices). It asks
  # RulesEngine for the position and refuses what the engine refuses. Called by Game#edit_position! under the phase lock.
  def self.apply(position, intent)
    case intent["action"]
    when "unit_added" then added(position, intent)
    when "unit_moved" then moved(position, intent)
    when "unit_removed" then removed(position, intent)
    when "owner_set" then owner_set(position, intent)
    when "date_set" then date_set(position, intent)
    else raise RulesEngine::EditRefused.new(:other)
    end
  end

  def self.added(position, intent)
    new_position = RulesEngine.add_unit(position, power: intent["power"], type: intent["type"], province: intent["province"], coast: intent["coast"])
    Result.new(new_position, intent.slice("action", "power", "type", "province", "coast"))
  end

  def self.moved(position, intent)
    new_position = RulesEngine.move_unit(position, from: intent["from"], province: intent["to"], coast: intent["to_coast"])
    unit = unit_at(position, intent["from"]) # the engine found it, so it is there
    Result.new(new_position, { "action" => "unit_moved", "power" => unit.power.to_s, "type" => unit.type.to_s, "from" => intent["from"],
                               "from_coast" => unit.location.coast&.to_s, "to" => intent["to"], "to_coast" => intent["to_coast"] })
  end

  def self.removed(position, intent)
    new_position = RulesEngine.remove_unit(position, province: intent["province"])
    unit = unit_at(position, intent["province"])
    Result.new(new_position, { "action" => "unit_removed", "power" => unit.power.to_s, "type" => unit.type.to_s,
                               "province" => intent["province"], "coast" => unit.location.coast&.to_s })
  end

  def self.owner_set(position, intent)
    new_position = RulesEngine.set_owner(position, center: intent["center"], power: intent["to"])
    Result.new(new_position, { "action" => "owner_set", "center" => intent["center"],
                               "from" => position.ownership[intent["center"].to_sym]&.to_s, "to" => intent["to"] })
  end

  def self.date_set(position, intent)
    new_position = RulesEngine.set_date(position, season: intent["to_season"], year: intent["to_year"])
    Result.new(new_position, { "action" => "date_set", "from_season" => position.season.to_s, "from_year" => position.year,
                               "to_season" => intent["to_season"], "to_year" => intent["to_year"] })
  end

  def self.unit_at(position, province) = position.units.find { |unit| unit.location.province.to_s == province }

  private_class_method :added, :moved, :removed, :owner_set, :date_set, :unit_at

  private

  def detail_has_a_known_shape
    keys = SHAPES[detail.is_a?(Hash) ? detail["action"] : nil]
    return errors.add(:detail, "is not one of the five shapes") unless keys && detail.keys.sort == ([ "action" ] + keys).sort

    bad = detail.reject { |key, value| key == "action" || value.nil? || (INTEGERS.include?(key) ? value.is_a?(Integer) : value.is_a?(String)) }
    errors.add(:detail, "holds a value of the wrong kind") if bad.any?
  end
end

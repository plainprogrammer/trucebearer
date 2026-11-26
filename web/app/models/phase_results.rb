# What a revealed phase looks like to a reader (spec 025 FR-1). It reads the stored adjudication's hash form and the phase's starting
# position's hash form, and nothing else: no gem class, no saved order, no computed outcome. So a result from gem 0.2.0 draws the same.
class PhaseResults
  UnitRef = Data.define(:type)
  Row = Data.define(:order, :power, :province, :unit, :result, :submitted, :dislodged)
  Group = Data.define(:power, :rows) { def dislodged? = rows.any?(&:dislodged) }
  Banner = Data.define(:power, :unit_type, :province)

  attr_reader :phase

  def initialize(phase)
    raise ArgumentError, "results are only for a revealed phase" if phase.open?

    @phase = phase
    @hash = phase.adjudication.to_h
  end

  def paradox? = @hash["paradox"] == true

  # Powers in the gem's order. Within a group, dislodged rows come first and the rest keep the order the result gives them.
  def groups
    @groups ||= begin
      by_power = rows.group_by(&:power)
      RulesEngine.powers.map { |power| power.id.to_s }.filter_map do |id|
        list = by_power[id]
        next unless list

        Group.new(power: id, rows: list.each_with_index.sort_by { |row, index| [ row.dislodged ? 0 : 1, index ] }.map(&:first))
      end
    end
  end

  # The host's reading order: groups holding a dislodged unit first (spec 025 D8).
  def reading_groups = groups.each_with_index.sort_by { |group, index| [ group.dislodged? ? 0 : 1, index ] }.map(&:first)

  # From the stored position's dislodged units, which is the authority for the host's warnings (spec 025 D8).
  def banners
    @hash.dig("position", "dislodged_units").map do |entry|
      unit = entry.fetch("unit")
      Banner.new(power: unit["power"], unit_type: unit["type"], province: unit.dig("location", "province"))
    end
  end

  private

  def rows
    @rows ||= @hash["outcomes"].map do |outcome|
      order = outcome["order"]
      unit = starting_units[order["at"]]
      ref = unit && unit["power"] == order["power"] ? UnitRef.new(type: unit["type"].to_sym) : nil
      Row.new(order: order, power: order["power"], province: order["at"], unit: ref, result: outcome["result"],
              submitted: outcome["submitted"], dislodged: outcome["dislodged"])
    end
  end

  def starting_units = @starting_units ||= phase.position.to_h["units"].to_h { |unit| [ unit.dig("location", "province"), unit ] }
end

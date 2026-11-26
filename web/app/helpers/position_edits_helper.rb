# Words and lists for the position editor (spec 027 D8, AC-6.3): the sentences of a refusal, the record of a change in words, and the
# options of the forms. The lists come from RulesEngine, so no map is written here.
module PositionEditsHelper
  def refusal_text(reason, province: nil, coast: nil)
    name = RulesEngine.provinces.find { |info| info.id == province }&.name || "That province"
    coast_name = coast_label(coast).delete_suffix(" coast")
    { army_at_sea: "An army can't stand in #{name}: it is a sea province.", fleet_inland: "A fleet can't stand in #{name}: it is inland.",
      fleet_needs_coast: "A fleet in #{name} must say which coast it is on.", army_coast: "An army doesn't stand on a coast. Leave the coast blank.",
      no_such_coast: "#{name} has no #{coast_name} coast.", province_taken: "#{name} already holds a unit. A province holds one unit.",
      not_a_center: "#{name} is not a supply center.", no_change: "That is already the position." }
      .fetch(reason, "That isn't possible on the map.")
  end

  # The record of one change as plain text (spec 027 AC-6.3): "France's army added in BUR", "Italy's fleet moved from NAP to ION".
  def position_edit_text(detail)
    case detail["action"]
    when "unit_added" then "#{unit_words(detail)} added in #{spot(detail['province'], detail['coast'])}"
    when "unit_moved" then "#{unit_words(detail)} moved from #{spot(detail['from'], detail['from_coast'])} to #{spot(detail['to'], detail['to_coast'])}"
    when "unit_removed" then "#{power_name(detail['power'])}'s #{detail['type']} in #{spot(detail['province'], detail['coast'])} removed"
    when "owner_set"
      detail["to"] ? "#{detail['center'].upcase} given to #{power_name(detail['to'])}" : "#{detail['center'].upcase} set to nobody"
    when "date_set"
      "season and year set from #{detail['from_season'].capitalize} #{detail['from_year']} to #{detail['to_season'].capitalize} #{detail['to_year']}"
    end
  end

  def province_options = RulesEngine.provinces.sort_by(&:name).map { |info| [ "#{info.name} (#{info.id.upcase})", info.id ] }

  def power_options = RulesEngine.powers.map { |power| [ power.name, power.id.to_s ] }

  def coast_options = [ [ "No coast", "" ] ] + RulesEngine.coasts.map { |id| [ coast_label(id).capitalize, id ] }

  def center_options = RulesEngine.supply_centers.map { |id| [ "#{RulesEngine.province_name(id)} (#{id.upcase})", id ] }.sort_by(&:first)

  # What the board page groups: the units of one power, in province order.
  def units_of(position, power) = position.units.select { |unit| unit.power.to_s == power }

  def centers_of(position, power)
    position.ownership.select { |_center, owner| owner.to_s == power }.keys.map(&:to_s).sort
  end

  def unowned_centers(position) = RulesEngine.supply_centers - position.ownership.keys.map(&:to_s)

  private

  def unit_words(detail) = "#{power_name(detail['power'])}'s #{detail['type']}"

  def spot(province, coast) = coast ? "#{province.upcase} (#{coast_label(coast)})" : province.upcase

  def coast_label(id, fallback = "that coast") = OrderLabelHelper::COASTS.fetch(id.to_s, fallback)
end

# Builds rules objects from hand-written, string-keyed hash forms, so specs need no gem constants.
module RulesHelpers
  # units: [[power, type, province, coast_or_nil], ...]
  def rules_position(units:, ownership: {}, season: "spring", year: 1901, phase: "movement", standoffs: [])
    RulesEngine.load_position(
      "format" => 1, "map" => "classic", "season" => season, "year" => year, "phase" => phase,
      "units" => units.map { |power, type, province, coast| unit_hash(power, type, province, coast) },
      "ownership" => ownership.transform_keys(&:to_s).transform_values(&:to_s),
      "dislodged_units" => [], "standoffs" => standoffs.map(&:to_s)
    )
  end

  def unit_hash(power, type, province, coast = nil)
    { "power" => power.to_s, "type" => type.to_s, "location" => { "province" => province.to_s, "coast" => coast&.to_s } }
  end

  def rules_order(type, power, at, **rest)
    RulesEngine.load_order(
      { "format" => 1, "type" => type.to_s, "power" => power.to_s, "at" => at.to_s }.merge(rest.transform_keys(&:to_s))
    )
  end

  # An order's hash form as the JSON text a player's phone sends.
  def json_of(order) = JSON.generate(order.to_h)

  def move(power, at, province, coast = nil)
    rules_order(:move, power, at, destination: { "province" => province.to_s, "coast" => coast&.to_s })
  end
end

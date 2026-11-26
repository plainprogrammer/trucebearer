# frozen_string_literal: true

require "trucebearer/adjudicator"

TA = Trucebearer::Adjudicator unless defined?(TA)
L = TA::Location unless defined?(L)
O = TA::Order unless defined?(O)

# What the classic map allows, for the specs that try every case, and the example
# objects that docs/interface.md reuses (army, fleet, spring).
module Board
  module_function

  def map = TA::Map.classic
  def provinces = map.provinces.map(&:id)                                   # 75
  def powers = map.powers.map(&:id)                                         # 7
  def inland = map.provinces.select { |p| p.type == :inland }.map(&:id)     # 14
  def sea = map.provinces.select { |p| p.type == :sea }.map(&:id)           # 19
  def split = map.provinces.reject { |p| p.coasts.empty? }                  # bul, spa, stp
  def army_provinces = map.provinces.reject { |p| p.type == :sea }.map(&:id)   # 56

  # 64 places a fleet can stand: seas, coastal provinces, and each split coast.
  def fleet_locations
    map.provinces.reject { |p| p.type == :inland }.flat_map do |p|
      p.coasts.empty? ? [L.new(province: p.id)] : p.coasts.map { |c| L.new(province: p.id, coast: c) }
    end
  end

  # 81 locations: every province with no coast, and the six split coasts.
  def locations
    provinces.map { |id| L.new(province: id) } +
      split.flat_map { |p| p.coasts.map { |c| L.new(province: p.id, coast: c) } }
  end

  def army = TA::Unit.new(power: :austria, type: :army, location: L.new(province: :bud))
  def fleet = TA::Unit.new(power: :russia, type: :fleet, location: L.new(province: :stp, coast: :sc))
  def spring = { map: "classic", season: :spring, year: 1901, phase: :movement, dislodged_units: [], standoffs: [] }

  # "spa/nc" or "par" as a TA::Location.
  def loc(text)
    province, coast = text.split("/")
    L.new(province: province.to_sym, coast: coast&.to_sym)
  end

  # A unit from short pieces: unit(:france, :fleet, "spa/nc").
  def unit(power, type, at) = TA::Unit.new(power: power, type: type, location: loc(at))

  # A spring 1901 position holding only these units, no ownership.
  def position(*units, phase: :movement)
    TA::Position.new(map: "classic", season: :spring, year: 1901, phase: phase, units: units,
                     ownership: {}, dislodged_units: [], standoffs: [])
  end

  # What checking says, as the list of reasons: [] when legal.
  def verdict(position, order)
    result = TA.check(position, order)
    result.legal ? [] : result.reasons
  end
end

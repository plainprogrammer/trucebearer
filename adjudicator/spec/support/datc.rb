# frozen_string_literal: true

require "yaml"
require "trucebearer/adjudicator"
require_relative "board"

# Reads the hand-written DATC fixtures in spec/datc/ (one YAML file per case, named by
# its DATC section number). A fixture holds exactly the units and orders of its case.
#
# Short notation, expanded here: a location is "spa/nc" or "par"; an order is the hash
# form of docs/interface.md without "format", which is added; `destination` is a location.
# `check:` is {legal: true} or {legal: false, reason: <symbol text>}. `result:` (an outcome
# symbol text) and `dislodged:` (true when the unit that followed the order was dislodged) go
# beside each `check:`, and `after:` holds the position after the moves: `units` (each
# {power, type, at}), `dislodged` (each {power, type, at, from, by_convoy}) and `standoffs`.
# A case with `after:` is adjudicated (spec/datc/datc_adjudicate_spec.rb). Every order of such
# a case carries a `check:` and a `result:`, and the implied holds are worked out from the
# checks, so the expectation doesn't depend on the engine. A case with `paradox: true` holds a
# convoy paradox whose result is pending (#39): it has no `after:` and no `result:`, and is
# only tested for the flag and a valid position.
module Datc
  class FormatError < StandardError; end

  Case = Data.define(:id, :departure, :position, :entries, :after, :paradox)
  Entry = Data.define(:order, :expected, :result, :dislodged)

  DIR = File.expand_path("../datc", __dir__)
  TOP_KEYS = %w[case summary departure paradox position orders after].freeze
  TOP_REQUIRED = %w[case summary position orders].freeze
  POSITION_KEYS = %w[units phase].freeze
  UNIT_KEYS = %w[power type at].freeze
  ENTRY_KEYS = %w[order check result dislodged].freeze
  AFTER_KEYS = %w[units dislodged standoffs].freeze
  DISLODGED_KEYS = %w[power type at from by_convoy].freeze
  RESULTS = %w[void held no_route bounced succeeded unmatched cut given disrupted].freeze

  # The cases that carry `after:`: the ones adjudicated. The checking runner expects these
  # files and the ones with `paradox: true`.
  ADJUDICATED = (
    (1..12).map { |n| "6.A.#{n}" } +
    [1, 2, 3, 4, 5, 6, 7, 8, 10, 11, 12, 13, 15, 16, 17, 18, 19].map { |n| "6.B.#{n}" } +
    (1..9).map { |n| "6.C.#{n}" } +
    (1..35).map { |n| "6.D.#{n}" } +
    (1..15).map { |n| "6.E.#{n}" } +
    ((1..30).to_a - [14, 15, 16, 17, 18, 22, 23, 24, 26, 27, 28]).map { |n| "6.F.#{n}" } +
    ((1..20).to_a - [11]).map { |n| "6.G.#{n}" }
  ).sort.freeze
  # The convoy paradoxes the contract leaves to #39 (docs/interface.md, "DATC scope").
  PARADOX_PENDING = (
    [14, 15, 16, 17, 18, 22, 23, 24, 26, 27, 28].map { |n| "6.F.#{n}" } + %w[6.G.11]
  ).sort.freeze
  CHECK_KEYS = %w[legal reason].freeze
  PHASES = %w[movement retreat adjustment].freeze

  module_function

  def files = Dir[File.join(DIR, "*.yml")].sort

  def load_all = files.map { |path| load_file(path) }

  def load_file(path)
    parse(YAML.safe_load_file(path, permitted_classes: [], aliases: false), File.basename(path, ".yml"))
  end

  def parse(data, name)
    fail!(name, "expected a mapping, got #{data.inspect}") unless data.is_a?(Hash)
    keys!(data, TOP_KEYS, TOP_REQUIRED, name, "the top level")
    fail!(name, "\"case\" is #{data["case"].inspect}, which doesn't match the file name") unless data["case"] == name
    departure = data.fetch("departure", false)
    fail!(name, "\"departure\" must be true or false, got #{departure.inspect}") unless [true, false].include?(departure)
    position = build_position(data["position"], name)
    entries = Array(data["orders"]).map { |entry| build_entry(entry, name) }
    paradox = data.fetch("paradox", false)
    fail!(name, "\"paradox\" must be true when given, got #{paradox.inspect}") unless [true, false].include?(paradox) && (paradox || !data.key?("paradox"))
    fail!(name, "a case with \"paradox\" has no \"after\", since its result is pending") if paradox && data.key?("after")
    after = data.key?("after") ? build_after(data["after"], position, entries, name) : nil
    fail!(name, "an order has a \"result\" but the case has no \"after\"") if after.nil? && entries.any?(&:result)
    Case.new(id: name, departure: departure, position: position, entries: entries, after: after, paradox: paradox)
  end

  def build_position(data, name)
    fail!(name, "\"position\" must be a mapping") unless data.is_a?(Hash)
    keys!(data, POSITION_KEYS, %w[units], name, "\"position\"")
    phase = data.fetch("phase", "movement")
    fail!(name, "unknown phase #{phase.inspect}") unless PHASES.include?(phase)
    units = Array(data["units"]).map { |unit| build_unit(unit, name) }
    Board.position(*units, phase: phase.to_sym)
  rescue TA::InvalidInput => e
    fail!(name, "bad position: #{e.message}")
  end

  def build_unit(unit, name)
    fail!(name, "a unit must be a mapping, got #{unit.inspect}") unless unit.is_a?(Hash)
    keys!(unit, UNIT_KEYS, UNIT_KEYS, name, "a unit")
    TA::Unit.from_h("power" => unit["power"], "type" => unit["type"], "location" => location_hash(unit["at"]))
  rescue TA::InvalidInput => e
    fail!(name, "bad unit #{unit.inspect}: #{e.message}")
  end

  def build_entry(entry, name)
    fail!(name, "an order entry must be a mapping, got #{entry.inspect}") unless entry.is_a?(Hash)
    keys!(entry, ENTRY_KEYS, %w[order], name, "an order entry")
    result = entry["result"]
    fail!(name, "unknown result #{result.inspect}") unless result.nil? || RESULTS.include?(result)
    dislodged = entry.fetch("dislodged", false)
    fail!(name, "\"dislodged\" must be true or false, got #{dislodged.inspect}") unless [true, false].include?(dislodged)
    Entry.new(order: build_order(entry["order"], name), expected: build_check(entry["check"], name),
              result: result&.to_sym, dislodged: dislodged)
  end

  # The position after the moves, as the retreat-phase position adjudication gives. A case
  # with `after:` needs a `check:` and a `result:` on every order.
  def build_after(data, position, entries, name)
    fail!(name, "\"after\" must be a mapping") unless data.is_a?(Hash)
    keys!(data, AFTER_KEYS, %w[units], name, "\"after\"")
    entries.each do |entry|
      fail!(name, "an order of a case with \"after\" has no \"result\": #{entry.order.inspect}") if entry.result.nil?
      fail!(name, "an order of a case with \"after\" has no \"check\": #{entry.order.inspect}") if entry.expected.nil?
    end
    units = Array(data["units"]).map { |unit| build_unit(unit, name).to_h }
    dislodged = Array(data["dislodged"]).map { |entry| build_dislodged(entry, name) }
    TA::Position.from_h(position.to_h.merge("phase" => "retreat", "units" => units, "dislodged_units" => dislodged,
                                            "standoffs" => Array(data["standoffs"]).map(&:to_s)))
  rescue TA::InvalidInput => e
    fail!(name, "bad \"after\": #{e.message}")
  end

  def build_dislodged(entry, name)
    fail!(name, "a dislodged unit must be a mapping, got #{entry.inspect}") unless entry.is_a?(Hash)
    keys!(entry, DISLODGED_KEYS, %w[power type at from], name, "a dislodged unit")
    unit = build_unit(entry.slice("power", "type", "at"), name)
    { "unit" => unit.to_h, "attacker_from" => entry["from"].to_s, "by_convoy" => entry.fetch("by_convoy", false) }
  end

  # What adjudicating the case must give, worked out from the fixture alone: the submitted
  # orders as written, then an implied hold for each unit that has no legal order from its
  # owner, sorted by province.
  def expected_outcomes(kase)
    submitted = kase.entries.map do |entry|
      TA::Outcome.new(order: entry.order, result: entry.result, submitted: true, dislodged: entry.dislodged)
    end
    legal = kase.entries.select { |entry| entry.expected.legal }.map(&:order)
    implied = kase.position.units.reject do |unit|
      legal.any? { |order| order.at == unit.location.province && order.power == unit.power }
    end
    submitted + implied.sort_by { |unit| unit.location.province }.map do |unit|
      province = unit.location.province
      TA::Outcome.new(order: TA::Order::Hold.new(power: unit.power, at: province), result: :held, submitted: false,
                      dislodged: kase.after.dislodged_units.any? { |entry| entry.unit.location.province == province })
    end
  end

  def build_order(hash, name)
    fail!(name, "an order must be a mapping, got #{hash.inspect}") unless hash.is_a?(Hash)
    fields = hash.dup
    fields["destination"] = location_hash(fields["destination"]) if fields.key?("destination")
    TA::Order.from_h({ "format" => TA.const_get(:Shape)::FORMAT }.merge(fields))
  rescue TA::InvalidInput => e
    fail!(name, "bad order #{hash.inspect}: #{e.message}")
  end

  def build_check(check, name)
    return nil if check.nil?

    fail!(name, "\"check\" must be a mapping, got #{check.inspect}") unless check.is_a?(Hash)
    keys!(check, CHECK_KEYS, %w[legal], name, "\"check\"")
    legal = check["legal"]
    fail!(name, "\"legal\" must be true or false, got #{legal.inspect}") unless [true, false].include?(legal)
    if legal
      fail!(name, "a legal check has no \"reason\"") if check.key?("reason")
      return TA::CheckResult.new(legal: true, reasons: [])
    end
    reason = TA::CheckResult::REASONS.find { |candidate| candidate.to_s == check["reason"] }
    fail!(name, "unknown reason #{check["reason"].inspect}") unless reason
    TA::CheckResult.new(legal: false, reasons: [reason])
  end

  def location_hash(text)
    province, coast = text.to_s.split("/")
    { "province" => province, "coast" => coast }
  end

  def keys!(hash, allowed, required, name, where)
    (hash.keys - allowed).each { |key| fail!(name, "unknown key #{key.inspect} in #{where}") }
    (required - hash.keys).each { |key| fail!(name, "missing key #{key.inspect} in #{where}") }
  end

  def fail!(name, message)
    raise FormatError, "#{name}: #{message}"
  end
end

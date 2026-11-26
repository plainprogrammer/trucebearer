# frozen_string_literal: true

require "yaml"
require "trucebearer/adjudicator"
require_relative "board"

# Reads the hand-written DATC fixtures in spec/datc/ (one YAML file per case, named by
# its DATC section number). A fixture holds exactly the units and orders of its case.
#
# Short notation, expanded here: a location is "spa/nc" or "par"; an order is the hash
# form of docs/interface.md without "format", which is added; `destination` is a location.
# `check:` is {legal: true} or {legal: false, reason: <symbol text>}. `result:` and `after:`
# are reserved for the adjudication specs (#14) and ignored here.
module Datc
  class FormatError < StandardError; end

  Case = Data.define(:id, :departure, :position, :entries)
  Entry = Data.define(:order, :expected)

  DIR = File.expand_path("../datc", __dir__)
  TOP_KEYS = %w[case summary departure position orders after].freeze
  TOP_REQUIRED = %w[case summary position orders].freeze
  POSITION_KEYS = %w[units phase].freeze
  UNIT_KEYS = %w[power type at].freeze
  ENTRY_KEYS = %w[order check result].freeze
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
    Case.new(id: name, departure: departure,
             position: build_position(data["position"], name),
             entries: Array(data["orders"]).map { |entry| build_entry(entry, name) })
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
    Entry.new(order: build_order(entry["order"], name), expected: build_check(entry["check"], name))
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

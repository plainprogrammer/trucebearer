# frozen_string_literal: true

require "json"
require "yaml"
require "trucebearer/adjudicator"
require_relative "../../support/board"

RSpec.describe "Map#starting_position" do
  let(:map) { TA::Map.classic }
  let(:start) { map.starting_position }

  it "round-trips through JSON, with 22 units and 22 owned centers (AC-6.5)" do
    rebuilt = TA::Position.from_h(JSON.parse(JSON.generate(start.to_h)))
    expect(rebuilt).to eq(start)
    expect(rebuilt.units.size).to eq(22)
    expect(rebuilt.ownership.size).to eq(22)
  end

  it "is a spring 1901 movement position on the classic map (AC-6.1)" do
    expect(start).to be_a(TA::Position)
    expect([start.map, start.season, start.year, start.phase]).to eq(["classic", :spring, 1901, :movement])
  end

  it "holds the 22 starting units, sorted by province (AC-6.2)" do
    expect(start.units.size).to eq(22)
    expect(start.units.map { _1.location.province }).to eq(start.units.map { _1.location.province }.sort)
    expect(start.units).to eq(map.starting_units.map { |u| TA::Unit.new(power: u[:power], type: u[:type], location: u[:location]) }.sort_by { _1.location.province })
    by_power = start.units.group_by(&:power).transform_values { |units| units.map { [_1.type, _1.location.province, _1.location.coast] } }
    expect(by_power.fetch(:russia)).to contain_exactly(
      [:army, :mos, nil], [:army, :war, nil], [:fleet, :sev, nil], [:fleet, :stp, :sc]
    )
    expect(by_power.fetch(:england)).to contain_exactly([:fleet, :lon, nil], [:fleet, :edi, nil], [:army, :lvp, nil])
    expect(by_power.keys.sort).to eq(Board.powers)
    expect(by_power.values.map(&:size)).to all(be_between(3, 4))
  end

  it "gives each power its own home centers and leaves the 12 neutral centers out (AC-6.3)" do
    expect(start.ownership.size).to eq(22)
    map.powers.each do |power|
      map.home_centers(power.id).each { |center| expect(start.ownership[center]).to eq(power.id) }
    end
    expect(start.ownership[:lon]).to eq(:england)
    expect(start.ownership.key?(:bel)).to be(false)
    expect(map.supply_centers - start.ownership.keys).to have_attributes(size: 12)
  end

  it "has no dislodged units and no standoffs (AC-6.4)" do
    expect([start.dislodged_units, start.standoffs]).to eq([[], []])
  end

  it "comes from the data file, unit for unit (AC-6.6)" do
    raw = YAML.safe_load_file(File.expand_path("../../../data/maps/classic.yml", __dir__), permitted_classes: [], aliases: false)
    from_file = raw["starting_units"].map { |u| [u["power"].to_sym, u["type"].to_sym, u["province"].to_sym, u["coast"]&.to_sym] }
    expect(from_file.size).to eq(22)
    expect(start.units.map { [_1.power, _1.type, _1.location.province, _1.location.coast] }).to match_array(from_file)
    start.units.each { |unit| expect(start.ownership[unit.location.province]).to eq(unit.power) }
  end

  it "gives an equal, valid, frozen position on every call (AC-6.7)" do
    expect(map.starting_position).to eq(map.starting_position)
    expect(map.starting_position).to be_frozen
  end

  it "is not mentioned alongside starting_units in the interface document (AC-6.8)" do
    interface = File.read(File.expand_path("../../../docs/interface.md", __dir__))
    expect(interface).not_to include("starting_units")
  end
end

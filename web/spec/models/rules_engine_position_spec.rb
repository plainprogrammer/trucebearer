require "rails_helper"
require_relative "../support/rules_helpers"

# Spec 027 D5, AC-8.1, AC-8.2: the engine's edit methods. The gem decides what is possible; the reason of a refusal is found by
# build stage and the documented map queries, never from the gem's message text.
RSpec.describe RulesEngine, "position edits" do
  include RulesHelpers

  let(:start) { RulesEngine.starting_position }
  let(:empty) { rules_position(units: [ [ :france, :army, :par ] ]) }

  def refusal(&block)
    block.call
    raise "expected EditRefused"
  rescue RulesEngine::EditRefused => error
    error
  end

  def provinces_of(position) = position.units.map { |u| u.location.province.to_s }

  describe "the lists" do
    it "gives the 75 provinces with their names and coasts, the 34 supply centers and the three coasts" do
      expect(RulesEngine.provinces.size).to eq(75)
      expect(RulesEngine.provinces.find { |p| p.id == "spa" }).to have_attributes(name: "Spain", coasts: %w[nc sc])
      expect(RulesEngine.provinces.find { |p| p.id == "par" }.coasts).to eq([])
      expect(RulesEngine.supply_centers.size).to eq(34)
      expect(RulesEngine.coasts).to eq(%w[ec nc sc])
    end
  end

  describe "valid edits" do
    it "adds a unit, leaving the argument unchanged and returning a loadable position" do
      before = start.to_h
      result = RulesEngine.add_unit(start, power: "france", type: "army", province: "bur", coast: nil)

      expect(provinces_of(result)).to include("bur")
      expect(result.units.size).to eq(start.units.size + 1)
      expect(start.to_h).to eq(before)
      expect(RulesEngine.load_position(result.to_h)).to eq(result)
    end

    it "adds a fleet on a coast" do
      result = RulesEngine.add_unit(start, power: "france", type: "fleet", province: "spa", coast: "sc")

      unit = result.units.find { |u| u.location.province == :spa }
      expect(unit.type).to eq(:fleet)
      expect(unit.location.coast).to eq(:sc)
    end

    it "moves a unit, keeping its power and type" do
      result = RulesEngine.move_unit(start, from: "par", province: "bur", coast: nil)

      moved = result.units.find { |u| u.location.province == :bur }
      expect([ moved.power, moved.type ]).to eq(%i[france army])
      expect(provinces_of(result)).not_to include("par")
    end

    it "moves a fleet from one coast of a province to the other" do
      position = rules_position(units: [ [ :france, :fleet, :spa, :nc ] ])
      result = RulesEngine.move_unit(position, from: "spa", province: "spa", coast: "sc")

      expect(result.units.first.location.coast).to eq(:sc)
    end

    it "removes a unit" do
      result = RulesEngine.remove_unit(start, province: "par")

      expect(provinces_of(result)).not_to include("par")
      expect(result.units.size).to eq(start.units.size - 1)
    end

    it "sets and removes an owner" do
      owned = RulesEngine.set_owner(start, center: "bel", power: "germany")
      expect(owned.ownership[:bel]).to eq(:germany)

      cleared = RulesEngine.set_owner(owned, center: "bel", power: nil)
      expect(cleared.ownership).not_to have_key(:bel)
      expect(RulesEngine.load_position(cleared.to_h)).to eq(cleared)
    end

    it "sets the date" do
      result = RulesEngine.set_date(start, season: "fall", year: 1902)

      expect([ result.season, result.year, result.phase ]).to eq([ :fall, 1902, :movement ])
    end
  end

  describe "refusals, each with the reason of D5 (AC-8.2)" do
    it "refuses a fleet inland, an army at sea, a coast an army can't have, and a fleet with no coast" do
      expect(refusal { RulesEngine.add_unit(start, power: "germany", type: "fleet", province: "mun", coast: nil) }.reason).to eq(:fleet_inland)
      expect(refusal { RulesEngine.add_unit(start, power: "england", type: "army", province: "nth", coast: nil) }.reason).to eq(:army_at_sea)
      expect(refusal { RulesEngine.add_unit(start, power: "france", type: "army", province: "spa", coast: "nc") }.reason).to eq(:army_coast)
      expect(refusal { RulesEngine.add_unit(start, power: "france", type: "fleet", province: "spa", coast: nil) }.reason).to eq(:fleet_needs_coast)
    end

    it "refuses a coast the province doesn't have, for either type" do
      expect(refusal { RulesEngine.add_unit(start, power: "france", type: "army", province: "bur", coast: "nc") }.reason).to eq(:no_such_coast)
      expect(refusal { RulesEngine.add_unit(start, power: "france", type: "fleet", province: "bul", coast: "nc") }.reason).to eq(:no_such_coast)
    end

    it "refuses an occupied province, and the earlier stage wins when two rules break" do
      expect(refusal { RulesEngine.add_unit(start, power: "france", type: "army", province: "par", coast: nil) }.reason).to eq(:province_taken)
      expect(refusal { RulesEngine.add_unit(start, power: "france", type: "fleet", province: "par", coast: "nc") }.reason).to eq(:no_such_coast)
      expect(refusal { RulesEngine.move_unit(start, from: "par", province: "mar", coast: nil) }.reason).to eq(:province_taken)
    end

    it "refuses an owner for a province that is not a supply center" do
      expect(refusal { RulesEngine.set_owner(start, center: "bur", power: "france") }.reason).to eq(:not_a_center)
    end

    it "refuses to move or remove a unit that isn't there" do
      expect(refusal { RulesEngine.move_unit(start, from: "bur", province: "par", coast: nil) }.reason).to eq(:no_unit)
      expect(refusal { RulesEngine.remove_unit(start, province: "bur") }.reason).to eq(:no_unit)
    end

    it "gives :other for an unknown identifier, a nil or a value of the wrong kind, never a NoMethodError" do
      expect(refusal { RulesEngine.add_unit(start, power: "france", type: "army", province: "xyz", coast: nil) }.reason).to eq(:other)
      expect(refusal { RulesEngine.add_unit(start, power: "narnia", type: "fleet", province: "mun", coast: nil) }.reason).to eq(:other)
      expect(refusal { RulesEngine.add_unit(start, power: nil, type: "fleet", province: "mun", coast: nil) }.reason).to eq(:other)
      expect(refusal { RulesEngine.add_unit(start, power: "france", type: "tank", province: "bur", coast: nil) }.reason).to eq(:other)
      expect(refusal { RulesEngine.add_unit(start, power: "france", type: "army", province: "bur", coast: 7) }.reason).to eq(:other)
      expect(refusal { RulesEngine.set_owner(start, center: nil, power: nil) }.reason).to eq(:other)
      expect(refusal { RulesEngine.set_owner(start, center: "xyz", power: "france") }.reason).to eq(:other)
      expect(refusal { RulesEngine.set_owner(start, center: "bel", power: "narnia") }.reason).to eq(:other)
      expect(refusal { RulesEngine.set_date(start, season: "fall", year: "1902") }.reason).to eq(:other)
      expect(refusal { RulesEngine.set_date(start, season: "winter", year: 1902) }.reason).to eq(:other)
    end

    it "carries only the reason's name: never the gem's message, a position or an order" do
      error = refusal { RulesEngine.add_unit(start, power: "germany", type: "fleet", province: "mun", coast: nil) }

      expect(error.message).to eq("fleet_inland")
    end
  end

  it "keeps the existing loaders public (RulesObjectType calls them with public_send)" do
    expect(RulesEngine.public_methods(false)).to include(:load_position, :load_order, :load_check_result, :load_adjudication, :legal_orders)
    expect(RulesEngine.public_methods(false)).not_to include(:build_unit, :rebuilt, :text!)
  end
end

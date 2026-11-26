require "rails_helper"
require_relative "../support/rules_helpers"

# Spec 027 D4, AC-6.1, AC-6.5, AC-6.7: the record of one hand edit, and what building one asks of the engine.
RSpec.describe PositionEdit do
  include RulesHelpers

  let(:game) { Game.start!(power: "germany").game }
  let(:phase) { game.current_phase }
  let(:position) { phase.position }

  SHAPES = {
    "unit_added" => { "action" => "unit_added", "power" => "france", "type" => "army", "province" => "bur", "coast" => nil },
    "unit_moved" => { "action" => "unit_moved", "power" => "france", "type" => "fleet", "from" => "spa", "from_coast" => "nc", "to" => "spa", "to_coast" => "sc" },
    "unit_removed" => { "action" => "unit_removed", "power" => "italy", "type" => "army", "province" => "rom", "coast" => nil },
    "owner_set" => { "action" => "owner_set", "center" => "bel", "from" => nil, "to" => "austria" },
    "date_set" => { "action" => "date_set", "from_season" => "spring", "from_year" => 1901, "to_season" => "fall", "to_year" => 1901 }
  }.freeze

  describe "the record" do
    SHAPES.each do |action, detail|
      it "saves a #{action} row" do
        row = described_class.create!(phase: phase, detail: detail)

        expect(row.reload.detail).to eq(detail)
        expect(row.kind).to eq(:position_edit)
      end
    end

    it "is invalid when the action is unknown, the keys differ, or a value is of the wrong kind" do
      bad = [ { "action" => "unit_teleported" }, SHAPES["unit_added"].merge("extra" => "x"), SHAPES["unit_added"].except("coast"),
              SHAPES["unit_added"].merge("power" => 3), SHAPES["date_set"].merge("to_year" => "1901"), "text", nil ]

      bad.each { |detail| expect(described_class.new(phase: phase, detail: detail)).not_to be_valid, detail.inspect }
    end

    it "never changes and is never deleted (AC-6.5)" do
      row = described_class.create!(phase: phase, detail: SHAPES["owner_set"])

      expect { row.update!(detail: SHAPES["unit_added"]) }.to raise_error(ActiveRecord::ReadOnlyRecord)
      expect { row.destroy }.to raise_error(ActiveRecord::ReadOnlyRecord)
    end

    it "says which actions clear orders: the three that move units" do
      cleared = SHAPES.select { |_action, detail| described_class.new(phase: phase, detail: detail).clears_orders? }.keys

      expect(cleared).to eq(%w[unit_added unit_moved unit_removed])
    end

    it "has no column that could hold an order (AC-6.7)" do
      expect(described_class.column_names).to match_array(%w[id phase_id detail created_at])
    end
  end

  describe ".apply" do
    it "adds a unit and records it" do
      result = described_class.apply(position, { "action" => "unit_added", "power" => "france", "type" => "army", "province" => "bur", "coast" => nil })

      expect(result.position.units.map { |u| u.location.province.to_s }).to include("bur")
      expect(result.detail).to eq(SHAPES["unit_added"])
    end

    it "moves a unit, recording the unit's own power, type and coasts" do
      with_fleet = rules_position(units: [ [ :france, :fleet, :spa, :nc ] ])
      result = described_class.apply(with_fleet, { "action" => "unit_moved", "from" => "spa", "to" => "spa", "to_coast" => "sc" })

      expect(result.detail).to eq(SHAPES["unit_moved"])
    end

    it "removes a unit, recording its power, type and coast" do
      result = described_class.apply(position, { "action" => "unit_removed", "province" => "rom" })

      expect(result.detail).to eq(SHAPES["unit_removed"])
      expect(result.position.units.map { |u| u.location.province.to_s }).not_to include("rom")
    end

    it "sets an owner, recording the old one" do
      owned = RulesEngine.set_owner(position, center: "bel", power: "italy")
      result = described_class.apply(owned, { "action" => "owner_set", "center" => "bel", "to" => "austria" })

      expect(result.detail).to eq(SHAPES["owner_set"].merge("from" => "italy"))
      expect(described_class.apply(position, { "action" => "owner_set", "center" => "bel", "to" => "austria" }).detail).to eq(SHAPES["owner_set"])
    end

    it "sets the date, recording the old one" do
      result = described_class.apply(position, { "action" => "date_set", "to_season" => "fall", "to_year" => 1901 })

      expect(result.detail).to eq(SHAPES["date_set"])
    end

    it "refuses what the engine refuses, and an unknown action" do
      expect { described_class.apply(position, { "action" => "unit_added", "power" => "france", "type" => "fleet", "province" => "bur", "coast" => nil }) }
        .to raise_error(RulesEngine::EditRefused) { |error| expect(error.reason).to eq(:fleet_inland) }
      expect { described_class.apply(position, { "action" => "unit_moved", "from" => "bur", "to" => "par", "to_coast" => nil }) }
        .to raise_error(RulesEngine::EditRefused) { |error| expect(error.reason).to eq(:no_unit) }
      expect { described_class.apply(position, { "action" => "nonsense" }) }
        .to raise_error(RulesEngine::EditRefused) { |error| expect(error.reason).to eq(:other) }
    end
  end
end

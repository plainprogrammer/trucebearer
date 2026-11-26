# frozen_string_literal: true

require "trucebearer/adjudicator"

RSpec.describe Trucebearer::Adjudicator::Map do
  TA = Trucebearer::Adjudicator unless defined?(TA)

  INTERFACE_DOC = File.expand_path("../../../docs/interface.md", __dir__) unless defined?(INTERFACE_DOC)

  # Reads the province table in docs/interface.md (the source of truth).
  def self.table_rows
    section = File.read(INTERFACE_DOC)[/^### Provinces\n(.*?)^## Map/m, 1]
    section.lines.filter_map do |line|
      next unless line.start_with?("| `")

      id, name, type, sc, home = line.split("|", -1)[1..5].map(&:strip)
      { id: id.delete("`").to_sym, name: name, type: type.to_sym,
        supply_center: sc == "SC", home: home.empty? ? nil : home.to_sym }
    end
  end

  let(:map) { described_class.classic }

  describe "the province count" do
    it "has 75 provinces: 14 inland, 42 coastal and 19 sea" do
      expect(TA::Map.classic.provinces.size).to eq(75)
      expect(TA::Map.classic.provinces.map(&:type).tally).to eq(inland: 14, coastal: 42, sea: 19)
    end
  end

  describe ".classic" do
    it "returns the same map every time, and the map's id is the string classic" do
      expect(described_class.classic).to be_a(described_class)
      expect(described_class.classic).to equal(described_class.classic)
      expect(map.id).to eq("classic")
    end

    it "offers no way to load another file or build another map" do
      expect(described_class).not_to respond_to(:from_file)
      expect(described_class).not_to respond_to(:new)
    end

    it "gives every thread the same object" do
      maps = Array.new(8) { Thread.new { described_class.classic } }.map(&:value)
      expect(maps.uniq(&:object_id).size).to eq(1)
    end
  end

  describe "#provinces and the interface table" do
    it "reads 75 rows from the table" do
      expect(self.class.table_rows.size).to eq(75)
    end

    it "agrees with the table on every province, and has none the table lacks" do
      actual = map.provinces.map do |p|
        { id: p.id, name: p.name, type: p.type, supply_center: p.supply_center, home: p.home }
      end
      expect(actual).to eq(self.class.table_rows)
    end

    it "is sorted by identifier and frozen" do
      expect(map.provinces.map(&:id)).to eq(map.provinces.map(&:id).sort)
      expect(map.provinces).to be_frozen
      expect(map.provinces).to all(be_frozen)
    end
  end

  describe "#supply_centers and #home_centers" do
    it "lists 34 supply centers, sorted, starting with ank, bel and ber" do
      expect(map.supply_centers.size).to eq(34)
      expect(map.supply_centers).to eq(map.supply_centers.sort)
      expect(map.supply_centers.first(3)).to eq(%i[ank bel ber])
      expect(map.supply_centers).to be_frozen
    end

    it "lists 22 home centers across the seven powers" do
      homes = map.powers.to_h { |power| [power.id, map.home_centers(power.id)] }
      expect(homes.values.sum(&:size)).to eq(22)
      expect(homes.values).to all(be_frozen)
      expect(homes.values.map(&:sort)).to eq(homes.values)
      expect(homes.transform_values(&:size)).to eq(
        austria: 3, england: 3, france: 3, germany: 3, italy: 3, russia: 4, turkey: 3
      )
    end

    it "matches the interface examples" do
      expect(map.home_centers(:england)).to eq(%i[edi lon lvp])
      expect(map.home_centers(:russia)).to eq(%i[mos sev stp war])
    end

    it "leaves 12 neutral supply centers" do
      neutral = map.supply_centers - map.powers.flat_map { |power| map.home_centers(power.id) }
      expect(neutral).to eq(%i[bel bul den gre hol nwy por rum ser spa swe tun])
    end
  end

  describe "#powers and #power" do
    it "lists the seven powers, sorted, with their names" do
      expect(map.powers.map(&:id)).to eq(%i[austria england france germany italy russia turkey])
      expect(map.powers.map(&:name)).to eq(%w[Austria England France Germany Italy Russia Turkey])
      expect(map.powers).to be_frozen
      expect(map.powers).to all(be_frozen)
    end

    it "finds one power" do
      expect(map.power(:england).name).to eq("England")
    end
  end

  describe "#province" do
    it "returns the record with all its fields" do
      spa = map.province(:spa)
      expect([spa.name, spa.type, spa.supply_center, spa.home]).to eq(["Spain", :coastal, true, nil])
      expect(map.province(:lon).home).to eq(:england)
    end
  end

  describe "#coasts" do
    it "names the coasts of the three split-coast provinces and no others" do
      expect(map.coasts(:bul)).to eq(%i[ec sc])
      expect(map.coasts(:spa)).to eq(%i[nc sc])
      expect(map.coasts(:stp)).to eq(%i[nc sc])
      others = map.provinces.map(&:id) - %i[bul spa stp]
      expect(others.map { |id| map.coasts(id) }.uniq).to eq([[]])
    end

    it "agrees with each province record, and is frozen" do
      map.provinces.each do |province|
        expect(province.coasts).to eq(map.coasts(province.id))
        expect(province.coasts).to be_frozen
      end
    end
  end

  describe "unknown identifiers" do
    [[:xyz, ":xyz"], ["spa", '"spa"'], [nil, "nil"]].each do |bad, shown|
      %i[province coasts power home_centers].each do |query|
        it "makes #{query}(#{shown}) raise InvalidInput naming the value" do
          expect { map.public_send(query, bad) }.to raise_error(TA::InvalidInput, /#{Regexp.escape(shown)}/)
        end
      end
    end
  end
end

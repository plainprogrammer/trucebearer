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

    # The map loads when the gem is required, so this holds by construction.
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

    it "has frozen names, so nobody can change the shared map through a record" do
      expect(map.provinces.map(&:name)).to all(be_frozen)
      expect(map.powers.map(&:name)).to all(be_frozen)
      expect(map.id).to be_frozen
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

  describe "#adjacent?" do
    def loc(province, coast = nil)
      TA::Location.new(province: province, coast: coast)
    end

    def fleet(from, to)
      from_province, from_coast = from.to_s.split("/").map(&:to_sym)
      to_province, to_coast = to.to_s.split("/").map(&:to_sym)
      map.adjacent?(:fleet, loc(from_province, from_coast), loc(to_province, to_coast))
    end

    def army(from, to)
      map.adjacent?(:army, loc(from), loc(to))
    end

    let(:provinces) { map.provinces }
    let(:fleet_locations) do
      provinces.reject { |p| p.type == :inland }.flat_map do |p|
        p.coasts.empty? ? [loc(p.id)] : p.coasts.map { |c| loc(p.id, c) }
      end
    end

    it "matches the examples in the interface document" do
      expect(map.adjacent?(:fleet, loc(:mao), loc(:spa, :nc))).to be(true)
      expect(map.adjacent?(:fleet, loc(:gol), loc(:spa, :nc))).to be(false)
      expect(map.adjacent?(:army, loc(:par), loc(:bur))).to be(true)
      expect { map.adjacent?(:army, loc(:par), loc(:spa, :nc)) }.to raise_error(TA::InvalidInput)
    end

    it "is symmetric for armies, with no province next to itself" do
      provinces.each do |a|
        expect(army(a.id, a.id)).to be(false)
        provinces.each { |b| expect(army(a.id, b.id)).to eq(army(b.id, a.id)) }
      end
    end

    it "is symmetric for fleets by coast, with no location next to itself" do
      expect(fleet_locations.size).to eq(64)
      fleet_locations.each do |a|
        expect(map.adjacent?(:fleet, a, a)).to be(false)
        fleet_locations.each do |b|
          expect(map.adjacent?(:fleet, a, b)).to eq(map.adjacent?(:fleet, b, a))
        end
      end
    end

    describe "each split coast, for a fleet" do
      {
        "spa/nc" => { true => %i[mao gas por], false => %i[gol wes mar] },
        "spa/sc" => { true => %i[mao por gol wes mar], false => %i[gas] },
        "stp/nc" => { true => %i[bar nwy], false => %i[bot fin lvn] },
        "stp/sc" => { true => %i[bot fin lvn], false => %i[bar nwy] },
        "bul/ec" => { true => %i[bla con rum], false => %i[aeg gre] },
        "bul/sc" => { true => %i[aeg con gre], false => %i[bla rum] }
      }.each do |coast, expected|
        expected.each do |answer, neighbors|
          neighbors.each do |neighbor|
            it "says #{neighbor} -> #{coast} is #{answer}, and the same the other way" do
              expect(fleet(neighbor, coast)).to be(answer)
              expect(fleet(coast, neighbor)).to be(answer)
            end
          end
        end
      end

      it "never joins the two coasts of one province" do
        expect(fleet("spa/nc", "spa/sc")).to be(false)
        expect(fleet("stp/nc", "stp/sc")).to be(false)
        expect(fleet("bul/ec", "bul/sc")).to be(false)
      end
    end

    describe "a sample of land borders, for armies" do
      %w[par-bur par-pic par-gas par-bre spa-por spa-gas spa-mar stp-fin stp-nwy stp-lvn stp-mos
         bul-con bul-gre bul-rum bul-ser vie-boh ber-sil kie-den rom-apu lon-wal rom-tus tun-naf
         fin-nwy ank-smy arm-smy arm-syr lvp-yor wal-yor edi-lvp pie-ven tus-ven gas-mar].each do |pair|
        a, b = pair.split("-").map(&:to_sym)
        it("joins #{a} and #{b}") { expect(army(a, b)).to be(true) }
      end

      %w[par-mar par-lon spa-bre lon-bel rom-pie].each do |pair|
        a, b = pair.split("-").map(&:to_sym)
        it("does not join #{a} and #{b}") { expect(army(a, b)).to be(false) }
      end

      it "never joins a pair with a sea province on either side" do
        seas = provinces.select { |p| p.type == :sea }.map(&:id)
        provinces.each do |p|
          seas.each do |sea|
            expect(army(p.id, sea)).to be(false)
            expect(army(sea, p.id)).to be(false)
          end
        end
      end
    end

    describe "a sample of plain locations, for fleets" do
      %w[lon-nth lon-eng kie-den kie-hol kie-ber kie-hel kie-bal ven-adr con-bla con-aeg con-smy nth-nwg
         bal-bot bar-nwy adr-ion naf-mao den-swe nwy-swe den-bal ion-tun mao-wes].each do |pair|
        a, b = pair.split("-")
        it("joins #{a} and #{b}") { expect(fleet(a, b)).to be(true) }
      end

      %w[par-bur mun-boh rom-ven adr-tys lon-bel fin-nwy ank-smy arm-syr lvp-yor wal-yor edi-lvp pie-ven
         tus-ven gas-mar ska-bal hel-bal aeg-bla mao-gol].each do |pair|
        a, b = pair.split("-")
        it("does not join #{a} and #{b}") { expect(fleet(a, b)).to be(false) }
      end
    end

    it "gives every fleet location a fleet neighbor" do
      fleet_locations.each do |a|
        expect(fleet_locations.any? { |b| map.adjacent?(:fleet, a, b) }).to be(true), "#{a} has no fleet neighbor"
      end
    end

    it "keeps armies on land: no army neighbors at sea, at least one everywhere else" do
      provinces.each do |a|
        army_neighbors = provinces.select { |b| army(a.id, b.id) }
        if a.type == :sea
          expect(army_neighbors).to be_empty
        else
          expect(army_neighbors).not_to be_empty, "#{a.id} has no army neighbor"
        end
      end
    end

    it "keeps fleets off inland provinces" do
      provinces.select { |p| p.type == :inland }.each do |inland|
        expect(fleet_locations.none? { |b| map.adjacent?(:fleet, loc(inland.id), b) }).to be(true)
      end
    end

    it "makes every fleet-adjacent pair of non-sea provinces army-adjacent too" do
      coastal = fleet_locations.reject { |l| map.province(l.province).type == :sea }
      coastal.product(coastal).each do |a, b|
        next unless map.adjacent?(:fleet, a, b)
        next if a.province == b.province

        expect(army(a.province, b.province)).to be(true), "#{a} and #{b} touch for fleets but not armies"
      end
    end

    it "answers false, and raises nothing, for an army at sea or a fleet inland" do
      expect(map.adjacent?(:army, loc(:nth), loc(:eng))).to be(false)
      expect(map.adjacent?(:army, loc(:par), loc(:nth))).to be(false)
      expect(map.adjacent?(:fleet, loc(:par), loc(:bur))).to be(false)
      expect(map.adjacent?(:fleet, loc(:nth), loc(:mun))).to be(false)
    end

    describe "arguments that break the rules" do
      it "raises for an army location that names a coast, in from or in to" do
        shown = Regexp.escape(loc(:spa, :nc).inspect)
        expect { map.adjacent?(:army, loc(:par), loc(:spa, :nc)) }.to raise_error(TA::InvalidInput, /#{shown}/)
        expect { map.adjacent?(:army, loc(:spa, :nc), loc(:par)) }.to raise_error(TA::InvalidInput, /#{shown}/)
      end

      it "raises for a fleet location on a split-coast province with no coast, in from or in to" do
        shown = Regexp.escape(loc(:spa).inspect)
        expect { map.adjacent?(:fleet, loc(:mao), loc(:spa)) }.to raise_error(TA::InvalidInput, /#{shown}/)
        expect { map.adjacent?(:fleet, loc(:spa), loc(:mao)) }.to raise_error(TA::InvalidInput, /#{shown}/)
      end

      it "raises before working out an answer, even when the partner is far away" do
        expect { map.adjacent?(:army, loc(:spa, :nc), loc(:nth)) }.to raise_error(TA::InvalidInput)
        expect { map.adjacent?(:fleet, loc(:spa), loc(:par)) }.to raise_error(TA::InvalidInput)
      end

      it "raises for a unit type that is not :army or :fleet, naming the value" do
        ["army", "fleet", :cavalry, nil].each do |bad|
          expect { map.adjacent?(bad, loc(:par), loc(:bur)) }
            .to raise_error(TA::InvalidInput, /#{Regexp.escape(bad.inspect)}/)
        end
      end

      it "raises for a from or to that is not a TA::Location, naming the value" do
        expect { map.adjacent?(:army, :par, loc(:bur)) }.to raise_error(TA::InvalidInput, /:par/)
        expect { map.adjacent?(:army, loc(:par), "bur") }.to raise_error(TA::InvalidInput, /"bur"/)
      end
    end
  end

  describe "#starting_units (internal)" do
    let(:units) { map.starting_units }

    it "returns 22 frozen entries sorted by province, each with a power, a type and a location" do
      expect(units.size).to eq(22)
      expect(units).to be_frozen
      expect(units).to all(be_frozen)
      expect(units.map(&:keys).uniq).to eq([%i[power type location]])
      expect(units.map { |u| u[:location].province }).to eq(units.map { |u| u[:location].province }.sort)
      expect(units.map { |u| u[:location] }).to all(be_a(TA::Location))
    end

    it "gives each power its starting units" do
      by_power = units.group_by { |u| u[:power] }.transform_values do |list|
        list.map { |u| [u[:type], u[:location].province, u[:location].coast] }.sort_by { |_, p, _| p }
      end
      expect(by_power).to eq(
        austria: [[:army, :bud, nil], [:fleet, :tri, nil], [:army, :vie, nil]],
        england: [[:fleet, :edi, nil], [:fleet, :lon, nil], [:army, :lvp, nil]],
        france: [[:fleet, :bre, nil], [:army, :mar, nil], [:army, :par, nil]],
        germany: [[:army, :ber, nil], [:fleet, :kie, nil], [:army, :mun, nil]],
        italy: [[:fleet, :nap, nil], [:army, :rom, nil], [:army, :ven, nil]],
        russia: [[:army, :mos, nil], [:fleet, :sev, nil], [:fleet, :stp, :sc], [:army, :war, nil]],
        turkey: [[:fleet, :ank, nil], [:army, :con, nil], [:army, :smy, nil]]
      )
    end

    it "puts no two units in one province" do
      expect(units.map { |u| u[:location].province }.uniq.size).to eq(22)
    end

    it "puts each unit on a home center of its own power, one unit per home center" do
      map.powers.each do |power|
        provinces = units.select { |u| u[:power] == power.id }.map { |u| u[:location].province }
        expect(provinces.sort).to eq(map.home_centers(power.id))
      end
    end

    it "keeps armies off the sea, fleets out of inland provinces, and gives split-coast fleets a coast" do
      units.each do |unit|
        province = map.province(unit[:location].province)
        expect(province.type).not_to eq(:sea) if unit[:type] == :army
        expect(province.type).not_to eq(:inland) if unit[:type] == :fleet
        expect(unit[:location].coast.nil?).to eq(unit[:type] == :army || province.coasts.empty?)
      end
    end

    it "is not mentioned in the interface document" do
      expect(File.read(INTERFACE_DOC)).not_to include("starting_units")
    end
  end
end

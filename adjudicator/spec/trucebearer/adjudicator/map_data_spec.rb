# frozen_string_literal: true

require "yaml"

RSpec.describe "data/maps/classic.yml" do
  data_path = File.expand_path("../../../data/maps/classic.yml", __dir__)
  let(:raw) { YAML.safe_load_file(data_path, permitted_classes: [], aliases: false) }

  # Every place an identifier appears, as the loader would meet it.
  def identifiers(raw)
    provinces = raw["provinces"].flat_map do |p|
      [p["id"], p["type"], p["home"], *p["coasts"]].compact
    end
    powers = raw["powers"].map { |power| power["id"] }
    armies = raw["armies"].flat_map { |from, tos| [from, *tos] }
    fleets = raw["fleets"].flat_map { |from, tos| [from, *tos] }.flat_map { |loc| loc.split("/") }
    units = raw.fetch("starting_units", []).flat_map { |u| [u["power"], u["type"], u["province"], u["coast"]].compact }
    provinces + powers + armies + fleets + units
  end

  it "is found at data/maps/classic.yml and parses with the safe loader" do
    expect(File.file?(data_path)).to be(true)
    expect(raw.keys).to include("map", "powers", "provinces")
  end

  it "holds only strings where an identifier belongs" do
    expect(raw["map"]).to eq("classic")
    expect(identifiers(raw)).to all(be_a(String))
  end

  it "ships in the gem" do
    spec = Gem::Specification.load(File.expand_path("../../../trucebearer-adjudicator.gemspec", __dir__))
    expect(spec.files).to include("data/maps/classic.yml")
  end

  describe "army adjacency" do
    it "is symmetric, has no self-loops or duplicates, and names only known land provinces" do
      armies = raw["armies"]
      known = raw["provinces"].to_h { |p| [p["id"], p["type"]] }
      armies.each do |from, tos|
        expect(known[from]).not_to be_nil, "#{from} is not a province"
        expect(known[from]).not_to eq("sea"), "#{from} is a sea province with army neighbors"
        expect(tos).not_to include(from)
        expect(tos.uniq).to eq(tos), "#{from} lists a neighbor twice"
        tos.each do |to|
          expect(known[to]).not_to be_nil, "#{from} lists unknown #{to}"
          expect(known[to]).not_to eq("sea"), "#{from} lists sea province #{to}"
          expect(armies[to]).to include(from), "#{from} lists #{to}, but not the other way round"
        end
      end
    end
  end

  describe "fleet adjacency" do
    it "is symmetric, has no self-loops or duplicates, and names only known non-inland locations" do
      fleets = raw["fleets"]
      known = raw["provinces"].to_h { |p| [p["id"], p["type"]] }
      fleets.each do |from, tos|
        expect(tos).not_to include(from)
        expect(tos.uniq).to eq(tos), "#{from} lists a neighbor twice"
        [from, *tos].each do |loc|
          province = loc.split("/").first
          expect(known[province]).not_to be_nil, "unknown province in #{loc}"
          expect(known[province]).not_to eq("inland"), "inland province in #{loc}"
        end
        tos.each { |to| expect(fleets[to]).to include(from), "#{from} lists #{to}, but not the other way round" }
      end
    end

    it "names a coast exactly on the three split-coast provinces, and one the province has" do
      coasts = raw["provinces"].to_h { |p| [p["id"], p["coasts"] || []] }
      locations = raw["fleets"].flat_map { |from, tos| [from, *tos] }.uniq
      locations.each do |loc|
        province, coast = loc.split("/")
        if coasts[province].empty?
          expect(coast).to be_nil, "#{loc} names a coast on an unsplit province"
        else
          expect(coasts[province]).to include(coast), "#{loc} lacks a valid coast"
        end
      end
      expect(raw["fleets"].keys.size).to eq(64)
    end
  end
end

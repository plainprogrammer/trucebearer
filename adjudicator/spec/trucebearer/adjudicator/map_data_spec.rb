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
    armies = raw.fetch("armies", {}).flat_map { |from, tos| [from, *tos] }
    fleets = raw.fetch("fleets", {}).flat_map { |from, tos| [from, *tos] }.flat_map { |loc| loc.split("/") }
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
end

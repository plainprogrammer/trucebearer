# frozen_string_literal: true

require "tmpdir"
require "trucebearer/adjudicator"
require_relative "../support/datc"

# The loader of the DATC fixtures (AC-8.5, AC-8.6). The fixtures themselves are run in
# datc_check_spec.rb.
RSpec.describe Datc do
  let(:good) do
    { "case" => "6.X.1", "summary" => "a test case",
      "position" => { "units" => [{ "power" => "england", "type" => "fleet", "at" => "lon" }] },
      "orders" => [{ "order" => { "type" => "hold", "power" => "england", "at" => "lon" }, "check" => { "legal" => true } }] }
  end

  def parse(data, name = "6.X.1") = described_class.parse(data, name)

  it "builds the position and the orders of a case, expanding short locations" do
    data = good.merge("position" => { "units" => [{ "power" => "france", "type" => "fleet", "at" => "spa/nc" }] },
                      "orders" => [{ "order" => { "type" => "move", "power" => "france", "at" => "spa", "destination" => "gol" },
                                     "check" => { "legal" => false, "reason" => "not_reachable" } }])
    kase = parse(data)
    expect(kase.id).to eq("6.X.1")
    expect(kase.position.units.first.location).to eq(L.new(province: :spa, coast: :nc))
    expect(kase.position.phase).to eq(:movement)
    expect(kase.entries.first.order).to eq(O::Move.new(power: :france, at: :spa, destination: L.new(province: :gol)))
    expect(kase.entries.first.expected).to eq(TA::CheckResult.new(legal: false, reasons: [:not_reachable]))
  end

  it "takes an optional phase and an optional departure mark" do
    kase = parse(good.merge("departure" => true, "position" => { "phase" => "retreat", "units" => [] }))
    expect(kase.position.phase).to eq(:retreat)
    expect(kase.departure).to be(true)
  end

  it "ignores the keys reserved for #14, and an order with no check (AC-8.5)" do
    data = good.merge("after" => { "units" => [] })
    data["orders"] = [
      { "order" => { "type" => "hold", "power" => "england", "at" => "lon" }, "check" => { "legal" => true }, "result" => "held" },
      { "order" => { "type" => "hold", "power" => "england", "at" => "lon" }, "result" => "held" }
    ]
    kase = parse(data)
    expect(kase.entries.map(&:expected)).to eq([TA::CheckResult.new(legal: true, reasons: []), nil])
  end

  it "refuses a malformed fixture, naming the file (AC-8.6)" do
    bad = {
      "an unknown top-level key" => good.merge("surprise" => 1),
      "an unknown order-entry key" => good.merge("orders" => [{ "order" => good["orders"][0]["order"], "oops" => 1 }]),
      "an unknown check key" => good.merge("orders" => [{ "order" => good["orders"][0]["order"], "check" => { "legal" => true, "why" => "x" } }]),
      "an unknown unit key" => good.merge("position" => { "units" => [{ "power" => "england", "type" => "fleet", "at" => "lon", "x" => 1 }] }),
      "an unknown reason" => good.merge("orders" => [{ "order" => good["orders"][0]["order"], "check" => { "legal" => false, "reason" => "bogus" } }]),
      "a reason on a legal check" => good.merge("orders" => [{ "order" => good["orders"][0]["order"], "check" => { "legal" => true, "reason" => "own_province" } }]),
      "an illegal check with no reason" => good.merge("orders" => [{ "order" => good["orders"][0]["order"], "check" => { "legal" => false } }]),
      "a departure that isn't true or false" => good.merge("departure" => "yes"),
      "a missing summary" => good.reject { |key, _| key == "summary" },
      "a case id that doesn't match the file" => good.merge("case" => "6.X.2"),
      "an order that can't be built" => good.merge("orders" => [{ "order" => { "type" => "hold", "power" => "england" } }]),
      "a unit that can't be built" => good.merge("position" => { "units" => [{ "power" => "england", "type" => "fleet", "at" => "xyz" }] })
    }
    bad.each do |label, data|
      expect { parse(data) }.to raise_error(Datc::FormatError, /6\.X\.1/), "expected #{label} to be refused"
    end
  end

  it "reads a real file with no classes and no aliases" do
    Dir.mktmpdir do |dir|
      path = File.join(dir, "6.X.1.yml")
      File.write(path, "case: \"6.X.1\"\nsummary: x\nposition: &p\n  units: []\norders: []\nother: *p\n")
      expect { described_class.load_file(path) }.to raise_error(Psych::Exception)
    end
  end
end

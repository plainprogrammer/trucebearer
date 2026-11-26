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

  # `good` with the keys of its one order changed and an `after` that holds its unit.
  def with_after(data, entry)
    data.merge("orders" => [(data["orders"][0].reject { |key, _| %w[result dislodged].include?(key) }).merge(entry)],
               "after" => { "units" => [{ "power" => "england", "type" => "fleet", "at" => "lon" }] })
  end

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

  it "takes an order with no check when the case has no \"after\" (AC-8.5)" do
    data = good.merge("orders" => [{ "order" => { "type" => "hold", "power" => "england", "at" => "lon" } }])
    expect(parse(data).entries.map(&:expected)).to eq([nil])
  end

  it "reads each result, each dislodged mark and the position after the moves (AC-11.1)" do
    data = good.merge(
      "position" => { "units" => [{ "power" => "austria", "type" => "army", "at" => "vie" },
                                  { "power" => "germany", "type" => "army", "at" => "boh" },
                                  { "power" => "germany", "type" => "fleet", "at" => "bal" }] },
      "orders" => [{ "order" => { "type" => "hold", "power" => "austria", "at" => "vie" }, "check" => { "legal" => true },
                     "result" => "held", "dislodged" => true },
                   { "order" => { "type" => "move", "power" => "germany", "at" => "boh", "destination" => "vie" },
                     "check" => { "legal" => true }, "result" => "succeeded" }],
      "after" => { "units" => [{ "power" => "germany", "type" => "army", "at" => "vie" },
                               { "power" => "germany", "type" => "fleet", "at" => "bal" }],
                   "dislodged" => [{ "power" => "austria", "type" => "army", "at" => "vie", "from" => "boh" }],
                   "standoffs" => ["gal"] }
    )
    kase = parse(data)
    expect(kase.entries.map { [_1.result, _1.dislodged] }).to eq([[:held, true], [:succeeded, false]])
    expect(kase.after.phase).to eq(:retreat)
    expect(kase.after.units.map { _1.location.province }).to eq(%i[bal vie])
    expect(kase.after.dislodged_units.first.attacker_from).to eq(:boh)
    expect(kase.after.dislodged_units.first.by_convoy).to be(false)
    expect(kase.after.standoffs).to eq([:gal])
    expect(described_class.expected_outcomes(kase).map { [_1.order.at, _1.result, _1.submitted, _1.dislodged] })
      .to eq([[:vie, :held, true, true], [:boh, :succeeded, true, false], [:bal, :held, false, false]])
  end

  it "works out an implied hold for a unit whose only order is illegal (AC-11.1)" do
    data = good.merge("orders" => [{ "order" => { "type" => "hold", "power" => "france", "at" => "lon" },
                                     "check" => { "legal" => false, "reason" => "foreign_unit" }, "result" => "void" }],
                      "after" => { "units" => [{ "power" => "england", "type" => "fleet", "at" => "lon" }] })
    outcomes = described_class.expected_outcomes(parse(data))
    expect(outcomes.map { [_1.order.power, _1.result, _1.submitted] }).to eq([[:france, :void, true], [:england, :held, false]])
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
      "a unit that can't be built" => good.merge("position" => { "units" => [{ "power" => "england", "type" => "fleet", "at" => "xyz" }] }),
      "an unknown result" => with_after(good, "result" => "won"),
      "a result with no after" => good.merge("orders" => [good["orders"][0].merge("result" => "held")]),
      "a dislodged mark that isn't true or false" => with_after(good, "result" => "held", "dislodged" => "yes"),
      "an after with an order that has no result" => with_after(good, {}),
      "an after with an order that has no check" => with_after(good.merge("orders" => [{ "order" => good["orders"][0]["order"], "result" => "held" }]), "result" => "held"),
      "an unknown key in after" => good.merge("orders" => [good["orders"][0].merge("result" => "held")],
                                              "after" => { "units" => [], "surprise" => 1 }),
      "an after with no units" => good.merge("orders" => [good["orders"][0].merge("result" => "held")], "after" => {}),
      "an after unit that can't be built" => good.merge("orders" => [good["orders"][0].merge("result" => "held")],
                                                         "after" => { "units" => [{ "power" => "england", "type" => "army", "at" => "nth" }] }),
      "a dislodged unit with no attacker" => good.merge("orders" => [good["orders"][0].merge("result" => "held")],
                                                        "after" => { "units" => [], "dislodged" => [{ "power" => "england", "type" => "fleet", "at" => "lon" }] }),
      "a dislodged unit whose attacker isn't a province" => good.merge("orders" => [good["orders"][0].merge("result" => "held")],
                                                                       "after" => { "units" => [], "dislodged" => [{ "power" => "england", "type" => "fleet", "at" => "lon", "from" => "xyz" }] }),
      "an unknown standoff province" => good.merge("orders" => [good["orders"][0].merge("result" => "held")],
                                                    "after" => { "units" => [{ "power" => "england", "type" => "fleet", "at" => "lon" }], "standoffs" => ["xyz"] })
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

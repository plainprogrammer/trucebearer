# frozen_string_literal: true

require "json"
require "trucebearer/adjudicator"
require_relative "../../support/board"

# TA::Outcome (AC-2.1 to AC-2.5).
RSpec.describe TA::Outcome do
  let(:hold) { O::Hold.new(power: :england, at: :lon) }
  let(:move) { O::Move.new(power: :france, at: :mao, destination: L.new(province: :spa, coast: :nc)) }

  # One order of each class, with the results docs/interface.md `### Outcomes` allows it.
  samples = {
    "Hold" => [-> { O::Hold.new(power: :england, at: :lon) }, %i[void held]],
    "Move" => [-> { O::Move.new(power: :france, at: :mao, destination: L.new(province: :spa, coast: :nc)) }, %i[void no_route bounced succeeded]],
    "MoveViaConvoy" => [-> { O::MoveViaConvoy.new(power: :england, at: :lon, to: :wal) }, %i[void no_route bounced succeeded]],
    "SupportHold" => [-> { O::SupportHold.new(power: :germany, at: :mun, target: :ber) }, %i[void unmatched cut given]],
    "SupportMove" => [-> { O::SupportMove.new(power: :france, at: :por, from: :mao, to: :spa) }, %i[void unmatched cut given]],
    "Convoy" => [-> { O::Convoy.new(power: :england, at: :nth, from: :lon, to: :nwy) }, %i[void unmatched disrupted given]]
  }

  def build(order, result, submitted: true, dislodged: false)
    described_class.new(order: order, result: result, submitted: submitted, dislodged: dislodged)
  end

  it "builds a frozen value with equal contents equal (AC-2.1)" do
    outcome = build(hold, :held, submitted: false)
    expect(outcome).to be_frozen
    expect(outcome).to eq(build(hold, :held, submitted: false))
    expect(outcome.hash).to eq(build(hold, :held, submitted: false).hash)
    expect(outcome.to_h).to eq(
      "order" => { "format" => 1, "type" => "hold", "power" => "england", "at" => "lon" },
      "result" => "held", "submitted" => false, "dislodged" => false
    )
    expect(outcome.to_h.keys).to eq(%w[order result submitted dislodged])
    expect(described_class.from_h(JSON.parse(JSON.generate(outcome.to_h)))).to eq(outcome)
  end

  it "lists the nine results in the order of the contract (AC-2.5)" do
    expect(described_class::RESULTS).to eq(%i[void held no_route bounced succeeded unmatched cut given disrupted])
    line = File.read(File.expand_path("../../../docs/interface.md", __dir__))[/^- `result`: one of .*$/]
    expect(line.scan(/`:(\w+)`/).flatten.map(&:to_sym)).to eq(described_class::RESULTS)
  end

  samples.each do |name, (maker, allowed)|
    describe "an outcome of a #{name}" do
      allowed.each do |result|
        [true, false].each do |dislodged|
          next if result == :void && dislodged
          next if result == :succeeded && dislodged

          it "round-trips with #{result.inspect}, dislodged #{dislodged} (AC-2.2)" do
            outcome = build(maker.call, result, dislodged: dislodged)
            rebuilt = described_class.from_h(JSON.parse(JSON.generate(outcome.to_h)))
            expect(rebuilt).to eq(outcome)
            expect(outcome.to_h).not_to have_key("format")
            expect(outcome.to_h["order"]["format"]).to eq(1)
          end
        end
      end

      (described_class::RESULTS - allowed).each do |result|
        it "refuses #{result.inspect} (AC-2.4)" do
          expect { build(maker.call, result) }.to raise_error(TA::InvalidInput, /#{result}/)
        end
      end
    end
  end

  it "refuses the other impossible outcomes, from new and from from_h (AC-2.4)" do
    impossible = [
      -> { build(hold, :void, dislodged: true) },
      -> { build(move, :void, dislodged: true) },
      -> { build(move, :bounced, submitted: false) },
      -> { build(hold, :void, submitted: false) },
      -> { build(move, :succeeded, dislodged: true) }
    ]
    impossible.each { |make| expect { make.call }.to raise_error(TA::InvalidInput) }
    hash = build(hold, :held).to_h.merge("result" => "void", "dislodged" => true)
    expect { described_class.from_h(hash) }.to raise_error(TA::InvalidInput, /void/)
  end

  it "refuses a bad hash, naming the key or value (AC-2.3)" do
    good = build(hold, :held).to_h
    expect { described_class.from_h(good.reject { |key, _| key == "result" }) }.to raise_error(TA::InvalidInput, /result/)
    expect { described_class.from_h(good.merge("extra" => 1)) }.to raise_error(TA::InvalidInput, /extra/)
    expect { described_class.from_h(good.merge("format" => 1)) }.to raise_error(TA::InvalidInput, /format/)
    expect { described_class.from_h(good.merge("result" => "nonsense")) }.to raise_error(TA::InvalidInput, /nonsense/)
    expect { described_class.from_h(good.merge("submitted" => "yes")) }.to raise_error(TA::InvalidInput, /submitted/)
    expect { described_class.from_h(good.merge("dislodged" => nil)) }.to raise_error(TA::InvalidInput, /dislodged/)
    expect { described_class.from_h(good.merge("order" => { "type" => "hold" })) }.to raise_error(TA::InvalidInput)
    expect { described_class.new(order: hold, result: "held", submitted: true, dislodged: false) }.to raise_error(TA::InvalidInput, /held/)
    expect { described_class.new(order: hold.to_h, result: :held, submitted: true, dislodged: false) }.to raise_error(TA::InvalidInput)
  end
end

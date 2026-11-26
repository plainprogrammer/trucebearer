# frozen_string_literal: true

require "json"
require "trucebearer/adjudicator"
require_relative "../../support/board"

# TA::Adjudication (AC-3.1 to AC-3.5).
RSpec.describe TA::Adjudication do
  let(:position) { TA::Map.classic.starting_position }

  def outcome(order, result = :held, submitted: true, dislodged: false)
    TA::Outcome.new(order: order, result: result, submitted: submitted, dislodged: dislodged)
  end

  def hold(power, at) = O::Hold.new(power: power, at: at)

  def build(outcomes, paradox: false) = described_class.new(outcomes: outcomes, paradox: paradox, position: position)

  it "keeps the order of the outcomes, freezes its own copy and leaves the caller's array alone (AC-3.1)" do
    list = [outcome(hold(:england, :lon)), outcome(hold(:austria, :bud)), outcome(hold(:france, :bre), submitted: false)]
    adjudication = build(list)
    expect(adjudication).to be_frozen
    expect(adjudication.outcomes).to be_frozen
    expect(adjudication.outcomes.map { _1.order.at }).to eq(%i[lon bud bre])
    expect(list).not_to be_frozen
    expect(build(list)).to eq(adjudication)
    expect(build(list).hash).to eq(adjudication.hash)
  end

  it "round-trips through JSON, with format first (AC-3.2)" do
    adjudication = build([outcome(hold(:england, :lon)), outcome(hold(:france, :bre), submitted: false)], paradox: true)
    expect(adjudication.to_h.keys).to eq(%w[format outcomes paradox position])
    expect(adjudication.to_h["format"]).to eq(1)
    expect(described_class.from_h(JSON.parse(JSON.generate(adjudication.to_h)))).to eq(adjudication)
  end

  it "refuses a bad hash, naming the key or value (AC-3.3)" do
    good = build([outcome(hold(:england, :lon))]).to_h
    expect { described_class.from_h(good.reject { |key, _| key == "paradox" }) }.to raise_error(TA::InvalidInput, /paradox/)
    expect { described_class.from_h(good.merge("extra" => 1)) }.to raise_error(TA::InvalidInput, /extra/)
    expect { described_class.from_h(good.reject { |key, _| key == "format" }) }.to raise_error(TA::InvalidInput, /format/)
    expect { described_class.from_h(good.merge("format" => 2)) }.to raise_error(TA::InvalidInput, /2/)
    expect { described_class.from_h(good.merge("paradox" => "no")) }.to raise_error(TA::InvalidInput, /paradox/)
    expect { described_class.from_h(good.merge("outcomes" => "none")) }.to raise_error(TA::InvalidInput, /outcomes/)
    expect { described_class.from_h(good.merge("outcomes" => [{}])) }.to raise_error(TA::InvalidInput)
    expect { described_class.from_h(good.merge("position" => {})) }.to raise_error(TA::InvalidInput)
    expect { described_class.new(outcomes: [1], paradox: false, position: position) }.to raise_error(TA::InvalidInput, /outcomes/)
    expect { described_class.new(outcomes: [], paradox: 1, position: position) }.to raise_error(TA::InvalidInput, /paradox/)
    expect { described_class.new(outcomes: [], paradox: false, position: nil) }.to raise_error(TA::InvalidInput, /position/)
  end

  describe "the impossible adjudications (AC-3.4)" do
    it "refuses a submitted outcome after an implied hold" do
      list = [outcome(hold(:france, :bre), submitted: false), outcome(hold(:england, :lon))]
      expect { build(list) }.to raise_error(TA::InvalidInput, /after an implied hold/)
    end

    it "refuses implied holds that are not in ascending order of province, or repeat one" do
      expect { build([outcome(hold(:france, :bre), submitted: false), outcome(hold(:england, :bel), submitted: false)]) }
        .to raise_error(TA::InvalidInput, /ascending/)
      expect { build([outcome(hold(:france, :bre), submitted: false), outcome(hold(:france, :bre), submitted: false)]) }
        .to raise_error(TA::InvalidInput, /ascending/)
    end

    it "refuses two submitted outcomes for one power and province, which adjudication refuses as input" do
      list = [outcome(hold(:england, :lon)), outcome(O::Move.new(power: :england, at: :lon, destination: L.new(province: :nth)), :bounced)]
      expect { build(list) }.to raise_error(TA::InvalidInput, /same power and province/)
    end

    it "accepts two submitted outcomes for one province from two powers (one is void)" do
      list = [outcome(hold(:france, :lon), :void), outcome(hold(:england, :lon))]
      expect { build(list) }.not_to raise_error
    end

    it "takes any phase for the position, since 0.3 changes it" do
      movement = TA::Position.from_h(position.to_h.merge("phase" => "movement"))
      expect { described_class.new(outcomes: [], paradox: false, position: movement) }.not_to raise_error
    end
  end
end

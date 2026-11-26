require "rails_helper"
require_relative "../support/results_fixtures"

# Spec 029 AC-2.1, AC-2.2: a reveal applies the rules. A supported attack dislodges a holding unit.
RSpec.describe Phase, "#reveal! with the real engine" do
  include ResultsFixtures

  let(:game) { Game.start!(power: "germany").game }
  let(:revealed) do
    reveal_position!(game, units: [ %i[germany army mun], %i[germany army ruh], %i[france army bur] ],
                           orders: [ [ :move, :germany, :mun, { destination: { "province" => "bur", "coast" => nil } } ],
                                     [ :support_move, :germany, :ruh, { from: "mun", to: "bur" } ],
                                     [ :hold, :france, :bur ] ])
  end

  def outcome(power, province) = revealed.adjudication.to_h["outcomes"].find { |o| o["order"]["power"] == power && o["order"]["at"] == province }

  it "dislodges France's army in Burgundy, and says so in the stored result (AC-2.1)" do
    expect(outcome("germany", "mun")["result"]).to eq("succeeded")
    expect(outcome("germany", "ruh")["result"]).to eq("given")
    expect(outcome("france", "bur")).to include("result" => "held", "dislodged" => true)
    position = revealed.adjudication.to_h["position"]
    expect(position["dislodged_units"]).to eq([ { "unit" => unit_hash(:france, :army, :bur), "attacker_from" => "mun", "by_convoy" => false } ])
  end

  it "opens the next phase with Germany in Burgundy and no French unit there (AC-2.1)" do
    revealed
    units = game.current_phase.position.to_h["units"].map { |u| [ u["power"], u.dig("location", "province") ] }
    expect(units).to include([ "germany", "bur" ])
    expect(units).not_to include([ "france", "bur" ])
  end

  it "stores the gem's documented hash form, which loads back to an equal result (AC-2.2)" do
    raw = Phase.connection.select_value("SELECT adjudication FROM phases WHERE id = #{revealed.id}")
    expect(JSON.parse(raw)).to include("format" => 1).and include("outcomes", "paradox", "position")
    expect(Phase.find(revealed.id).adjudication).to eq(revealed.adjudication)
    expect(RulesEngine.load_adjudication(JSON.parse(raw))).to eq(revealed.adjudication)
  end
end

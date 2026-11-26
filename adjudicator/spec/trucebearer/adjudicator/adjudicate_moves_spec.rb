# frozen_string_literal: true

require "trucebearer/adjudicator"
require_relative "../../support/adjudicating"

# Moves, bounces and standoffs (Story 7).
RSpec.describe "TA.adjudicate: moves, bounces and standoffs" do
  it "moves a unit into an empty province, a fleet onto the coast it named (AC-7.1)" do
    result = run([u(:france, :army, "par")], [mv(:france, :par, "bur")])
    expect(results(result, 1)).to eq([:succeeded])
    expect(after(result)).to eq(bur: :france)
    fleet = run([u(:france, :fleet, "mao")], [mv(:france, :mao, "spa/nc")])
    expect(fleet.position.units.first.location).to eq(L.new(province: :spa, coast: :nc))
    stays = run([u(:france, :fleet, "spa/sc")], [hd(:france, :spa)])
    expect(stays.position.units.first.location).to eq(L.new(province: :spa, coast: :sc))
  end

  it "bounces two units, then three, that move into one empty province, and marks it a standoff (AC-7.2)" do
    two = run([u(:austria, :army, "vie"), u(:italy, :army, "ven")], [mv(:austria, :vie, "tyr"), mv(:italy, :ven, "tyr")])
    expect(results(two, 2)).to eq(%i[bounced bounced])
    expect(two.position.standoffs).to eq([:tyr])
    expect(after(two)).to eq(vie: :austria, ven: :italy)
    three = run([u(:austria, :army, "vie"), u(:germany, :army, "mun"), u(:italy, :army, "ven")],
                [mv(:austria, :vie, "tyr"), mv(:germany, :mun, "tyr"), mv(:italy, :ven, "tyr")])
    expect(results(three, 3)).to eq(%i[bounced bounced bounced])
    expect(three.position.standoffs).to eq([:tyr])
  end

  it "lets the supported move win, and then there is no standoff (AC-7.2)" do
    units = [u(:austria, :army, "vie"), u(:germany, :army, "mun"), u(:germany, :army, "boh"), u(:italy, :army, "ven")]
    result = run(units, [mv(:austria, :vie, "tyr"), mv(:germany, :mun, "tyr"), sm(:germany, :boh, :mun, :tyr), mv(:italy, :ven, "tyr")])
    expect(results(result, 4)).to eq(%i[bounced succeeded given bounced])
    expect(result.position.standoffs).to eq([])
    expect(after(result)[:tyr]).to eq(:germany)
  end

  it "bounces a move of equal strength against a holder, which is no standoff (AC-7.3)" do
    result = run([u(:austria, :army, "vie"), u(:italy, :army, "tyr")], [mv(:austria, :vie, "tyr")])
    expect(results(result, 1)).to eq([:bounced])
    expect(result.position.standoffs).to eq([])
    expect(result.position.dislodged_units).to eq([])
  end

  it "lets a move follow the winner of a head-to-head battle into the province it left (AC-7.3)" do
    units = [u(:germany, :army, "ber"), u(:germany, :fleet, "kie"), u(:germany, :army, "sil"), u(:russia, :army, "pru")]
    result = run(units, [mv(:germany, :ber, "pru"), mv(:germany, :kie, "ber"), sm(:germany, :sil, :ber, :pru), mv(:russia, :pru, "ber")])
    expect(results(result, 4)).to eq(%i[succeeded succeeded given bounced])
    expect(result.position.standoffs).to eq([])
  end

  it "marks a province a standoff when its holder left in the same turn (AC-7.4)" do
    units = [u(:austria, :army, "vie"), u(:italy, :army, "ven"), u(:germany, :army, "mun")]
    result = run(units, [mv(:austria, :vie, "tyr"), mv(:italy, :ven, "tyr"), mv(:germany, :mun, "boh")])
    expect(results(result, 3)).to eq(%i[bounced bounced succeeded])
    expect(result.position.standoffs).to eq([:tyr])
    units = [u(:austria, :army, "vie"), u(:italy, :army, "ven"), u(:germany, :army, "tyr")]
    left = run(units, [mv(:austria, :vie, "tyr"), mv(:italy, :ven, "tyr"), mv(:germany, :tyr, "boh")])
    expect(results(left, 3)).to eq(%i[bounced bounced succeeded])
    expect(left.position.standoffs).to eq([:tyr])
  end

  it "is no standoff when a third, stronger move enters (AC-7.4)" do
    units = [u(:austria, :army, "vie"), u(:italy, :army, "ven"), u(:germany, :army, "mun"), u(:germany, :army, "boh")]
    result = run(units, [mv(:austria, :vie, "tyr"), mv(:italy, :ven, "tyr"), mv(:germany, :mun, "tyr"), sm(:germany, :boh, :mun, :tyr)])
    expect(result.position.standoffs).to eq([])
    expect(after(result)[:tyr]).to eq(:germany)
  end

  it "puts every unit in place: a failed move stays, a successful one is alone in its province (AC-7.5)" do
    units = [u(:austria, :army, "vie"), u(:italy, :army, "ven"), u(:germany, :army, "mun"), u(:france, :army, "par")]
    result = run(units, [mv(:austria, :vie, "tyr"), mv(:italy, :ven, "tyr"), mv(:germany, :mun, "boh"), mv(:france, :par, "bur")])
    expect(after(result)).to eq(vie: :austria, ven: :italy, boh: :germany, bur: :france)
    expect(result.position.units.map { _1.location.province }.uniq.size).to eq(4)
  end
end

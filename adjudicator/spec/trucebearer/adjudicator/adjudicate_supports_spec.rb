# frozen_string_literal: true

require "trucebearer/adjudicator"
require_relative "../../support/adjudicating"

# Supports: strength, matching and cuts (Story 8).
RSpec.describe "TA.adjudicate: supports" do
  let(:vie_boh_tyr) { [u(:austria, :army, "vie"), u(:germany, :army, "boh"), u(:germany, :army, "tyr")] }

  it "gives a support to hold and adds one to the hold strength (AC-8.1)" do
    units = [u(:austria, :army, "vie"), u(:austria, :army, "gal"), u(:germany, :army, "boh"), u(:germany, :army, "tyr")]
    result = run(units, [sh(:austria, :gal, :vie), mv(:germany, :boh, "vie"), sm(:germany, :tyr, :boh, :vie)])
    expect(results(result, 3)).to eq(%i[given bounced given])
    expect(dislodged(result)).to eq({})
  end

  it "gives a support to move and adds one to the move's strength (AC-8.1)" do
    result = run(vie_boh_tyr, [mv(:germany, :boh, "vie"), sm(:germany, :tyr, :boh, :vie)])
    expect(results(result, 2)).to eq(%i[succeeded given])
    expect(dislodged(result)).to eq(vie: :boh)
  end

  it "is unmatched when the supported unit moves and the support is for a hold (AC-8.2)" do
    units = [u(:germany, :army, "boh"), u(:germany, :army, "tyr")]
    result = run(units, [mv(:germany, :boh, "vie"), sh(:germany, :tyr, :boh)])
    expect(results(result, 2)).to eq(%i[succeeded unmatched])
  end

  it "is unmatched when the supported move has another origin or destination, or the unit holds (AC-8.2)" do
    units = [u(:germany, :army, "boh"), u(:germany, :army, "tyr"), u(:austria, :army, "gal")]
    expect(results(run(units, [mv(:germany, :boh, "vie"), sm(:germany, :tyr, :boh, :mun)]), 2)).to eq(%i[succeeded unmatched])
    expect(results(run(units, [mv(:germany, :boh, "vie"), sm(:germany, :tyr, :gal, :vie)]), 2)).to eq(%i[succeeded unmatched])
    expect(results(run(units, [hd(:germany, :boh), sm(:germany, :tyr, :boh, :vie)]), 2)).to eq(%i[held unmatched])
  end

  it "is unmatched for a unit that holds because its own order was void, and matched for a hold support (AC-8.2)" do
    units = [u(:germany, :army, "boh"), u(:germany, :army, "tyr"), u(:austria, :army, "vie")]
    result = run(units, [mv(:germany, :boh, "bur"), sm(:germany, :tyr, :boh, :bur), sh(:austria, :vie, :boh)])
    expect(results(result, 3)).to eq(%i[void void given])
    expect(results(run(units, [mv(:germany, :boh, "mun"), sm(:germany, :tyr, :boh, :mun)]), 2)).to eq(%i[succeeded given])
  end

  it "ignores the coast when matching, and never calls an unmatched support cut (AC-8.2)" do
    matched = run([u(:france, :fleet, "mao"), u(:france, :fleet, "por")],
                  [mv(:france, :mao, "spa/nc"), sm(:france, :por, :mao, :spa)])
    expect(results(matched, 2)).to eq(%i[succeeded given])
    units = [u(:france, :fleet, "mao"), u(:france, :fleet, "por"), u(:italy, :fleet, "spa/sc")]
    unmatched = run(units, [hd(:france, :mao), sm(:france, :por, :mao, :spa), mv(:italy, :spa, "por")])
    expect(results(unmatched, 3)).to eq(%i[held unmatched bounced])
  end

  it "is cut by a move into the supporter's province from another power, not from the same power (AC-8.3)" do
    units = vie_boh_tyr + [u(:italy, :army, "ven"), u(:germany, :army, "mun")]
    cut = run(units, [mv(:germany, :boh, "vie"), sm(:germany, :tyr, :boh, :vie), mv(:italy, :ven, "tyr")])
    expect(results(cut, 3)).to eq(%i[bounced cut bounced])
    own = run(units, [mv(:germany, :boh, "vie"), sm(:germany, :tyr, :boh, :vie), mv(:germany, :mun, "tyr")])
    expect(results(own, 3)).to eq(%i[succeeded given bounced])
  end

  it "is not cut by the unit it attacks, unless that unit dislodges it (AC-8.3, AC-8.4)" do
    units = [u(:austria, :army, "vie"), u(:germany, :army, "boh"), u(:germany, :army, "tyr"), u(:italy, :army, "ven")]
    attacked = run(units, [mv(:austria, :vie, "boh"), mv(:germany, :boh, "vie"), sm(:germany, :tyr, :boh, :vie)])
    expect(results(attacked, 3)).to eq(%i[bounced succeeded given])
    # Here the supporter is attacked from the supported move's destination and dislodged: cut.
    dislodging = [u(:russia, :fleet, "con"), u(:russia, :fleet, "bla"), u(:turkey, :fleet, "ank"), u(:turkey, :army, "smy"),
                  u(:turkey, :army, "arm")]
    result = run(dislodging, [sm(:russia, :con, :bla, :ank), mv(:russia, :bla, "ank"), mv(:turkey, :ank, "con"),
                              sm(:turkey, :smy, :ank, :con), mv(:turkey, :arm, "ank")])
    expect(results(result, 5)).to eq(%i[cut bounced succeeded given bounced])
    expect(dislodged(result)).to eq(con: :ank)
    kept = run(dislodging.first(4), [sm(:russia, :con, :bla, :ank), mv(:russia, :bla, "ank"), mv(:turkey, :ank, "con")])
    expect(results(kept, 3)).to eq(%i[given succeeded bounced])
  end

  it "is not cut by an attack that has no route, a move that needs a convoy and has none (AC-8.3)" do
    units = [u(:england, :army, "lon"), u(:england, :fleet, "nth"), u(:germany, :army, "bel"), u(:germany, :army, "hol")]
    result = run(units, [mv(:england, :lon, "bel"), sh(:germany, :bel, :hol)])
    expect(results(result, 2)).to eq(%i[no_route given])
    expect(dislodged(result)).to eq({})
  end

  it "counts a support from another power for the supported unit, and not toward dislodging its own (AC-8.5)" do
    foreign = run([u(:austria, :army, "vie"), u(:germany, :army, "boh"), u(:italy, :army, "tyr")],
                  [mv(:germany, :boh, "vie"), sm(:italy, :tyr, :boh, :vie)])
    expect(results(foreign, 2)).to eq(%i[succeeded given])
    own_power = run([u(:austria, :army, "vie"), u(:austria, :army, "gal"), u(:germany, :army, "boh")],
                    [mv(:germany, :boh, "vie"), sm(:austria, :gal, :boh, :vie)])
    expect(results(own_power, 2)).to eq(%i[bounced given])
    expect(dislodged(own_power)).to eq({})
  end

  it "keeps the support's result the same whether its move succeeds or bounces (AC-8.6)" do
    wins = run(vie_boh_tyr, [mv(:germany, :boh, "vie"), sm(:germany, :tyr, :boh, :vie)])
    loses = run(vie_boh_tyr + [u(:austria, :army, "gal")], [mv(:germany, :boh, "vie"), sm(:germany, :tyr, :boh, :vie), sh(:austria, :gal, :vie)])
    expect([wins.outcomes[1].result, loses.outcomes[1].result]).to eq(%i[given given])
    expect([wins.outcomes[0].result, loses.outcomes[0].result]).to eq(%i[succeeded bounced])
  end

  it "can support an unmatched support or an unmatched convoy (AC-8.7)" do
    units = [u(:germany, :army, "ber"), u(:germany, :fleet, "kie"), u(:russia, :fleet, "bal"), u(:russia, :army, "pru")]
    result = run(units, [sh(:germany, :ber, :pru), sh(:germany, :kie, :ber), sm(:russia, :bal, :pru, :ber), mv(:russia, :pru, "ber")])
    expect(results(result, 4)).to eq(%i[unmatched given given bounced])
  end

  it "voids a support for a move that can't be made, and the move too (AC-8.7)" do
    units = [u(:germany, :fleet, "kie"), u(:germany, :army, "bur"), u(:russia, :army, "mun"), u(:russia, :army, "ber")]
    result = run(units, [mv(:germany, :kie, "mun"), sm(:germany, :bur, :kie, :mun), mv(:russia, :mun, "kie"), sm(:russia, :ber, :mun, :kie)])
    expect(results(result, 4)).to eq(%i[void void succeeded given])
    expect(result.outcomes.drop(4).map { [_1.order.at, _1.dislodged] }).to eq([[:bur, false], [:kie, true]])
  end
end

# frozen_string_literal: true

require "trucebearer/adjudicator"
require_relative "../../support/adjudicating"

# Convoys in TA.adjudicate (spec 015, Stories 2 to 5): routes, disruption, the results of
# convoy orders, by_convoy, circular movement with convoys and the paradox flag. The DATC cases
# are in spec/datc/; this file holds the small hand-built positions that show one rule each.
RSpec.describe "TA.adjudicate: convoys" do
  let(:england) { [u(:england, :army, "lon"), u(:england, :fleet, "nth")] }

  describe "routes (AC-2.1 to AC-2.5)" do
    it "carries an army across a chain of fleets that all give matching convoy orders" do
      units = [u(:england, :army, "lon"), u(:england, :fleet, "eng")]
      result = run(units, [mv(:england, :lon, "bel"), cv(:england, :eng, :lon, :bel)])
      expect(results(result, 2)).to eq(%i[succeeded given])
      expect(after(result)).to eq(bel: :england, eng: :england)
    end

    it "has no route when a fleet of the chain gives no matching order, and the army stays" do
      result = run(england, [mv(:england, :lon, "nwy")])
      expect(results(result, 1)).to eq([:no_route])
      expect(after(result)).to eq(lon: :england, nth: :england)
    end

    it "never falls back to land for a move via convoy that nobody convoys (6.G.8)" do
      expect(results(run(england, [mvc(:england, :lon, :yor)]), 1)).to eq([:no_route])
    end

    it "sends a plain move to a neighbor by land when only another power's fleet convoys it (6.G.2)" do
      units = [u(:england, :army, "lon"), u(:germany, :fleet, "nth")]
      result = run(units, [mv(:england, :lon, "yor"), cv(:germany, :nth, :lon, :yor)])
      expect(results(result, 2)).to eq(%i[succeeded unmatched])
    end

    it "carries an army over a fleet of another power that gives a matching convoy order (6.F.10, 6.F.11)" do
      units = [u(:england, :army, "lon"), u(:england, :fleet, "eng"), u(:germany, :fleet, "nth"), u(:france, :army, "bel")]
      result = run(units, [mv(:england, :lon, "bel"), cv(:germany, :nth, :lon, :bel)])
      expect(results(result, 2)).to eq(%i[bounced given])
    end

    it "lets a convoyed army bounce and receive support like any move (6.F.2, 6.F.3)" do
      units = [u(:england, :army, "lon"), u(:england, :fleet, "eng"), u(:england, :fleet, "mao"), u(:france, :army, "par")]
      plain = [mv(:england, :lon, "bre"), cv(:england, :eng, :lon, :bre), mv(:france, :par, "bre")]
      expect(results(run(units, plain), 3)).to eq(%i[bounced given bounced])
      supported = run(units, plain + [sm(:england, :mao, :lon, :bre)])
      expect(results(supported, 4)).to eq(%i[succeeded given bounced given])
    end
  end

  describe "disruption (AC-3.1 to AC-3.5)" do
    let(:units) { england + [u(:germany, :fleet, "ska"), u(:germany, :fleet, "hel")] }
    let(:convoy) { [mv(:england, :lon, "hol"), cv(:england, :nth, :lon, :hol)] }

    it "does not disrupt a convoy whose fleet is attacked but not dislodged (6.F.4)" do
      result = run(units, convoy + [mv(:germany, :ska, "nth")])
      expect(results(result, 3)).to eq(%i[succeeded given bounced])
    end

    it "disrupts the convoy of a dislodged fleet, and the army it carried has no route (6.F.6)" do
      result = run(units, convoy + [mv(:germany, :ska, "nth"), sm(:germany, :hel, :ska, :nth)])
      expect(results(result, 4)).to eq(%i[no_route disrupted succeeded given])
      expect(result.outcomes[1].dislodged).to be(true)
      expect(dislodged(result)).to eq(nth: :ska)
      expect(result.position.dislodged_units.first.by_convoy).to be(false)
    end

    it "gives a convoy order :unmatched when its army goes by land or doesn't move, even if the fleet is dislodged (6.G.3)" do
      by_land = [u(:england, :army, "lon"), u(:germany, :fleet, "nth")]
      expect(results(run(by_land, [mv(:england, :lon, "yor"), cv(:germany, :nth, :lon, :yor)]), 2)).to eq(%i[succeeded unmatched])
      holds = run(units, [hd(:england, :lon), cv(:england, :nth, :lon, :hol), mv(:germany, :ska, "nth"), sm(:germany, :hel, :ska, :nth)])
      expect(results(holds, 4)).to eq(%i[held unmatched succeeded given])
      expect(holds.outcomes[1].dislodged).to be(true)
    end

    it "does not let the result of a convoy depend on the army's fate (AC-3.5)" do
      free = run(units, convoy)
      stopped = run(units + [u(:france, :army, "hol")], convoy + [hd(:france, :hol)])
      expect(results(free, 2)).to eq(%i[succeeded given])
      expect(results(stopped, 2)).to eq(%i[bounced given])
    end

    it "marks the dislodged unit as taken by convoy and attacked from the army's own province (6.D.16)" do
      units = [u(:england, :army, "lon"), u(:england, :fleet, "nth"), u(:france, :army, "bel"), u(:france, :fleet, "eng")]
      result = run(units, [hd(:england, :lon), cv(:england, :nth, :bel, :lon), sm(:france, :eng, :bel, :lon), mv(:france, :bel, "lon")])
      expect(results(result, 4)).to eq(%i[held given given succeeded])
      entry = result.position.dislodged_units.first
      expect([entry.unit.location.province, entry.attacker_from, entry.by_convoy]).to eq([:lon, :bel, true])
    end

    it "keeps a convoyed move from cutting a support when the move has no route (6.F.6)" do
      units = [u(:england, :army, "lon"), u(:england, :fleet, "nth"), u(:germany, :army, "hol"), u(:germany, :army, "bel"),
               u(:germany, :fleet, "ska"), u(:germany, :fleet, "hel")]
      orders = [mv(:england, :lon, "hol"), cv(:england, :nth, :lon, :hol), sh(:germany, :hol, :bel),
                mv(:germany, :ska, "nth"), sm(:germany, :hel, :ska, :nth)]
      expect(results(run(units, orders), 5)).to eq(%i[no_route disrupted given succeeded given])
    end
  end

  describe "swaps and circles with convoys (AC-2.6, AC-4.1)" do
    it "swaps two armies when one goes by convoy, which is not a head-to-head battle (6.G.1)" do
      units = [u(:england, :army, "nwy"), u(:england, :fleet, "ska"), u(:russia, :army, "swe")]
      result = run(units, [mv(:england, :nwy, "swe"), cv(:england, :ska, :nwy, :swe), mv(:russia, :swe, "nwy")])
      expect(results(result, 3)).to eq(%i[succeeded given succeeded])
      expect(after(result)).to eq(swe: :england, nwy: :russia, ska: :england)
    end

    it "swaps two armies that both go by convoy (6.C.6)" do
      units = [u(:england, :army, "lon"), u(:england, :fleet, "nth"), u(:france, :army, "bel"), u(:france, :fleet, "eng")]
      orders = [mv(:england, :lon, "bel"), cv(:england, :nth, :lon, :bel), mv(:france, :bel, "lon"), cv(:france, :eng, :bel, :lon)]
      expect(results(run(units, orders), 4)).to eq(%i[succeeded given succeeded given])
    end

    it "fails both armies of a swap when a third unit bounces one of them (6.C.7)" do
      units = [u(:england, :army, "lon"), u(:england, :fleet, "nth"), u(:france, :army, "bel"), u(:france, :fleet, "eng"), u(:france, :army, "bur")]
      orders = [mv(:england, :lon, "bel"), cv(:england, :nth, :lon, :bel), mv(:france, :bel, "lon"), cv(:france, :eng, :bel, :lon),
                mv(:france, :bur, "bel")]
      expect(results(run(units, orders), 5)).to eq(%i[bounced given bounced given bounced])
    end
  end

  describe "convoy paradoxes (AC-5.1 to AC-5.6)" do
    let(:paradox_units) { [u(:england, :fleet, "lon"), u(:england, :fleet, "wal"), u(:france, :army, "bre"), u(:france, :fleet, "eng")] }
    let(:paradox_orders) do
      [mv(:england, :wal, "eng"), sm(:england, :lon, :wal, :eng), mv(:france, :bre, "lon"), cv(:france, :eng, :bre, :lon)]
    end

    it "sets the flag for the simplest paradox and still returns a valid position" do
      result = run(paradox_units, paradox_orders)
      expect(result.paradox).to be(true)
      expect(result.position.units.size + result.position.dislodged_units.size).to eq(4)
      expect(result.outcomes.size).to eq(4)
    end

    it "sets the flag when the convoyed army has a support too, since a cut doesn't need success" do
      units = paradox_units + [u(:france, :fleet, "yor")]
      result = run(units, paradox_orders + [sm(:france, :yor, :bre, :lon)])
      expect(result.paradox).to be(true)
    end

    it "keeps the flag clear when the convoyed army attacks nothing that decides its fleet" do
      steady = run(paradox_units, [mv(:england, :wal, "eng"), mv(:france, :bre, "lon"), cv(:france, :eng, :bre, :lon)])
      expect(steady.paradox).to be(false)
      expect(results(steady, 3)).to eq(%i[bounced bounced given])
    end

    it "flags a paradox next to independent orders, and still places every unit once" do
      units = paradox_units + [u(:italy, :army, "tun"), u(:italy, :fleet, "ion")]
      result = run(units, paradox_orders + [mv(:italy, :tun, "gre"), cv(:italy, :ion, :tun, :gre)])
      expect(result.paradox).to be(true)
      expect(result.position.units.size + result.position.dislodged_units.size).to eq(6)
      expect(result.outcomes.size).to eq(6)
    end

    it "flags a paradox beside a circle that holds a convoyed army, and still places every unit once" do
      units = paradox_units + [u(:austria, :army, "tri"), u(:austria, :army, "ser"), u(:turkey, :army, "bul"),
                               u(:turkey, :fleet, "aeg"), u(:turkey, :fleet, "ion"), u(:turkey, :fleet, "adr")]
      orders = paradox_orders + [mv(:austria, :tri, "ser"), mv(:austria, :ser, "bul"), mv(:turkey, :bul, "tri"),
                                 cv(:turkey, :aeg, :bul, :tri), cv(:turkey, :ion, :bul, :tri), cv(:turkey, :adr, :bul, :tri)]
      result = run(units, orders)
      expect(result.paradox).to be(true)
      expect(result.position.units.size + result.position.dislodged_units.size).to eq(10)
      expect(results(result, 10).last(6)).to eq(%i[succeeded succeeded succeeded given given given])
    end

    it "does not flag a circle that holds a convoyed army (6.C.4)" do
      units = [u(:austria, :army, "tri"), u(:austria, :army, "ser"), u(:turkey, :army, "bul"), u(:turkey, :fleet, "aeg"),
               u(:turkey, :fleet, "ion"), u(:turkey, :fleet, "adr")]
      orders = [mv(:austria, :tri, "ser"), mv(:austria, :ser, "bul"), mv(:turkey, :bul, "tri"),
                cv(:turkey, :aeg, :bul, :tri), cv(:turkey, :ion, :bul, :tri), cv(:turkey, :adr, :bul, :tri)]
      result = run(units, orders)
      expect(results(result, 6)).to eq(%i[succeeded succeeded succeeded given given given])
      expect(result.paradox).to be(false)
    end
  end
end

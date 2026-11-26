# frozen_string_literal: true

require "trucebearer/adjudicator"
require_relative "../../support/adjudicating"

# Dislodgement and the next position (Story 9); head-to-head battles, beleaguered
# garrisons and circular movement (Story 10). The DATC cases of these (6.C, 6.D, 6.E) are
# fixtures, run in spec/datc/datc_adjudicate_spec.rb.
RSpec.describe "TA.adjudicate: dislodgement, battles and circles" do
  describe "the dislodged units" do
    it "records the unit, its attacker's province and no convoy, and flags only the order it followed (AC-9.2)" do
      units = [u(:austria, :army, "vie"), u(:austria, :army, "gal"), u(:germany, :army, "boh"), u(:germany, :army, "tyr")]
      result = run(units, [sm(:austria, :gal, :vie, :bud), mv(:germany, :boh, "vie"), sm(:germany, :tyr, :boh, :vie)])
      expect(result.position.dislodged_units).to eq(
        [TA::DislodgedUnit.new(unit: u(:austria, :army, "vie"), attacker_from: :boh, by_convoy: false)]
      )
      expect(after(result)).to eq(gal: :austria, vie: :germany, tyr: :germany)
      expect(result.outcomes.select(&:dislodged).map { _1.order.at }).to eq([:vie])
      expect(result.outcomes.last.order).to eq(hd(:austria, :vie))
      expect(result.outcomes.last.dislodged).to be(true)
    end

    it "flags a dislodged unit's failed move, in the order it followed (AC-9.2)" do
      units = [u(:austria, :army, "vie"), u(:germany, :army, "boh"), u(:italy, :army, "tri"), u(:italy, :army, "tyr")]
      result = run(units, [mv(:austria, :vie, "boh"), mv(:italy, :tri, "vie"), sm(:italy, :tyr, :tri, :vie)])
      expect(results(result, 3)).to eq(%i[bounced succeeded given])
      expect(result.outcomes.map { [_1.order.at, _1.dislodged] }.select(&:last)).to eq([[:vie, true]])
      expect(dislodged(result)).to eq(vie: :tri)
    end

    it "flags a dislodged supporter, whose support is cut (AC-9.2)" do
      units = [u(:austria, :army, "vie"), u(:austria, :army, "gal"), u(:italy, :army, "tri"), u(:italy, :army, "tyr")]
      result = run(units, [sh(:austria, :vie, :gal), mv(:italy, :tri, "vie"), sm(:italy, :tyr, :tri, :vie)])
      expect(results(result, 3)).to eq(%i[cut succeeded given])
      expect(result.outcomes.map { [_1.order.at, _1.dislodged] }.select(&:last)).to eq([[:vie, true]])
      expect(dislodged(result)).to eq(vie: :tri)
    end

    it "flags a dislodged convoying fleet, whose convoy order is unmatched in this release (AC-9.2)" do
      units = [u(:england, :army, "lon"), u(:england, :fleet, "nth"), u(:germany, :fleet, "hel"), u(:germany, :fleet, "ska")]
      result = run(units, [cv(:england, :nth, :lon, :nwy), mv(:germany, :hel, "nth"), sm(:germany, :ska, :hel, :nth)])
      expect(results(result, 3)).to eq(%i[unmatched succeeded given])
      expect(result.outcomes.map { [_1.order.at, _1.dislodged] }.select(&:last)).to eq([[:nth, true]])
      expect(dislodged(result)).to eq(nth: :hel)
    end

    it "keeps a dislodged fleet's coast, and names the attacker's province with no coast (AC-9.3)" do
      units = [u(:france, :fleet, "spa/nc"), u(:italy, :fleet, "gol"), u(:italy, :fleet, "wes")]
      result = run(units, [mv(:italy, :gol, "spa/sc"), sm(:italy, :wes, :gol, :spa)])
      entry = result.position.dislodged_units.first
      expect(entry.unit.location).to eq(L.new(province: :spa, coast: :nc))
      expect(entry.attacker_from).to eq(:gol)
      expect(result.position.units.find { _1.location.province == :spa }.location).to eq(L.new(province: :spa, coast: :sc))
    end

    it "dislodges an army next to a split-coast province (AC-9.3)" do
      units = [u(:france, :army, "mar"), u(:germany, :army, "gas"), u(:germany, :army, "bur")]
      result = run(units, [mv(:germany, :gas, "mar"), sm(:germany, :bur, :gas, :mar)])
      expect(dislodged(result)).to eq(mar: :gas)
      expect(result.position.dislodged_units.first.by_convoy).to be(false)
    end

    it "keeps every unit once, and the season, year, map and ownership (AC-9.4)" do
      start = TA::Map.classic.starting_position
      orders = [mv(:germany, :kie, "hol"), mv(:england, :lon, "nth"), mv(:russia, :war, "gal"), mv(:austria, :vie, "gal")]
      result = TA.adjudicate(start, orders)
      position = result.position
      expect([position.season, position.year, position.map, position.phase]).to eq([:spring, 1901, "classic", :retreat])
      expect(position.ownership).to eq(start.ownership)
      expect(position.units.size + position.dislodged_units.size).to eq(start.units.size)
    end
  end

  describe "units that can't be dislodged by their own power (AC-9.6)" do
    it "gives a move against a unit of the mover's own power no strength" do
      units = [u(:germany, :army, "ber"), u(:germany, :fleet, "kie"), u(:germany, :army, "mun")]
      result = run(units, [hd(:germany, :ber), mv(:germany, :kie, "ber"), sm(:germany, :mun, :kie, :ber)])
      expect(results(result, 3)).to eq(%i[held bounced given])
      expect(dislodged(result)).to eq({})
    end
  end

  describe "head-to-head battles" do
    let(:vie_tyr) { [u(:austria, :army, "vie"), u(:austria, :army, "boh"), u(:italy, :army, "tyr")] }

    it "lets the stronger unit win and dislodges the other (AC-10.1)" do
      result = run(vie_tyr, [mv(:austria, :vie, "tyr"), sm(:austria, :boh, :vie, :tyr), mv(:italy, :tyr, "vie")])
      expect(results(result, 3)).to eq(%i[succeeded given bounced])
      expect(dislodged(result)).to eq(tyr: :vie)
      expect(after(result)).to eq(tyr: :austria, boh: :austria)
    end

    it "bounces both when they are equal (AC-10.1)" do
      result = run([u(:austria, :army, "vie"), u(:italy, :army, "tyr")], [mv(:austria, :vie, "tyr"), mv(:italy, :tyr, "vie")])
      expect(results(result, 2)).to eq(%i[bounced bounced])
      expect(after(result)).to eq(vie: :austria, tyr: :italy)
    end

    it "bounces both when they belong to one power, even with support (AC-10.1)" do
      units = [u(:austria, :army, "vie"), u(:austria, :army, "tyr"), u(:austria, :army, "boh")]
      result = run(units, [mv(:austria, :vie, "tyr"), mv(:austria, :tyr, "vie"), sm(:austria, :boh, :vie, :tyr)])
      expect(results(result, 3)).to eq(%i[bounced bounced given])
    end
  end

  describe "a unit attacked from several sides" do
    it "fails every attack of equal strength and dislodges nobody (AC-10.2)" do
      units = [u(:germany, :army, "tyr"), u(:austria, :army, "vie"), u(:germany, :army, "mun"), u(:italy, :army, "ven")]
      result = run(units, [hd(:germany, :tyr), mv(:austria, :vie, "tyr"), mv(:germany, :mun, "tyr"), mv(:italy, :ven, "tyr")])
      expect(results(result, 4)).to eq(%i[held bounced bounced bounced])
      expect(dislodged(result)).to eq({})
    end
  end

  describe "circular movement" do
    # Armies that can step around: tri, ser, bud, vie (four), and with gal for five.
    def circle(power, *provinces)
      provinces.each_cons(2).map { |from, to| mv(power, from, to.to_s) } << mv(power, provinces.last, provinces.first.to_s)
    end

    def circle_units(power, *provinces) = provinces.map { |province| u(power, :army, province.to_s) }

    it "moves a circle of three, four and five units, with no paradox (AC-10.3)" do
      [%i[ank con smy], %i[tri ser bud vie], %i[tri ser bud gal vie]].each do |provinces|
        result = run(circle_units(:austria, *provinces), circle(:austria, *provinces))
        expect(results(result, provinces.size)).to eq([:succeeded] * provinces.size)
        expect(result.paradox).to be(false)
        expect(after(result).keys).to match_array(provinces)
      end
    end

    it "moves two circles that share no province, of different powers (AC-10.3)" do
      units = circle_units(:austria, :tri, :ser, :bud, :vie) + circle_units(:turkey, :ank, :con, :smy)
      orders = circle(:austria, :tri, :ser, :bud, :vie) + circle(:turkey, :ank, :con, :smy)
      result = run(units, orders)
      expect(results(result, 7)).to eq([:succeeded] * 7)
      expect(result.paradox).to be(false)
    end

    it "moves a circle that one supported move runs through, and one of another power (AC-10.3)" do
      units = [u(:turkey, :fleet, "ank"), u(:turkey, :army, "smy"), u(:turkey, :army, "bul"), u(:italy, :army, "con")]
      orders = [mv(:turkey, :ank, "con"), mv(:turkey, :smy, "ank"), sm(:turkey, :bul, :ank, :con), mv(:italy, :con, "smy")]
      result = run(units, orders)
      expect(results(result, 4)).to eq(%i[succeeded succeeded given succeeded])
      expect(result.paradox).to be(false)
    end

    it "holds the whole circle when a fourth unit bounces one of its moves (AC-10.3)" do
      units = circle_units(:austria, :tri, :ser, :bud, :vie) + [u(:italy, :army, "ven")]
      result = run(units, circle(:austria, :tri, :ser, :bud, :vie) + [mv(:italy, :ven, "tri")])
      expect(results(result, 5)).to eq([:bounced] * 5)
      expect(after(result).keys).to match_array(%i[tri ser bud vie ven])
      expect(result.paradox).to be(false)
    end
  end
end

# frozen_string_literal: true

require "trucebearer/adjudicator"
require_relative "../../support/adjudicating"

# What TA.adjudicate refuses (Story 5), and void orders and implied holds (Story 6).
RSpec.describe "TA.adjudicate: input, void orders and implied holds" do
  let(:start) { TA::Map.classic.starting_position }
  let(:retreat) { TA::Position.from_h(start.to_h.merge("phase" => "retreat")) }
  let(:adjustment) { TA::Position.from_h(start.to_h.merge("phase" => "adjustment")) }

  describe "what it refuses" do
    it "raises for a position that isn't in the movement phase, naming the phase (AC-5.1)" do
      expect { TA.adjudicate(retreat, []) }.to raise_error(TA::InvalidInput, /retreat/)
      expect { TA.adjudicate(adjustment, []) }.to raise_error(TA::InvalidInput, /adjustment/)
    end

    it "raises for two orders of one power for one province, naming both (AC-5.2)" do
      [
        [hd(:england, :lon), hd(:england, :lon)],
        [hd(:england, :lon), mv(:england, :lon, "nth")],
        [hd(:england, :wal), hd(:england, :wal)],
        [hd(:england, :lon), hd(:england, :lon), hd(:france, :lon)]
      ].each do |orders|
        expect { TA.adjudicate(start, orders) }.to raise_error(TA::InvalidInput, /(england|france).*(lon|wal)/)
      end
      expect { TA.adjudicate(start, [hd(:france, :lon), hd(:france, :lon)]) }.to raise_error(TA::InvalidInput, /france.*lon/)
    end

    it "raises the errors in a fixed order: wrong class, then phase, then duplicates (AC-5.2)" do
      twice = [hd(:england, :lon), hd(:england, :lon)]
      expect { TA.adjudicate(retreat, twice) }.to raise_error(TA::InvalidInput, /retreat/)
      expect { TA.adjudicate(nil, twice) }.to raise_error(TA::InvalidInput, /position/)
      expect { TA.adjudicate(retreat, [nil, nil]) }.to raise_error(TA::InvalidInput, /nil/)
    end

    it "raises for an argument of the wrong class, naming it (AC-5.3)" do
      [nil, {}, start.to_h, :start].each { |bad| expect { TA.adjudicate(bad, []) }.to raise_error(TA::InvalidInput, /position/) }
      [nil, {}, hd(:england, :lon)].each { |bad| expect { TA.adjudicate(start, bad) }.to raise_error(TA::InvalidInput, /orders/) }
      [nil, hd(:england, :lon).to_h, TA::CheckResult.new(legal: true, reasons: [])].each do |bad|
        expect { TA.adjudicate(start, [bad]) }.to raise_error(TA::InvalidInput, /#{Regexp.escape(bad.inspect[0, 20])}/)
      end
    end

    it "refuses as input what an Adjudication refuses as output (AC-3.4)" do
      expect { TA.adjudicate(start, [hd(:england, :lon), mv(:england, :lon, "nth")]) }.to raise_error(TA::InvalidInput)
      held = TA::Outcome.new(order: hd(:england, :lon), result: :held, submitted: true, dislodged: false)
      expect { TA::Adjudication.new(outcomes: [held, held], paradox: false, position: start) }
        .to raise_error(TA::InvalidInput, /same power and province/)
    end

    it "never raises for orders of different powers for one unit (AC-5.4)" do
      result = TA.adjudicate(start, [hd(:france, :lon), mv(:england, :lon, "nth"), hd(:germany, :lon)])
      expect(results(result, 3)).to eq(%i[void succeeded void])
      expect(result.outcomes.first(3).map { _1.order.power }).to eq(%i[france england germany])
      result = TA.adjudicate(start, [hd(:france, :wal), hd(:england, :wal)])
      expect(results(result, 2)).to eq(%i[void void])
    end

    it "changes none of its arguments, and gives equal results twice (AC-5.5)" do
      orders = [mv(:england, :lon, "nth"), hd(:france, :lon)]
      first = TA.adjudicate(start, orders)
      expect(orders).not_to be_frozen
      expect(orders.size).to eq(2)
      expect(start).to eq(TA::Map.classic.starting_position)
      expect(TA.adjudicate(start, orders)).to eq(first)
    end
  end

  describe "void orders" do
    # One position and one order for each reason checking can give, except wrong_phase.
    let(:lon_bel) { Board.position(u(:england, :army, "lon"), u(:england, :army, "bel")) }
    let(:convoys) { Board.position(u(:england, :army, "lon"), u(:england, :fleet, "nth"), u(:england, :fleet, "eng")) }
    let(:cases) do
      {
        no_such_unit: [start, hd(:england, :wal)],
        foreign_unit: [start, hd(:france, :lon)],
        own_province: [start, mv(:england, :lon, "lon")],
        not_reachable: [start, mv(:england, :lon, "bel")],
        coast_not_allowed: [start, mv(:france, :mar, "spa/nc")],
        coast_required: [Board.position(u(:france, :fleet, "por")), mv(:france, :por, "spa")],
        coast_unreachable: [Board.position(u(:france, :fleet, "gol")), mv(:france, :gol, "spa/nc")],
        not_army: [Board.position(u(:england, :fleet, "lon")), mvc(:england, :lon, :wal)],
        not_adjacent: [Board.position(u(:england, :army, "lon")), mvc(:england, :lon, :bel)],
        no_convoy_route: [start, mvc(:england, :lvp, :wal)],
        same_province: [lon_bel, sm(:england, :lon, :bel, :bel)],
        no_unit: [start, sh(:germany, :mun, :sil)],
        move_impossible: [lon_bel, sm(:england, :lon, :bel, :yor)],
        not_fleet_at_sea: [start, cv(:england, :lon, :lvp, :bel)],
        bad_endpoints: [convoys, cv(:england, :nth, :lon, :lon)],
        not_on_chain: [convoys, cv(:england, :eng, :lon, :nwy)]
      }
    end

    it "is void exactly when TA.check says the order is illegal, never dislodged, always submitted (AC-6.1)" do
      expect(cases.keys).to match_array(TA::CheckResult::REASONS - [:wrong_phase])
      cases.each do |reason, (position, order)|
        expect(TA.check(position, order).reasons).to eq([reason])
        outcome = TA.adjudicate(position, [order]).outcomes.first
        expect([outcome.result, outcome.dislodged, outcome.submitted]).to eq([:void, false, true]), reason.to_s
      end
      legal = [hd(:england, :lon), mv(:england, :lon, "nth"), sh(:germany, :mun, :ber),
               sm(:austria, :vie, :war, :gal)]
      legal.each do |order|
        expect(TA.check(start, order).legal).to be(true)
        expect(TA.adjudicate(start, [order]).outcomes.first.result).not_to eq(:void)
      end
    end

    it "gives the unit an implied hold when its only order is void (AC-6.2)" do
      result = TA.adjudicate(start, [hd(:france, :lon)])
      implied = result.outcomes.find { _1.order.at == :lon && !_1.submitted }
      expect([implied.order.power, implied.result]).to eq(%i[england held])
    end
  end

  describe "implied holds" do
    it "come after the submitted outcomes, sorted by province, each held and owned by the unit's owner (AC-6.3)" do
      result = TA.adjudicate(start, [mv(:russia, :war, "gal"), hd(:france, :lon), hd(:austria, :vie)])
      expect(result.outcomes.first(3).map { _1.order.at }).to eq(%i[war lon vie])
      implied = result.outcomes.drop(3)
      expect(implied.size).to eq(20)
      expect(implied.map { _1.order.at }).to eq(implied.map { _1.order.at }.sort)
      expect(implied.map(&:submitted)).to all(be(false))
      expect(implied.map(&:result)).to all(eq(:held))
      expect(implied.map(&:dislodged)).to all(be(false))
      owners = start.units.to_h { [_1.location.province, _1.power] }
      expect(implied.map { [_1.order.at, _1.order.power] }).to all(satisfy { |at, power| owners[at] == power })
      expect(implied.map { _1.order.at }).not_to include(:war, :vie)
    end

    it "can be supported and dislodged, and a dislodged one is still held (AC-6.4)" do
      units = [u(:austria, :army, "vie"), u(:germany, :army, "boh"), u(:germany, :army, "tyr"), u(:russia, :army, "gal")]
      result = run(units, [mv(:germany, :boh, "vie"), sm(:germany, :tyr, :boh, :vie), sh(:russia, :gal, :vie)])
      implied = result.outcomes.last
      expect([implied.order.at, implied.result, implied.dislodged, implied.submitted]).to eq([:vie, :held, false, false])
      expect(results(result, 3)).to eq(%i[bounced given given])
      units = [u(:austria, :army, "vie"), u(:germany, :army, "boh"), u(:germany, :army, "tyr")]
      implied = run(units, [mv(:germany, :boh, "vie"), sm(:germany, :tyr, :boh, :vie)]).outcomes.last
      expect([implied.result, implied.dislodged]).to eq([:held, true])
    end

    it "a void support doesn't cut, support or move, and its unit holds (AC-6.4)" do
      units = [u(:england, :army, "lon"), u(:england, :army, "bel"), u(:germany, :army, "kie"), u(:germany, :army, "hol")]
      result = run(units, [sm(:england, :lon, :bel, :yor), mv(:germany, :kie, "hol")])
      expect(results(result, 2)).to eq(%i[void bounced])
      expect(after(result)[:lon]).to eq(:england)
    end

    it "makes every unit hold when no order is given (AC-6.5)" do
      result = TA.adjudicate(start, [])
      expect(result.outcomes.size).to eq(22)
      expect(result.outcomes.map(&:result)).to all(eq(:held))
      expect(result.paradox).to be(false)
      expect(result.position.units).to eq(start.units)
      expect(result.position.phase).to eq(:retreat)
    end
  end
end

require "rails_helper"
require_relative "../support/rules_helpers"

RSpec.describe RulesEngine do
  include RulesHelpers

  let(:start) { RulesEngine.starting_position }

  it "gives the classic starting position, with 22 units (AC-2.1)" do
    expect([ start.map, start.season, start.year, start.phase ]).to eq([ "classic", :spring, 1901, :movement ])
    expect(start.units.size).to eq(22)
  end

  it "checks England's hold in London as legal (AC-2.2)" do
    order = RulesEngine.load_order({ "format" => 1, "type" => "hold", "power" => "england", "at" => "lon" })
    result = RulesEngine.check(start, order)
    expect(result.legal).to be(true)
    expect(result.reasons).to eq([])
  end

  it "gives a reason for an illegal order (AC-2.3)" do
    result = RulesEngine.check(start, rules_order(:hold, :france, :lon))
    expect([ result.legal, result.reasons ]).to eq([ false, [ :foreign_unit ] ])
  end

  it "lists legal orders starting with the hold, and every one passes check (AC-2.4)" do
    fleet = start.units.find { |u| u.location.province == :lon }
    orders = RulesEngine.legal_orders(start, fleet)
    expect(orders.first).to eq(rules_order(:hold, :england, :lon))
    expect(orders.map { |o| RulesEngine.check(start, o).legal }).to all(be(true))
  end

  describe ".powers" do
    it "lists the seven powers of the classic map, each with an id and a name (spec 021 FR-12)" do
      expect(RulesEngine.powers.map(&:id)).to eq(%i[austria england france germany italy russia turkey])
      expect(RulesEngine.powers.map(&:name)).to eq(RulesEngine.powers.map { |power| power.id.to_s.capitalize })
    end

    it "agrees with the names the power badge draws, so the two lists cannot drift" do
      expect(PowerBadgeHelper::POWER_NAMES).to eq(RulesEngine.powers.to_h { |power| [ power.id.to_s, power.name ] })
    end
  end

  describe "loaders" do
    let(:order_hashes) do
      [ { "type" => "hold", "power" => "england", "at" => "lon" },
        { "type" => "move", "power" => "france", "at" => "mao", "destination" => { "province" => "spa", "coast" => "nc" } },
        { "type" => "move_via_convoy", "power" => "england", "at" => "lon", "to" => "wal" },
        { "type" => "support_hold", "power" => "germany", "at" => "mun", "target" => "ber" },
        { "type" => "support_move", "power" => "france", "at" => "por", "from" => "mao", "to" => "spa" },
        { "type" => "convoy", "power" => "england", "at" => "nth", "from" => "lon", "to" => "nwy" } ]
        .map { |h| { "format" => 1 }.merge(h) }
    end

    it "round-trips each kind through JSON (AC-2.5)" do
      order_hashes.each do |h|
        order = RulesEngine.load_order(JSON.parse(JSON.generate(h)))
        expect(order.to_h).to eq(h)
      end
      expect(RulesEngine.load_position(JSON.parse(JSON.generate(start.to_h)))).to eq(start)
      [ rules_order(:hold, :england, :lon), rules_order(:hold, :france, :lon) ].each do |order|
        result = RulesEngine.check(start, order)
        expect(RulesEngine.load_check_result(JSON.parse(JSON.generate(result.to_h)))).to eq(result)
      end
    end

    it "returns an object of the right kind as it is, and nil as nil (AC-2.5a)" do
      order = rules_order(:hold, :england, :lon)
      expect(RulesEngine.load_order(order)).to equal(order)
      expect(RulesEngine.load_position(start)).to equal(start)
      verdict = RulesEngine.check(start, order)
      expect(RulesEngine.load_check_result(verdict)).to equal(verdict)
      expect([ RulesEngine.load_order(nil), RulesEngine.load_position(nil), RulesEngine.load_check_result(nil) ]).to all(be_nil)
    end

    it "raises InvalidInput naming a value of the wrong kind (AC-2.5b)" do
      [ 5, "hold", [], rules_order(:hold, :england, :lon) ].each do |bad|
        expect { RulesEngine.load_position(bad) }.to raise_error(RulesEngine::InvalidInput, /#{Regexp.escape(bad.inspect)}/)
      end
      [ 5, "x", [], start ].each do |bad|
        expect { RulesEngine.load_order(bad) }.to raise_error(RulesEngine::InvalidInput, /#{Regexp.escape(bad.inspect)}/)
        expect { RulesEngine.load_check_result(bad) }.to raise_error(RulesEngine::InvalidInput, /#{Regexp.escape(bad.inspect)}/)
      end
      expect(RulesEngine.load_check_result(nil)).to be_nil
    end

    it "raises InvalidInput, naming the offending key or value, for a bad hash (AC-2.6)" do
      good = start.to_h
      hold = order_hashes.first
      verdict = RulesEngine.check(start, rules_order(:hold, :england, :lon)).to_h
      {
        load_position: [ [ good.merge("format" => 2), /format 2/ ], [ good.except("format"), /"format"/ ],
                         [ good.merge("extra" => 1), /"extra"/ ], [ good.except("year"), /"year"/ ],
                         [ good.merge("year" => "1901"), /"year".*1901/ ], [ good.transform_keys(&:to_sym), /"format"/ ] ],
        load_order: [ [ hold.merge("format" => 2), /format 2/ ], [ hold.except("at"), /"at"/ ],
                      [ hold.merge("type" => "dance"), /dance/ ], [ hold.merge("extra" => 1), /"extra"/ ] ],
        load_check_result: [ [ verdict.merge("format" => 2), /format 2/ ], [ verdict.except("legal"), /"legal"/ ],
                             [ verdict.merge("extra" => 1), /"extra"/ ] ]
      }.each do |loader, cases|
        cases.each do |bad, message|
          expect { RulesEngine.public_send(loader, bad) }.to raise_error(RulesEngine::InvalidInput, message)
        end
      end
    end
  end

  it "says whether an identifier is a province of the map (spec 022 AC-2.5)" do
    expect(RulesEngine.province?("lon")).to be(true)
    expect(RulesEngine.province?(:lon)).to be(true)
    expect([ "xyz", "", nil, "LON", "lon " ].map { |id| RulesEngine.province?(id) }).to all(be(false))
  end
end

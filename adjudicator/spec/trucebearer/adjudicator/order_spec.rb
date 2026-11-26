# frozen_string_literal: true

require "json"
require "trucebearer/adjudicator"
require_relative "../../support/board"

RSpec.describe Trucebearer::Adjudicator::Order do
  # class, keywords, hash form (the interface examples)
  cases = [
    [O::Hold, { power: :england, at: :lon },
     { "format" => 1, "type" => "hold", "power" => "england", "at" => "lon" }],
    [O::Move, { power: :france, at: :mao, destination: L.new(province: :spa, coast: :nc) },
     { "format" => 1, "type" => "move", "power" => "france", "at" => "mao", "destination" => { "province" => "spa", "coast" => "nc" } }],
    [O::MoveViaConvoy, { power: :england, at: :lon, to: :wal },
     { "format" => 1, "type" => "move_via_convoy", "power" => "england", "at" => "lon", "to" => "wal" }],
    [O::SupportHold, { power: :germany, at: :mun, target: :ber },
     { "format" => 1, "type" => "support_hold", "power" => "germany", "at" => "mun", "target" => "ber" }],
    [O::SupportMove, { power: :france, at: :por, from: :mao, to: :spa },
     { "format" => 1, "type" => "support_move", "power" => "france", "at" => "por", "from" => "mao", "to" => "spa" }],
    [O::Convoy, { power: :england, at: :nth, from: :lon, to: :nwy },
     { "format" => 1, "type" => "convoy", "power" => "england", "at" => "nth", "from" => "lon", "to" => "nwy" }]
  ].freeze

  it "has the six classes, with the fields the interface gives (AC-3.1, AC-3.2)" do
    expect(cases.map { |klass, _, _| klass.members }).to eq(
      [%i[power at], %i[power at destination], %i[power at to], %i[power at target], %i[power at from to], %i[power at from to]]
    )
    expect(cases.map { |_, _, hash| O.from_h(hash).class }).to eq(cases.map(&:first))
    expect(O::SupportMove.new(power: :france, at: :por, from: :mao, to: :spa))
      .not_to eq(O::Convoy.new(power: :france, at: :por, from: :mao, to: :spa))
  end

  cases.each do |klass, keywords, hash|
    describe klass.name.split("::").last do
      let(:order) { klass.new(**keywords) }

      it "is frozen, equal to one with the same contents, and gives its hash form (AC-3.1, AC-3.2)" do
        expect(order).to be_frozen
        expect(order).to eq(klass.new(**keywords))
        expect(order.hash).to eq(klass.new(**keywords).hash)
        expect(order.to_h).to eq(hash)
        expect(order.to_h.keys).to eq(hash.keys)
      end

      it "round-trips through JSON, through its own from_h and through Order.from_h (AC-3.3)" do
        json = JSON.parse(JSON.generate(order.to_h))
        expect(klass.from_h(json)).to eq(order)
        expect(O.from_h(json)).to eq(order)
        expect(O.from_h(json)).to be_a(klass)
      end

      it "refuses the hash of each other class (AC-3.5)" do
        cases.each do |other, _, other_hash|
          next if other == klass

          expect { klass.from_h(other_hash) }.to raise_error(TA::InvalidInput, /#{Regexp.escape(other_hash["type"].inspect)}/)
        end
      end

      it "refuses a missing key, an unknown key, symbol keys and a non-hash (AC-3.11)" do
        hash.each_key do |key|
          expect { klass.from_h(hash.reject { |k, _| k == key }) }.to raise_error(TA::InvalidInput, /#{Regexp.escape(key.inspect)}/)
        end
        expect { klass.from_h(hash.merge("extra" => 1)) }.to raise_error(TA::InvalidInput, /"extra"/)
        expect { klass.from_h(hash.transform_keys(&:to_sym)) }.to raise_error(TA::InvalidInput)
        expect { klass.from_h("order") }.to raise_error(TA::InvalidInput, /"order"/)
        expect { klass.from_h(hash.merge("power" => :england)) }.to raise_error(TA::InvalidInput, /:england/)
        expect { klass.from_h(hash.merge("power" => "atlantis")) }.to raise_error(TA::InvalidInput, /"atlantis"/)
      end

      it "refuses a bad format, naming it (AC-4.2, AC-4.5)" do
        expect { klass.from_h(hash.reject { |k, _| k == "format" }) }.to raise_error(TA::InvalidInput, /"format"/)
        [2, 0, "1", 1.0, nil].each do |bad|
          expect { klass.from_h(hash.merge("format" => bad)) }.to raise_error(TA::InvalidInput, /#{Regexp.escape(bad.inspect)}/)
          expect { O.from_h(hash.merge("format" => bad)) }.to raise_error(TA::InvalidInput, /#{Regexp.escape(bad.inspect)}/)
        end
      end

      it "refuses a missing keyword, and a bad power or at, in new (AC-1.10, AC-3.10)" do
        expect { klass.new(**keywords.reject { |k, _| k == :at }) }.to raise_error(ArgumentError)
        expect { klass.new(**keywords, extra: 1) }.to raise_error(ArgumentError)
        expect { klass.new(**keywords.merge(power: "england")) }.to raise_error(TA::InvalidInput, /"england"/)
        expect { klass.new(**keywords.merge(power: :atlantis)) }.to raise_error(TA::InvalidInput, /:atlantis/)
        expect { klass.new(**keywords.merge(at: :xyz)) }.to raise_error(TA::InvalidInput, /:xyz/)
        expect { klass.new(**keywords.merge(at: "lon")) }.to raise_error(TA::InvalidInput, /"lon"/)
      end

      it "refuses an impossible change made with #with (AC-5.11)" do
        expect { order.with(at: :xyz) }.to raise_error(TA::InvalidInput, /:xyz/)
      end

      it "writes only plain data, with string keys all the way down (AC-4.3)" do
        plain = lambda do |value|
          case value
          when Hash then value.all? { |k, v| k.is_a?(String) && plain.call(v) }
          when Array then value.all? { plain.call(_1) }
          else [String, Integer, true, false, nil].any? { |type| type === value }
          end
        end
        expect(plain.call(order.to_h)).to be(true)
      end
    end
  end

  describe "province fields and location fields (AC-3.6, AC-3.7, AC-3.12)" do
    province_fields = { O::Hold => %w[at], O::Move => %w[at], O::MoveViaConvoy => %w[at to],
                        O::SupportHold => %w[at target], O::SupportMove => %w[at from to], O::Convoy => %w[at from to] }

    province_fields.each do |klass, fields|
      it "refuses a coast, a location, a symbol, nil or an unknown name in each province field of #{klass.name.split("::").last}" do
        valid = cases.find { |k, _, _| k == klass }.last
        fields.each do |field|
          [{ "province" => "spa", "coast" => "nc" }, { "province" => "spa", "coast" => nil }, :spa, nil, "xyz"].each do |bad|
            expect { klass.from_h(valid.merge(field => bad)) }.to raise_error(TA::InvalidInput, /#{Regexp.escape(bad.inspect)}/)
          end
        end
      end
    end

    it "refuses a Location or a string in a province field of new, and a non-Location destination (AC-3.7)" do
      expect { O::Hold.new(power: :england, at: L.new(province: :lon)) }.to raise_error(TA::InvalidInput, /#{Regexp.escape(L.new(province: :lon).inspect)}/)
      expect { O::MoveViaConvoy.new(power: :england, at: :lon, to: "wal") }.to raise_error(TA::InvalidInput, /"wal"/)
      [:spa, nil, { "province" => "spa", "coast" => nil }].each do |bad|
        expect { O::Move.new(power: :france, at: :mao, destination: bad) }.to raise_error(TA::InvalidInput, /#{Regexp.escape(bad.inspect)}/)
      end
      expect(O::Move.new(power: :france, at: :mao, destination: L.new(province: :spa, coast: :nc))).to be_a(O::Move)
    end

    it "refuses a destination that is not exactly a location hash (AC-3.12)" do
      valid = cases.find { |k, _, _| k == O::Move }.last
      [["spa", /"spa"/], [nil, /nil/], [:spa, /:spa/], [{ "province" => "spa" }, /"coast"/],
       [{ "province" => "spa", "coast" => nil, "x" => 1 }, /"x"/], [{ "province" => "par", "coast" => "nc" }, /"nc"/]].each do |bad, pattern|
        expect { O::Move.from_h(valid.merge("destination" => bad)) }.to raise_error(TA::InvalidInput, pattern)
        expect { O.from_h(valid.merge("destination" => bad)) }.to raise_error(TA::InvalidInput, pattern)
      end
    end
  end

  describe ".from_h" do
    it "refuses an unknown, missing or non-string type, and a non-hash (AC-3.4)" do
      hold = cases.first.last
      ["teleport", "Hold"].each { |bad| expect { O.from_h(hold.merge("type" => bad)) }.to raise_error(TA::InvalidInput, /#{Regexp.escape(bad.inspect)}/) }
      [:hold, nil, 1].each { |bad| expect { O.from_h(hold.merge("type" => bad)) }.to raise_error(TA::InvalidInput, /#{Regexp.escape(bad.inspect)}/) }
      expect { O.from_h(hold.reject { |k, _| k == "type" }) }.to raise_error(TA::InvalidInput, /"type"/)
      expect { O.from_h("hold") }.to raise_error(TA::InvalidInput, /"hold"/)
    end

    it "checks format and type before the other keys (AC-3.5)" do
      hold = cases.first.last
      expect { O::Move.from_h(hold) }.to raise_error(TA::InvalidInput, /"hold"/)
    end

    it "leaves its argument alone, accepts a frozen hash, and holds no reference to it (AC-2.9)" do
      move = cases.find { |k, _, _| k == O::Move }.last
      parsed = JSON.parse(JSON.generate(move))
      before = Marshal.load(Marshal.dump(parsed))
      order = O.from_h(Ractor.make_shareable(parsed))
      expect(parsed).to eq(before)
      expect(order.destination).to eq(L.new(province: :spa, coast: :nc))
      fresh = JSON.parse(JSON.generate(move))
      built = O.from_h(fresh)
      fresh["power"] << "x"
      fresh["destination"]["province"] << "x"
      expect(built).to eq(O::Move.new(power: :france, at: :mao, destination: L.new(province: :spa, coast: :nc)))
    end
  end

  describe "orders that break a rule of the game (AC-3.8)" do
    it "builds them, with new and with from_h" do
      odd = [
        O::Move.new(power: :england, at: :lon, destination: L.new(province: :lon)),
        O::Move.new(power: :germany, at: :mun, destination: L.new(province: :nth)),
        O::Convoy.new(power: :france, at: :par, from: :bur, to: :bur),
        O::SupportMove.new(power: :france, at: :par, from: :bur, to: :bur),
        O::Hold.new(power: :turkey, at: :nth)
      ]
      odd.each { |order| expect(O.from_h(JSON.parse(JSON.generate(order.to_h)))).to eq(order) }
    end
  end

  describe "round trips over every place (AC-3.9)" do
    it "round-trips a Move to each of the 81 locations" do
      Board.locations.each do |location|
        order = O::Move.new(power: :france, at: :mao, destination: location)
        json = JSON.parse(JSON.generate(order.to_h))
        expect([O::Move.from_h(json), O.from_h(json)]).to eq([order, order])
      end
    end

    it "round-trips each province in each province field of each class" do
      Board.provinces.each do |id|
        orders = [O::Hold.new(power: :italy, at: id), O::Move.new(power: :italy, at: id, destination: L.new(province: :nth)),
                  O::MoveViaConvoy.new(power: :italy, at: id, to: id),
                  O::SupportHold.new(power: :italy, at: id, target: id), O::SupportMove.new(power: :italy, at: id, from: id, to: id),
                  O::Convoy.new(power: :italy, at: id, from: id, to: id)]
        orders.each do |order|
          json = JSON.parse(JSON.generate(order.to_h))
          expect([order.class.from_h(json), O.from_h(json)]).to eq([order, order])
        end
      end
    end
  end
end

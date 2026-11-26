# frozen_string_literal: true

require "trucebearer/adjudicator"
require_relative "../../support/board"

# docs/interface.md promises that value objects are immutable and validated. Marshal
# builds an object without going through `initialize`, so these specs hold it to the
# same promise: a round trip returns an equal, deeply frozen object, and a payload
# describing an impossible object raises InvalidInput on load. (Issue #77)
RSpec.describe "Marshal round trips of the value objects" do
  let(:starting_position) { TA::Map.classic.starting_position }

  # A retreat-phase position that fills every field, so the nested lists are not empty.
  let(:retreat_position) do
    dislodged = TA::DislodgedUnit.new(unit: Board.army, attacker_from: :rum, by_convoy: true)
    TA::Position.new(map: "classic", season: :fall, year: 1902, phase: :retreat,
                     units: [Board.fleet], ownership: { bud: :austria, stp: :russia },
                     dislodged_units: [dislodged], standoffs: %i[vie boh])
  end

  # What a Marshal payload for a class with marshal_dump looks like: "\x04\b" is the
  # format version, "U" marks a user-marshalled object, then comes the class name as a
  # symbol, then the dumped value. Dumping `[name, value]` in one stream and dropping
  # its four-byte array header ("\x04\b[\x07") keeps Marshal's back-references
  # numbered as in a real dump. Two separate dumps joined together would not be.
  def payload(klass, value)
    "\x04\bU".b + Marshal.dump([klass.name.to_sym, value])[4..]
  end

  def deeply_frozen?(value)
    return false unless value.frozen?

    case value
    when Array then value.all? { |element| deeply_frozen?(element) }
    when Hash then value.all? { |key, element| deeply_frozen?(key) && deeply_frozen?(element) }
    when Data then value.class.members.all? { |name| deeply_frozen?(value.public_send(name)) }
    else true
    end
  end

  # [label, object]. Every value object: the ones the Issue names, and CheckResult (#11).
  objects = [
    ["Location with a coast", -> { L.new(province: :spa, coast: :nc) }],
    ["Location without a coast", -> { L.new(province: :bud) }],
    ["Unit", -> { Board.fleet }],
    ["DislodgedUnit", -> { TA::DislodgedUnit.new(unit: Board.army, attacker_from: :rum, by_convoy: false) }],
    ["Position, the 1901 start", -> { TA::Map.classic.starting_position }],
    ["Position, a retreat phase", lambda {
      TA::Position.new(map: "classic", season: :fall, year: 1902, phase: :retreat,
                       units: [Board.fleet], ownership: { bud: :austria, stp: :russia },
                       dislodged_units: [TA::DislodgedUnit.new(unit: Board.army, attacker_from: :rum, by_convoy: true)],
                       standoffs: %i[vie boh])
    }],
    ["Hold", -> { O::Hold.new(power: :england, at: :lon) }],
    ["Move", -> { O::Move.new(power: :france, at: :mao, destination: L.new(province: :spa, coast: :nc)) }],
    ["MoveViaConvoy", -> { O::MoveViaConvoy.new(power: :england, at: :lon, to: :wal) }],
    ["SupportHold", -> { O::SupportHold.new(power: :germany, at: :mun, target: :ber) }],
    ["SupportMove", -> { O::SupportMove.new(power: :france, at: :por, from: :mao, to: :spa) }],
    ["Convoy", -> { O::Convoy.new(power: :england, at: :nth, from: :lon, to: :nwy) }],
    ["CheckResult, legal", -> { TA::CheckResult.new(legal: true, reasons: []) }],
    ["CheckResult, illegal", -> { TA::CheckResult.new(legal: false, reasons: [:no_unit]) }],
    ["Outcome, an implied hold", -> { TA::Outcome.new(order: O::Hold.new(power: :england, at: :lon), result: :held, submitted: false, dislodged: false) }],
    ["Outcome, a dislodged move", lambda {
      TA::Outcome.new(order: O::Move.new(power: :germany, at: :boh, destination: L.new(province: :vie)),
                      result: :bounced, submitted: true, dislodged: true)
    }],
    ["Adjudication, hand built", lambda {
      held = TA::Outcome.new(order: O::Hold.new(power: :england, at: :lon), result: :held, submitted: true, dislodged: false)
      TA::Adjudication.new(outcomes: [held], paradox: false, position: TA::Map.classic.starting_position)
    }],
    ["Adjudication, with a dislodged unit", lambda {
      move = O::Move.new(power: :germany, at: :boh, destination: L.new(province: :vie))
      outcomes = [TA::Outcome.new(order: O::Hold.new(power: :austria, at: :vie), result: :held, submitted: false, dislodged: true),
                  TA::Outcome.new(order: move, result: :succeeded, submitted: true, dislodged: false)]
      dislodged = TA::DislodgedUnit.new(unit: Board.army, attacker_from: :boh, by_convoy: false)
      TA::Adjudication.new(outcomes: outcomes.reverse, paradox: false,
                           position: TA::Position.new(map: "classic", season: :spring, year: 1901, phase: :retreat,
                                                      units: [Board.fleet], ownership: {}, dislodged_units: [dislodged], standoffs: []))
    }]
  ]

  it "returns an equal position whose units are frozen, for the 1901 start (the Issue's own example)" do
    loaded = Marshal.load(Marshal.dump(starting_position))
    expect(loaded).to eq(starting_position)
    expect(loaded.units).to be_frozen
  end

  objects.each do |label, build|
    describe label do
      let(:object) { build.call }
      let(:loaded) { Marshal.load(Marshal.dump(object)) }

      it "round-trips to an equal object, deeply frozen" do
        expect(loaded).to eq(object)
        expect(loaded.class).to eq(object.class)
        expect(loaded.hash).to eq(object.hash)
        expect(loaded.to_h).to eq(object.to_h)
        expect(deeply_frozen?(loaded)).to be(true)
      end

      it "round-trips with freeze: true as well" do
        frozen_load = Marshal.load(Marshal.dump(object), freeze: true)
        expect(frozen_load).to eq(object)
        expect(deeply_frozen?(frozen_load)).to be(true)
      end

      it "dumps the hash form, so a hand-built payload of to_h is the same bytes (checks the spec helper)" do
        expect(payload(object.class, object.to_h)).to eq(Marshal.dump(object))
      end

      it "loads an untampered hand-built payload as an equal object (checks the spec helper)" do
        expect(Marshal.load(payload(object.class, object.to_h))).to eq(object)
      end

      it "cannot have initialize or marshal_load run again on the loaded object" do
        expect { loaded.send(:initialize, **loaded.deconstruct_keys(nil)) }.to raise_error(FrozenError)
        expect { loaded.send(:marshal_load, loaded.to_h) }.to raise_error(FrozenError)
      end

      it "keeps the Marshal hooks out of the public interface" do
        expect(object.public_methods).not_to include(:marshal_dump, :marshal_load)
      end

      it "refuses a payload that is not a hash form" do
        [nil, 1, "text", [object.to_h], { symbol: 1 }].each do |value|
          expect { Marshal.load(payload(object.class, value)) }.to raise_error(TA::InvalidInput)
        end
      end

      it "refuses a hash form with a key missing, or an extra key" do
        key = object.to_h.keys.last
        expect { Marshal.load(payload(object.class, object.to_h.reject { |k, _| k == key })) }
          .to raise_error(TA::InvalidInput, /#{key}/)
        expect { Marshal.load(payload(object.class, object.to_h.merge("extra" => 1))) }
          .to raise_error(TA::InvalidInput, /"extra"/)
      end
    end
  end

  describe "objects nested in other objects" do
    it "keeps the units of a position, each on its own and inside it, frozen and equal" do
      retreat_position.units.each do |unit|
        alone = Marshal.load(Marshal.dump(unit))
        expect(alone).to eq(unit)
        expect(deeply_frozen?(alone)).to be(true)
      end
      inside = Marshal.load(Marshal.dump(retreat_position)).units
      expect(inside).to eq(retreat_position.units)
      expect(deeply_frozen?(inside)).to be(true)
    end

    it "keeps the nested lists, mappings and strings of a position frozen" do
      loaded = Marshal.load(Marshal.dump(retreat_position))
      expect(loaded.units).to be_frozen
      expect(loaded.ownership).to be_frozen
      expect(loaded.dislodged_units).to be_frozen
      expect(loaded.standoffs).to be_frozen
      expect(loaded.map).to be_frozen
      expect(loaded.dislodged_units.first.unit.location).to be_frozen
    end

    it "puts the lists back in canonical order, even from a payload written out of order" do
      hash = retreat_position.to_h
      hash["standoffs"] = %w[vie boh]
      hash["ownership"] = { "stp" => "russia", "bud" => "austria" }
      hash["units"] = [Board.fleet, Board.army].map(&:to_h)
      loaded = Marshal.load(payload(TA::Position, hash))
      expect(loaded.standoffs).to eq(%i[boh vie])
      expect(loaded.ownership.keys).to eq(%i[bud stp])
      expect(loaded.units.map { |unit| unit.location.province }).to eq(%i[bud stp])
    end

    it "round-trips a whole list of objects, as a cache would hold them" do
      list = [starting_position, retreat_position, O::Hold.new(power: :england, at: :lon)]
      expect(Marshal.load(Marshal.dump(list))).to eq(list)
    end
  end

  describe "a tampered payload that describes an impossible object" do
    # [class, hash form, change to make, what the error says]
    spots = [
      [TA::Location, ->(h) { h.merge("province" => "xyz") }, /"xyz"/],
      [TA::Location, ->(h) { h.merge("province" => "par", "coast" => "nc") }, /coast/],
      [TA::Unit, ->(h) { h.merge("type" => "fleet", "location" => { "province" => "mun", "coast" => nil }) }, /inland/],
      [TA::Unit, ->(h) { h.merge("type" => "army", "location" => { "province" => "spa", "coast" => "nc" }) }, /coast/],
      [TA::Unit, ->(h) { h.merge("type" => "fleet", "location" => { "province" => "spa", "coast" => nil }) }, /coast/],
      [TA::Unit, ->(h) { h.merge("power" => "narnia") }, /"narnia"/],
      [TA::DislodgedUnit, ->(h) { h.merge("attacker_from" => "xyz") }, /"xyz"/],
      [TA::DislodgedUnit, ->(h) { h.merge("by_convoy" => "yes") }, /by_convoy/],
      [TA::Position, ->(h) { h.merge("format" => 2) }, /format/],
      [TA::Position, ->(h) { h.reject { |k, _| k == "format" } }, /format/],
      [TA::Position, ->(h) { h.merge("map" => "modern") }, /map/],
      [TA::Position, ->(h) { h.merge("standoffs" => ["bur"]) }, /movement/],
      [TA::Position, ->(h) { h.merge("ownership" => { "bur" => "france" }) }, /"bur"/],
      [TA::Position, ->(h) { h.merge("units" => h["units"] + [h["units"].first]) }, /share the province/],
      [O::Hold, ->(h) { h.merge("format" => 2) }, /format/],
      [O::Hold, ->(h) { h.merge("at" => "xyz") }, /"xyz"/],
      [O::Hold, ->(h) { h.merge("type" => "move") }, /"move"/],
      [O::Move, ->(h) { h.merge("destination" => { "province" => "par", "coast" => "nc" }) }, /coast/],
      [O::MoveViaConvoy, ->(h) { h.merge("to" => "xyz") }, /"xyz"/],
      [O::SupportHold, ->(h) { h.merge("target" => "spa/nc") }, /"spa\/nc"/],
      [O::SupportMove, ->(h) { h.merge("to" => "spa/nc") }, /"spa\/nc"/],
      [O::Convoy, ->(h) { h.merge("from" => "xyz") }, /"xyz"/],
      [TA::CheckResult, ->(h) { h.merge("format" => 2) }, /format/],
      [TA::CheckResult, ->(h) { h.merge("reasons" => ["bogus"]) }, /"bogus"/],
      [TA::CheckResult, ->(h) { h.merge("legal" => true) }, /no reasons/],
      [TA::Outcome, ->(h) { h.merge("result" => "bounced") }, /bounced/],
      [TA::Outcome, ->(h) { h.merge("result" => "void", "dislodged" => true) }, /void/],
      [TA::Outcome, ->(h) { h.merge("order" => h["order"].merge("format" => 2)) }, /format/],
      [TA::Adjudication, ->(h) { h.merge("format" => 2) }, /format/],
      [TA::Adjudication, ->(h) { h.merge("outcomes" => h["outcomes"].dup.insert(1, h["outcomes"].first)) }, /same power and province/],
      [TA::Adjudication, ->(h) { h.merge("paradox" => "no") }, /paradox/]
    ]
    bases = {
      TA::Location => -> { L.new(province: :bud) },
      TA::Unit => -> { Board.army },
      TA::DislodgedUnit => -> { TA::DislodgedUnit.new(unit: Board.army, attacker_from: :rum, by_convoy: false) },
      TA::Position => -> { TA::Map.classic.starting_position },
      O::Hold => -> { O::Hold.new(power: :england, at: :lon) },
      O::Move => -> { O::Move.new(power: :france, at: :mao, destination: L.new(province: :spa, coast: :nc)) },
      O::MoveViaConvoy => -> { O::MoveViaConvoy.new(power: :england, at: :lon, to: :wal) },
      O::SupportHold => -> { O::SupportHold.new(power: :germany, at: :mun, target: :ber) },
      O::SupportMove => -> { O::SupportMove.new(power: :france, at: :por, from: :mao, to: :spa) },
      O::Convoy => -> { O::Convoy.new(power: :england, at: :nth, from: :lon, to: :nwy) },
      TA::CheckResult => -> { TA::CheckResult.new(legal: false, reasons: [:no_unit]) },
      TA::Outcome => -> { TA::Outcome.new(order: O::Hold.new(power: :england, at: :lon), result: :held, submitted: true, dislodged: false) },
      TA::Adjudication => lambda {
        outcomes = [TA::Outcome.new(order: O::Hold.new(power: :england, at: :lon), result: :held, submitted: true, dislodged: false),
                    TA::Outcome.new(order: O::Hold.new(power: :france, at: :bre), result: :held, submitted: false, dislodged: false)]
        TA::Adjudication.new(outcomes: outcomes, paradox: false, position: TA::Map.classic.starting_position)
      }
    }

    spots.each_with_index do |(klass, change, message), index|
      it "raises InvalidInput on load, as from_h would (#{klass.name.split("::").last}, case #{index + 1})" do
        tampered = change.call(bases.fetch(klass).call.to_h)
        expect { klass.from_h(tampered) }.to raise_error(TA::InvalidInput, message)
        expect { Marshal.load(payload(klass, tampered)) }.to raise_error(TA::InvalidInput, message)
        expect { Marshal.load(payload(klass, tampered), freeze: true) }.to raise_error(TA::InvalidInput, message)
      end
    end

    it "raises InvalidInput for a unit tampered inside a position, naming the unit's problem" do
      hash = starting_position.to_h
      hash["units"][0] = hash["units"][0].merge("type" => "fleet", "location" => { "province" => "mun", "coast" => nil })
      expect { Marshal.load(payload(TA::Position, hash)) }.to raise_error(TA::InvalidInput, /inland/)
    end

    # A limit, written down so the interface wording stays honest. Ruby reads a payload in
    # its plain struct format ("S") straight into the fields in C, without calling
    # `initialize` or `marshal_load`, so no Ruby code can check it. If a future Ruby
    # closes this, this example fails: then the docs can promise more.
    it "does not catch a payload built by hand in Ruby's plain struct format (a limit of Ruby)" do
      symbol = ->(name) { Marshal.dump(name.to_sym)[2..] }
      by_hand = "\x04\bS".b + symbol.call(TA::Location.name) + "\x07".b +
                symbol.call(:province) + symbol.call(:xyz) + symbol.call(:coast) + "0".b
      expect { TA::Location.from_h("province" => "xyz", "coast" => nil) }.to raise_error(TA::InvalidInput)
      expect(Marshal.load(by_hand).province).to eq(:xyz)
    end
  end
end

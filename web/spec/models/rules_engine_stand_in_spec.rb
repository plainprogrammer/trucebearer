require "rails_helper"
require_relative "../support/rules_helpers"

# The stand-in's outcomes are FAKE (spec 019, FR-3). These specs pin what it does, not what the rules say.
RSpec.describe "RulesEngine.adjudicate, the stand-in" do
  include RulesHelpers

  let(:start) { RulesEngine.starting_position }

  # Gate B condition: a case never quietly tests a void order. Every order a case relies on is
  # asserted legal through check before its outcome is asserted.
  def adjudicate_legal(position, orders)
    orders.each do |order|
      result = RulesEngine.check(position, order)
      expect(result.legal).to be(true), "expected #{order.to_h} to be legal, got #{result.reasons}"
    end
    RulesEngine.adjudicate(position, orders)
  end

  def results(adjudication) = adjudication.outcomes.map(&:result)
  def outcome_for(adjudication, at) = adjudication.outcomes.find { |o| o.order.at == at && o.submitted }
  def provinces(adjudication) = adjudication.position.units.map { |u| u.location.province }

  it "succeeds two separate moves and gives the other 20 units implied holds (AC-3.1)" do
    adj = adjudicate_legal(start, [ move(:england, :lon, :nth), move(:germany, :kie, :hol) ])
    expect(results(adj).first(2)).to eq([ :succeeded, :succeeded ])
    implied = adj.outcomes.reject(&:submitted)
    expect(implied.size).to eq(20)
    expect(implied.map(&:result).uniq).to eq([ :held ])
    expect(implied.map { |o| o.order.at }).to eq(implied.map { |o| o.order.at }.sort)
    expect(adj.paradox).to be(false)
    expect(provinces(adj)).to include(:nth, :hol)
  end

  it "bounces two moves into one province and records the standoff (AC-3.2)" do
    adj = adjudicate_legal(start, [ move(:russia, :war, :gal), move(:austria, :vie, :gal) ])
    expect(results(adj).first(2)).to eq([ :bounced, :bounced ])
    expect(provinces(adj)).not_to include(:gal)
    expect(adj.position.standoffs).to eq([ :gal ])
  end

  it "voids a failing order and gives the owner's unit an implied hold (AC-3.3)" do
    order = rules_order(:hold, :france, :lon)
    expect(RulesEngine.check(start, order).legal).to be(false)
    adj = RulesEngine.adjudicate(start, [ order ])
    expect(adj.outcomes.first).to have_attributes(result: :void, submitted: true, dislodged: false)
    expect(adj.outcomes.find { |o| o.order.at == :lon && !o.submitted }.result).to eq(:held)
  end

  it "gives a legal support or convoy :given with no effect (AC-3.4)" do
    pos = rules_position(units: [ [ :england, :army, :lon ], [ :england, :fleet, :nth ], [ :germany, :army, :mun ], [ :germany, :army, :ber ] ])
    adj = adjudicate_legal(pos, [ rules_order(:convoy, :england, :nth, from: "lon", to: "nwy"),
                                  rules_order(:support_hold, :germany, :mun, target: "ber"),
                                  move(:germany, :ber, :sil) ])
    expect(results(adj).first(3)).to eq([ :given, :given, :succeeded ])
    expect(provinces(adj)).to contain_exactly(:lon, :nth, :mun, :sil)
  end

  describe "a move into a province whose unit stays (AC-3.5)" do
    it "bounces when the unit holds" do
      pos = rules_position(units: [ [ :russia, :army, :war ], [ :austria, :army, :gal ] ])
      adj = adjudicate_legal(pos, [ move(:russia, :war, :gal), rules_order(:hold, :austria, :gal) ])
      expect(results(adj)).to eq([ :bounced, :held ])
      expect(adj.position.standoffs).to eq([])
    end

    it "bounces when the unit's order is void" do
      pos = rules_position(units: [ [ :russia, :army, :war ], [ :austria, :army, :gal ] ])
      void = rules_order(:hold, :russia, :gal)
      expect(RulesEngine.check(pos, void).legal).to be(false)
      attack = move(:russia, :war, :gal)
      expect(RulesEngine.check(pos, attack).legal).to be(true)
      adj = RulesEngine.adjudicate(pos, [ attack, void ])
      expect(outcome_for(adj, :war).result).to eq(:bounced)
      expect(outcome_for(adj, :gal).result).to eq(:void)
      expect(adj.position.standoffs).to eq([])
    end

    it "bounces when the unit supports" do
      pos = rules_position(units: [ [ :russia, :army, :war ], [ :austria, :army, :gal ], [ :austria, :army, :vie ] ])
      adj = adjudicate_legal(pos, [ move(:russia, :war, :gal), rules_order(:support_hold, :austria, :gal, target: "vie") ])
      expect(outcome_for(adj, :war).result).to eq(:bounced)
      expect(outcome_for(adj, :gal).result).to eq(:given)
    end

    it "bounces when the unit convoys" do
      pos = rules_position(units: [ [ :france, :fleet, :eng ], [ :england, :fleet, :nth ], [ :england, :army, :lon ] ])
      adj = adjudicate_legal(pos, [ move(:france, :eng, :nth), rules_order(:convoy, :england, :nth, from: "lon", to: "nwy") ])
      expect(outcome_for(adj, :eng).result).to eq(:bounced)
      expect(outcome_for(adj, :nth).result).to eq(:given)
    end

    it "bounces when the unit's own move bounced" do
      pos = rules_position(units: [ [ :russia, :army, :war ], [ :austria, :army, :gal ], [ :austria, :army, :bud ] ])
      adj = adjudicate_legal(pos, [ move(:russia, :war, :gal), move(:austria, :gal, :bud), rules_order(:hold, :austria, :bud) ])
      expect(results(adj)).to eq([ :bounced, :bounced, :held ])
    end
  end

  it "succeeds a move into a province whose unit moves away successfully (AC-3.6)" do
    pos = rules_position(units: [ [ :russia, :army, :war ], [ :austria, :army, :gal ] ])
    adj = adjudicate_legal(pos, [ move(:russia, :war, :gal), move(:austria, :gal, :bud) ])
    expect(results(adj)).to eq([ :succeeded, :succeeded ])
    expect(provinces(adj)).to contain_exactly(:gal, :bud)
  end

  it "succeeds a swap and a rotation (AC-3.6a; fake: 0.2.0 corrects it)" do
    swap = rules_position(units: [ [ :france, :army, :par ], [ :france, :army, :bur ] ])
    adj = adjudicate_legal(swap, [ move(:france, :par, :bur), move(:france, :bur, :par) ])
    expect(results(adj)).to eq([ :succeeded, :succeeded ])
    expect(provinces(adj)).to contain_exactly(:par, :bur)

    ring = rules_position(units: [ [ :france, :army, :par ], [ :france, :army, :bur ], [ :france, :army, :gas ] ])
    adj = adjudicate_legal(ring, [ move(:france, :par, :bur), move(:france, :bur, :gas), move(:france, :gas, :par) ])
    expect(results(adj)).to eq([ :succeeded, :succeeded, :succeeded ])
  end

  it "bounces a chain of moves behind a blocked move (AC-3.6b)" do
    pos = rules_position(units: [ [ :france, :army, :par ], [ :france, :army, :bur ], [ :germany, :army, :mun ], [ :austria, :army, :boh ] ])
    adj = adjudicate_legal(pos, [ move(:france, :par, :bur), move(:france, :bur, :mun), move(:germany, :mun, :boh) ])
    expect(results(adj).first(3)).to eq([ :bounced, :bounced, :bounced ])
    expect(provinces(adj)).to contain_exactly(:par, :bur, :mun, :boh)
  end

  it "bounces three moves into one empty province, and lists the standoff once (AC-3.6c)" do
    pos = rules_position(units: [ [ :germany, :army, :ber ], [ :germany, :army, :mun ], [ :russia, :army, :war ] ])
    adj = adjudicate_legal(pos, [ move(:germany, :ber, :sil), move(:germany, :mun, :sil), move(:russia, :war, :sil) ])
    expect(results(adj)).to eq([ :bounced, :bounced, :bounced ])
    expect(adj.position.standoffs).to eq([ :sil ])
  end

  it "keeps the destination coast for a fleet, and gives no coast on leaving a split coast (AC-3.6d)" do
    pos = rules_position(units: [ [ :france, :fleet, :mao ], [ :russia, :fleet, :stp, :sc ] ])
    adj = adjudicate_legal(pos, [ move(:france, :mao, :spa, :nc), move(:russia, :stp, :bot) ])
    expect(results(adj)).to eq([ :succeeded, :succeeded ])
    coasts = adj.position.units.to_h { |u| [ u.location.province, u.location.coast ] }
    expect(coasts).to eq(spa: :nc, bot: nil)
  end

  it "treats a legal move via convoy as a move to its destination (AC-3.6e)" do
    pos = rules_position(units: [ [ :england, :army, :lon ], [ :england, :fleet, :eng ] ])
    adj = adjudicate_legal(pos, [ rules_order(:move_via_convoy, :england, :lon, to: "wal") ])
    expect(outcome_for(adj, :lon).result).to eq(:succeeded)
    wal = adj.position.units.find { |u| u.location.province == :wal }
    expect([ wal.power, wal.type, wal.location.coast ]).to eq([ :england, :army, nil ])
  end

  it "bounces two moves into a province whose unit moves away, and lists the standoff once (AC-3.6g)" do
    pos = rules_position(units: [ [ :germany, :army, :mun ], [ :austria, :army, :boh ], [ :russia, :army, :sil ] ])
    adj = adjudicate_legal(pos, [ move(:germany, :mun, :ber), move(:austria, :boh, :mun), move(:russia, :sil, :mun) ])
    expect(results(adj)).to eq([ :succeeded, :bounced, :bounced ])
    expect(adj.position.standoffs).to eq([ :mun ])
  end

  it "never raises and always builds a valid next position over seeded random legal orders (AC-3.6f)" do
    rng = Random.new(2026)
    positions = [
      start,
      rules_position(units: [ [ :france, :fleet, :mao ], [ :france, :fleet, :gol ], [ :france, :army, :mar ], [ :england, :fleet, :nth ], [ :england, :army, :lon ] ]),
      rules_position(units: [ [ :russia, :fleet, :stp, :sc ], [ :russia, :army, :mos ], [ :russia, :fleet, :sev ], [ :turkey, :fleet, :bla ], [ :germany, :army, :ber ] ])
    ]
    phases = 0
    positions.each do |pos|
      120.times do
        orders = pos.units.map { |u| RulesEngine.legal_orders(pos, u).sample(random: rng) }
        adj = RulesEngine.adjudicate(pos, orders)
        expect(RulesEngine.load_position(adj.position.to_h)).to eq(adj.position)
        expect(adj.outcomes.map(&:dislodged)).to all(be(false))
        expect([ adj.paradox, adj.position.phase, adj.position.dislodged_units ]).to eq([ false, :retreat, [] ])
        expect([ adj.position.season, adj.position.year, adj.position.ownership ]).to eq([ pos.season, pos.year, pos.ownership ])
        expect(RulesEngine.load_adjudication(JSON.parse(JSON.generate(adj.to_h)))).to eq(adj)
        phases += 1
      end
    end
    expect(phases).to be >= 300
  end

  it "dislodges nobody and keeps season, year and ownership, with the phase :retreat (AC-3.7)" do
    adj = adjudicate_legal(start, [ move(:england, :lon, :nth), move(:russia, :war, :gal), move(:austria, :vie, :gal) ])
    expect(adj.outcomes.map(&:dislodged)).to all(be(false))
    expect(adj.position.dislodged_units).to eq([])
    expect([ adj.position.season, adj.position.year, adj.position.ownership ]).to eq([ :spring, 1901, start.ownership ])
    expect(adj.position.phase).to eq(:retreat)
  end

  it "lists submitted orders in the order given, then implied holds by province, with documented results (AC-3.8)" do
    orders = [ move(:england, :lon, :nth), move(:germany, :kie, :hol) ] # lon comes after kie by province, so a sort would reorder them
    adj = adjudicate_legal(start, orders)
    expect(adj.outcomes.first(2).map(&:order)).to eq(orders)
    implied_provinces = adj.outcomes.drop(2).map { |o| o.order.at }
    expect(implied_provinces).to eq(implied_provinces.sort)
    documented = %i[void held no_route bounced succeeded unmatched cut given disrupted]
    expect(documented).to include(*results(adj).uniq)
  end

  it "raises InvalidInput for a retreat position, duplicate orders and wrong arguments (AC-3.9)" do
    retreat = rules_position(units: [ [ :england, :fleet, :lon ] ], phase: "retreat")
    expect { RulesEngine.adjudicate(retreat, []) }.to raise_error(RulesEngine::InvalidInput)
    hold = rules_order(:hold, :england, :lon)
    expect { RulesEngine.adjudicate(start, [ hold, hold ]) }.to raise_error(RulesEngine::InvalidInput)
    expect { RulesEngine.adjudicate(start, [ hold, move(:england, :lon, :nth) ]) }.to raise_error(RulesEngine::InvalidInput)
    expect { RulesEngine.adjudicate(5, []) }.to raise_error(RulesEngine::InvalidInput)
    expect { RulesEngine.adjudicate(start, "orders") }.to raise_error(RulesEngine::InvalidInput)
    expect { RulesEngine.adjudicate(start, [ 5 ]) }.to raise_error(RulesEngine::InvalidInput)
  end

  it "gives the documented hash form (AC-3.10)" do
    adj = adjudicate_legal(start, [ move(:england, :lon, :nth) ])
    hash = adj.to_h
    expect(hash.keys).to contain_exactly("format", "outcomes", "paradox", "position")
    expect(hash["format"]).to eq(1)
    expect(hash["outcomes"].first.keys).to contain_exactly("order", "result", "submitted", "dislodged")
    expect(hash["outcomes"].first["order"]["format"]).to eq(1)
    expect(hash["outcomes"].first["result"]).to eq("succeeded")
    expect(RulesEngine.load_position(hash["position"])).to eq(adj.position)
    expect(JSON.parse(JSON.generate(hash))).to eq(hash)
  end

  it "has the readers of the gem's own result classes (AC-5.2)" do
    adj = adjudicate_legal(start, [ move(:england, :lon, :nth) ])
    expect(adj).to respond_to(:outcomes, :paradox, :position)
    expect(adj.outcomes.first).to respond_to(:order, :result, :submitted, :dislodged)
    expect(adj.outcomes).to be_frozen
  end

  describe "load_adjudication (AC-2.5, 2.5a, 2.5b, 2.6)" do
    let(:adj) { adjudicate_legal(start, [ move(:england, :lon, :nth) ]) }
    let(:good) { JSON.parse(JSON.generate(adj.to_h)) }

    it "round-trips, and returns an adjudication or nil as it is" do
      expect(RulesEngine.load_adjudication(good)).to eq(adj)
      expect(RulesEngine.load_adjudication(adj)).to equal(adj)
      expect(RulesEngine.load_adjudication(nil)).to be_nil
    end

    it "raises InvalidInput naming a wrong kind of value" do
      [ 5, "x", [], start ].each do |bad|
        expect { RulesEngine.load_adjudication(bad) }.to raise_error(RulesEngine::InvalidInput, /#{Regexp.escape(bad.inspect)}/)
      end
    end

    it "raises InvalidInput for each kind of bad hash" do
      outcome = good["outcomes"].first
      bad = [ [ good.merge("format" => 2), /"format".*2/ ], [ good.except("format"), /"format"/ ],
              [ good.transform_keys(&:to_sym), /"format"/ ], [ good.merge("extra" => 1), /"extra"/ ],
              [ good.except("paradox"), /"paradox"/ ], [ good.merge(mixed: 1), /:mixed/ ],
              [ good.merge("outcomes" => "none"), /"outcomes".*none/ ], [ good.merge("paradox" => "no"), /"paradox".*no/ ],
              [ good.merge("position" => nil), /"position"/ ], [ good.merge("position" => 5), /"position".*5/ ],
              [ good.merge("outcomes" => [ outcome.merge("format" => 1) ]), /"format"/ ],
              [ good.merge("outcomes" => [ outcome.merge("result" => "won") ]), /"result".*won/ ],
              [ good.merge("outcomes" => [ outcome.merge("submitted" => "yes") ]), /"submitted".*yes/ ],
              [ good.merge("outcomes" => [ outcome.except("order") ]), /"order"/ ] ]
      bad.each { |h, message| expect { RulesEngine.load_adjudication(h) }.to raise_error(RulesEngine::InvalidInput, message) }
    end
  end
end

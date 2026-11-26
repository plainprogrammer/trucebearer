# frozen_string_literal: true

require "trucebearer/adjudicator"
require_relative "../../support/board"

# Every Ruby example in docs/interface.md under "## Legal orders" (AC-7.1), built as the
# document builds it.
RSpec.describe "docs/interface.md examples: legal orders" do
  let(:start) { TA::Map.classic.starting_position }
  let(:fleet) { TA::Unit.new(power: :england, type: :fleet, location: L.new(province: :lon)) }
  let(:at_sea) do
    TA::Position.new(map: "classic", season: :spring, year: 1901, phase: :movement, ownership: {},
                     dislodged_units: [], standoffs: [],
                     units: [TA::Unit.new(power: :france, type: :fleet, location: L.new(province: :mao)),
                             TA::Unit.new(power: :france, type: :fleet, location: L.new(province: :gol))])
  end
  let(:retreat) { TA::Position.from_h(start.to_h.merge("phase" => "retreat")) }
  let(:ln) do
    TA::Position.new(map: "classic", season: :spring, year: 1901, phase: :movement, ownership: {},
                     dislodged_units: [], standoffs: [],
                     units: [TA::Unit.new(power: :england, type: :army, location: L.new(province: :lon)),
                             TA::Unit.new(power: :england, type: :fleet, location: L.new(province: :nth))])
  end

  it "gives the list order example" do
    expect(TA.legal_orders(start, fleet).first(3)).to eq(
      [O::Hold.new(power: :england, at: :lon),
       O::Move.new(power: :england, at: :lon, destination: L.new(province: :eng)),
       O::Move.new(power: :england, at: :lon, destination: L.new(province: :nth))]
    )
    expect(TA.legal_orders(start, TA::Unit.new(power: :france, type: :fleet, location: L.new(province: :lon)))).to eq([])
  end

  it "gives the support, coast, convoy and phase examples" do
    vie = TA::Unit.new(power: :austria, type: :army, location: L.new(province: :vie))
    expect(TA.legal_orders(start, vie).include?(O::SupportMove.new(power: :austria, at: :vie, from: :war, to: :gal))).to be(true)

    mao = TA::Unit.new(power: :france, type: :fleet, location: L.new(province: :mao))
    expect(TA.legal_orders(at_sea, mao).select { O::Move === _1 && _1.destination.province == :spa }.map { _1.destination.coast })
      .to eq(%i[nc sc])

    army = TA::Unit.new(power: :england, type: :army, location: L.new(province: :lon))
    expect(TA.legal_orders(ln, army).grep(O::MoveViaConvoy).map(&:to)).to eq([:yor])
    expect(TA.legal_orders(ln, army).any? { O::Move === _1 && _1.destination.province == :nwy }).to be(true)
    expect(TA.legal_orders(retreat, fleet)).to eq([])
  end
end

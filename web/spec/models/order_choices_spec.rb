require "rails_helper"
require_relative "../support/rules_helpers"

RSpec.describe OrderChoices do
  include RulesHelpers

  def positions
    {
      "the starting position" => RulesEngine.starting_position,
      "fleets at sea, armies on the coast, a split coast" => rules_position(units: [
        [ :france, :fleet, :mao ], [ :france, :fleet, :gol ], [ :france, :army, :gas ], [ :france, :army, :mar ], [ :england, :fleet, :eng ] ]),
      "an army with a land route and a convoy chain" => rules_position(units: [
        [ :england, :army, :lon ], [ :england, :fleet, :nth ], [ :germany, :fleet, :hel ] ]),
      "a support to move only (VIE for WAR is not adjacent)" => rules_position(units: [
        [ :austria, :army, :vie ], [ :russia, :army, :war ], [ :austria, :army, :bud ] ]),
      "a support to hold only (a fleet in ION, an army in TUN)" => rules_position(units: [ [ :italy, :fleet, :ion ], [ :italy, :army, :tun ] ])
    }
  end

  # Every save a chain of picks can reach, found by following each step's own choices.
  def saves_reachable(choices, draft = {})
    step = choices.step(draft)
    raise "no step for #{draft.inspect}" unless step

    step.choices.flat_map { |choice| choice.save ? [ choice.save ] : saves_reachable(choices, choice.draft) }
  end

  it "reaches exactly the legal orders of every unit, none missing, none extra, none twice (AC-2.10)" do
    positions.each do |name, position|
      position.units.each do |unit|
        choices = OrderChoices.new(position, unit, ordered: true)
        legal = RulesEngine.legal_orders(position, unit).map { |order| JSON.generate(order.to_h) }

        expect(saves_reachable(choices).reject(&:empty?)).to match_array(legal), "#{name}: #{unit.type} in #{unit.location.province}"
      end
    end
  end

  it "offers Hold always, a kind only when the unit has such a legal order, and No order only when ordered (AC-2.1)" do
    start = RulesEngine.starting_position
    army = start.units.find { |u| u.location.province == :lvp }
    words = ->(ordered) { OrderChoices.new(start, army, ordered: ordered).step({}).choices.map(&:words) }

    expect(words.(false)).to eq([ "Hold", "Move", "Support" ])
    expect(words.(true)).to eq([ "Hold", "Move", "Support", "No order (holds)" ])
    expect(OrderChoices.new(start, army, ordered: true).step({}).choices.last.save).to eq("")
  end

  def unit_in(position, province) = position.units.find { |u| u.location.province == province.to_sym }

  def choices_for(position, province, ordered: false) = OrderChoices.new(position, unit_in(position, province), ordered: ordered)

  def legal_hashes(position, province) = RulesEngine.legal_orders(position, unit_in(position, province)).map(&:to_h)

  let(:start) { RulesEngine.starting_position }
  let(:sea) { rules_position(units: [ [ :france, :fleet, :mao ], [ :france, :fleet, :gol ] ]) }
  let(:ln) { rules_position(units: [ [ :england, :army, :lon ], [ :england, :fleet, :nth ] ]) }

  it "lists each destination once, in the gem's order, and saves a destination that has one order (AC-2.4)" do
    step = choices_for(start, :lon).step("kind" => "move")
    expected = legal_hashes(start, :lon).select { |h| h["type"] == "move" }.map { |h| h["destination"]["province"] }.uniq

    expect(step.title).to eq("Move where?")
    expect(step.choices.map(&:province)).to eq(expected)
    expect(step.choices).to all(satisfy { |choice| choice.save && choice.draft.nil? })
  end

  it "links a split-coast destination to its coast step, which lists the coasts the gem offered (AC-2.5)" do
    spain = choices_for(sea, :mao).step("kind" => "move").choices.find { |c| c.province == "spa" }
    expect(spain.draft).to eq("kind" => "move", "to" => "spa")
    expect(spain.save).to be_nil

    coast = choices_for(sea, :mao).step(spain.draft)
    expect(coast.title).to eq("Which coast?")
    expect(coast.choices.map(&:words)).to eq([ "North coast (NC)", "South coast (SC)" ])
    expect(coast.choices.map { |c| JSON.parse(c.save)["destination"]["coast"] }).to eq(%w[nc sc])
  end

  it "notes the coast on a destination with one reachable coast, and saves from the row (spec D3)" do
    spain = choices_for(sea, :gol).step("kind" => "move").choices.find { |c| c.province == "spa" }

    expect(spain.note).to eq("south coast")
    expect(JSON.parse(spain.save)["destination"]["coast"]).to eq("sc")
    expect(spain.draft).to be_nil
  end

  it "links a destination with a plain and a convoy move to 'By land' and 'By convoy' (AC-2.6)" do
    yorkshire = choices_for(ln, :lon).step("kind" => "move").choices.find { |c| c.province == "yor" }
    expect(yorkshire.draft).to eq("kind" => "move", "to" => "yor")

    how = choices_for(ln, :lon).step(yorkshire.draft)
    expect(how.title).to eq("How does it get there?")
    expect(how.choices.map(&:words)).to eq([ "By land", "By convoy" ])
    expect(how.choices.map { |c| JSON.parse(c.save)["type"] }).to eq(%w[move move_via_convoy])
  end

  it "marks an army's convoy-only destination 'needs a convoy' and saves the plain move (AC-2.7)" do
    norway = choices_for(ln, :lon).step("kind" => "move").choices.find { |c| c.province == "nwy" }

    expect(norway.note).to eq("needs a convoy")
    expect(JSON.parse(norway.save)).to include("type" => "move", "at" => "lon")
  end

  it "lists the supported units once, then 'Hold in place' first, then each destination (AC-2.8)" do
    list = choices_for(start, :lvp).step("kind" => "support")
    edinburgh = list.choices.find { |c| c.province == "edi" }
    expect(list.choices.map(&:province)).to eq(list.choices.map(&:province).uniq)
    expect([ edinburgh.words, edinburgh.note ]).to eq([ "Fleet in", "England" ])

    how = choices_for(start, :lvp).step(edinburgh.draft)
    moves = legal_hashes(start, :lvp).select { |h| h["type"] == "support_move" && h["from"] == "edi" }.map { |h| h["to"] }
    expect(how.title).to eq("Support it how?")
    expect(how.choices.map(&:words)).to eq([ "Hold in place" ] + [ "Move to" ] * moves.size)
    expect(how.choices.drop(1).map(&:province)).to eq(moves)
  end

  it "lists the convoyable armies once, then their destinations (AC-2.9)" do
    armies = choices_for(ln, :nth).step("kind" => "convoy")
    london = armies.choices.first
    expect(armies.choices.map(&:province)).to eq([ "lon" ])
    expect([ london.words, london.note ]).to eq([ "Army in", "England" ])

    where = choices_for(ln, :nth).step(london.draft)
    expected = legal_hashes(ln, :nth).select { |h| h["type"] == "convoy" && h["from"] == "lon" }.map { |h| h["to"] }
    expect(where.title).to eq("Convoy it where?")
    expect(where.choices.map(&:province)).to eq(expected)
  end

  it "gives nil for a draft that names no legal choice: unknown kind or key, a kind with no orders, a bad target or destination, a complete draft, a non-String (AC-2.11)" do
    choices = choices_for(start, :lvp)
    [ { "kind" => "teleport" }, { "kind" => "move", "to" => "xyz" }, { "kind" => "support", "target" => "zzz" },
      { "kind" => "convoy" }, { "bad" => "1" }, { "kind" => 1 }, { "to" => "cly" }, { "kind" => "move", "to" => "cly" } ].each do |draft|
      expect(choices.step(draft)).to be_nil, draft.inspect
    end
  end

  it "gives the trail and the back draft of each step: nil for step 1, {} for a kind alone, the kind's draft for the second step (AC-2.14)" do
    choices = choices_for(start, :lvp)
    expect(choices.step({}).back).to be_nil
    expect(choices.step("kind" => "move").back).to eq({})
    expect(choices.step("kind" => "move").trail.map(&:words)).to eq([ "Move" ])
    how = choices.step("kind" => "support", "target" => "edi")
    expect(how.back).to eq("kind" => "support")
    expect(how.trail.map { |t| [ t.words, t.province ] }).to eq([ [ "Support", nil ], [ "Fleet in", "edi" ] ])
  end
end

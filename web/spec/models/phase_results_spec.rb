require "rails_helper"
require_relative "../support/results_fixtures"

# Spec 025 FR-1: what a revealed phase looks like to a reader, from the stored hash form only.
RSpec.describe PhaseResults do
  include ResultsFixtures

  let(:game) { Game.start!(power: "england").game }
  let(:hold) { ->(power, at) { { "format" => 1, "type" => "hold", "power" => power, "at" => at } } }

  it "refuses an open phase" do
    expect { PhaseResults.new(game.current_phase) }.to raise_error(ArgumentError)
  end

  it "groups by power in the gem's order, dislodged rows first, and a group holding a dislodged unit first in the reading order (D8, AC-1.5)" do
    phase = revealed_phase_with(game, dislodged: [ %w[france army par] ], outcomes: [
      [ hold.("england", "lon"), :held, true, false ], [ hold.("france", "par"), :held, true, true ], [ hold.("france", "bre"), :held, false, false ] ])
    results = PhaseResults.new(phase)

    expect(results.groups.map(&:power)).to eq(%w[england france])
    expect(results.groups.last.rows.map(&:province)).to eq(%w[par bre]) # the dislodged row first
    expect(results.reading_groups.map(&:power)).to eq(%w[france england]) # a group holding a dislodged unit first
    expect(results.banners.map { |banner| [ banner.power, banner.unit_type, banner.province ] }).to eq([ %w[france army par] ])
  end

  it "gives a void order for a unit that is not the power's own no unit, and keeps an implied hold's flag (D8, AC-1.3, AC-1.6)" do
    phase = revealed_phase_with(game, outcomes: [ [ hold.("france", "lon"), :void, true, false ], [ hold.("england", "lon"), :held, false, false ] ])
    rows = PhaseResults.new(phase).groups.flat_map(&:rows)

    expect(rows.find { |row| row.power == "france" }.unit).to be_nil
    expect(rows.find { |row| row.power == "england" }.unit.type).to eq(:fleet)
    expect(rows.find { |row| row.power == "england" }.submitted).to be(false)
  end

  it "reads only the hash form: a hash shaped as the gem's 0.2.0 to_h, and the same with every key order reversed, draw the same rows (AC-7.2)" do
    outcomes = [ { "order" => hold.("england", "lon"), "result" => "held", "submitted" => true, "dislodged" => false } ]
    after = game.current_phase.position.to_h.merge("phase" => "retreat")
    documented = { "format" => 1, "outcomes" => outcomes, "paradox" => false, "position" => after }
    reversed = lambda do |value|
      case value
      when Hash then value.to_a.reverse.to_h { |key, inner| [ key, reversed.call(inner) ] }
      when Array then value.map { |inner| reversed.call(inner) }
      else value
      end
    end
    phases = [ documented, reversed.call(documented) ].map do |hash|
      phase = Game.start!(power: "england").game.current_phase
      phase.update_columns(adjudication: RulesEngine.load_adjudication(hash), revealed_at: Time.current)
      phase.reload
    end

    expect(PhaseResults.new(phases.first).groups).to eq(PhaseResults.new(phases.last).groups)
    expect(PhaseResults.new(phases.first).groups.first.rows.map(&:province)).to eq(%w[lon])
    drawn = phases.map do |phase|
      ApplicationController.render(partial: "results/section", locals: { results: PhaseResults.new(phase), kind: :seat, game: phase.game, earlier: [], banners: false, skip: false })
    end
    expect(drawn.first).to eq(drawn.last) # both draw the same page
  end

  it "carries the stored paradox flag" do
    expect(PhaseResults.new(revealed_phase_with(game, outcomes: [], paradox: true)).paradox?).to be(true)
    expect(PhaseResults.new(revealed_phase_with(Game.start!(power: "england").game, outcomes: [])).paradox?).to be(false)
  end
end

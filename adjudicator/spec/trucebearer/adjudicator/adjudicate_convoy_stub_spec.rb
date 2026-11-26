# frozen_string_literal: true

require "trucebearer/adjudicator"
require_relative "../../support/adjudicating"

# TEMPORARY. Convoy routing arrives with #15, before 0.2.0 ships. Until then convoys never
# work (docs/specs/014-adjudicate-movement/spec.md, "Convoys in this release", AC-13.1): a
# move that goes by convoy is :no_route, and a legal Convoy order is :unmatched. This is the
# only file that pins that behavior. #15 replaces it, and the two convoy examples that are
# pending in adjudicate_examples_spec.rb.
RSpec.describe "TA.adjudicate: convoys in this release (temporary, replaced by #15)" do
  let(:england) { [u(:england, :army, "lon"), u(:england, :fleet, "nth")] }

  it "fails a move to a province an army can't reach by land, whatever fleet is at sea" do
    result = run(england, [mv(:england, :lon, "nwy")])
    expect(results(result, 1)).to eq([:no_route])
    expect(after(result)).to eq(lon: :england, nth: :england)
  end

  it "fails a move via convoy" do
    expect(results(run(england, [mvc(:england, :lon, :yor)]), 1)).to eq([:no_route])
  end

  it "fails a plain move to a neighbor when a fleet of its own power gives a matching convoy order" do
    result = run(england, [mv(:england, :lon, "yor"), cv(:england, :nth, :lon, :yor)])
    expect(results(result, 2)).to eq(%i[no_route unmatched])
  end

  it "sends that move by land when the convoy order comes from another power's fleet" do
    units = [u(:england, :army, "lon"), u(:germany, :fleet, "nth")]
    result = run(units, [mv(:england, :lon, "yor"), cv(:germany, :nth, :lon, :yor)])
    expect(results(result, 2)).to eq(%i[succeeded unmatched])
  end

  it "gives a legal convoy order :unmatched, and an illegal one :void" do
    expect(results(run(england, [cv(:england, :nth, :lon, :nwy)]), 1)).to eq([:unmatched])
    expect(results(run(england, [cv(:england, :lon, :lon, :nwy)]), 1)).to eq([:void])
  end

  it "treats a failed move like a unit that stays: it cuts nothing, and can be dislodged" do
    units = england + [u(:germany, :army, "wal"), u(:germany, :army, "yor")]
    result = run(units, [mv(:england, :lon, "nwy"), mv(:germany, :wal, "lon"), sm(:germany, :yor, :wal, :lon)])
    expect(results(result, 3)).to eq(%i[no_route succeeded given])
    expect(result.outcomes.first.dislodged).to be(true)
    expect(dislodged(result)).to eq(lon: :wal)
    expect(result.position.dislodged_units.first.by_convoy).to be(false)
  end

  it "bounces nothing: a failed move into a province gives way to another move into it" do
    units = england + [u(:russia, :army, "swe")]
    result = run(units, [mv(:england, :lon, "nwy"), mv(:russia, :swe, "nwy")])
    expect(results(result, 2)).to eq(%i[no_route succeeded])
  end

  it "holds with strength one: an unsupported attack on it bounces" do
    units = england + [u(:germany, :army, "wal")]
    result = run(units, [mv(:england, :lon, "nwy"), mv(:germany, :wal, "lon")])
    expect(results(result, 2)).to eq(%i[no_route bounced])
    expect(dislodged(result)).to eq({})
  end

  it "cuts no support even when a convoy order was given for it" do
    units = england + [u(:germany, :army, "yor"), u(:germany, :army, "wal")]
    result = run(units, [mv(:england, :lon, "yor"), cv(:england, :nth, :lon, :yor), sh(:germany, :yor, :wal)])
    expect(results(result, 3)).to eq(%i[no_route unmatched given])
  end

  it "never sets the paradox flag, and raises nothing" do
    pos = TA::Position.new(map: "classic", season: :spring, year: 1901, phase: :movement, ownership: {},
                           dislodged_units: [], standoffs: [],
                           units: [u(:england, :fleet, "lon"), u(:england, :fleet, "wal"), u(:france, :army, "bre"), u(:france, :fleet, "eng")])
    result = TA.adjudicate(pos, [mv(:england, :wal, "eng"), sm(:england, :lon, :wal, :eng), mv(:france, :bre, "lon"),
                                 cv(:france, :eng, :bre, :lon)])
    expect(result.paradox).to be(false)
    expect(result.position.phase).to eq(:retreat)
  end
end

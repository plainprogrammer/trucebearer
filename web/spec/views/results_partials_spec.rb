require "rails_helper"
require_relative "../support/results_fixtures"

# Spec 025 FR-2, D6, D8: the results partials, drawn from the one fixture builder.
RSpec.describe "results partials", type: :view do
  include ResultsFixtures

  let(:game) { Game.start!(power: "england").game }

  def order(type, power, at, **rest) = { "format" => 1, "type" => type, "power" => power, "at" => at }.merge(rest.transform_keys(&:to_s))
  def move_to(power, at, to) = order("move", power, at, destination: { "province" => to, "coast" => nil })

  def draw(phase, kind: :seat, banners: false, skip: false)
    html = render(partial: "results/section", locals: { results: PhaseResults.new(phase), kind: kind, game: game, earlier: [], banners: banners, skip: skip })
    Nokogiri::HTML5.fragment(html)
  end

  def rows_by_key(fragment) = fragment.css(".result-row").to_h { |row| [ [ row["data-power"], row["data-province"] ], row ] }

  it "draws one row of every order kind, in words with full names, and 'Order for LON' for a unit that is not the power's own or not on the board (AC-1.3)" do
    phase = revealed_phase_with(game, outcomes: [
      [ order("hold", "england", "edi"), :held, true, false ],
      [ move_to("england", "lon", "nth"), :succeeded, true, false ],
      [ order("move_via_convoy", "england", "lvp", to: "nwy"), :no_route, true, false ],
      [ order("support_move", "england", "yor", from: "lvp", to: "wal"), :unmatched, true, false ],
      [ order("convoy", "england", "nth", from: "lvp", to: "nwy"), :given, true, false ],
      [ order("support_hold", "england", "wal", target: "lvp"), :given, true, false ],
      [ move_to("france", "lon", "eng"), :void, true, false ],
      [ move_to("germany", "ruh", "bel"), :void, true, false ] ])
    rows = rows_by_key(draw(phase))

    expect(rows[%w[england edi]].text).to include("Hold")
    expect(rows[%w[england lon]].text).to include("Move to North Sea (NTH)")
    expect(rows[%w[england lvp]].text).to include("Move to Norway (NWY)").and include("by convoy")
    expect(rows[%w[england yor]].text).to include("Support Liverpool (LVP) to Wales (WAL)")
    expect(rows[%w[england nth]].text).to include("Convoy Liverpool (LVP) to Norway (NWY)")
    expect(rows[%w[england wal]].text).to include("Support hold in Liverpool (LVP)")
    expect(rows[%w[france lon]].text).to include("Order for London (LON)") # London holds England's fleet, not France's
    expect(rows[%w[germany ruh]].text).to include("Order for Ruhr (RUH)") # no unit stands there: a plain move never meets a missing unit type
    expect(rows[%w[france lon]].at_css(".unit-icon")).to be_nil
    expect(rows[%w[england lon]].at_css(".unit-icon")).to be_present
  end

  it "tags each symbol and the dislodged flag, row by row (AC-1.4)" do
    phase = revealed_phase_with(game, dislodged: [ %w[england fleet lon], %w[england fleet edi], %w[england army lvp] ], outcomes: [
      [ order("convoy", "england", "lon", from: "lvp", to: "nwy"), :disrupted, true, true ],
      [ order("hold", "england", "edi"), :held, true, true ],
      [ move_to("england", "lvp", "yor"), :bounced, true, true ],
      [ move_to("france", "par", "bur"), :succeeded, true, false ],
      [ order("support_move", "france", "bre", from: "par", to: "bur"), :cut, true, false ],
      [ order("support_hold", "france", "mar", target: "par"), :given, true, false ],
      [ order("convoy", "germany", "kie", from: "ber", to: "swe"), :unmatched, true, false ],
      [ order("move_via_convoy", "germany", "ber", to: "swe"), :no_route, true, false ],
      [ order("hold", "austria", "vie"), :void, true, false ] ])
    tags = rows_by_key(draw(phase)).transform_values { |row| row.css(".outcome-tag").map(&:text) }

    expect(tags[%w[england lon]]).to eq([ "Dislodged", "Convoy disrupted" ])
    expect(tags[%w[england edi]]).to eq([ "Dislodged" ]) # its Held tag is dropped beside Dislodged
    expect(tags[%w[england lvp]]).to eq([ "Dislodged", "Bounced" ])
    expect(tags[%w[france par]]).to eq([ "Succeeded" ])
    expect(tags[%w[france bre]]).to eq([ "Support cut" ])
    expect(tags[%w[france mar]]).to eq([ "Given" ])
    expect(tags[%w[germany kie]]).to eq([ "Not used" ])
    expect(tags[%w[germany ber]]).to eq([ "No route" ])
    expect(tags[%w[austria vie]]).to eq([ "Not a legal order" ])
  end

  it "notes an implied hold's cause, and drops 'so it held' when it was dislodged; a void order and its implied hold are two rows (AC-1.6)" do
    phase = revealed_phase_with(game, dislodged: [ %w[england fleet lon] ], outcomes: [
      [ move_to("england", "edi", "wal"), :void, true, false ],
      [ order("hold", "england", "edi"), :held, false, false ], [ order("hold", "england", "lon"), :held, false, true ] ]) # implied holds, by province
    fragment = draw(phase)
    notes = fragment.css(".result-row").filter_map { |row| [ row["data-province"], row.at_css(".result-row__note")&.text ] if row.at_css(".result-row__note") }.to_h

    expect(notes).to eq("lon" => "No valid order", "edi" => "No valid order, so it held")
    expect(fragment.css(".result-row[data-province=edi]").map { |row| row.css(".outcome-tag").map(&:text) }).to eq([ [ "Not a legal order" ], [ "Held" ] ])
  end

  it "shows the paradox banner only when the stored result says so, and the practice note only while the stand-in is in use (AC-7.1, AC-7.4)" do
    clean = revealed_phase_with(game, outcomes: [])
    expect(draw(clean).css("[data-paradox]")).to be_empty
    expect(draw(clean).at_css(".practice-note")).to be_present
    allow(RulesEngine).to receive(:stand_in?).and_return(false)
    expect(draw(clean).at_css(".practice-note")).to be_nil

    odd = revealed_phase_with(Game.start!(power: "england").game, outcomes: [], paradox: true)
    expect(draw(odd).css("[data-paradox].banner--warning").size).to eq(1)
  end

  it "has one banner for each dislodged unit, equal to the Dislodged tags, and none when banners is false (AC-2.2, AC-2.6)" do
    phase = revealed_phase_with(game, dislodged: [ %w[england fleet lon] ], outcomes: [ [ order("hold", "england", "lon"), :held, true, true ] ])

    expect(draw(phase, kind: :host, banners: true).css("[data-dislodged]").size).to eq(draw(phase, kind: :host).css(".outcome-tag--dislodged").size)
    expect(draw(phase, kind: :host, banners: true).at_css("[data-dislodged]").text).to eq("Warning: England's fleet in LON was dislodged. Settle it by hand.")
    expect(draw(phase, kind: :host, banners: false).css("[data-dislodged]")).to be_empty
  end

  it "uses the reading variant for the host and puts groups with a dislodged unit first (AC-2.1, AC-2.2)" do
    phase = revealed_phase_with(game, dislodged: [ %w[france army par] ], outcomes: [
      [ order("hold", "england", "lon"), :held, true, false ], [ order("hold", "france", "par"), :held, true, true ] ])
    host = draw(phase, kind: :host, banners: true)
    seat = draw(phase, kind: :seat)

    expect(host.css(".result-group").map { |group| group["data-power"] }).to eq(%w[france england])
    expect(host.css(".result-group--reading").size).to eq(2)
    expect(seat.css(".result-group").map { |group| group["data-power"] }).to eq(%w[england france])
    expect(seat.css(".result-group--reading")).to be_empty
  end

  it "heads the section with the phase title and offers a skip link only when asked (AC-1.9)" do
    phase = revealed_phase_with(game, outcomes: [])

    expect(draw(phase, skip: true).at_css("h2").text).to eq("Results: Spring 1901 · Movement")
    expect(draw(phase, skip: true).at_css("a[href='#enter-orders']").text).to eq("Skip to orders")
    expect(draw(phase).at_css("a[href='#enter-orders']")).to be_nil
  end
end

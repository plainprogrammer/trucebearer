require "rails_helper"
require_relative "../support/rules_helpers"

# Spec 024 Story 3: a broadcast carries the seven submitted states and nothing else, whatever the orders are.
RSpec.describe "The status payload" do
  include RulesHelpers

  before { @game_ids = [] }

  def hold(province) = json_of(rules_order(:hold, :england, province.to_sym))

  # Drives the same five flips in a game whatever the orders are, and returns the decoded payloads of its stream.
  def run_flips(england_first:, england_edit:, france_orders:)
    game = Game.start!(power: "england").game
    @game_ids << game.public_id
    england = game.seats.find_by(power: "england")
    france = game.take_seat!("france").first
    phase = game.current_phase
    england.save_orders!(phase, england_first) unless england_first.empty?
    england.save_orders!(phase, {}, submit: true)                   # flip 1
    england.save_orders!(phase, england_edit)                       # flip 2: an edit clears the submission
    england.save_orders!(phase, {}, submit: true)                   # flip 3
    france.save_orders!(phase, france_orders, submit: true)         # flip 4
    england.save_orders!(phase, england_edit, submit: true)         # no flip: nothing changes, still submitted
    game.reissue_seat!(england)                                     # flip 5
    ActionCable.server.pubsub.broadcasts("seat_status:#{game.public_id}").map { |raw| JSON.parse(raw) }
  end

  let(:quiet) { run_flips(england_first: {}, england_edit: { "lon" => hold("lon") }, france_orders: {}) }
  let(:busy) do
    run_flips(england_first: { "edi" => hold("edi"), "lvp" => hold("lvp"), "lon" => hold("lon") },
              england_edit: { "lon" => json_of(move(:england, :lon, :nth)), "edi" => "", "lvp" => "" },
              france_orders: { "par" => json_of(move(:france, :par, :bur)) })
  end

  it "has the same payloads, in the same count and order, whatever the orders are (AC-3.2)" do
    expect(quiet.size).to eq(5)
    expect(busy).to eq(quiet)
  end

  it "matches an exact allowlist of elements, attributes and text (AC-3.1)" do
    (quiet + busy).each do |payload|
      streams = Nokogiri::HTML5.fragment(payload).css("turbo-stream")
      expect(streams.size).to eq(1)
      expect(streams.first.attributes.transform_values(&:value)).to eq("action" => "update", "method" => "morph", "target" => "seat-status")

      template = streams.first.at_css("template")
      rows = template.css("li")
      expect(rows.map { |row| row["data-power"] }).to eq(%w[austria england france germany italy russia turkey])
      rows.each do |row|
        expect(row.attributes.keys).to match_array(%w[class data-power])
        expect(row["class"]).to eq("seat-status__row")
        badge, state = row.element_children
        expect(row.element_children.size).to eq(2)
        expect([ badge.name, badge["class"], badge.attributes.keys ]).to eq([ "span", "power-badge power-badge--#{row['data-power']}", [ "class" ] ])
        expect(badge.text).to eq(row["data-power"].capitalize)
        expect([ state.name, state["class"], state.attributes.keys ]).to eq([ "span", "seat-status__state", [ "class" ] ])
        expect([ "Submitted", "Not submitted" ]).to include(state.text)
      end
      expect(template.css("*").map(&:name).uniq).to match_array(%w[li span])
    end
  end

  it "has no province, order word, count, phase title or game id in its text, and no digit anywhere (AC-3.4)" do
    named = %w[lon nth edi lvp par bur eng yor] # every province the orders above name, by abbreviation
    provinces = named + named.map { |id| RulesEngine.province_name(id) }
    words = [ "Move", "Hold", "Support", "Convoy", "by convoy", "ordered", "units", "Spring", "Fall", "Movement" ]

    (quiet + busy).each do |payload|
      @game_ids.each { |id| expect(payload).not_to include(id) } # an all-letter public id has no digit to give it away
      text = Nokogiri::HTML5.fragment(payload).at_css("template").text.gsub(/\s+/, " ")
      (provinces + words).each { |word| expect(text).not_to match(/\b#{Regexp.escape(word)}\b/i), word }
      expect(payload).not_to match(/\d/)
    end
  end

  it "control: the checks do catch a leak, so they are not vacuous" do
    leaky = quiet.first.sub("Not submitted", "Not submitted, 3 ordered")
    template = Nokogiri::HTML5.fragment(leaky).at_css("template")

    expect(template.text).to match(/\bordered\b/)
    expect(leaky).to match(/\d/)
    expect([ "Submitted", "Not submitted" ]).not_to include(template.css("li").first.element_children.last.text)
  end
end

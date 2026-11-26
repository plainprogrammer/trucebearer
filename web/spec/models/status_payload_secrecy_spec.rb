require "rails_helper"
require_relative "../support/rules_helpers"

# Spec 024 Story 3: a broadcast carries the seven submitted states and nothing else, whatever the orders are. Since 1.3.0 (D10,
# AC-9.3) the same proof covers what SeatStatusChannel transmits to a subscriber as it arrives, after each step.
RSpec.describe "The status payload", type: :channel do
  include RulesHelpers

  tests SeatStatusChannel

  before do
    @game_ids = []
    stub_connection
  end

  def hold(province) = json_of(rules_order(:hold, :england, province.to_sym))

  # Subscribes the way a woken phone does, and returns the one message it was sent.
  def catch_up(game)
    before = transmissions.size
    subscribe(signed_stream_name: Turbo::StreamsChannel.signed_stream_name([ :seat_status, game.public_id ]))
    expect(subscription).to be_confirmed
    expect(transmissions.size).to eq(before + 1) # one subscribe, one message
    transmissions.last.to_str.tap { unsubscribe }
  end

  # Drives the same five flips in a game whatever the orders are, and returns the decoded payloads of its stream (broadcasts) and,
  # after each of the six steps, what a subscriber is sent (catch_ups, each with the latest broadcast at that moment). The
  # step marked "no flip" changes England's orders while it stays submitted, in the second game, and changes nothing in the first.
  def run_flips(england_first:, england_edit:, england_resubmit:, france_orders:)
    game = Game.start!(power: "england").game
    @game_ids << game.public_id
    england = game.seats.find_by(power: "england")
    france = game.take_seat!("france").first
    phase = game.current_phase
    stream = "seat_status:#{game.public_id}"
    broadcasts = -> { ActionCable.server.pubsub.broadcasts(stream).map { |raw| JSON.parse(raw) } }
    catch_ups = []
    caught = -> { catch_ups << [ catch_up(game), broadcasts.call.last ] }
    england.save_orders!(phase, england_first) unless england_first.empty?
    england.save_orders!(phase, {}, submit: true)                    # flip 1
    caught.call
    england.save_orders!(phase, england_edit)                        # flip 2: an edit clears the submission
    caught.call
    england.save_orders!(phase, {}, submit: true)                    # flip 3
    caught.call
    france.save_orders!(phase, france_orders, submit: true)          # flip 4
    caught.call
    england.save_orders!(phase, england_resubmit, submit: true)      # no flip: still submitted, orders changed or not
    caught.call
    game.reissue_seat!(england)                                      # flip 5
    caught.call
    { broadcasts: broadcasts.call, catch_ups: catch_ups }
  end

  let(:quiet_run) do
    run_flips(england_first: {}, england_edit: { "lon" => hold("lon") }, england_resubmit: { "lon" => hold("lon") }, france_orders: {})
  end
  let(:busy_run) do
    run_flips(england_first: { "edi" => hold("edi"), "lvp" => hold("lvp"), "lon" => hold("lon") },
              england_edit: { "lon" => json_of(move(:england, :lon, :nth)), "edi" => "", "lvp" => "" },
              england_resubmit: { "lon" => json_of(move(:england, :lon, :eng)), "edi" => hold("edi") },
              france_orders: { "par" => json_of(move(:france, :par, :bur)) })
  end

  let(:quiet) { quiet_run[:broadcasts] }
  let(:busy) { busy_run[:broadcasts] }
  let(:catch_ups) { (quiet_run[:catch_ups] + busy_run[:catch_ups]).map(&:first) }

  def power_ids = %w[austria england france germany italy russia turkey]

  # Everything wrong with a payload against the exact allowlist of AC-3.1; empty means it conforms. Whitespace between
  # elements is allowed, and nothing else that is not an element.
  def violations(payload)
    found = []
    doc = Nokogiri::HTML5.fragment(payload)
    streams = doc.element_children
    found << "not exactly one element at the top" unless streams.size == 1 && streams.first.name == "turbo-stream"
    return found unless found.empty?

    stream = streams.first
    found << "turbo-stream attributes" unless stream.attributes.transform_values(&:value) == { "action" => "update", "method" => "morph", "target" => "seat-status" }
    found << "turbo-stream children" unless stream.element_children.map(&:name) == [ "template" ]
    found << "text beside the template" unless stream.children.all? { |node| node.element? || node.text.strip.empty? }
    template = stream.at_css("template")
    return found << "no template" unless template

    found << "template attributes" unless template.attributes.empty?
    found << "text outside the rows" unless template.children.all? { |node| node.element? || node.text.strip.empty? }
    rows = template.element_children
    found << "rows are not seven li in power order" unless rows.map(&:name) == [ "li" ] * 7 && rows.map { |row| row["data-power"] } == power_ids
    rows.each do |row|
      found << "row attributes" unless row.attributes.keys.sort == %w[class data-power] && row["class"] == "seat-status__row"
      found << "text directly in a row" unless row.children.all? { |node| node.element? || node.text.strip.empty? }
      badge, state = row.element_children
      found << "row children" unless row.element_children.size == 2
      next unless badge && state

      found << "badge" unless badge.name == "span" && badge["class"] == "power-badge power-badge--#{row['data-power']}" &&
                              badge.attributes.keys == [ "class" ] && badge.text == row["data-power"].capitalize && badge.element_children.empty?
      found << "state" unless state.name == "span" && state["class"] == "seat-status__state" && state.attributes.keys == [ "class" ] &&
                              [ "Submitted", "Not submitted" ].include?(state.text) && state.element_children.empty?
    end
    found
  end

  it "has the same payloads, in the same count and order, whatever the orders are (AC-3.2)" do
    expect(quiet.size).to eq(5)
    expect(busy).to eq(quiet)
  end

  it "matches an exact allowlist of elements, attributes and text (AC-3.1)" do
    (quiet + busy + catch_ups).each { |payload| expect(violations(payload)).to be_empty }
  end

  it "sends a subscriber, byte for byte, the latest broadcast for the same state, and the same in both games (AC-9.3)" do
    expect(quiet_run[:catch_ups].size).to eq(6)
    (quiet_run[:catch_ups] + busy_run[:catch_ups]).each { |sent, latest| expect(sent).to eq(latest) }
    expect(busy_run[:catch_ups].map(&:first)).to eq(quiet_run[:catch_ups].map(&:first))
  end

  it "broadcasts nothing when a subscriber arrives (AC-9.3)" do
    game = Game.start!(power: "england").game
    stream = "seat_status:#{game.public_id}"
    expect(ActionCable.server).not_to receive(:broadcast)

    expect { catch_up(game) }.not_to(change { ActionCable.server.pubsub.broadcasts(stream).size })
  end

  it "has no province, order word, count, phase title or game id in its text, and no digit anywhere (AC-3.4)" do
    named = %w[lon nth eng edi lvp par bur yor] # every province the orders above name, by abbreviation
    provinces = named + named.map { |id| RulesEngine.province_name(id) }
    words = [ "Move", "Hold", "Support", "Convoy", "by convoy", "ordered", "units", "Spring", "Fall", "Movement" ]

    (quiet + busy + catch_ups).each do |payload|
      @game_ids.each { |id| expect(payload).not_to include(id) } # an all-letter public id has no digit to give it away
      text = Nokogiri::HTML5.fragment(payload).at_css("template").text.gsub(/\s+/, " ")
      (provinces + words).each { |word| expect(text).not_to match(/\b#{Regexp.escape(word)}\b/i), word }
      expect(payload).not_to match(/\d/)
    end
  end

  it "control: the allowlist catches each kind of leak, so it is not vacuous" do
    good = quiet.first
    leaks = {
      "an order word beside a state" => good.sub("Not submitted", "Not submitted, 3 ordered"),
      "a word between the spans" => good.sub("</span> <span class=\"seat-status__state\">", "</span> Holds <span class=\"seat-status__state\">"),
      "an extra attribute" => good.sub('<li class="seat-status__row"', '<li data-orders="3" class="seat-status__row"'),
      "a different state word" => good.sub("Not submitted", "Moved"),
      "a different method" => good.sub("morph", "replace"),
      "text in the template" => good.sub("<template>", "<template>Hold ")
    }

    expect(violations(good)).to be_empty
    leaks.each do |name, payload|
      expect(payload).not_to eq(good), "#{name}: the substitution changed nothing"
      expect(violations(payload)).not_to be_empty, name
    end
  end
end

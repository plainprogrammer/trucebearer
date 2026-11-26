# Plan 024: Show live submission status

**Spec:** `web/docs/specs/024-live-status/spec.md` v1.0.1 (Approved at Gate A; 1.0.1 allows a space between a row's elements)
**Issue:** #24 · **Branch:** `web/24-live-status` · **Plan version:** 1.1.0 (after the Opus review: see the changelog at the end)

## Goal

Show a `.seat-status` list (seven rows, each a power badge and "Submitted" or "Not submitted") on the seat page and on the host's controls, and keep it live on every open page through Turbo Streams over Solid Cable, as the spec says. Broadcasts are a snapshot of the seven states on a dedicated stream, sent only when the submitted set flips, and are proved state-only by tests. All work is under `web/`. Each phase is test first (RSpec), ends with the whole suite green, and is one commit. Commit messages are plain imperative sentences ending with the `Co-Authored-By:` line. No migration, no new gem, no new JavaScript, no new HTTP route.

**The first test.** Before Phase 1 the brief's model spec is written and run once to see it fail. It lives in the scratchpad (outside `spec/`) until Phase 3 copies it in and makes it pass, so every commit is green and the first test is still the first one written:

```ruby
# spec spec/models/seat_status_broadcast_spec.rb (first version)
require "rails_helper"

RSpec.describe "Seat status broadcast" do
  let(:game) { Game.start!(power: "england").game }
  let(:seat) { game.seats.find_by(power: "england") }
  let(:phase) { game.current_phase }
  let(:stream) { "seat_status:#{game.public_id}" }

  # What Action Cable's test adapter kept for a stream, JSON-decoded (it stores the string JSON-encoded).
  def payloads = ActionCable.server.pubsub.broadcasts(stream).map { |raw| JSON.parse(raw) }

  it "sends one broadcast to the game's status stream when England submits, and England's row says Submitted" do
    seat.save_orders!(phase, {}, submit: true)

    expect(payloads.size).to eq(1)
    row = Nokogiri::HTML5.fragment(payloads.first).at_css("[data-power='england']")
    expect(row[:class]).to include("seat-status__row")
    expect(row.at_css(".seat-status__state").text).to eq("Submitted")
  end
end
```

Run once against today's code: it fails (`payloads.size` is 0). Note for the run: parsing `<template>` content with Nokogiri's HTML5 parser must find the rows as children of the template; if it does not, the spec reads `Nokogiri::HTML5.fragment(payload).at_css("template").children`.

## Decisions the plan adds (each traceable to the spec)

- **Names.** `Phase::Status` and `Phase#seat_statuses` (FR-1); partial `shared/_seat_status` (the seven rows); `SeatStatusHelper#seat_status(statuses, id:)` (the `ul` live region); partial `phases/_status` (heading, list, stream source and the cache-control meta, so each page changes by one line and #26's edits to the same views do not collide); `Game#broadcast_seat_status` (FR-2); `CableOrigins` in `lib/cable_origins.rb` (D5).
- **`Seat#clear_orders!` returns a boolean** (a submission was removed), which `Game#reissue_seat!` uses (D3). Its other behaviour is unchanged.
- **Where the calls go** (D3): `Seat#save_orders!` (after its `Phase.transaction`, when the submitted state differs from the one read inside the lock), `Game#reissue_seat!` (after its transaction, when a submission was removed), `Phase#reveal!` (after its transaction, when the status is `:revealed`).
- **`phases/_status` locals:** `game:`, `phase:`, `level:` (2 on the seat page, 3 in the host section). It calls `content_for :head` for the `turbo-cache-control: no-cache` meta, always. The host page's existing conditional meta line (only while the one-time host link shows) is deleted, because the partial now covers it; the page still sets `no_store` as before.
- **CSS.** `.seat-status` shares `.list`'s two rules by selector grouping (`.list, .seat-status` and `.list > li + li, .seat-status > li + li`), so the element does not carry the `list` class and the specs that count `.host-section ul.list > li` stay at seven. `.seat-status__row` is a flex row like `.list__row` without the control behaviour.
- **Stylesheet budget:** before this feature `components.css` is 14,855 bytes and the total 26,565 of 32,768; `styleguide.css` 3,716 of 6,144. Phase 2 and Phase 9 record the sizes after.

## Gates checked

- **Simplicity:** one model method pair, one broadcast method, one helper, two partials, one small module, no channel, controller or JavaScript.
- **Anti-abstraction:** no service object, no `after_commit` callback layer; three explicit calls to one method.
- **Integration-first:** the first test goes through the real writer and the real adapter; the system spec (Phase 10) goes through two real browsers.

## Phase 1: `Phase#seat_statuses`

**Implements:** FR-1 (data). **Files:** change `app/models/phase.rb`, `spec/models/phase_spec.rb`.

Test first:

```ruby
# spec/models/phase_spec.rb (added)
describe "#seat_statuses" do
  let(:game) { Game.start!(power: "england").game }
  let(:phase) { game.current_phase }

  it "gives seven statuses in the gem's power order, none submitted at the start" do
    statuses = phase.seat_statuses

    expect(statuses.map(&:power)).to eq(RulesEngine.powers.map { |power| power.id.to_s })
    expect(statuses.size).to eq(7)
    expect(statuses.map(&:submitted)).to all(be(false))
  end

  it "marks a seat that has submitted, and a power nobody holds is not submitted" do
    england = game.seats.find_by(power: "england")
    Submission.create!(phase: phase, seat: england)

    by_power = phase.seat_statuses.to_h { |status| [ status.power, status.submitted ] }
    expect(by_power["england"]).to be(true)
    expect(by_power.except("england").values).to all(be(false))
  end

  it "reads only submissions and seats, never an order" do
    expect(Phase.instance_method(:seat_statuses).source_location).not_to be_nil
    expect(File.read(Rails.root.join("app/models/phase.rb"))[/def seat_statuses.*?\n  end\n/m]).not_to match(/saved_orders?|SavedOrder|orders_for/i)
  end
end
```

Then:

```ruby
# app/models/phase.rb (after Pending)
Status = Data.define(:power, :submitted) # one power's row in the status list (spec 024 FR-1)

# The seven powers in the gem's order, each with whether its seat has submitted. It reads seats and submissions only
# (spec 024 D2): the one input of the status partial, and so of every message the status stream carries.
def seat_statuses
  seats = game.seats.index_by(&:power)
  done = submissions.pluck(:seat_id).to_set
  RulesEngine.powers.map do |power|
    seat = seats[power.id.to_s]
    Status.new(power: power.id.to_s, submitted: !seat.nil? && done.include?(seat.id))
  end
end
```

Check: `bundle exec rspec spec/models` and the whole suite green. One commit: "Add the seven seat statuses of a phase".

## Phase 2: The partial, the helper and the CSS

**Implements:** FR-1 (markup, style), D6. **Files:** create `app/views/shared/_seat_status.html.erb`, `app/helpers/seat_status_helper.rb`, `spec/helpers/seat_status_helper_spec.rb`; change `app/assets/stylesheets/components.css`.

Test first:

```ruby
# spec/helpers/seat_status_helper_spec.rb
require "rails_helper"

RSpec.describe SeatStatusHelper, type: :helper do
  let(:statuses) do
    RulesEngine.powers.map { |power| Phase::Status.new(power: power.id.to_s, submitted: power.id.to_s == "england") }
  end

  def page(html) = Nokogiri::HTML5.fragment(html)

  it "writes a persistent polite live list with seven rows in power order" do
    list = page(helper.seat_status(statuses)).at_css("ul")

    expect(list[:id]).to eq("seat-status")
    expect(list[:class]).to eq("seat-status")
    expect(list["aria-live"]).to eq("polite")
    expect(list["role"]).to be_nil
    expect(list.css("> li").map { |row| row["data-power"] }).to eq(statuses.map(&:power))
  end

  it "gives each row the power's badge and its state in words" do
    rows = page(helper.seat_status(statuses)).css("li.seat-status__row")
    england = rows.find { |row| row["data-power"] == "england" }
    france = rows.find { |row| row["data-power"] == "france" }

    expect(england.at_css(".power-badge--england").text).to eq("England")
    expect(england.at_css(".seat-status__state").text).to eq("Submitted")
    expect(france.at_css(".seat-status__state").text).to eq("Not submitted")
    expect(rows.map { |row| row.element_children.size }.uniq).to eq([ 2 ])
  end

  it "takes the id from the caller, so a page can show several lists" do
    expect(page(helper.seat_status(statuses, id: "sample-2")).at_css("ul")[:id]).to eq("sample-2")
  end

  it "renders the same rows as the partial a broadcast uses" do
    inner = page(helper.seat_status(statuses)).at_css("ul").inner_html
    partial = ApplicationController.render(partial: "shared/seat_status", locals: { statuses: statuses })
    expect(inner.gsub(/\s+/, " ").strip).to eq(partial.gsub(/\s+/, " ").strip)
  end
end
```

Then:

```erb
<%# The seven rows of the status list (spec 024 D6). Used inside the live list by seat_status, and alone as the body of a
    stream message, so the page and the message cannot differ. locals: statuses (seven Phase::Status) %>
<% statuses.each do |status| -%>
  <li class="seat-status__row" data-power="<%= status.power %>"><%= power_badge(status.power) %> <span class="seat-status__state"><%= status.submitted ? "Submitted" : "Not submitted" %></span></li>
<% end -%>
```

```ruby
# app/helpers/seat_status_helper.rb
# The status list: a persistent polite live region around the rows. A stream message morphs the inside of this element, so the
# element itself is never replaced and only a row whose text changed is announced (spec 024 D6).
module SeatStatusHelper
  def seat_status(statuses, id: "seat-status")
    tag.ul(render("shared/seat_status", statuses: statuses), id: id, class: "seat-status", aria: { live: "polite" })
  end
end
```

```css
/* components.css: change the two list rules to name .seat-status as well, then add */
  /* ---- Seat status: <ul class="seat-status"> of <li class="seat-status__row"> (spec 024) ---- */
  .seat-status__row {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: var(--space-3);
    padding: var(--space-2) var(--space-4);
    background: var(--color-surface);
  }

  .seat-status__state {
    font-weight: var(--weight-strong);
  }
```

The existing `stylesheet_rules_spec` (no raw colours, no `!important`, only tokens) decides if a value is wrong. Measure `wc -c app/assets/stylesheets/*.css` after and note the sizes in the commit message body. Check: the helper spec, the stylesheet specs, the whole suite. One commit: "Add the seat status list, its partial and its styles".

## Phase 3: The broadcast on a save (the first test)

**Implements:** FR-2, D1, D2, D3 (save), D7, AC-2.3, AC-2.6, AC-3.3, AC-5.4. **Files:** change `app/models/game.rb`, `app/models/seat.rb`; create `spec/models/seat_status_broadcast_spec.rb` (the first test above, then more).

The first test is copied into `spec/models/` and run: it still fails. Add these to the same file (written before the code):

```ruby
  def phase_orders = { "lon" => JSON.generate({ "format" => 1, "type" => "hold", "power" => "england", "at" => "lon" }) }

  it "sends nothing for a save that does not submit, or for a first save of orders" do
    seat.save_orders!(phase, phase_orders)
    expect(payloads).to be_empty
  end

  it "sends one broadcast when a submitted seat changes an order, and England's row then says Not submitted (AC-2.3)" do
    seat.save_orders!(phase, {}, submit: true)
    seat.save_orders!(phase, phase_orders)

    expect(payloads.size).to eq(2)
    row = Nokogiri::HTML5.fragment(payloads.last).at_css("[data-power='england']")
    expect(row.at_css(".seat-status__state").text).to eq("Not submitted")
  end

  it "sends nothing when an edit and a re-submit end where they began (D3)" do
    seat.save_orders!(phase, {}, submit: true)
    seat.save_orders!(phase, phase_orders, submit: true)
    expect(payloads.size).to eq(1)
  end

  it "sends nothing when the save is refused, stale or on a revealed phase (AC-2.6)" do
    expect { seat.save_orders!(phase, { "par" => "{}" }, submit: true) }.to raise_error(Seat::Refusal)
    stale = Seat.find(seat.id) # a second copy of the seat, loaded before the host reissues it
    game.reissue_seat!(seat) # a seat that had not submitted: no message, and the copy's digest is now stale
    expect { stale.save_orders!(phase, {}, submit: true) }.to raise_error(Seat::Stale)
    expect(payloads).to be_empty

    revealed = game.current_phase
    revealed.reveal!
    ActionCable.server.pubsub.clear_messages(stream) # the reveal's own message is not under test here
    expect { game.seats.find_by(power: "england").save_orders!(revealed, {}, submit: true) }.to raise_error(Phase::Revealed)
    expect(payloads).to be_empty
  end

  it "keeps the save, and its answer, when the cable call raises, and logs only the exception's class (D7, AC-5.4)" do
    allow(Turbo::StreamsChannel).to receive(:broadcast_update_to).and_raise(IOError, "secret detail")
    allow(Rails.logger).to receive(:warn)

    expect(seat.save_orders!(phase, {}, submit: true)).to eq(Seat::Saved.new(changed: false, submitted: true))
    expect(seat.submitted?(phase)).to be(true)
    expect(Rails.logger).to have_received(:warn).with("seat status broadcast failed: IOError")
  end

  it "does not hide a template that raises (D7)" do
    allow(ApplicationController).to receive(:render).and_raise(RuntimeError, "boom")
    expect { seat.save_orders!(phase, {}, submit: true) }.to raise_error(RuntimeError, "boom")
  end
```

Then:

```ruby
# app/models/game.rb
# Tells every open seat page and host page which seats have submitted. One snapshot of the seven states, rendered from
# Phase#seat_statuses and nothing else, on a stream of its own that only the seat and host pages subscribe to (spec 024
# D1, D2, D4). It is the only place the app talks to the cable; spec/models/status_broadcast_scan_spec.rb enforces that. The
# render is outside the rescue so a broken template raises everywhere; the cable call is inside it so a stored save is
# never answered with an error (D7).
def broadcast_seat_status
  html = ApplicationController.render(partial: "shared/seat_status", locals: { statuses: current_phase.seat_statuses })
  begin
    Turbo::StreamsChannel.broadcast_update_to(:seat_status, public_id, target: "seat-status", content: html,
                                              attributes: { method: :morph })
  rescue StandardError => error
    Rails.logger.warn("seat status broadcast failed: #{error.class}")
  end
end
```

```ruby
# app/models/seat.rb: save_orders! becomes
def save_orders!(phase, entries, submit: false)
  before = nil
  saved = Phase.transaction do
    phase.lock!
    raise Phase::Revealed unless phase.open?
    raise Stale unless Seat.exists?(id: id, token_digest: token_digest)

    before = submitted?(phase) # inside the lock, before any change (spec 024 D3)
    # ... the body is unchanged down to the Saved line
    Saved.new(changed: changed, submitted: submitted?(phase))
  end
  phase.game.broadcast_seat_status if saved.submitted != before # only a flip of the submitted state is news
  saved
end
```

(Only the lines marked are new; the rest of the method stays exactly as it is, including the refusal order of spec 022 FR-2.) Check: the new spec, `spec/models/seat_orders_spec.rb`, the saved-orders boundary and write scans, the whole suite. One commit: "Broadcast the seat status when a save flips submitted".

## Phase 4: The broadcast on a reissue and a reveal

**Implements:** D3 (reissue, reveal), AC-2.4, AC-2.5. **Files:** change `app/models/seat.rb`, `app/models/game.rb`, `app/models/phase.rb`; add to `spec/models/seat_status_broadcast_spec.rb`.

Test first:

```ruby
  it "sends one broadcast when the host reissues a submitted seat (AC-2.4), and none for a seat that had not submitted" do
    seat.save_orders!(phase, {}, submit: true)
    game.reissue_seat!(seat)
    expect(payloads.size).to eq(2)
    row = Nokogiri::HTML5.fragment(payloads.last).at_css("[data-power='england']")
    expect(row.at_css(".seat-status__state").text).to eq("Not submitted")

    france = game.take_seat!("france").first
    game.reissue_seat!(france)
    expect(payloads.size).to eq(2)
  end

  it "sends one broadcast at a reveal, all seven Not submitted, and none for a reveal that finds the phase done (AC-2.5)" do
    seat.save_orders!(phase, {}, submit: true)
    expect(phase.reveal!.status).to eq(:revealed)

    expect(payloads.size).to eq(2)
    states = Nokogiri::HTML5.fragment(payloads.last).css(".seat-status__state").map(&:text)
    expect(states).to eq([ "Not submitted" ] * 7)
    expect(Phase.find(phase.id).reveal!.status).to eq(:already)
    expect(payloads.size).to eq(2)
  end
```

Then:

```ruby
# app/models/seat.rb: clear_orders! reports whether a submission was removed
def clear_orders!(phase)
  orders = saved_orders.where(phase_id: phase.id).destroy_all
  withdrawn = submissions.where(phase_id: phase.id).destroy_all
  raise Phase::Revealed unless (orders + withdrawn).all?(&:destroyed?) # a guard refused: the phase was revealed under us

  withdrawn.any?
end
```

```ruby
# app/models/game.rb: reissue_seat!
def reissue_seat!(seat)
  token = Token.generate
  withdrew = transaction do
    phase = phases.lock.find_by!(revealed_at: nil)
    seat.update!(token_digest: Token.digest(token))
    seat.clear_orders!(phase)
  end
  broadcast_seat_status if withdrew
  token
end
```

```ruby
# app/models/phase.rb: reveal! (after `reload`'s transaction, before the return)
reload
game.broadcast_seat_status if status == :revealed
Reveal.new(status: status)
```

Check: the reissue and reveal specs (`reissue_clears_orders_spec`, `phase_reveal_spec`, `phase_concurrency_spec`) unchanged and green, then the whole suite. One commit: "Broadcast the seat status on a reissue and a reveal".

## Phase 5: The scan, and the secrecy proof of the payload

**Implements:** AC-2.7, AC-3.1, AC-3.2, AC-3.3, AC-3.4, AC-3.7. **Files:** create `spec/models/status_broadcast_scan_spec.rb`, `spec/models/status_payload_secrecy_spec.rb`.

Test first (these pass at once, since Phases 3 and 4 made the code; each is also shown to fail against a deliberately wrong input in the examples marked "control"):

```ruby
# spec/models/status_broadcast_scan_spec.rb
require "rails_helper"

# Spec 024 AC-2.7: who writes submissions, who calls the broadcast, and who may name the cable.
RSpec.describe "Who writes and broadcasts the status" do
  files = Dir.glob(Rails.root.join("{app,lib}/**/*")).select { |f| File.file?(f) && !f.match?(/\.(png|svg|woff2?|ico)\z/) }
  text = ->(path) { File.binread(path).force_encoding("UTF-8").scrub }
  rel = ->(path) { path.delete_prefix("#{Rails.root}/") }
  named = ->(pattern) { files.select { |f| text.call(f).match?(pattern) }.map(&rel) }

  it "writes submissions only in Seat" do
    writes = /Submission\.(?:create|new|delete|destroy)|\bsubmissions\.(?:create|find_or_create_by|build|destroy|delete)|submissions\.where\([^)]*\)\.(?:destroy_all|delete_all)/
    expect(named.call(writes)).to eq([ "app/models/seat.rb" ])
  end

  it "calls broadcast_seat_status only from Game, Seat#save_orders! and Phase#reveal!" do
    expect(named.call(/broadcast_seat_status/)).to match_array(%w[app/models/game.rb app/models/seat.rb app/models/phase.rb])
    expect(text.call(File.join(Rails.root, "app/models/seat.rb"))[/def save_orders!.*?\n  end\n/m]).to include("broadcast_seat_status")
    expect(text.call(File.join(Rails.root, "app/models/phase.rb"))[/def reveal!.*?\n  end\n/m]).to include("broadcast_seat_status")
  end

  it "names the cable and any other broadcast only inside Game#broadcast_seat_status" do
    # Code only: full-line comments are not scanned, so a sentence may use the plain word.
    code = ->(path) { text.call(path).lines.reject { |line| line.strip.start_with?("#") }.join.gsub(/<%#.*?%>/m, "") }
    cable = /Turbo::StreamsChannel|ActionCable|\.broadcasts?\b|\bbroadcast_(?!seat_status\b)\w+/
    naming = files.select { |f| code.call(f).match?(cable) }.map(&rel)
    expect(naming).to eq([ "app/models/game.rb" ])
    outside = code.call(File.join(Rails.root, "app/models/game.rb")).sub(/def broadcast_seat_status.*?\n  end\n/m, "")
    expect(outside).not_to match(cable)
  end

  it "mentions submissions elsewhere only as the associations (AC-2.7a)" do
    mentions = files.flat_map { |f| text.call(f).lines.grep(/\bsubmissions\b/).map { |line| [ rel.call(f), line.strip ] } }
    other = mentions.reject { |path, line| path == "app/models/seat.rb" || line.match?(/has_many :submissions, dependent: :destroy/) }
    expect(other.map(&:first).uniq - [ "app/models/phase.rb" ]).to be_empty # Phase#seat_statuses and #pending read them
    expect(other.select { |path, _| path == "app/models/phase.rb" }.map(&:last).grep(/\.(?:create|destroy|delete)/)).to be_empty
  end

  it "keeps the status code away from saved orders (AC-3.7)" do
    code = [ File.read(Rails.root.join("app/views/shared/_seat_status.html.erb")), File.read(Rails.root.join("app/helpers/seat_status_helper.rb")),
             File.read(Rails.root.join("app/models/game.rb"))[/def broadcast_seat_status.*?\n  end\n/m],
             File.read(Rails.root.join("app/models/phase.rb"))[/def seat_statuses.*?\n  end\n/m] ].join
    expect(code).not_to match(/SavedOrder|saved_orders?|orders_for/)
  end
end
```

```ruby
# spec/models/status_payload_secrecy_spec.rb
require "rails_helper"
require_relative "../support/rules_helpers"

# Spec 024 Story 3: a broadcast carries the seven submitted states and nothing else.
RSpec.describe "The status payload" do
  include RulesHelpers

  # Drives the same flips in a game whatever the orders are; returns the decoded payloads of its stream.
  def run_flips(england_first:, england_edit:, france_orders:)
    game = Game.start!(power: "england").game
    @game_ids << game.public_id
    england = game.seats.find_by(power: "england")
    france = game.take_seat!("france").first
    phase = game.current_phase
    england.save_orders!(phase, england_first) unless england_first.empty?
    england.save_orders!(phase, {}, submit: true)                    # flip 1
    england.save_orders!(phase, england_edit)                        # flip 2: an edit clears the submission
    england.save_orders!(phase, {}, submit: true)                    # flip 3
    france.save_orders!(phase, france_orders, submit: true)          # flip 4
    england.save_orders!(phase, england_edit, submit: true)          # no flip: no change, still submitted
    game.reissue_seat!(england)                                      # flip 5
    ActionCable.server.pubsub.broadcasts("seat_status:#{game.public_id}").map { |raw| JSON.parse(raw) }
  end

  def hold(province) = json_of(rules_order(:hold, :england, province.to_sym))

  before { @game_ids = [] }

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
      doc = Nokogiri::HTML5.fragment(payload)
      streams = doc.css("turbo-stream")
      expect(streams.size).to eq(1)
      expect(streams.first.attributes.transform_values(&:value)).to eq("action" => "update", "method" => "morph", "target" => "seat-status")
      template = streams.first.at_css("template")
      rows = template.css("li")
      expect(rows.map { |row| row["data-power"] }).to eq(%w[austria england france germany italy russia turkey])
      rows.each do |row|
        expect(row.attributes.keys).to match_array(%w[class data-power])
        expect(row["class"]).to eq("seat-status__row")
        badge, state = row.element_children
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
    expect(Nokogiri::HTML5.fragment(leaky).at_css("template").text).to match(/\bordered\b/)
    expect(leaky).to match(/\d/)
    expect(Nokogiri::HTML5.fragment(leaky).at_css("template").css("li").first.element_children.last.text).not_to be_in([ "Submitted", "Not submitted" ])
  end
end
```

The orders are built with the helpers of `spec/support/rules_helpers.rb` (`rules_order`, `move`, `json_of`); the plan adds no method to `RulesEngine`. Check: both specs pass; the control example passes; the saved-orders boundary scan unchanged and green; the whole suite. One commit: "Prove the status payload carries no order and scan who broadcasts".

## Phase 6: The pages, the stream element and the classification

**Implements:** FR-3, FR-5, FR-6, D8, D9, AC-1.1, AC-1.2, AC-2.1, AC-4.1, AC-4.2, AC-4.5, AC-4.6, AC-5.1, AC-5.2 (meta), AC-5.3, AC-3.5, AC-8.3 (the rewrites). **Files:** create `app/views/phases/_status.html.erb`; change `app/views/games/show.html.erb`, `app/views/hosts/show.html.erb`, `spec/support/secrecy_routes.rb`, `spec/requests/order_secrecy_spec.rb`, `spec/requests/phase_pages_spec.rb`, `spec/requests/player_spec.rb`, `spec/requests/host_spec.rb` (if a count needs it); create `spec/requests/seat_status_pages_spec.rb`.

Test first:

```ruby
# spec/requests/seat_status_pages_spec.rb
require "rails_helper"
require_relative "../support/rules_helpers"

RSpec.describe "The status list on the pages", type: :request do
  around { |example| with_passphrase { example.run } }

  let!(:created) { create_game(power: "germany") }
  let(:game) { created.game }
  let(:id) { game.public_id }
  let!(:england) { game.take_seat!("england") }
  let(:phase) { game.current_phase }

  def page_of(session, path)
    session.get path
    Nokogiri::HTML5(session.response.body)
  end

  def state_of(page, power) = page.at_css("#seat-status [data-power='#{power}'] .seat-status__state").text

  it "shows the seven rows on the seat page under an h2 and on the host page above the Reveal button under an h3 (AC-1.1, AC-2.1)" do
    seat_page = page_of(created.session, "/games/#{id}")
    expect(seat_page.css("#seat-status > li").size).to eq(7)
    expect(seat_page.css("h2").map(&:text)).to include("Who has submitted")
    expect(seat_page.css("#seat-status > li").map { |row| row["data-power"] }).to eq(%w[austria england france germany italy russia turkey])
    expect(seat_page.text).not_to match(/^\s*Submitted\s*$|^\s*Not submitted\s*$/) # the old single line is gone

    host_page = page_of(created.session, "/games/#{id}/host")
    section = host_page.at_css(".host-section")
    expect(section.css("h3").map(&:text)).to include("Who has submitted")
    expect(section.css("#seat-status > li").size).to eq(7)
    heading = section.css("h3").find { |node| node.text == "Who has submitted" }
    reveal = section.css("a.button").find { |link| link.text == "Reveal orders" }
    expect(heading <=> reveal).to eq(-1) # document order: the heading, and the list after it, come before the button
    expect(section.at_css("#seat-status") <=> reveal).to eq(-1)
    expect(host_page.css("ul.list > li").size).to be >= 7
    expect(section.css("ul.list > li").size).to eq(7) # the seats list; the status list does not carry .list
  end

  it "is correct on a plain page load, with no live connection (AC-1.2, AC-5.1)" do
    england.first.save_orders!(phase, {}, submit: true)
    [ "/games/#{id}", "/games/#{id}/host" ].each do |path|
      page = page_of(created.session, path)
      expect(state_of(page, "england")).to eq("Submitted")
      expect(state_of(page, "france")).to eq("Not submitted")
    end
  end

  it "is the same element on both pages, and its inside is what a broadcast sends (AC-5.3)" do
    england.first.save_orders!(phase, {}, submit: true)
    seat_list = page_of(created.session, "/games/#{id}").at_css("#seat-status").to_html
    host_list = page_of(created.session, "/games/#{id}/host").at_css("#seat-status").to_html
    expect(seat_list).to eq(host_list)
    game.broadcast_seat_status
    payload = JSON.parse(ActionCable.server.pubsub.broadcasts("seat_status:#{id}").last)
    template = Nokogiri::HTML5.fragment(payload).at_css("template").inner_html
    expect(template.gsub(/\s+/, " ").strip).to eq(Nokogiri::HTML5.fragment(seat_list).at_css("ul").inner_html.gsub(/\s+/, " ").strip)
  end

  it "has one stream source whose signed name verifies to this game's status stream, and never another game's (AC-4.1)" do
    other = create_game(power: "france")
    names = [ "/games/#{id}", "/games/#{id}/host" ].map do |path|
      sources = page_of(created.session, path).css("turbo-cable-stream-source")
      expect(sources.size).to eq(1)
      Turbo.signed_stream_verifier.verified(sources.first["signed-stream-name"])
    end
    expect(names).to eq([ "seat_status:#{id}" ] * 2)
    other_name = page_of(other.session, "/games/#{other.game.public_id}").at_css("turbo-cable-stream-source")["signed-stream-name"]
    expect(Turbo.signed_stream_verifier.verified(other_name)).to eq("seat_status:#{other.game.public_id}")
  end

  it "gives no stream element to a stranger, a junk cookie, another game's cookie or a seat cookie on the host page (AC-4.2)" do
    [ "", "/host" ].each do |suffix|
      stranger_responses(created, suffix: suffix).each_value do |(existing, _missing)|
        expect(existing[1]).not_to include("turbo-cable-stream-source")
        expect(existing[1]).not_to include("signed-stream-name")
      end
    end
  end

  it "does not let Turbo keep a snapshot of either page (D9, AC-5.2)" do
    [ "/games/#{id}", "/games/#{id}/host" ].each do |path|
      metas = page_of(created.session, path).css("meta[name='turbo-cache-control']")
      expect(metas.map { |meta| meta["content"] }).to eq([ "no-cache" ])
    end
  end
end
```

(`stranger_responses` is the helper of `spec/support/game_flow.rb`; it returns `{ condition => [[status, body, headers, cookies] of the existing game, the same of a missing game] }`, so `existing[1]` is the body. It is called here with `suffix: ""` for the seat page and again with `suffix: "/host"` for the host page.)

Then:

```erb
<%# phases/_status: the heading, the live status list, the stream source and the cache rule (spec 024 FR-3, D9). One line
    in each page. locals: game, phase, level (2 on the seat page, 3 in the host section) %>
<% content_for :head, tag.meta(name: "turbo-cache-control", content: "no-cache") %>
<%= turbo_stream_from :seat_status, game.public_id %>
<%= content_tag "h#{level}", "Who has submitted" %>
<%= seat_status(phase.seat_statuses) %>
```

```erb
<%# app/views/games/show.html.erb: delete the line  <p><%= @seat.submitted?(@phase) ? "Submitted" : "Not submitted" %></p>
    and, after the "Keep this page..." paragraph and before the host section (so the count and the "Enter orders" link
    stay together above it), add %>
  <%= render "phases/status", game: @game, phase: @phase, level: 2 %>
```

```erb
<%# app/views/hosts/show.html.erb: delete line 2 (the conditional meta) and, in the host section above "Reveal orders", add %>
    <%= render "phases/status", game: @game, phase: @phase, level: 3 %>
```

The classification in `spec/support/secrecy_routes.rb`:

```ruby
# in APP, after the reveal rows
"MOUNT /cable" => { shows: :none, why: "state-only stream (spec 024): the signed name is only in pages behind a seat or the host cookie" }
# the seat page and host page `why` texts become
"the seat's own state and count, never an order; the status list of the seven powers (spec 024)"
"phase header, history, dislodged units, the status list of the seven powers (spec 024)"
# FRAMEWORK: delete the line  [ /\AMOUNT \/cable\z/, "no channel exists yet; ..." ]
```

The secrecy spec's "would fail for a route nobody classified" example already asserts `MOUNT /cable` is classified; it now passes through `APP`. The submitted-versus-not sweep example is rewritten:

```ruby
    it "answers the same whether England has submitted or not, except the host's list of who has not and England's own row (AC-7.2, AC-4.1, spec 024 AC-3.5)" do
      set_orders(:all)
      unsubmitted = snapshot
      set_orders(:all, submit: true)
      submitted = snapshot

      confirm = "GET /games/:public_id/host/phases/:number/reveal"
      hosts = [ "the host, with a seat of its own", "the host, with no seat" ]
      lists = [ "GET /games/:public_id", "GET /games/:public_id/host" ]
      # The four viewer and page pairs that get a status list. The others get the stranger page and stay in the strict comparison.
      listed = [ [ "another seat", lists[0] ], [ hosts[0], lists[0] ], [ hosts[0], lists[1] ], [ hosts[1], lists[1] ] ]
      expect(differences(unsubmitted, submitted, except: hosts.map { |host| [ host, confirm ] } + listed)).to be_empty

      # Where a list shows, the page differs inside #seat-status and nowhere else, and only in England's row.
      listed.each do |viewer, key|
        before, after = unsubmitted[viewer][key][1], submitted[viewer][key][1]
        outside = ->(body) { Nokogiri::HTML5(body).tap { |doc| doc.at_css("#seat-status").remove }.to_html }
        expect(outside.call(after)).to eq(outside.call(before)), "#{viewer} on #{key}"
        rows = ->(body) { Nokogiri::HTML5(body).css("#seat-status li").to_h { |row| [ row["data-power"], row.text.squish ] } }
        changed = rows.call(after).reject { |power, text| rows.call(before)[power] == text }.keys
        expect(changed).to eq([ "england" ]), "#{viewer} on #{key}"
      end
      hosts.each do |host|
        expect(unsubmitted[host][confirm][1]).to include("England")
        expect(submitted[host][confirm][1]).not_to include("England")
      end
    end
```

The sweep's first example (orders change, submitted state the same) is untouched: it now also compares the seat and host pages with their status lists, which must be identical. A new example in the same file (AC-4.5) scans every body of the snapshot for `signed-stream-name`:

```ruby
    it "puts the signed stream name only on the pages of the viewers who may see the status (spec 024 AC-4.5)" do
      set_orders(:none)
      carrying = snapshot.flat_map do |viewer, routes|
        routes.select { |_key, (_status, body)| body.include?("signed-stream-name") }.keys.map { |key| [ viewer, key ] }
      end
      expect(carrying).to match_array([
        [ "another seat", "GET /games/:public_id" ],
        [ "the host, with a seat of its own", "GET /games/:public_id" ],
        [ "the host, with a seat of its own", "GET /games/:public_id/host" ],
        [ "the host, with no seat", "GET /games/:public_id/host" ]
      ])
    end
```

and a route-table example (AC-4.6): `SecrecyRoutes::APP["MOUNT /cable"][:shows]` is `:none` and no `FRAMEWORK` pattern matches `"MOUNT /cable"` (`SecrecyRoutes::FRAMEWORK.none? { |pattern, _| "MOUNT /cable".match?(pattern) }`). Existing specs that assert the old page are rewritten in this phase: `phase_pages_spec.rb:20` reads England's row ("Not submitted") instead of the page text; `:23` and `player_spec.rb:24` ("does not name France") now assert that the seat page shows no *order* and no other power's *orders link or count* (the seven badges are expected); the `phase_pages_spec.rb` example at lines 41 to 46 asserts England's row says "Submitted" and France's "Not submitted" instead of the page lacking the words. Check: `bundle exec rspec spec/requests` and the whole suite. One commit: "Show the status list on the seat page and the host's controls".

## Phase 7: Who may subscribe

**Implements:** D4, AC-4.3, AC-4.4. **Files:** create `spec/channels/seat_status_subscription_spec.rb`.

Test first (no production code changes; the channel is Turbo's):

```ruby
require "rails_helper"

RSpec.describe Turbo::StreamsChannel, type: :channel do
  let(:game) { Game.start!(power: "england").game }
  let(:other) { Game.start!(power: "france").game }

  def signed(*streamables) = Turbo::StreamsChannel.signed_stream_name(streamables)

  before { stub_connection }

  it "confirms a subscription with the game's signed status name and streams from the status stream (AC-4.3)" do
    subscribe(signed_stream_name: signed(:seat_status, game.public_id))
    expect(subscription).to be_confirmed
    expect(subscription).to have_stream_from("seat_status:#{game.public_id}")
  end

  it "rejects an unsigned name, a name signed with another key, and no name (AC-4.3)" do
    subscribe(signed_stream_name: "seat_status:#{game.public_id}")
    expect(subscription).to be_rejected
    subscribe(signed_stream_name: ActiveSupport::MessageVerifier.new("another key", serializer: JSON).generate("seat_status:#{game.public_id}"))
    expect(subscription).to be_rejected
    subscribe
    expect(subscription).to be_rejected
  end

  it "hears nothing of another game's status, or of a broadcast to the game itself (AC-4.4)" do
    subscribe(signed_stream_name: signed(:seat_status, game.public_id))
    other.broadcast_seat_status
    Turbo::StreamsChannel.broadcast_update_to(game, target: "x", content: "y")

    expect(ActionCable.server.pubsub.broadcasts("seat_status:#{game.public_id}")).to be_empty
    expect(subscription.streams).to eq([ "seat_status:#{game.public_id}" ])
  end
end
```

The last example calls `Turbo::StreamsChannel` from a spec, which the scan of Phase 5 does not cover (it scans `app/` and `lib/`). `signed_stream_name` as a class method is used as Turbo's own helper does; if the signature differs the spec uses `Turbo::StreamsChannel.signed_stream_name(streamables)` exactly as `turbo_stream_from` does (checked in `bundle show turbo-rails`, `app/helpers/turbo/streams_helper.rb`). Check: the channel spec and the whole suite. One commit: "Test who may subscribe to the status stream".

## Phase 8: The allowed origins

**Implements:** D5, FR-4, AC-7.1, AC-7.2, AC-7.3. **Files:** create `lib/cable_origins.rb`, `spec/lib/cable_origins_spec.rb`, `spec/config/cable_origins_config_spec.rb`; change `config/environments/production.rb`, `config/deploy.yml`, `README.md`.

Test first:

```ruby
# spec/lib/cable_origins_spec.rb
require "rails_helper"

RSpec.describe CableOrigins do
  it "gives no origins for nothing, a blank or only separators" do
    expect([ nil, "", "  ", " ,, " ].map { |value| CableOrigins.parse(value) }).to all(eq([]))
  end

  it "reads origins separated by commas or spaces, dropping a trailing slash and repeats" do
    expect(CableOrigins.parse("https://a.example")).to eq([ "https://a.example" ])
    expect(CableOrigins.parse("https://a.example/, https://b.example")).to eq([ "https://a.example", "https://b.example" ])
    expect(CableOrigins.parse("https://a.example https://a.example")).to eq([ "https://a.example" ])
  end

  it "names the variable that production.rb reads" do
    expect(CableOrigins::ENV_NAME).to eq("TRUCEBEARER_CABLE_ORIGINS")
  end
end
```

```ruby
# spec/config/cable_origins_config_spec.rb
require "rails_helper"

# Spec 024 D5: what the setting does to Action Cable's own origin check, and where it is documented.
RSpec.describe "The Action Cable origins" do
  def allowed?(list, origin:, host: "play.example.org")
    config = ActionCable::Server::Configuration.new # a fresh one, so the suite's own server config is not changed
    config.allowed_request_origins = list
    config.logger = Rails.logger
    server = ActionCable::Server::Base.new(config: config)
    env = Rack::MockRequest.env_for("https://#{host}/cable", "HTTP_ORIGIN" => origin, "HTTP_HOST" => host, "HTTPS" => "on")
    ActionCable::Connection::Base.new(server, env).send(:allow_request_origin?)
  end

  [ nil, "", "https://a.example", "https://a.example/, https://b.example", " ,, " ].each do |setting|
    list = CableOrigins.parse(setting)

    it "always lets the app's own origin in, with #{setting.inspect}" do
      expect(allowed?(list, origin: "https://play.example.org")).to be(true)
    end

    it "refuses an unlisted foreign origin, with #{setting.inspect}" do
      expect(allowed?(list, origin: "https://evil.example")).to be(false)
    end

    it "lets every listed origin in, with #{setting.inspect}" do
      list.each { |origin| expect(allowed?(list, origin: origin)).to be(true) }
    end
  end

  it "reads the setting in production.rb from the one variable, with one live line" do
    live = File.readlines(Rails.root.join("config/environments/production.rb")).reject { |line| line.strip.start_with?("#") }.join
    expect(live).to match(/^\s*config\.action_cable\.allowed_request_origins = CableOrigins\.parse\(ENV\["TRUCEBEARER_CABLE_ORIGINS"\]\)\s*$/)
    expect(live).to match(%r{^\s*require_relative "\.\./\.\./lib/cable_origins"\s*$})
  end

  it "never turns the forgery protection off, in any environment file" do
    files = Dir.glob(Rails.root.join("config/{environments,initializers}/*.rb"))
    live = files.flat_map { |f| File.readlines(f).reject { |line| line.strip.start_with?("#") } }.join
    expect(live).not_to match(/disable_request_forgery_protection\s*=\s*true/)
  end

  it "lists the variable under env.clear in deploy.yml and explains it, with the unset case, in the README (AC-7.3)" do
    deploy = YAML.load_file(Rails.root.join("config/deploy.yml"))
    expect(deploy.dig("env", "clear")).to include("TRUCEBEARER_CABLE_ORIGINS" => "https://app.example.com")
    readme = File.read(Rails.root.join("README.md"))
    section = readme[/^## Live updates.*?(?=^## |\z)/m]
    expect(section).not_to be_nil
    expect(section).to include("TRUCEBEARER_CABLE_ORIGINS")
    expect(section).to match(/unset/i)
    expect(section).to match(/Request origin not allowed/)
  end
end
```

Then:

```ruby
# lib/cable_origins.rb  (no dependency: production.rb requires it before the autoloader exists)
# The origins, besides its own address, that may open the live-update socket (spec 024 D5). Read from one variable.
module CableOrigins
  ENV_NAME = "TRUCEBEARER_CABLE_ORIGINS".freeze

  # "https://a.example/, https://b.example" -> ["https://a.example", "https://b.example"]. Blank entries and repeats are dropped.
  def self.parse(value)
    value.to_s.split(/[\s,]+/).map { |origin| origin.chomp("/") }.reject(&:empty?).uniq
  end
end
```

```ruby
# config/environments/production.rb, first line of code, above Rails.application.configure
require_relative "../../lib/cable_origins"
```

```ruby
# config/environments/production.rb, inside the configure block, after assume_ssl
# Origins besides the app's own that may open the live-update socket. Unset keeps Rails' default: only the app's own
# address (spec 024 D5, README "Live updates").
config.action_cable.allowed_request_origins = CableOrigins.parse(ENV["TRUCEBEARER_CABLE_ORIGINS"])
``` `config/deploy.yml`, under `env.clear`:

```yaml
    # Origins besides the app's own that may open the live-update socket, separated by commas or spaces.
    # Unset: only the address the app is served at; live updates stop working behind a proxy that changes the Host header.
    TRUCEBEARER_CABLE_ORIGINS: https://app.example.com
```

README, after the passphrase paragraph, a `## Live updates` section (the spec reads that heading): what the status list is; that it uses Action Cable over Solid Cable (stored for a day, state-only); the variable with an example; and what happens when unset (same address only, https because the app assumes SSL, refused sockets logged as "Request origin not allowed", pages correct on every load, only live updates missing). Check: the three specs; `RAILS_ENV=production SECRET_KEY_BASE_DUMMY=1 bin/rails runner 'p Rails.configuration.action_cable.allowed_request_origins'` printing `["https://app.example.com"]` with that variable and `[]` with it unset (a one-off manual check, written into the commit message, not a spec: booting production needs four databases); the whole suite. One commit: "Read the allowed Action Cable origins from TRUCEBEARER_CABLE_ORIGINS".

## Phase 9: The style guide and the design system

**Implements:** AC-8.1, FR-6 budget. **Files:** change `app/views/styleguide/show.html.erb`, `spec/requests/styleguide_spec.rb`, `spec/docs/design_system_spec.rb`, `docs/design-system.md`, `app/assets/stylesheets/styleguide.css` (only if a sample needs it).

Test first:

```ruby
# spec/requests/styleguide_spec.rb: add "seat-status" to the components list; and
it "shows the seat status with all submitted, none submitted and a mix, each list with an id of its own (spec 024 AC-8.1)" do
  get "/styleguide"
  section = Nokogiri::HTML5(response.body).at_css("[data-component='seat-status']")
  lists = section.css("ul.seat-status")
  expect(lists.size).to eq(3)
  expect(lists.map { |list| list[:id] }.uniq.size).to eq(3)
  states = lists.map { |list| list.css(".seat-status__state").map(&:text).uniq.sort }
  expect(states).to contain_exactly([ "Submitted" ], [ "Not submitted" ], [ "Not submitted", "Submitted" ])
end
```


```ruby
# spec/docs/design_system_spec.rb
it "lists the seat status of Issue 24 as built, with its class, helper and partial (spec 024 AC-8.1)" do
  # `doc` is the file's own local, read at the top of the describe block
  line = doc.lines.find { |l| l.include?("`.seat-status`") && l.include?("#24") && l.match?(/built/i) }
  expect(line).not_to be_nil
  expect(line).to include("seat_status").and include("shared/_seat_status")
end
```

Then: a `data-component="seat-status"` section in the style guide, in the same shape as the neighbouring ones, with a short sentence and three `seat_status(statuses, id: "sg-seat-status-all")`, `-none` and `-mix` lists built from `RulesEngine.powers` and `Phase::Status.new` (a made-up mix: England and France submitted). The design-system row becomes:

`| Seat status | `.seat-status` (helper `seat_status`, partial `shared/_seat_status`, section partial `phases/_status`) | #24 (built) | Seven rows: badge plus "Submitted" or "Not submitted"; a polite live list that a broadcast morphs, so only a changed row is announced; the same list on the seat page and next to the host's reveal button |`

Record `wc -c app/assets/stylesheets/*.css` and confirm the caps (32,768 total, 6,144 for `styleguide.css`) hold, in the commit message. Check: the style guide specs, `design_system_spec`, the layout system spec for the style guide (`spec/system/styleguide_layout_spec.rb`), the whole suite. One commit: "Add the seat status to the style guide and design system".

## Phase 10: Two phones at 360 pixels

**Implements:** Story 6, AC-1.3, AC-2.2, AC-2.3 (live), AC-5.2 (Back), AC-6.1, AC-6.2. **Files:** create `spec/system/live_status_spec.rb`; screenshots in `docs/specs/024-live-status/screens/`.

Test first:

```ruby
require "rails_helper"

# Spec 024 Story 6: two real browsers at 360 pixels. The test cable adapter delivers in this process, so no extra setup.
RSpec.describe "Live submission status", type: :system do
  def screenshot(name)
    dir = ENV["SCREENSHOTS"]
    page.save_screenshot(File.join(dir, "#{name}.png")) if dir
  end

  def state_of(power) = find("#seat-status [data-power='#{power}'] .seat-status__state").text

  def measure(label)
    widths = evaluate_script("({ scroll: document.documentElement.scrollWidth, client: document.documentElement.clientWidth })")
    expect(widths["scroll"]).to be <= widths["client"], "#{label} scrolls sideways at 360"
    small = evaluate_script(<<~JS)
      Array.from(document.querySelectorAll(":is(main, .app-actions) :is(a:not(p a), button, input:not([type=hidden]))")).filter((el) => {
        const r = el.getBoundingClientRect(); return r.width < 43.5 || r.height < 43.5;
      }).map((el) => el.className || el.tagName)
    JS
    expect(small).to be_empty, "#{label}: controls under 44 by 44: #{small.join(', ')}"
  end

  let(:started) { Game.start!(power: "germany") }
  let(:game) { started.game }
  let!(:england) { game.take_seat!("england") }

  it "shows the host England's submit and England's change of mind without a reload (AC-6.1)" do
    with_viewport(360) do
      visit "/games/#{game.public_id}/host-link?token=#{started.host_token}"
      expect(page).to have_css("h1", text: "Your game")
      expect(page).to have_css("turbo-cable-stream-source[connected]") # subscribed: Turbo sets this once the socket confirms
      expect(state_of("england")).to eq("Not submitted")
      measure("the host page"); screenshot("01-host-before")

      Capybara.using_session(:england) do
        with_viewport(360) do
          visit "/games/#{game.public_id}/seat-link?token=#{england.last}"
          visit "/games/#{game.public_id}/phases/1/orders"
          click_on "Submit orders"
          expect(page).to have_css(".banner--info", text: "Submitted.")
        end
      end

      expect(page).to have_css("#seat-status [data-power='england'] .seat-status__state", text: "Submitted", wait: 5)
      expect(state_of("germany")).to eq("Not submitted")
      measure("the host page, England submitted"); screenshot("02-host-england-submitted")

      Capybara.using_session(:england) do
        with_viewport(360) do
          click_on "Fleet in London" # a unit row on the order screen
          click_on "Hold"
          expect(page).to have_css("h1", text: "Your orders")
        end
      end
      expect(page).to have_css("#seat-status [data-power='england'] .seat-status__state", text: "Not submitted", wait: 5)
    end
  end

  it "shows a seat page the same change, and Back shows the current state, not a snapshot (AC-2.2, AC-5.2)" do
    france = game.take_seat!("france")
    with_viewport(360) do
      visit "/games/#{game.public_id}/seat-link?token=#{france.last}"
      expect(page).to have_css("turbo-cable-stream-source[connected]")
      expect(state_of("england")).to eq("Not submitted")
      measure("the seat page"); screenshot("03-seat-page")
      click_on "Enter orders"
      expect(page).to have_css("h1", text: "Your orders")

      Capybara.using_session(:england) do
        with_viewport(360) do
          visit "/games/#{game.public_id}/seat-link?token=#{england.last}"
          visit "/games/#{game.public_id}/phases/1/orders"
          click_on "Submit orders"
          expect(page).to have_css(".banner--info", text: "Submitted.")
        end
      end

      page.go_back
      expect(page).to have_css("#seat-status [data-power='england'] .seat-status__state", text: "Submitted", wait: 5)
      screenshot("04-seat-page-after-back")
    end
  end
end
```

If the "Fleet in London" tap needs the exact label the order screen uses, the spec reads it from the page the way `order_pickers_spec` does. Check: the system spec passes locally with Chrome, and with `SCREENSHOTS=docs/specs/024-live-status/screens` it writes the four 360-pixel screenshots (a copy is checked into the spec folder as spec 023 did); without the variable it writes nothing (AC-6.2). One commit: "Walk the live status between two phones at 360 pixels".

## Phase 11: Spec 022's amendment and the close

**Implements:** AC-8.2, AC-8.3. **Files:** change `docs/specs/022-phase-lifecycle/spec.md`; create `spec/docs/spec_amendments_spec.rb`.

Test first: a docs example in `spec/docs/spec_amendments_spec.rb` (new, small; the citation of #105 is already in the spec and needs no test of its own):

```ruby
require "rails_helper"

RSpec.describe "Spec amendments" do
  it "records spec 024's changes to spec 022 in a 1.4.0 changelog row (spec 024 AC-8.2)" do
    spec = File.read(Rails.root.join("docs/specs/022-phase-lifecycle/spec.md"))
    expect(spec).to include("**Version:** 1.4.0")
    row = spec.lines.find { |line| line.start_with?("| 1.4.0 |") }
    expect(row).to include("AC-1.5").and include("AC-7.5").and include("AC-7.2").and include("/cable").and include("spec 024")
  end
end
```

Then the 1.4.0 changelog row on spec 022, in the style of its 1.3.0 row: AC-1.5 and the FR-9 table rows for the seat page and the host page are read as "the seat page shows the seven powers and their submitted state, and the seat's own count and orders link"; AC-7.5 is read as "the host can read, before the reveal, which powers have submitted (the same set as the names of those that have not)"; AC-7.2's sanctioned difference is extended as spec 024 AC-3.5 says; the route table classifies `/cable`; every other criterion holds unchanged. Then the full proof, from `web/`:

- `bundle exec rspec` (system specs included) passes;
- `bin/brakeman` and `bin/rubocop` are clean;
- `git diff --name-only main...HEAD` lists only paths under `web/`;
- `wc -c app/assets/stylesheets/*.css` within the caps.

One commit: "Amend spec 022 for the live status".

## Done-when map

| Issue item | Where it is proved |
|---|---|
| Status updates on every phone through Turbo Streams over Solid Cable | Phases 3 to 4 (broadcasts), 6 (stream element), 7 (subscription), 10 (two browsers) |
| The host's controls show the same status next to the reveal button | Phase 6 (`seat_status_pages_spec`), Phase 10 |
| A seat returning to "not submitted" updates everyone | Phase 3 (model), Phase 10 (live) |
| `.seat-status` in `/styleguide` | Phase 9 |

## Spec coverage

| Requirement | Phase |
|---|---|
| FR-1 status list (data, markup, style) | 1, 2 |
| FR-2 the broadcast | 3, 4, 5 |
| FR-3 subscribing | 6, 7 |
| FR-4 origins | 8 |
| FR-5 page-load correctness | 6 |
| FR-6 classification, scans | 5, 6 |
| AC-1.x host | 6, 10 |
| AC-2.x players and flips | 3, 4, 6, 10 |
| AC-3.x payload secrecy | 5, 6 (3.5); 3.6 is the README of 8 |
| AC-4.x subscribers | 6, 7 |
| AC-5.x without a connection | 3 (5.4), 6 |
| AC-6.x phones | 10 |
| AC-7.x origins | 8 |
| AC-8.x design system, amendments | 6, 9, 11 |

## Risks

- **Nokogiri and `<template>`:** if the HTML5 parser does not expose a template's children as expected, the specs read `template.children` or parse the template's inner HTML again. Settled by running the first test.
- **Morph in a real browser:** the system spec is the proof that the bundled Turbo morphs the list in place; if it does not, the fallback is `update` without `method: :morph`, which changes the allowlist of AC-3.1 and needs a spec amendment before use.
- **The test adapter in system specs:** it extends the async adapter, so a second browser session receives broadcasts in the same process. If it does not, the system spec fails in Phase 10 and the plan stops there to ask.
- **`Game#broadcast_seat_status` in a request inside the test transaction:** the call runs after the (savepoint) transaction in the same thread and the shared test connection, so the render sees the new rows.

## Version 1.2.0 addendum: catch up as a phone resubscribes (Issue #105)

Phases 12 to 18 are added for spec version 1.2.0. Phases 1 to 11 stand. Test first in every phase; one commit per phase; every phase leaves the whole suite green (the scan spec and the amendment spec move with the code they police, not after it).

**Goal.** A subscriber is sent the current state as it subscribes or resubscribes: `SeatStatusChannel` the seven rows, `ResultsChannel` a refresh when the phase its page was drawn for has since been revealed. No JavaScript, gem, route or migration. Anything new that sends is covered by the same allowlist and byte-equality proof, and the scan lists it as the only other sender.

**Gates (checked).** Simplicity: two channel classes (one per stream; a new `app/channels/` directory, no `ApplicationCable` needed, Action Cable falls back to its base connection) and four `Game` methods, nothing else new. Anti-abstraction: the channels subclass Turbo's channel and call `Game`; no shared base class (the two name patterns differ). Integration-first: Phase 12 starts with the channel spec the maintainer named.

**Names used throughout (defined once, here).**

```ruby
# app/models/game.rb
PUBLIC_ID_PATTERN = /[A-Za-z0-9]{12}/        # what Game.start! generates with SecureRandom.alphanumeric(12), which stays as it is
def seat_status_message   ... end            # String: the one <turbo-stream action=update method=morph> message
def results_refresh_message ... end          # String: <turbo-stream action="refresh"></turbo-stream>
def broadcast_seat_status ... end            # unchanged contract; now sends seat_status_message
def broadcast_results_refresh ... end        # unchanged contract; now sends results_refresh_message
```
All four are written as block `def ... end` (the scan cuts method bodies with `/def X.*?\n  end\n/m`, which a one-line `def x = ...` would break).

### Phase 12 (added v1.2.0): `SeatStatusChannel`, the first test

**Implements** D10, FR-7 (status half). **Satisfies** AC-9.1, AC-9.2 (status half), AC-4.3, AC-9.3(d) (status half). **Files:** `spec/channels/seat_status_subscription_spec.rb`, `app/channels/seat_status_channel.rb` (new), `app/models/game.rb`, `spec/models/seat_status_broadcast_spec.rb`, `spec/requests/seat_status_pages_spec.rb`, `spec/models/status_broadcast_scan_spec.rb`, `spec/docs/spec_amendments_spec.rb`.

1. **Red, the named test.** The subscription spec's group becomes `RSpec.describe SeatStatusChannel, type: :channel` and gains:

```ruby
  def rows(message) = Nokogiri::HTML5.fragment(message).css("li.seat-status__row").to_h { |li| [ li["data-power"], li.at_css(".seat-status__state").text ] }

  it "transmits one snapshot on subscribing, and England's row reads Submitted when England has submitted (AC-9.1)" do
    game.seats.find_by(power: "england").save_orders!(game.current_phase, {}, submit: true)
    subscribe(signed_stream_name: signed(:seat_status, game.public_id))

    expect(subscription).to be_confirmed
    expect(subscription).to have_stream_from("seat_status:#{game.public_id}")
    expect(transmissions.size).to eq(1)
    expect(rows(transmissions.first).size).to eq(7)
    expect(rows(transmissions.first)).to include("england" => "Submitted", "france" => "Not submitted")
  end

  it "transmits one more when a client resubscribes, and all seven read Not submitted when nobody has submitted (AC-9.1)" do
    subscribe(signed_stream_name: signed(:seat_status, game.public_id))
    subscribe(signed_stream_name: signed(:seat_status, game.public_id))

    expect(transmissions.size).to eq(2)
    expect(rows(transmissions.last).values.uniq).to eq([ "Not submitted" ])
  end
```
   Run `bundle exec rspec spec/channels/seat_status_subscription_spec.rb`: fails (`uninitialized constant SeatStatusChannel`). The three existing examples stay (confirms, rejects, hears nothing) and now describe the new class.
2. **Builders** in `Game` (both blocks, the second replacing the current body):

```ruby
  def seat_status_message
    html = ApplicationController.render(partial: "shared/seat_status", locals: { statuses: current_phase.seat_statuses })
    Turbo::StreamsChannel.turbo_stream_action_tag(:update, target: "seat-status", template: html, method: :morph)
  end

  def broadcast_seat_status
    message = seat_status_message # outside the rescue: a broken template raises everywhere (D7)
    begin
      Turbo::StreamsChannel.broadcast_stream_to(:seat_status, public_id, content: message)
    rescue StandardError => error
      Rails.logger.warn("seat status broadcast failed: #{error.class}")
    end
  end
```
   Written first, red, in `seat_status_broadcast_spec.rb`: after one flip `game.seat_status_message` equals `payloads.last` (JSON-decoded), and `Game.start!(power: "england").game.public_id` matches `/\A#{Game::PUBLIC_ID_PATTERN}\z/` (so the generator and the parser cannot drift). Add `PUBLIC_ID_PATTERN` to `Game`. The stub at `seat_status_broadcast_spec.rb:62` and the one at `seat_status_pages_spec.rb:95` change from `broadcast_update_to` to `broadcast_stream_to`.
3. **Channel, in two steps so the rejections are red.** First a loose version that behaves like Turbo's own channel (it confirms any verified name and transmits only if a game is found):

```ruby
  def subscribed
    return reject unless (name = verified_stream_name_from_params)
    stream_from name.to_s
    game = Game.find_by(public_id: name.to_s.delete_prefix("seat_status:"))
    transmit game.seat_status_message if game
  end
```
   Then the rejection examples below, every one of which fails against it on `be_rejected`; then the strict one:

```ruby
# app/channels/seat_status_channel.rb
class SeatStatusChannel < Turbo::StreamsChannel
  NAME = /\Aseat_status:(?<id>#{Game::PUBLIC_ID_PATTERN})\z/

  def subscribed
    name = verified_stream_name_from_params
    match = name.is_a?(String) && NAME.match(name)
    game = match && Game.find_by(public_id: match[:id])
    return reject unless game

    stream_from name
    transmit game.seat_status_message
  end
end
```
   Rejection examples (AC-9.2, status half), each `be_rejected` and `transmissions` empty: unsigned, forged key, no name, `signed(game)` (the general stream), `signed(:results, id, 1)`, `signed(:seat_status, "AAAAAAAAAAAA")` (no such game), `signed(:seat_status, "#{id}:x")`, a name with a trailing newline (`Turbo.signed_stream_verifier.generate("seat_status:#{id}\n")`), and non-strings signed honestly with the app's own verifier (its serializer is JSON): `Turbo.signed_stream_verifier.generate(["seat_status:#{id}"])` and `generate({ "a" => 1 })`.
4. **The scan and the amendment spec move now** (so the suite is green at this commit). In `status_broadcast_scan_spec.rb`: the "names the cable" example's allowed file list becomes `app/models/game.rb` plus `app/channels/seat_status_channel.rb` (compared with `match_array`: the glob sorts `app/channels` first), the `game.rb` "outside" removal also strips `seat_status_message`, and a new example says `transmit` is named (code only) once in `app/channels/seat_status_channel.rb` and nowhere else in `app/` and `lib/`; the channel file, with its `< Turbo::StreamsChannel` removed, matches neither the `cable` pattern nor `/\brender\b|\bbroadcast\w*|Submission|\bsubmissions\b|SavedOrder|saved_orders?|orders_for/`. In `spec/docs/spec_amendments_spec.rb`, line 33's assertion of spec 024's exact version is dropped (its own comment at line 9 says the version line moves on and the row stays); the 1.4.0 row assertions stay.

**Verify:** `bundle exec rspec spec/channels spec/models spec/docs spec/requests/seat_status_pages_spec.rb` passes. Commit: "Catch a status subscriber up with the current seven rows" (the body says it also repairs `spec_amendments_spec.rb:33`, which is red at the start of this work because spec 024 is already at 1.2.0).

### Phase 13 (added v1.2.0): the payload proof covers the catch-up

**Satisfies** AC-9.3 (a), (b), (c), AC-3.1, 3.2, 3.4 extensions. **Files:** `spec/models/status_payload_secrecy_spec.rb` (becomes a channel spec).

1. Red first. The group becomes `RSpec.describe "The status payload", type: :channel do` with `tests SeatStatusChannel` and `before { stub_connection }` (rspec-rails takes the channel class from `tests` when the describe is a string). `run_flips` returns `{ broadcasts:, catch_ups: }` and every existing use of its result (the `quiet` and `busy` lets and what reads them) becomes `quiet[:broadcasts]` and so on. The no-flip step does not broadcast, so there are six catch-ups and five broadcasts; (a) pairs each catch-up with the latest broadcast so far (for the first catch-up, which follows the first flip, that is the first broadcast; for the no-flip step, the one before it):

```ruby
  def catch_up(game)
    before = transmissions.size
    subscribe(signed_stream_name: Turbo::StreamsChannel.signed_stream_name([ :seat_status, game.public_id ]))
    expect(subscription).to be_confirmed
    expect(transmissions.size).to eq(before + 1) # one subscribe, one message
    transmissions.last.to_str.tap { unsubscribe }
  end
```
   `catch_up(game)` is called after each flip in `run_flips`. New examples: (a) each catch-up equals the JSON-decoded last broadcast for the same state (for a no-flip step, the previous one); (b) each passes the AC-3.1 allowlist (the existing matcher applied to the string) and the AC-3.4 word and digit rules; (c) a catch-up broadcasts nothing: `ActionCable.server.pubsub.broadcasts("seat_status:#{id}").size` is the same before and after `catch_up` (the channel test stub never touches the pubsub, so a `not_to receive` would prove nothing), and `expect(ActionCable.server).not_to receive(:broadcast)` around it; (d) the two games' `catch_ups` lists are byte-equal.
2. **Proving the examples are not vacuous.** Two temporary mutations of the channel, each reverted, recorded in the commit message. (i) `transmit game.seat_status_message.sub("<li ", '<li data-orders="1" ')`: the allowlist and (a) examples fail while the broadcast examples stay green. (ii) `transmit game.seat_status_message.sub("<li ", %(<li data-n="#{SavedOrder.where(phase: game.current_phase).count}" ))`: this depends on the orders, so the cross-game byte-equality example (d) fails (a mutation that changes both games alike cannot).

**Verify:** `bundle exec rspec spec/models/status_payload_secrecy_spec.rb spec/models/seat_status_broadcast_spec.rb`. Commit: "Prove the catch-up carries what the broadcast carries".

### Phase 14 (added v1.2.0): `ResultsChannel`

**Implements** D10 (results half), FR-7. **Satisfies** AC-9.2 (results half), AC-9.4, AC-9.3(d). **Files:** `spec/channels/results_subscription_spec.rb` (new), `app/channels/results_channel.rb` (new), `app/models/game.rb`, `spec/models/results_broadcast_spec.rb`, `spec/requests/reveal_post_spec.rb`, `spec/models/status_broadcast_scan_spec.rb`.

1. **Red.**

```ruby
RSpec.describe ResultsChannel, type: :channel do
  let(:game) { Game.start!(power: "england").game }
  def signed(*streamables) = Turbo::StreamsChannel.signed_stream_name(streamables)
  before { stub_connection }

  it "streams from the game's results stream and transmits nothing for an open phase (AC-9.4)" do
    subscribe(signed_stream_name: signed(:results, game.public_id, 1))

    expect(subscription).to be_confirmed
    expect(subscription).to have_stream_from("results:#{game.public_id}")
    expect(transmissions).to be_empty
  end

  it "transmits the reveal's own refresh to a page drawn for a phase that has been revealed since, and nothing for the open phase (AC-9.4)" do
    game.current_phase.reveal!
    broadcast = JSON.parse(ActionCable.server.pubsub.broadcasts("results:#{game.public_id}").last)
    subscribe(signed_stream_name: signed(:results, game.public_id, 1))

    expect(transmissions.map(&:to_str)).to eq([ broadcast ])
    expect(broadcast).to eq(%(<turbo-stream action="refresh"></turbo-stream>))
    subscribe(signed_stream_name: signed(:results, game.public_id, 2))
    expect(transmissions.size).to eq(1)
  end

  [ [ "the status name", ->(g) { [ :seat_status, g.public_id ] } ], [ "the general stream", ->(g) { [ g ] } ],
    [ "no phase number", ->(g) { [ :results, g.public_id ] } ], [ "a leading zero", ->(g) { [ :results, g.public_id, "01" ] } ],
    [ "zero", ->(g) { [ :results, g.public_id, 0 ] } ], [ "a suffix", ->(g) { [ :results, g.public_id, "1x" ] } ],
    [ "two numbers", ->(g) { [ :results, g.public_id, 1, 2 ] } ], [ "a phase that does not exist", ->(g) { [ :results, g.public_id, 9 ] } ],
    [ "a number beyond the integer range", ->(g) { [ :results, g.public_id, "99999999999999999999" ] } ],
    [ "a game that does not exist", ->(_g) { [ :results, "AAAAAAAAAAAA", 1 ] } ] ].each do |label, name|
    it "rejects #{label} and transmits nothing (AC-9.2)" do
      subscribe(signed_stream_name: signed(*name.call(game)))
      expect(subscription).to be_rejected
      expect(transmissions).to be_empty
    end
  end
  # plus, each rejected with nothing transmitted: unsigned, forged key, no name, a trailing newline, and non-strings signed with
  # Turbo.signed_stream_verifier.generate(["results:<id>:1"]) and generate({ "a" => 1 })
end
```
   Run: fails (`uninitialized constant ResultsChannel`). Build the channel first loosely (stream any verified name, parse the number with `to_i`), watch the shape examples fail, then make it strict.
2. **Builders and channel.**

```ruby
# Game
  def results_refresh_message
    Turbo::StreamsChannel.turbo_stream_refresh_tag(request_id: nil)
  end

  def broadcast_results_refresh
    Turbo::StreamsChannel.broadcast_stream_to(:results, public_id, content: results_refresh_message)
  rescue StandardError => error
    Rails.logger.warn("results broadcast failed: #{error.class}")
  end
```
```ruby
# app/channels/results_channel.rb
class ResultsChannel < Turbo::StreamsChannel
  NAME = /\Aresults:(?<id>#{Game::PUBLIC_ID_PATTERN}):(?<number>[1-9]\d*)\z/

  def subscribed
    name = verified_stream_name_from_params
    match = name.is_a?(String) && NAME.match(name)
    game = match && Game.find_by(public_id: match[:id])
    phase = game && game.phases.find_by(number: match[:number].to_i)
    return reject unless phase

    stream_from "results:#{game.public_id}"
    transmit game.results_refresh_message if phase.revealed_at
  end
end
```
3. **Existing specs that move with it:** `results_broadcast_spec.rb:58` and `reveal_post_spec.rb:146` stub `broadcast_stream_to` instead of `broadcast_refresh_to` (the expectations name the warning line they want: the status broadcast in a reveal is also stubbed and logs its own); the AC-4.1/4.2/4.4 examples of `results_broadcast_spec.rb` run unchanged and are the proof that 025's payload is untouched. **The scan** (`status_broadcast_scan_spec.rb`): the allowed files gain `app/channels/results_channel.rb`, the `game.rb` removal also strips `results_refresh_message`, `transmit` is named once in each of the two channel files, and `results_refresh_message` and `seat_status_message` are defined only in `app/models/game.rb`.

**Verify:** `bundle exec rspec spec/channels spec/models spec/requests/reveal_post_spec.rb`. Commit: "Refresh a phone that slept through a reveal when it resubscribes".

### Phase 15 (added v1.2.0): the pages name the channels

**Satisfies** AC-4.1, AC-9.5, AC-4.5 (names verified). **Files:** `app/views/phases/_status.html.erb`, `app/views/results/_live.html.erb`, `app/views/games/show.html.erb`, `app/views/hosts/show.html.erb`, `app/views/seat_orders/show.html.erb`, `app/views/order_pickers/show.html.erb`, `spec/requests/results_stream_spec.rb`, `spec/requests/seat_status_pages_spec.rb`, `spec/requests/order_secrecy_spec.rb`, `spec/system/reveal_results_spec.rb`.

1. **Red** (specs first):
   - `results_stream_spec.rb`: the expected names at lines 25, 34 and 42 become `results:#{id}:1` (and `results:#{other.game.public_id}:1`); a new example reads each source's `channel` attribute on the four pages (`SeatStatusChannel`, `ResultsChannel`).
   - `seat_status_pages_spec.rb`: AC-4.1's example also expects `channel="SeatStatusChannel"` on the status source.
   - `order_secrecy_spec.rb`: lines 312 and 313 (`results:#{id}` becomes `results:#{id}:1`) and line 525 (`"results:#{id}"` becomes `"results:#{id}:2"`; that sweep already visits every viewer and every route, revealed routes included, with phase 2 open, so it is the AC-9.5 proof that no page carries a revealed phase's number) gain a check of each source's `channel` attribute; the helpers at lines 303 and 428 are unchanged.
   - `reveal_results_spec.rb:96-106` ("still measures the refusal page"): it visits the order screen and reveals at once, so after this phase a late subscription would be sent a catch-up refresh and the page would leave. The example waits `connected(1)` before the reveal and its comment says the page has subscribed before it.
2. **Green.**

```erb
<%# phases/_status.html.erb %>
<%= turbo_stream_from :seat_status, game.public_id, channel: SeatStatusChannel %>
```
```erb
<%# results/_live.html.erb, locals: game, phase %>
<% turbo_refreshes_with method: :morph, scroll: :preserve %>
<%= turbo_stream_from :results, game.public_id, phase.number, channel: ResultsChannel %>
```
   The four callers pass `phase: @phase` (all four hold the open phase in `@phase`; the order screen and picker redirect before rendering a revealed one).

**Verify:** `bundle exec rspec spec/requests spec/system/live_status_spec.rb spec/system/reveal_results_spec.rb` passes. Commit: "Name the catch-up channels on the pages that subscribe".

### Phase 16 (added v1.2.0): the scan, finished

**Satisfies** AC-9.7, AC-2.7(c), AC-3.7. **Files:** `spec/models/status_broadcast_scan_spec.rb`.

The allowances arrived with the code in Phases 12 and 14. This phase adds what is left: the control lines (`transmit x` and `ActionCable.server.broadcast` outside the two channel files are caught by the patterns; a `class X < Turbo::StreamsChannel` in a third file is caught by the file list), the rule that `shared/seat_status` is rendered only by `app/helpers/seat_status_helper.rb` and `app/models/game.rb`, and AC-3.7: the "keeps the status code away from saved orders" list gains the whole `seat_status_message` and `results_refresh_message` bodies and both channel files. Red by adding a throwaway `transmit "x"` to `app/models/seat.rb` and a `render "shared/seat_status"` to a view, seeing the scan fail, and removing both.

**Verify:** `bundle exec rspec spec/models/status_broadcast_scan_spec.rb`. Commit: "Finish the scan that names the channels as the only other senders".

### Phase 17 (added v1.2.0): a disconnected phone catches up (system spec)

**Satisfies** AC-9.6. **Files:** `spec/system/catch_up_spec.rb` (new).

AC-9.6's "two sessions" are read as England's browser (the page under test) and the server side that changes the state while it is cut off: France's submit goes through the same `Seat#save_orders!` whose broadcast the page would have received, and the reveal goes through a second Capybara session on the host's own confirmation page, as `reveal_results_spec#host_reveals` does.

1. **Red first.** Write the examples below. Because Phases 12 to 15 already exist, the red is made by a temporary revert, described after the code.

```ruby
require "rails_helper"
require_relative "../support/results_fixtures"

RSpec.describe "Catching up after a disconnect", type: :system do
  include ResultsFixtures

  let(:started) { Game.start!(power: "germany") }
  let(:game) { started.game }
  let(:id) { game.public_id }
  let!(:england) { game.take_seat!("england") }          # [seat, token]
  let!(:france) { game.take_seat!("france").first }

  before { england.first.save_orders!(game.current_phase, { "lon" => json_of(move(:england, :lon, :nth)) }, submit: true) }

  def state_of(power) = find("#seat-status [data-power='#{power}'] .seat-status__state").text

  # Closes or reopens the page's Action Cable consumer from the test alone: no hook is added to app/javascript.
  def socket(action)
    page.evaluate_async_script(<<~JS, action)
      const [action, done] = [arguments[0], arguments[arguments.length - 1]]
      import("@hotwired/turbo-rails").then(({ cable }) => cable.getConsumer()).then((consumer) => { consumer[action](); done(true) })
    JS
  end

  # Counts the stream messages this page has rendered, so "nothing arrived" and "a snapshot arrived and changed nothing" differ.
  # (it wraps the render, so the count goes up after the message has been applied, not before)
  def count_renders
    execute_script(<<~JS)
      window.renders = 0
      document.addEventListener("turbo:before-stream-render", (event) => {
        const render = event.detail.render
        event.detail.render = async (element) => { await render(element); window.renders++ }
      })
    JS
  end
  def renders = evaluate_script("window.renders")

  def open_seat_page
    visit "/games/#{id}/seat-link?token=#{england.last}"
    expect(page).to have_css("turbo-cable-stream-source[connected]", count: 2, visible: :all, wait: 5)
    count_renders
  end

  def disconnect
    socket("disconnect")
    expect(page).to have_no_css("turbo-cable-stream-source[connected]", visible: :all)
  end

  def host_reveals
    Capybara.using_session(:revealer) do
      with_viewport(360) do
        visit "/games/#{id}/host-link?token=#{started.host_token}"
        click_on "Reveal orders"
        click_button "Reveal orders"
        expect(page).to have_css(".banner--info", text: "was revealed")
      end
    end
  end

  it "shows a seat page what changed while its socket was closed, without a reload (AC-9.6)" do
    with_viewport(360) do
      open_seat_page
      disconnect
      france.save_orders!(game.current_phase, {}, submit: true) # broadcast now: this page is not listening

      expect(state_of("france")).to eq("Not submitted")
      expect(renders).to eq(0)
      socket("connect")
      expect(page).to have_css("#seat-status [data-power='france'] .seat-status__state", text: "Submitted", wait: 5)
      expect(renders).to be >= 1
    end
  end

  it "sends a snapshot on reconnecting that changes nothing when nothing was missed (AC-9.6)" do
    france.save_orders!(game.current_phase, {}, submit: true)
    with_viewport(360) do
      open_seat_page
      before = evaluate_script("document.getElementById('seat-status').outerHTML")
      disconnect
      socket("connect")

      page.document.synchronize(10) { raise Capybara::ExpectationNotMet, "no snapshot rendered" unless renders >= 1 } # the counter is the proof it arrived
      expect(evaluate_script("document.getElementById('seat-status').outerHTML")).to eq(before)
      expect(state_of("france")).to eq("Submitted")
    end
  end

  it "redraws a page for the next phase, with the results, when the reveal happened while its socket was closed (AC-9.6, spec 025)" do
    with_viewport(360) do
      open_seat_page
      first_title = find(".phase-header__title").text
      disconnect
      host_reveals

      expect(find(".phase-header__title").text).to eq(first_title) # still the old page: it was not listening
      socket("connect")
      expect(page).to have_css(".phase-header__title", text: /fall 1901/i, wait: 10)
      expect(page).to have_css("section[data-results] .result-row", text: "Move to North Sea (NTH)")
    end
  end
end
```
   The results section's exact selector and the next phase's title text are read from `app/views/results/_section.html.erb` and `Phase#title` when the file is written, and the examples use whatever those render (the header is upper-cased by CSS, so the comparison is case-insensitive).
   **The red:** temporarily revert `channel:` to the default in the two views (not committed), run the three examples: the first and third fail (the page is not caught up) and the second fails (`renders` stays 0 and the wait raises); restore the views.
2. **Green** with the Phase 15 pages in place. If `import("@hotwired/turbo-rails")` does not work through WebDriver's script call, inject a module script from the test, `<script type="module">import { cable } from "@hotwired/turbo-rails"; window.__cable = cable</script>`, and wait for `window.__cable`: the same module instance, test-only, no change to `app/javascript`, so the AC stands. I do not fall back to removing the elements.

**Verify:** `bundle exec rspec spec/system/catch_up_spec.rb spec/system/live_status_spec.rb spec/system/reveal_results_spec.rb`, run three times to look for flakes. Commit: "Show a disconnected phone catching up".

### Phase 18 (added v1.2.0): documents and the close

**Satisfies** AC-9.8. **Files:** `README.md`, `docs/specs/024-live-status/plan.md` (this addendum), `spec/docs/spec_amendments_spec.rb`.

1. README "Live updates": the sentence "A phone that was asleep or offline shows the old page until it is touched or reloaded." (and the sibling sentence about the status list, if it says the same) becomes: a phone that wakes or reconnects is sent the current list, and a refresh if a reveal happened, as it resubscribes; and the three limits (pages with no stream source, a refresh Turbo drops mid-navigation, the millisecond window between the snapshot's read and the stream going live).
2. `spec/docs/spec_amendments_spec.rb` gains, red first (the rows exist but the README line does not): spec 025's `| 1.1.0 |` row includes "spec 024", "ResultsChannel" and "AC-9.4"; spec 024's `| 1.2.0 |` row includes "SeatStatusChannel", "ResultsChannel" and "#105"; the README names the catch-up. The route table is unchanged: AC-9.8's "no route added" is proved by the existing classification examples (`order_secrecy_spec.rb:32` and `:48`), which stay green.
3. Copy this addendum into `plan.md` before the "Done-when map", extend the map and the coverage table with the rows below, and add the Plan changelog row 1.2.0.
4. Full proof, from `web/`: `bundle exec rspec`, `bin/rubocop`, `bin/brakeman`, `wc -c app/assets/stylesheets/*.css` (unchanged), `git diff --name-only main...HEAD` (only `web/`).

Commit: "Record the catch-up in the README and the plan".

**Done-when map (Issue #105)**

| Issue item | Where it is proved |
|---|---|
| A subscriber gets the current snapshot as it subscribes or resubscribes | Phase 12 (channel spec, AC-9.1), Phase 14 (results), Phase 17 (system) |
| The snapshot carries exactly what #24's broadcasts carry, covered by #24's payload proof | Phase 12 (one builder), Phase 13 (allowlist, byte equality, words), Phases 12, 14, 16 (scan) |
| A system spec shows a disconnected session catching up | Phase 17 |

**Spec coverage (1.2.0):** D10 and FR-7: 12, 14, 15. AC-9.1: 12. AC-9.2: 12, 14. AC-9.3: 12, 13. AC-9.4: 14. AC-9.5: 15. AC-9.6: 17. AC-9.7: 12, 14, 16. AC-9.8: 12 to 16, 18. AC-2.7, 3.1, 3.2, 3.4, 3.7: 13, 16. AC-4.1, 4.3: 12, 15.

**Risks (1.2.0).**
- *The system spec's socket control* (`import("@hotwired/turbo-rails")`, `cable.getConsumer()`, `consumer.disconnect()/connect()`) was traced by the plan review against turbo.min.js and Action Cable's `Consumer`; Phase 17's first run is the proof. After the catch-up refresh Turbo's morph removes the `connected` attribute from the status source (the server HTML does not carry it) and the status source, whose name did not change, does not resubscribe; the results source's name changes (`:1` to `:2`) so it resubscribes, and a later reconnect does not replay the old phase's refresh. The reveal example waits for the new page, not for `connected`.
- *`turbo_stream_action_tag` and `turbo_stream_refresh_tag`* are public on `Turbo::StreamsChannel` (read in turbo-rails 2.0.23 and in the plan review); Phase 12's builder-equals-broadcast example fails loudly if the bytes ever differ from what `broadcast_update_to` sent.
- *Channel code reads the database in a system spec for the first time* (`Game.find_by` on an Action Cable worker thread, against the one shared SQLite connection the system specs pin). It should work (the pool shares the connection under a lock); Phase 17's three repeated runs are the proof, and a hang or a locked database stops the work and goes to `ask`.
- *Stubs of `broadcast_stream_to`* also reach the status broadcast in a reveal; the expectations name the warning line they want.
- *A late subscription after a reveal now sends a refresh* (the race the catch-up closes): any system spec that reveals right after a visit without waiting for the stream could see it; Phase 15 fixes the one that does (`reveal_results_spec.rb:96-106`), and the other system specs run in Phase 15's verify.
- *Merges with #27 and #29:* #29 edits `results/_section`, removes the practice note and also adds a spec 025 1.1.0 changelog row (whichever merges second takes the next version); #27 touches the host page. Phase 15 edits one line of `hosts/show.html.erb` and Phase 17 reads `results/_section`'s selector. When `main` moves, merge it keeping both sides.
- *Added cost:* each subscribe renders seven rows and runs two queries.

**As built (deviations from the plan above, none changing a requirement).**
- Spec 025's row for this work is **1.2.0**, not 1.1.0: #29 (spec 029) merged first and took 1.1.0. The merge kept both rows; the plan and spec 024 say 1.2.0 where they name it.
- `spec/docs/spec_amendments_spec.rb`'s `amendment_row` helper (spec 029's) required a spec's version line to equal its spec-029 row's version; it now requires the version line to have reached it, which its own comment already intended.
- The cross-game byte-equality assertion (D) shares one example with the broadcast pairing, so the second mutation of Phase 13 is caught by both assertions of that example at once; the first is caught by the allowlist, the word rules and the pairing.
- The scan spec's list of channel files is a local variable of the describe block (not a constant), and the "renders the partial" and "defines the two messages" rules are two small examples of their own.
- Phase 18's red was shown by restoring the old README for one run of the amendment spec, since the spec and the README line were written together.


## Changelog

| Version | Change |
|---------|--------|
| 1.2.0 | Phases 12 to 18 added for spec 024 1.2.0 (Issue #105): the catch-up channels, with the Opus plan review's two rounds taken and the as-built deviations listed after Phase 18 |
| 1.1.0 | After the Opus review. Blocking: the Phase 5 scan now reads code only and a narrower pattern, so comments may use the word "broadcast"; the Phase 6 sweep rewrite lists only the four viewer and page pairs that get a status list. Non-blocking, all taken: heading checks that really compare text; the status block placed after "Keep this page" on the seat page; a fresh `ActionCable::Server::Configuration` in the origin spec; the production line names the variable literally; waits for `turbo-cable-stream-source[connected]` and `have_css` with a wait in the system specs; a stale-seat copy and `clear_messages(stream)` in the AC-2.6 example; the AC-3.4 check of the game ids; the AC-2.7(a), AC-4.5, AC-4.6, AC-5.4 and AC-1.1 examples added; `var(--weight-strong)`; a space between a row's two spans (spec 1.0.1); README checks tied to the new section; the already-true #105 test dropped |
| 1.0.0 | First draft |

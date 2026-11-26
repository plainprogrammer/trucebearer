require "rails_helper"
require_relative "../support/rules_helpers"

# Spec 023 Story 7: five units, a full set of orders, 360 pixels wide, within 18 taps and 45 seconds (D7).
RSpec.describe "Entering orders with the pickers", type: :system do
  include RulesHelpers

  def max_taps = 18

  def max_seconds = 45

  # One tap: a click on a link or button. It waits for the page the tap leads to (its heading) before returning, so the next tap
  # and every measurement are made on that page and not on the one before it (Turbo renders after the click returns).
  def tap_on(text, see:)
    @taps += 1
    click_on text
    expect(page).to have_css("h1", text: see)
  end

  def screenshot(name)
    dir = ENV["SCREENSHOTS"]
    page.save_screenshot(File.join(dir, "#{name}.png")) if dir
  end

  def measure_step(label, width)
    widths = evaluate_script("({ scroll: document.documentElement.scrollWidth, client: document.documentElement.clientWidth })")
    expect(widths["scroll"]).to be <= widths["client"], "#{label} scrolls sideways at #{width}"
    small = evaluate_script(<<~JS)
      Array.from(document.querySelectorAll(":is(main, .app-actions) :is(a:not(p a), button, input:not([type=hidden]))")).filter((el) => {
        const r = el.getBoundingClientRect(); return r.width < 43.5 || r.height < 43.5;
      }).map((el) => el.className || el.tagName)
    JS
    expect(small).to be_empty, "#{label}: controls under 44 by 44: #{small.join(', ')}"
  end

  def start_game_with(units)
    started = Game.start!(power: "england")
    started.game.current_phase.update_columns(position: rules_position(units: units))
    visit "/games/#{started.game.public_id}/seat-link?token=#{started.seat_token}"
    started
  end

  it "enters orders for five units and submits in at most 18 taps and 45 seconds (AC-7.1, AC-7.2)" do
    started = start_game_with([ [ :england, :army, :lvp ], [ :england, :fleet, :edi ], [ :england, :fleet, :lon ],
                                [ :england, :army, :yor ], [ :england, :fleet, :mao ] ])
    game = started.game
    @taps = 0

    with_viewport(360) do
      began = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      visit "/games/#{game.public_id}/phases/1/orders"
      expect(page).to have_css(".unit-row", count: 5)
      measure_step("the list", 360)
      screenshot("01-order-screen")

      tap_on "Fleet in Edinburgh", see: "What should it do?"                                              # 3
      tap_on "Move", see: "Move where?"
      tap_on "Norwegian Sea", see: "Your orders"
      tap_on "Fleet in London", see: "What should it do?"                                                 # 3
      tap_on "Move", see: "Move where?"
      tap_on "English Channel", see: "Your orders"
      tap_on "Army in Yorkshire", see: "What should it do?"                                               # 2
      tap_on "Hold", see: "Your orders"
      tap_on "Army in Liverpool", see: "What should it do?"                                               # 4
      measure_step("the action step", 360); screenshot("02-action")
      tap_on "Support", see: "Support which unit?"
      measure_step("support which unit", 360); screenshot("06-support-which-unit")
      tap_on "Fleet in Edinburgh", see: "Support it how?"
      measure_step("support it how", 360); screenshot("07-support-how")
      tap_on "Move to Clyde", see: "Your orders"
      tap_on "Fleet in Mid-Atlantic Ocean", see: "What should it do?"                                     # 4
      tap_on "Move", see: "Move where?"
      tap_on "Spain", see: "Which coast?"
      tap_on "North coast", see: "Your orders"
      expect(page).to have_css(".submit-bar", text: "5 of 5 ordered")
      click_on "Submit orders" # the last tap
      @taps += 1
      expect(page).to have_css(".banner--info", text: "Submitted.")
      measure_step("the submitted list", 360); screenshot("11-submitted")
      elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - began
      expect(@taps).to be <= max_taps
      expect(elapsed).to be <= max_seconds
      seat = game.seats.find_by(power: "england")
      expect(seat.orders_for(game.current_phase).size).to eq(5)
      expect(seat.submitted?(game.current_phase)).to be(true)
    end
  end

  it "completes a by-land-or-convoy move, a convoy order and the other steps, with no sideways scroll and no small control (AC-7.3, AC-7.4)" do
    started = start_game_with([ [ :england, :army, :lon ], [ :england, :fleet, :nth ], [ :england, :fleet, :mao ] ])
    seat = started.game.seats.find_by(power: "england")
    @taps = 0
    with_viewport(360) do
      visit "/games/#{started.game.public_id}/phases/1/orders"
      tap_on "Army in London", see: "What should it do?"
      tap_on "Move", see: "Move where?"
      measure_step("the destinations", 360); screenshot("03-move-where")
      tap_on "Yorkshire", see: "How does it get there?" # land and convoy both legal: the "How" step
      measure_step("by land or convoy", 360); screenshot("04-by-land-or-convoy")
      tap_on "By convoy", see: "Your orders"
      expect(page).to have_css(".unit-row__order", text: "Move to Yorkshire (YOR) by convoy")

      tap_on "Fleet in North Sea", see: "What should it do?"
      tap_on "Convoy", see: "Convoy which army?"
      measure_step("which army", 360); screenshot("08-convoy-which-army")
      tap_on "Army in London", see: "Convoy it where?"
      measure_step("convoy where", 360); screenshot("09-convoy-where")
      tap_on "Yorkshire", see: "Your orders"

      tap_on "Fleet in Mid-Atlantic Ocean", see: "What should it do?"
      tap_on "Move", see: "Move where?"
      tap_on "Spain", see: "Which coast?"
      measure_step("which coast", 360); screenshot("05-which-coast")
      tap_on "South coast", see: "Your orders"
      expect(seat.orders_for(started.game.current_phase.reload).keys).to match_array(%w[lon nth mao])
      screenshot("10-order-screen-ordered")
    end
  end

  it "shows 'Saving…' while a form is being submitted and the resting text otherwise (AC-3.6)" do
    started = start_game_with(RulesEngine.starting_position.units.select { |u| u.power == :england }.map { |u| [ :england, u.type, u.location.province ] })
    with_viewport(360) do
      visit "/games/#{started.game.public_id}/phases/1/orders"
      expect(page).to have_css(".save-status__rest", text: "Saved")
      execute_script("document.querySelector('.submit-bar form').setAttribute('aria-busy', 'true')")
      expect(page).to have_css(".save-status__saving", text: "Saving…", visible: :visible)
      expect(page).to have_no_css(".save-status__rest", visible: :visible)
      execute_script("document.querySelector('.submit-bar form').removeAttribute('aria-busy')")
      expect(page).to have_css(".save-status__rest", text: "Saved", visible: :visible)
    end
  end
end

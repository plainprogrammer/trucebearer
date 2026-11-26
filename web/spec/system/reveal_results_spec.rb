require "rails_helper"
require_relative "../support/results_fixtures"

# Spec 025 Story 3: two real browsers at 360 pixels. The test cable adapter delivers inside this process, so a message sent by the
# revealing session's request reaches the other sessions' open pages. It exercises Turbo and the pages, not Solid Cable's own delivery.
RSpec.describe "Revealing results to every phone", type: :system do
  include ResultsFixtures

  def screenshot(name)
    dir = ENV["SCREENSHOTS"]
    page.save_screenshot(File.join(dir, "#{name}.png")) if dir
  end

  # Waits for every stream source this page has to be subscribed: Turbo sets [connected] once the socket confirms.
  def connected(count) = expect(page).to have_css("turbo-cable-stream-source[connected]", count: count, visible: :all, wait: 5)

  def measure(label) # as live_status_spec does: nothing scrolls sideways, no control under 44 by 44
    widths = evaluate_script("({ scroll: document.documentElement.scrollWidth, client: document.documentElement.clientWidth })")
    expect(widths["scroll"]).to be <= widths["client"], "#{label} scrolls sideways at 360"
    small = evaluate_script(<<~JS)
      Array.from(document.querySelectorAll(":is(main, .app-actions) :is(a:not(p a), button, input:not([type=hidden]))")).filter((el) => {
        const r = el.getBoundingClientRect(); return r.width < 43.5 || r.height < 43.5;
      }).map((el) => el.className || el.tagName)
    JS
    expect(small).to be_empty, "#{label}: controls under 44 by 44: #{small.join(', ')}"
  end

  def font_px(selector) = evaluate_script("parseFloat(getComputedStyle(document.querySelector('#{selector}')).fontSize)")

  let(:started) { Game.start!(power: "germany") }
  let(:game) { started.game }
  let(:id) { game.public_id }
  let!(:england) { game.take_seat!("england") }
  let!(:france) { game.take_seat!("france") }

  before { england.first.save_orders!(game.current_phase, { "lon" => json_of(move(:england, :lon, :nth)) }, submit: true) }

  # The host's own phone, a session with no stream to wait on, reveals through the real confirmation page.
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

  it "moves a second phone, an order screen, a picker step and the host's other tab when the host reveals (AC-3.1, AC-3.2)" do
    with_viewport(360) do
      visit "/games/#{id}/seat-link?token=#{england.last}"
      visit "/games/#{id}/phases/1/orders"
      connected(1) # the order screen holds the results source only
      Capybara.using_session(:host_tab) do
        with_viewport(360) do
          visit "/games/#{id}/host-link?token=#{started.host_token}"
          visit "/games/#{id}/host"
          connected(2)
          Capybara.using_session(:picker) do
            with_viewport(360) do
              visit "/games/#{id}/seat-link?token=#{england.last}"
              visit "/games/#{id}/phases/1/orders/lon"
              connected(1)
              Capybara.using_session(:france) do
                with_viewport(360) do
                  visit "/games/#{id}/seat-link?token=#{france.last}"
                  visit "/games/#{id}"
                  connected(2) # the status source and the results source
                  expect(page).not_to have_css("section[data-results]")
                  host_reveals

                  expect(page).to have_css("section[data-results] .result-row", text: "Move to North Sea (NTH)", wait: 5)
                  expect(page).to have_css(".phase-header", text: /fall 1901/i) # the half-stale header of spec 024 is gone
                  expect(page).to have_link("Skip to orders")
                  expect(font_px(".result-group")).to be <= 16.5
                  measure("France's seat page after the reveal")
                  screenshot("01-seat-page-after-reveal")
                end
              end
              expect(page).to have_current_path("/games/#{id}/phases/1/results", wait: 5) # the picker step's refresh met the 303
            end
          end
          expect(page).to have_css("section[data-results] .result-group--reading", wait: 5) # the host's other tab shows the reading view
          expect(font_px(".result-group--reading")).to be >= 19
          measure("the host's other tab after the reveal")
        end
      end
      expect(page).to have_current_path("/games/#{id}/phases/1/results", wait: 5) # the order screen's refresh met the 303
      expect(page).to have_css("section[data-results] .result-row", text: "Move to North Sea (NTH)")
      measure("England's results page")
      screenshot("02-results-page")
    end
  end

  it "still measures the refusal page a stale write meets, at 360 pixels (spec 022 AC-6.1)" do
    allow_any_instance_of(Game).to receive(:broadcast_results_refresh) # so the open order screen stays put and its stale write is sent
    with_viewport(360) do
      visit "/games/#{id}/seat-link?token=#{france.last}"
      visit "/games/#{id}/phases/1/orders"
      Phase.find_by(game: game, number: 1).reveal!
      click_on "Submit orders"
      expect(page).to have_css(".banner--danger", text: "The host has already revealed this phase")
      measure("the refusal page")
    end
  end

  it "keeps the revealing browser's banner and shows the host the reading view (AC-3.3, AC-2.1)" do
    with_viewport(360) do
      visit "/games/#{id}/host-link?token=#{started.host_token}"
      visit "/games/#{id}/host"
      connected(2)
      click_on "Reveal orders"
      click_button "Reveal orders"
      expect(page).to have_css(".banner--info", text: "was revealed")
      sleep 2 # a real wait: a refresh, had one reached this page, would have landed within it
      expect(page).to have_css(".banner--info", text: "was revealed")
      expect(page).to have_current_path("/games/#{id}/host")
      expect(page).to have_css("section[data-results] .result-group--reading")
      expect(font_px(".result-group--reading")).to be >= 19
      measure("the host page after the reveal")
      screenshot("03-host-page-after-reveal")
    end
  end

  it "still shows the Submitted banner after a submit on a morphing order screen (a side effect of the morph, checked at 360)" do
    with_viewport(360) do
      visit "/games/#{id}/seat-link?token=#{france.last}"
      visit "/games/#{id}/phases/1/orders"
      click_on "Submit orders"
      expect(page).to have_css(".banner--info", text: "Submitted.")
      expect(evaluate_script("document.querySelector('.banner--info').getBoundingClientRect().top >= 0")).to be(true)
    end
  end

  it "writes 360-pixel screenshots of a reveal with a mix of outcomes, a dislodged row and the practice note, only when SCREENSHOTS is set (AC-8.4)" do
    other = Game.start!(power: "england")
    hold = ->(power, at) { { "format" => 1, "type" => "hold", "power" => power, "at" => at } }
    mover = ->(power, at, to) { { "format" => 1, "type" => "move", "power" => power, "at" => at, "destination" => { "province" => to, "coast" => nil } } }
    revealed_phase_with(other.game, dislodged: [ %w[england fleet lon] ], outcomes: [
      [ mover.call("england", "edi", "nth"), :succeeded, true, false ], [ mover.call("england", "lvp", "yor"), :bounced, true, false ],
      [ hold.call("england", "lon"), :held, true, true ], [ mover.call("france", "par", "bur"), :succeeded, true, false ],
      [ hold.call("france", "bre"), :held, false, false ] ])
    with_viewport(360) do
      visit "/games/#{other.game.public_id}/host-link?token=#{other.host_token}"
      visit "/games/#{other.game.public_id}/host"
      expect(page).to have_css("[data-dislodged]", count: 1)
      measure("the host reading view")
      screenshot("04-host-reading-view-mix")
      visit "/games/#{other.game.public_id}/seat-link?token=#{other.seat_token}" # the host's own seat
      visit "/games/#{other.game.public_id}"
      expect(page).to have_css(".outcome-tag--dislodged")
      expect(page).to have_css(".practice-note")
      measure("the seat page with a mix of outcomes")
      screenshot("05-seat-page-mix")
      visit "/games/#{other.game.public_id}/phases/1/results"
      measure("a results page with a dislodged row")
      screenshot("06-results-page-mix")
    end
  end
end

require "rails_helper"
require_relative "../support/rules_helpers"

# Spec 026 Story 9: the step-in screens at 360 pixels, with no sideways scroll, controls of at least 44 by 44, and the way back in view.
RSpec.describe "The step-in screens", type: :system do
  include RulesHelpers

  def screenshot(name)
    dir = ENV["SCREENSHOTS"]
    page.save_screenshot(File.join(dir, "#{name}.png")) if dir
  end

  def measure(label, width = 360)
    widths = evaluate_script("({ scroll: document.documentElement.scrollWidth, client: document.documentElement.clientWidth })")
    expect(widths["scroll"]).to be <= widths["client"], "#{label} scrolls sideways at #{width}"
    small = evaluate_script(<<~JS)
      Array.from(document.querySelectorAll(":is(main, .app-actions) :is(a:not(p a), button, input:not([type=hidden]))")).filter((el) => {
        const r = el.getBoundingClientRect(); return r.width < 43.5 || r.height < 43.5;
      }).map((el) => el.className || el.tagName)
    JS
    expect(small).to be_empty, "#{label}: controls under 44 by 44: #{small.join(', ')}"
  end

  it "walks the host into France's seat and out again, and shows France its notice (AC-9.1, AC-9.2)" do
    started = Game.start!(power: "germany")
    game = started.game
    id = game.public_id
    france, france_token = game.take_seat!("france")
    france.save_orders!(game.current_phase, { "par" => json_of(rules_order(:hold, :france, :par)) })

    with_viewport(360) do
      visit "/games/#{id}/host-link?token=#{started.host_token}"
      visit "/games/#{id}/seat-link?token=#{started.seat_token}"
      visit "/games/#{id}/host"
      expect(page).to have_css("[data-step-in-entry] li", count: 1)
      measure("the host page")
      execute_script("document.querySelector('[data-step-in-entry]').scrollIntoView({ block: 'center' })")
      screenshot("01-host-step-in-list")

      click_on "Step in"
      expect(page).to have_css("h1", text: "Step into France's seat")
      expect(page).to have_css(".confirm .button--danger", text: "Step into France")
      measure("the confirmation")
      screenshot("02-confirmation")

      click_on "Step into France"
      expect(page).to have_css("h1", text: "France's orders")
      expect(page).to have_css(".banner--warning", text: "Acting as France")
      expect(page).to have_css(".unit-row", count: 3)
      measure("the stepped-in order screen")
      leave = evaluate_script("(() => { const r = document.querySelector('form[action$=\"/step-in\"] button').getBoundingClientRect(); return { bottom: r.bottom, height: window.innerHeight }; })()")
      expect(leave["bottom"]).to be <= leave["height"], "Leave is below the first screen"
      screenshot("03-stepped-in-orders")

      visit "/games/#{id}"
      expect(page).to have_css("h1", text: "You hold Germany")
      expect(page).to have_css(".banner--warning", text: "Still stepped into France's seat.")
      measure("the host's own seat page while stepped in")
      screenshot("04-still-stepped-in")

      click_on "Leave France's seat"
      expect(page).to have_css("h1", text: "You hold Germany")
      expect(page).to have_no_css(".banner--warning")
    end

    Capybara.using_session("france") do
      with_viewport(360) do
        visit "/games/#{id}/seat-link?token=#{france_token}"
        expect(page).to have_css("h1", text: "You hold France")
        expect(page).to have_css(".banner--warning", text: /The host entered your orders at \d{1,2}:\d{2} (AM|PM) [A-Z]+/)
        measure("France's seat page with the notice")
        screenshot("05-owner-notice")
      end
    end
  end

  it "shows the seat history with a step-in row and a reissue row at 360 pixels (AC-9.1)" do
    started = Game.start!(power: "germany")
    game = started.game
    id = game.public_id
    france, = game.take_seat!("france")
    StepIn.record!(phase: game.current_phase, seat: france)
    game.reissue_seat!(france)

    with_viewport(360) do
      visit "/games/#{id}/host-link?token=#{started.host_token}"
      visit "/games/#{id}/host"
      expect(page).to have_css("[data-seat-history] li", count: 2)
      expect(page).to have_css("[data-seat-history]", text: "seat reissued")
      expect(page).to have_css("[data-seat-history]", text: "stepped in")
      measure("the host page with the seat history")
      execute_script("document.querySelector('[data-seat-history]').scrollIntoView({ block: 'center' })")
      screenshot("06-seat-history")
    end
  end
end

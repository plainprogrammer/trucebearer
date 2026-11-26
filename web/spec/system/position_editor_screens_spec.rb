require "rails_helper"
require_relative "../support/rules_helpers"

# Spec 027 Story 9: the editor's pages at 360 pixels, with no sideways scroll, controls of at least 44 pixels, the primary button in view,
# and the segmented toggle working by tap and by keyboard. SCREENSHOTS=<dir> also writes the eight screenshots of D10.
RSpec.describe "The position editor screens", type: :system do
  include RulesHelpers

  def screenshot(name)
    dir = ENV["SCREENSHOTS"]
    page.save_screenshot(File.join(dir, "#{name}.png")) if dir
  end

  # No sideways scroll, and every control of the page (links in running text excepted) at least 44 pixels tall.
  def measure(label, width = 360)
    widths = evaluate_script("({ scroll: document.documentElement.scrollWidth, client: document.documentElement.clientWidth })")
    expect(widths["scroll"]).to be <= widths["client"], "#{label} scrolls sideways at #{width}"
    small = evaluate_script(<<~JS)
      Array.from(document.querySelectorAll(":is(main, .app-actions) :is(a:not(p a), button, select, input:not([type=hidden]):not(.segmented__input), .segmented__label)")).filter((el) => {
        const r = el.getBoundingClientRect(); return r.width < 43.5 || r.height < 43.5;
      }).map((el) => el.className || el.tagName)
    JS
    expect(small).to be_empty, "#{label}: controls under 44 by 44: #{small.join(', ')}"
  end

  def button_in_view(text)
    box = evaluate_script("(() => { const b = Array.from(document.querySelectorAll('main button, .app-actions button')).find((el) => el.textContent.trim() === #{text.to_json}); const r = b.getBoundingClientRect(); return { bottom: r.bottom, height: window.innerHeight }; })()")
    expect(box["bottom"]).to be <= box["height"], "#{text} is below the first screen"
  end

  it "walks the host through every edit and shows France its notice (AC-9.1 to AC-9.3)" do
    started = Game.start!(power: "germany")
    game = started.game
    id = game.public_id
    france, france_token = game.take_seat!("france")
    france.save_orders!(game.current_phase, { "par" => json_of(rules_order(:hold, :france, :par)) }, submit: true)

    with_viewport(360) do
      visit "/games/#{id}/host-link?token=#{started.host_token}"
      visit "/games/#{id}/seat-link?token=#{started.seat_token}"
      visit "/games/#{id}/host"
      expect(page).to have_link("Edit the board")
      measure("the host page")

      click_on "Edit the board"
      expect(page).to have_css("h1", text: "Edit the board")
      expect(page).to have_css("svg.supply-center-icon")
      measure("the board")

      click_on "Add a unit"
      expect(page).to have_css("h1", text: "Add a unit")
      measure("the add form")
      button_in_view("Add unit")
      screenshot("02-add-unit")

      # The segmented toggle: a tap selects, the radio is the real control, a keyboard focus shows the ring (AC-9.2).
      expect(find("input[value=army]", visible: :all)).to be_checked
      find(".segmented__label", text: "Fleet").click
      expect(find("input[value=fleet]", visible: :all)).to be_checked
      expect(find("input[value=army]", visible: :all)).not_to be_checked
      selected = evaluate_script("getComputedStyle(document.querySelector('input[value=fleet] + .segmented__label')).backgroundColor")
      plain = evaluate_script("getComputedStyle(document.querySelector('input[value=army] + .segmented__label')).backgroundColor")
      expect(selected).not_to eq(plain)
      find("#unit-power").send_keys(:tab)
      ring = evaluate_script("getComputedStyle(document.querySelector('input[name=\"unit[type]\"]:focus + .segmented__label')).outlineStyle")
      expect(ring).to eq("solid")
      ring_color = evaluate_script("getComputedStyle(document.querySelector('input[name=\"unit[type]\"]:focus + .segmented__label')).outlineColor")
      focus_color = evaluate_script("(() => { const probe = document.createElement('i'); probe.style.color = 'var(--color-focus)'; document.body.appendChild(probe); return getComputedStyle(probe).color; })()")
      expect(ring_color).to eq(focus_color)

      select "France", from: "Power"
      select "Burgundy (BUR)", from: "Province"
      click_on "Add unit"
      expect(page).to have_css(".banner--danger", text: "A fleet can't stand in Burgundy: it is inland.")
      expect(find("input[value=fleet]", visible: :all)).to be_checked # what the host picked is kept
      measure("the add form, refused")
      button_in_view("Add unit")
      screenshot("03-add-unit-refused")

      find(".segmented__label", text: "Army").click
      click_on "Add unit"
      expect(page).to have_css(".banner--info", text: "Saved. France's army added in BUR. Saved orders for this phase were cleared.")
      expect(page).to have_css("a.list__row", text: "Army in Burgundy (BUR)")
      measure("the board after an edit")
      screenshot("01-board")

      click_on "Army in Burgundy (BUR)"
      expect(page).to have_css("h1", text: "France's army in Burgundy")
      measure("a unit's page")
      button_in_view("Move unit")
      screenshot("04-unit")

      visit "/games/#{id}/host/phases/1/position/owners"
      expect(page).to have_css("h1", text: "Set a supply center's owner")
      measure("the owners form")
      button_in_view("Set owner")
      select "Belgium (BEL)", from: "Supply center"
      select "Germany", from: "Owner"
      screenshot("05-owner")
      click_on "Set owner"
      expect(page).to have_css(".banner--info", text: "BEL given to Germany. Orders are kept.")

      visit "/games/#{id}/host/phases/1/position/date"
      expect(page).to have_css("h1", text: "Season and year")
      measure("the date form")
      button_in_view("Set season and year")
      screenshot("06-date")

      visit "/games/#{id}/host"
      history = find("[data-seat-history]")
      expect(history).to have_text("board changed: France's army added in BUR")
      expect(history).to have_text("board changed: BEL given to Germany")
      measure("the host page with the History")
      execute_script("document.querySelector('[data-seat-history]').scrollIntoView({ block: 'center' })")
      screenshot("07-host-history")
    end

    Capybara.using_session("france") do
      with_viewport(360) do
        visit "/games/#{id}/seat-link?token=#{france_token}"
        expect(page).to have_css("h1", text: "You hold France")
        expect(page).to have_css(".banner--warning", text: /The host changed the board at \d{1,2}:\d{2} (AM|PM) [A-Z]+\. Orders saved before then were cleared, so check yours\./)
        measure("France's seat page with the notice")
        execute_script("document.querySelector('.banner--warning').scrollIntoView({ block: 'center' })")
        screenshot("08-seat-notice")
      end
    end
  end
end

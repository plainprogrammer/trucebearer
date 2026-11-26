require "rails_helper"
require_relative "../support/rules_helpers"

# Spec 022 NFR layout, AC-8.1, AC-8.3: every screen this feature adds, at phone width and at 768 pixels, has no sideways scroll
# and no tappable control under 44 by 44 CSS pixels, and one round is driven through a real browser. Geometry is read in the
# page, as in screens_layout_spec.rb.
RSpec.describe "Screens of the phase lifecycle", type: :system do
  include RulesHelpers

  def tappable = "a:not(p a), button, input:not([type=hidden]), select"

  def tolerance = 0.5

  def measure_screen(label, width)
    expect(evaluate_script("window.innerWidth")).to eq(width)
    expect(page).to have_css("h1")

    widths = evaluate_script("({ scroll: document.documentElement.scrollWidth, client: document.documentElement.clientWidth })")
    expect(widths["scroll"]).to be <= widths["client"], "#{label} scrolls sideways at #{width}"

    controls = evaluate_script(<<~JS)
      Array.from(document.querySelectorAll(":is(main, .app-actions) :is(#{tappable})")).map((el) => {
        const r = el.getBoundingClientRect();
        return { name: el.className || el.tagName, width: r.width, height: r.height };
      })
    JS
    too_small = controls.select { |c| c["width"] < 44 - tolerance || c["height"] < 44 - tolerance }
    expect(too_small).to be_empty, "#{label} under 44 by 44 at #{width}: #{too_small.map { |c| "#{c['name']} #{c['width'].round(1)}x#{c['height'].round(1)}" }.join(', ')}"
  end

  [ 360, 768 ].each do |width|
    it "has no sideways scroll and no small tap target on any screen at #{width} pixels wide, through a whole round" do
      started = Game.start!(power: "england")
      game = started.game
      id = game.public_id
      france, = game.take_seat!("france")
      france.save_orders!(game.current_phase, { "par" => json_of(rules_order(:hold, :france, :par)) })

      with_viewport(width) do
        visit "/games/#{id}/host-link?token=#{started.host_token}"
        visit "/games/#{id}/seat-link?token=#{started.seat_token}"

        visit "/games/#{id}"
        expect(page).to have_css(".phase-header__title", text: /spring 1901 · movement/i) # the stylesheet draws capitals
        expect(page).to have_text("0 of 3 units ordered")
        measure_screen("the seat page", width)

        click_link "Enter orders"
        expect(page).to have_css(".unit-row", count: 3)
        measure_screen("the orders page", width)

        # The submit bar lives in the sticky action area, inside the viewport.
        sticky = evaluate_script(<<~JS)
          (() => {
            const area = document.querySelector(".app-actions");
            return { position: getComputedStyle(area).position, bottom: area.getBoundingClientRect().bottom, height: window.innerHeight,
                     buttons: Array.from(area.querySelectorAll("button")).map((b) => b.textContent.replace(/\\s+/g, " ").trim()) };
          })()
        JS
        expect(sticky["position"]).to eq("sticky")
        expect(sticky["bottom"]).to be <= sticky["height"] + tolerance
        expect(sticky["buttons"]).to eq([ "Submit orders 0 of 3 ordered" ])

        click_link "Fleet in London"
        click_link "Move"
        click_button "North Sea"
        expect(page).to have_css(".unit-row__order", text: "Move to North Sea (NTH)")
        click_button "Submit orders"
        expect(page).to have_css(".banner--info", text: "Submitted.")
        expect(page).to have_text("1 of 3 ordered")
        measure_screen("the orders page after submitting", width)

        visit "/games/#{id}/host"
        expect(page).to have_css(".phase-header__title", text: /spring 1901 · movement/i) # the stylesheet draws capitals
        expect(page).to have_link("Reveal orders")
        measure_screen("the host page", width)

        click_link "Reveal orders"
        expect(page).to have_css(".confirm")
        expect(page).to have_text(/their unordered units will hold/i)
        measure_screen("the reveal confirmation page", width)

        click_button "Reveal orders"
        expect(page).to have_css(".banner--info", text: "was revealed. It is now Fall 1901 · Movement.")
        measure_screen("the host page after the reveal", width)

        visit "/games/#{id}/phases/1/orders"
        expect(page).to have_css(".banner--danger", text: "The host has already revealed this phase")
        measure_screen("the refusal page", width)

        # A reveal the gem refuses leaves the phase open and says so.
        allow(RulesEngine).to receive(:adjudicate).and_raise(RulesEngine::InvalidInput, "refused")
        visit "/games/#{id}/host/phases/2/reveal"
        click_button "Reveal orders"
        expect(page).to have_css(".banner--danger", text: "Nothing was changed. The phase is still open.")
        measure_screen("the reveal-failed page", width)
        expect(game.reload.current_phase.number).to eq(2)
      end
    end
  end
end

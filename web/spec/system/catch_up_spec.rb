require "rails_helper"
require_relative "../support/results_fixtures"

# Spec 024 Story 9 (AC-9.6): a phone whose socket was cut off while the state changed is caught up when the socket comes back.
# England's browser is the page under test. The consumer is closed and reopened from the test alone, so no hook is added to the app's
# JavaScript; what changes in the meantime is changed on the server side (France's submit through the model, the reveal through the
# host's own confirmation page in a second session). The test cable adapter delivers inside this process.
RSpec.describe "Catching up after a disconnect", type: :system do
  include ResultsFixtures

  let(:started) { Game.start!(power: "germany") }
  let(:game) { started.game }
  let(:id) { game.public_id }
  let!(:england) { game.take_seat!("england") } # [seat, token]
  let!(:france) { game.take_seat!("france").first }

  before { england.first.save_orders!(game.current_phase, { "lon" => json_of(move(:england, :lon, :nth)) }, submit: true) }

  def state_of(power) = find("#seat-status [data-power='#{power}'] .seat-status__state").text

  # Closes or reopens the page's Action Cable consumer, through the module turbo-rails exports.
  def socket(action)
    page.evaluate_async_script(<<~JS, action)
      const [action, done] = [arguments[0], arguments[arguments.length - 1]]
      import("@hotwired/turbo-rails").then(({ cable }) => cable.getConsumer()).then((consumer) => { consumer[action](); done(true) })
    JS
  end

  # Counts the stream messages this page has rendered (after each is applied), so "nothing arrived" and "a snapshot arrived and
  # changed nothing" are different things to the test.
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

  it "is sent a snapshot on reconnecting that changes nothing when nothing was missed (AC-9.6)" do
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
      next_title = game.phases.find_by(number: 2).title

      expect(find(".phase-header__title").text).to eq(first_title) # still the old page: it was not listening
      socket("connect")
      expect(page).to have_css(".phase-header__title", text: /#{Regexp.escape(next_title)}/i, wait: 10) # the stylesheet upper-cases it
      expect(page).to have_css("section[data-results] .result-row", text: "Move to North Sea (NTH)")
    end
  end
end

require "rails_helper"

# Spec 024 Story 6: two real browsers at 360 pixels. The test cable adapter delivers inside this process, so a message
# sent by one session's request reaches the other session's open page.
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

  def england_submits(game, token)
    Capybara.using_session(:england) do
      with_viewport(360) do
        visit "/games/#{game.public_id}/seat-link?token=#{token}"
        visit "/games/#{game.public_id}/phases/1/orders"
        click_on "Submit orders"
        expect(page).to have_css(".banner--info", text: "Submitted.")
      end
    end
  end

  let(:started) { Game.start!(power: "germany") }
  let(:game) { started.game }
  let!(:england) { game.take_seat!("england") }

  it "shows the host England's submit and England's change of mind without a reload (AC-6.1)" do
    with_viewport(360) do
      visit "/games/#{game.public_id}/host-link?token=#{started.host_token}"
      expect(page).to have_css("h1", text: "Your game")
      expect(page).to have_css("turbo-cable-stream-source[connected]", count: 2, visible: :all) # subscribed: Turbo sets this once the socket confirms
      expect(state_of("england")).to eq("Not submitted")
      measure("the host page")
      screenshot("01-host-before")

      england_submits(game, england.last)

      expect(page).to have_css("#seat-status [data-power='england'] .seat-status__state", text: "Submitted", wait: 5)
      expect(state_of("germany")).to eq("Not submitted")
      measure("the host page, England submitted")
      screenshot("02-host-england-submitted")

      Capybara.using_session(:england) do
        with_viewport(360) do
          click_on "Fleet in London"
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
      expect(page).to have_css("turbo-cable-stream-source[connected]", count: 2, visible: :all)
      expect(state_of("england")).to eq("Not submitted")
      measure("the seat page")
      screenshot("03-seat-page")
      click_on "Enter orders"
      expect(page).to have_css("h1", text: "Your orders")

      england_submits(game, england.last)

      page.go_back
      expect(page).to have_css("#seat-status [data-power='england'] .seat-status__state", text: "Submitted", wait: 5)
      screenshot("04-seat-page-after-back")
    end
  end
end

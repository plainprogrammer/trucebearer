require "rails_helper"

# Spec 028 Stories 6 and 7: leaving and resuming in real browsers, at 360 pixels. SCREENSHOTS=<dir> also writes the screenshots of AC-6.4.
RSpec.describe "Resuming a game", type: :system do
  around do |example|
    original = ENV["TRUCEBEARER_PASSPHRASE"]
    ENV["TRUCEBEARER_PASSPHRASE"] = "open sesame"
    example.run
  ensure
    ENV["TRUCEBEARER_PASSPHRASE"] = original
  end

  def screenshot(name)
    dir = ENV["SCREENSHOTS"]
    page.save_screenshot(File.join(dir, "#{name}.png")) if dir
  end

  # What a real browser does when it restarts: cookies with no expiry (Rails' session cookie, a step-in) go; the persistent ones stay.
  def end_browser_session
    manager = page.driver.browser.manage
    manager.all_cookies.select { |cookie| cookie[:expires].nil? }.each { |cookie| manager.delete_cookie(cookie[:name]) }
  end

  def no_sideways_scroll
    widths = evaluate_script("({ scroll: document.documentElement.scrollWidth, client: document.documentElement.clientWidth })")
    expect(widths["scroll"]).to be <= widths["client"]
  end

  def cards_at_least_44
    small = evaluate_script(<<~JS)
      Array.from(document.querySelectorAll("a.game-card")).filter((el) => {
        const r = el.getBoundingClientRect(); return r.height < 43.5 || r.width < 43.5;
      }).length
    JS
    expect(small).to eq(0)
  end

  def create_game_and_join_as_france
    visit "/games/new"
    fill_in "Passphrase", with: "open sesame"
    click_button "England"
    host_link = find("#host-link").value
    join_code = find(".join-code").text.delete(" ")
    using_session(:player) do
      visit "/join"
      fill_in "Game code", with: join_code
      click_button "Join"
      click_button "France"
      expect(page).to have_css("h1", text: "You hold France")
    end
    [ host_link, join_code ]
  end

  it "brings a player back to the current phase after the browser was closed (AC-7.1, AC-7.2)" do
    with_viewport(360) { create_game_and_join_as_france }
    game = Game.order(:id).last
    title = ->(phase) { /#{Regexp.escape(phase.title)}/i } # the page draws the title in capitals
    first_title = title.call(game.current_phase)

    using_session(:player) do
      with_viewport(360) do
        end_browser_session
        visit "/"
        expect(page).to have_css("a.game-card", count: 1)
        expect(page).to have_css("a.game-card", text: first_title)
        no_sideways_scroll
        cards_at_least_44
        click_link(class: "game-card")
        expect(page).to have_css("h1", text: "You hold France")
      end
    end

    game.current_phase.reveal!

    using_session(:player) do
      with_viewport(360) do
        end_browser_session
        visit "/"
        expect(page).to have_css("a.game-card", text: title.call(game.reload.current_phase))
        click_link(class: "game-card")
        expect(page).to have_css("h1", text: "You hold France")
        expect(page).to have_text(title.call(game.current_phase))
      end
    end
  end

  it "opens the host link in a fresh browser, and the host can take the seat back by reissuing it (AC-7.3)" do
    host_link = nil
    with_viewport(360) { host_link, = create_game_and_join_as_france }
    id = Game.order(:id).last.public_id

    using_session(:spare) do
      with_viewport(360) do
        visit host_link
        expect(page).to have_link("Reveal orders")
        visit "/"
        expect(page).to have_css("a.game-card[href='/games/#{id}/host']", text: "You host this game")

        visit "/games/#{id}/host"
        find("a[href$='/host/seats/england/reissue']").click
        click_button "Reissue seat"
        seat_link = find(".qr-card__link").text
        visit seat_link
        expect(page).to have_css("h1", text: "You hold England")
        expect(page).to have_link("Host controls")
        visit "/"
        expect(page).to have_css("a.game-card[href='/games/#{id}']")
      end
    end
  end

  it "tells a player whose cookie is gone what to do, and the reissued seat brings them back (AC-7.4)" do
    with_viewport(360) { create_game_and_join_as_france }
    id = Game.order(:id).last.public_id
    seat_link = nil

    using_session(:lost) do
      with_viewport(360) do
        visit "/"
        expect(page).to have_no_css("a.game-card")
        expect(page).to have_text("Lost your seat? Ask the host for a new QR code.")
        no_sideways_scroll
      end
    end

    with_viewport(360) do
      visit "/games/#{id}/host"
      find("a[href$='/host/seats/france/reissue']").click
      click_button "Reissue seat"
      seat_link = find(".qr-card__link").text
    end

    using_session(:lost) do
      with_viewport(360) do
        visit seat_link
        expect(page).to have_css("h1", text: "You hold France")
        visit "/"
        expect(page).to have_css("a.game-card[href='/games/#{id}']")
      end
    end
  end

  it "draws three cards, the empty home page and the stranger page at 360 pixels (AC-6.1 to AC-6.4)" do
    seat_game = Game.start!(power: "england")
    _france, france_token = seat_game.game.take_seat!("france")
    host_with_seat = Game.start!(power: "germany")
    host_only = Game.start!(power: "russia")

    with_viewport(360) do
      visit "/"
      expect(page).to have_no_css("a.game-card")
      expect(page).to have_text("Lost your seat? Ask the host for a new QR code.")
      no_sideways_scroll
      screenshot("01-home-empty")

      visit "/games/#{seat_game.game.public_id}/seat-link?token=#{france_token}"
      visit "/games/#{host_with_seat.game.public_id}/host-link?token=#{host_with_seat.host_token}"
      visit "/games/#{host_with_seat.game.public_id}/seat-link?token=#{host_with_seat.seat_token}"
      visit "/games/#{host_only.game.public_id}/host-link?token=#{host_only.host_token}"
      visit "/"

      expect(page).to have_css("a.game-card", count: 3)
      no_sideways_scroll
      cards_at_least_44
      overlap = evaluate_script("Array.from(document.querySelectorAll('.game-card .phase-header')).filter((h) => { const b = h.querySelector('.power-badge'); return b && b.getBoundingClientRect().left < h.querySelector('.phase-header__title').getBoundingClientRect().right - 0.5; }).length")
      expect(overlap).to eq(0)
      below = evaluate_script("document.querySelector('a.button').getBoundingClientRect().top >= Array.from(document.querySelectorAll('a.game-card')).pop().getBoundingClientRect().bottom")
      expect(below).to be(true)
      screenshot("02-home-three-cards")

      visit "/games/zzzzzzzzzzzz"
      expect(page).to have_text("Lost your seat? Ask the host for a new QR code.")
      no_sideways_scroll
      screenshot("03-stranger")
    end
  end
end

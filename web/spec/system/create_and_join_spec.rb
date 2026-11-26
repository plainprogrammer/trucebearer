require "rails_helper"

# Spec 021, Story 10: a game is created and joined in real browsers, each session with its own cookies.
RSpec.describe "Creating a game and joining it", type: :system do
  around do |example|
    original = ENV["TRUCEBEARER_PASSPHRASE"]
    ENV["TRUCEBEARER_PASSPHRASE"] = "open sesame"
    example.run
  ensure
    ENV["TRUCEBEARER_PASSPHRASE"] = original
  end

  def no_sideways_scroll
    widths = evaluate_script("({ scroll: document.documentElement.scrollWidth, client: document.documentElement.clientWidth })")
    expect(widths["scroll"]).to be <= widths["client"]
  end

  it "lets a host create a game at 360 pixels and a second phone join it by code (AC-10.1 to 10.4)" do
    join_code = nil

    with_viewport(360) do
      visit "/games/new"
      no_sideways_scroll
      fill_in "Passphrase", with: "open sesame"
      click_button "England"

      expect(page).to have_css(".qr-card svg[role=img]")
      expect(page).to have_css("#host-link")
      join_code = find(".join-code").text.delete(" ")
      expect(join_code).to match(JoinCode::SHAPE)
      no_sideways_scroll
    end

    using_session(:player) do
      with_viewport(360) do
        visit "/join"
        no_sideways_scroll
        fill_in "Game code", with: join_code.downcase
        click_button "Join"

        expect(page).to have_css(".power-tile--taken", text: "England")
        expect(page).to have_css("button.power-tile", count: 6)
        no_sideways_scroll
        click_button "France"

        expect(page).to have_css("h1", text: "You hold France")
        no_sideways_scroll
      end
    end

    with_viewport(360) do
      visit current_path # the host reloads
      expect(page).to have_css(".list__row", text: "Reissue seat", count: 2)
      expect(page).to have_css(".list__row", text: "Open", count: 5)

      click_link "Close joining"
      click_button "Close joining"
      expect(page).to have_text("Joining is closed.")
      no_sideways_scroll
    end

    using_session(:third) do
      with_viewport(360) do
        visit "/join"
        fill_in "Game code", with: join_code
        click_button "Join"

        expect(page).to have_text("That code doesn't match a game that is open for joining.")
        no_sideways_scroll
      end
    end
  end

  it "reissues a seat and the old phone loses it (AC-7.5, 7.6)" do
    join_code = nil
    seat_link = nil

    with_viewport(360) do
      visit "/games/new"
      fill_in "Passphrase", with: "open sesame"
      click_button "England"
      join_code = find(".join-code").text.delete(" ")
    end

    using_session(:player) do
      with_viewport(360) do
        visit "/join"
        fill_in "Game code", with: join_code
        click_button "Join"
        click_button "France"
        expect(page).to have_css("h1", text: "You hold France")
      end
    end

    with_viewport(360) do
      visit current_path
      find("a.list__row", text: "France").click
      click_button "Reissue seat"
      expect(page).to have_css(".qr-card__link")
      seat_link = find(".qr-card__link").text
    end

    using_session(:replacement) do
      with_viewport(360) do
        visit seat_link
        expect(page).to have_css("h1", text: "You hold France")
      end
    end

    using_session(:player) do
      with_viewport(360) do
        page.refresh
        expect(page).to have_text("We can't find that page.")
      end
    end
  end
end

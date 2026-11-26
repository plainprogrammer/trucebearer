require "rails_helper"

# Spec 021, AC-9.2 and AC-10.4: every screen the feature adds, at phone width and at 768 pixels, has no sideways
# scroll and no tappable control under 44 by 44 CSS pixels. Geometry is read in the page, as in the style guide spec.
RSpec.describe "Screens of creating and joining a game", type: :system do
  around do |example|
    original = ENV["TRUCEBEARER_PASSPHRASE"]
    ENV["TRUCEBEARER_PASSPHRASE"] = "open sesame"
    example.run
  ensure
    ENV["TRUCEBEARER_PASSPHRASE"] = original
  end

  # A link inside a paragraph is running text and exempt; every other link on these screens is a .button or a .list__row.
  def tappable = "a:not(p a), button, input:not([type=hidden]), select, .power-tile:not(.power-tile--taken)"

  # Chrome reports sub-pixel sizes; the style guide spec allows half a pixel too.
  def tolerance = 0.5

  # Visits the path, checks it reached its screen, then measures it. Pass a block to assert what the screen is.
  def check_screen(path, width)
    visit path
    yield if block_given?
    measure_screen(path, width)
  end

  def measure_screen(label, width)
    expect(evaluate_script("window.innerWidth")).to eq(width)
    expect(page).to have_css("h1")

    widths = evaluate_script("({ scroll: document.documentElement.scrollWidth, client: document.documentElement.clientWidth })")
    expect(widths["scroll"]).to be <= widths["client"], "#{label} scrolls sideways at #{width}"

    controls = evaluate_script(<<~JS)
      Array.from(document.querySelectorAll("main :is(#{tappable})")).map((el) => {
        const r = el.getBoundingClientRect();
        return { name: el.className || el.tagName, width: r.width, height: r.height };
      })
    JS
    too_small = controls.select { |c| c["width"] < 44 - tolerance || c["height"] < 44 - tolerance }
    expect(too_small).to be_empty, "#{label} under 44 by 44 at #{width}: #{too_small.map { |c| "#{c['name']} #{c['width'].round(1)}x#{c['height'].round(1)}" }.join(', ')}"
  end

  [ 360, 768 ].each do |width|
    it "has no sideways scroll and no small tap target on any screen at #{width} pixels wide" do
      started = Game.start!(power: "england")
      game = started.game
      id = game.public_id
      code = game.join_code

      with_viewport(width) do
        # Signed out, in a fresh session: each visit must reach the screen it names.
        check_screen("/", width) { expect(page).to have_link("Create a game") }
        check_screen("/games/new", width) { expect(page).to have_field("Passphrase") }

        original = ENV.delete("TRUCEBEARER_PASSPHRASE")
        begin
          check_screen("/games/new", width) { expect(page).to have_text("turned off") }
        ensure
          ENV["TRUCEBEARER_PASSPHRASE"] = original
        end

        check_screen("/join", width) { expect(page).to have_field("Game code") }
        check_screen("/join/#{code}", width) { expect(page).to have_css("button.power-tile") }
        check_screen("/join/ZZZZZZ", width) { expect(page).to have_text(JoinsController::NOT_OPEN) }
        check_screen("/games/#{id}", width) { expect(page).to have_text("We can't find that page.") }
        check_screen("/games/#{id}/host", width) { expect(page).to have_text("We can't find that page.") }

        # The rate limit page: more than 30 lookups in a minute.
        31.times { visit "/join/#{code}" }
        expect(page).to have_text("Too many tries")
        measure_screen("the too-many-tries page", width)

        # Signed in: a host link and a seat link, as the host's phone and a seat holder's phone would use them.
        visit "/games/#{id}/host-link?token=#{started.host_token}"
        expect(page).to have_css("h1", text: "Your game")
        visit "/games/#{id}/seat-link?token=#{started.seat_token}"

        check_screen("/games/#{id}", width) { expect(page).to have_css("h1", text: "You hold") }
        check_screen("/games/#{id}/host", width) { expect(page).to have_css("h1", text: "Your game") }
        check_screen("/games/#{id}/host/close", width) { expect(page).to have_css("h1", text: "Close joining") }
        check_screen("/games/#{id}/host/seats/england/reissue", width) { expect(page).to have_css("h1", text: "Reissue") }

        # The new seat code is shown once, and only after posting the reissue form.
        click_button "Reissue seat"
        expect(page).to have_css(".qr-card svg[role=img]")
        measure_screen("the new seat code", width)

        # A reload finds no code and goes back to the host page with a note.
        visit current_path
        expect(page).to have_css("[role=status]", text: "shown once")
        measure_screen("the host page with a note", width)

        # A wrong passphrase shows the form again with a message, and a right one shows the host page with its link.
        visit "/games/new"
        fill_in "Passphrase", with: "wrong"
        click_button "France"
        expect(page).to have_css("[role=alert]", text: "That passphrase isn't right.")
        measure_screen("the create form with an error", width)

        fill_in "Passphrase", with: "open sesame"
        click_button "France"
        expect(page).to have_css("#host-link")
        measure_screen("the host page with its link", width)
      end
    end
  end
end

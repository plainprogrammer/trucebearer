require "rails_helper"
require_relative "../support/rules_helpers"

# Spec 026 Stories 2 to 5: the host confirms, is recorded, acts as the seat through the one order screen and the one save path,
# sees the bar on every page, and the step-in ends.
RSpec.describe "Stepping into a seat", type: :request do
  include RulesHelpers

  around { |example| with_passphrase { example.run } }

  let(:created) { create_game(power: "germany") } # the host holds Germany
  let(:game) { created.game }
  let(:id) { game.public_id }
  let!(:england_and_token) { game.take_seat!("england") }
  let!(:france_and_token) { game.take_seat!("france") }
  let(:england) { england_and_token.first }
  let(:france) { france_and_token.first }
  let(:host) { created.session }

  def hold(power, at) = json_of(rules_order(:hold, power, at))

  def confirm(power = "france", number = 1, session: host) = session.post("/games/#{id}/host/seats/#{power}/phases/#{number}/step-in")

  def screen(power = "france", number = 1) = "/games/#{id}/host/seats/#{power}/phases/#{number}/orders"

  def page(session = host) = Nokogiri::HTML5(session.response.body)

  def expect_stranger(session = host, why = nil)
    expect(session.response).to have_http_status(:not_found), why
    expect(page(session).at_css("h1").text).to eq("We can't find that page."), why
    expect(page(session).css(".banner--warning")).to be_empty, why
  end

  def france_phone
    open_session.tap { |phone| phone.get "/games/#{id}/seat-link", params: { token: france_and_token.last } }
  end

  before { france.save_orders!(game.current_phase, { "par" => hold(:france, :par) }) }

  describe "confirming (Story 2)" do
    it "writes one row, sets the cookie and goes to the stepped-in order screen (AC-2.1)" do
      expect { confirm }.to change(StepIn, :count).by(1)

      row = StepIn.last
      expect([ row.seat, row.phase ]).to eq([ france, game.current_phase ])
      expect(host.response).to have_http_status(:see_other)
      expect(URI(host.response.location).path).to eq(screen)
      line = cookie_line(host.response, "step_in_#{id}")
      expect(line).to match(/httponly/i)
      expect(line).to match(/samesite=lax/i)
      expect(line).not_to match(/expires/i)
    end

    it "shows nothing of France's orders, and writes nothing, before the host has confirmed (AC-2.2)" do
      host.get screen
      expect_stranger(host, "the screen")
      host.get "#{screen}/par"
      expect_stranger(host, "the picker")
      expect { host.put screen, params: { orders: { "par" => hold(:france, :par) } } }.not_to change { [ StepIn.count, SavedOrder.count ] }
      expect_stranger(host, "the endpoint")
      expect(host.response.body).not_to include("Army in Paris")
      expect(host.response.body).not_to include("Hold")
    end

    it "shows France's own orders once the host has confirmed (AC-2.3)" do
      confirm
      host.get screen

      expect(host.response).to have_http_status(:ok)
      rows = page.css(".unit-row__body").map { |row| row.text.squish }
      expect(rows).to include("Army in Paris (PAR) Hold")
      expect(page.at_css(".phase-header .power-badge").text).to eq("France")
    end

    it "never carries a token in the cookie, and leaves France's own phone working (AC-2.4)" do
      confirm
      line = cookie_line(host.response, "step_in_#{id}")

      expect(line).not_to include(france_and_token.last)
      expect(line).not_to include(france.token_digest)
      phone = france_phone
      phone.get "/games/#{id}/phases/1/orders"
      expect(phone.response).to have_http_status(:ok)
      phone.put "/games/#{id}/phases/1/orders", params: { orders: { "mar" => hold(:france, :mar) } }
      expect(phone.response).to have_http_status(:see_other)
    end

    it "makes a second row for a second confirmation (AC-2.5)" do
      expect { 2.times { confirm } }.to change(StepIn, :count).by(2)
    end

    it "makes England's seat the only one in reach after England's confirmation (AC-2.6)" do
      confirm
      confirm("england")

      host.get screen("france")
      expect_stranger(host, "France")
      host.get screen("england")
      expect(host.response).to have_http_status(:ok)
    end

    it "gives a seat's phone, a stranger and another game's host the stranger response on the POST, and writes nothing (AC-1.4)" do
      other_host = create_game(power: "england").session
      expect { [ france_phone, open_session, other_host ].each { |session| confirm("france", 1, session: session) } }.not_to change(StepIn, :count)
      [ france_phone, open_session, other_host ].each do |session|
        confirm("france", 1, session: session)
        expect_stranger(session)
      end
    end

    it "redirects a revealed number on the POST to the open phase's confirmation and writes nothing (AC-1.7)" do
      game.current_phase.reveal!

      expect { confirm }.not_to change(StepIn, :count)
      expect(host.response).to have_http_status(:see_other)
      expect(URI(host.response.location).path).to eq("/games/#{id}/host/seats/france/phases/2/step-in")
    end
  end

  describe "the bar and the own screens (Story 3)" do
    before { confirm }

    it "names the power on the stepped-in screen and picker, with Leave (AC-3.1)" do
      [ screen, "#{screen}/par" ].each do |path|
        host.get path
        banner = page.at_css(".banner--warning")
        expect(banner.text).to include("Acting as France"), path
        form = page.at_css("form[action='/games/#{id}/host/seats/france/step-in']")
        expect(form.at_css("input[name=_method][value=delete]")).to be_present, path
        expect(form.at_css("button").text).to eq("Leave France's seat"), path
      end
    end

    it "marks every other game page as still stepped in, with a way back to France's orders (AC-3.2)" do
      [ "/games/#{id}", "/games/#{id}/host", "/games/#{id}/host/phases/1/reveal", "/games/#{id}/host/close",
        "/games/#{id}/host/seats/england/reissue" ].each do |path|
        host.get path
        expect(host.response).to have_http_status(:ok), path
        expect(page.at_css(".banner--warning").text).to include("Still stepped into France's seat."), path
        expect(page.css("a").map { |a| [ a.text, a["href"] ] }).to include([ "France's orders", screen ]), path
        expect(page.at_css("form[action='/games/#{id}/host/seats/france/step-in'] button").text).to eq("Leave France's seat"), path
      end
    end

    it "keeps the host's own orders URLs the host's own, query or not (AC-3.6)" do
      [ "", "?power=france" ].each do |query|
        host.get "/games/#{id}/phases/1/orders#{query}"
        expect(page.at_css("h1").text).to eq("Your orders")
        expect(page.at_css(".phase-header .power-badge").text).to eq("Germany")
        expect(page.css(".unit-row__body").map { |row| row.text.squish }.join).not_to include("Paris")
      end
    end

    it "keeps the host's own seat as the main screen and the host controls in their own section (AC-3.7)" do
      host.get "/games/#{id}"
      expect(page.at_css("h1").text).to eq("You hold Germany")
      expect(page.css(".host-section a").map(&:text)).to eq([ "Host controls" ])
      expect(host.response.body).not_to include("Reveal orders")

      host.delete "/games/#{id}/host/seats/france/step-in"
      host.follow_redirect!
      expect(page.at_css("h1").text).to eq("You hold Germany")
    end

    it "leaves no bar on a stranger page, and sets and deletes no step-in cookie (AC-3.8)" do
      paths = [ "/games/#{id}/phases/1/orders/xyz", "/games/#{id}/phases/9/orders" ]
      host.delete "/games/#{id}/host/seats/france/step-in"
      without = paths.map { |path| host.get(path) && comparable(host.response, id) }
      confirm
      paths.zip(without).each do |path, expected|
        host.get path
        expect(comparable(host.response, id)).to eq(expected), path
        expect(cookie_lines(host.response).grep(/step_in_/)).to be_empty
        expect(page.css(".banner--warning")).to be_empty
      end
    end

    it "has no bar on the 409 page, and its link follows the stepped-in URLs (AC-3.8)" do
      game.current_phase.reveal!
      confirm("france", 2)
      host.get screen("france", 1)

      expect(host.response).to have_http_status(:conflict)
      expect(page.at_css("h1").text).to eq("France's orders")
      expect(page.css(".banner--warning")).to be_empty
      expect(page.css("a").map { |a| [ a.text, a["href"] ] }).to include([ "Go to the current phase", screen("france", 2) ])
    end

    it "has no bar before confirming, after Leave or after a reveal (AC-3.3)" do
      host.delete "/games/#{id}/host/seats/france/step-in"
      host.get "/games/#{id}/host"
      expect(page.css(".banner--warning").map(&:text).join).not_to match(/stepped|Acting/)

      fresh = create_game(power: "germany")
      fresh.session.get "/games/#{fresh.game.public_id}/host"
      expect(Nokogiri::HTML5(fresh.session.response.body).css(".banner--warning").map(&:text).join).not_to match(/stepped|Acting/)
    end

    it "ends this browser's step-in with Leave, and a second Leave is harmless (AC-3.5)" do
      host.delete "/games/#{id}/host/seats/france/step-in"
      expect(host.response).to have_http_status(:see_other)
      expect(URI(host.response.location).path).to eq("/games/#{id}")
      host.delete "/games/#{id}/host/seats/france/step-in"
      expect(host.response).to have_http_status(:see_other)
      host.get screen
      expect_stranger
      open_session.tap { |session| session.delete "/games/#{id}/host/seats/france/step-in" }.then { |session| expect_stranger(session) }
    end

    it "sends the stepped-in screen's cache and referrer headers, as the player's (AC-8.6)" do
      [ screen, "#{screen}/par" ].each do |path|
        host.get path
        expect(host.response.headers["Cache-Control"]).to include("no-store"), path
        expect(host.response.headers["Referrer-Policy"]).to eq("no-referrer"), path
        expect(page.at_css("meta[name=turbo-cache-control]")["content"]).to eq("no-cache"), path
      end
    end
  end

  describe "saving as the seat (Story 4)" do
    before { confirm }

    it "saves through the endpoint for France's seat, and France's phone sees it (AC-4.1)" do
      host.put screen, params: { orders: { "mar" => hold(:france, :mar) } }

      expect(host.response).to have_http_status(:see_other)
      expect(URI(host.response.location).path).to eq(screen)
      expect(france.orders_for(game.current_phase).keys).to match_array(%w[mar par])
      phone = france_phone
      phone.get "/games/#{id}/phases/1/orders"
      expect(Nokogiri::HTML5(phone.response.body).css(".unit-row__body").map { |row| row.text.squish }).to include("Army in Marseilles (MAR) Hold")
    end

    it "refuses what spec 022 refuses and stores nothing (AC-4.2)" do
      before = SavedOrder.count
      host.put screen, params: { orders: { "lon" => hold(:england, :lon) } }
      expect(host.response).to have_http_status(:unprocessable_content)
      expect(page.at_css(".banner--danger").text).to include("You have no unit in LON.")
      host.put screen, params: { orders: { "par" => json_of(move(:france, :par, :mun)) } }
      expect(page.at_css(".banner--danger").text).to include("can't reach there")
      host.put screen, params: { orders: { "par" => "not an order" } }
      expect(page.at_css(".banner--danger").text).to include("That order couldn't be read.")
      expect(SavedOrder.count).to eq(before)
    end

    it "marks France submitted, and a changed order marks it not submitted again (AC-4.3)" do
      host.put screen, params: { submit: "1" }
      expect(france.submitted?(game.current_phase)).to be(true)
      host.put screen, params: { orders: { "par" => json_of(move(:france, :par, :bur)) } }
      expect(france.submitted?(game.current_phase)).to be(false)
    end

    it "refuses a save through another seat's stepped-in URL, and stores nothing there (AC-4.5)" do
      expect { host.put screen("england"), params: { orders: { "lon" => hold(:england, :lon) } } }.not_to change(SavedOrder, :count)
      expect_stranger
    end

    it "says whose orders they are, and keeps every link on the stepped-in URLs (AC-4.6)" do
      host.get screen
      expect(page.at_css("h1").text).to eq("France's orders")
      host.put screen, params: { submit: "1" }
      host.get screen
      expect(page.css(".app-actions a").map { |a| [ a.text, a["href"] ] }).to eq([ [ "Your own seat", "/games/#{id}" ] ])

      host.get "#{screen}/par"
      links = page.css("main a[href], main form[action], .app-actions a[href]").map { |node| node["href"] || node["action"] }
      links.each { |link| expect(link).to start_with("/games/#{id}/host/seats/france/"), link }
      expect(links.size).to be > 2
    end
  end

  describe "ending (Story 5)" do
    before { confirm }

    it "ends at the reveal, and the next phase needs a new confirmation and a new row (AC-5.1, AC-5.4)" do
      game.current_phase.reveal!

      host.get screen("france", 2)
      expect_stranger
      host.get "/games/#{id}/host"
      expect(page.css(".banner--warning")).to be_empty
      expect { confirm("france", 2) }.to change(StepIn, :count).by(1)
      expect(StepIn.last.phase.number).to eq(2)
      host.get screen("france", 2)
      expect(host.response).to have_http_status(:ok)
    end

    it "works at 29 minutes and not at 31 (AC-5.2)" do
      travel(29.minutes) { host.get screen }
      expect(host.response).to have_http_status(:ok)
      travel(31.minutes) do
        host.get screen
        expect_stranger
        host.get "/games/#{id}/host"
        expect(page.css(".banner--warning")).to be_empty
      end
    end

    it "ignores a cookie that is forged, of another name, of another seat's row, missing its row or without the host cookie (AC-5.3)" do
      host.cookies["step_in_#{id}"] = "garbage"
      host.get screen
      expect_stranger(host, "garbage")

      other = create_game(power: "germany")
      other.game.take_seat!("france")
      confirm("france", 1, session: other.session)
      host.cookies["step_in_#{id}"] = other.session.cookies["step_in_#{other.game.public_id}"]
      host.get screen
      expect_stranger(host, "another game's cookie")

      host.cookies["step_in_#{id}"] = nil
      confirm
      host.get screen("england")
      expect_stranger(host, "another seat's URL")

      StepIn.delete_all
      host.get screen
      expect_stranger(host, "a missing row")

      confirm
      no_host = open_session
      no_host.cookies["step_in_#{id}"] = host.cookies["step_in_#{id}"]
      no_host.get screen
      expect_stranger(no_host, "no host cookie")
    end

    it "ignores a correctly signed cookie that names a row of another game (AC-5.3)" do
      other = Game.start!(power: "germany").game
      row = StepIn.record!(phase: other.current_phase, seat: other.take_seat!("france").first)
      host_only = open_session.tap { |session| session.get "/games/#{id}/host-link", params: { token: created.host_token } }
      allow_any_instance_of(ActionDispatch::Cookies::CookieJar).to receive(:signed)
        .and_return("host_#{id}" => created.host_token, "step_in_#{id}" => row.id)

      host_only.get screen
      expect(host_only.response).to have_http_status(:not_found)
    end
  end
end

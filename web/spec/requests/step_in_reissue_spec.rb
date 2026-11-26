require "rails_helper"
require_relative "../support/rules_helpers"

# Spec 026 Story 7 (D5): a reissued seat link opened on a browser that holds the host cookie is a step-in, never a quiet takeover.
RSpec.describe "The reissue gap", type: :request do
  include RulesHelpers

  around { |example| with_passphrase { example.run } }

  let(:created) { create_game(power: "germany") } # the host holds Germany
  let(:game) { created.game }
  let(:id) { game.public_id }
  let!(:france_and_token) { game.take_seat!("france") }
  let!(:england_and_token) { game.take_seat!("england") }
  let(:france) { france_and_token.first }
  let(:host) { created.session }
  let(:confirmation) { "/games/#{id}/host/seats/france/phases/1/step-in" }

  def hold(power, at) = json_of(rules_order(:hold, power, at))

  def page(session = host) = Nokogiri::HTML5(session.response.body)

  # The host reissues the seat; returns the new link's path and query as the QR page shows it.
  def reissue(power)
    host.post "/games/#{id}/host/seats/#{power}/reissue"
    host.follow_redirect!
    page.at_css(".qr-card__link").text.delete_prefix("http://www.example.com")
  end

  def location_path(session = host) = URI(session.response.location).path

  before { france.save_orders!(game.current_phase, { "par" => hold(:france, :par) }) }

  it "sends the host to France's confirmation and stores no seat cookie, the host's own seat cookie untouched (AC-7.1)" do
    link = reissue("france")
    own_seat_cookie = host.cookies["seat_#{id}"]

    host.get link

    expect(host.response).to have_http_status(:found)
    expect(location_path).to eq(confirmation)
    expect(cookie_lines(host.response).grep(/\Aseat_/)).to be_empty
    expect(host.cookies["seat_#{id}"]).to eq(own_seat_cookie)
    expect(StepIn.count).to eq(0)
    host.get "/games/#{id}"
    expect(page.at_css("h1").text).to eq("You hold Germany")
    host.get confirmation
    expect(page.at_css(".confirm h1").text).to include("France")
    expect(host.response.body).not_to include("Hold")
  end

  it "is an ordinary step-in once confirmed, and the new token is stored nowhere (AC-7.2)" do
    link = reissue("france")
    token = link[/token=([^&]+)/, 1]
    host.get link
    host.post confirmation

    expect(StepIn.count).to eq(1)
    expect(host.cookies.to_hash.values.join).not_to include(token)
    host.get "/games/#{id}/host/seats/france/phases/1/orders"
    expect(host.response).to have_http_status(:ok)
    expect(page.at_css(".banner--warning").text).to include("Acting as France")
  end

  it "sets the seat cookie as before when the host reopens their own reissued seat (AC-7.3)" do
    link = reissue("germany")
    before = host.cookies["seat_#{id}"]

    host.get link

    expect(location_path).to eq("/games/#{id}")
    expect(host.cookies["seat_#{id}"]).not_to eq(before)
    host.get "/games/#{id}"
    expect(page.at_css("h1").text).to eq("You hold Germany")
    expect(StepIn.count).to eq(0)
  end

  it "makes a phone with no host cookie the seat's new holder, as before (AC-7.4)" do
    link = reissue("france")
    phone = open_session

    phone.get link

    expect(location_path(phone)).to eq("/games/#{id}")
    expect(cookie_line(phone.response, "seat_#{id}")).to be_present
    expect(StepIn.count).to eq(0)
  end

  describe "a browser that holds the host cookie and another seat's cookie (AC-7.5)" do
    let(:browser) do
      open_session.tap do |session|
        session.get "/games/#{id}/seat-link", params: { token: france_and_token.last }
        session.get "/games/#{id}/host-link", params: { token: created.host_token }
      end
    end
    let!(:saved) { browser.cookies["seat_#{id}"] }

    def request_as_wearing_france(verb, path, **options)
      browser.cookies["seat_#{id}"] = saved # the redirect deletes the cookie, so each request is made with it again
      browser.public_send(verb, path, **options)
    end

    it "is sent to France's confirmation from the seat page, the order screen, the picker and the endpoint, and deletes that cookie" do
      [ [ :get, "/games/#{id}" ], [ :get, "/games/#{id}/phases/1/orders" ], [ :get, "/games/#{id}/phases/1/orders/par" ],
        [ :put, "/games/#{id}/phases/1/orders" ] ].each do |verb, path|
        options = verb == :put ? { params: { orders: { "mar" => hold(:france, :mar) } } } : {}
        request_as_wearing_france(verb, path, **options)

        expect(browser.response).to have_http_status(:see_other), path
        expect(location_path(browser)).to eq(confirmation), path
        expect(cookie_line(browser.response, "seat_#{id}")).to match(/\Aseat_#{id}=;|max-age=0|expires=Thu, 01 Jan 1970/i), path
        expect(browser.response.body).not_to include("Hold"), path
      end
      expect(france.orders_for(game.current_phase).keys).to eq([ "par" ])
      expect(StepIn.count).to eq(0)
    end

    it "is an ordinary step-in after confirming" do
      request_as_wearing_france(:get, "/games/#{id}")
      browser.post confirmation
      browser.get "/games/#{id}/host/seats/france/phases/1/orders"

      expect(browser.response).to have_http_status(:ok)
      expect(StepIn.count).to eq(1)
    end
  end

  it "answers a wrong, old or malformed token the same with and without the host cookie (AC-7.6)" do
    reissue("france")
    old = france_and_token.last # dead since the reissue
    [ old, Token.generate, "x" ].each do |token|
      host.get "/games/#{id}/seat-link", params: { token: token }
      with_cookie = comparable(host.response, id)
      status = host.response.status
      plain = open_session
      plain.get "/games/#{id}/seat-link", params: { token: token }

      expect(with_cookie).to eq(comparable(plain.response, id)), token
      expect(status).to eq(404)
    end
  end

  it "tells the host on the reissue page that opening the link on their own phone is stepping in (AC-7.7)" do
    host.get "/games/#{id}/host/seats/france/reissue"

    text = page.at_css(".confirm").text.squish
    expect(text).to include("saved orders for this phase are deleted")
    expect(text).to include("counts as stepping into this seat")
  end

  describe "a host browser with no seat of its own (AC-3.9)" do
    it "lands on the host page after Leave and from the submit bar's own-seat link" do
      second_phone = open_session.tap { |session| session.get "/games/#{id}/host-link", params: { token: created.host_token } }
      second_phone.post confirmation
      second_phone.put "/games/#{id}/host/seats/france/phases/1/orders", params: { submit: "1" }
      second_phone.get "/games/#{id}/host/seats/france/phases/1/orders"

      expect(page(second_phone).css(".app-actions a").map { |a| a["href"] }).to eq([ "/games/#{id}/host" ])
      second_phone.delete "/games/#{id}/host/seats/france/step-in"
      expect(location_path(second_phone)).to eq("/games/#{id}/host")
    end
  end

  describe "the host page's way in (AC-1.6)" do
    it "lists each held seat but the host's own, linking to its confirmation, with no order, count or submitted state" do
      france.save_orders!(game.current_phase, {}, submit: true)
      host.get "/games/#{id}/host"

      entry = page.at_css("[data-step-in-entry]")
      expect(entry.css("li a").map { |a| a["href"] }).to eq([ "/games/#{id}/host/seats/england/phases/1/step-in", confirmation ])
      expect(entry.css("li").map { |li| li.css("span").map(&:text) }).to eq([ [ "England", "Step in" ], [ "France", "Step in" ] ])
      expect(page.at_css(".host-section").text).to include("Step into a seat")
      expect(entry.text).not_to match(/ordered|Submitted|\d of \d/)
    end

    it "shows no list when nobody but the host holds a seat" do
      other = create_game(power: "germany")
      other.session.get "/games/#{other.game.public_id}/host"

      expect(Nokogiri::HTML5(other.session.response.body).at_css("[data-step-in-entry]")).to be_nil
    end
  end
end

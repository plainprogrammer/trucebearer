require "rails_helper"

RSpec.describe "Reissuing a seat", type: :request do
  around { |example| with_passphrase { example.run } }

  let(:created) { create_game(power: "england") }
  let(:game) { created.game }
  let(:id) { game.public_id }
  let(:host) { created.session }
  let(:path) { "/games/#{id}/host/seats/france/reissue" }
  let(:qr_path) { "/games/#{id}/host/seats/france/qr" }
  let(:label) { "QR code for this seat" }

  def stranger_page?(response)
    response.status == 404 && response.body.include?("We can't find that page.")
  end

  def digest_of(power) = game.seats.find_by!(power: power).token_digest

  # The France player joins on their own phone. Returns that phone's session and the token it holds.
  def france_joins
    _seat, token = game.take_seat!("france")
    phone = open_session
    phone.get "/games/#{id}/seat-link", params: { token: token }
    [ phone, token ]
  end

  describe "the host page lists the seats (AC-7.1)" do
    it "links taken seats to their reissue page and marks the rest open" do
      game.take_seat!("france")
      host.get "/games/#{id}/host"

      rows = Nokogiri::HTML5(host.response.body).css(".host-section ul.list:not([data-step-in-entry]) > li")
      expect(rows.size).to eq(7)
      expect(rows.css("a").map { |link| link["href"] }).to eq(
        [ "/games/#{id}/host/seats/england/reissue", "/games/#{id}/host/seats/france/reissue" ]
      )
      expect(rows.map { |row| row.text.squish }.count { |text| text.include?("Open") }).to eq(5)
    end
  end

  describe "the confirmation page (AC-7.2)" do
    it "says the old phone loses the seat at once and offers a danger button and a way back" do
      game.take_seat!("france")
      host.get path

      page = Nokogiri::HTML5(host.response.body)
      expect(host.response).to have_http_status(:ok)
      expect(page.css("title").text).to eq("Reissue a seat")
      expect(page.at_css("h1").text).to eq("Reissue France")
      expect(page.text).to include("The phone that holds this seat loses it at once.")
      form = page.at_css("form[action='#{path}']")
      expect(form["method"]).to eq("post")
      expect(form.at_css("button.button.button--danger").text).to eq("Reissue seat")
      back = page.at_css("a.button.button--secondary")
      expect(back.text).to eq("Back")
      expect(back["href"]).to eq("/games/#{id}/host")
      expect(digest_of("france")).to be_present
    end
  end

  describe "reissuing (AC-7.3)" do
    it "replaces the token digest and goes to the QR page" do
      game.take_seat!("france")
      before = digest_of("france")

      host.post path

      expect(host.response).to have_http_status(:found)
      expect(host.response.location).to eq("http://www.example.com#{qr_path}")
      expect(digest_of("france")).not_to eq(before)
    end
  end

  describe "the new QR code (AC-7.4)" do
    it "shows the card once, uncached, and then goes back to the host page" do
      game.take_seat!("france")
      host.post path
      host.follow_redirect!

      page = Nokogiri::HTML5(host.response.body)
      expect(host.response).to have_http_status(:ok)
      expect(page.css("title").text).to eq("New seat code")
      expect(page.at_css(".qr-card .qr-card__caption .power-badge--france").text).to eq("France")
      link = page.at_css(".qr-card__link").text
      expect(link).to match(%r{\Ahttp://www\.example\.com/games/#{id}/seat-link\?token=[A-Za-z0-9_-]{32}\z})
      expect(host.response.body).to include(ApplicationController.helpers.qr_code_svg(link, label))
      expect(page.at_css(".qr-card svg")["aria-label"]).to eq(label)
      expect(page.text).to include("Scan this once. It cannot be shown again.")
      expect(host.response.headers["Cache-Control"]).to include("no-store")
      expect(page.at_css("meta[name=turbo-cache-control][content=no-cache]")).to be_present

      host.get qr_path

      expect(host.response).to have_http_status(:found)
      expect(host.response.location).to eq("http://www.example.com/games/#{id}/host")
      host.follow_redirect!
      expect(Nokogiri::HTML5(host.response.body).at_css("[role=status]").text).to include("shown once")
      expect(host.response.body).not_to include(link[/token=(.+)\z/, 1])
    end

    it "goes back to the host page when the QR page is opened without a reissue" do
      game.take_seat!("france")
      host.get qr_path

      expect(host.response).to have_http_status(:found)
      expect(host.response.location).to eq("http://www.example.com/games/#{id}/host")
    end
  end

  describe "the old phone (AC-7.5)" do
    it "gets the stranger page and loses its cookie, while the host cookie stays valid" do
      player, _token = france_joins
      player.get "/games/#{id}"
      expect(player.response).to have_http_status(:ok)
      host.post path

      player.get "/games/#{id}"

      expect(stranger_page?(player.response)).to be(true)
      expect(cookie_line(player.response, "seat_#{id}")).to match(/expires=Thu, 01 Jan 1970/i)

      host.get "/games/#{id}/host"
      expect(host.response).to have_http_status(:ok)
      expect(cookie_lines(host.response).grep(/\Ahost_/)).to be_empty
    end
  end

  describe "the new phone (AC-7.6)" do
    it "opens the new link and lands on its seat" do
      game.take_seat!("france")
      host.post path
      host.follow_redirect!
      link = Nokogiri::HTML5(host.response.body).at_css(".qr-card__link").text
      token = link[/token=(.+)\z/, 1]
      phone = open_session

      phone.get "/games/#{id}/seat-link", params: { token: token }

      expect(cookie_line(phone.response, "seat_#{id}")).to be_present
      expect(phone.response.location).to eq("http://www.example.com/games/#{id}")
      phone.follow_redirect!
      expect(Nokogiri::HTML5(phone.response.body).at_css("h1").text).to eq("You hold France")
    end
  end

  describe "the old token (AC-7.7)" do
    it "gives the stranger page and sets no seat value" do
      _player, old_token = france_joins
      host.post path
      phone = open_session

      phone.get "/games/#{id}/seat-link", params: { token: old_token }

      expect(stranger_page?(phone.response)).to be(true)
      expect(cookie_lines(phone.response).grep(/\Aseat_/)).to be_empty
    end
  end

  describe "a power nobody holds, or one that does not exist (AC-7.8)" do
    it "gives the stranger page for the page and the post, and changes nothing" do
      digests = game.seats.order(:power).pluck(:power, :token_digest)

      %w[germany narnia].each do |power|
        host.get "/games/#{id}/host/seats/#{power}/reissue"
        expect(stranger_page?(host.response)).to be(true)
        host.post "/games/#{id}/host/seats/#{power}/reissue"
        expect(stranger_page?(host.response)).to be(true)
        host.get "/games/#{id}/host/seats/#{power}/qr"
        expect(stranger_page?(host.response)).to be(true)
      end

      expect(game.seats.reload.order(:power).pluck(:power, :token_digest)).to eq(digests)
      host.get "/games/#{id}/host"
      expect(host.response).to have_http_status(:ok)
    end
  end

  describe "a phone without the host cookie (AC-7.9)" do
    it "gets the stranger page for both pages and the digest is unchanged" do
      game.take_seat!("france")
      before = digest_of("france")
      phones = [ open_session, seat_only_session(created) ]

      phones.each do |phone|
        phone.get path
        expect(stranger_page?(phone.response)).to be(true)
        phone.post path
        expect(stranger_page?(phone.response)).to be(true)
        phone.get qr_path
        expect(stranger_page?(phone.response)).to be(true)
      end

      expect(digest_of("france")).to eq(before)
    end
  end

  describe "the host reissues their own power (AC-7.10)" do
    it "makes the host's old seat cookie fail" do
      host.get "/games/#{id}"
      expect(host.response).to have_http_status(:ok)

      host.post "/games/#{id}/host/seats/england/reissue"
      expect(host.response.location).to eq("http://www.example.com/games/#{id}/host/seats/england/qr")

      host.get "/games/#{id}"
      expect(stranger_page?(host.response)).to be(true)
      host.get "/games/#{id}/host"
      expect(host.response).to have_http_status(:ok)
    end
  end
end

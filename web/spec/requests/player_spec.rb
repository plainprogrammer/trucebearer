require "rails_helper"

RSpec.describe "The player's page and seat links", type: :request do
  around { |example| with_passphrase { example.run } }

  let(:created) { create_game(power: "england") }
  let(:game) { created.game }
  let(:id) { game.public_id }

  def stranger_page?(response)
    response.status == 404 && response.body.include?("We can't find that page.")
  end

  describe "the player's page (AC-4.10)" do
    it "shows the holder's power and the wait for the host, and no other seat" do
      game.take_seat!("france")
      created.session.get "/games/#{id}"

      page = Nokogiri::HTML5(created.session.response.body)
      expect(created.session.response).to have_http_status(:ok)
      expect(page.at_css("h1").text).to eq("You hold England")
      expect(page.at_css(".power-badge--england").text).to eq("England")
      expect(page.text).to include("The host will start the game.")
      expect(page.text).not_to include("France")
      expect(page.css("title").text).to eq("Your seat")
    end

    it "shows a link to the host controls to the host only" do
      created.session.get "/games/#{id}"
      page = Nokogiri::HTML5(created.session.response.body)
      expect(page.at_css(".host-section a[href='/games/#{id}/host']").text).to eq("Host controls")

      _seat, token = game.take_seat!("france")
      player = open_session
      player.get "/games/#{id}/seat-link", params: { token: token }
      player.follow_redirect!

      expect(player.response).to have_http_status(:ok)
      expect(Nokogiri::HTML5(player.response.body).at_css(".host-section")).to be_nil
    end

    it "shows the stranger page to a phone with no seat" do
      phone = open_session
      phone.get "/games/#{id}"

      expect(stranger_page?(phone.response)).to be(true)
    end
  end

  describe "strangers cannot tell a game exists from the player's page (AC-5.5)" do
    it "answers alike for a game that exists and one that does not, under every condition" do
      conditions = stranger_responses(created, suffix: "")

      expect(conditions.keys.size).to eq(3)
      conditions.each do |name, (existing, missing)|
        expect(existing).to eq(missing), "condition #{name}: responses differ"
        expect(existing.first).to eq(404)
        expect(existing[1]).to include("We can't find that page.")
      end
    end
  end

  describe "opening a seat link (AC-5.6, AC-7.6)" do
    it "sets the seat cookie, redirects to the player's page and sends no referrer" do
      seat, token = game.take_seat!("france")
      phone = open_session

      phone.get "/games/#{id}/seat-link", params: { token: token }

      expect(phone.response).to have_http_status(:found)
      expect(phone.response.location).to eq("http://www.example.com/games/#{id}")
      expect(cookie_line(phone.response, "seat_#{id}")).to be_present
      expect(phone.response.headers["Referrer-Policy"]).to eq("no-referrer")

      phone.follow_redirect!

      expect(Nokogiri::HTML5(phone.response.body).at_css("h1").text).to eq("You hold #{ApplicationController.helpers.power_name(seat.power)}")
      expect(phone.response.body).not_to include(token)
    end

    it "gives the stranger page and no cookie for a wrong, empty or missing token and an unknown game" do
      _seat, token = game.take_seat!("france")
      phone = open_session
      requests = [ [ id, { token: Token.generate } ], [ id, { token: "" } ], [ id, {} ], [ GameFlow::MISSING_ID, { token: token } ] ]

      requests.each do |game_id, params|
        phone.get "/games/#{game_id}/seat-link", params: params

        expect(stranger_page?(phone.response)).to be(true)
        expect(cookie_lines(phone.response).grep(/\A(?:host|seat)_/)).to be_empty
        expect(phone.response.headers["Referrer-Policy"]).to eq("no-referrer")
      end
    end

    it "does not take the host token for a seat token, nor the seat token for a host token" do
      phone = open_session
      phone.get "/games/#{id}/seat-link", params: { token: created.host_token }
      expect(stranger_page?(phone.response)).to be(true)

      _seat, token = game.take_seat!("france")
      phone.get "/games/#{id}/host-link", params: { token: token }
      expect(stranger_page?(phone.response)).to be(true)
      expect(cookie_lines(phone.response).grep(/\A(?:host|seat)_/)).to be_empty
    end
  end

  describe "a valid cookie is never stripped by a bad seat link (AC-2.5)" do
    it "keeps the host and seat cookies after a wrong-token seat link" do
      phone = created.session

      phone.get "/games/#{id}/seat-link", params: { token: Token.generate }

      expect(stranger_page?(phone.response)).to be(true)
      expect(cookie_lines(phone.response).grep(/\A(?:host|seat)_/)).to be_empty
      phone.get "/games/#{id}/host"
      expect(phone.response).to have_http_status(:ok)
      phone.get "/games/#{id}"
      expect(phone.response).to have_http_status(:ok)
    end
  end

  describe "a reissued seat (AC-7.5, AC-7.7)" do
    it "turns the old cookie into a stranger and deletes it, and refuses the old token in a link" do
      seat, old_token = game.take_seat!("france")
      player = open_session
      player.get "/games/#{id}/seat-link", params: { token: old_token }
      new_token = game.reissue_seat!(seat)

      player.get "/games/#{id}"

      expect(stranger_page?(player.response)).to be(true)
      expect(cookie_line(player.response, "seat_#{id}")).to match(/expires=Thu, 01 Jan 1970/i)

      other = open_session
      other.get "/games/#{id}/seat-link", params: { token: old_token }
      expect(stranger_page?(other.response)).to be(true)
      expect(cookie_lines(other.response).grep(/\A(?:host|seat)_/)).to be_empty

      other.get "/games/#{id}/seat-link", params: { token: new_token }
      expect(cookie_line(other.response, "seat_#{id}")).to be_present
      other.follow_redirect!
      expect(Nokogiri::HTML5(other.response.body).at_css("h1").text).to eq("You hold France")
    end
  end
end

require "rails_helper"

RSpec.describe "The host page and host links", type: :request do
  around { |example| with_passphrase { example.run } }

  let(:label) { "QR code to join the game" }

  describe "the one-time host link (AC-1.8)" do
    it "shows the link once, uncached, and never again (the page is no-store always since spec 025 D9)" do
      post "/games", params: { passphrase: GameFlow::PASSPHRASE, power: "england" }
      game = Game.last
      follow_redirect!

      page = Nokogiri::HTML5(response.body)
      link = page.at_css("input#host-link")
      expect(link.has_attribute?("readonly")).to be(true)
      expect(link["value"]).to match(%r{\Ahttp://www\.example\.com/games/#{game.public_id}/host-link\?token=[A-Za-z0-9_-]{32}\z})
      expect(response.headers["Cache-Control"]).to include("no-store")
      expect(page.at_css("meta[name=turbo-cache-control][content=no-cache]")).to be_present
      expect(page.text).to include("Anyone who has it controls this game")
      token = link["value"][/token=(.+)\z/, 1]

      get "/games/#{game.public_id}/host"

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include(token)
      expect(Nokogiri::HTML5(response.body).at_css("#host-link")).to be_nil
      expect(response.headers["Cache-Control"]).to include("no-store") # always: it can carry a revealed phase's orders (spec 025 D9)
    end
  end

  describe "opening a host link (AC-2.1)" do
    it "sets the host cookie and redirects, without the token on the page" do
      created = create_game
      id = created.game.public_id
      phone = open_session

      phone.get "/games/#{id}/host-link", params: { token: created.host_token }

      expect(phone.response).to have_http_status(:found)
      expect(phone.response.location).to eq("http://www.example.com/games/#{id}/host")
      expect(cookie_line(phone.response, "host_#{id}")).to be_present
      expect(phone.response.headers["Referrer-Policy"]).to eq("no-referrer")

      phone.follow_redirect!

      expect(phone.response).to have_http_status(:ok)
      expect(Nokogiri::HTML5(phone.response.body).at_css(".host-section")).to be_present
      expect(phone.response.body).not_to include(created.host_token)
    end
  end

  describe "a bad host link (AC-2.2)" do
    it "gives the stranger page and no cookie for a wrong, empty or missing token and an unknown game" do
      created = create_game
      id = created.game.public_id
      phone = open_session
      requests = [
        [ id, { token: Token.generate } ], [ id, { token: "" } ], [ id, {} ], [ GameFlow::MISSING_ID, { token: created.host_token } ]
      ]

      requests.each do |game_id, params|
        phone.get "/games/#{game_id}/host-link", params: params

        expect(phone.response).to have_http_status(:not_found)
        expect(phone.response.body).to include("We can't find that page.")
        expect(cookie_lines(phone.response).grep(/\A(?:host|seat)_/)).to be_empty
        expect(phone.response.headers["Referrer-Policy"]).to eq("no-referrer")
      end
    end
  end

  describe "who may see the host page (AC-2.3)" do
    it "shows the controls to the host" do
      created = create_game
      created.session.get "/games/#{created.game.public_id}/host"

      expect(created.session.response).to have_http_status(:ok)
      expect(Nokogiri::HTML5(created.session.response.body).at_css(".host-section")).to be_present
    end

    it "keeps the host page for an open game under 40,000 bytes (NFR)" do
      created = create_game
      created.session.get "/games/#{created.game.public_id}/host"

      expect(created.session.response).to have_http_status(:ok)
      expect(created.session.response.body.bytesize).to be < 40_000
    end

    it "shows the stranger page without a cookie, with a cookie for another game and with only a seat cookie" do
      created = create_game
      path = "/games/#{created.game.public_id}/host"
      other = create_game.session
      seat_only = created.session
      seat_only.cookies.delete("host_#{created.game.public_id}")

      [ open_session, other, seat_only ].each do |phone|
        phone.get path

        expect(phone.response).to have_http_status(:not_found)
        expect(phone.response.body).to include("We can't find that page.")
      end
    end

    it "shows the stranger page and drops a stale host cookie" do
      created = create_game
      id = created.game.public_id
      phone = open_session
      phone.cookies["host_#{id}"] = "stale"

      phone.get "/games/#{id}/host"

      expect(phone.response).to have_http_status(:not_found)
      expect(cookie_line(phone.response, "host_#{id}")).to match(/expires=Thu, 01 Jan 1970/i)
    end
  end

  describe "a valid cookie is never stripped by a stranger page or a bad link (AC-2.5)" do
    it "keeps the host and seat cookies after a bad host link" do
      created = create_game
      id = created.game.public_id
      phone = created.session

      phone.get "/games/#{id}/host-link", params: { token: Token.generate }
      expect(phone.response).to have_http_status(:not_found)
      expect(cookie_lines(phone.response).grep(/\A(?:host|seat)_/)).to be_empty

      phone.get "/games/#{id}/host"
      expect(phone.response).to have_http_status(:ok)
    end

    it "keeps the seat cookie when the host page turns away a phone that has only that" do
      created = create_game
      id = created.game.public_id
      phone = seat_only_session(created)

      phone.get "/games/#{id}/host"

      expect(phone.response).to have_http_status(:not_found)
      expect(cookie_lines(phone.response).grep(/\A(?:host|seat)_/)).to be_empty
    end
  end

  describe "strangers cannot tell a game exists from the host page (AC-5.5)" do
    it "answers alike for a game that exists and one that does not, under every condition" do
      created = create_game
      conditions = stranger_responses(created, suffix: "/host")

      expect(conditions.keys.size).to eq(4)
      conditions.each do |name, (existing, missing)|
        expect(existing).to eq(missing), "condition #{name}: responses differ"
        expect(existing.first).to eq(404)
        expect(existing[1]).to include("We can't find that page.")
      end
    end
  end

  describe "the QR card (AC-3.1 to 3.3)" do
    it "shows the code, the join code and the join link for the request's own host" do
      created = create_game(host: "play.example.org", https: true)
      code = created.game.join_code
      created.session.get "/games/#{created.game.public_id}/host"

      body = created.session.response.body
      page = Nokogiri::HTML5(body)
      url = "https://play.example.org/join/#{code}"
      expect(page.at_css(".qr-card svg[role=img]")).to be_present
      expect(page.at_css(".join-code").text).to eq("#{code[0, 3]} #{code[3, 3]}")
      expect(page.at_css(".qr-card__link").text).to eq(url)
      expect(body).to include(ApplicationController.helpers.qr_code_svg(url, label))
    end

    it "follows another host name, and a port" do
      plain = create_game(host: "other.example.net")
      plain.session.get "/games/#{plain.game.public_id}/host"
      plain_url = "http://other.example.net/join/#{plain.game.join_code}"
      expect(Nokogiri::HTML5(plain.session.response.body).at_css(".qr-card__link").text).to eq(plain_url)
      expect(plain.session.response.body).to include(ApplicationController.helpers.qr_code_svg(plain_url, label))

      ported = create_game(host: "play.example.org:8443", https: true)
      ported.session.get "/games/#{ported.game.public_id}/host"
      ported_url = "https://play.example.org:8443/join/#{ported.game.join_code}"
      expect(Nokogiri::HTML5(ported.session.response.body).at_css(".qr-card__link").text).to eq(ported_url)
      expect(ported.session.response.body).to include(ApplicationController.helpers.qr_code_svg(ported_url, label))
      expect(ported.session.response.body).not_to include(ApplicationController.helpers.qr_code_svg(plain_url, label))
    end

    it "is inline svg with no image, no drawing script and no request to another host (AC-3.8)" do
      created = create_game
      created.session.get "/games/#{created.game.public_id}/host"

      page = Nokogiri::HTML5(created.session.response.body)
      svg = page.at_css(".qr-card svg")
      expect(svg["role"]).to eq("img")
      expect(svg["aria-label"]).to eq(label)
      expect(svg.to_html).not_to match(/\b(?:fill|style)=/)
      expect(page.css("img")).to be_empty
      expect(page.css("script").map { |script| script["type"] }.uniq - %w[importmap module]).to be_empty
      references = page.css("[src], [href]").map { |node| node["src"] || node["href"] }
      expect(references).to all(satisfy { |ref| ref.start_with?("/") || ref.start_with?("http://www.example.com/") })
    end

    it "shows no code once joining is closed" do
      created = create_game
      created.game.close_joining!
      created.session.get "/games/#{created.game.public_id}/host"

      page = Nokogiri::HTML5(created.session.response.body)
      expect(page.text).to include("Joining is closed.")
      expect(page.at_css(".qr-card")).to be_nil
      expect(page.at_css(".join-code")).to be_nil
    end

    it "lists seven powers, the held one linking to its reissue page (AC-7.1)" do
      created = create_game(power: "england")
      id = created.game.public_id
      created.session.get "/games/#{id}/host"

      rows = Nokogiri::HTML5(created.session.response.body).css(".host-section ul.list:not([data-step-in-entry]) > li")
      expect(rows.size).to eq(7)
      expect(rows.css("a").map { |link| link["href"] }).to eq([ "/games/#{id}/host/seats/england/reissue" ])
      expect(rows.map { |row| row.text.squish }.count { |text| text.include?("Open") }).to eq(6)
    end
  end
end

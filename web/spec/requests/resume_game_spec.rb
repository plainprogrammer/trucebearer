require "rails_helper"

# Spec 028 Story 1: a phone that holds a seat is led back to its game from the home page, and a phone with no cookie sees no game.
RSpec.describe "Resuming a game", type: :request do
  let(:started) { Game.start!(power: "england") }
  let(:game) { started.game }
  let(:id) { game.public_id }
  let(:england_phone) do
    open_session.tap { |phone| phone.get "/games/#{id}/seat-link", params: { token: started.seat_token } } # the seat cookie, and no other
  end

  def cards(phone) = Nokogiri::HTML5(phone.response.body).css("a.game-card")

  it "leads England's phone to the game's current phase and shows a phone with no cookie no game (AC-1.1)" do
    england_phone.get "/"

    expect(england_phone.response).to have_http_status(:ok)
    expect(cards(england_phone).size).to eq(1)
    card = cards(england_phone).first
    expect(card["href"]).to eq("/games/#{id}")
    expect(card.text.squish).to include(game.current_phase.title).and include("England")

    england_phone.get card["href"]
    expect(england_phone.response).to have_http_status(:ok)
    expect(england_phone.response.body).to include(game.current_phase.title)

    nobody = open_session
    nobody.get "/"
    expect(nobody.response).to have_http_status(:ok)
    expect(cards(nobody)).to be_empty
    expect(nobody.response.body).not_to include("Your games")
    expect(nobody.response.body).not_to include(id)
  end

  def card_text(phone, index = 0) = cards(phone)[index].text.squish

  it "sends no-store and sets or deletes no game cookie (AC-1.6)" do
    england_phone.get "/"
    expect(england_phone.response.headers["Cache-Control"]).to include("no-store")
    expect(cookie_lines(england_phone.response).grep(/\A(?:host|seat|step_in)_/)).to be_empty

    nobody = open_session
    nobody.get "/"
    expect(nobody.response.headers["Cache-Control"]).to include("no-store")
    expect(cookie_lines(nobody.response).grep(/\A(?:host|seat|step_in)_/)).to be_empty
  end

  it "keeps the intro, then the cards, then the two buttons (AC-1.5)" do
    england_phone.get "/"
    main = Nokogiri::HTML5(england_phone.response.body).at_css("main")

    expect(main.at_css("h1").text).to eq("Trucebearer")
    expect(main.at_css("p").text).to eq("Enter secret orders on your phone and have each turn adjudicated.")
    order = main.css("h2, a.game-card, a.button").map { |node| node.name == "h2" ? "h2" : node["class"].split.first }
    expect(order).to eq(%w[h2 game-card button button])
    expect(main.css("a.button").map(&:text)).to eq([ "Create a game", "Join a game" ])
    expect(main.at_css("h2").text).to eq("Your games")
  end

  it "shows the new open phase after a reveal, with the same link (AC-1.3)" do
    england_phone.get "/"
    before = card_text(england_phone)
    game.current_phase.reveal!

    england_phone.get "/"
    expect(cards(england_phone).first["href"]).to eq("/games/#{id}")
    expect(card_text(england_phone)).not_to eq(before)
    expect(card_text(england_phone)).to include(game.reload.current_phase.title)
  end

  it "lists two games newest first, each with its own phase and power (AC-1.4)" do
    older = started
    older.game.update_columns(created_at: 3.days.ago)
    newer = Game.start!(power: "france")
    phone = open_session
    phone.get "/games/#{older.game.public_id}/seat-link", params: { token: older.seat_token }
    phone.get "/games/#{newer.game.public_id}/seat-link", params: { token: newer.seat_token }

    phone.get "/"

    expect(cards(phone).map { |card| card["href"] }).to eq([ "/games/#{newer.game.public_id}", "/games/#{older.game.public_id}" ])
    expect(card_text(phone, 0)).to include("France")
    expect(card_text(phone, 1)).to include("England")
  end

  describe "the host (D3, AC-2.1 to AC-2.5)" do
    let(:host_token) { started.host_token }

    def holder(*links)
      open_session.tap do |phone|
        links.each { |path, token| phone.get "/games/#{id}/#{path}", params: { token: token } }
      end
    end

    it "links a host with its own seat to the seat page, with the badge and the words (AC-2.1)" do
      phone = holder([ "host-link", host_token ], [ "seat-link", started.seat_token ])
      phone.get "/"

      expect(cards(phone).first["href"]).to eq("/games/#{id}")
      expect(card_text(phone)).to include("England").and include("You host this game")
    end

    it "links a host with no seat to the host page, with no badge (AC-2.2)" do
      phone = holder([ "host-link", host_token ])
      phone.get "/"

      expect(cards(phone).first["href"]).to eq("/games/#{id}/host")
      expect(card_text(phone)).to include("You host this game")
      expect(cards(phone).first.at_css(".power-badge")).to be_nil
    end

    it "treats a foreign seat cookie as no seat and deletes nothing (AC-2.3)" do
      _france, token = game.take_seat!("france")
      phone = holder([ "seat-link", token ], [ "host-link", host_token ])
      phone.get "/"

      expect(cards(phone).first["href"]).to eq("/games/#{id}/host")
      expect(cards(phone).first.at_css(".power-badge")).to be_nil
      expect(cookie_lines(phone.response).grep(/\Aseat_/)).to be_empty
      expect(phone.cookies["seat_#{id}"]).to be_present
    end

    it "does not call the holder of the host's own seat the host when the host cookie is gone (AC-2.4)" do
      phone = holder([ "seat-link", started.seat_token ])
      phone.get "/"

      expect(cards(phone).first["href"]).to eq("/games/#{id}")
      expect(card_text(phone)).not_to include("You host this game")
    end

    it "gives each game its own card by the table (AC-2.5)" do
      other = Game.start!(power: "france")
      phone = holder([ "host-link", host_token ], [ "seat-link", started.seat_token ])
      phone.get "/games/#{other.game.public_id}/seat-link", params: { token: other.seat_token }
      phone.get "/"

      hrefs = cards(phone).to_h { |card| [ card["href"], card.text.squish ] }
      expect(hrefs.keys).to match_array([ "/games/#{id}", "/games/#{other.game.public_id}" ])
      expect(hrefs["/games/#{id}"]).to include("You host this game")
      expect(hrefs["/games/#{other.game.public_id}"]).not_to include("You host this game")
    end
  end

  describe "the lost-seat line (D6)" do
    let(:line) { "Lost your seat? Ask the host for a new QR code." }

    def occurrences(phone) = phone.response.body.scan(line).size

    it "is on the home page once, below the buttons, for everyone (AC-4.1, AC-4.4)" do
      [ open_session, england_phone ].each do |phone|
        phone.get "/"
        main = Nokogiri::HTML5(phone.response.body).at_css("main")
        expect(occurrences(phone)).to eq(1)
        expect(main.css("a.button, p").map(&:text).last).to eq(line)
        expect(main.css("p").find { |p| p.text == line }.css("a")).to be_empty
      end
    end

    it "is on the stranger page once, and the stranger responses stay identical (AC-4.2)" do
      phone = open_session
      phone.get "/games/#{id}"
      expect(phone.response).to have_http_status(:not_found)
      expect(occurrences(phone)).to eq(1)

      existing, missing = [ id, GameFlow::MISSING_ID ].map do |game_id|
        open_session.tap { |s| s.get "/games/#{game_id}" }.then { |s| comparable(s.response, game_id) }
      end
      expect(existing).to eq(missing)
    end

    it "gives a reissued seat back to its replacement phone and not to the old one (AC-4.3)" do
      old_phone = england_phone
      token = game.reissue_seat!(game.seat_for(started.seat_token))
      new_phone = open_session
      new_phone.get "/games/#{id}/seat-link", params: { token: token }

      expect(new_phone.response.location).to eq("http://www.example.com/games/#{id}")
      new_phone.get "/"
      expect(cards(new_phone).map { |card| card["href"] }).to eq([ "/games/#{id}" ])
      old_phone.get "/"
      expect(cards(old_phone)).to be_empty # before the game page, whose stranger response would delete the stale cookie
      old_phone.get "/games/#{id}"
      expect(old_phone.response).to have_http_status(:not_found)
    end
  end
end

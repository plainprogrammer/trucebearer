require "rails_helper"

RSpec.describe "Joining a game by code or QR", type: :request do
  let(:started) { Game.start!(power: "england") }
  let(:game) { started.game }
  let(:id) { game.public_id }
  let(:code) { game.join_code }

  around { |example| with_passphrase { example.run } }
  before { started }

  def page_of(response) = Nokogiri::HTML5(response.body)

  def open_error?(response, status)
    response.status == status && page_of(response).at_css("[role=alert]")&.text == JoinsController::NOT_OPEN
  end

  def redirected_to(response, path)
    expect(response).to have_http_status(:found)
    expect(URI(response.headers["Location"]).path).to eq(path)
  end

  def seat_cookie?(session) = session.cookies.to_hash.keys.any? { |name| name.start_with?("seat_") }

  describe "the join page (AC-4.1)" do
    it "shows seven tiles, the host's power taken and the other six as buttons named by power" do
      get "/join/#{code}"

      page = page_of(response)
      expect(response).to have_http_status(:ok)
      expect(page.css(".power-tile").size).to eq(7)
      taken = page.css(".power-tile--taken")
      expect(taken.size).to eq(1)
      expect(taken.first.name).to eq("div")
      expect(taken.first.text).to include("Taken", "England")
      expect(taken.first.ancestors("button, a")).to be_empty
      buttons = page.css("button.power-tile")
      expect(buttons.size).to eq(6)
      expect(buttons.map { |button| button.text.strip }).to match_array(%w[Austria France Germany Italy Russia Turkey])
      expect(page.css("title").text).to eq("Pick a power")
      expect(page.at_css("form[action='/join/#{code}/seat'][method=post]")).to be_present
    end
  end

  describe "the code form (AC-4.2)" do
    it "has a labelled code field and a Join button" do
      get "/join"

      page = page_of(response)
      expect(response).to have_http_status(:ok)
      expect(page.css("title").text).to eq("Join a game")
      expect(page.at_css("label[for=code]").text).to eq("Game code")
      field = page.at_css("input#code[name=code]")
      expect(field["class"].split).to include("control", "mono")
      expect(field["autocomplete"]).to eq("off")
      expect(field["autocapitalize"]).to eq("characters")
      expect(page.at_css("form[action='/join'] button.button").text.strip).to eq("Join")
      expect(page.at_css("[role=alert]")).to be_nil
    end

    it "redirects lower case, a middle space or hyphen, and surrounding spaces to the code's page" do
      typed = [ code.downcase, "#{code[0, 3]}-#{code[3, 3]}".downcase, "#{code[0, 3].downcase} #{code[3, 3].downcase}",
                " #{code} " ]

      typed.each do |input|
        post "/join", params: { code: input }

        expect(response).to redirect_to("/join/#{code}"), "input #{input.inspect}"
      end
    end
  end

  describe "taking a power (AC-4.3, AC-4.4)" do
    it "creates one seat, sets a signed seat cookie and redirects to the player's page" do
      phone = open_session
      expect { phone.post "/join/#{code}/seat", params: { power: "france" } }.to change(Seat, :count).by(1)

      redirected_to(phone.response, "/games/#{id}")
      expect(game.seats.where(power: "france").count).to eq(1)
      line = cookie_line(phone.response, "seat_#{id}")
      expect(line).to include("httponly", "samesite=lax")
    end

    it "holds the token only in the signed cookie and stores only its digest" do
      phone = open_session
      phone.post "/join/#{code}/seat", params: { power: "france" }
      seat = game.seats.find_by!(power: "france")

      raw = CGI.unescape(cookie_line(phone.response, "seat_#{id}")[/\Aseat_#{id}=([^;]*)/, 1])
      token = phone.request.cookie_jar.signed["seat_#{id}"]
      expect(token).to be_present
      expect(raw).not_to include(token)
      expect(Token.match?(token, seat.token_digest)).to be(true)
      expect(game.seat_for(token)).to eq(seat)
      expect(Seat.column_names.grep(/token/)).to eq([ "token_digest" ])
      expect(seat.attributes.values.map(&:to_s)).not_to include(token)
    end
  end

  describe "a taken or unknown power (AC-4.5, AC-4.7)" do
    it "refuses a taken power with the tiles again, no seat and no cookie" do
      phone = open_session
      expect { phone.post "/join/#{code}/seat", params: { power: "england" } }.not_to change(Seat, :count)

      page = page_of(phone.response)
      expect(phone.response).to have_http_status(:unprocessable_content)
      expect(page.at_css("[role=alert]").text).to eq("England has been taken. Pick another.")
      expect(page.css(".power-tile").size).to eq(7)
      expect(page.css(".power-tile--taken").size).to eq(1)
      expect(cookie_line(phone.response, "seat_#{id}")).to be_nil
      expect(seat_cookie?(phone)).to be(false)
    end

    it "refuses an unknown or missing power" do
      [ { power: "narnia" }, {}, { power: "" } ].each do |params|
        phone = open_session
        expect { phone.post "/join/#{code}/seat", params: params }.not_to change(Seat, :count)

        page = page_of(phone.response)
        expect(phone.response).to have_http_status(:unprocessable_content), params.inspect
        expect(page.at_css("[role=alert]").text).to eq("Pick one of the seven powers.")
        expect(page.css(".power-tile").size).to eq(7)
        expect(seat_cookie?(phone)).to be(false)
      end
    end
  end

  describe "two phones, one power (AC-4.6)" do
    it "gives the power to the first and the taken answer to the second" do
      first = open_session
      second = open_session
      first.post "/join/#{code}/seat", params: { power: "france" }
      expect(first.response).to have_http_status(:found)

      expect { second.post "/join/#{code}/seat", params: { power: "france" } }.not_to change(Seat, :count)

      expect(second.response).to have_http_status(:unprocessable_content)
      expect(page_of(second.response).at_css("[role=alert]").text).to eq("France has been taken. Pick another.")
      expect(seat_cookie?(second)).to be(false)
      expect(game.seats.where(power: "france").count).to eq(1)
    end

    it "answers as taken when the model raises SeatTaken, whatever the page's own check said (controller answer only)" do
      other = open_session
      allow_any_instance_of(Game).to receive(:take_seat!).and_raise(Game::SeatTaken)

      expect { other.post "/join/#{code}/seat", params: { power: "france" } }.not_to change(Seat, :count)

      expect(other.response).to have_http_status(:unprocessable_content)
      expect(page_of(other.response).at_css("[role=alert]").text).to eq("France has been taken. Pick another.")
    end
  end

  describe "a phone that already holds a seat (AC-4.8)" do
    it "is sent to its page from the join page and from the seat post, with no second seat and the same cookie" do
      phone = open_session
      phone.post "/join/#{code}/seat", params: { power: "france" }
      before = phone.cookies["seat_#{id}"]

      phone.get "/join/#{code}"
      redirected_to(phone.response, "/games/#{id}")

      expect { phone.post "/join/#{code}/seat", params: { power: "italy" } }.not_to change(Seat, :count)
      redirected_to(phone.response, "/games/#{id}")
      expect(phone.cookies["seat_#{id}"]).to eq(before)
      expect(game.seats.pluck(:power)).to match_array(%w[england france])
    end

    it "sends the host's phone to its page too" do
      created = create_game
      created.session.get "/join/#{created.game.join_code}"

      redirected_to(created.session.response, "/games/#{created.game.public_id}")
    end
  end

  describe "a full game (AC-4.9)" do
    it "shows seven taken tiles and says every seat is taken" do
      %w[austria france germany italy russia turkey].each { |power| game.take_seat!(power) }

      get "/join/#{code}"

      page = page_of(response)
      expect(response).to have_http_status(:ok)
      expect(page.css(".power-tile--taken").size).to eq(7)
      expect(page.css("button.power-tile")).to be_empty
      expect(page.text).to include("Every seat is taken.")
    end

    it "does not say every seat is taken while one is open" do
      get "/join/#{code}"

      expect(response.body).not_to include("Every seat is taken.")
    end
  end

  describe "joining closed after the page loaded (AC-4.11)" do
    it "creates no seat and answers as an unknown code" do
      get "/join/#{code}"
      expect(response).to have_http_status(:ok)
      game.close_joining!

      phone = open_session
      expect { phone.post "/join/#{code}/seat", params: { power: "france" } }.not_to change(Seat, :count)

      expect(open_error?(phone.response, 422)).to be(true)
      expect(phone.response.body).not_to include(code)
      expect(seat_cookie?(phone)).to be(false)
    end

    it "answers as the closed answer when the model raises NotOpen (controller answer only)" do
      allow_any_instance_of(Game).to receive(:take_seat!).and_raise(Game::NotOpen)

      phone = open_session
      phone.post "/join/#{code}/seat", params: { power: "france" }

      expect(open_error?(phone.response, 422)).to be(true)
      expect(seat_cookie?(phone)).to be(false)
    end
  end

  describe "unknown, closed and malformed codes (AC-5.1 to AC-5.4)" do
    let(:closed) { Game.start!(power: "france").game.tap(&:close_joining!) }
    let(:unknown) { (JoinCode::ALPHABET.each_cons(6).map(&:join) - Game.pluck(:join_code)).first }
    let(:malformed) { %w[ABCDE ABCDEFG AB!DEF AB.DEF ABC%20DE ABCDEB abcd%0Aef] }

    def request_route(session, route, code)
      case route
      when :post_join then session.post "/join", params: { code: code }
      when :get_show then session.get "/join/#{code}"
      when :post_seat then session.post "/join/#{code}/seat", params: { power: "france" }
      end
      session.response
    end

    {
      post_join: 422,
      get_show: 404,
      post_seat: 422
    }.each do |route, status|
      describe "on #{route}" do
        it "answers an unknown code and a closed game's code alike" do
          unknown_response = request_route(open_session, route, unknown)
          unknown_tuple = comparable(unknown_response, "ID")
          closed_response = request_route(open_session, route, closed.join_code)

          expect(unknown_tuple.first).to eq(status)
          expect(comparable(closed_response, "ID")).to eq(unknown_tuple)
          expect(open_error?(closed_response, status)).to be(true)
          expect(closed_response.body).not_to include(closed.join_code)
          expect(unknown_response.body).not_to include(unknown)
          expect(cookie_lines(closed_response).grep(/\A(?:host|seat)_/)).to be_empty
        end

        it "answers each malformed code like an unknown one, never with the framework's page" do
          expected = comparable(request_route(open_session, route, unknown), "ID")

          malformed.each do |bad|
            response = request_route(open_session, route, bad)

            expect(comparable(response, "ID")).to eq(expected), "code #{bad.inspect}"
            expect(open_error?(response, status)).to be(true), "code #{bad.inspect}"
            expect(response.body).not_to include("AB.DEF", "ABC DE", "ABCDEFG")
          end
        end
      end
    end

    it "creates no seat and sets no cookie when a power is posted to an unknown, closed or malformed code" do
      [ unknown, closed.join_code, *malformed ].each do |bad|
        phone = open_session
        expect { request_route(phone, :post_seat, bad) }.not_to change(Seat, :count)
        expect(seat_cookie?(phone)).to be(false), "code #{bad.inspect}"
      end
    end

    it "does not take a lower-case or spaced copy of a closed game's code" do
      post "/join", params: { code: closed.join_code.downcase }

      expect(open_error?(response, 422)).to be(true)
    end
  end

  describe "seats held when joining closes (AC-6.3)" do
    it "keeps opening the player's page for the holders" do
      host = create_game
      player = open_session
      player.post "/join/#{host.game.join_code}/seat", params: { power: "france" }
      host.game.close_joining!

      [ host.session, player ].each do |phone|
        phone.get "/games/#{host.game.public_id}"
        expect(phone.response).to have_http_status(:ok)
      end
    end

    it "gives a closed game's page the not-open answer for a phone without a seat" do
      game.close_joining!

      get "/join/#{code}"

      expect(open_error?(response, 404)).to be(true)
    end
  end
end

require "rails_helper"

RSpec.describe "Joining a game by code or QR", type: :request do
  let(:started) { Game.start!(power: "england") }
  let(:game) { started.game }
  let(:id) { game.public_id }
  let(:code) { game.join_code }

  def page_of(response) = Nokogiri::HTML5(response.body)

  def open_error?(response, status)
    response.status == status && page_of(response).at_css("[role=alert]")&.text == JoinsController::NOT_OPEN
  end

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

  describe "unknown, closed and malformed codes (AC-5.1 to AC-5.4)" do
    let(:closed) { Game.start!(power: "france").game.tap(&:close_joining!) }
    let(:unknown) { (JoinCode::ALPHABET.each_cons(6).map(&:join) - Game.pluck(:join_code)).first }
    let(:malformed) { %w[ABCDE ABCDEFG AB!DEF AB.DEF ABC%20DE ABCDEB abcd%0Aef] }

    def request_route(session, route, code)
      case route
      when :post_join then session.post "/join", params: { code: code }
      when :get_show then session.get "/join/#{code}"
      end
      session.response
    end

    {
      post_join: 422,
      get_show: 404
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

    it "does not take a lower-case or spaced copy of a closed game's code" do
      post "/join", params: { code: closed.join_code.downcase }

      expect(open_error?(response, 422)).to be(true)
    end
  end

  describe "a closed game (AC-6.3)" do
    it "gives a closed game's page the not-open answer for a phone without a seat" do
      game.close_joining!

      get "/join/#{code}"

      expect(open_error?(response, 404)).to be(true)
    end
  end
end

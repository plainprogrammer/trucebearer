require "rails_helper"

RSpec.describe "Creating a game", type: :request do
  around do |example|
    original = ENV["TRUCEBEARER_PASSPHRASE"]
    ENV["TRUCEBEARER_PASSPHRASE"] = "open sesame"
    example.run
  ensure
    ENV["TRUCEBEARER_PASSPHRASE"] = original
  end

  it "refuses a wrong passphrase and creates no game (AC-1.3)" do
    expect { post "/games", params: { passphrase: "wrong", power: "england" } }.not_to change { [ Game.count, Seat.count ] }

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("That passphrase isn&#39;t right.")
    expect(cookie_lines(response).grep(/\A(?:host|seat)_/)).to be_empty
  end

  it "creates a game and sets the host cookie with the right passphrase (AC-1.2)" do
    expect { post "/games", params: { passphrase: "open sesame", power: "england" } }
      .to change(Game, :count).by(1).and change(Seat, :count).by(1)

    game = Game.last
    expect(response).to redirect_to("/games/#{game.public_id}/host")
    expect(cookie_line(response, "host_#{game.public_id}")).to be_present
    expect(cookie_line(response, "seat_#{game.public_id}")).to be_present
  end

  describe "the new-game page (AC-1.1)" do
    it "shows a passphrase field and seven open power tiles, and makes no game" do
      expect { get "/games/new" }.not_to change(Game, :count)

      page = Nokogiri::HTML5(response.body)
      expect(response).to have_http_status(:ok)
      expect(page.at_css("h1").text).to eq("Create a game")
      expect(page.css("input[name=passphrase]").size).to eq(1)
      expect(page.css("button.power-tile").map { |tile| tile.text.strip }).to eq(RulesEngine.powers.map(&:name))
      expect(page.css("button.power-tile").map { |tile| tile["value"] }).to eq(RulesEngine.powers.map { |power| power.id.to_s })
    end

    it "never puts a value in the passphrase field" do
      post "/games", params: { passphrase: "wrong guess", power: "england" }

      expect(Nokogiri::HTML5(response.body).at_css("input[name=passphrase]")["value"]).to be_nil
      expect(response.body).not_to include("wrong guess")
    end
  end

  describe "a wrong passphrase gives one answer (AC-1.4)" do
    def without_form_token(body) = body.gsub(/(authenticity_token|csrf-token)[^>]*>/, "")

    it "answers 422 with the same message and body for every kind of wrong guess" do
      post "/games", params: { passphrase: "wrong", power: "england" }
      reference = without_form_token(response.body)

      [ { passphrase: "" }, {}, { passphrase: "open sesam" }, { passphrase: "open sesamee" }, { passphrase: "Open sesame" } ].each do |guess|
        expect { post "/games", params: guess.merge(power: "england") }.not_to change(Game, :count)

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include("That passphrase isn&#39;t right.")
        expect(without_form_token(response.body)).to eq(reference)
      end
    end
  end

  describe "a power that is not one of the seven (AC-1.5)" do
    [ "", nil, "narnia" ].each do |power|
      it "refuses #{power.inspect} and creates nothing" do
        expect { post "/games", params: { passphrase: "open sesame", power: power }.compact }.not_to change { [ Game.count, Seat.count ] }

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include("Pick one of the seven powers.")
        expect(cookie_lines(response).grep(/\A(?:host|seat)_/)).to be_empty
      end
    end
  end

  describe "an instance with no passphrase set (AC-1.6)" do
    [ nil, "  " ].each do |value|
      context "when the variable is #{value.inspect}" do
        before { ENV["TRUCEBEARER_PASSPHRASE"] = value }

        it "turns the new-game page off with a 403 and no passphrase field" do
          allow(Rails.logger).to receive(:warn)

          get "/games/new"

          expect(response).to have_http_status(:forbidden)
          expect(response.body).to include("Creating games is turned off on this instance. Ask whoever runs it.")
          expect(response.body).not_to include('name="passphrase"')
          expect(Rails.logger).to have_received(:warn).with(/TRUCEBEARER_PASSPHRASE/).once
        end

        it "refuses a post, whatever passphrase it brings, and logs once" do
          allow(Rails.logger).to receive(:warn)

          expect { post "/games", params: { passphrase: value.to_s, power: "england" } }.not_to change(Game, :count)

          expect(response).to have_http_status(:forbidden)
          expect(response.body).to include("Creating games is turned off on this instance. Ask whoever runs it.")
          expect(Rails.logger).to have_received(:warn).with(/TRUCEBEARER_PASSPHRASE/).once
        end
      end
    end
  end

  describe "the passphrase comparison (AC-1.7)" do
    it "reaches secure_compare with two digests, even for a missing guess" do
      allow(ActiveSupport::SecurityUtils).to receive(:secure_compare).and_call_original

      post "/games", params: { power: "england" }

      expect(ActiveSupport::SecurityUtils).to have_received(:secure_compare)
        .with(Token.digest(""), Token.digest("open sesame"))
      expect(Token.digest("")).to match(/\A\h{64}\z/)
    end

    it "never writes the passphrase to the log" do
      io = StringIO.new
      logger = Logger.new(io)
      Rails.logger.broadcast_to(logger)
      begin
        post "/games", params: { passphrase: "open sesame", power: "england" }
      ensure
        Rails.logger.stop_broadcasting_to(logger)
      end

      expect(io.string).to include("[FILTERED]")
      expect(io.string).not_to include("open sesame")
    end
  end

  describe "the cookies it sets (AC-11.2, AC-11.3)" do
    def create_game = post("/games", params: { passphrase: "open sesame", power: "england" })

    def session_line = cookie_lines(response).find { |line| !line.match?(/\A(?:host|seat)_/) }

    it "marks host, seat and session cookies HttpOnly and SameSite=Lax, and the first two Secure when force_ssl is on" do
      allow(Rails.configuration).to receive(:force_ssl).and_return(true)
      https!
      create_game
      id = Game.last.public_id

      [ cookie_line(response, "host_#{id}"), cookie_line(response, "seat_#{id}") ].each do |line|
        expect(line).to match(/;\s*httponly/i)
        expect(line).to match(/;\s*samesite=lax/i)
        expect(line).to match(/;\s*secure/i)
      end
      expect(session_line).to match(/;\s*httponly/i)
      expect(session_line).to match(/;\s*samesite=lax/i)
    end

    it "leaves Secure off when force_ssl is off" do
      allow(Rails.configuration).to receive(:force_ssl).and_return(false)
      create_game
      id = Game.last.public_id

      [ cookie_line(response, "host_#{id}"), cookie_line(response, "seat_#{id}") ].each do |line|
        expect(line).to match(/;\s*httponly/i)
        expect(line).to match(/;\s*samesite=lax/i)
        expect(line).not_to match(/;\s*secure/i)
      end
      expect(session_line).to match(/;\s*httponly/i)
      expect(session_line).to match(/;\s*samesite=lax/i)
    end

    it "stores the token signed, never in the clear" do
      create_game
      game = Game.last
      name = "seat_#{game.public_id}"
      raw = cookie_line(response, name)[/\A#{name}=([^;]*)/, 1]

      # The header holds the value URL-escaped, as a browser would send it back after unescaping.
      jar = ActionDispatch::Cookies::CookieJar.build(request, { name => CGI.unescape(raw) })
      token = jar.signed[name]

      expect(token).to be_present
      expect(raw).not_to include(token)
      expect(Token.match?(token, game.seats.first.token_digest)).to be(true)
      expect(game.host_token?(token)).to be(false)
    end
  end
end

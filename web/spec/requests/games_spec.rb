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
end

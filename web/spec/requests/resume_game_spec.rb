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
end

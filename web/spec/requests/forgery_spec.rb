require "rails_helper"

RSpec.describe "Forgery protection", type: :request do
  around do |example|
    with_passphrase do
      original = ActionController::Base.allow_forgery_protection
      example.run
    ensure
      ActionController::Base.allow_forgery_protection = original
    end
  end

  # Games are made with the check off, as the helper posts the form without a token; the check goes on for the attempt.
  let!(:created) { create_game(power: "england") }
  let(:game) { created.game }
  let(:id) { game.public_id }

  def state
    [ Game.count, Seat.count, game.reload.joining_closed_at, Seat.order(:id).pluck(:token_digest),
      Phase.count, game.current_phase.revealed_at, SavedOrder.count, Submission.count ]
  end

  # Posts without a token on a phone that holds every cookie the host has, and says what became of it.
  def post_without_token(path, verb: :post, **params)
    ActionController::Base.allow_forgery_protection = true
    before = state
    refused = begin
      created.session.public_send(verb, path, params: params)
      created.session.response.status == 422
    rescue ActionController::InvalidAuthenticityToken
      true
    end
    expect(refused).to be(true)
    expect(state).to eq(before)
  end

  it "refuses a new game without a token (AC-11.1)" do
    post_without_token "/games", passphrase: GameFlow::PASSPHRASE, power: "france"
  end

  it "refuses a code lookup without a token (AC-11.1)" do
    post_without_token "/join", code: game.join_code
  end

  it "refuses taking a power without a token (AC-11.1)" do
    post_without_token "/join/#{game.join_code}/seat", power: "france"
  end

  it "refuses closing joining without a token (AC-11.1)" do
    post_without_token "/games/#{id}/host/close"
    expect(game.reload.joining_closed_at).to be_nil
  end

  it "refuses reissuing a seat without a token (AC-11.1)" do
    post_without_token "/games/#{id}/host/seats/england/reissue"
  end

  it "does accept the same posts with a token, so the check is really on" do
    ActionController::Base.allow_forgery_protection = true
    created.session.get "/games/#{id}/host/close"
    token = Nokogiri::HTML5(created.session.response.body).at_css("input[name=authenticity_token]")["value"]
    created.session.post "/games/#{id}/host/close", params: { authenticity_token: token }
    expect(created.session.response).to have_http_status(:redirect)
    expect(game.reload.joining_closed_at).not_to be_nil
  end

  it "refuses saving orders without a token (spec 022 NFR security)" do
    hold = JSON.generate({ "format" => 1, "type" => "hold", "power" => "england", "at" => "lon" })
    post_without_token "/games/#{id}/phases/1/orders", verb: :put, orders: { lon: hold }, submit: "1"
  end

  it "refuses a reveal without a token, and the phase stays open (spec 022 NFR security)" do
    post_without_token "/games/#{id}/host/phases/1/reveal"
    expect(game.current_phase.number).to eq(1)
  end
end

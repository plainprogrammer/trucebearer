require "rails_helper"
require_relative "../support/results_fixtures"

# Spec 025 D2, AC-3.4, AC-4.3: which pages carry the signed results name, and that nothing else does.
RSpec.describe "The results stream on pages", type: :request do
  include ResultsFixtures

  around { |example| with_passphrase { example.run } }

  let!(:created) { create_game(power: "england") }
  let(:game) { created.game }
  let(:id) { game.public_id }
  let(:host) { created.session }
  let!(:france) { game.take_seat!("france") }

  def page(session) = Nokogiri::HTML5(session.response.body)

  def names(session) = page(session).css("turbo-cable-stream-source").map { |source| Turbo.signed_stream_verifier.verified(source["signed-stream-name"]) }.sort

  def meta(session, name) = page(session).at_css("meta[name='#{name}']")&.[]("content")

  it "gives the seat page and the host page the status and results names, and the morphed refresh (AC-3.4)" do
    [ "/games/#{id}", "/games/#{id}/host" ].each do |path|
      host.get path
      expect(names(host)).to eq([ "results:#{id}:1", "seat_status:#{id}" ]), path
      expect(meta(host, "turbo-refresh-method")).to eq("morph"), path
      expect(meta(host, "turbo-refresh-scroll")).to eq("preserve"), path
    end
  end

  it "gives the seat's own order screen and picker the results name only (AC-3.4)" do
    [ "/games/#{id}/phases/1/orders", "/games/#{id}/phases/1/orders/lon" ].each do |path|
      host.get path
      expect(names(host)).to eq([ "results:#{id}:1" ]), path
      expect(meta(host, "turbo-refresh-method")).to eq("morph"), path
    end
  end

  it "names the channel that carries each source: the status channel and the results channel, on the pages that have them (spec 024 AC-9.5)" do
    [ "/games/#{id}", "/games/#{id}/host" ].each do |path|
      host.get path
      expect(page(host).css("turbo-cable-stream-source").to_h { |source| [ source["channel"], Turbo.signed_stream_verifier.verified(source["signed-stream-name"]) ] })
        .to eq("SeatStatusChannel" => "seat_status:#{id}", "ResultsChannel" => "results:#{id}:1"), path
    end
    [ "/games/#{id}/phases/1/orders", "/games/#{id}/phases/1/orders/lon" ].each do |path|
      host.get path
      expect(page(host).css("turbo-cable-stream-source").map { |source| source["channel"] }).to eq([ "ResultsChannel" ]), path
    end
  end

  it "gives no page of another game this game's name, and no stranger any name (AC-4.3)" do
    other = create_game(power: "france")
    other.session.get "/games/#{other.game.public_id}"
    expect(names(other.session)).to eq([ "results:#{other.game.public_id}:1", "seat_status:#{other.game.public_id}" ])

    stranger = open_session
    [ "/games/#{id}", "/games/#{id}/host", "/games/#{id}/phases/1/orders", "/games/#{id}/phases/1/orders/lon" ].each do |path|
      stranger.get path
      expect(stranger.response.body).not_to include("turbo-cable-stream-source"), path
      expect(stranger.response.body).not_to include("signed-stream-name"), path
    end
  end

  it "gives no stream to a stepped-in screen, a confirmation page or a results page (D2)" do
    stepped = open_session.tap { |session| session.get "/games/#{id}/host-link", params: { token: created.host_token } }
    stepped.post "/games/#{id}/host/seats/france/phases/1/step-in"
    stepped.get "/games/#{id}/host/seats/france/phases/1/orders"
    expect(stepped.response).to have_http_status(:ok)
    expect(names(stepped)).to be_empty

    stepped.get "/games/#{id}/host/seats/england/phases/1/step-in"
    host.get "/games/#{id}/host/phases/1/reveal"
    [ stepped, host ].each { |session| expect(names(session)).to be_empty }

    revealed_phase_with(game, outcomes: [])
    [ "/games/#{id}/phases/1/results", "/games/#{id}/host/phases/1/results" ].each do |path|
      host.get path
      expect(names(host)).to be_empty, path
    end
  end
end

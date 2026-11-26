require "rails_helper"
require_relative "../support/rules_helpers"

# Spec 026 D10 and Story 10: every reissue leaves a row, and the host page's history shows it with a time and no order.
RSpec.describe "The reissue history", type: :request do
  include RulesHelpers

  around { |example| with_passphrase { example.run } }

  let(:created) { create_game(power: "germany") }
  let(:game) { created.game }
  let(:id) { game.public_id }
  let(:host) { created.session }
  let!(:france_and_token) { game.take_seat!("france") }
  let(:france) { france_and_token.first }

  def page = Nokogiri::HTML5(host.response.body)

  def reissue(power) = host.post("/games/#{id}/host/seats/#{power}/reissue")

  def history = page.at_css("[data-seat-history]")

  # Reissues, follows the redirect to the one-time QR page, and returns the new token the new phone would scan.
  def reissue_and_read_token(power)
    reissue(power)
    host.follow_redirect!
    page.at_css(".qr-card__link").text[/token=(.+)\z/, 1]
  end

  it "shows France's reissue on the host page with the phase and the time, and no order (AC-10.1)" do
    france.save_orders!(game.current_phase, { "par" => json_of(rules_order(:hold, :france, :par)) }, submit: true)
    travel_to(Time.utc(2026, 11, 26, 20, 40)) { reissue("france") }
    host.get "/games/#{id}/host"

    expect(history).not_to be_nil # red for the right reason: the section is not on the page yet
    expect(history.css("li").map { |row| row.text.squish }).to eq([ "#{game.current_phase.title} France seat reissued 8:40 PM UTC" ])
    expect(history.at_css("time")["datetime"]).to eq("2026-11-26T20:40:00Z")
    expect(history.css("select, option, a")).to be_empty
    expect(history.text).not_to match(/\bHold\b|\bPAR\b|ordered|Submitted|\d of \d|token/)
  end

  it "carries no token or link of the reissue in the history (AC-10.6)" do
    token = reissue_and_read_token("france")
    host.get "/games/#{id}/host"

    expect(token).to be_present
    expect(history.to_html).not_to include(token)
  end

  it "lists a step-in and reissues together in time order, and keeps an earlier phase's rows after its reveal (AC-10.4)" do
    game.take_seat!("england")
    first_title = game.current_phase.title
    travel_to(Time.utc(2026, 11, 26, 20, 30)) { host.post "/games/#{id}/host/seats/england/phases/1/step-in" }
    travel_to(Time.utc(2026, 11, 26, 20, 40)) { reissue("france") }
    game.current_phase.reveal!
    second_title = game.current_phase.title
    travel_to(Time.utc(2026, 11, 26, 22, 0)) { reissue("england") }
    host.get "/games/#{id}/host"

    expect(history.css("li").map { |row| row.text.squish }).to eq([
      "#{first_title} England stepped in 8:30 PM UTC",
      "#{first_title} France seat reissued 8:40 PM UTC",
      "#{second_title} England seat reissued 10:00 PM UTC"
    ])
  end

  it "reads with the table's time zone (AC-6.5)" do
    travel_to(Time.utc(2026, 11, 26, 20, 40)) { reissue("france") }
    original = ENV["TRUCEBEARER_TIME_ZONE"]
    begin
      ENV["TRUCEBEARER_TIME_ZONE"] = "America/New_York"
      host.get "/games/#{id}/host"
    ensure
      ENV["TRUCEBEARER_TIME_ZONE"] = original
    end

    expect(history.text).to include("3:40 PM EST")
  end

  it "says so when nothing has happened (AC-6.4)" do
    host.get "/games/#{id}/host"

    expect(history.text).to include("Nothing has happened to a seat yet.")
  end

  it "writes no row for a reissue that is refused (AC-10.2)" do
    stranger = open_session
    stranger.post "/games/#{id}/host/seats/france/reissue"
    france_phone = open_session
    france_phone.get "/games/#{id}/seat-link", params: { token: france_and_token.last }
    france_phone.post "/games/#{id}/host/seats/france/reissue" # a seat's own phone is not the host's
    host.post "/games/#{id}/host/seats/england/reissue" # no seat is held by England
    host.post "/games/#{id}/host/seats/nowhere/reissue"

    expect(Reissue.count).to eq(0)
  end

  it "adds nothing to any seat's own pages, and shows the history only to the host (AC-10.8, spec 021 AC-7.12)" do
    england_token = game.take_seat!("england").last
    france_token = reissue_and_read_token("france")
    phones = [ france_token, england_token ].map do |token|
      open_session.tap { |phone| phone.get "/games/#{id}/seat-link", params: { token: token } }
    end

    phones.each do |phone|
      [ "/games/#{id}", "/games/#{id}/phases/1/orders" ].each do |path|
        phone.get path
        expect(phone.response).to have_http_status(:ok), path
        doc = Nokogiri::HTML5(phone.response.body)
        expect(doc.css(".banner--warning").map(&:text).join).not_to match(/reissue/i), path
        expect(phone.response.body).not_to match(/reissued|Seat history/), path
      end
    end
  end
end

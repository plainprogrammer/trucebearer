require "rails_helper"
require_relative "../support/rules_helpers"

# Spec 026 Story 6: the seat's owner is told, and the game's history keeps the step-ins.
RSpec.describe "Step-in notices and history", type: :request do
  include RulesHelpers

  around { |example| with_passphrase { example.run } }

  let(:created) { create_game(power: "germany") }
  let(:game) { created.game }
  let(:id) { game.public_id }
  let!(:england_and_token) { game.take_seat!("england") }
  let!(:france_and_token) { game.take_seat!("france") }
  let(:host) { created.session }

  def page(session = host) = Nokogiri::HTML5(session.response.body)

  def phone_for(token) = open_session.tap { |phone| phone.get "/games/#{id}/seat-link", params: { token: token } }

  def confirm(power = "france", number = 1) = host.post("/games/#{id}/host/seats/#{power}/phases/#{number}/step-in")

  def notice(session) = page(session).css(".banner--warning").map { |banner| banner.text.squish }.grep(/The host entered/)

  it "shows France one banner with the time on its seat page and order screen (AC-6.1, AC-6.2)" do
    travel_to(Time.utc(2026, 11, 26, 20, 42)) { confirm }
    phone = phone_for(france_and_token.last)

    [ "/games/#{id}", "/games/#{id}/phases/1/orders" ].each do |path|
      phone.get path
      expect(notice(phone)).to eq([ "Warning: The host entered your orders at 8:42 PM UTC." ]), path
      expect(page(phone).at_css(".banner--warning time")["datetime"]).to eq("2026-11-26T20:42:00Z"), path
    end
  end

  it "lists every time in the one banner (AC-6.1)" do
    travel_to(Time.utc(2026, 11, 26, 20, 42)) { confirm }
    travel_to(Time.utc(2026, 11, 26, 21, 5)) { confirm }
    phone = phone_for(france_and_token.last)
    phone.get "/games/#{id}"

    expect(notice(phone)).to eq([ "Warning: The host entered your orders at 8:42 PM UTC, 9:05 PM UTC." ])
  end

  it "shows it to no one else, not even the stepped-in host on France's own screen (AC-6.3)" do
    confirm
    host.get "/games/#{id}/host/seats/france/phases/1/orders"
    expect(notice(host)).to be_empty
    england = phone_for(england_and_token.last)
    [ "/games/#{id}", "/games/#{id}/phases/1/orders" ].each do |path|
      england.get path
      expect(notice(england)).to be_empty, path
      # France is named in the status list of the seven powers (spec 024), and only there.
      outside_status = Nokogiri::HTML5(england.response.body).tap { |doc| doc.at_css("#seat-status")&.remove }.to_html
      expect(outside_status).not_to match(/France|stepped/), path
    end
    host.get "/games/#{id}"
    expect(notice(host)).to be_empty
  end

  it "tells France in the new link's seat page after a reissue and a step-in (AC-7.2)" do
    host.post "/games/#{id}/host/seats/france/reissue"
    host.follow_redirect!
    link = page.at_css(".qr-card__link").text.delete_prefix("http://www.example.com")
    host.get link
    host.post "/games/#{id}/host/seats/france/phases/1/step-in"
    phone = open_session
    phone.get link
    phone.get "/games/#{id}"

    expect(notice(phone).size).to eq(1)
  end

  it "keeps the history on the host page, and drops the notice in the next phase (AC-6.4)" do
    travel_to(Time.utc(2026, 11, 26, 20, 42)) { confirm }
    game.current_phase.reveal!
    phone = phone_for(france_and_token.last)
    phone.get "/games/#{id}"
    expect(notice(phone)).to be_empty

    host.get "/games/#{id}/host"
    rows = page.css("[data-step-ins] li").map { |li| li.text.squish }
    expect(rows).to eq([ "Spring 1901 · Movement France 8:42 PM UTC" ])
    expect(page.at_css("[data-step-ins] .power-badge").text).to eq("France")
  end

  it "says so when there are none, and lists several oldest first (AC-6.4)" do
    host.get "/games/#{id}/host"
    expect(page.at_css("[data-step-ins]").text).to include("The host has not stepped into a seat.")

    confirm("england")
    confirm("france")
    host.get "/games/#{id}/host"
    expect(page.css("[data-step-ins] .power-badge").map(&:text)).to eq([ "England", "France" ])
  end

  it "shows no order, count or submitted state in the history, and the host page stays free of them (AC-6.6)" do
    england_and_token.first.save_orders!(game.current_phase, { "lon" => json_of(rules_order(:hold, :england, :lon)) }, submit: true)
    confirm("england")
    host.get "/games/#{id}/host"

    history = page.at_css("[data-step-ins]")
    expect(history.css("select, option")).to be_empty
    expect(history.text).not_to match(/ordered|Submitted|\d of \d|Hold/)
    expect(host.response.body).not_to match(/\bordered\b/)
  end
end

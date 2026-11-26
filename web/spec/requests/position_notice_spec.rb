require "rails_helper"
require_relative "../support/rules_helpers"

# Spec 027 Stories 5 and 6: what a seat is told when the host moves units, and how the host page lists an edit.
RSpec.describe "The board-changed notice and the history row", type: :request do
  include RulesHelpers
  include ActiveSupport::Testing::TimeHelpers

  around { |example| with_passphrase { example.run } }

  let(:created) { create_game(power: "germany") }
  let(:game) { created.game }
  let(:id) { game.public_id }
  let!(:england_and_token) { game.take_seat!("england") }
  let!(:france_and_token) { game.take_seat!("france") }
  let(:host) { created.session }
  let(:base) { "/games/#{id}/host/phases/1/position" }
  let(:notice) { "Orders saved before then were cleared, so check yours." }

  def phone(token) = open_session.tap { |session| session.get "/games/#{id}/seat-link", params: { token: token } }
  def page(session) = Nokogiri::HTML5(session.response.body)
  def banners(session) = page(session).css(".banner--warning").map { |node| node.text.squish }
  def hold(power, at) = json_of(rules_order(:hold, power, at))

  def add(province: "bur") = host.post "#{base}/units", params: { unit: { power: "france", type: "army", province: province, coast: "" } }

  describe "the seat's notice (AC-5.6, AC-5.7)" do
    it "tells a seat on its page and order screen that the host changed the board, with the time" do
      add
      england = phone(england_and_token.last)

      england.get "/games/#{id}"
      expect(banners(england).join).to match(/The host changed the board at \d{1,2}:\d{2} (AM|PM) [A-Z]+\. #{Regexp.escape(notice)}/)
      expect(page(england).at_css(".banner--warning time")["datetime"]).to match(/\A\d{4}-\d\d-\d\dT.*Z\z/)

      england.get "/games/#{id}/phases/1/orders"
      expect(banners(england).join).to include("The host changed the board at")
    end

    it "shows only the later time after two edits that moved units" do
      first = Time.utc(2026, 11, 26, 20, 40)
      travel_to(first) { add }
      travel_to(first + 25.minutes) { add(province: "tyr") }
      england = phone(england_and_token.last)

      england.get "/games/#{id}"

      text = banners(england).join
      expect(text).to include("9:05 PM UTC")
      expect(text).not_to include("8:40 PM UTC")
    end

    it "draws no notice after an owner edit or a date edit, or before any edit" do
      england = phone(england_and_token.last)
      england.get "/games/#{id}"
      expect(banners(england)).to be_empty

      host.put "#{base}/owners", params: { owner: { center: "bel", power: "germany" } }
      host.put "#{base}/date", params: { date: { season: "fall", year: "1901" } }
      england.get "/games/#{id}"
      expect(banners(england)).to be_empty
    end

    it "is the same for a seat that had saved orders and a seat that had none" do
      england = england_and_token.first
      england.save_orders!(game.current_phase, { "lon" => hold(:england, :lon) }, submit: true)
      add

      with_orders = phone(england_and_token.last)
      without = phone(france_and_token.last)
      [ with_orders, without ].each { |session| session.get "/games/#{id}" }

      notes = [ with_orders, without ].map { |session| page(session).at_css(".banner--warning").to_html }
      expect(notes.uniq.size).to eq(1)
    end

    it "is not drawn on a stepped-in page" do
      add
      host.post "/games/#{id}/host/seats/france/phases/1/step-in"
      host.get "/games/#{id}/host/seats/france/phases/1/orders"

      expect(banners(host).join).not_to include("The host changed the board")
    end
  end

  describe "a stale phone (AC-5.8)" do
    it "is refused the existing sentence for a unit the edit removed, and stores nothing" do
      england = phone(england_and_token.last)
      host.delete "#{base}/units/lon"

      england.put "/games/#{id}/phases/1/orders", params: { orders: { "lon" => hold(:england, :lon) } }

      expect(england.response.body).to include("You have no unit in LON.")
      expect(SavedOrder.count).to eq(0)
    end
  end

  describe "the host page's history (AC-6.2 to AC-6.4)" do
    it "lists the edit in words, with the phase and the time, under the existing heading and hook" do
      add

      host.get "/games/#{id}/host"

      history = page(host).at_css("[data-seat-history]")
      expect(history.at_css("h2").text).to eq("Seat history")
      row = history.at_css("li").text.squish
      expect(row).to include("Spring 1901 · Movement").and include("board changed: France's army added in BUR").and match(/\d{1,2}:\d{2} (AM|PM) [A-Z]+/)
      expect(history.at_css("li time")["datetime"]).to be_present
    end

    it "still says nothing has happened when there is no history (AC-6.4)" do
      host.get "/games/#{id}/host"

      expect(page(host).at_css("[data-seat-history]").text).to include("Nothing has happened to a seat yet.")
    end

    it "words every kind of edit (AC-6.3)" do
      host.post "#{base}/units", params: { unit: { power: "france", type: "fleet", province: "spa", coast: "nc" } }
      host.patch "#{base}/units/spa", params: { unit: { province: "spa", coast: "sc" } }
      host.delete "#{base}/units/spa"
      host.put "#{base}/owners", params: { owner: { center: "ven", power: "austria" } }
      host.put "#{base}/owners", params: { owner: { center: "ven", power: "nobody" } }
      host.put "#{base}/date", params: { date: { season: "fall", year: "1901" } }

      host.get "/games/#{id}/host"

      text = page(host).at_css("[data-seat-history]").text.squish
      [ "France's fleet added in SPA (north coast)", "France's fleet moved from SPA (north coast) to SPA (south coast)", "France's fleet in SPA (south coast) removed",
        "VEN given to Austria", "VEN set to nobody", "season and year set from Spring 1901 to Fall 1901" ].each { |words| expect(text).to include(words) }
    end

    it "carries no order, count, token or submitted state, and is the same whatever the seats ordered (AC-6.6)" do
      add
      host.get "/games/#{id}/host"
      before = page(host).at_css("[data-seat-history]").to_html
      england_and_token.first.save_orders!(game.current_phase, { "lon" => hold(:england, :lon) }, submit: true)
      host.get "/games/#{id}/host"

      expect(page(host).at_css("[data-seat-history]").to_html).to eq(before)
      expect(before).not_to match(/hold|submitted|token/i)
    end
  end
end

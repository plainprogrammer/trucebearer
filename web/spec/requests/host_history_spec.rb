require "rails_helper"
require_relative "../support/rules_helpers"

# Spec 026 D11 and Story 11 (#112): the host page has one history, in time order, that holds the reveals, the step-ins, the reissues and
# the board changes, and no other list of them.
RSpec.describe "The host page's one history", type: :request do
  include RulesHelpers

  around { |example| with_passphrase { example.run } }

  let(:created) { create_game(power: "germany") }
  let(:game) { created.game }
  let(:id) { game.public_id }
  let(:host) { created.session }
  let!(:england_and_token) { game.take_seat!("england") }
  let!(:france_and_token) { game.take_seat!("france") }

  def page = Nokogiri::HTML5(host.response.body)

  def history = page.at_css("[data-seat-history]")

  def rows = history.css("li").map { |row| row.text.squish }

  def open_host_page = host.get("/games/#{id}/host")

  def reissue_at(time, power) = travel_to(time) { host.post("/games/#{id}/host/seats/#{power}/reissue") }

  def reveal_at(time, number = 1) = travel_to(time) { host.post("/games/#{id}/host/phases/#{number}/reveal") }

  it "holds a reissue, a step-in and a reveal in one list, in time order (AC-11.1)" do
    reissue_at(Time.utc(2026, 11, 26, 20, 40), "france")
    travel_to(Time.utc(2026, 11, 26, 20, 41)) { host.post "/games/#{id}/host/seats/england/phases/1/step-in" }
    reveal_at(Time.utc(2026, 11, 26, 20, 42))
    open_host_page

    expect(rows).to eq([
      "Spring 1901 · Movement France seat reissued 8:40 PM UTC",
      "Spring 1901 · Movement England stepped in 8:41 PM UTC",
      "Spring 1901 · Movement revealed 8:42 PM UTC"
    ])
    expect(page.css("[data-seat-history]").size).to eq(1)
    expect(history.at_css("h2").text).to eq("History")
    expect(page.at_css("[data-history]")).to be_nil
    expect(page.css("h2, h3").map { |heading| heading.text.strip }).not_to include("Earlier results", "Revealed phases", "Seat history")
    expect(host.response.body).not_to include("Seat history")
    expect(host.response.body).not_to include("Revealed phases")
  end

  it "draws a reveal as a link to that phase's host results page, with its time and no outcome or order (AC-11.3)" do
    france_and_token.first.save_orders!(game.current_phase, { "par" => json_of(rules_order(:hold, :france, :par)) }, submit: true)
    reveal_at(Time.utc(2026, 11, 26, 20, 42))
    open_host_page

    row = history.css("li").first
    link = row.at_css("a[href='/games/#{id}/host/phases/1/results']")
    expect(link).not_to be_nil
    expect(link.text.squish).to eq("Spring 1901 · Movement revealed 8:42 PM UTC")
    expect(row.at_css("time")["datetime"]).to eq("2026-11-26T20:42:00Z")
    expect(row.css(".outcome-tag, .result-row, .power-badge")).to be_empty
    expect(row.text).not_to match(/Hold|PAR|Succeeded|Move/)

    host.get link["href"]
    expect(host.response).to have_http_status(:ok)
  end

  describe "the sentence and the list (AC-11.5)" do
    it "is only the sentence when nothing has happened" do
      open_host_page

      expect(history.at_css("h2").text).to eq("History")
      expect(history.css("p").map { |p| p.text.squish }).to eq([ "No phase has been revealed yet." ])
      expect(history.css("ul, li")).to be_empty
    end

    it "puts the sentence above a reissue row when nothing has been revealed" do
      reissue_at(Time.utc(2026, 11, 26, 20, 40), "france")
      open_host_page

      expect(history.css("p").map { |p| p.text.squish }).to eq([ "No phase has been revealed yet." ])
      expect(rows).to eq([ "Spring 1901 · Movement France seat reissued 8:40 PM UTC" ])
    end

    it "has the reveal row and no sentence once a phase is revealed" do
      reveal_at(Time.utc(2026, 11, 26, 20, 42))
      open_host_page

      expect(rows).to eq([ "Spring 1901 · Movement revealed 8:42 PM UTC" ])
      expect(history.css("p")).to be_empty
    end
  end
end

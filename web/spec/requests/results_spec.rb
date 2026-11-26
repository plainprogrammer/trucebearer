require "rails_helper"
require_relative "../support/results_fixtures"

# Spec 025 Stories 1, 6 and 7: what a seat reads after the host reveals, and what it does not read before.
RSpec.describe "Results after the reveal", type: :request do
  include ResultsFixtures

  around { |example| with_passphrase { example.run } }

  let!(:created) { create_game(power: "england") }
  let(:game) { created.game }
  let(:id) { game.public_id }
  let!(:france) { game.take_seat!("france") }
  let(:france_phone) do
    open_session.tap { |session| session.get "/games/#{id}/seat-link", params: { token: france.last } }
  end
  let(:host) { created.session }
  let(:hold) { ->(power, at) { { "format" => 1, "type" => "hold", "power" => power, "at" => at } } }

  def page(session) = Nokogiri::HTML5(session.response.body)

  def reveal(number = 1) = host.post("/games/#{id}/host/phases/#{number}/reveal")

  def stranger_body? = ->(response) { response.status == 404 && response.body.include?("We can't find that page.") }

  it "shows France's seat page England's order and the tag Succeeded once the host has revealed (AC-1.1)" do
    england = game.seats.find_by(power: "england")
    england.save_orders!(game.current_phase, { "lon" => json_of(move(:england, :lon, :nth)) }, submit: true)
    reveal

    france_phone.get "/games/#{id}"
    section = page(france_phone).at_css("section[data-results]")
    row = page(france_phone).css(".result-group[data-power=england] .result-row").find { |r| r.text.include?("Move to North Sea (NTH)") }

    expect(section).not_to be_nil
    expect(section.at_css("h2").text).to include("Spring 1901 · Movement")
    expect(row).not_to be_nil
    expect(row.at_css(".outcome-tag").text).to eq("Succeeded")
  end

  it "serves the player version on the phase's own URL, with a link back and no store header (AC-1.2)" do
    england = game.seats.find_by(power: "england")
    england.save_orders!(game.current_phase, { "lon" => json_of(move(:england, :lon, :nth)) }, submit: true)
    reveal

    france_phone.get "/games/#{id}/phases/1/results"
    results = page(france_phone)

    expect(france_phone.response).to have_http_status(:ok)
    expect(france_phone.response.headers["Cache-Control"]).to include("no-store")
    expect(results.at_css("h1").text).to eq("Results")
    expect(results.css(".result-group--reading")).to be_empty
    expect(results.at_css(".result-group[data-power=england] .outcome-tag").text).to eq("Succeeded")
    expect(results.at_css("a[href='/games/#{id}']")).to be_present
  end

  it "gives the stranger response for the open phase, a later one, 7, 01, 1.5 and abc (AC-1.8)" do
    reveal
    [ "2", "3", "7", "01", "1.5", "abc", "0" ].each do |number|
      path = "/games/#{id}/phases/#{number}/results"
      france_phone.get path
      stranger = open_session.tap { |session| session.get path }

      expect(stranger_body?.call(france_phone.response)).to be(true), number
      expect(comparable(france_phone.response, id)).to eq(comparable(stranger.response, id)), number
    end
  end

  it "has no results section, no Earlier results list and no reveal row before any reveal (AC-1.7)" do
    france_phone.get "/games/#{id}"
    host.get "/games/#{id}/host"

    [ france_phone, host ].each do |session|
      expect(page(session).css("section[data-results]")).to be_empty
      expect(session.response.body).not_to include("Earlier results")
    end
    expect(page(host).css("[data-seat-history] li")).to be_empty
  end

  it "starts the seat page's results with a Skip to orders link that reaches the Enter orders button (AC-1.9)" do
    reveal
    france_phone.get "/games/#{id}"

    expect(page(france_phone).at_css("section[data-results] a.button[href='#enter-orders']").text).to eq("Skip to orders")
    expect(page(france_phone).at_css("a#enter-orders").text).to eq("Enter orders")
  end

  it "lists earlier phases newest first with links that work, and none with one revealed phase (AC-6.1, AC-6.2)" do
    reveal
    france_phone.get "/games/#{id}"
    expect(france_phone.response.body).not_to include("Earlier results")

    reveal(2)
    france_phone.get "/games/#{id}"
    section = page(france_phone).at_css("section[data-results]")
    links = section.css("ul.list a").map { |link| [ link.text, link["href"] ] }

    expect(section.at_css("h2").text).to include("Fall 1901")
    expect(links).to eq([ [ "Spring 1901 · Movement", "/games/#{id}/phases/1/results" ] ])
    france_phone.get links.first.last
    expect(france_phone.response).to have_http_status(:ok)
    expect(page(france_phone).at_css("h2").text).to include("Spring 1901")
  end

  it "gives the host no Earlier results list: each revealed phase is a row of the History, a link that works (AC-6.4, spec 026 D11)" do
    reveal
    reveal(2)
    host.get "/games/#{id}/host"
    doc = page(host)
    links = doc.css("[data-seat-history] li a").map { |link| [ link.text.squish.sub(/ \d{1,2}:\d{2} [AP]M [A-Z]+\z/, ""), link["href"] ] }

    expect(host.response.body).not_to include("Earlier results")
    expect(doc.at_css("[data-history]")).to be_nil
    expect(doc.at_css("section[data-results] h2").text).to include("Fall 1901") # the latest phase's results section is still drawn
    expect(links).to eq([ [ "Spring 1901 · Movement revealed", "/games/#{id}/host/phases/1/results" ], [ "Fall 1901 · Movement revealed", "/games/#{id}/host/phases/2/results" ] ])
    links.each do |_, href|
      host.get href
      expect(host.response).to have_http_status(:ok)
    end
    france_phone.get "/games/#{id}"
    expect(france_phone.response.body).to include("Earlier results") # the seat page keeps its list (spec 025 D7)
  end

  describe "the four views of a revealed phase" do
    let(:views) do
      -> { { "seat page" => [ france_phone, "/games/#{id}" ], "host page" => [ host, "/games/#{id}/host" ],
             "seat results" => [ france_phone, "/games/#{id}/phases/1/results" ], "host results" => [ host, "/games/#{id}/host/phases/1/results" ] } }
    end

    def each_view
      views.call.each do |name, (session, path)|
        session.get path
        yield name, session
      end
    end

    it "shows no practice note on any results view (spec 029 AC-3.3)" do
      revealed_phase_with(game, outcomes: [ [ hold.("england", "lon"), :held, true, false ] ])
      each_view do |name, session|
        expect(page(session).css(".practice-note")).to be_empty, name
        expect(page(session).text).not_to include("Practice results"), name
      end
    end

    it "shows one paradox banner for a paradox result and none otherwise (AC-7.4)" do
      revealed_phase_with(game, outcomes: [], paradox: true)
      each_view { |name, session| expect(page(session).css("section[data-results] [data-paradox]").size).to eq(1), name }

      other = create_game(power: "england")
      revealed_phase_with(other.game, outcomes: [])
      other.session.get "/games/#{other.game.public_id}/host"
      expect(page(other.session).css("[data-paradox]")).to be_empty
    end

    it "says nothing that calls the results real or official (AC-7.3)" do
      revealed_phase_with(game, outcomes: [ [ hold.("england", "lon"), :held, true, false ] ])
      each_view do |name, session|
        text = page(session).css("section[data-results]").text
        expect(text).not_to match(/official|licensed|authorized|confirmed|verified|\bfinal\b|real results/i), name
        expect(text).not_to include("Practice results"), name
      end
    end
  end

  it "answers the stranger page on both results routes for the open phase, and for a stranger once revealed (AC-5.2)" do
    stranger = open_session
    [ "/games/#{id}/phases/1/results", "/games/#{id}/host/phases/1/results" ].each do |path|
      [ france_phone, stranger ].each do |session|
        session.get path
        expect(stranger_body?.call(session.response)).to be(true), path
      end
    end

    reveal
    [ "/games/#{id}/phases/1/results", "/games/#{id}/host/phases/1/results" ].each do |path|
      stranger.get path
      expect(stranger_body?.call(stranger.response)).to be(true), path
    end
  end
end

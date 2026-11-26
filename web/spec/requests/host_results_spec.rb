require "rails_helper"
require_relative "../support/results_fixtures"

# Spec 025 Story 2: the host's reading view of a revealed phase.
RSpec.describe "The host's reading view", type: :request do
  include ResultsFixtures

  around { |example| with_passphrase { example.run } }

  let!(:created) { create_game(power: "england") }
  let(:game) { created.game }
  let(:id) { game.public_id }
  let(:host) { created.session }
  let!(:france) { game.take_seat!("france") }
  let(:france_phone) { open_session.tap { |session| session.get "/games/#{id}/seat-link", params: { token: france.last } } }
  let(:hold) { ->(power, at) { { "format" => 1, "type" => "hold", "power" => power, "at" => at } } }

  def page(session = host) = Nokogiri::HTML5(session.response.body)

  def stranger_body?(response) = response.status == 404 && response.body.include?("We can't find that page.")

  let(:outcomes) { [ [ hold.("england", "lon"), :held, true, false ], [ hold.("france", "par"), :held, true, true ] ] }

  it "shows the host the reading view above the Host section, and the seat page the player version (AC-2.1, AC-2.4)" do
    revealed_phase_with(game, outcomes: outcomes, dislodged: [ %w[france army par] ])

    host.get "/games/#{id}/host"
    body = page
    expect(body.css("section[data-results] .result-group--reading").size).to eq(2)
    expect(body.css("main > div.stack > *").map { |node| node.name == "section" && node["data-results"] ? :results : (node["class"].to_s.include?("host-section") ? :host : nil) }.compact).to eq(%i[results host])

    host.get "/games/#{id}"
    expect(page.css("section[data-results] .result-group").size).to eq(2)
    expect(page.css(".result-group--reading")).to be_empty # the host's own seat page is the player version
  end

  it "starts with one banner for each dislodged unit, counted like the Dislodged tags, and lists a group holding one first (AC-2.2)" do
    revealed_phase_with(game, outcomes: outcomes, dislodged: [ %w[france army par] ])
    host.get "/games/#{id}/host"
    section = page.at_css("section[data-results]")

    expect(section.css("[data-dislodged]").size).to eq(1)
    expect(section.css("[data-dislodged]").size).to eq(section.css(".outcome-tag--dislodged").size)
    expect(section.at_css("[data-dislodged]").text).to eq("Warning: France's army in PAR was dislodged. Settle it by hand.")
    expect(section.css(".result-group").map { |group| group["data-power"] }).to eq(%w[france england])
    expect(section.element_children.map(&:name).index("p")).to be < section.element_children.map(&:name).index("section") # banners come before the groups
    expect(page.css("[data-dislodged]").size).to eq(1) # once on the page: the page's own banner loop is gone
  end

  it "serves the host results page to the host only (AC-2.3)" do
    revealed_phase_with(game, outcomes: outcomes, dislodged: [ %w[france army par] ])
    host.get "/games/#{id}/host/phases/1/results"

    expect(host.response).to have_http_status(:ok)
    expect(page.at_css("h1").text).to eq("Results")
    expect(page.css(".result-group--reading").size).to eq(2)
    expect(page.at_css("a[href='/games/#{id}/host']")).to be_present

    junk = open_session.tap { |session| session.cookies["host_#{id}"] = "junk" }
    [ france_phone, open_session, junk, seat_only_session(created) ].each do |session|
      session.get "/games/#{id}/host/phases/1/results"
      expect(stranger_body?(session.response)).to be(true)
    end
    [ "2", "3", "01", "x" ].each do |number|
      host.get "/games/#{id}/host/phases/#{number}/results"
      expect(stranger_body?(host.response)).to be(true), number
    end
  end

  it "shows an earlier phase's Dislodged tags and no banner there, and banners for the latest phase only (AC-2.6)" do
    revealed_phase_with(game, outcomes: outcomes, dislodged: [ %w[france army par] ])
    revealed_phase_with(game, outcomes: [ [ hold.("england", "lon"), :held, true, true ] ], dislodged: [ %w[england fleet lon] ])

    host.get "/games/#{id}/host/phases/1/results"
    expect(page.css(".outcome-tag--dislodged").size).to eq(1)
    expect(page.css("[data-dislodged]")).to be_empty

    host.get "/games/#{id}/host/phases/2/results"
    expect(page.css("[data-dislodged]").map(&:text)).to eq([ "Warning: England's fleet in LON was dislodged. Settle it by hand." ])

    host.get "/games/#{id}/host"
    expect(page.css("[data-dislodged]").map(&:text)).to eq([ "Warning: England's fleet in LON was dislodged. Settle it by hand." ])
    expect(page.css("section[data-results] ul.list a").map { |link| link["href"] }).to eq([ "/games/#{id}/host/phases/1/results" ])
  end

  it "shows the host no order of the open phase, whatever the seats saved after the reveal (AC-2.5)" do
    revealed_phase_with(game, outcomes: outcomes)
    england = game.seats.find_by(power: "england")
    england.save_orders!(game.current_phase, { "lon" => json_of(move(:england, :lon, :eng)) }, submit: true)

    [ "/games/#{id}/host", "/games/#{id}/host/phases/2/reveal" ].each do |path|
      host.get path
      expect(page.css("select, option")).to be_empty, path
      expect(host.response.body).not_to match(/\bordered\b|\d of \d/), path
      expect(host.response.body).not_to include("Move to English Channel"), path
    end
  end
end

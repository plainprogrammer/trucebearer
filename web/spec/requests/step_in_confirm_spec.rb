require "rails_helper"
require_relative "../support/rules_helpers"

# Spec 026 Story 1: the host asks to step into France's seat and gets a confirmation that names France. Nothing is recorded until
# the host confirms.
RSpec.describe "The step-in confirmation", type: :request do
  include RulesHelpers

  around { |example| with_passphrase { example.run } }

  let(:created) { create_game(power: "germany") } # the host holds Germany
  let(:game) { created.game }
  let(:id) { game.public_id }
  let!(:france_and_token) { game.take_seat!("france") }
  let(:france) { france_and_token.first }
  let(:path) { "/games/#{id}/host/seats/france/phases/1/step-in" }
  let(:host) { created.session }

  def page = Nokogiri::HTML5(host.response.body)

  it "names France on a .confirm page and records nothing (AC-1.1)" do
    host.get path

    expect(host.response).to have_http_status(:ok)
    expect(page.at_css(".confirm h1").text).to include("France")
    expect(page.at_css(".confirm button").text).to eq("Step into France")
    expect(StepIn.count).to eq(0)
    expect(cookie_lines(host.response).grep(/step_in_/)).to be_empty
  end

  it "is a danger confirmation that names the phase and says what it means, and shows no order (AC-1.2)" do
    france.save_orders!(game.current_phase, { "par" => json_of(rules_order(:hold, :france, :par)) })
    host.get path

    confirm = page.at_css(".confirm")
    expect(confirm.at_css("button.button--danger")).to be_present
    text = confirm.text.squish
    expect(text).to include("Spring 1901")
    expect(text).to include("recorded")
    expect(text).to include("30 minutes")
    expect(text).to include("Leave")
    expect(host.response.body).not_to include("Hold")
    expect(host.response.body).not_to include("&quot;hold&quot;")
    expect(host.response.body).not_to match(/\bordered\b|\d of \d/)
  end

  it "goes back to the host page with Back, and a GET writes nothing (AC-1.3)" do
    host.get path

    expect(page.at_css(".confirm a.button--secondary")["href"]).to eq("/games/#{id}/host")
    expect(StepIn.count).to eq(0)
  end

  describe "who may open it (AC-1.4, AC-1.5)" do
    it "gives a seat's phone, a stranger and another game's host the stranger response" do
      france_phone = open_session.tap { |session| session.get "/games/#{id}/seat-link", params: { token: france_and_token.last } }
      other_host = create_game(power: "england").session
      missing = "/games/#{GameFlow::MISSING_ID}/host/seats/france/phases/1/step-in"

      [ france_phone, open_session, other_host ].each do |session|
        session.get path
        existing = comparable(session.response, id)
        session.get missing
        expect(existing).to eq(comparable(session.response, GameFlow::MISSING_ID))
        expect(session.response).to have_http_status(:not_found)
      end
      expect(StepIn.count).to eq(0)
    end

    it "gives the host the stranger response for their own power, an empty power and a non-power" do
      %w[germany italy nope].each do |power|
        host.get "/games/#{id}/host/seats/#{power}/phases/1/step-in"
        expect(host.response).to have_http_status(:not_found), power
      end
    end
  end

  describe "the phase number (AC-1.7)" do
    it "sends a revealed number to the open phase's confirmation and writes nothing" do
      game.current_phase.reveal!
      host.get path

      expect(host.response).to have_http_status(:see_other)
      expect(URI(host.response.location).path).to eq("/games/#{id}/host/seats/france/phases/2/step-in")
      host.follow_redirect!
      expect(page.at_css(".banner--info").text).to include("already revealed")
      expect(StepIn.count).to eq(0)
    end

    it "gives a later, unknown or malformed number the stranger response" do
      %w[9 01 1x].each do |number|
        host.get "/games/#{id}/host/seats/france/phases/#{number}/step-in"
        expect(host.response).to have_http_status(:not_found), number
      end
    end
  end
end

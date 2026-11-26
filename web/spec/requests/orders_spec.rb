require "rails_helper"
require_relative "../support/rules_helpers"

# Spec 022 Story 2 and 3 over HTTP: the plain orders page and the endpoint behind it. England starts with a fleet in LON,
# a fleet in EDI and an army in LVP.
RSpec.describe "Saving orders", type: :request do
  include RulesHelpers

  around { |example| with_passphrase { example.run } }

  let(:created) { create_game(power: "england") }
  let(:game) { created.game }
  let(:id) { game.public_id }
  let(:path) { "/games/#{id}/phases/1/orders" }
  let(:england) { game.seats.find_by(power: "england") }
  let(:phase) { game.current_phase }
  let(:phone) { created.session }

  def page = Nokogiri::HTML5(phone.response.body)

  def reveal_directly
    phase.update_columns(adjudication: RulesEngine.adjudicate(RulesEngine.starting_position, []), revealed_at: Time.current)
    game.phases.create!(number: 2, position: RulesEngine.starting_position)
  end

  # The page replaced spec 022's plain form (spec 023 AC-8.2). The equivalents of its examples:
  describe "the order screen (replaces AC-2.11; spec 023 AC-1.1 to AC-1.6)" do
    def rows = page.css(".unit-row__body").map { |row| row.text.squish }

    it "has a row for each of the seat's units, none of another power's, and no select" do
      phone.get path

      expect(phone.response).to have_http_status(:ok)
      expect(page.css("a.unit-row").map { |a| a["href"] }).to eq(%w[edi lon lvp].map { |province| "#{path}/#{province}" })
      expect(rows).to eq([ "Fleet in Edinburgh (EDI) holds", "Fleet in London (LON) holds", "Army in Liverpool (LVP) holds" ])
      expect(page.css("select, option")).to be_empty
    end

    it "shows the stored order in words on its row, and 'holds' on a unit that has none" do
      england.save_orders!(phase, { "lon" => json_of(move(:england, :lon, :nth)) })

      phone.get path

      expect(rows).to eq([ "Fleet in Edinburgh (EDI) holds", "Fleet in London (LON) Move to North Sea (NTH)", "Army in Liverpool (LVP) holds" ])
    end

    it "shows the seat's own state and count in the submit bar, and the phase header with its badge" do
      england.save_orders!(phase, { "lon" => json_of(rules_order(:hold, :england, :lon)) }, submit: true)

      phone.get path

      expect(page.at_css(".phase-header__title").text).to eq("Spring 1901 · Movement")
      expect(page.at_css(".phase-header .power-badge--england")).to be_present
      expect(page.at_css(".submit-bar__state").text).to eq("Submitted · 1 of 3 ordered")
    end

    it "has one Submit button in the action area, in a form that PUTs to the endpoint with submit=1 (D9)" do
      phone.get path

      form = page.at_css(".app-actions .submit-bar form")
      expect(form["action"]).to eq(path)
      expect(form.at_css("input[name=_method]")["value"]).to eq("put")
      expect(form.at_css("button[name=submit][value='1']").text.squish).to eq("Submit orders 0 of 3 ordered")
      expect(page.css(".app-actions button").size).to eq(1)
    end
  end

  describe "saving (AC-2.1, AC-3.1)" do
    it "stores an order for each unit and goes back to the page, saved, with no banner (spec 023 D4)" do
      orders = { "lon" => json_of(move(:england, :lon, :nth)), "edi" => json_of(rules_order(:hold, :england, :edi)),
                 "lvp" => json_of(move(:england, :lvp, :yor)) }

      phone.put path, params: { orders: orders }

      expect(phone.response).to have_http_status(:see_other)
      expect(phone.response.location).to eq("http://www.example.com#{path}")
      expect(SavedOrder.where(seat_id: england.id, phase_id: phase.id).count).to eq(3)
      phone.follow_redirect!
      expect(page.css(".banner")).to be_empty
      expect(page.at_css(".save-status__rest").text).to eq("Saved")
      expect(page.at_css(".submit-bar").text.squish).to include("3 of 3 ordered")
    end

    it "submits when asked, and the banner says so (AC-3.1)" do
      phone.put path, params: { orders: { "lon" => json_of(rules_order(:hold, :england, :lon)) }, submit: "1" }
      phone.follow_redirect!

      expect(england.submitted?(phase)).to be(true)
      expect(page.css(".banner--info").map(&:text)).to eq([ "Submitted." ])
      expect(page.text).to match(/\bSubmitted\b/)
    end

    it "submits alone, with no orders at all" do
      phone.put path, params: { submit: "1" }

      expect(phone.response).to have_http_status(:see_other)
      expect(england.submitted?(phase)).to be(true)
      expect(SavedOrder.count).to eq(0)
    end

    it "does not lock after a submit: the next edit is accepted and puts the seat back to not submitted (AC-3.6, AC-3.2)" do
      phone.put path, params: { submit: "1" }
      phone.put path, params: { orders: { "lon" => json_of(rules_order(:hold, :england, :lon)) } }

      expect(phone.response).to have_http_status(:see_other)
      expect(england.submitted?(phase)).to be(false)
    end

    it "keeps only the banner's kind and text in the flash (AC-7.7)" do
      order = json_of(move(:england, :lon, :nth))
      phone.put path, params: { orders: { "lon" => order }, submit: "1" }

      expect(phone.flash.to_h).to eq({ "banner" => { "kind" => "info", "text" => "Submitted." } })
      phone.follow_redirect!
      phone.put path, params: { orders: { "lon" => json_of(rules_order(:hold, :england, :lon)) } } # a plain save sets no flash (spec 023 D4)
      expect(phone.flash.to_h).to be_empty
    end
  end

  describe "what is refused (AC-2.2 to AC-2.6)" do
    it "gives 422 and the sentence in an error banner, storing nothing, for an illegal order" do
      phone.put path, params: { orders: { "lon" => json_of(move(:england, :lon, :bel)), "lvp" => json_of(move(:england, :lvp, :yor)) } }

      expect(phone.response).to have_http_status(:unprocessable_content)
      expect(page.css(".banner--danger").map(&:text)).to eq([ "Error: The fleet in LON can't reach there." ])
      expect(SavedOrder.count).to eq(0)
      expect(page.css(".unit-row").size).to eq(3)
      expect(page.at_css(".save-status__rest").text).to eq("Not saved")
    end

    it "gives 422 for another power's unit and for another power's name" do
      phone.put path, params: { orders: { "par" => json_of(rules_order(:hold, :france, :par)) } }
      expect(page.css(".banner--danger").map(&:text)).to eq([ "Error: You have no unit in PAR." ])

      phone.put path, params: { orders: { "lon" => json_of(rules_order(:hold, :france, :lon)) } }
      expect(page.css(".banner--danger").map(&:text)).to eq([ "Error: That order isn't for your power." ])
      expect(SavedOrder.count).to eq(0)
    end

    it "gives 422 when orders is not a hash of text, or a value is not text" do
      [ { orders: "lon" }, { orders: [ "a" ] }, { orders: { "lon" => { "at" => "lon" } } } ].each do |params|
        phone.put path, params: params
        expect(phone.response).to have_http_status(:unprocessable_content), params.inspect
        expect(page.css(".banner--danger").map(&:text)).to eq([ "Error: That order couldn't be read." ])
      end
      expect(SavedOrder.count).to eq(0)
    end

    it "keeps what was stored when a later save is refused" do
      england.save_orders!(phase, { "lon" => json_of(move(:england, :lon, :nth)) })

      phone.put path, params: { orders: { "lon" => json_of(move(:england, :lon, :bel)) } }

      expect(england.orders_for(phase)["lon"]).to eq(move(:england, :lon, :nth))
    end
  end

  describe "who may use it (AC-2.12)" do
    let(:order) { json_of(rules_order(:hold, :england, :lon)) }

    def stranger_page?(response) = response.status == 404 && response.body.include?("We can't find that page.")

    it "gives the stranger response, and stores nothing, with no cookie, with the host cookie only, and with another game's seat" do
      host_only = open_session
      host_only.get "/games/#{id}/host-link", params: { token: created.host_token }
      other = create_game(power: "france")

      [ open_session, host_only, other.session ].each do |session|
        session.get path
        expect(stranger_page?(session.response)).to be(true)
        session.put path, params: { orders: { "lon" => order }, submit: "1" }
        expect(stranger_page?(session.response)).to be(true)
      end
      expect(SavedOrder.count).to eq(0)
      expect(Submission.count).to eq(0)
    end

    it "gives the stranger response for a number that is not one of the game's phases" do
      %w[2 01 0 1abc 1.5 -1].each do |number|
        phone.get "/games/#{id}/phases/#{number}/orders"
        expect(stranger_page?(phone.response)).to be(true), number
        phone.put "/games/#{id}/phases/#{number}/orders", params: { orders: { "lon" => order } }
        expect(stranger_page?(phone.response)).to be(true), number
      end
      expect(SavedOrder.count).to eq(0)
    end
  end

  describe "caching (AC-7.6)" do
    it "tells the browser not to keep the page or the redirect, and Turbo not to snapshot the page" do
      phone.get path
      expect(phone.response.headers["Cache-Control"]).to include("no-store")
      expect(page.at_css("meta[name=turbo-cache-control][content=no-cache]")).to be_present

      phone.put path, params: { submit: "1" }
      expect(phone.response.headers["Cache-Control"]).to include("no-store")
    end
  end

  describe "after the host has revealed the phase (AC-6.1 to AC-6.3, the page and the refusal)" do
    before { reveal_directly }

    it "refuses a save with 409 and a sentence, and links to the current phase" do
      phone.put path, params: { orders: { "lon" => json_of(rules_order(:hold, :england, :lon)) }, submit: "1" }

      expect(phone.response).to have_http_status(:conflict)
      expect(page.css(".banner--danger").map(&:text)).to eq([ "Error: The host has already revealed this phase. Your orders were not saved." ])
      expect(page.at_css("a.button[href='/games/#{id}/phases/2/orders']")).to be_present
      expect(SavedOrder.count).to eq(0)
      expect(Submission.count).to eq(0)
    end

    it "sends a read to that phase's results, not the form (spec 025 D5; it was a 409 page under spec 022 AC-6.3)" do
      phone.get path

      expect(phone.response).to have_http_status(:see_other)
      expect(phone.response.headers["Location"]).to end_with("/games/#{id}/phases/1/results")
      expect(phone.response.headers["Cache-Control"]).to include("no-store")
      expect(phone.response.body).not_to include("<form")
    end
  end
end

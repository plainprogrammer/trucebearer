require "rails_helper"
require_relative "../support/rules_helpers"

# Spec 022 Story 4 to 6 over HTTP: the host reveals, a repeat does nothing, a failure changes nothing, and a late save is refused.
RSpec.describe "Revealing a phase", type: :request do
  include RulesHelpers

  around { |example| with_passphrase { example.run } }

  let(:created) { create_game(power: "england") }
  let(:game) { created.game }
  let(:id) { game.public_id }
  let(:reveal_path) { "/games/#{id}/host/phases/1/reveal" }
  let(:host) { created.session }
  let(:england) { game.seats.find_by(power: "england") }

  def page(session = host) = Nokogiri::HTML5(session.response.body)

  def stranger_page?(response) = response.status == 404 && response.body.include?("We can't find that page.")

  describe "who may reveal (AC-4.4)" do
    it "gives the stranger response, and changes nothing, to a seat without the host cookie, to no cookie, and to another game's host" do
      other = create_game(power: "france")

      [ seat_only_session(created), open_session, other.session ].each do |session|
        session.post reveal_path
        expect(stranger_page?(session.response)).to be(true)
      end
      expect(game.reload.phases.count).to eq(1)
      expect(game.current_phase.adjudication).to be_nil
    end

    it "gives the stranger response for a later, unknown or malformed number" do
      [ "2", "01", "0", "1abc", "1.5" ].each do |number|
        host.post "/games/#{id}/host/phases/#{number}/reveal"
        expect(stranger_page?(host.response)).to be(true), number
      end
      expect(game.phases.count).to eq(1)
    end
  end

  describe "the reveal (AC-4.5)" do
    it "locks, adjudicates and opens the next phase, and the host page says what happened" do
      england.save_orders!(game.current_phase, { "lon" => json_of(move(:england, :lon, :nth)) }, submit: true)

      host.post reveal_path

      expect(host.response).to have_http_status(:see_other)
      expect(host.response.location).to eq("http://www.example.com/games/#{id}/host")
      expect(game.phases.count).to eq(2)
      expect(game.history.first.adjudication.outcomes.first.result).to eq(:succeeded)
      host.follow_redirect!
      expect(page.css(".banner--info").map(&:text)).to eq([ "Spring 1901 · Movement was revealed. It is now Fall 1901 · Movement." ])
      expect(page.at_css(".phase-header__title").text).to eq("Fall 1901 · Movement")
      expect(page.at_css("[data-history]").text).to include("Spring 1901 · Movement")
    end

    it "reveals while joining is still open (AC-4.13)" do
      expect(game).to be_open

      host.post reveal_path

      expect(game.reload.phases.count).to eq(2)
    end
  end

  describe "a repeat (AC-4.8)" do
    it "adjudicates once however often the button is pressed, and says so the second time" do
      allow(RulesEngine).to receive(:adjudicate).and_call_original

      host.post reveal_path
      host.post reveal_path

      expect(RulesEngine).to have_received(:adjudicate).once
      expect(game.phases.count).to eq(2)
      expect(host.response).to have_http_status(:see_other)
      host.follow_redirect!
      expect(page.css(".banner--info").map(&:text)).to eq([ "That phase was already revealed." ])
    end

    it "does not reveal the next phase when the old page is sent again (D7)" do
      host.post reveal_path
      host.post reveal_path
      host.post reveal_path

      expect(game.phases.count).to eq(2)
      expect(game.current_phase.number).to eq(2)
    end
  end

  describe "when it fails (AC-4.10)" do
    it "answers 422 without the error's message, logs the class and no message, and changes nothing" do
      allow(RulesEngine).to receive(:adjudicate).and_raise(RulesEngine::InvalidInput, "secret order text")
      log = StringIO.new
      original = Rails.logger
      Rails.logger = ActiveSupport::Logger.new(log)

      host.post reveal_path

      expect(host.response).to have_http_status(:unprocessable_content)
      expect(page.css(".banner--danger").map(&:text)).to eq([ "Error: Nothing was changed. The phase is still open." ])
      expect(host.response.body).not_to include("secret order text")
      expect(log.string).to include("reveal failed")
      expect(log.string).not_to include("secret order text")
      expect(game.reload.phases.count).to eq(1)
      expect(game.current_phase.adjudication).to be_nil
    ensure
      Rails.logger = original
    end

    it "lets the host try again once the cause is gone" do
      allow(RulesEngine).to receive(:adjudicate).and_raise(RulesEngine::InvalidInput, "once")
      host.post reveal_path
      allow(RulesEngine).to receive(:adjudicate).and_call_original

      host.post reveal_path

      expect(host.response).to have_http_status(:see_other)
      expect(game.reload.phases.count).to eq(2)
    end
  end

  describe "no undo (AC-4.12)" do
    it "has no route that reopens, undoes or deletes a phase" do
      routes = Rails.application.routes.routes.map { |route| [ route.verb, route.path.spec.to_s.sub("(.:format)", "") ] }
      phase_routes = routes.select { |_, path| path.include?("phases") }

      expect(phase_routes).to match_array([
        [ "GET", "/games/:public_id/phases/:number/orders" ], [ "PUT", "/games/:public_id/phases/:number/orders" ],
        [ "GET", "/games/:public_id/host/phases/:number/reveal" ], [ "POST", "/games/:public_id/host/phases/:number/reveal" ]
      ])
      expect(routes.map(&:last).grep(/reopen|undo|unreveal/)).to be_empty
    end
  end

  describe "a save after the reveal (AC-6.1 to AC-6.3)" do
    it "is refused with 409 and the sentence, and nothing lands in the next phase" do
      england_phone = created.session
      england_phone.get "/games/#{id}/phases/1/orders" # the page is open on the phone
      other_host = open_session
      other_host.get "/games/#{id}/host-link", params: { token: created.host_token }
      other_host.post reveal_path

      england_phone.put "/games/#{id}/phases/1/orders", params: { orders: { "lon" => json_of(rules_order(:hold, :england, :lon)) }, submit: "1" }

      expect(england_phone.response).to have_http_status(:conflict)
      expect(page(england_phone).css(".banner--danger").map(&:text)).to eq([ "Error: The host has already revealed this phase. Your orders were not saved." ])
      expect(page(england_phone).at_css("a.button[href='/games/#{id}/phases/2/orders']")).to be_present
      expect(SavedOrder.count).to eq(0)
      expect(Submission.count).to eq(0)
      england_phone.get "/games/#{id}/phases/1/orders"
      expect(england_phone.response).to have_http_status(:conflict)
    end
  end

  describe "dislodged units (AC-5.4)" do
    def stub_result_with_dislodged_unit
      result = RulesEngine.adjudicate(RulesEngine.starting_position, []).to_h
      result["position"]["dislodged_units"] = [ { "unit" => unit_hash(:austria, :army, :ser), "attacker_from" => "bul", "by_convoy" => false } ]
      allow(RulesEngine).to receive(:adjudicate).and_return(RulesEngine.load_adjudication(result))
    end

    it "names each on the host page in a warning banner, and keeps them off the board of the next phase" do
      stub_result_with_dislodged_unit

      host.post reveal_path
      host.get "/games/#{id}/host"

      expect(page.css(".banner--warning").map(&:text)).to eq([ "Warning: Austria's army in SER was dislodged. Settle it by hand." ])
      expect(game.current_phase.position.dislodged_units).to be_empty
      expect(game.history.first.adjudication.position.dislodged_units.size).to eq(1)
    end

    it "shows none when nothing was dislodged" do
      host.post reveal_path
      host.get "/games/#{id}/host"

      expect(page.css(".banner--warning")).to be_empty
    end
  end
end

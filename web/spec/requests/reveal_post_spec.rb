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
      captured = ActiveSupport::Logger.new(log)
      Rails.logger.broadcast_to(captured) # reaches the controller's and Active Record's loggers too

      host.post reveal_path

      expect(host.response).to have_http_status(:unprocessable_content)
      expect(page.css(".banner--danger").map(&:text)).to eq([ "Error: Nothing was changed. The phase is still open." ])
      expect(host.response.body).not_to include("secret order text")
      expect(log.string).to include("reveal failed")
      expect(log.string).not_to include("secret order text")
      expect(game.reload.phases.count).to eq(1)
      expect(game.current_phase.adjudication).to be_nil
    ensure
      Rails.logger.stop_broadcasting_to(captured)
    end

    it "answers 422 the same way when the next position cannot be built (AC-5.6)" do
      allow(RulesEngine).to receive(:next_movement_position).and_raise(RulesEngine::InvalidInput, "secret position text")

      host.post reveal_path

      expect(host.response).to have_http_status(:unprocessable_content)
      expect(page.css(".banner--danger").map(&:text)).to eq([ "Error: Nothing was changed. The phase is still open." ])
      expect(host.response.body).not_to include("secret position text")
      expect(game.reload.phases.count).to eq(1)
      expect(game.current_phase.adjudication).to be_nil
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

  describe "the refresh the reveal sends (spec 025 AC-4.2, AC-4.5)" do
    it "sends one attribute although the reveal request carries a request id, and redirects as usual" do
      host.post reveal_path, headers: { "X-Turbo-Request-Id" => "11111111-2222-3333-4444-555555555555" }

      message = JSON.parse(ActionCable.server.pubsub.broadcasts("results:#{id}").first)
      expect(Nokogiri::HTML5.fragment(message).children.first.attributes.keys).to eq([ "action" ])
      expect(host.response).to have_http_status(:see_other)
      expect(host.response.headers["Location"]).to end_with("/games/#{id}/host")
    end

    it "answers the same redirect when the cable raises, and stores the reveal" do
      allow(Turbo::StreamsChannel).to receive(:broadcast_refresh_to).and_raise(RuntimeError)
      host.post reveal_path

      expect(host.response).to have_http_status(:see_other)
      expect(host.response.headers["Location"]).to end_with("/games/#{id}/host")
      expect(game.history.count).to eq(1)
    end
  end

  describe "no undo (AC-4.12)" do
    it "has no route that reopens, undoes or deletes a phase" do
      routes = Rails.application.routes.routes.map { |route| [ route.verb, route.path.spec.to_s.sub("(.:format)", "") ] }
      phase_routes = routes.select { |_, path| path.include?("phases") }

      expect(phase_routes).to match_array([
        [ "GET", "/games/:public_id/phases/:number/orders" ], [ "PUT", "/games/:public_id/phases/:number/orders" ],
        [ "GET", "/games/:public_id/phases/:number/orders/:province" ],
        # Spec 025: the results of a revealed phase, read-only pages for a seat and for the host.
        [ "GET", "/games/:public_id/phases/:number/results" ], [ "GET", "/games/:public_id/host/phases/:number/results" ],
        [ "GET", "/games/:public_id/host/phases/:number/reveal" ], [ "POST", "/games/:public_id/host/phases/:number/reveal" ],
        # Spec 026: the step-in confirmation and its record carry the phase number, and neither touches a phase.
        [ "GET", "/games/:public_id/host/seats/:power/phases/:number/step-in" ], [ "POST", "/games/:public_id/host/seats/:power/phases/:number/step-in" ],
        [ "GET", "/games/:public_id/host/seats/:power/phases/:number/orders" ], [ "PUT", "/games/:public_id/host/seats/:power/phases/:number/orders" ],
        [ "GET", "/games/:public_id/host/seats/:power/phases/:number/orders/:province" ]
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
      england_phone.get "/games/#{id}/phases/1/orders" # a read is sent to the results (spec 025 D5); the refused write above keeps its 409
      expect(england_phone.response).to have_http_status(:see_other)
    end
  end

  describe "dislodged units (AC-5.4)" do
    # A real dislodgement: Germany's supported attack on France's holding army in Burgundy (spec 029 AC-2.1).
    def save_dislodging_orders(phase = game.current_phase)
      phase.update_columns(position: rules_position(units: [ %i[germany army mun], %i[germany army ruh], %i[france army bur] ]))
      germany = game.seats.find_by(power: "germany") || game.take_seat!("germany").first
      germany.save_orders!(phase.reload, { "mun" => json_of(move(:germany, :mun, :bur)),
                                           "ruh" => json_of(rules_order(:support_move, :germany, :ruh, from: "mun", to: "bur")) }, submit: true)
    end

    it "names each on the host page in a warning banner, and keeps them off the board of the next phase" do
      save_dislodging_orders

      host.post reveal_path
      host.get "/games/#{id}/host"

      expect(page.css(".banner--warning").map(&:text)).to eq([ "Warning: France's army in BUR was dislodged. Settle it by hand." ])
      expect(page.css("[data-dislodged]").size).to eq(page.css(".outcome-tag--dislodged").size) # one banner for each Dislodged tag (spec 025 AC-2.2)
      expect(game.current_phase.position.dislodged_units).to be_empty
      expect(game.history.first.adjudication.position.dislodged_units.size).to eq(1)
    end

    it "shows only the latest revealed phase's dislodged units" do
      save_dislodging_orders
      host.post reveal_path
      host.post "/games/#{id}/host/phases/2/reveal"
      host.get "/games/#{id}/host"

      expect(page.css(".banner--warning")).to be_empty
      expect(game.history.map(&:number)).to eq([ 1, 2 ])
    end

    it "shows none when nothing was dislodged" do
      host.post reveal_path
      host.get "/games/#{id}/host"

      expect(page.css(".banner--warning")).to be_empty
    end
  end
end

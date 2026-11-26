require "rails_helper"

# Spec 022 AC-1.5 and AC-1.6: the seat page and the host page say which phase the game is in.
RSpec.describe "The phase on the seat page and the host page", type: :request do
  around { |example| with_passphrase { example.run } }

  let(:created) { create_game(power: "england") }
  let(:game) { created.game }
  let(:id) { game.public_id }

  describe "the seat page (AC-1.5)" do
    it "has a phase header with the player's badge, and the player's own state" do
      game.take_seat!("france")
      created.session.get "/games/#{id}"

      page = Nokogiri::HTML5(created.session.response.body)
      header = page.at_css(".phase-header")
      expect(header.at_css(".phase-header__title").text).to eq("Spring 1901 · Movement")
      expect(header.at_css(".power-badge--england").text).to eq("England")
      expect(page.text).to include("Not submitted")
      expect(page.text).to include("Keep this page. The host reveals each phase when the table is ready.")
      expect(page.text).not_to include("The host will start the game")
      expect(page.text).not_to include("France")
    end

    it "says Submitted once the seat has submitted" do
      Submission.create!(phase: game.current_phase, seat: game.seats.find_by(power: "england"))
      created.session.get "/games/#{id}"

      expect(Nokogiri::HTML5(created.session.response.body).text).to include("Submitted")
      expect(created.session.response.body).not_to include("Not submitted")
    end
  end

  describe "the host page (AC-1.6)" do
    it "has a phase header without a badge, a Reveal button, and says nothing has been revealed" do
      created.session.get "/games/#{id}/host"

      page = Nokogiri::HTML5(created.session.response.body)
      header = page.at_css(".phase-header")
      expect(header.at_css(".phase-header__title").text).to eq("Spring 1901 · Movement")
      expect(header.at_css(".power-badge")).to be_nil
      reveal = page.at_css(".host-section a.button[href='/games/#{id}/host/phases/1/reveal']")
      expect(reveal.text).to eq("Reveal orders")
      expect(page.text).to include("No phase has been revealed yet.")
    end

    it "lists the revealed phases outside the seat list, which keeps its seven rows" do
      phase = game.current_phase
      phase.update_columns(adjudication: RulesEngine.adjudicate(RulesEngine.starting_position, []), revealed_at: Time.current)
      fall = RulesEngine.load_position(RulesEngine.starting_position.to_h.merge("season" => "fall"))
      game.phases.create!(number: 2, position: fall)

      created.session.get "/games/#{id}/host"

      page = Nokogiri::HTML5(created.session.response.body)
      expect(page.at_css(".phase-header__title").text).to eq("Fall 1901 · Movement")
      history = page.at_css("[data-history]")
      expect(history.text).to include("Spring 1901 · Movement")
      expect(page.css(".host-section ul.list > li").size).to eq(7)
      expect(page.text).not_to include("No phase has been revealed yet.")
    end
  end
end

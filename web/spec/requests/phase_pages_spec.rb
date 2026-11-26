require "rails_helper"

# Spec 022 AC-1.5 and AC-1.6: the seat page and the host page say which phase the game is in.
RSpec.describe "The phase on the seat page and the host page", type: :request do
  around { |example| with_passphrase { example.run } }

  let(:created) { create_game(power: "england") }
  let(:game) { created.game }
  let(:id) { game.public_id }

  describe "the seat page (AC-1.5)" do
    it "has a phase header with the player's badge, and the status list of the seven powers (spec 024 AC-2.1)" do
      game.take_seat!("france")
      created.session.get "/games/#{id}"

      page = Nokogiri::HTML5(created.session.response.body)
      header = page.at_css(".phase-header")
      expect(header.at_css(".phase-header__title").text).to eq("Spring 1901 · Movement")
      expect(header.at_css(".power-badge--england").text).to eq("England")
      expect(page.at_css("#seat-status [data-power='england'] .seat-status__state").text).to eq("Not submitted")
      expect(page.text).to include("Keep this page. The host reveals each phase when the table is ready.")
      expect(page.text).not_to include("The host will start the game")
      # Another power appears only as a row of the status list (spec 024 AC-2.1): never an order, a count or a link of its own.
      expect(page.css(".power-badge--france").size).to eq(1)
      expect(page.css("#seat-status .power-badge--france").size).to eq(1)
    end

    it "links to the orders page of the current phase and shows the seat's own count, never an order (AC-1.5)" do
      created.session.get "/games/#{id}"
      page = Nokogiri::HTML5(created.session.response.body)
      expect(page.at_css("a.button[href='/games/#{id}/phases/1/orders']").text).to eq("Enter orders")
      expect(page.text).to include("0 of 3 units ordered")

      england = game.seats.find_by(power: "england")
      england.save_orders!(game.current_phase, { "lon" => JSON.generate({ "format" => 1, "type" => "hold", "power" => "england", "at" => "lon" }) })
      created.session.get "/games/#{id}"
      page = Nokogiri::HTML5(created.session.response.body)
      expect(page.text).to include("1 of 3 units ordered")
      expect(page.text).not_to include("Hold")
      expect(page.at_css("select")).to be_nil
    end

    it "says Submitted in the seat's own row once the seat has submitted, and Not submitted in the others (spec 024 AC-2.1)" do
      Submission.create!(phase: game.current_phase, seat: game.seats.find_by(power: "england"))
      created.session.get "/games/#{id}"

      page = Nokogiri::HTML5(created.session.response.body)
      states = page.css("#seat-status li").to_h { |row| [ row["data-power"], row.at_css(".seat-status__state").text ] }
      expect(states["england"]).to eq("Submitted")
      expect(states.except("england").values.uniq).to eq([ "Not submitted" ])
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
      expect(page.css(".host-section ul.list:not([data-step-in-entry]) > li").size).to eq(7)
      expect(page.text).not_to include("No phase has been revealed yet.")
    end
  end
end

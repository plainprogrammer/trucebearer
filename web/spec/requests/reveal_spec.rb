require "rails_helper"

RSpec::Matchers.define_negated_matcher :not_change, :change

# Spec 022, Story 1 and Story 4 (the confirmation page): a game has a current phase, and the host's page names
# every power that has not submitted.
RSpec.describe "The reveal confirmation page", type: :request do
  around { |example| with_passphrase { example.run } }

  it "shows a new game's spring 1901 movement phase, open, and names every power that has not submitted (AC-1.1, AC-1.2)" do
    created = create_game(power: "england")
    game = created.game

    expect(game.phases.count).to eq(1)
    phase = game.current_phase
    expect([ phase.number, phase.position.season, phase.position.year, phase.position.phase ]).to eq([ 1, :spring, 1901, :movement ])
    expect(phase.position).to eq(RulesEngine.starting_position)
    expect(phase.adjudication).to be_nil
    expect(phase.revealed_at).to be_nil

    created.session.get "/games/#{game.public_id}/host/phases/1/reveal"

    expect(created.session.response).to have_http_status(:ok)
    page = Nokogiri::HTML5(created.session.response.body)
    rows = page.css(".list__row")
    expect(rows.size).to eq(7)
    RulesEngine.powers.each { |power| expect(rows.map(&:text).join(" ")).to include(power.name) }
    england = rows.find { |row| row.text.include?("England") }
    expect(england.text).not_to include("no one has joined")
    expect(rows.count { |row| row.text.include?("no one has joined") }).to eq(6)
    expect(page.text).to match(/their unordered units will hold/i)
    expect(page.at_css(".confirm")).to be_present
  end

  describe "who is named" do
    let(:created) { create_game(power: "england") }
    let(:game) { created.game }
    let(:id) { game.public_id }

    def rows_for(session)
      session.get "/games/#{id}/host/phases/1/reveal"
      Nokogiri::HTML5(session.response.body).css(".list__row")
    end

    it "names each power that has not submitted and not those that have (AC-4.1)" do
      france, = game.take_seat!("france")
      england = game.seats.find_by(power: "england")
      Submission.create!(phase: game.current_phase, seat: england)
      Submission.create!(phase: game.current_phase, seat: france)

      rows = rows_for(created.session)

      expect(rows.size).to eq(5)
      names = rows.map(&:text).join(" ")
      expect(names).not_to include("England")
      expect(names).not_to include("France")
      %w[Austria Germany Italy Russia Turkey].each { |name| expect(names).to include(name) }
      expect(Nokogiri::HTML5(created.session.response.body).text).to match(/their unordered units will hold/i)
    end

    it "says every power has submitted when they all have, and drops the will-hold sentence (AC-4.2)" do
      RulesEngine.powers.each do |power|
        seat = game.seats.find_by(power: power.id.to_s) || game.take_seat!(power.id.to_s).first
        Submission.create!(phase: game.current_phase, seat: seat)
      end

      created.session.get "/games/#{id}/host/phases/1/reveal"

      page = Nokogiri::HTML5(created.session.response.body)
      expect(page.text).to include("Every power has submitted.")
      expect(page.text).not_to match(/will hold/i)
      expect(page.css(".list__row")).to be_empty
    end

    it "marks a power nobody holds, even while joining is open (AC-4.13)" do
      expect(game).to be_open
      expect(rows_for(created.session).count { |row| row.text.include?("no one has joined") }).to eq(6)
    end
  end

  describe "the page itself (AC-4.3)" do
    it "is a full page built from the confirm part, and opening it changes nothing" do
      created = create_game(power: "england")
      id = created.game.public_id

      expect { created.session.get "/games/#{id}/host/phases/1/reveal" }
        .to not_change(Phase, :count).and not_change(Submission, :count).and not_change { created.game.current_phase.reload.revealed_at }

      page = Nokogiri::HTML5(created.session.response.body)
      expect(page.at_css("h1").text).to eq("Reveal Spring 1901 · Movement?")
      expect(page.text).to include("This cannot be undone.")
      expect(page.at_css(".confirm form[action='/games/#{id}/host/phases/1/reveal'] button.button").text).to eq("Reveal orders")
      back = page.at_css(".confirm a.button.button--secondary")
      expect(back["href"]).to eq("/games/#{id}/host")
      expect(page.at_css("dialog")).to be_nil
    end
  end

  describe "who may open it (AC-4.4)" do
    it "gives the stranger response to a seat without the host cookie, to no cookie, and to another game's host" do
      created = create_game(power: "england")
      id = created.game.public_id
      other = create_game(power: "france")

      sessions = [ seat_only_session(created), open_session, other.session ]
      sessions.each do |session|
        session.get "/games/#{id}/host/phases/1/reveal"
        expect(session.response).to have_http_status(:not_found)
        expect(session.response.body).to include("We can't find that page.")
      end
      expect(created.game.current_phase.reload).to be_open
    end
  end

  describe "the phase number (AC-4.11)" do
    let(:created) { create_game(power: "england") }
    let(:id) { created.game.public_id }

    it "is the stranger response for a later, unknown or malformed number" do
      [ "2", "7", "01", "0", "1abc", "1.5", "-1" ].each do |number|
        created.session.get "/games/#{id}/host/phases/#{number}/reveal"
        expect(created.session.response).to have_http_status(:not_found), "number #{number}"
        expect(created.session.response.body).to include("We can't find that page."), "number #{number}"
      end
    end

    it "sends the host back to the host page, with a banner, for a phase that was already revealed" do
      phase = created.game.current_phase
      phase.update_columns(adjudication: RulesEngine.adjudicate(RulesEngine.starting_position, []), revealed_at: Time.current)
      created.game.phases.create!(number: 2, position: RulesEngine.starting_position)

      created.session.get "/games/#{id}/host/phases/1/reveal"

      expect(created.session.response).to have_http_status(:see_other)
      expect(created.session.response.location).to eq("http://www.example.com/games/#{id}/host")
      expect(created.session.flash[:banner]).to eq({ "kind" => "info", "text" => "That phase was already revealed." })
    end
  end
end

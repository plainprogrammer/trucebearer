require "rails_helper"

# Spec 022 Story 8: the phase header, the banner and the confirmation page, built once and used everywhere.
RSpec.describe "The phase components", type: :request do
  around { |example| with_passphrase { example.run } }

  describe "the banner (AC-8.2)" do
    before { get "/styleguide" }

    let(:page) { Nokogiri::HTML5(response.body) }
    let(:banners) { page.css("section[data-component=banner] .banner") }

    it "has the three kinds, each one sentence, and words that say the kind" do
      expect(banners.map { |b| b["class"].split.last }).to match_array(%w[banner--info banner--warning banner--danger])
      expect(banners.find { |b| b["class"].include?("banner--warning") }.text).to start_with("Warning:")
      expect(banners.find { |b| b["class"].include?("banner--danger") }.text).to start_with("Error:")
      expect(banners.find { |b| b["class"].include?("banner--info") }.text).not_to match(/\A(Warning|Error):/)
    end
  end

  it "is written by one partial only: no other view writes a banner element (AC-8.2)" do
    views = Dir.glob(Rails.root.join("app/views/**/*.erb")).reject { |path| path.end_with?("shared/_banner.html.erb") }
    offenders = views.select { |path| File.read(path).match?(/class="[^"]*\bbanner\b/) || File.read(path).include?("banner--") }
    expect(offenders).to be_empty, "banner written outside the partial: #{offenders.join(', ')}"
  end

  describe "the banner in the layout" do
    it "shows what a redirect put in the flash, through the partial" do
      created = create_game(power: "england")
      phase = created.game.current_phase
      phase.update_columns(adjudication: RulesEngine.adjudicate(RulesEngine.starting_position, []), revealed_at: Time.current)
      created.game.phases.create!(number: 2, position: RulesEngine.starting_position)

      created.session.get "/games/#{created.game.public_id}/host/phases/1/reveal"
      created.session.follow_redirect!

      banner = Nokogiri::HTML5(created.session.response.body).css(".banner--info")
      expect(banner.size).to eq(1)
      expect(banner.first.text).to eq("That phase was already revealed.")
    end
  end

  describe "the confirmation page (AC-8.3)" do
    let(:created) { create_game(power: "england") }
    let(:id) { created.game.public_id }

    it "is built from one part by the close-joining page, with a danger button and a back link" do
      created.session.get "/games/#{id}/host/close"
      page = Nokogiri::HTML5(created.session.response.body)

      expect(page.css(".confirm").size).to eq(1)
      expect(page.at_css(".confirm form button.button.button--danger").text).to eq("Close joining")
      expect(page.at_css(".confirm a.button.button--secondary").text).to eq("Back")
      expect(page.at_css("dialog")).to be_nil
    end

    it "is built from the same part by the reissue page" do
      created.session.get "/games/#{id}/host/seats/england/reissue"
      page = Nokogiri::HTML5(created.session.response.body)

      expect(page.css(".confirm").size).to eq(1)
      expect(page.at_css(".confirm form button.button.button--danger").text).to eq("Reissue seat")
      expect(page.at_css("h1").text).to eq("Reissue England")
    end

    it "is not a danger page when it reveals a phase" do
      created.session.get "/games/#{id}/host/phases/1/reveal"
      page = Nokogiri::HTML5(created.session.response.body)

      expect(page.at_css(".confirm form button.button").text).to eq("Reveal orders")
      expect(page.at_css(".confirm form button.button--danger")).to be_nil
    end
  end

  describe "the style guide" do
    it "has one section for each component and keeps its one h1 (AC-8.4)" do
      get "/styleguide"
      page = Nokogiri::HTML5(response.body)

      %w[phase-header banner confirm].each { |name| expect(page.css("section[data-component=#{name}]").size).to eq(1) }
      expect(page.css("h1:not([role=none])").map(&:text)).to eq([ "Style guide" ])
      expect(page.css("section[data-component=confirm] .confirm").size).to eq(2)
      expect(page.css("section[data-component=phase-header] .phase-header").size).to eq(2)
      expect(page.css("section[data-component=phase-header] .phase-header .power-badge").size).to eq(1)
    end
  end
end

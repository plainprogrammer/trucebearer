require "rails_helper"
require_relative "../support/stylesheets"

RSpec.describe "Style guide", type: :request do
  components = %w[button link list field choice power-badge heading-text unit-icon supply-center-icon mono-text
                join-code qr-card power-tile host-section phase-header banner confirm unit-row picker submit-bar seat-status results segmented game-card]
  # The documented pairs other than the power pairs (spec FR-3).
  non_power_pair_count = Contrast::DOCUMENTED_PAIRS.size

  def flag = Rails.configuration.x.styleguide

  around do |example|
    original = flag
    example.run
  ensure
    Rails.configuration.x.styleguide = original
  end

  describe "where it is available" do
    before { get "/styleguide" }

    let(:page) { Nokogiri::HTML5(response.body) }

    it "responds with 200 and one section for each component (AC-5.1)" do
      expect(response).to have_http_status(:ok)
      expect(page.css("section[data-component]").map { |s| s["data-component"] }).to match_array(components)
    end

    it "shows the segmented toggle: a legend and exactly one checked radio in each sample (spec 027 AC-9.4)" do
      samples = page.css("section[data-component=segmented] fieldset.segmented")

      expect(samples.size).to be >= 2
      samples.each do |sample|
        expect(sample.at_css("legend").text).to be_present
        expect(sample.css("input[type=radio][checked]").size).to eq(1)
        expect(sample.css("input[type=radio]").size).to be >= 2
      end
    end

    it "shows the game card in its three forms (spec 028 AC-8.1)" do
      cards = page.css("section[data-component=game-card] a.game-card")

      expect(cards.size).to eq(3)
      expect(cards.map { |card| card.text.squish }.join(" ")).to include("You host this game")
      expect(cards.count { |card| card.at_css(".power-badge") }).to eq(2)
    end

    it "shows static variants: each button variant, disabled, invalid, a disabled choice (AC-5.1)" do
      expect(page.css(".button").size).to be >= 8
      expect(page.css(".button--secondary, .button--danger").size).to be >= 4
      expect(page.css(".button[disabled], .button[aria-disabled=true]").size).to be >= 2
      expect(page.css(".control[aria-invalid=true]").size).to be >= 1
      expect(page.css(".field__error").map(&:text)).to all(start_with("Error:"))
      expect(page.css(".choice--disabled input[disabled]").size).to be >= 1
    end

    it "ties every error to its control (AC-2.7)" do
      page.css(".control[aria-invalid=true]").each do |control|
        described = control["aria-describedby"].to_s.split
        expect(described.any? { |id| page.at_css("##{id}.field__error") }).to be(true)
      end
    end

    it "shows each color token other than the power tokens as a labelled swatch (AC-5.4)" do
      expected = Stylesheets.color_tokens.keys.reject { |n| n.match?(/\A--color-power-/) }
      shown = page.css(".sg-swatch__name").map(&:text)
      expect(shown).to match_array(expected)
    end

    it "shows each non-power pair as a sample with its token names and minimum (AC-5.4)" do
      samples = page.css(".sg-sample")
      expect(samples.size).to eq(non_power_pair_count)
      expect(samples.map { |s| s.at_css(".sg-sample__meta").text }).to all(match(/\S+ on \S+ \(min \d(\.\d)?\)/))
    end

    it "shows exactly the documented pairs, and every class it uses exists (AC-5.4)" do
      shown = StyleguideHelper::PAIRS.map { |fg, bg, min| [ fg, bg, min.to_f ] }
      expect(shown).to eq(Contrast::DOCUMENTED_PAIRS)
      css = File.read(File.join(Stylesheets::DIR, "styleguide.css"))
      used = page.css("[class*=sg-]").flat_map { |e| e["class"].split }.grep(/\Asg-(?:bg|fg)-/).uniq
      missing = used.reject { |klass| css.include?(".#{klass} ") }
      expect(missing).to be_empty, "styleguide.css lacks: #{missing.join(', ')}"
    end

    it "shows the type scale and the spacing scale (AC-5.4)" do
      expect(page.css(".sg-type-step").size).to eq(5)
      expect(page.css(".sg-space-step").size).to eq(8)
    end

    it "shows seven power badges, each with its name and token name beside it (AC-4.5)" do
      badges = page.css("section[data-component=power-badge] .power-badge")
      expect(badges.map(&:text)).to match_array(%w[Austria England France Germany Italy Russia Turkey])
      expect(page.css(".sg-power__token").map(&:text)).to match_array(
        %w[austria england france germany italy russia turkey].map { |id| "--color-power-#{id}" }
      )
    end

    it "shows every power's army and fleet at 20, 32 and 48 pixels, one row on ice-pale (AC-7.10, 4.5)" do
      icons = page.css(".sg-units .unit-icon")
      expect(icons.size).to eq(42)
      expect(icons.map { |i| [ i["width"], i["class"][/unit-icon--(\w+)/, 1] ] }.tally.values.uniq).to eq([ 2 ])
      expect(icons.map { |i| i["width"] }.tally).to eq("20" => 14, "32" => 14, "48" => 14)
      expect(page.css(".sg-units .sg-bg-ice-pale").size).to eq(1)
      expect(page.css(".sg-unit__name").map(&:text)).to match_array(%w[Austria England France Germany Italy Russia Turkey])
      # Each row names the power whose icons it holds.
      page.css(".sg-unit").each do |row|
        classes = row.css(".unit-icon").map { |i| i["class"][/unit-icon--(\w+)/, 1] }.uniq
        expect(classes.size).to eq(1)
        expect(row.at_css(".sg-unit__name").text.downcase).to eq(classes.first)
      end
    end

    it "shows the join code, two QR cards and the host section on their own (AC-9.1)" do
      expect(page.css("section[data-component=join-code] .join-code.mono").map { |e| e.text.strip }).to eq([ "ACD EFG" ])
      cards = page.css("section[data-component=qr-card] .qr-card")
      expect(cards.size).to eq(2)
      expect(cards.map { |c| c.at_css("svg.qr-card__code")["aria-label"] }).to all(be_present)
      expect(cards.map { |c| c.at_css(".qr-card__link").text }).to all(start_with("https://"))
      host = page.css("section[data-component=host-section] .host-section")
      expect(host.size).to eq(1)
      expect(host.first.css(".button, a").size).to be >= 4
    end

    it "shows results: a player group, a reading group with a dislodged row, and every tag, and no practice note (spec 025 AC-8.1, spec 029 AC-3.4)" do
      section = page.at_css("section[data-component=results]")

      expect(section.css(".result-group").size).to eq(2)
      expect(section.css(".result-group--reading").size).to eq(1)
      expect(section.css(".result-group--reading .result-row--dislodged")).not_to be_empty
      expect(section.css(".outcome-tag").map(&:text).uniq).to include("Succeeded", "Bounced", "Support cut", "Dislodged", "Not a legal order")
      expect(section.css(".outcome-tag").map(&:text).uniq).to match_array(OutcomeHelper::OUTCOME_WORDS.values)
      expect(section.at_css(".practice-note")).to be_nil
    end

    it "shows the seat status with all submitted, none submitted and a mix, each list with an id of its own (spec 024 AC-8.1)" do
      section = page.at_css("section[data-component=seat-status]")
      lists = section.css("ul.seat-status")
      states = lists.map { |list| list.css(".seat-status__state").map(&:text).uniq.sort }

      expect(lists.size).to eq(3)
      expect(lists.map { |list| list[:id] }.uniq.size).to eq(3)
      expect(states).to contain_exactly([ "Submitted" ], [ "Not submitted" ], [ "Not submitted", "Submitted" ])
      expect(lists.map { |list| list.css("li").size }).to eq([ 7, 7, 7 ])
    end

    it "shows open power tiles as buttons and taken ones as plain text, each with a power name (AC-9.3)" do
      names = %w[Austria England France Germany Italy Russia Turkey]
      section = page.at_css("section[data-component=power-tile]")
      open = section.css("button.power-tile")
      taken = section.css(".power-tile--taken")
      expect(open.size + taken.size).to eq(7)
      expect(taken.size).to eq(2)
      expect((open + taken).flat_map { |t| t.css(".power-badge").map(&:text) }).to match_array(names)
      expect(taken.map(&:name)).to all(eq("div"))
      expect(taken.map { |t| t.text }).to all(include("Taken"))
      expect(taken.flat_map { |t| t.css("button, a, input").to_a }).to be_empty
      expect(open.map { |t| t.text }).to all(satisfy { |text| names.any? { |n| text.include?(n) } && !text.include?("Taken") })
    end

    it "shows each owner and the unowned look, named beside each (AC-7.10)" do
      expect(page.css(".sg-supply .supply-center-icon").map { |i| i["class"][/--(\w+)\z/, 1] })
        .to match_array(%w[austria england france germany italy russia turkey unowned])
      expect(page.css(".sg-supply__name").map(&:text)).to match_array(%w[Austria England France Germany Italy Russia Turkey Unowned])
      page.css(".sg-supply__item").each do |item|
        owner = item.at_css(".supply-center-icon")["class"][/--(\w+)\z/, 1]
        expect(item.at_css(".sg-supply__name").text.downcase).to eq(owner)
      end
    end

    it "shows a line of mono text" do
      expect(page.css("section[data-component=mono-text] .mono").size).to be >= 1
    end

    it "shows an action area with two buttons inside the real layout" do
      expect(page.css("header").size).to eq(1)
      expect(page.css("main").size).to eq(1)
      expect(page.css(".app-actions .button").size).to eq(2)
    end

    it "uses no inline styles (spec Security requirement, FR-1 must-not list)" do
      expect(page.css("[style]")).to be_empty
      expect(page.css("style")).to be_empty
    end
  end

  describe "where it is not available (AC-5.2)" do
    it "responds with 404 when the flag is off, as in production" do
      Rails.configuration.x.styleguide = false
      get "/styleguide"
      expect(response).to have_http_status(:not_found)
    end

    it "is switched off by default and only switched on in development and test" do
      root = Rails.root
      expect(File.read(root.join("config/application.rb"))).to include("config.x.styleguide = false")
      expect(File.read(root.join("config/environments/development.rb"))).to include("config.x.styleguide = true")
      expect(File.read(root.join("config/environments/test.rb"))).to include("config.x.styleguide = true")
      expect(File.read(root.join("config/environments/production.rb"))).not_to include("styleguide")
    end
  end
end

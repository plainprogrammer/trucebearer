require "rails_helper"
require_relative "../support/stylesheets"

RSpec.describe "Style guide", type: :request do
  components = %w[button link list field choice power-badge heading-text]
  # The documented pairs other than the power pairs (spec FR-3): 31 of them.
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
      badges = page.css(".power-badge")
      expect(badges.map(&:text)).to match_array(%w[Austria England France Germany Italy Russia Turkey])
      expect(page.css(".sg-power__token").map(&:text)).to match_array(
        %w[austria england france germany italy russia turkey].map { |id| "--color-power-#{id}" }
      )
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

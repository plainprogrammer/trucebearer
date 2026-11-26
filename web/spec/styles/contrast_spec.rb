require "spec_helper"
require_relative "../support/stylesheets"

RSpec.describe "Palette contrast (WCAG 2.2)" do
  powers = %w[austria england france germany italy russia turkey]

  documented_pairs = Contrast::DOCUMENTED_PAIRS

  # Each pair is held once, at its higher minimum: a power color on surface is both the tag's
  # initial (4.5) and a unit's or badge's edge (3).
  power_pairs = powers.flat_map do |id|
    [ [ "on-power", "power-#{id}", 4.5 ], [ "power-#{id}", "surface", 4.5 ],
      [ "power-#{id}", "page", 3.0 ], [ "power-#{id}", "ice-pale", 3.0 ] ]
  end

  pairs = documented_pairs + power_pairs

  # The Cold War palette (decisions 41 and 42). Held exactly: nobody tunes a value by eye (AC-2.10).
  palette = {
    "page" => "#eef3f6", "surface" => "#ffffff", "ice" => "#a7c4d4", "ice-pale" => "#dde8ee", "steel" => "#4f7a93",
    "text" => "#22262b", "text-muted" => "#4a5560", "border" => "#65727e",
    "link" => "#2c5873", "link-visited" => "#5b3a7a",
    "primary" => "#3d6178", "primary-pressed" => "#2b4657", "on-primary" => "#ffffff",
    "danger" => "#9e2a22", "danger-pressed" => "#7a1f19", "on-danger" => "#ffffff",
    "focus" => "#a8480a", "disabled-text" => "#56606a", "disabled-fill" => "#d3dce2", "on-power" => "#ffffff",
    "power-austria" => "#586f2a", "power-england" => "#822635", "power-france" => "#744983",
    "power-germany" => "#196666", "power-italy" => "#866713", "power-russia" => "#994324", "power-turkey" => "#324e8f"
  }.transform_keys { |name| "--color-#{name}" }.freeze

  let(:colors) { Stylesheets.color_tokens }

  it "has the token file" do
    expect(File).to exist(Stylesheets::TOKENS)
  end

  it "writes every color token as a six-digit hex value" do
    bad = colors.reject { |_, value| value.match?(/\A#[0-9a-f]{6}\z/i) }
    expect(bad).to be_empty, "not six-digit hex: #{bad.keys.join(', ')}"
  end

  it "documents a pair for every color token, and every pair names real tokens (AC-2.3)" do
    used = pairs.flat_map { |fg, bg, _| [ "--color-#{fg}", "--color-#{bg}" ] }.uniq
    expect(colors.keys - used).to be_empty, "no documented pair uses: #{(colors.keys - used).join(', ')}"
    expect(used - colors.keys).to be_empty, "pair names a missing token: #{(used - colors.keys).join(', ')}"
  end

  it "meets the minimum ratio for every documented pair (AC-2.1, AC-2.2)" do
    expect(Contrast.failures(colors, pairs)).to be_empty
  end

  it "holds every palette and power value exactly as the spec writes it (AC-2.10)" do
    expect(colors).to eq(palette)
  end

  it "keeps on-power white, the white the artwork's marks are drawn in (AC-2.10)" do
    expect(colors["--color-on-power"]).to eq("#ffffff")
  end

  it "reads --color-ice only as a background (AC-2.9)" do
    Stylesheets.files.each do |file|
      misuse = Stylesheets.ice_uses(Stylesheets.read(file)).reject { |prop, _| %w[background background-color].include?(prop) }
      expect(misuse).to be_empty, "#{File.basename(file)} reads --color-ice in #{misuse.map(&:join).join(', ')}"
    end
  end

  it "finds a misuse of --color-ice when there is one (the check itself)" do
    expect(Stylesheets.ice_uses("a { color: var(--color-ice); }")).to eq([ [ "color", 1 ] ])
    expect(Stylesheets.ice_uses("a { background: var(--color-ice-pale); }")).to be_empty
  end

  it "has exactly one power color for each power (AC-4.1)" do
    names = colors.keys.grep(/\A--color-power-/)
    expect(names).to match_array(powers.map { |id| "--color-power-#{id}" })
  end

  it "keeps the power hues at least 25 degrees apart (AC-4.2)" do
    hexes = powers.to_h { |id| [ id, colors.fetch("--color-power-#{id}") ] }
    hexes.to_a.combination(2).each do |(a, ha), (b, hb)|
      expect(Contrast.hue_distance(ha, hb)).to be >= 25, "#{a} and #{b} are too close in hue"
    end
  end

  it "keeps the page and surface, and each resting and pressed fill, visibly different" do
    [ %w[page surface], %w[primary primary-pressed], %w[danger danger-pressed] ].each do |a, b|
      expect(colors["--color-#{a}"]).not_to eq(colors["--color-#{b}"]), "#{a} and #{b} are the same"
    end
  end

  describe "the checker itself" do
    it "reports a pair under its minimum with the pair, ratio and threshold (AC-2.6)" do
      weak = { "--color-text" => "#777777", "--color-page" => "#ffffff" }
      messages = Contrast.failures(weak, [ [ "text", "page", 4.5 ] ])
      expect(messages).to eq([ "text / page: ratio 4.47 is below 4.5" ])
    end

    it "reports a pair that names a missing token" do
      messages = Contrast.failures({ "--color-text" => "#000000" }, [ [ "text", "nope", 4.5 ] ])
      expect(messages).to eq([ "text / nope: token missing" ])
    end

    it "computes known ratios" do
      expect(Contrast.ratio("#000000", "#ffffff")).to be_within(0.001).of(21.0)
      expect(Contrast.ratio("#ffffff", "#ffffff")).to be_within(0.001).of(1.0)
    end

    it "measures hue as a circular distance" do
      expect(Contrast.hue_distance("#ff0000", "#ff0040")).to be_within(1.5).of(15)
      expect(Contrast.hue_distance("#ff0000", "#00ffff")).to be_within(0.5).of(180)
    end
  end
end

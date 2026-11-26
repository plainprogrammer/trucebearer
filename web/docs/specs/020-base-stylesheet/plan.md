# Implementation Plan: Mobile-first base stylesheet

**Spec:** web/docs/specs/020-base-stylesheet/spec.md (v1.2.1, Approved at Gate A)
**Decisions:** none new. `docs/architecture.md` "Front end": no build step, Propshaft, import maps, plain modern CSS
**Created:** 2026-11-25

All paths are relative to `web/`. Nothing outside `web/` changes.

## Global Constraints

- No new gem, no new importmap pin, no Node, no preprocessor. (AC-6.4)
- Plain CSS in `app/assets/stylesheets/`, linked by the existing `stylesheet_link_tag :app`. No `@import`, `url(`, `@font-face`, web font, inline `style`, `!important`, JavaScript. (FR-1, AC-6.2)
- Every color is a six-digit hex `--color-*` token in `tokens.css`; rules read tokens only. (FR-2, AC-2.4)
- No `opacity` (other than `opacity: 1`), `filter`, `mix-blend-mode` or `color-mix()`. (AC-2.8)
- No font size in `px`, no root font size. (AC-1.5)
- Total stylesheet weight at most 24 KB, of which the style guide's file at most 4 KB. (FR-1)
- The name: nothing in `app/`, `lib/`, `spec/` or `config/routes.rb`, in file names or contents, matches `diplomacy` or a word starting with `dip`. (AC-6.5)
- No text from the game's rulebook or the DATC. No logos, artwork, board images or fonts from any edition. Never edit `adjudicator/`.
- Test first. Run `bundle exec rspec` from `web/` before every push.
- Commit messages: plain imperative sentence, ending with `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`.

---

## Goal

A mobile-first base stylesheet (tokens, layout, buttons, lists, form controls, power badges), a layout with header, main and sticky action area, and a development-only `/styleguide` page, with a contrast spec that proves every documented pair from the stylesheet itself.

## Pre-implementation gates

- **Simplicity:** three units. The stylesheet set, the style guide (route, controller, helper, view) and the `power_badge` helper. The helper is required by AC-4.3. The style guide is required by FR-7. No wrappers around Rails.
- **Anti-abstraction:** the spec support code (`spec/support/stylesheets.rb`) exists only so two specs share one parser. It is test code, not app code, and nothing in `app/` reads a stylesheet.
- **Integration first:** the specs in Phase 0 fix the token names, the markup hooks and the helper signature before any CSS exists.

## Design decisions the spec left to the plan

| Question | Decision | Why |
|---|---|---|
| Cascade order independent of file names (FR-1) | Every CSS file starts with the same statement `@layer reset, base, layout, components, styleguide;`. The first file the browser loads fixes the order, and the rest repeat it harmlessly. A spec asserts every file starts with exactly that line | `stylesheet_link_tag :app` loads files in file-name order; repeating the declaration removes the dependence |
| Files | `tokens.css` (tokens only), `base.css` (reset and elements), `layout.css`, `components.css`, `styleguide.css`; `application.css` keeps only the layer line and a comment | One concern per file; six small requests over one connection |
| Action area | `position: sticky; bottom: 0` as the last child of a column flex `body` that is at least one viewport high. Below 30rem of height it becomes `static` | Sticks while the page scrolls, never overlays the last line, sits at the bottom when content is short, no fixed height needed (FR-5, B3) |
| Focus not hidden (AC-3.6) | `html { scroll-padding-bottom: var(--scroll-pad) }`, with `--scroll-pad` = tap height + `--space-6` + bottom safe-area inset, enough for one row of buttons | WCAG 2.4.11 asks only "not entirely hidden" |
| Page height fallback | `min-height: 100vh; min-height: 100dvh;` | A browser without `dvh` keeps the first line |
| Pressed shape | `box-shadow: inset 0 0 0 var(--border-width) <edge color>` on top of the border, so the border looks twice as thick with no layout shift | Spec: "thickens the border to twice `--border-width`" |
| Per-variant state colors | Each button variant sets four local properties: `--_fill`, `--_edge`, `--_ink`, `--_fill-pressed`. They hold `var(--color-*)` only, never a color value | Keeps AC-2.4 true and each variant to a few lines |
| Production 404 (AC-5.2) | `config.x.styleguide` is `false` in `application.rb`, `true` in `development.rb` and `test.rb`. The route sits inside `constraints(->(_) { Rails.configuration.x.styleguide })`. A request spec flips the flag to `false` and expects 404, and a file spec checks production does not set it | The route is really absent when the flag is off, and the spec exercises it without stubbing `Rails.env` |
| Power colors (FR-9) | Seven hues from an even HSL spread, start 17 degrees, step 360/7 = 51.43 degrees, saturation 60 percent, assigned alphabetically. Lightness per color is the highest whole percent at which white reaches at least 4.7 | Reproducible, arbitrary on purpose. No tuning of hue was needed (see table) |
| Neutral and accent palette | Warm paper page, cool ink text, one deep blue accent, brick red danger, burnt orange focus ring | The app's own aim; chosen without consulting any edition of the game |
| Visual check (FR-7) | `/styleguide` | Outlives the root page, which #21 replaces |
| Geometry proof | Real Chrome through the browser tooling: a console snippet kept in `measure.md`, run at 320, 360, 390, 768 and 1024 pixels, plus screenshots at 360 and 768 | No new dependency (Gate A, decision 5) |

### The palette (derived once, recorded here)

No edition of the game was consulted. Hue start 17 degrees, step 51.43 degrees, saturation 60 percent. Lightness is the highest whole percent at which white text reaches at least 4.7 on the fill. Contrast is computed with the WCAG 2.2 formula.

| Power | Nominal hue | Hex | Hue of the hex | White on it | On `page` | On `surface` |
|---|---|---|---|---|---|---|
| austria | 17.0 | `#b8552e` | 17.0 | 4.80 | 4.33 | 4.80 |
| england | 68.4 | `#6e7a1f` | 67.9 | 4.70 | 4.24 | 4.70 |
| france | 119.9 | `#218321` | 120.0 | 4.85 | 4.37 | 4.85 |
| germany | 171.3 | `#207e71` | 171.7 | 4.90 | 4.42 | 4.90 |
| italy | 222.7 | `#335fcc` | 222.7 | 5.75 | 5.19 | 5.75 |
| russia | 274.1 | `#8a33cc` | 274.1 | 6.13 | 5.53 | 6.13 |
| turkey | 325.6 | `#cc338b` | 325.5 | 4.76 | 4.29 | 4.76 |

The least circular distance between two of these hues is 51.0 degrees, so the 25-degree rule holds with room. No hue moved by more than 0.5 degrees through rounding, and no tuning was needed. All seven fills sit in a narrow band of darkness and differ chiefly by hue (spec FR-4); the name is always printed on the badge.

| Token | Hex | Contrast it must hold (see FR-3) |
|---|---|---|
| `--color-page` | `#f6f3ec` | Background |
| `--color-surface` | `#ffffff` | Background |
| `--color-text` | `#1b2230` | 14.38 on page, 15.93 on surface |
| `--color-text-muted` | `#4b5567` | 6.78 on page, 7.51 on surface |
| `--color-border` | `#6a7385` | 4.30 against page, 4.77 against surface |
| `--color-link` | `#1d4f9c` | 7.15 on page, 7.92 on surface |
| `--color-link-visited` | `#5b3a8c` | 7.80 on page, 8.65 on surface |
| `--color-primary` | `#1f4e8c` | 7.50 against page, 8.31 against surface |
| `--color-primary-pressed` | `#163a69` | 10.28 against page, 11.39 against surface |
| `--color-on-primary` | `#ffffff` | 8.31 on primary, 11.39 on pressed |
| `--color-danger` | `#a3262a` | 6.61 on page, 7.32 on surface |
| `--color-danger-pressed` | `#7e1b1e` | 9.19 against page, 10.18 against surface |
| `--color-on-danger` | `#ffffff` | 7.32 on danger, 10.18 on pressed |
| `--color-focus` | `#b3470a` | 4.96 against page, 5.49 against surface |
| `--color-disabled-text` | `#5c6270` | 4.30 on disabled fill |
| `--color-disabled-fill` | `#dcd8cf` | Background |
| `--color-on-power` | `#ffffff` | See the power table |

These ratios were computed with the same formula the spec uses. If the spec disagrees in Phase 1, the spec wins and the token is retuned, with the new value recorded here.

---

## Phase 0: Specs first (they fail until the palette exists)

**Implements:** FR-2, FR-3, FR-4, FR-6 (the checkable parts) | **Satisfies:** AC-1.5, 2.1 to 2.6, 2.8, 4.1, 4.2, 4.4, 6.2, 6.5
**Files:** `spec/support/stylesheets.rb`, `spec/styles/contrast_spec.rb`, `spec/styles/stylesheet_rules_spec.rb`, `spec/styles/words_spec.rb`
**Interfaces:** Consumes: nothing. Produces: `Stylesheets` (parsing and scanning), `Contrast` (WCAG maths), used by Phases 1 to 4 specs.

The contrast spec is the first test, as the brief requires. It reads `app/assets/stylesheets/tokens.css`, which does not exist yet, so every example about the real files fails. The examples that test the scanner and the maths on synthetic input pass at once, since they need no stylesheet.

- [ ] Write `spec/support/stylesheets.rb`:

```ruby
# Test-only helpers: read the app's own stylesheets and measure them.
# Nothing in app/ uses this file.
module Stylesheets
  DIR = File.expand_path("../../app/assets/stylesheets", __dir__)
  TOKENS = File.join(DIR, "tokens.css")
  LAYER_LINE = "@layer reset, base, layout, components, styleguide;"

  NAMED_COLORS = %w[
    aliceblue antiquewhite aqua aquamarine azure beige bisque black blanchedalmond blue blueviolet
    brown burlywood cadetblue chartreuse chocolate coral cornflowerblue cornsilk crimson cyan
    darkblue darkcyan darkgoldenrod darkgray darkgreen darkgrey darkkhaki darkmagenta
    darkolivegreen darkorange darkorchid darkred darksalmon darkseagreen darkslateblue
    darkslategray darkslategrey darkturquoise darkviolet deeppink deepskyblue dimgray dimgrey
    dodgerblue firebrick floralwhite forestgreen fuchsia gainsboro ghostwhite gold goldenrod gray
    green greenyellow grey honeydew hotpink indianred indigo ivory khaki lavender lavenderblush
    lawngreen lemonchiffon lightblue lightcoral lightcyan lightgoldenrodyellow lightgray
    lightgreen lightgrey lightpink lightsalmon lightseagreen lightskyblue lightslategray
    lightslategrey lightsteelblue lightyellow lime limegreen linen magenta maroon
    mediumaquamarine mediumblue mediumorchid mediumpurple mediumseagreen mediumslateblue
    mediumspringgreen mediumturquoise mediumvioletred midnightblue mintcream mistyrose moccasin
    navajowhite navy oldlace olive olivedrab orange orangered orchid palegoldenrod palegreen
    paleturquoise palevioletred papayawhip peachpuff peru pink plum powderblue purple
    rebeccapurple red rosybrown royalblue saddlebrown salmon sandybrown seagreen seashell sienna
    silver skyblue slateblue slategray slategrey snow springgreen steelblue tan teal thistle
    tomato turquoise violet wheat white whitesmoke yellow yellowgreen
  ].freeze
  SYSTEM_COLORS = %w[
    canvas canvastext linktext visitedtext activetext buttonface buttontext buttonborder field
    fieldtext highlight highlighttext selecteditem selecteditemtext mark marktext graytext
    accentcolor accentcolortext
  ].freeze
  COLOR_FUNCTION = /\b(?:rgb|rgba|hsl|hsla|hwb|lab|lch|oklab|oklch|color|color-mix|light-dark)\(/i
  HEX_COLOR = /#[0-9a-f]{3,8}\b/i

  module_function

  def files = Dir[File.join(DIR, "**/*.css")].sort

  # Comments become blanks so line numbers stay true.
  def strip_comments(css) = css.gsub(%r{/\*.*?\*/}m) { |c| c.gsub(/[^\n]/, " ") }

  def read(path) = strip_comments(File.read(path))

  # [[property, value, line], ...] for every declaration.
  def declarations(css)
    css.to_enum(:scan, /([\w-]+)\s*:\s*([^;{}]+?)\s*(?=;|\})/m).map do
      m = Regexp.last_match
      [m[1], m[2].strip, css[0...m.begin(0)].count("\n") + 1]
    end
  end

  # [[selector, body], ...] for every innermost rule.
  def rules(css)
    css.scan(/([^{}]+)\{([^{}]*)\}/m).map { |sel, body| [sel.strip, body] }
  end

  # { "--color-page" => "#f6f3ec", ... } from the token file.
  def tokens(path = TOKENS)
    declarations(read(path)).select { |p, _, _| p.start_with?("--") }.to_h { |p, v, _| [p, v] }
  end

  def color_tokens(path = TOKENS)
    tokens(path).select { |name, _| name.start_with?("--color-") }
  end

  # Problems with a stylesheet other than the token file. Each is "file:line: what".
  def violations(css, label)
    out = []
    declarations(css).each do |prop, value, line|
      at = "#{label}:#{line}"
      plain = value.gsub(/var\([^)]*\)/, "")
      words = plain.downcase.scan(/[a-z]+/)
      out << "#{at}: hex color in #{prop}" if value.match?(HEX_COLOR)
      out << "#{at}: color function in #{prop}" if value.match?(COLOR_FUNCTION)
      out << "#{at}: named or system color in #{prop}" if (words & (NAMED_COLORS + SYSTEM_COLORS)).any?
      out << "#{at}: banned #{prop}" if prop.match?(/\A(?:-\w+-)?(?:filter|mix-blend-mode)\z/)
      out << "#{at}: banned opacity" if prop == "opacity" && value != "1"
      out << "#{at}: px font size in #{prop}" if %w[font font-size].include?(prop) && value.match?(/\d\s*px/i)
      out << "#{at}: !important" if value.include?("!important")
    end
    out << "#{label}: @import" if css.include?("@import")
    out << "#{label}: @font-face" if css.include?("@font-face")
    out << "#{label}: url(" if css.match?(/url\(/i)
    out << "#{label}: color-mix" if css.include?("color-mix(")
    rules(css).each do |selector, body|
      next unless body.include?("--color-power-")
      out << "#{label}: --color-power- used outside a power badge rule (#{selector})" unless selector.match?(/\.power-badge/)
    end
    out
  end
end

module Contrast
  module_function

  def channel(value)
    c = value / 255.0
    c <= 0.04045 ? c / 12.92 : ((c + 0.055) / 1.055)**2.4
  end

  def rgb(hex) = hex.delete("#").scan(/../).map { |pair| pair.to_i(16) }

  def luminance(hex)
    r, g, b = rgb(hex).map { |v| channel(v) }
    (0.2126 * r) + (0.7152 * g) + (0.0722 * b)
  end

  def ratio(first, second)
    light, dark = [luminance(first), luminance(second)].max, [luminance(first), luminance(second)].min
    (light + 0.05) / (dark + 0.05)
  end

  # Hue in degrees (HSL), from a hex color.
  def hue(hex)
    r, g, b = rgb(hex).map { |v| v / 255.0 }
    top, bottom = [r, g, b].max, [r, g, b].min
    delta = top - bottom
    return 0.0 if delta.zero?
    h = case top
        when r then ((g - b) / delta) % 6
        when g then ((b - r) / delta) + 2
        else ((r - g) / delta) + 4
        end
    (h * 60) % 360
  end

  def hue_distance(first, second)
    d = (hue(first) - hue(second)).abs
    [d, 360 - d].min
  end

  # Messages for pairs that fail. A pair is [foreground token, background token, minimum].
  def failures(colors, pairs)
    pairs.filter_map do |fg, bg, min|
      a, b = colors["--color-#{fg}"], colors["--color-#{bg}"]
      next "#{fg} / #{bg}: token missing" unless a && b
      r = ratio(a, b)
      "#{fg} / #{bg}: ratio #{r.round(2)} is below #{min}" if r < min
    end
  end
end
```

- [ ] Write `spec/styles/contrast_spec.rb`:

```ruby
require "spec_helper"
require_relative "../support/stylesheets"

RSpec.describe "Palette contrast (WCAG 2.2)" do
  POWERS = %w[austria england france germany italy russia turkey].freeze

  # The documented pairs (spec FR-3). [foreground, background, minimum ratio].
  # Each pair appears once, with its higher minimum where the spec lists two uses.
  DOCUMENTED_PAIRS = [
    %w[text page 4.5], %w[text surface 4.5],
    %w[text-muted page 4.5], %w[text-muted surface 4.5],
    %w[link page 4.5], %w[link surface 4.5],
    %w[link-visited page 4.5], %w[link-visited surface 4.5],
    %w[on-primary primary 4.5], %w[on-primary primary-pressed 4.5],
    %w[primary page 3], %w[primary surface 3],
    %w[primary-pressed page 3], %w[primary-pressed surface 3],
    %w[border page 3], %w[border surface 3],
    %w[danger page 4.5], %w[danger surface 4.5],
    %w[on-danger danger 4.5], %w[on-danger danger-pressed 4.5],
    %w[danger-pressed page 3], %w[danger-pressed surface 3],
    %w[focus page 3], %w[focus surface 3],
    %w[disabled-text disabled-fill 3]
  ].map { |fg, bg, min| [fg, bg, min.to_f] }.freeze

  POWER_PAIRS = POWERS.flat_map do |id|
    [["on-power", "power-#{id}", 4.5], ["power-#{id}", "page", 3.0], ["power-#{id}", "surface", 3.0]]
  end.freeze

  PAIRS = (DOCUMENTED_PAIRS + POWER_PAIRS).freeze

  let(:colors) { Stylesheets.color_tokens }

  it "has the token file" do
    expect(File).to exist(Stylesheets::TOKENS)
  end

  it "writes every color token as a six-digit hex value" do
    bad = colors.reject { |_, value| value.match?(/\A#[0-9a-f]{6}\z/i) }
    expect(bad).to be_empty, "not six-digit hex: #{bad.keys.join(', ')}"
  end

  it "documents a pair for every color token, and every pair names real tokens (AC-2.3)" do
    used = PAIRS.flat_map { |fg, bg, _| ["--color-#{fg}", "--color-#{bg}"] }.uniq
    expect(colors.keys - used).to be_empty, "no documented pair uses: #{(colors.keys - used).join(', ')}"
    expect(used - colors.keys).to be_empty, "pair names a missing token: #{(used - colors.keys).join(', ')}"
  end

  it "meets the minimum ratio for every documented pair (AC-2.1, AC-2.2)" do
    expect(Contrast.failures(colors, PAIRS)).to be_empty
  end

  it "has exactly one power color for each power (AC-4.1)" do
    names = colors.keys.grep(/\A--color-power-/)
    expect(names).to match_array(POWERS.map { |id| "--color-power-#{id}" })
  end

  it "keeps the power hues at least 25 degrees apart (AC-4.2)" do
    hexes = POWERS.to_h { |id| [id, colors.fetch("--color-power-#{id}")] }
    hexes.to_a.combination(2).each do |(a, ha), (b, hb)|
      expect(Contrast.hue_distance(ha, hb)).to be >= 25, "#{a} and #{b} are too close in hue"
    end
  end

  it "keeps the page and surface, and each resting and pressed fill, visibly different" do
    [%w[page surface], %w[primary primary-pressed], %w[danger danger-pressed]].each do |a, b|
      expect(colors["--color-#{a}"]).not_to eq(colors["--color-#{b}"]), "#{a} and #{b} are the same"
    end
  end

  describe "the checker itself" do
    it "reports a pair under its minimum with the pair, ratio and threshold (AC-2.6)" do
      weak = { "--color-text" => "#777777", "--color-page" => "#ffffff" }
      messages = Contrast.failures(weak, [["text", "page", 4.5]])
      expect(messages).to eq(["text / page: ratio 4.48 is below 4.5"])
    end

    it "reports a pair that names a missing token" do
      messages = Contrast.failures({ "--color-text" => "#000000" }, [["text", "nope", 4.5]])
      expect(messages).to eq(["text / nope: token missing"])
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
```

The `#777777` on white ratio is 4.48 under the WCAG 2.2 formula; if the first run prints another two-decimal value, correct the expected string to what the formula gives, since that example tests the message format and not the number.

- [ ] Write `spec/styles/stylesheet_rules_spec.rb`:

```ruby
require "spec_helper"
require_relative "../support/stylesheets"

RSpec.describe "Stylesheet rules" do
  let(:files) { Stylesheets.files }
  let(:non_token_files) { files.reject { |f| f == Stylesheets::TOKENS } }

  it "has the five stylesheets and the manifest" do
    names = files.map { |f| File.basename(f) }
    expect(names).to match_array(%w[application.css tokens.css base.css layout.css components.css styleguide.css])
  end

  it "starts every file with the same layer order, so load order does not matter (FR-1)" do
    files.each do |file|
      first = Stylesheets.read(file).strip.lines.first.to_s.strip
      expect(first).to eq(Stylesheets::LAYER_LINE), "#{File.basename(file)} must start with the layer line"
    end
  end

  it "keeps the token file to custom properties on :root" do
    body = Stylesheets.read(Stylesheets::TOKENS).sub(Stylesheets::LAYER_LINE, "").strip
    expect(body).to match(/\A:root\s*\{[^{}]*\}\z/m)
    names = Stylesheets.declarations(body).map(&:first)
    expect(names).to all(start_with("--"))
  end

  it "defines the token groups of FR-2" do
    t = Stylesheets.tokens
    %w[--font-sans --text-sm --text-base --text-lg --text-xl --text-2xl --leading-tight --leading-normal
       --weight-regular --weight-strong --gutter --tap-min --content-max --radius --border-width
       --focus-width --focus-offset --scroll-pad].each { |n| expect(t).to have_key(n) }
    (1..8).each { |i| expect(t).to have_key("--space-#{i}") }
    expect(t["--text-base"]).to eq("1rem")
    expect(t["--font-sans"]).to start_with("system-ui").and end_with("sans-serif")
    expect(t["--space-1"]).to eq("0.25rem")
    expect(t["--tap-min"]).to eq("max(44px, 2.75rem)")
    expect(t["--content-max"]).to eq("40rem")
    sizes = %w[--text-sm --text-base --text-lg --text-xl --text-2xl].map { |n| t[n] }
    expect(sizes).to all(match(/\A[\d.]+rem\z/))
    expect(sizes.map(&:to_f).min).to be >= 0.875
  end

  it "has no stray colors, banned properties, px font sizes, imports, fonts or url( outside the tokens (AC-2.4, 2.8, 1.5, 6.2, 4.4)" do
    problems = non_token_files.flat_map { |f| Stylesheets.violations(Stylesheets.read(f), File.basename(f)) }
    expect(problems).to be_empty, problems.join("\n")
  end

  it "does not set a root font size, or block zoom" do
    css = files.map { |f| Stylesheets.read(f) }.join("\n")
    expect(css).not_to match(/(?:html|:root)\s*\{[^}]*font-size/)
    expect(css).not_to include("user-scalable")
  end

  it "keeps a custom property from holding a color outside the token file (AC-2.5)" do
    non_token_files.each do |f|
      Stylesheets.declarations(Stylesheets.read(f)).select { |p, _, _| p.start_with?("--") }.each do |p, v, line|
        expect(v).not_to match(Stylesheets::HEX_COLOR), "#{File.basename(f)}:#{line} #{p} holds a color"
      end
    end
  end

  it "keeps total weight within 24 KB and the style guide within 4 KB (FR-1)" do
    expect(files.sum { |f| File.size(f) }).to be <= 24 * 1024
    expect(File.size(File.join(Stylesheets::DIR, "styleguide.css"))).to be <= 4 * 1024
  end

  it "sets touch-action and safe-area insets, and sizes fields at 1rem (AC-1.4, 1.6, 3.5)" do
    css = files.map { |f| Stylesheets.read(f) }.join("\n")
    expect(css).to include("touch-action: manipulation")
    expect(css).to include("safe-area-inset-bottom")
    expect(css).to include("safe-area-inset-top")
    expect(css).to include("color-scheme: light")
    control = Stylesheets.rules(Stylesheets.read(File.join(Stylesheets::DIR, "components.css")))
                         .find { |sel, _| sel.split(",").map(&:strip).include?(".control") }
    expect(control&.last).to include("font-size: var(--text-base)")
  end

  describe "the scanner itself" do
    def found(css) = Stylesheets.violations(css, "x.css")

    it "flags colors in every form (AC-2.4)" do
      ["a { color: #fff; }", "a { color: #ffffff80; }", "a { color: rgb(0 0 0); }", "a { color: rgba(0,0,0,.5); }",
       "a { color: hsl(10 10% 10%); }", "a { color: oklch(50% 0.1 20); }", "a { color: red; }",
       "a { color: ButtonText; }", "a { background: linear-gradient(white, black); }"].each do |css|
        expect(found(css)).not_to be_empty, css
      end
    end

    it "allows token reads and the three keywords" do
      expect(found("a { color: var(--color-text); background: transparent; border-color: currentColor; outline-color: inherit; }")).to be_empty
    end

    it "does not read a comment as CSS" do
      expect(found(Stylesheets.strip_comments("/* color: red; */ a { color: var(--color-text); }"))).to be_empty
    end

    it "reports the line of a problem" do
      expect(found("a {\n  color: #fff;\n}")).to eq(["x.css:2: hex color in color"])
    end

    it "flags banned properties but allows opacity: 1 (AC-2.8)" do
      expect(found("a { opacity: 0.5; }")).not_to be_empty
      expect(found("a { filter: blur(2px); }")).not_to be_empty
      expect(found("a { backdrop-filter: blur(2px); }")).not_to be_empty
      expect(found("a { mix-blend-mode: multiply; }")).not_to be_empty
      expect(found("a { opacity: 1; }")).to be_empty
    end

    it "flags px font sizes (AC-1.5)" do
      expect(found("a { font-size: 16px; }")).not_to be_empty
      expect(found("a { font: 16px/1.5 sans-serif; }")).not_to be_empty
      expect(found("a { font-size: var(--text-base); }")).to be_empty
    end

    it "flags imports, font rules and url( (AC-6.2)" do
      expect(found("@import 'x.css';")).not_to be_empty
      expect(found("@font-face { font-family: X; }")).not_to be_empty
      expect(found("a { background: url(x.png); }")).not_to be_empty
    end

    it "allows a power token only inside a power badge rule (AC-4.4)" do
      expect(found(".power-badge--austria { --_fill: var(--color-power-austria); }")).to be_empty
      expect(found(".button { color: var(--color-power-austria); }")).not_to be_empty
    end
  end
end
```

- [ ] Write `spec/styles/words_spec.rb`:

```ruby
require "spec_helper"

RSpec.describe "Words and names (AC-6.5)" do
  ROOT = File.expand_path("../..", __dir__)
  # Built from pieces so this file does not contain the words it forbids.
  FORBIDDEN = Regexp.new("diplo" + "macy|\\bd" + "ip[a-z]*", Regexp::IGNORECASE)

  paths = (Dir[File.join(ROOT, "{app,lib,spec}/**/*")] + [File.join(ROOT, "config/routes.rb")])
          .select { |p| File.file?(p) }
          .reject { |p| p == __FILE__ }

  it "finds files to scan" do
    expect(paths.size).to be > 10
  end

  it "has no forbidden word in any file name or content" do
    hits = paths.filter_map do |path|
      relative = path.delete_prefix("#{ROOT}/")
      next "#{relative}: file name" if relative.match?(FORBIDDEN)
      next unless File.extname(path).match?(/\.(rb|erb|css|js|json|svg|md|yml|html)\z/)
      "#{relative}: content" if File.read(path).match?(FORBIDDEN)
    end
    expect(hits).to be_empty, hits.join("\n")
  end
end
```

- [ ] Run: `bundle exec rspec spec/styles` — expect FAIL: the contrast, token and file-list examples about the real stylesheets fail because `tokens.css` and the other files do not exist; the scanner and maths examples pass; the words spec passes.
- [ ] Commit: `Add the failing contrast and stylesheet rule specs`

---

## Phase 1: The tokens and the manifest

**Implements:** FR-2, FR-3, FR-4, FR-9 | **Satisfies:** AC-2.1 to 2.6, 4.1, 4.2
**Files:** `app/assets/stylesheets/tokens.css`, `app/assets/stylesheets/application.css`
**Interfaces:** Consumes: `Stylesheets`, `Contrast` (Phase 0). Produces: every token named in FR-2, read by Phases 2 to 4.

The palette from the table above, as hex values in one file, plus the manifest that carries the layer line. The contrast spec goes green here. Spec examples about the other four files stay red.

- [ ] Write `app/assets/stylesheets/tokens.css`:

```css
@layer reset, base, layout, components, styleguide;

/*
 * Design tokens. The only place a color, font stack, size or step is defined.
 * Every color has a documented pair in spec/styles/contrast_spec.rb, which
 * computes each ratio from this file on every run.
 *
 * Power colors: an even spread of seven hues around the HSL wheel from 17
 * degrees, assigned in alphabetical order, at 60 percent saturation. See
 * web/docs/specs/020-base-stylesheet/plan.md for the derivation.
 */
:root {
  /* Neutrals: warm paper page, cool ink text */
  --color-page: #f6f3ec;
  --color-surface: #ffffff;
  --color-text: #1b2230;
  --color-text-muted: #4b5567;
  --color-border: #6a7385;

  /* Links */
  --color-link: #1d4f9c;
  --color-link-visited: #5b3a8c;

  /* Actions */
  --color-primary: #1f4e8c;
  --color-primary-pressed: #163a69;
  --color-on-primary: #ffffff;
  --color-danger: #a3262a;
  --color-danger-pressed: #7e1b1e;
  --color-on-danger: #ffffff;

  /* Focus and disabled */
  --color-focus: #b3470a;
  --color-disabled-text: #5c6270;
  --color-disabled-fill: #dcd8cf;

  /* Powers: shown only as a badge that carries the power's name */
  --color-on-power: #ffffff;
  --color-power-austria: #b8552e;
  --color-power-england: #6e7a1f;
  --color-power-france: #218321;
  --color-power-germany: #207e71;
  --color-power-italy: #335fcc;
  --color-power-russia: #8a33cc;
  --color-power-turkey: #cc338b;

  /* Type: system fonts only */
  --font-sans: system-ui, -apple-system, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
  --text-sm: 0.875rem;
  --text-base: 1rem;
  --text-lg: 1.25rem;
  --text-xl: 1.5rem;
  --text-2xl: 2rem;
  --leading-tight: 1.2;
  --leading-normal: 1.5;
  --weight-regular: 400;
  --weight-strong: 600;

  /* Spacing: 0.25rem steps, wider at the top */
  --space-1: 0.25rem;
  --space-2: 0.5rem;
  --space-3: 0.75rem;
  --space-4: 1rem;
  --space-5: 1.5rem;
  --space-6: 2rem;
  --space-7: 3rem;
  --space-8: 4rem;
  --gutter: var(--space-4);

  /* Sizing */
  --tap-min: max(44px, 2.75rem);
  --content-max: 40rem;
  --radius: 0.5rem;
  --border-width: 2px;
  --focus-width: 3px;
  --focus-offset: 2px;
  --scroll-pad: calc(var(--tap-min) + var(--space-6) + env(safe-area-inset-bottom, 0px));
}
```

- [ ] Replace `app/assets/stylesheets/application.css` with:

```css
@layer reset, base, layout, components, styleguide;

/*
 * Propshaft links every CSS file in this folder (stylesheet_link_tag :app),
 * in file-name order. Each file begins with the layer line above, so the
 * cascade order does not depend on that order.
 *
 *   tokens.css      design tokens only
 *   base.css        reset and plain elements
 *   layout.css      header, main, action area
 *   components.css  button, list, field, choice, power badge
 *   styleguide.css  rules for the development-only /styleguide page
 */
```

- [ ] Run: `bundle exec rspec spec/styles/contrast_spec.rb` — expect PASS (all 46 pairs). If a ratio fails, retune that token in `tokens.css`, rerun, and write the new value in the palette table above.
- [ ] Run: `bundle exec rspec spec/styles` — expect the file-list, layer-line and `components.css` examples still FAIL (files missing), the rest PASS.
- [ ] Commit: `Add the design tokens and an original palette`

---

## Phase 2: Base styles, layout and the layout file

**Implements:** FR-1, FR-5, FR-8 | **Satisfies:** AC-1.1, 1.5, 3.1 to 3.10, 5.3, 6.6
**Files:** `app/assets/stylesheets/base.css`, `app/assets/stylesheets/layout.css`, `app/views/layouts/application.html.erb`, `app/views/home/index.html.erb`, `spec/requests/layout_spec.rb`, `spec/requests/root_spec.rb`
**Interfaces:** Consumes: the tokens of Phase 1. Produces: the layout's three regions (`.app-header`, `.app-main`, `.app-actions`) and the `content_for :actions` hook, used by Phase 4's page and every later screen.

- [ ] Write `spec/requests/layout_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe "Layout", type: :request do
  before { get "/" }

  let(:page) { Nokogiri::HTML5(response.body) }

  it "sets the language and a viewport that covers the unsafe edges and allows zoom" do
    expect(page.at_css("html")["lang"]).to eq("en")
    viewport = page.at_css("meta[name=viewport]")["content"]
    expect(viewport).to include("width=device-width", "initial-scale=1", "viewport-fit=cover")
    expect(viewport).not_to include("user-scalable")
    expect(viewport).not_to include("maximum-scale")
  end

  it "has one header and one main landmark, supplied by the layout (AC-6.6)" do
    expect(page.css("header").size).to eq(1)
    expect(page.css("main").size).to eq(1)
    expect(page.at_css("main h1").text).to eq("Trucebearer")
  end

  it "shows the app name in the header as a link to the root page" do
    link = page.at_css("header a.app-header__name")
    expect(link.text.strip).to eq("Trucebearer")
    expect(link["href"]).to eq("/")
  end

  it "renders no action area when the page gives none (AC-3.7)" do
    expect(page.css(".app-actions")).to be_empty
  end

  it "does not link to the style guide (AC-5.3)" do
    expect(page.css("a[href*=styleguide]")).to be_empty
  end

  it "links every stylesheet in the folder" do
    hrefs = page.css("link[rel=stylesheet]").map { |l| l["href"] }
    names = Dir[Rails.root.join("app/assets/stylesheets/*.css")].map { |f| File.basename(f, ".css") }
    expect(names).to include("tokens", "base", "layout")
    names.each { |name| expect(hrefs.grep(/#{name}-/)).not_to be_empty, "no link for #{name}.css" }
  end
end
```

- [ ] Replace `spec/requests/root_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe "Root page", type: :request do
  it "responds with success on GET / and keeps its own content (AC-6.6)" do
    get "/"

    expect(response).to have_http_status(:ok)
    body = Nokogiri::HTML5(response.body)
    expect(body.at_css("h1").text).to eq("Trucebearer")
    expect(body.at_css("main p").text).to eq("Enter secret orders on your phone and have each turn adjudicated.")
  end
end
```

- [ ] Run: `bundle exec rspec spec/requests` — expect FAIL (no `lang`, no `viewport-fit`, no header, no `.app-header__name`, two or zero `main`).
- [ ] Write `app/assets/stylesheets/base.css`:

```css
@layer reset, base, layout, components, styleguide;

@layer reset {
  *,
  *::before,
  *::after {
    box-sizing: border-box;
  }

  html {
    -webkit-text-size-adjust: 100%;
    text-size-adjust: 100%;
  }

  body,
  h1,
  h2,
  h3,
  p,
  ul,
  ol,
  fieldset,
  figure {
    margin: 0;
  }

  fieldset {
    min-width: 0;
    padding: 0;
    border: 0;
  }

  button,
  input,
  select,
  textarea {
    font: inherit;
    color: inherit;
  }

  ::placeholder {
    opacity: 1;
  }
}

@layer base {
  :root {
    color-scheme: light;
  }

  html {
    scroll-padding-bottom: var(--scroll-pad);
  }

  body {
    background: var(--color-page);
    color: var(--color-text);
    font-family: var(--font-sans);
    font-size: var(--text-base);
    font-weight: var(--weight-regular);
    line-height: var(--leading-normal);
  }

  h1,
  h2,
  h3 {
    font-weight: var(--weight-strong);
    line-height: var(--leading-tight);
  }

  h1 {
    font-size: var(--text-2xl);
  }

  h2 {
    font-size: var(--text-xl);
  }

  h3 {
    font-size: var(--text-lg);
  }

  legend {
    padding: 0;
    font-weight: var(--weight-strong);
  }

  small,
  .text-small {
    font-size: var(--text-sm);
  }

  .text-muted {
    color: var(--color-text-muted);
  }

  /* One vertical rhythm for stacked content */
  .stack > * + * {
    margin-block-start: var(--space-4);
  }

  a {
    color: var(--color-link);
    text-decoration: underline;
    text-decoration-thickness: from-font;
    text-underline-offset: 0.2em;
  }

  a:visited {
    color: var(--color-link-visited);
  }

  @media (hover: hover) {
    a:hover {
      text-decoration-thickness: var(--border-width);
    }
  }

  ::placeholder {
    color: var(--color-text-muted);
  }

  :focus-visible {
    outline: var(--focus-width) solid var(--color-focus);
    outline-offset: var(--focus-offset);
  }
}
```

Reduced motion is handled in Phase 3, next to the only rule that has a transition (`.button`), so no `!important` is needed anywhere.

- [ ] Write `app/assets/stylesheets/layout.css`:

```css
@layer reset, base, layout, components, styleguide;

@layer layout {
  .app {
    display: flex;
    flex-direction: column;
    min-height: 100vh;
    min-height: 100dvh;
  }

  /* One centered column. The side padding clears a notch in landscape. */
  .app-column {
    width: 100%;
    max-width: var(--content-max);
    margin-inline: auto;
    padding-left: max(var(--gutter), env(safe-area-inset-left, 0px));
    padding-right: max(var(--gutter), env(safe-area-inset-right, 0px));
  }

  .app-header {
    padding-top: env(safe-area-inset-top, 0px);
    background: var(--color-surface);
    border-bottom: var(--border-width) solid var(--color-border);
  }

  .app-header__name {
    display: inline-flex;
    align-items: center;
    min-height: var(--tap-min);
    color: var(--color-text);
    font-size: var(--text-lg);
    font-weight: var(--weight-strong);
    text-decoration: none;
  }

  .app-header__name:visited {
    color: var(--color-text);
  }

  @media (hover: hover) {
    .app-header__name:hover {
      text-decoration: underline;
    }
  }

  .app-main {
    flex: 1 0 auto;
    padding-top: var(--space-5);
    padding-bottom: var(--space-5);
  }

  /* In the page flow, after main. It sticks to the bottom of the viewport
     while the page scrolls, and never covers the end of the content. */
  .app-actions {
    position: sticky;
    bottom: 0;
    padding-bottom: env(safe-area-inset-bottom, 0px);
    background: var(--color-surface);
    border-top: var(--border-width) solid var(--color-border);
  }

  .app-actions__inner {
    display: flex;
    flex-wrap: wrap;
    gap: var(--space-2);
    padding-top: var(--space-3);
    padding-bottom: var(--space-3);
  }

  /* Up to two share a row. One alone, or one that no longer fits, is full width. */
  .app-actions__inner > * {
    flex: 1 1 8rem;
  }

  /* A short screen (a phone on its side) gives the area no room to stick */
  @media (max-height: 30rem) {
    .app-actions {
      position: static;
    }
  }
}
```

- [ ] Replace `app/views/layouts/application.html.erb` (everything above `<head>` content stays as generated, except the `<html>` tag, the viewport and the `<body>`):

```erb
<!DOCTYPE html>
<html lang="en">
  <head>
    <title><%= content_for(:title) || "Trucebearer" %></title>
    <meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">
    <meta name="apple-mobile-web-app-capable" content="yes">
    <meta name="application-name" content="Trucebearer">
    <meta name="mobile-web-app-capable" content="yes">
    <%= csrf_meta_tags %>
    <%= csp_meta_tag %>

    <%= yield :head %>

    <%# Enable PWA manifest for installable apps (make sure to enable in config/routes.rb too!) %>
    <%#= tag.link rel: "manifest", href: pwa_manifest_path(format: :json) %>

    <link rel="icon" href="/icon.png" type="image/png">
    <link rel="icon" href="/icon.svg" type="image/svg+xml">
    <link rel="apple-touch-icon" href="/icon.png">

    <%# Includes all stylesheet files in app/assets/stylesheets %>
    <%= stylesheet_link_tag :app, "data-turbo-track": "reload" %>
    <%= javascript_importmap_tags %>
  </head>

  <body class="app">
    <header class="app-header">
      <div class="app-column">
        <%= link_to "Trucebearer", root_path, class: "app-header__name" %>
      </div>
    </header>

    <main class="app-main app-column">
      <%= yield %>
    </main>

    <% if content_for?(:actions) %>
      <div class="app-actions" role="group" aria-label="Actions">
        <div class="app-actions__inner app-column">
          <%= yield :actions %>
        </div>
      </div>
    <% end %>
  </body>
</html>
```

- [ ] Replace `app/views/home/index.html.erb` (the layout now supplies `main`):

```erb
<% content_for :title, "Trucebearer" %>

<div class="stack">
  <h1>Trucebearer</h1>
  <p>Enter secret orders on your phone and have each turn adjudicated.</p>
</div>
```

- [ ] Run: `bundle exec rspec spec/requests spec/styles/stylesheet_rules_spec.rb` — expect request specs PASS; rules spec still FAILS on the missing `components.css` and `styleguide.css` (file list, layer line).
- [ ] Commit: `Add base styles, the page layout and the sticky action area`

---

## Phase 3: Components and the power badge

**Implements:** FR-4, FR-6 | **Satisfies:** AC-1.2, 1.3, 1.4, 1.6, 2.7, 4.3, 4.4
**Files:** `app/assets/stylesheets/components.css`, `app/helpers/power_badge_helper.rb`, `spec/helpers/power_badge_helper_spec.rb`
**Interfaces:** Consumes: tokens (Phase 1). Produces: the classes `.button` (`--secondary`, `--danger`), `.list` and `.list__row`, `.field` (`__label`, `__hint`, `__error`), `.control`, `.choices` and `.choice`, `.power-badge` (`--<id>`), and the helper `power_badge(identifier)`. Phase 4 renders all of them.

- [ ] Write `spec/helpers/power_badge_helper_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe PowerBadgeHelper, type: :helper do
  NAMES = {
    "austria" => "Austria", "england" => "England", "france" => "France", "germany" => "Germany",
    "italy" => "Italy", "russia" => "Russia", "turkey" => "Turkey"
  }.freeze

  NAMES.each do |id, name|
    it "prints the name of #{id} as the badge text (AC-4.3)" do
      html = Nokogiri::HTML5.fragment(helper.power_badge(id))
      badge = html.at_css("span.power-badge.power-badge--#{id}")
      expect(badge.text).to eq(name)
    end
  end

  it "accepts a symbol or a string" do
    expect(helper.power_badge(:england)).to eq(helper.power_badge("england"))
  end

  it "raises ArgumentError for an unknown identifier, nil, or an empty string" do
    [:wales, "wales", nil, ""].each do |bad|
      expect { helper.power_badge(bad) }.to raise_error(ArgumentError)
    end
  end
end
```

- [ ] Run: `bundle exec rspec spec/helpers` — expect FAIL (`PowerBadgeHelper` is not defined).
- [ ] Write `app/helpers/power_badge_helper.rb`:

```ruby
# The one way to show a power's color. The badge always carries the power's name,
# so color is never the only signal (Issue #20, spec 020 FR-4).
#
# The names are written here for now. When the app pins the adjudicator gem, a later
# issue replaces this list with the names the gem's map returns.
module PowerBadgeHelper
  POWER_NAMES = {
    "austria" => "Austria",
    "england" => "England",
    "france" => "France",
    "germany" => "Germany",
    "italy" => "Italy",
    "russia" => "Russia",
    "turkey" => "Turkey"
  }.freeze

  def power_badge(identifier)
    key = identifier.to_s
    name = POWER_NAMES.fetch(key) { raise ArgumentError, "unknown power: #{identifier.inspect}" }
    tag.span(name, class: ["power-badge", "power-badge--#{key}"])
  end
end
```

- [ ] Write `app/assets/stylesheets/components.css`:

```css
@layer reset, base, layout, components, styleguide;

@layer components {
  /* ---- Button: <button>, <a> or <input type="submit"> with class "button" ----
     Each variant sets four local properties from tokens. A pressed button also
     thickens its edge by drawing an inset ring, so it changes shape as well as fill. */
  .button {
    --_fill: var(--color-primary);
    --_fill-pressed: var(--color-primary-pressed);
    --_edge: var(--color-primary);
    --_edge-pressed: var(--color-primary-pressed);
    --_ink: var(--color-on-primary);

    display: inline-flex;
    align-items: center;
    justify-content: center;
    gap: var(--space-2);
    min-width: var(--tap-min);
    min-height: var(--tap-min);
    padding: var(--space-2) var(--space-4);
    border: var(--border-width) solid var(--_edge);
    border-radius: var(--radius);
    background: var(--_fill);
    color: var(--_ink);
    font-size: var(--text-base);
    font-weight: var(--weight-strong);
    line-height: var(--leading-tight);
    text-align: center;
    text-decoration: none;
    cursor: pointer;
    touch-action: manipulation;
    -webkit-tap-highlight-color: transparent;
    transition: background-color 120ms ease, box-shadow 120ms ease;
  }

  .button--secondary {
    --_fill: var(--color-surface);
    --_fill-pressed: var(--color-page);
    --_edge: var(--color-border);
    --_edge-pressed: var(--color-border);
    --_ink: var(--color-text);
  }

  .button--danger {
    --_fill: var(--color-danger);
    --_fill-pressed: var(--color-danger-pressed);
    --_edge: var(--color-danger);
    --_edge-pressed: var(--color-danger-pressed);
    --_ink: var(--color-on-danger);
  }

  @media (hover: hover) {
    .button:hover:not(:disabled):not([aria-disabled="true"]) {
      background: var(--_fill-pressed);
    }
  }

  .button:active:not(:disabled):not([aria-disabled="true"]) {
    background: var(--_fill-pressed);
    box-shadow: inset 0 0 0 var(--border-width) var(--_edge-pressed);
  }

  .button:disabled,
  .button[aria-disabled="true"] {
    --_fill: var(--color-disabled-fill);
    --_edge: var(--color-disabled-text);
    --_ink: var(--color-disabled-text);
    pointer-events: none;
  }

  /* ---- List: <ul class="list"> of <li><a|button|div class="list__row"> ---- */
  .list {
    margin: 0;
    padding: 0;
    overflow: hidden;
    list-style: none;
    background: var(--color-surface);
    border: var(--border-width) solid var(--color-border);
    border-radius: var(--radius);
  }

  .list > li + li {
    border-top: var(--border-width) solid var(--color-border);
  }

  .list__row {
    display: flex;
    align-items: center;
    gap: var(--space-3);
    width: 100%;
    min-height: var(--tap-min);
    padding: var(--space-2) var(--space-4);
    border: 0;
    background: var(--color-surface);
    color: var(--color-text);
    text-align: start;
    text-decoration: none;
  }

  a.list__row,
  button.list__row {
    cursor: pointer;
    touch-action: manipulation;
    -webkit-tap-highlight-color: transparent;
  }

  a.list__row:visited {
    color: var(--color-text);
  }

  /* The list clips its corners, so the ring sits inside the row */
  .list__row:focus-visible {
    outline-offset: calc(var(--focus-width) * -1);
  }

  @media (hover: hover) {
    a.list__row:hover,
    button.list__row:hover {
      background: var(--color-page);
    }
  }

  a.list__row:active,
  button.list__row:active {
    background: var(--color-page);
    box-shadow: inset 0 0 0 var(--border-width) var(--color-border);
  }

  /* ---- Field: label above the control, optional hint and error ---- */
  .field {
    display: flex;
    flex-direction: column;
    gap: var(--space-1);
  }

  .field__label {
    font-weight: var(--weight-strong);
  }

  .field__hint {
    color: var(--color-text-muted);
    font-size: var(--text-sm);
  }

  /* The text starts with the word "Error:", so color is not the only signal */
  .field__error {
    color: var(--color-danger);
    font-weight: var(--weight-strong);
  }

  .control {
    display: block;
    width: 100%;
    min-height: var(--tap-min);
    padding: var(--space-2) var(--space-3);
    border: var(--border-width) solid var(--color-border);
    border-radius: var(--radius);
    background: var(--color-surface);
    color: var(--color-text);
    font-size: var(--text-base);
    line-height: var(--leading-normal);
  }

  textarea.control {
    min-height: calc(var(--tap-min) * 2.5);
    resize: vertical;
  }

  .control[aria-invalid="true"] {
    border-color: var(--color-danger);
    box-shadow: inset 0 0 0 var(--border-width) var(--color-danger);
  }

  .control:disabled {
    border-color: var(--color-disabled-text);
    background: var(--color-disabled-fill);
    color: var(--color-disabled-text);
  }

  /* ---- Choice: checkbox or radio, label inside the tappable row ---- */
  .choices {
    display: flex;
    flex-direction: column;
  }

  .choice {
    display: flex;
    align-items: center;
    gap: var(--space-3);
    min-height: var(--tap-min);
    padding: var(--space-2) var(--space-3);
    border: var(--border-width) solid var(--color-border);
    background: var(--color-surface);
    color: var(--color-text);
    cursor: pointer;
    touch-action: manipulation;
    -webkit-tap-highlight-color: transparent;
  }

  .choice + .choice {
    margin-top: calc(var(--border-width) * -1);
  }

  .choice:first-child {
    border-top-left-radius: var(--radius);
    border-top-right-radius: var(--radius);
  }

  .choice:last-child {
    border-bottom-left-radius: var(--radius);
    border-bottom-right-radius: var(--radius);
  }

  .choice input {
    flex: none;
    width: var(--space-5);
    height: var(--space-5);
    margin: 0;
    accent-color: var(--color-primary);
  }

  .choice:active {
    background: var(--color-page);
    box-shadow: inset 0 0 0 var(--border-width) var(--color-border);
  }

  .choice[aria-disabled="true"] {
    border-color: var(--color-disabled-text);
    background: var(--color-disabled-fill);
    color: var(--color-disabled-text);
    pointer-events: none;
  }

  /* ---- Power badge: made only by the power_badge helper, always with the name ---- */
  .power-badge {
    --_fill: var(--color-surface);

    display: inline-flex;
    align-items: center;
    padding: var(--space-1) var(--space-3);
    border: var(--border-width) solid var(--_fill);
    border-radius: var(--radius);
    background: var(--_fill);
    color: var(--color-on-power);
    font-weight: var(--weight-strong);
    line-height: var(--leading-tight);
  }

  .power-badge--austria { --_fill: var(--color-power-austria); }
  .power-badge--england { --_fill: var(--color-power-england); }
  .power-badge--france { --_fill: var(--color-power-france); }
  .power-badge--germany { --_fill: var(--color-power-germany); }
  .power-badge--italy { --_fill: var(--color-power-italy); }
  .power-badge--russia { --_fill: var(--color-power-russia); }
  .power-badge--turkey { --_fill: var(--color-power-turkey); }

  /* ---- Reduced motion: no transition runs ---- */
  @media (prefers-reduced-motion: reduce) {
    .button {
      transition: none;
    }
  }
}
```

Reduced motion is handled in the component that has a transition, so no `!important` is needed and the Phase 2 base block is left out as noted there.

- [ ] Run: `bundle exec rspec spec/helpers spec/styles/contrast_spec.rb` — expect PASS.
- [ ] Run: `bundle exec rspec spec/styles/stylesheet_rules_spec.rb` — expect the remaining failures only for the missing `styleguide.css` (file list, layer line, size).
- [ ] Commit: `Add buttons, lists, fields, choices and the power badge`

---

## Phase 4: The style guide

**Implements:** FR-7, FR-6 (shown) | **Satisfies:** AC-4.5, 5.1 to 5.5
**Files:** `config/application.rb`, `config/environments/development.rb`, `config/environments/test.rb`, `config/routes.rb`, `app/controllers/styleguide_controller.rb`, `app/helpers/styleguide_helper.rb`, `app/views/styleguide/show.html.erb`, `app/assets/stylesheets/styleguide.css`, `spec/requests/styleguide_spec.rb`
**Interfaces:** Consumes: components (Phase 3), `power_badge`, the layout's `content_for :actions`. Produces: `GET /styleguide` (development and test only) and `Rails.configuration.x.styleguide`.

- [ ] Write `spec/requests/styleguide_spec.rb`:

```ruby
require "rails_helper"
require_relative "../support/stylesheets"

RSpec.describe "Style guide", type: :request do
  COMPONENTS = %w[button link list field choice power-badge heading-text].freeze
  # The documented pairs other than the power pairs (spec FR-3): 25 of them.
  NON_POWER_PAIR_COUNT = 25

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
      expect(page.css("section[data-component]").map { |s| s["data-component"] }).to match_array(COMPONENTS)
    end

    it "shows static variants: each button variant, disabled, invalid, a disabled choice (AC-5.1)" do
      expect(page.css(".button").size).to be >= 8
      expect(page.css(".button--secondary, .button--danger").size).to be >= 4
      expect(page.css(".button[disabled], .button[aria-disabled=true]").size).to be >= 2
      expect(page.css(".control[aria-invalid=true]").size).to be >= 1
      expect(page.css(".field__error").map(&:text)).to all(start_with("Error:"))
      expect(page.css(".choice[aria-disabled=true]").size).to be >= 1
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
      expect(samples.size).to eq(NON_POWER_PAIR_COUNT)
      expect(samples.map { |s| s.at_css(".sg-sample__meta").text }).to all(match(/\S+ on \S+ \(min \d(\.\d)?\)/))
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

    it "uses no inline styles and loads no script of its own" do
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
```

The count of 25 non-power pairs is the number of rows in `DOCUMENTED_PAIRS` in the contrast spec. If a pair is ever added, both numbers change in the same pull request.

- [ ] Run: `bundle exec rspec spec/requests/styleguide_spec.rb` — expect FAIL (no route).
- [ ] Edit `config/application.rb`: inside `class Application`, after `config.generators.system_tests = nil`, add:

```ruby
    # The style guide page (spec 020) exists only where this is true: development and test.
    config.x.styleguide = false
```

- [ ] Edit `config/environments/development.rb` and `config/environments/test.rb`: inside the `configure` block, add:

```ruby
  # The style guide page (spec 020).
  config.x.styleguide = true
```

- [ ] Edit `config/routes.rb`: before `root "home#index"`, add:

```ruby
  # Development and test only. See config.x.styleguide. Never linked from any page.
  constraints(->(_request) { Rails.configuration.x.styleguide }) do
    get "styleguide" => "styleguide#show"
  end
```

- [ ] Write `app/controllers/styleguide_controller.rb`:

```ruby
# Shows the tokens and components of the base stylesheet. Development and test only:
# the route exists only where config.x.styleguide is true.
class StyleguideController < ApplicationController
  def show
  end
end
```

- [ ] Write `app/helpers/styleguide_helper.rb`. The pair list is the third hand copy (spec FR-7) and carries the non-power pairs only:

```ruby
module StyleguideHelper
  # The color tokens other than the power colors, in the order they are shown.
  COLOR_TOKENS = %w[
    page surface text text-muted border link link-visited primary primary-pressed on-primary
    danger danger-pressed on-danger focus disabled-text disabled-fill on-power
  ].freeze

  # [foreground, background, minimum ratio] for the documented pairs other than the power pairs.
  PAIRS = [
    ["text", "page", "4.5"], ["text", "surface", "4.5"],
    ["text-muted", "page", "4.5"], ["text-muted", "surface", "4.5"],
    ["link", "page", "4.5"], ["link", "surface", "4.5"],
    ["link-visited", "page", "4.5"], ["link-visited", "surface", "4.5"],
    ["on-primary", "primary", "4.5"], ["on-primary", "primary-pressed", "4.5"],
    ["primary", "page", "3"], ["primary", "surface", "3"],
    ["primary-pressed", "page", "3"], ["primary-pressed", "surface", "3"],
    ["border", "page", "3"], ["border", "surface", "3"],
    ["danger", "page", "4.5"], ["danger", "surface", "4.5"],
    ["on-danger", "danger", "4.5"], ["on-danger", "danger-pressed", "4.5"],
    ["danger-pressed", "page", "3"], ["danger-pressed", "surface", "3"],
    ["focus", "page", "3"], ["focus", "surface", "3"],
    ["disabled-text", "disabled-fill", "3"]
  ].freeze

  TYPE_STEPS = %w[sm base lg xl 2xl].freeze
  SPACE_STEPS = (1..8).to_a.freeze
  POWER_IDS = PowerBadgeHelper::POWER_NAMES.keys.freeze
end
```

- [ ] Write `app/views/styleguide/show.html.erb`. All text is original. No component text is taken from any rulebook; examples use made-up labels:

```erb
<% content_for :title, "Style guide" %>

<% content_for :actions do %>
  <button type="button" class="button button--secondary">Back</button>
  <button type="button" class="button">Send</button>
<% end %>

<div class="stack">
  <h1>Style guide</h1>
  <p>The tokens and parts of the base stylesheet. Only available while developing. Change the stylesheet, then check this page at 360 and 768 pixels wide.</p>

  <section data-component="heading-text" class="stack" aria-labelledby="sg-text">
    <h2 id="sg-text">Headings and text</h2>
    <h1>Heading one</h1>
    <h2>Heading two</h2>
    <h3>Heading three</h3>
    <p>Body text is one rem. <span class="text-muted">Muted text is for hints.</span> <small>Small text is the smallest step.</small></p>
    <ul class="sg-type">
      <% StyleguideHelper::TYPE_STEPS.each do |step| %>
        <li class="sg-type-step sg-type-step--<%= step %>">--text-<%= step %></li>
      <% end %>
    </ul>
    <ul class="sg-space">
      <% StyleguideHelper::SPACE_STEPS.each do |step| %>
        <li class="sg-space-step"><span class="sg-space-bar sg-space-bar--<%= step %>"></span> --space-<%= step %></li>
      <% end %>
    </ul>
  </section>

  <section data-component="link" class="stack" aria-labelledby="sg-link">
    <h2 id="sg-link">Links</h2>
    <p>A link in running text is <a href="#sg-link">underlined and colored</a>, and a visited one is <a href="/">colored differently</a>.</p>
  </section>

  <section data-component="button" class="stack" aria-labelledby="sg-button">
    <h2 id="sg-button">Buttons</h2>
    <div class="sg-row">
      <button type="button" class="button">Primary</button>
      <button type="button" class="button button--secondary">Secondary</button>
      <button type="button" class="button button--danger">Danger</button>
    </div>
    <div class="sg-row">
      <button type="button" class="button" disabled>Primary</button>
      <button type="button" class="button button--secondary" disabled>Secondary</button>
      <button type="button" class="button button--danger" disabled>Danger</button>
    </div>
    <div class="sg-row">
      <a href="#sg-button" class="button">Link as button</a>
      <a class="button button--secondary" aria-disabled="true" tabindex="-1">Disabled link</a>
      <input type="submit" class="button" value="Submit input">
    </div>
  </section>

  <section data-component="list" class="stack" aria-labelledby="sg-list">
    <h2 id="sg-list">Lists</h2>
    <ul class="list">
      <li><a href="#sg-list" class="list__row">A row you can tap</a></li>
      <li><a href="#sg-list" class="list__row">Another row you can tap</a></li>
      <li><div class="list__row">A row with text only</div></li>
    </ul>
  </section>

  <section data-component="field" class="stack" aria-labelledby="sg-field">
    <h2 id="sg-field">Form fields</h2>
    <div class="field">
      <label class="field__label" for="sg-name">Name</label>
      <input class="control" id="sg-name" type="text" autocomplete="off" aria-describedby="sg-name-hint">
      <span class="field__hint" id="sg-name-hint">What the others at the table call you.</span>
    </div>
    <div class="field">
      <label class="field__label" for="sg-power">Choose one</label>
      <select class="control" id="sg-power">
        <option>First</option>
        <option>Second</option>
      </select>
    </div>
    <div class="field">
      <label class="field__label" for="sg-note">Note</label>
      <textarea class="control" id="sg-note"></textarea>
    </div>
    <div class="field">
      <label class="field__label" for="sg-code">Code (required)</label>
      <input class="control" id="sg-code" type="text" aria-invalid="true" aria-describedby="sg-code-error" required>
      <p class="field__error" id="sg-code-error">Error: enter the code you were given.</p>
    </div>
    <div class="field">
      <label class="field__label" for="sg-off">Not available</label>
      <input class="control" id="sg-off" type="text" disabled value="Disabled">
    </div>
  </section>

  <section data-component="choice" class="stack" aria-labelledby="sg-choice">
    <h2 id="sg-choice">Choices</h2>
    <fieldset class="choices">
      <legend>Pick any</legend>
      <label class="choice"><input type="checkbox"> First option</label>
      <label class="choice"><input type="checkbox" checked> Second option</label>
      <label class="choice" aria-disabled="true"><input type="checkbox" disabled> Not available</label>
    </fieldset>
    <fieldset class="choices">
      <legend>Pick one</legend>
      <label class="choice"><input type="radio" name="sg-radio"> Left</label>
      <label class="choice"><input type="radio" name="sg-radio" checked> Right</label>
    </fieldset>
  </section>

  <section data-component="power-badge" class="stack" aria-labelledby="sg-power-badge">
    <h2 id="sg-power-badge">Power badges</h2>
    <p>A power's color always comes with its name.</p>
    <ul class="sg-powers">
      <% StyleguideHelper::POWER_IDS.each do |id| %>
        <li class="sg-power"><%= power_badge(id) %> <code class="sg-power__token">--color-power-<%= id %></code></li>
      <% end %>
    </ul>
  </section>

  <section class="stack" aria-labelledby="sg-colors">
    <h2 id="sg-colors">Colors</h2>
    <ul class="sg-swatches">
      <% StyleguideHelper::COLOR_TOKENS.each do |token| %>
        <li class="sg-swatch"><span class="sg-chip sg-bg-<%= token %>"></span> <code class="sg-swatch__name">--color-<%= token %></code></li>
      <% end %>
    </ul>
    <h3>Documented pairs</h3>
    <p class="text-muted">Each sample shows the foreground on its background. The contrast spec measures every pair, power pairs included.</p>
    <ul class="sg-samples">
      <% StyleguideHelper::PAIRS.each do |fg, bg, min| %>
        <li class="sg-sample sg-bg-<%= bg %> sg-fg-<%= fg %>">
          <span>Sample text</span>
          <span class="sg-sample__meta"><%= fg %> on <%= bg %> (min <%= min %>)</span>
        </li>
      <% end %>
    </ul>
  </section>
</div>
```

The `<code>` token names and the sample meta lines sit on `surface` and `page` backgrounds only, so they stay inside documented pairs; the sample lines inherit the sample's own foreground, which is the pair being shown.

- [ ] Write `app/assets/stylesheets/styleguide.css`:

```css
@layer reset, base, layout, components, styleguide;

@layer styleguide {
  .sg-row { display: flex; flex-wrap: wrap; gap: var(--space-2); }

  .sg-type,
  .sg-space,
  .sg-powers,
  .sg-swatches,
  .sg-samples { margin: 0; padding: 0; list-style: none; }

  .sg-type-step--sm { font-size: var(--text-sm); }
  .sg-type-step--base { font-size: var(--text-base); }
  .sg-type-step--lg { font-size: var(--text-lg); }
  .sg-type-step--xl { font-size: var(--text-xl); }
  .sg-type-step--2xl { font-size: var(--text-2xl); }

  .sg-space-step { display: flex; align-items: center; gap: var(--space-2); }
  .sg-space-bar { height: var(--space-2); background: var(--color-primary); }
  .sg-space-bar--1 { width: var(--space-1); }
  .sg-space-bar--2 { width: var(--space-2); }
  .sg-space-bar--3 { width: var(--space-3); }
  .sg-space-bar--4 { width: var(--space-4); }
  .sg-space-bar--5 { width: var(--space-5); }
  .sg-space-bar--6 { width: var(--space-6); }
  .sg-space-bar--7 { width: var(--space-7); }
  .sg-space-bar--8 { width: var(--space-8); }

  .sg-power { display: flex; align-items: center; gap: var(--space-3); padding: var(--space-1) 0; }
  .sg-swatch { display: flex; align-items: center; gap: var(--space-3); padding: var(--space-1) 0; }
  .sg-chip { flex: none; width: var(--tap-min); height: var(--tap-min); border: var(--border-width) solid var(--color-border); border-radius: var(--radius); }

  .sg-sample { display: flex; flex-direction: column; margin-bottom: var(--space-2); padding: var(--space-3) var(--space-4); border: var(--border-width) solid var(--color-border); border-radius: var(--radius); }
  .sg-sample__meta { font-size: var(--text-sm); }

  .sg-bg-page { background: var(--color-page); }
  .sg-bg-surface { background: var(--color-surface); }
  .sg-bg-text { background: var(--color-text); }
  .sg-bg-text-muted { background: var(--color-text-muted); }
  .sg-bg-border { background: var(--color-border); }
  .sg-bg-link { background: var(--color-link); }
  .sg-bg-link-visited { background: var(--color-link-visited); }
  .sg-bg-primary { background: var(--color-primary); }
  .sg-bg-primary-pressed { background: var(--color-primary-pressed); }
  .sg-bg-on-primary { background: var(--color-on-primary); }
  .sg-bg-danger { background: var(--color-danger); }
  .sg-bg-danger-pressed { background: var(--color-danger-pressed); }
  .sg-bg-on-danger { background: var(--color-on-danger); }
  .sg-bg-focus { background: var(--color-focus); }
  .sg-bg-disabled-text { background: var(--color-disabled-text); }
  .sg-bg-disabled-fill { background: var(--color-disabled-fill); }
  .sg-bg-on-power { background: var(--color-on-power); }

  .sg-fg-page { color: var(--color-page); }
  .sg-fg-surface { color: var(--color-surface); }
  .sg-fg-text { color: var(--color-text); }
  .sg-fg-text-muted { color: var(--color-text-muted); }
  .sg-fg-border { color: var(--color-border); }
  .sg-fg-link { color: var(--color-link); }
  .sg-fg-link-visited { color: var(--color-link-visited); }
  .sg-fg-primary { color: var(--color-primary); }
  .sg-fg-primary-pressed { color: var(--color-primary-pressed); }
  .sg-fg-on-primary { color: var(--color-on-primary); }
  .sg-fg-danger { color: var(--color-danger); }
  .sg-fg-danger-pressed { color: var(--color-danger-pressed); }
  .sg-fg-on-danger { color: var(--color-on-danger); }
  .sg-fg-focus { color: var(--color-focus); }
  .sg-fg-disabled-text { color: var(--color-disabled-text); }
}
```

- [ ] Run: `bundle exec rspec` — expect everything PASS: the contrast spec, the rules spec (all five files present, total under 24 KB, `styleguide.css` under 4 KB), helper, layout, root, style guide, words. If `styleguide.css` is over 4 KB, trim the `sg-bg-*` and `sg-fg-*` lines that no pair uses. If the words spec finds a match, rename it (do not widen the exemption).
- [ ] Commit: `Add the development-only style guide page`

---

## Phase 5: Measure in a real browser, then document

**Implements:** FR-5, FR-6, FR-8 (geometry) | **Satisfies:** AC-1.1 to 1.3, 3.1 to 3.4, 3.6, 3.8 to 3.10, 6.3, and the pressed, hover, focus ring, forced colors and reduced motion checks
**Files:** `docs/specs/020-base-stylesheet/measure.md`, `docs/specs/020-base-stylesheet/screenshots/styleguide-360.png`, `docs/specs/020-base-stylesheet/screenshots/styleguide-768.png`
**Interfaces:** Consumes: the running `/styleguide` page. Produces: measured results for the pull request. No app code.

No new dependency is added. Chrome is driven by the browser tooling in this environment, or, if that is unavailable, by `Google Chrome --headless` for screenshots and a manual run of the snippet.

- [ ] Start the app: `bin/rails server -p 3020` from `web/`, in the background. Wait until `curl -s -o /dev/null -w '%{http_code}' http://localhost:3020/styleguide` prints `200`.
- [ ] Write `docs/specs/020-base-stylesheet/measure.md` with this procedure and this console snippet (it is documentation, not app JavaScript):

```js
// Run on http://localhost:3020/styleguide at each width: 320, 360, 390, 768, 1024.
(() => {
  const out = { width: innerWidth, problems: [] };
  const doc = document.documentElement;
  if (doc.scrollWidth > innerWidth) out.problems.push(`sideways scroll: ${doc.scrollWidth} > ${innerWidth}`);

  // AC-1.2: tap targets (running-text links are exempt)
  const targets = [...document.querySelectorAll(
    '.button, .app-header__name, .list__row, .control, .choice')]
    .filter((el) => !el.matches('[disabled]') || true);
  for (const el of targets) {
    const r = el.getBoundingClientRect();
    if (r.width < 43.5 || r.height < 43.5) out.problems.push(`small target ${el.className}: ${r.width.toFixed(1)}x${r.height.toFixed(1)}`);
  }

  // AC-1.3: gap of at least 8px between separate controls in a row or column
  const rows = document.querySelectorAll('.sg-row, .app-actions__inner');
  for (const row of rows) {
    const kids = [...row.children].map((el) => el.getBoundingClientRect());
    for (let i = 0; i < kids.length; i++) for (let j = i + 1; j < kids.length; j++) {
      const a = kids[i], b = kids[j];
      const dx = Math.max(b.left - a.right, a.left - b.right), dy = Math.max(b.top - a.bottom, a.top - b.bottom);
      if (Math.max(dx, dy) < 7.5) out.problems.push(`gap < 8px in ${row.className}`);
    }
  }

  // AC-1.1: text sizes
  const bodySize = parseFloat(getComputedStyle(document.body).fontSize);
  if (bodySize < 16) out.problems.push(`body text ${bodySize}px`);
  for (const el of document.querySelectorAll('main *, header *, .app-actions *')) {
    if (!el.childNodes.length || ![...el.childNodes].some((n) => n.nodeType === 3 && n.textContent.trim())) continue;
    const s = parseFloat(getComputedStyle(el).fontSize);
    if (s < 14) out.problems.push(`text under 14px: ${el.tagName}.${el.className} ${s}px`);
  }
  // AC-1.4: control text at least 16px
  for (const el of document.querySelectorAll('.control')) {
    if (parseFloat(getComputedStyle(el).fontSize) < 16) out.problems.push('control text under 16px');
  }

  // AC-3.2 to 3.4, 3.10: the action area
  const bar = document.querySelector('.app-actions');
  const header = document.querySelector('.app-header');
  const tall = doc.scrollHeight > innerHeight * 1.2;
  out.actionPosition = getComputedStyle(bar).position;
  out.pageIsTall = tall;
  out.barBottomGap = +(innerHeight - bar.getBoundingClientRect().bottom).toFixed(1); // expect 0 at every scroll position
  out.headerTop = +header.getBoundingClientRect().top.toFixed(1); // expect < 0 once scrolled (AC-3.10)
  out.mainWidth = document.querySelector('.app-main').getBoundingClientRect().width; // expect <= 640 (AC-3.8)
  out.problems_ok = out.problems.length === 0;
  return out;
})();
```

  with the manual steps beside it: for each width, run the snippet at scroll top, scroll to the middle, scroll to the end (the bar's `barBottomGap` stays 0 and the last `main` line ends above `bar.getBoundingClientRect().top`, AC-3.3); press Tab through the page and confirm each focused control keeps its top above the bar's top (AC-3.6); check one short viewport (height 400, width 800) that `actionPosition` is `static` (AC-3.9); open the network panel and confirm no font request and only same-origin stylesheets (AC-6.3); emulate reduced motion, forced colors and hover/active/focus states (DevTools Rendering and Styles panes) and record what was seen; edit the page to show one button, two buttons, and three stacked buttons in the action area and record each.

- [ ] Run the snippet at 320, 360, 390, 768 and 1024 wide, plus the short viewport. Fix any real problem it reports in the stylesheet, add a spec if the problem can be caught in text, rerun `bundle exec rspec`, and commit each fix on its own: `Fix <what>`.
- [ ] Take screenshots at 360 and 768 pixels wide, full page, and save them as `docs/specs/020-base-stylesheet/screenshots/styleguide-360.png` and `styleguide-768.png`.
- [ ] Record the measured results (a short table: width, problems found, action-area position, header scrolled away) at the end of `measure.md`, and the states that could not be checked, with the reason.
- [ ] Stop the server.
- [ ] Commit: `Record the browser measurements and screenshots for the base stylesheet`

---

## Phase 6: Integration Verification

**Implements:** All FRs | **Satisfies:** All ACs

- [ ] `bundle exec rspec` from `web/` — expect 0 failures. Record the counts.
- [ ] `git diff --name-only main...HEAD` — expect every path under `web/`.
- [ ] `git diff main...HEAD -- web/Gemfile web/Gemfile.lock web/config/importmap.rb` — expect empty (AC-6.4).
- [ ] `bin/rubocop` from `web/` — expect no offenses in the files this branch touches.
- [ ] `bin/brakeman -q` from `web/` — expect no new warning.
- [ ] Walk the acceptance criteria of the spec once against `measure.md`, the specs and the PR. Anything unmet gets a fix or an honest entry in the pull request, with AC-1.4, 1.6, 3.2 and 3.5 named as owed to the maintainer in Issue #71.
- [ ] Dispatch the implementation review (read-only, Opus), record its findings and how each was handled in the pull request description.

---

## Quickstart Validation

From `web/`: `bin/rails server`, then open `http://localhost:3000/styleguide` on a phone-sized window. Expect a header with the app name, sections for every component, seven power badges with names, and a two-button action area that stays at the bottom as the page scrolls. Open `http://localhost:3000/` and expect the placeholder page in the same frame, with no action area. Run `bundle exec rspec spec/styles` and expect all contrast examples to pass.

## Spec coverage (self-review)

| FR | Phase |
|---|---|
| FR-1 Delivery | 0 (rules spec), 1, 2 |
| FR-2 Tokens | 0, 1 |
| FR-3 Palette and contrast | 0, 1 |
| FR-4 Power colors | 0, 1, 3 |
| FR-5 Layout | 2, 5 |
| FR-6 Components | 3, 4, 5 |
| FR-7 Style guide | 4 |
| FR-8 Accessibility behavior | 2, 3, 5 |
| FR-9 Originality | Plan (palette section), 1 |

| AC group | Where it is proven |
|---|---|
| 2.1 to 2.6, 2.8 | `spec/styles/contrast_spec.rb`, `stylesheet_rules_spec.rb` |
| 1.4, 1.5, 1.6, 3.5 (static parts), 4.1, 4.2, 4.4, 6.2 | `stylesheet_rules_spec.rb` |
| 4.3 | `spec/helpers/power_badge_helper_spec.rb` |
| 3.7, 5.3, 6.6 | `spec/requests/layout_spec.rb`, `root_spec.rb` |
| 4.5, 5.1, 5.2, 5.4 | `spec/requests/styleguide_spec.rb` |
| 6.5 | `spec/styles/words_spec.rb` |
| 6.4 | Phase 6 diff check |
| 2.7, 4.6, 5.5, 6.1 | Review: the markup, this plan, the page copy, the file list |
| 1.1 to 1.3, 3.1 to 3.4, 3.6, 3.8 to 3.10, 6.3 | Phase 5 measurement |
| 1.4 (zoom), 1.6 (touch), 3.2 (toolbar), 3.5 (insets) on a real phone | Owed to the maintainer, Issue #71 |

Placeholder scan: none. Names used across phases agree: `Stylesheets`, `Contrast`, `power_badge`, `PowerBadgeHelper::POWER_NAMES`, `StyleguideHelper::{COLOR_TOKENS, PAIRS, TYPE_STEPS, SPACE_STEPS, POWER_IDS}`, `.app-header`, `.app-main`, `.app-actions`, `.app-column`, `Rails.configuration.x.styleguide`.

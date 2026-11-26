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
- Commit messages: a plain imperative sentence, ending with the `Co-Authored-By` trailer the session gives for commits.

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
| Power colors (FR-9) | Seven hues from an even HSL spread, start 17 degrees, step 360/7 = 51.43 degrees, saturation 60 percent, assigned alphabetically. Lightness per color is the highest whole percent, at most 50, at which white reaches at least 4.7 | Reproducible, arbitrary on purpose. The cap of 50 keeps every fill from turning pastel. No hand tuning was needed (see table) |
| Neutral and accent palette | Warm paper page, cool ink text, one deep blue accent, brick red danger, burnt orange focus ring | The app's own aim; chosen without consulting any edition of the game |
| Visual check (FR-7) | `/styleguide` | Outlives the root page, which #21 replaces |
| Geometry proof | Real Chrome through the browser tooling: a console snippet kept in `measure.md`, run at 320, 360, 390, 768 and 1024 pixels, plus screenshots at 360 and 768 | No new dependency (Gate A, decision 5) |

### CSS features used (FR-1: each must be Baseline "widely available")

`@layer`; custom properties and `var()`; `calc()`, `max()`; `env()` and `viewport-fit=cover`; `dvh` with a `vh` fallback line; `position: sticky`; flexbox with `gap`; `display: contents` (used only on an unnamed form wrapper, which has no role to lose); `:focus-visible`; `:not()`; `::placeholder`; `accent-color`; `color-scheme`; `scroll-padding`; `touch-action`; `text-decoration-thickness` and `text-underline-offset`; logical properties (`margin-inline`, `margin-block-start`, `text-align: start`); the media features `hover` and `prefers-reduced-motion`, and the range form `(height < 30rem)`. A reviewer checks the list against MDN's Baseline data. Two declarations that are not Baseline were dropped on review: `text-size-adjust` and `-webkit-tap-highlight-color`.

### The palette (derived once, recorded here)

> **Superseded by spec 2.0.0.** These colors were derived by a method in version 1.2.1. They are replaced by fixed values; see "The palette, final" in the version 2.0 phases below.

No edition of the game was consulted. Hue start 17 degrees, step 51.43 degrees, saturation 60 percent. Lightness is the highest whole percent, at most 50, at which white text reaches at least 4.7 on the fill. Contrast is computed with the WCAG 2.2 formula and shown rounded down.

| Power | Nominal hue | Lightness | Hex | Hue of the hex | White on it | On `page` | On `surface` |
|---|---|---|---|---|---|---|---|
| austria | 17.0 | 45% | `#b8552e` | 17.0 | 4.80 | 4.33 | 4.80 |
| england | 68.4 | 30% | `#6e7a1f` | 67.9 | 4.70 | 4.24 | 4.70 |
| france | 119.9 | 32% | `#218321` | 120.0 | 4.85 | 4.37 | 4.85 |
| germany | 171.3 | 31% | `#207e71` | 171.7 | 4.90 | 4.42 | 4.90 |
| italy | 222.7 | 50% (cap) | `#335fcc` | 222.7 | 5.75 | 5.19 | 5.75 |
| russia | 274.1 | 50% (cap) | `#8a33cc` | 274.1 | 6.13 | 5.53 | 6.13 |
| turkey | 325.6 | 50% | `#cc338b` | 325.5 | 4.76 | 4.29 | 4.76 |

Italy and russia reach the cap of 50 percent; their white contrast is already well above 4.7 there. The least circular distance between two of these hues is 50.96 degrees, so the 25-degree rule holds with room. Rounding to hex moved england's hue by 0.52 degrees and no other by more than 0.4; nothing was tuned by hand, so the 5-degree allowance in FR-9 is unused. All seven fills sit in a narrow band of darkness and differ chiefly by hue (spec FR-4); the name is always printed on the badge.

| Token | Hex | Contrast it must hold (see FR-3) |
|---|---|---|
| `--color-page` | `#f6f3ec` | Background |
| `--color-surface` | `#ffffff` | Background |
| `--color-text` | `#1b2230` | 14.38 on page, 15.93 on surface |
| `--color-text-muted` | `#4b5567` | 6.78 on page, 7.51 on surface |
| `--color-border` | `#6a7385` | 4.30 against page, 4.77 against surface |
| `--color-link` | `#1d4f9c` | 7.15 on page, 7.92 on surface |
| `--color-link-visited` | `#5b3a8c` | 7.80 on page, 8.65 on surface |
| `--color-primary` | `#1f4e8c` | 7.49 against page, 8.31 against surface |
| `--color-primary-pressed` | `#163a69` | 10.28 against page, 11.39 against surface |
| `--color-on-primary` | `#ffffff` | 8.31 on primary, 11.39 on pressed |
| `--color-danger` | `#a3262a` | 6.61 on page, 7.32 on surface |
| `--color-danger-pressed` | `#7e1b1e` | 9.19 against page, 10.18 against surface |
| `--color-on-danger` | `#ffffff` | 7.32 on danger, 10.18 on pressed |
| `--color-focus` | `#b3470a` | 4.96 against page, 5.49 against surface |
| `--color-disabled-text` | `#5c6270` | 4.29 on disabled fill |
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

  # Problems with a stylesheet. Each is "file:line: what". In the token file, a
  # --color-* token may hold a six-digit hex value (and nothing else may hold a color).
  def violations(css, label, token_file: false)
    out = []
    declarations(css).each do |prop, value, line|
      at = "#{label}:#{line}"
      color_token = token_file && prop.start_with?("--color-") && value.match?(/\A#[0-9a-f]{6}\z/i)
      plain = value.gsub(/var\([^)]*\)/, "")
      words = plain.downcase.scan(/[a-z]+/)
      unless color_token
        out << "#{at}: hex color in #{prop}" if value.match?(HEX_COLOR)
        out << "#{at}: color function in #{prop}" if value.match?(COLOR_FUNCTION)
        out << "#{at}: named or system color in #{prop}" if (words & (NAMED_COLORS + SYSTEM_COLORS)).any?
      end
      out << "#{at}: banned #{prop}" if prop.match?(/\A(?:-\w+-)?(?:(?:backdrop-)?filter|mix-blend-mode)\z/)
      out << "#{at}: banned opacity" if prop == "opacity" && value != "1"
      out << "#{at}: px font size in #{prop}" if %w[font font-size].include?(prop) && value.match?(/\d\s*px/i)
      out << "#{at}: !important" if value.include?("!important")
    end
    out << "#{label}: @import" if css.include?("@import")
    out << "#{label}: @font-face" if css.include?("@font-face")
    out << "#{label}: url(" if css.match?(/url\(/i)
    out << "#{label}: color-mix" if css.include?("color-mix(")
    rules(css).each do |selector, body|
      next unless body.include?("var(--color-power-")
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
      "#{fg} / #{bg}: ratio #{r.floor(2)} is below #{min}" if r < min
    end
  end
end
```

- [ ] Write `spec/styles/contrast_spec.rb`:

```ruby
require "spec_helper"
require_relative "../support/stylesheets"

RSpec.describe "Palette contrast (WCAG 2.2)" do
  powers = %w[austria england france germany italy russia turkey]

  # The documented pairs (spec FR-3). [foreground, background, minimum ratio].
  # Each pair appears once, with its higher minimum where the spec lists two uses.
  documented_pairs = [
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
  ].map { |fg, bg, min| [fg, bg, min.to_f] }

  power_pairs = powers.flat_map do |id|
    [["on-power", "power-#{id}", 4.5], ["power-#{id}", "page", 3.0], ["power-#{id}", "surface", 3.0]]
  end

  pairs = documented_pairs + power_pairs

  let(:colors) { Stylesheets.color_tokens }

  it "has the token file" do
    expect(File).to exist(Stylesheets::TOKENS)
  end

  it "writes every color token as a six-digit hex value" do
    bad = colors.reject { |_, value| value.match?(/\A#[0-9a-f]{6}\z/i) }
    expect(bad).to be_empty, "not six-digit hex: #{bad.keys.join(', ')}"
  end

  it "documents a pair for every color token, and every pair names real tokens (AC-2.3)" do
    used = pairs.flat_map { |fg, bg, _| ["--color-#{fg}", "--color-#{bg}"] }.uniq
    expect(colors.keys - used).to be_empty, "no documented pair uses: #{(colors.keys - used).join(', ')}"
    expect(used - colors.keys).to be_empty, "pair names a missing token: #{(used - colors.keys).join(', ')}"
  end

  it "meets the minimum ratio for every documented pair (AC-2.1, AC-2.2)" do
    expect(Contrast.failures(colors, pairs)).to be_empty
  end

  it "has exactly one power color for each power (AC-4.1)" do
    names = colors.keys.grep(/\A--color-power-/)
    expect(names).to match_array(powers.map { |id| "--color-power-#{id}" })
  end

  it "keeps the power hues at least 25 degrees apart (AC-4.2)" do
    hexes = powers.to_h { |id| [id, colors.fetch("--color-power-#{id}")] }
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
      expect(messages).to eq(["text / page: ratio 4.47 is below 4.5"])
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

The `#777777` on white ratio is 4.4781 under the WCAG 2.2 formula, and the message rounds down (spec FR-3), so it prints 4.47. If the first run prints another value, correct the expected string to what the formula gives, since that example tests the message format and not the number.

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

  it "has no stray colors, banned properties, px font sizes, imports, fonts or url( in any file (AC-2.4, 2.5, 2.8, 1.5, 6.2, 4.4)" do
    problems = files.flat_map do |f|
      Stylesheets.violations(Stylesheets.read(f), File.basename(f), token_file: f == Stylesheets::TOKENS)
    end
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
    expect(File.size?(File.join(Stylesheets::DIR, "styleguide.css")).to_i).to be <= 4 * 1024
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

    it "lets the token file hold hex only in --color-* tokens (AC-2.5)" do
      expect(Stylesheets.violations(":root { --color-page: #f6f3ec; }", "t.css", token_file: true)).to be_empty
      expect(Stylesheets.violations(":root { --brand: #123456; }", "t.css", token_file: true)).not_to be_empty
      expect(Stylesheets.violations(":root { --color-page: red; }", "t.css", token_file: true)).not_to be_empty
      expect(Stylesheets.violations(":root { --bg: url(a.png); }", "t.css", token_file: true)).not_to be_empty
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
  root = File.expand_path("../..", __dir__)
  # Built from pieces so this file does not contain the words it forbids.
  forbidden = Regexp.new("diplo" + "macy|\\bd" + "ip[a-z]*", Regexp::IGNORECASE)

  paths = (Dir[File.join(root, "{app,lib,spec}/**/*")] + [File.join(root, "config/routes.rb")])
          .select { |p| File.file?(p) }
          .reject { |p| p == __FILE__ }

  it "finds files to scan" do
    expect(paths.size).to be > 10
  end

  it "has no forbidden word in any file name or content" do
    hits = paths.filter_map do |path|
      relative = path.delete_prefix("#{root}/")
      next "#{relative}: file name" if relative.match?(forbidden)
      next if File.extname(path).match?(/\.(png|jpe?g|gif|ico|webp|woff2?)\z/i)
      "#{relative}: content" if File.binread(path).force_encoding("UTF-8").scrub.match?(forbidden)
    end
    expect(hits).to be_empty, hits.join("\n")
  end
end
```

- [ ] Run: `bundle exec rspec spec/styles` — expect FAIL: the contrast examples, the token examples, the file-list, layer-line and `.control` examples fail because `tokens.css` and the other files do not exist (the layer-line example fails on `application.css`, which holds only a comment today); the scanner and maths examples and the words spec pass.
- [ ] Run: `bin/rubocop -A spec/support spec/styles`, then rerun the line above to confirm nothing changed in meaning.
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
- [ ] Run: `bundle exec rspec spec/styles` — expect the file-list example (four files missing) and the `.control` example (`components.css` missing) still FAIL; the rest PASS, including the layer-line example, the no-violations example over `tokens.css` and `application.css`, and the size examples.
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
  .text-small,
  code {
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
    text-underline-offset: var(--space-1);
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

  .app-header__name:focus-visible {
    text-decoration: underline;
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

  /* Up to two share a row (two at 34 percent fit, three do not). One alone,
     or one that no longer fits, is full width. A button_to form wrapper is
     flattened so its button is the flex item. */
  .app-actions__inner > *,
  .app-actions__inner > form > .button {
    flex: 1 1 34%;
  }

  .app-actions__inner > form {
    display: contents;
  }

  /* A short screen (a phone on its side) gives the area no room to stick */
  @media (height < 30rem) {
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

- [ ] Run: `bundle exec rspec spec/requests spec/styles/stylesheet_rules_spec.rb` — expect request specs PASS; the rules spec still FAILS on the file-list example (`components.css` and `styleguide.css` missing) and the `.control` example.
- [ ] Run: `bin/rubocop -A spec/requests`.
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
  names = {
    "austria" => "Austria", "england" => "England", "france" => "France", "germany" => "Germany",
    "italy" => "Italy", "russia" => "Russia", "turkey" => "Turkey"
  }

  names.each do |id, name|
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
    pointer-events: none;
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
  }

  /* Rows touch and share one edge, so each keeps its full 44 pixels */
  .choice + .choice {
    border-top-width: 0;
  }

  .choice:first-of-type {
    border-top-left-radius: var(--radius);
    border-top-right-radius: var(--radius);
  }

  .choice:last-of-type {
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
- [ ] Run: `bundle exec rspec spec/styles/stylesheet_rules_spec.rb` — expect the one remaining failure: the file-list example, because `styleguide.css` is missing.
- [ ] Run: `bin/rubocop -A app/helpers spec/helpers`.
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
  components = %w[button link list field choice power-badge heading-text]
  # The documented pairs other than the power pairs (spec FR-3): 25 of them.
  non_power_pair_count = 25

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
      expect(samples.size).to eq(non_power_pair_count)
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
      <label class="field__label" for="sg-email">Email</label>
      <input class="control" id="sg-email" type="email" autocomplete="off">
    </div>
    <div class="field">
      <label class="field__label" for="sg-number">Number</label>
      <input class="control" id="sg-number" type="number" inputmode="numeric">
    </div>
    <div class="field">
      <label class="field__label" for="sg-search">Search</label>
      <input class="control" id="sg-search" type="search">
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
        <% text_pair = min.to_f >= 4.5 %>
        <li class="sg-sample sg-bg-<%= bg %><%= " sg-fg-#{fg}" if text_pair %>">
          <% if text_pair %>
            <span>Sample text</span>
          <% else %>
            <span class="sg-bar sg-bg-<%= fg %>"></span>
          <% end %>
          <span class="sg-sample__meta"><%= fg %> on <%= bg %> (min <%= min %>)</span>
        </li>
      <% end %>
    </ul>
  </section>
</div>
```

Pairs with a minimum of 4.5 are text pairs: the sample text and its caption are drawn in the pair's foreground on its background. Pairs with a minimum of 3 are not text (edges, rings, a disabled label): the sample draws the foreground as a bar, and the caption stays in `--color-text`, which reads on `page`, `surface` and `disabled-fill`. So no text on this page is set below 4.5. The `<code>` token names sit on `page` in `--color-text`.

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
  .sg-bar { display: block; height: var(--space-3); border-radius: var(--radius); }

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

  .sg-fg-text { color: var(--color-text); }
  .sg-fg-text-muted { color: var(--color-text-muted); }
  .sg-fg-link { color: var(--color-link); }
  .sg-fg-link-visited { color: var(--color-link-visited); }
  .sg-fg-on-primary { color: var(--color-on-primary); }
  .sg-fg-danger { color: var(--color-danger); }
  .sg-fg-on-danger { color: var(--color-on-danger); }
}
```

- [ ] Run: `bundle exec rspec` — expect everything PASS: the contrast spec, the rules spec (all five files present, total under 24 KB, `styleguide.css` under 4 KB), helper, layout, root, style guide, words. If `styleguide.css` is over 4 KB, trim the `sg-bg-*` and `sg-fg-*` lines that no pair uses. If the words spec finds a match, rename it (do not widen the exemption).
- [ ] Run: `bin/rubocop -A app/controllers app/helpers config/application.rb config/environments/development.rb config/environments/test.rb config/routes.rb spec/requests`, then `bundle exec rspec` again.
- [ ] Commit: `Add the development-only style guide page`

---

## Phase 5: Measure in a real browser, then document

**Implements:** FR-5, FR-6, FR-8 (geometry) | **Satisfies:** AC-1.1 to 1.3, 3.1 to 3.4, 3.6, 3.8 to 3.10, 6.3, and the pressed, hover, focus ring, forced colors and reduced motion checks
**Files:** `docs/specs/020-base-stylesheet/measure.md`, `docs/specs/020-base-stylesheet/screenshots/styleguide-360.png`, `docs/specs/020-base-stylesheet/screenshots/styleguide-768.png`
**Interfaces:** Consumes: the running `/styleguide` and `/` pages. Produces: measured results for the pull request. No app code.

No new dependency is added. Two ways of using Chrome, because a desktop window cannot be made 320 to 390 pixels wide (its floor is about 500):

- **Measuring:** a scratch page `public/frame.html`, never committed (it is deleted at the end of this phase and listed in `.git/info/exclude` while it exists), holds `<iframe id="f" src="/styleguide" style="width:360px;height:800px;border:0">`. It is served by the same Rails server, so it is same-origin and the snippet can reach into the frame. The frame's width and height are the viewport the page sees, so media queries, `dvh` and `sticky` behave as on a phone of that size. The snippet runs in the parent page through the browser tooling's JavaScript tool, or in DevTools.
- **Screenshots:** headless Chrome, which can be given any window size: `"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless=new --hide-scrollbars --window-size=360,800 --screenshot=<path> http://localhost:3020/styleguide`. That captures the top of the page at the viewport size. A taller `--window-size` (for example `360,2600`) captures the whole page. Check each capture with `sips -g pixelWidth <png>`: if Chrome enforced a minimum window width and the PNG is wider than asked, screenshot `frame.html` with the frame set to that width instead.

- [ ] Start the app in the background: `bin/rails server -p 3020` from `web/`. Wait until `curl -s -o /dev/null -w '%{http_code}' http://localhost:3020/styleguide` prints `200`. Add the scratch file to the exclude list with `echo web/public/frame.html >> "$(git rev-parse --git-path info/exclude)"` (this checkout is a git worktree, so `.git` is a file, and the list is shared with the other worktrees), then write `public/frame.html` (`<!doctype html><title>frame</title><iframe id="f" src="/styleguide" style="width:360px;height:800px;border:0"></iframe>`).
- [ ] Write `docs/specs/020-base-stylesheet/measure.md` with the procedure above and this snippet (documentation, not app JavaScript). It takes the frame's window, so the same code runs at each size:

```js
// Parent page: http://localhost:3020/frame.html. Set the frame size, load the page, then:
//   const f = document.getElementById('f'); f.style.width = '360px'; f.style.height = '800px';
//   measure(f.contentWindow)
function measure(win) {
  const d = win.document, doc = d.documentElement;
  const out = { width: win.innerWidth, height: win.innerHeight, problems: [] };
  if (doc.scrollWidth > doc.clientWidth) out.problems.push(`sideways scroll: ${doc.scrollWidth} > ${doc.clientWidth}`);

  // AC-1.2: tap targets (links in running text are exempt)
  for (const el of d.querySelectorAll('.button, .app-header__name, .list__row, .control, .choice')) {
    const r = el.getBoundingClientRect();
    if (r.width < 43.5 || r.height < 43.5) out.problems.push(`small target ${el.className}: ${r.width.toFixed(1)}x${r.height.toFixed(1)}`);
  }
  // A choice row overlaps nothing: its next sibling starts at or below its bottom edge
  for (const el of d.querySelectorAll('.choice + .choice')) {
    const a = el.previousElementSibling.getBoundingClientRect(), b = el.getBoundingClientRect();
    if (b.top < a.bottom - 0.5) out.problems.push('choice rows overlap');
  }

  // AC-1.3: at least 8px between separate controls
  for (const row of d.querySelectorAll('.sg-row, .app-actions__inner')) {
    const k = [...row.children].map((el) => el.getBoundingClientRect());
    for (let i = 0; i < k.length; i++) for (let j = i + 1; j < k.length; j++) {
      const dx = Math.max(k[j].left - k[i].right, k[i].left - k[j].right);
      const dy = Math.max(k[j].top - k[i].bottom, k[i].top - k[j].bottom);
      if (Math.max(dx, dy) < 7.5) out.problems.push(`gap under 8px in ${row.className}`);
    }
  }

  // AC-1.1 and AC-1.4: text sizes
  if (parseFloat(win.getComputedStyle(d.body).fontSize) < 16) out.problems.push('body text under 16px');
  for (const el of d.querySelectorAll('body *')) {
    if (![...el.childNodes].some((n) => n.nodeType === 3 && n.textContent.trim())) continue;
    const s = parseFloat(win.getComputedStyle(el).fontSize);
    if (s < 14) out.problems.push(`text under 14px: ${el.tagName}.${el.className} ${s}px`);
  }
  for (const el of d.querySelectorAll('.control')) {
    if (parseFloat(win.getComputedStyle(el).fontSize) < 16) out.problems.push('control text under 16px');
  }

  // AC-3.2 to 3.4, 3.8, 3.10: the action area, when the page has one
  const bar = d.querySelector('.app-actions');
  out.actionArea = !!bar;
  if (bar) {
    out.position = win.getComputedStyle(bar).position;
    out.barBottomGap = +(win.innerHeight - bar.getBoundingClientRect().bottom).toFixed(1);   // 0 when stuck or at the page bottom
    const last = d.querySelector('.app-main').lastElementChild.getBoundingClientRect();
    out.clearOfBar = last.bottom <= bar.getBoundingClientRect().top + 0.5;                  // check at the end of the scroll
  }
  out.headerTop = +d.querySelector('.app-header').getBoundingClientRect().top.toFixed(1);   // below 0 once scrolled
  out.mainWidth = +d.querySelector('.app-main').getBoundingClientRect().width.toFixed(1);   // at most 640
  out.pageHeight = doc.scrollHeight;
  out.ok = out.problems.length === 0;
  return out;
}
```

  Procedure beside it, for each width 320, 360, 390, 768 and 1024 (frame height 800):
  1. Run `measure` at scroll top, at the middle (`win.scrollTo(0, doc.scrollHeight / 2)`) and at the end (`win.scrollTo(0, doc.scrollHeight)`). `barBottomGap` stays 0 at all three, `clearOfBar` is true at the end, and `headerTop` is negative once scrolled (AC-3.2, 3.3, 3.10).
  2. AC-3.4 (short content): in the frame, remove every `section` and the intro (`f.contentDocument.querySelectorAll('.stack > *:not(h1)').forEach(e => e.remove())`) so the content is short, and confirm `barBottomGap` is 0 at scroll top.
  3. AC-3.6: press Tab through the frame's page (focus the first control with `f.contentWindow.focus()`, then Tab with the browser tooling's key action), and after each press confirm the focused element's top is above the bar's top.
  4. AC-3.9: set the frame to 800 wide by 400 high; `position` is `static`. At 800 by 480 (above 30rem) it is `sticky`.
  5. AC-3.8: at 768 and 1024, `mainWidth` is at most 640, and the header text, content and buttons share one left edge.
  6. Action area shapes: in the frame, replace the two buttons with one, then with three (`.app-actions__inner` innerHTML), and check one is full width, and three show two on a row and one below, each at least 44 high.
  7. `/` at 360: `actionArea` is false, no empty bar (AC-3.7).
  8. AC-6.3: with the page loaded in the tab itself (not the frame), read the network log: no font request, every stylesheet request to `localhost:3020`.
  9. Emulation (DevTools Rendering and Styles panes, if the tooling can reach them): hover, active and focus-visible on a primary button, a secondary button and a list row; `prefers-reduced-motion: reduce`; forced colors. Record what was seen. Anything the tooling cannot reach is listed as "not checked, reason" in the results.

- [ ] Run the procedure at the five widths and the short viewport. Fix any real problem in the stylesheet, add a text spec if the problem can be caught in text, rerun `bundle exec rspec`, and commit each fix on its own: `Fix <what>`.
- [ ] Take the screenshots with headless Chrome at `--window-size=360,800` and `768,1024` (viewport at the top), and a tall `360,2600` and `768,2600` for the whole page. Save the 360 and 768 ones as `docs/specs/020-base-stylesheet/screenshots/styleguide-360.png` and `styleguide-768.png` (tall versions) and keep each under about 400 KB.
- [ ] Record the measured results at the end of `measure.md`: a table with width, `problems`, position, `barBottomGap`, `clearOfBar` and `headerTop` for each run, and the states that could not be checked with the reason. Delete `public/frame.html` and remove exactly that one line from the exclude list (it is shared with other worktrees). Confirm `git status --porcelain | grep frame.html` prints nothing. Stop the server.
- [ ] Commit: `Record the browser measurements and screenshots for the base stylesheet`

---

## Phase 6: Integration Verification

**Implements:** All FRs | **Satisfies:** All ACs

- [ ] `bundle exec rspec` from `web/` — expect 0 failures. Record the counts.
- [ ] `git diff --name-only main...HEAD` — expect every path under `web/`.
- [ ] `git diff main...HEAD -- web/Gemfile web/Gemfile.lock web/config/importmap.rb` — expect empty (AC-6.4).
- [ ] `git diff --name-only main...HEAD | grep -E 'package(-lock)?\.json|yarn\.lock|node_modules'` — expect no output (AC-6.4).
- [ ] `bin/rubocop` from `web/` (the CI script runs it over `spec/` too) — expect no offenses.
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

---

## Changes made during implementation review

The code in the phases above is what was first written. The independent implementation review (see the pull request) led to these differences in the final code. The spec did not change.

| Change | Why |
|---|---|
| `.button` pressed ring is `on-primary` / `on-danger`, not the pressed fill | The ring was the same color as the pressed fill, so the thicker edge could not be seen (AC-1.6) |
| Disabled buttons, fields and choice rows have a `dashed` border; the disabled choice row is `.choice--disabled`, not `aria-disabled` on a `label` | A disabled state must differ by shape as well as color (AC-2.7). A label has no role for `aria-disabled` |
| The style guide's disabled link is `<a role="link" aria-disabled="true">`, with no `tabindex` | An `a` with no `href` has no role |
| Action area items get `min-width: min-content`, through `--_min-width`, which `.button` reads | `.button`'s own `min-width` sits in a later layer and would have won. Without this, two buttons shared a row whatever their labels' width |
| `body { overflow-wrap: break-word }`, and the style guide's token names break anywhere | At 200 percent text, the root page's heading and a monospace name overflowed the column |
| `.app-actions { z-index: 1 }` | Later positioned content in `main` must not paint over the bar |
| The style guide's sample headings have `role="none"` | The page keeps one real heading order |
| `Contrast::DOCUMENTED_PAIRS` lives in `spec/support/stylesheets.rb`, shared by the contrast spec and the style guide spec, which now compares `StyleguideHelper::PAIRS` to it and checks that every `sg-bg-*` and `sg-fg-*` class used exists | Replaces a count of 25 that could not catch a wrong pair |
| The scanner reads `var()` fallbacks, old and vendor system colors, ignores quoted text, flags `px` in `--text-*` and `--font-*` tokens, checks root font size through selector lists, requires every selector in a `--color-power-` rule to be a badge variant, and requires `touch-action` on `.button`, `a.list__row` and `.choice` | Gaps the review found by probing |
| The words check also catches CamelCase and underscore forms, and scans dotfiles | The root rule forbids names that contain or echo the word, in any form |
| `--_min-width` is set only on a button that is a direct item of the action area (or of a `button_to` form there), not on every item | A custom property is inherited, so a button nested deeper in an item would have taken `min-content` instead of `--tap-min` |
| `Stylesheets.rules` reads a selector as the text after the last `;`; the scanner drops every `--name` before looking for color words, reads `px` through a custom property that a font size uses, and knows the `-moz-` link colors | Round 2 of the review found the `@layer` line before `tokens.css` hid its `:root` from the root font-size check, and some false positives on custom names |
| The rules spec uses `!sel.include?(":")` instead of ActiveSupport's `exclude?` | `spec/styles` must pass when run on its own, without Rails loaded |
---

# Version 2.0 phases (added for Issue #81, spec 020 v2.0.2)

> **Execution order: 7, 10, 8, 9, 11, 12, 13.** Phase 7's helper spec stays red until Phase 10 writes the helper, and a red spec file stops a whole `bundle exec rspec` run. Phase 10 needs nothing from Phases 8 and 9, so it runs straight after Phase 7, and nothing is pushed while the suite is red. The phases keep their numbers because the spec coverage table refers to them.
>
> Phases 0 to 6 above built version 1.2.1 and stay as the record of that work. Phases 7 to 13 below build version 2.0.x. Where they contradict a phase above, these win. The old derivation under "The palette" is superseded (see Phase 8).

## Global Constraints (2.0)

- Work only in `web/`. The pull request touches nothing else (`git diff --name-only main...HEAD` lists only `web/` paths).
- Test first: every phase starts with a failing spec that is run and seen to fail. The very first test written is the helper spec of Phase 7.
- No new gem, pin or Node file. Nokogiri is already in the bundle through Rails and Capybara, and the helper uses it. The font is an asset, not a dependency.
- Palette and power hexes go in exactly as Issue #81 gives them. If a documented pair fails, stop and ask with the numbers. Never change a value.
- The Capybara layout specs of #73 must pass unchanged. A failure is a defect to fix in the stylesheet.
- No request to a third party at runtime. Every file the page uses is served by this app.
- No text from the game's rulebook or the DATC; nothing named after the game's trademark or its three-letter prefix.
- Every commit message is a plain imperative sentence and ends with the `Co-Authored-By:` trailer naming the model the session runs on (Claude Sonnet 5.5). One git operation per shell call.

## Goal (2.0)

Replace the #20 palette with the fixed Cold War palette, add one self-hosted monospace, add `unit_icon`, `supply_center_icon` and `.mono`, restyle what #20 built, extend `/styleguide`, and write `web/docs/design-system.md`.

## Pre-implementation gates (2.0)

- **Simplicity:** three parts only: the stylesheets and tokens, one icon helper module, and the documents. No new dependency. The font file is not a dependency: it is one static asset, added because no system monospace looks the same on every phone and a six-character join code is read aloud.
- **Anti-abstraction:** the helper reads the master drawings and sets attributes on them. It does not wrap them in a component class, a builder or a template engine.
- **Integration-first:** the contract is the helper's markup (AC-7.1, 7.6), written as a helper spec before the helper.

## Decisions the spec left to the plan

| Decision | Choice | Why |
|---|---|---|
| Where the artwork copies live | `web/app/assets/images/icons/`, five files copied byte for byte from `assets/icons/` with `cp` | The Docker build context is `web/`, so the app can never read the root folder. This is the Rails default place for images, so nothing new is configured. Propshaft will also serve them at a digested URL, which is harmless (they are public CC BY-SA files) |
| How the helper reads them | Read the five files once when the module loads, into a frozen hash. For each icon it parses the stored text with Nokogiri, edits the copy and prints it | No file read per icon, no cache to invalidate, and a missing file stops the app at boot |
| Where `@font-face` lives | `base.css`, after the layer line, outside every layer | `@font-face` is not a layered rule. `base.css` already holds the element-level rules |
| The font's URL | `url("IBMPlexMono-Medium-Latin1.woff2")`, a bare file name | Propshaft resolves it to the digested `/assets/...` path, and a bare name can name no scheme or host (AC-6.2) |
| How the scanner allows exactly one `@font-face` | `Stylesheets.violations(css, label, font_face: true)` removes the first `@font-face { ... }` block before scanning, for `base.css` only. A second block, or a `url(` anywhere else, is still flagged. A separate font spec holds the exact shape of the one block | The scanner stays the one place that bans `url(`; the exception is stated where it is made |
| Faux bold | The `@font-face` declares `font-weight: 400 700` for the one Medium file | The browser then never fakes a bold of it |
| Tag geometry | Tile `rect` at x 20.75, y 20.75, 10.5 by 10.5, `stroke-width="1.5"`, so the stroked outer edge is exactly 20 to 32. Initial: `text` at x 26, y 28.8, `text-anchor="middle"`, `font-size="8"` (all in drawing units) | The initial's cap height is about 5.6 units, so it sits centered in the 9-unit inner tile. All of it is inside the corner the artwork leaves empty |
| Header look | `.app-header` background `ice`, bottom rule `steel` | Spec 2.0.2, FR-2. Maintainer sees it as a design call in the pull request |
| Font source | `@ibm/plex-mono` 2.5.0 from the npm registry, file `package/fonts/split/woff2/IBMPlexMono-Medium-Latin1.woff2`; license `package/fonts/split/woff2/license.txt` copied as `OFL.txt` | The official IBM Plex release publishes this split file. The tarball's sha1 (`152c0b1dda619ef5f032db258bda798cf278125e`) matches the registry's published value |

### The palette, final (replaces the derivation under "The palette" above)

No method, no tuning: the maintainer's fixed values (decision 42 for powers, decision 41 for the rest). No edition's colors, artwork or fonts were sampled, traced or looked up.

| Power | Token | Value |
|---|---|---|
| Austria | `--color-power-austria` | `#586f2a` |
| England | `--color-power-england` | `#822635` |
| France | `--color-power-france` | `#744983` |
| Germany | `--color-power-germany` | `#196666` |
| Italy | `--color-power-italy` | `#866713` |
| Russia | `--color-power-russia` | `#994324` |
| Turkey | `--color-power-turkey` | `#324e8f` |

Checked before any code, with the repo's own `Contrast` module: all 31 non-power pairs and all 28 power pairs pass. Lowest ratios: `steel` on `page` 4.14 (needs 3), `focus` on `ice` 3.19 (needs 3), `power-italy` against `ice-pale` 4.25 (needs 3), `power-austria` against `ice-pale` 4.53 (needs 3), `power-italy` on `surface` 5.30 (needs 4.5). Closest hues: England and Russia 25.68 degrees, Italy and Russia 27.93 (need 25).

---

## Phase 7: The required first test (the helper contract, red)

**Implements:** FR-10 (contract) | **Satisfies:** AC-7.1, AC-7.3 (first two examples) | **Files:** create `spec/helpers/icon_helper_spec.rb` | **Interfaces:** `unit_icon(power, type, size: 32, decorative: false)` in `IconHelper`

- [ ] **Step 1: Write the failing spec.** This is the first test written.

```ruby
require "rails_helper"

RSpec.describe IconHelper, type: :helper do
  it "draws an army as an inline svg labelled with its type and power (AC-7.1)" do
    svg = Nokogiri::HTML5.fragment(helper.unit_icon(:austria, :army)).at_css("svg")
    expect(svg).not_to be_nil
    expect(svg["role"]).to eq("img")
    expect(svg["aria-label"]).to eq("Army, Austria")
  end

  it "raises ArgumentError for a type that is not army or fleet (AC-7.3)" do
    expect { helper.unit_icon(:austria, :submarine) }.to raise_error(ArgumentError)
  end
end
```

- [ ] **Step 2: Run it and see it fail.** From `web/`: `bundle exec rspec spec/helpers/icon_helper_spec.rb`. Expected: FAIL at load with `uninitialized constant IconHelper`.
- [ ] **Step 3: Commit** `Add the failing helper spec for unit_icon`.

---

## Phase 8: The palette, the tokens and the restyled header

**Implements:** FR-2, FR-3, FR-9, FR-5 (header only), Story 2 | **Satisfies:** AC-2.1, 2.2, 2.3, 2.9, 2.10, 4.1, 4.2, 4.6, 5.4 (swatches and samples) | **Files:** modify `spec/support/stylesheets.rb`, `spec/styles/contrast_spec.rb`, `spec/styles/stylesheet_rules_spec.rb`, `spec/requests/styleguide_spec.rb`, `app/assets/stylesheets/tokens.css`, `layout.css`, `styleguide.css`, `app/helpers/styleguide_helper.rb`, `app/views/styleguide/show.html.erb` (swatch list only), `docs/specs/020-base-stylesheet/plan.md` | **Interfaces:** `Contrast::DOCUMENTED_PAIRS` (31 pairs), `Stylesheets.ice_uses(css)`

- [ ] **Step 1: Write the failing specs.**

In `spec/support/stylesheets.rb`, replace `Contrast::DOCUMENTED_PAIRS` with the 31 pairs of spec FR-3 (each once, at its higher minimum), and add the ice scan next to `rules`:

```ruby
  DOCUMENTED_PAIRS = [
    [ "text", "page", 4.5 ], [ "text", "surface", 4.5 ], [ "text", "ice", 4.5 ], [ "text", "ice-pale", 4.5 ],
    [ "text-muted", "page", 4.5 ], [ "text-muted", "surface", 4.5 ], [ "text-muted", "ice-pale", 4.5 ],
    [ "link", "page", 4.5 ], [ "link", "surface", 4.5 ],
    [ "link-visited", "page", 4.5 ], [ "link-visited", "surface", 4.5 ],
    [ "on-primary", "primary", 4.5 ], [ "on-primary", "primary-pressed", 4.5 ],
    [ "primary", "page", 3.0 ], [ "primary", "surface", 3.0 ],
    [ "primary-pressed", "page", 3.0 ], [ "primary-pressed", "surface", 3.0 ],
    [ "border", "page", 3.0 ], [ "border", "surface", 3.0 ],
    [ "danger", "page", 4.5 ], [ "danger", "surface", 4.5 ],
    [ "on-danger", "danger", 4.5 ], [ "on-danger", "danger-pressed", 4.5 ],
    [ "danger-pressed", "page", 3.0 ], [ "danger-pressed", "surface", 3.0 ],
    [ "focus", "page", 3.0 ], [ "focus", "surface", 3.0 ], [ "focus", "ice", 3.0 ],
    [ "steel", "page", 3.0 ], [ "steel", "surface", 3.0 ],
    [ "disabled-text", "disabled-fill", 3.0 ]
  ].freeze
```

```ruby
  # [[property, line], ...] for each declaration that reads --color-ice (not --color-ice-pale).
  def ice_uses(css)
    declarations(css).select { |_, value, _| value.match?(/var\(\s*--color-ice\s*[,)]/) }.map { |prop, _, line| [ prop, line ] }
  end
```

In `spec/styles/contrast_spec.rb` replace `power_pairs`, and add the palette, `on-power` and `ice` examples:

```ruby
  power_pairs = powers.flat_map do |id|
    [ [ "on-power", "power-#{id}", 4.5 ], [ "power-#{id}", "surface", 4.5 ],
      [ "power-#{id}", "page", 3.0 ], [ "power-#{id}", "ice-pale", 3.0 ] ]
  end

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
```

In `spec/styles/stylesheet_rules_spec.rb`, add an example for the header (FR-2), then `--font-mono` to the token-group list:

```ruby
  it "sets the header on ice with a steel rule, and reads steel nowhere else (FR-2)" do
    layout = Stylesheets.rules(Stylesheets.read(File.join(Stylesheets::DIR, "layout.css")))
    header = layout.find { |selector, _| selector == ".app-header" }&.last.to_s
    expect(header).to include("background: var(--color-ice)")
    expect(header).to match(/border-bottom:[^;]*var\(--color-steel\)/)
    steel_readers = Stylesheets.files.flat_map { |f| Stylesheets.rules(Stylesheets.read(f)).select { |_, body| body.include?("var(--color-steel)") }.map(&:first) }
    expect(steel_readers).to eq([ ".app-header" ])
  end
```

and then add `--font-mono` to the token-group list and add `expect(t["--font-mono"]).to eq('"Plex Mono", ui-monospace, "SF Mono", Menlo, Consolas, monospace')` (AC-8.1).

In `spec/requests/styleguide_spec.rb`, the only hand edit is the comment at the top that says "25 of them", which becomes "31 of them". The examples need no change: it reads `Contrast::DOCUMENTED_PAIRS` and the token file, so the new pairs and swatches fail until the view and helper catch up.

- [ ] **Step 2: Run and see them fail.** `bundle exec rspec spec/styles spec/requests/styleguide_spec.rb`. Expected: FAIL: the palette example (old values), the missing `ice`, `ice-pale`, `steel` tokens (AC-2.3), `--font-mono` missing, the swatch and sample counts.
- [ ] **Step 3: Write `tokens.css`.** Replace the comment and the color block; keep the type, spacing and sizing blocks, adding `--font-mono`:

```css
@layer reset, base, layout, components, styleguide;

/*
 * Design tokens. The only place a color, font stack, size or step is defined.
 * Every color has a documented pair in spec/styles/contrast_spec.rb, which
 * computes each ratio from this file on every run.
 *
 * The palette is the Cold War palette of the logo, and the seven power colors
 * are fixed values the maintainer chose (decisions 41 and 42). They are held
 * exactly by the contrast spec; do not adjust one by eye. See
 * web/docs/design-system.md.
 */
:root {
  /* Ground: pale blue paper, white surfaces, the Ice tints and the decorative Steel */
  --color-page: #eef3f6;
  --color-surface: #ffffff;
  --color-ice: #a7c4d4;
  --color-ice-pale: #dde8ee;
  --color-steel: #4f7a93;

  /* Text and edges: cool Iron ink */
  --color-text: #22262b;
  --color-text-muted: #4a5560;
  --color-border: #65727e;

  /* Links */
  --color-link: #2c5873;
  --color-link-visited: #5b3a7a;

  /* Actions */
  --color-primary: #3d6178;
  --color-primary-pressed: #2b4657;
  --color-on-primary: #ffffff;
  --color-danger: #9e2a22;
  --color-danger-pressed: #7a1f19;
  --color-on-danger: #ffffff;

  /* Focus and disabled */
  --color-focus: #a8480a;
  --color-disabled-text: #56606a;
  --color-disabled-fill: #d3dce2;

  /* Powers: shown only with the power's name or initial */
  --color-on-power: #ffffff;
  --color-power-austria: #586f2a;
  --color-power-england: #822635;
  --color-power-france: #744983;
  --color-power-germany: #196666;
  --color-power-italy: #866713;
  --color-power-russia: #994324;
  --color-power-turkey: #324e8f;

  /* Type: system sans for text, one self-hosted monospace for codes and tags */
  --font-sans: system-ui, -apple-system, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
  --font-mono: "Plex Mono", ui-monospace, "SF Mono", Menlo, Consolas, monospace;
  /* ...the remaining type, spacing and sizing tokens are unchanged... */
}
```

(The unchanged tokens stay exactly as they are in the file; only the lines above are edited. The font family name is the only quoted name not read from a token.)

- [ ] **Step 4: Restyle the header.** In `layout.css`, in `.app-header`:

```css
  .app-header {
    padding-top: env(safe-area-inset-top, 0px);
    background: var(--color-ice);
    border-bottom: var(--border-width) solid var(--color-steel);
  }
```

- [ ] **Step 5: Teach the style guide the new tokens.** In `app/helpers/styleguide_helper.rb` replace `COLOR_TOKENS` and `PAIRS` (same order as `Contrast::DOCUMENTED_PAIRS`):

```ruby
  COLOR_TOKENS = %w[
    page surface ice ice-pale steel text text-muted border link link-visited primary primary-pressed on-primary
    danger danger-pressed on-danger focus disabled-text disabled-fill on-power
  ].freeze

  PAIRS = [
    [ "text", "page", "4.5" ], [ "text", "surface", "4.5" ], [ "text", "ice", "4.5" ], [ "text", "ice-pale", "4.5" ],
    [ "text-muted", "page", "4.5" ], [ "text-muted", "surface", "4.5" ], [ "text-muted", "ice-pale", "4.5" ],
    [ "link", "page", "4.5" ], [ "link", "surface", "4.5" ],
    [ "link-visited", "page", "4.5" ], [ "link-visited", "surface", "4.5" ],
    [ "on-primary", "primary", "4.5" ], [ "on-primary", "primary-pressed", "4.5" ],
    [ "primary", "page", "3" ], [ "primary", "surface", "3" ],
    [ "primary-pressed", "page", "3" ], [ "primary-pressed", "surface", "3" ],
    [ "border", "page", "3" ], [ "border", "surface", "3" ],
    [ "danger", "page", "4.5" ], [ "danger", "surface", "4.5" ],
    [ "on-danger", "danger", "4.5" ], [ "on-danger", "danger-pressed", "4.5" ],
    [ "danger-pressed", "page", "3" ], [ "danger-pressed", "surface", "3" ],
    [ "focus", "page", "3" ], [ "focus", "surface", "3" ], [ "focus", "ice", "3" ],
    [ "steel", "page", "3" ], [ "steel", "surface", "3" ],
    [ "disabled-text", "disabled-fill", "3" ]
  ].freeze
```

In `styleguide.css`, add the three missing swatch and ground classes beside the other `.sg-bg-*` lines (each followed by a space before `{`, which the request spec looks for):

```css
  .sg-bg-ice { background: var(--color-ice); }
  .sg-bg-ice-pale { background: var(--color-ice-pale); }
  .sg-bg-steel { background: var(--color-steel); }
```

- [ ] **Step 6: Mark the old derivation superseded.** In `docs/specs/020-base-stylesheet/plan.md`, under the heading "### The palette (derived once, recorded here)" add as its first line: `> **Superseded by spec 2.0.0.** These colors were derived by a method in version 1.2.1. They are replaced by fixed values; see "The palette, final" in the version 2.0 phases below.`
- [ ] **Step 7: Run and see them pass.** `bundle exec rspec spec/styles spec/requests` then `bundle exec rspec spec/system`. Expected: PASS, including the #73 layout specs unchanged. If any documented pair fails, stop and ask with the numbers.
- [ ] **Step 8: Commit** `Replace the palette with the Cold War colors and restyle the header`.

---

## Phase 9: The monospace font, `.mono` and the notices

**Implements:** FR-11, FR-1 (the one `url(`), Story 8, Story 6 (amended) | **Satisfies:** AC-6.2, 6.3, 8.1, 8.2 (static and loading), 8.3, 8.4 | **Files:** create `app/assets/fonts/IBMPlexMono-Medium-Latin1.woff2`, `app/assets/fonts/OFL.txt`, `spec/styles/font_spec.rb`, `spec/requests/font_spec.rb`, `spec/system/font_spec.rb`; modify `spec/support/stylesheets.rb`, `spec/styles/stylesheet_rules_spec.rb`, `app/assets/stylesheets/base.css`, `components.css`, `NOTICE` | **Interfaces:** `Stylesheets.violations(css, label, token_file: false, font_face: false)`, class `.mono`

- [ ] **Step 1: Write the failing specs.**

`spec/styles/font_spec.rb`:

```ruby
require "spec_helper"
require "digest"
require_relative "../support/stylesheets"

RSpec.describe "The self-hosted monospace (AC-6.2, 8.1 to 8.4)" do
  root = File.expand_path("../..", __dir__)
  fonts = File.join(root, "app/assets/fonts")
  file = "IBMPlexMono-Medium-Latin1.woff2"
  face = /@font-face\s*\{[^{}]*\}/m

  let(:sheets) { Stylesheets.files.to_h { |f| [ File.basename(f), Stylesheets.read(f) ] } }
  let(:notice) { File.read(File.join(root, "NOTICE")) }

  it "holds exactly one font file and the license beside it (AC-8.3)" do
    expect(Dir.children(fonts)).to match_array([ file, "OFL.txt" ])
    expect(File.read(File.join(fonts, "OFL.txt"))).to include("SIL OPEN FONT LICENSE Version 1.1")
  end

  it "records the file's SHA-256, source and license in NOTICE (AC-8.3, 8.4)" do
    sha = Digest::SHA256.file(File.join(fonts, file)).hexdigest
    expect(notice).to include("SHA-256: #{sha}")
    expect(notice).to include("IBM Plex Mono")
    expect(notice).to include("https://registry.npmjs.org/@ibm/plex-mono/-/plex-mono-2.5.0.tgz")
    expect(notice).to include("SIL Open Font License")
  end

  it "carries the CC BY-SA 4.0 notice for the inlined artwork (AC-8.4)" do
    expect(notice).to include("app/assets/images/icons")
    expect(notice).to include("CC BY-SA 4.0")
  end

  it "has exactly one @font-face, whose one url() is a bare file name, with swap and a weight range (AC-6.2)" do
    faces = sheets.values.flat_map { |css| css.scan(face) }
    expect(faces.size).to eq(1)
    block = faces.first
    expect(block.scan(/url\(/i).size).to eq(1)
    expect(block).to match(/url\(\s*"#{Regexp.escape(file)}"\s*\)/) # no scheme, no host, no folder
    expect(block).to match(/font-family:\s*"Plex Mono"/)
    expect(block).to match(/font-display:\s*swap/)
    expect(block).to match(/font-weight:\s*400 700/)
    expect(sheets.values.join("\n").gsub(face, "")).not_to match(/url\(/i)
  end

  it "reads --font-mono only in the .mono rule, which uses the regular weight token (AC-8.2)" do
    css = sheets.values.join("\n")
    readers = Stylesheets.rules(css).select { |_, body| body.include?("var(--font-mono)") }
    expect(readers.map(&:first)).to eq([ ".mono" ])
    expect(readers.first.last).to include("font-weight: var(--weight-regular)")
  end
end
```

`spec/requests/font_spec.rb` (the page really serves the font from this app):

```ruby
require "rails_helper"

RSpec.describe "The font is served by this app (AC-6.2, 6.3)", type: :request do
  it "links a stylesheet whose font url is a local path that answers with the file" do
    get "/styleguide"
    hrefs = Nokogiri::HTML5(response.body).css("link[rel=stylesheet]").map { |l| l["href"] }
    expect(hrefs).to all(start_with("/"))
    css = hrefs.map { |href| get(href) && response.body }.join("\n")
    path = css[/url\("(\/assets\/IBMPlexMono-Medium-Latin1-[0-9a-f]+\.woff2)"\)/, 1]
    expect(path).not_to be_nil
    get path
    expect(response).to have_http_status(:ok)
    expect(response.body.b).to eq(File.binread(Rails.root.join("app/assets/fonts/IBMPlexMono-Medium-Latin1.woff2")))
  end
end
```

In `spec/support/stylesheets.rb` change the scanner so one conforming block is allowed where the caller says so:

```ruby
  FONT_FACE = /@font-face\s*\{[^{}]*\}/m

  def violations(css, label, token_file: false, font_face: false)
    css = css.sub(FONT_FACE, "") if font_face # one block; font_spec holds its exact shape
    out = []
    # ...the rest of the method is unchanged...
```

In `spec/styles/stylesheet_rules_spec.rb`, the "no stray colors..." example passes `font_face: File.basename(f) == "base.css"`, and the scanner example for AC-6.2 becomes:

```ruby
    it "flags imports, a second font face and url( (AC-6.2)" do
      expect(found("@import 'x.css';")).not_to be_empty
      expect(found("@font-face { font-family: X; }")).not_to be_empty
      expect(found("a { background: url(x.png); }")).not_to be_empty
      one = '@font-face { font-family: "Plex Mono"; src: url("a.woff2"); }'
      expect(Stylesheets.violations(one, "x.css", font_face: true)).to be_empty
      expect(Stylesheets.violations("#{one} #{one}", "x.css", font_face: true)).not_to be_empty
      expect(Stylesheets.violations("#{one} a { background: url(x.png); }", "x.css", font_face: true)).not_to be_empty
    end
```

`spec/system/font_spec.rb` (the browser half of AC-6.2, 6.3 and 8.2: it needs the font and the stylesheet, not the style guide's new sections):

```ruby
require "rails_helper"

RSpec.describe "The font in the browser", type: :system do
  before { visit "/styleguide" }

  def load_font = page.evaluate_async_script(%(const done = arguments[0]; document.fonts.load('1rem "Plex Mono"').then((f) => done(f.length));))

  it "really loads the one face (AC-8.2)" do
    expect(load_font).to eq(1)
  end

  it "makes every request to this app, with the one font file as the only font (AC-6.3)" do
    load_font
    entries = evaluate_script("performance.getEntriesByType('resource').map((e) => e.name)")
    origin = evaluate_script("window.location.origin")
    expect(entries).not_to be_empty
    expect(entries).to all(start_with(origin))
    expect(entries.grep(/\.(woff2?|ttf|otf)(\?|\z)/).size).to eq(1)
    expect(entries.grep(/\.woff2\z/).size).to eq(1)
  end
end
```

- [ ] **Step 2: Run and see them fail.** `bundle exec rspec spec/styles spec/requests/font_spec.rb spec/system/font_spec.rb`. Expected: FAIL: no font folder, no `@font-face`, no `.mono`, no NOTICE text.
- [ ] **Step 3: Fetch, verify and add the files.** The tarball is untrusted data: it goes in its own new directory and nothing runs from inside it. From the repository root:

```sh
work="$(mktemp -d)"; mkdir "$work/dl" "$work/out"
curl -sS -o "$work/dl/plex-mono-2.5.0.tgz" https://registry.npmjs.org/@ibm/plex-mono/-/plex-mono-2.5.0.tgz
shasum "$work/dl/plex-mono-2.5.0.tgz"        # expect 152c0b1dda619ef5f032db258bda798cf278125e, the sha1 the registry publishes
tar -xzf "$work/dl/plex-mono-2.5.0.tgz" -C "$work/out" package/fonts/split/woff2/IBMPlexMono-Medium-Latin1.woff2 package/fonts/split/woff2/license.txt
mkdir -p web/app/assets/fonts
cp "$work/out/package/fonts/split/woff2/IBMPlexMono-Medium-Latin1.woff2" web/app/assets/fonts/
cp "$work/out/package/fonts/split/woff2/license.txt" web/app/assets/fonts/OFL.txt
shasum -a 256 web/app/assets/fonts/IBMPlexMono-Medium-Latin1.woff2
```

Expected SHA-256: `41201b658a328b9d00368215c2f1102770f80b15952ab82631e4006255e6365d` (17,868 bytes). If either checksum differs, stop and ask.

- [ ] **Step 4: Add the `@font-face` to `base.css`**, after the layer line and before `@layer reset`:

```css
/* The one web font: IBM Plex Mono Medium, Latin, served by this app. The face is
   declared for 400 to 700 so the browser never fakes a bold of it. */
@font-face {
  font-family: "Plex Mono";
  font-style: normal;
  font-weight: 400 700;
  font-display: swap;
  src: url("IBMPlexMono-Medium-Latin1.woff2") format("woff2");
}
```

- [ ] **Step 5: Add `.mono` to `components.css`**, inside `@layer components`, after the power badge rules:

```css
  /* ---- Mono text: the face for codes, abbreviations and tags ---- */
  .mono {
    font-family: var(--font-mono);
    font-weight: var(--weight-regular);
  }
```

- [ ] **Step 6: Add the notices to `web/NOTICE`.** In the "Artwork" paragraph, insert the sentence about the inlined copies before the sentence about Fraunces, and add the "Fonts" section after "Artwork" and before the paragraph that begins "Trucebearer is an independent, unofficial companion":

```
Artwork
-------
The Trucebearer logo, wordmark and icons are licensed under the Creative
Commons Attribution-ShareAlike 4.0 International License
(https://creativecommons.org/licenses/by-sa/4.0/), (C) 2026 James
Thompson, wherever they are copied in this repository, including into
this folder. The unit and supply-center drawings inlined by the app are
copies of assets/icons/, kept byte for byte in app/assets/images/icons/,
and are CC BY-SA 4.0 (see assets/LICENSE). The wordmark is set in Fraunces,
an SIL Open Font License 1.1 typeface by The Fraunces Project Authors,
outlined to vector shapes.

Fonts
-----
The app serves one font, IBM Plex Mono Medium (Latin subset), (C) 2017 IBM
Corp. with Reserved Font Name "Plex", under the SIL Open Font License 1.1.
The license text is in app/assets/fonts/OFL.txt. The file is the unmodified
IBMPlexMono-Medium-Latin1.woff2 from the @ibm/plex-mono package, release
2.5.0, https://registry.npmjs.org/@ibm/plex-mono/-/plex-mono-2.5.0.tgz
SHA-256: 41201b658a328b9d00368215c2f1102770f80b15952ab82631e4006255e6365d
```

(Only the sentence about the copies is new in "Artwork"; the Fraunces sentence is unchanged. "Plex Mono" in the stylesheet is a CSS family name for the unmodified file, not a modified font.)

- [ ] **Step 7: Run and see them pass.** `bundle exec rspec spec/styles spec/requests spec/system`. Expected: PASS, including `words_spec` (the OFL text and file names contain no forbidden word; the `.woff2` content is skipped).
- [ ] **Step 8: Commit** `Add the self-hosted IBM Plex Mono and the mono class`.

---

## Phase 10: The unit and supply-center helpers and their artwork

**Implements:** FR-10, Story 7, FR-4 (icons), FR-6 (icon rows) | **Satisfies:** AC-4.4, 7.1 to 7.9 (markup and files) | **Files:** create `app/helpers/icon_helper.rb`, `app/assets/images/icons/{army,army-small,fleet,fleet-small,supply-center}.svg`, `spec/assets/icons_spec.rb`; modify `spec/helpers/icon_helper_spec.rb`, `spec/support/stylesheets.rb`, `spec/styles/stylesheet_rules_spec.rb`, `components.css` | **Interfaces:** `unit_icon(power, type, size: 32, decorative: false)`, `supply_center_icon(owner, size: 32, decorative: false)`

- [ ] **Step 1: Finish the helper spec** (Phase 7's two examples stay; these are added in the same file):

```ruby
RSpec.describe IconHelper, type: :helper do
  powers = { "austria" => "Austria", "england" => "England", "france" => "France", "germany" => "Germany",
             "italy" => "Italy", "russia" => "Russia", "turkey" => "Turkey" }
  initials = { "austria" => "A", "england" => "E", "france" => "F", "germany" => "G",
               "italy" => "I", "russia" => "R", "turkey" => "T" }
  icons = File.expand_path("../../app/assets/images/icons", __dir__)

  def svg_of(html) = Nokogiri::HTML5.fragment(html).at_css("svg")
  def silhouette_path(file) = Nokogiri::XML(File.read(file)).at_css("#silhouette")["d"]

  describe "#unit_icon" do
    powers.each do |id, name|
      %w[army fleet].each do |type|
        it "labels #{type} of #{id} (AC-7.1)" do
          expect(svg_of(helper.unit_icon(id, type))["aria-label"]).to eq("#{type.capitalize}, #{name}")
        end
      end
    end

    it "is one inline svg with the stated attributes and parts (AC-7.1)" do
      html = helper.unit_icon(:austria, :army)
      svg = svg_of(html)
      expect(svg["viewBox"]).to eq("0 0 32 32")
      expect([ svg["width"], svg["height"] ]).to eq(%w[32 32])
      expect(svg["class"]).to eq("unit-icon unit-icon--austria")
      expect(svg.css("[id]")).to be_empty
      expect(svg.at_css("path.unit-icon__silhouette")).not_to be_nil
      expect(svg.at_css("g.unit-icon__marks .mark")).not_to be_nil
      expect(html).not_to match(/url\(|<style|<image|<script|<title|style=/i)
    end

    it "sets width and height from size (AC-7.1)" do
      svg = svg_of(helper.unit_icon(:italy, :fleet, size: 48))
      expect([ svg["width"], svg["height"] ]).to eq(%w[48 48])
    end

    it "accepts symbols and strings alike (AC-7.1)" do
      expect(helper.unit_icon(:england, :fleet)).to eq(helper.unit_icon("england", "fleet"))
    end

    it "is hidden from assistive technology when decorative (AC-7.2)" do
      svg = svg_of(helper.unit_icon(:austria, :army, decorative: true))
      expect(svg["aria-hidden"]).to eq("true")
      expect([ svg["role"], svg["aria-label"] ]).to eq([ nil, nil ])
    end

    it "raises ArgumentError for an unknown power, type or size, and renders nothing (AC-7.3)" do
      [ [ :wales, :army ], [ nil, :army ], [ "", :army ], [ :austria, :submarine ], [ :austria, nil ], [ :austria, "" ] ].each do |power, type|
        expect { helper.unit_icon(power, type) }.to raise_error(ArgumentError)
      end
      [ 0, -1, "32", 32.0, nil ].each do |size|
        expect { helper.unit_icon(:austria, :army, size: size) }.to raise_error(ArgumentError)
      end
    end

    it "uses the small drawing below 24 and the full one from 24 (AC-7.4)" do
      %w[army fleet].each do |type|
        small = silhouette_path(File.join(icons, "#{type}-small.svg"))
        full = silhouette_path(File.join(icons, "#{type}.svg"))
        expect(small).not_to eq(full)
        [ 20, 23 ].each { |s| expect(svg_of(helper.unit_icon(:austria, type, size: s)).at_css("path.unit-icon__silhouette")["d"]).to eq(small) }
        [ 24, 32, 48 ].each { |s| expect(svg_of(helper.unit_icon(:austria, type, size: s)).at_css("path.unit-icon__silhouette")["d"]).to eq(full) }
      end
    end

    initials.each do |id, initial|
      it "puts the initial #{initial} in the tag for #{id}, inside the bottom-right corner (AC-7.5)" do
        [ 20, 32 ].each do |size|
          svg = svg_of(helper.unit_icon(id, :army, size: size))
          tag = svg.at_css("g.unit-icon__tag")
          expect(tag["aria-hidden"]).to eq("true")
          tile = tag.at_css("rect.unit-icon__tag-tile")
          half = tile["stroke-width"].to_f / 2
          expect(tile["stroke-width"].to_f).to be >= 1.5
          # The stroked tile spans the corner exactly: outer edges at 20 and 32 on both axes.
          expect(tile["x"].to_f - half).to eq(20)
          expect(tile["y"].to_f - half).to eq(20)
          expect(tile["x"].to_f + tile["width"].to_f + half).to eq(32)
          expect(tile["y"].to_f + tile["height"].to_f + half).to eq(32)
          text = tag.at_css("text.unit-icon__tag-initial")
          expect(text.text).to eq(initial)
          expect(text["class"].split).to include("mono")
          expect(text["font-size"]).to eq("8")
        end
      end
    end
  end

  describe "#supply_center_icon" do
    it "labels an unowned center and uses the unowned class (AC-7.6)" do
      svg = svg_of(helper.supply_center_icon(nil))
      expect(svg["role"]).to eq("img")
      expect(svg["aria-label"]).to eq("Supply center, unowned")
      expect(svg["class"]).to eq("supply-center-icon supply-center-icon--unowned")
      expect([ svg["viewBox"], svg["width"], svg["height"] ]).to eq([ "0 0 32 32", "32", "32" ])
    end

    powers.each do |id, name|
      it "labels a center owned by #{id} (AC-7.6)" do
        svg = svg_of(helper.supply_center_icon(id))
        expect(svg["aria-label"]).to eq("Supply center, #{name}")
        expect(svg["class"]).to eq("supply-center-icon supply-center-icon--#{id}")
      end
    end

    it "has its parts as classes and no ids or url( (AC-7.1, 7.6)" do
      html = helper.supply_center_icon(:italy)
      svg = svg_of(html)
      expect(svg.css("[id]")).to be_empty
      %w[disk edge center].each { |part| expect(svg.at_css("path.supply-center-icon__#{part}")).not_to be_nil }
      expect(html).not_to match(/url\(|<style|<image|<script|<title|style=/i)
    end

    it "accepts a symbol or a string, and hides when decorative (AC-7.2, 7.6)" do
      expect(helper.supply_center_icon(:italy)).to eq(helper.supply_center_icon("italy"))
      svg = svg_of(helper.supply_center_icon(nil, decorative: true))
      expect(svg["aria-hidden"]).to eq("true")
      expect([ svg["role"], svg["aria-label"] ]).to eq([ nil, nil ])
    end

    it "raises ArgumentError for an unknown owner or a bad size, but not for nil (AC-7.3)" do
      [ "", :wales, "wales" ].each { |owner| expect { helper.supply_center_icon(owner) }.to raise_error(ArgumentError) }
      [ 0, -1, "32", 32.0, nil ].each { |size| expect { helper.supply_center_icon(:italy, size: size) }.to raise_error(ArgumentError) }
      expect { helper.supply_center_icon(nil) }.not_to raise_error
    end
  end
end
```

`spec/assets/icons_spec.rb` (AC-7.8, 7.9):

```ruby
require "spec_helper"

RSpec.describe "The inlined artwork (AC-7.8, 7.9)" do
  web = File.expand_path("../..", __dir__)
  masters = File.expand_path("../assets/icons", web)
  copies = File.join(web, "app/assets/images/icons")
  drawings = %w[army army-small fleet fleet-small supply-center]

  it "can see the masters (the whole repository is checked out locally and in CI)" do
    expect(Dir.exist?(masters)).to be(true)
  end

  drawings.each do |name|
    it "keeps #{name}.svg identical to its master" do
      expect(File.binread(File.join(copies, "#{name}.svg"))).to eq(File.binread(File.join(masters, "#{name}.svg")))
    end
  end

  it "has a copy for every master drawing and no other file" do
    expect(Dir.children(copies).sort).to eq(Dir.children(masters).grep(/\.svg\z/).sort)
    expect(Dir.children(copies).sort).to eq(drawings.map { |n| "#{n}.svg" }.sort)
  end

  it "never reads the root assets folder at run time" do
    files = Dir.glob(File.join(web, "{app,lib,config}/**/*")).select { |f| File.file?(f) && File.extname(f) != ".woff2" }
    hits = files.select { |f| File.binread(f).force_encoding("UTF-8").scrub.include?("assets/icons") }
    expect(hits).to be_empty, hits.join(", ")
  end

  it "draws an svg only in the icon helper (AC-7.8)" do
    files = Dir.glob(File.join(web, "app/{views,helpers}/**/*")).select { |f| File.file?(f) }
    hits = files.select { |f| File.read(f).include?("<svg") }.map { |f| f.delete_prefix("#{web}/") }
    expect(hits - [ "app/helpers/icon_helper.rb" ]).to be_empty
  end
end
```

In `spec/support/stylesheets.rb` and its scanner example, widen the AC-4.4 selector test from `.power-badge--` to the three variants:

```ruby
      next if selector.split(",").all? { |part| part.match?(/\.(?:power-badge|unit-icon|supply-center-icon)--(?:austria|england|france|germany|italy|russia|turkey)\z/) }
```

and in `stylesheet_rules_spec.rb` replace the AC-4.4 example with:

```ruby
    it "allows a power token only inside a badge, unit icon or supply-center icon variant rule (AC-4.4)" do
      expect(found(".power-badge--austria { --_fill: var(--color-power-austria); }")).to be_empty
      expect(found(".unit-icon--austria { --_power: var(--color-power-austria); }")).to be_empty
      expect(found(".supply-center-icon--austria { --_owner: var(--color-power-austria); }")).to be_empty
      expect(found(".button { color: var(--color-power-austria); }")).not_to be_empty
      expect(found(".unit-icon { color: var(--color-power-austria); }")).not_to be_empty
      expect(found(".power-badge--austria, .button { color: var(--color-power-austria); }")).not_to be_empty
    end
```

- [ ] **Step 2: Run and see it fail.** `bundle exec rspec spec/helpers spec/assets spec/styles`. Expected: FAIL (no `IconHelper`, no copies, the selector test).
- [ ] **Step 3: Copy the artwork, byte for byte,** from the repository root: `mkdir -p web/app/assets/images/icons && for n in army army-small fleet fleet-small supply-center; do cp assets/icons/$n.svg web/app/assets/images/icons/$n.svg; done`.
- [ ] **Step 4: Write the helper.**

```ruby
# The only way to draw a unit or a supply center, as power_badge is the only way to draw a
# badge (spec 020 FR-10). The drawings are copies of the master artwork in the repository's
# root icons folder, kept in app/assets/images/icons/ (the Docker build context is web/). Each part is named by an id
# in the artwork; the id becomes a class, so a page with many icons never repeats an id.
module IconHelper
  UNIT_TYPES = { "army" => "Army", "fleet" => "Fleet" }.freeze
  SMALL_BELOW = 24
  ICON_DIR = Rails.root.join("app/assets/images/icons").freeze
  SOURCES = %w[army army-small fleet fleet-small supply-center]
              .to_h { |name| [ name, ICON_DIR.join("#{name}.svg").read.freeze ] }.freeze

  # Bottom-right corner of the unit drawings (x and y from 20 to 32), left empty by the artwork.
  # The tile's 1.5 stroke is drawn inside it: the tile is inset by half the stroke.
  TAG = <<~SVG.strip.freeze
    <g class="unit-icon__tag" aria-hidden="true">
      <rect class="unit-icon__tag-tile" x="20.75" y="20.75" width="10.5" height="10.5" stroke-width="1.5"/>
      <text class="unit-icon__tag-initial mono" x="26" y="28.8" text-anchor="middle" font-size="8">%<initial>s</text>
    </g>
  SVG

  def unit_icon(power, type, size: 32, decorative: false)
    key = power_key(power)
    type_key = type.to_s
    raise ArgumentError, "unknown unit type: #{type.inspect}" unless UNIT_TYPES.key?(type_key)
    size = icon_size(size)

    name = PowerBadgeHelper::POWER_NAMES.fetch(key)
    file = size < SMALL_BELOW ? "#{type_key}-small" : type_key
    svg = icon_svg(file, "unit-icon", "unit-icon unit-icon--#{key}", size, "#{UNIT_TYPES.fetch(type_key)}, #{name}", decorative)
    svg.add_child(format(TAG, initial: name[0]))
    svg_markup(svg)
  end

  # A nil owner is the unowned look. Anything else must be one of the seven powers.
  def supply_center_icon(owner, size: 32, decorative: false)
    key = owner.nil? ? nil : power_key(owner)
    size = icon_size(size)

    label = "Supply center, #{key ? PowerBadgeHelper::POWER_NAMES.fetch(key) : 'unowned'}"
    classes = "supply-center-icon supply-center-icon--#{key || 'unowned'}"
    svg_markup(icon_svg("supply-center", "supply-center-icon", classes, size, label, decorative))
  end

  private

  def power_key(identifier)
    key = identifier.to_s
    PowerBadgeHelper::POWER_NAMES.key?(key) ? key : raise(ArgumentError, "unknown power: #{identifier.inspect}")
  end

  def icon_size(size)
    size.is_a?(Integer) && size.positive? ? size : raise(ArgumentError, "size must be an Integer above zero: #{size.inspect}")
  end

  def icon_svg(file, block, classes, size, label, decorative)
    svg = Nokogiri::XML(SOURCES.fetch(file)).root
    svg["class"] = classes
    svg["width"] = svg["height"] = size.to_s
    if decorative
      svg["aria-hidden"] = "true"
    else
      svg["role"] = "img"
      svg["aria-label"] = label
    end
    svg.xpath(".//*[@id]").each do |part|
      id = part["id"]
      part.remove_attribute("id")
      part["class"] = [ part["class"], "#{block}__#{id}" ].compact.join(" ")
    end
    svg
  end

  def svg_markup(svg)
    svg.to_xml(save_with: Nokogiri::XML::Node::SaveOptions::AS_XML).html_safe
  end
end
```

If Nokogiri's XML serializer or the HTML parser disagrees with this shape (for example an `xmlns=""` on the added group), the spec in Step 1 shows it, and the fix stays inside `icon_svg` and `svg_markup`. That is recorded in the plan's "Changes made during implementation" if it happens.

- [ ] **Step 5: Add the icon rules to `components.css`**, inside `@layer components`, after `.mono`:

```css
  /* ---- Unit and supply-center icons: made only by the icon helpers ---- */
  .unit-icon,
  .supply-center-icon {
    display: inline-block;
    flex: none;
    vertical-align: middle;
  }

  /* The silhouette is currentColor, so the power's color is the element's color. The marks keep
     the artwork's white. The tag is a surface tile with a border and an initial in the power's color. */
  .unit-icon { color: var(--_power, var(--color-text)); }
  .unit-icon__tag-tile { fill: var(--color-surface); stroke: var(--_power); }
  .unit-icon__tag-initial { fill: var(--_power); }

  .unit-icon--austria { --_power: var(--color-power-austria); }
  .unit-icon--england { --_power: var(--color-power-england); }
  .unit-icon--france { --_power: var(--color-power-france); }
  .unit-icon--germany { --_power: var(--color-power-germany); }
  .unit-icon--italy { --_power: var(--color-power-italy); }
  .unit-icon--russia { --_power: var(--color-power-russia); }
  .unit-icon--turkey { --_power: var(--color-power-turkey); }

  /* Unowned is the artwork's own look (white disk), with the edge and center in text color. Owned: the
     disk and edge take the owner's color and the center is white. */
  .supply-center-icon { color: var(--color-text); }

  .supply-center-icon:not(.supply-center-icon--unowned) .supply-center-icon__disk,
  .supply-center-icon:not(.supply-center-icon--unowned) .supply-center-icon__edge { fill: var(--_owner); }
  .supply-center-icon:not(.supply-center-icon--unowned) .supply-center-icon__center { fill: var(--color-on-power); }

  .supply-center-icon--austria { --_owner: var(--color-power-austria); }
  .supply-center-icon--england { --_owner: var(--color-power-england); }
  .supply-center-icon--france { --_owner: var(--color-power-france); }
  .supply-center-icon--germany { --_owner: var(--color-power-germany); }
  .supply-center-icon--italy { --_owner: var(--color-power-italy); }
  .supply-center-icon--russia { --_owner: var(--color-power-russia); }
  .supply-center-icon--turkey { --_owner: var(--color-power-turkey); }
```

- [ ] **Step 6: Run and see them pass.** `bundle exec rspec spec/helpers spec/assets spec/styles`. Expected: PASS, including Phase 7's two examples (green for the first time).
- [ ] **Step 7: Commit** `Add the unit and supply-center icon helpers and their artwork`.

---

## Phase 11: The style guide sections and the browser checks

**Implements:** FR-6 (rows), FR-7, Story 5, Story 7 (AC-7.7, 7.10), Story 8 (AC-8.2 browser part), FR-1 | **Satisfies:** AC-5.1, 5.4, 4.5, 7.7, 7.10, 8.2 (computed font) | **Files:** modify `app/views/styleguide/show.html.erb`, `app/helpers/styleguide_helper.rb`, `app/assets/stylesheets/styleguide.css`, `spec/requests/styleguide_spec.rb`; create `spec/system/icons_spec.rb` | **Interfaces:** `StyleguideHelper::UNIT_SIZES`

- [ ] **Step 1: Write the failing specs.** In `spec/requests/styleguide_spec.rb`: `components = %w[button link list field choice power-badge heading-text unit-icon supply-center-icon mono-text]`, and add:

```ruby
    it "shows every power's army and fleet at 20, 32 and 48 pixels, one row on ice-pale (AC-7.10, 4.5)" do
      icons = page.css(".sg-units .unit-icon")
      expect(icons.size).to eq(42)
      expect(icons.map { |i| [ i["width"], i["class"][/unit-icon--(\w+)/, 1] ] }.tally.values.uniq).to eq([ 2 ])
      expect(icons.map { |i| i["width"] }.tally).to eq("20" => 14, "32" => 14, "48" => 14)
      expect(page.css(".sg-units .sg-bg-ice-pale").size).to eq(1)
      expect(page.css(".sg-unit__name").map(&:text)).to match_array(%w[Austria England France Germany Italy Russia Turkey])
    end

    it "shows each owner and the unowned look, named beside each (AC-7.10)" do
      expect(page.css(".sg-supply .supply-center-icon").map { |i| i["class"][/--(\w+)\z/, 1] })
        .to match_array(%w[austria england france germany italy russia turkey unowned])
      expect(page.css(".sg-supply__name").map(&:text)).to include("Unowned", "Austria")
    end

    it "shows a line of mono text" do
      expect(page.css("section[data-component=mono-text] .mono").size).to be >= 1
    end
```

`spec/system/icons_spec.rb` (AC-7.7 and the computed font of AC-8.2, in real Chrome; the font loading and the request origins are in Phase 9):

```ruby
require "rails_helper"

RSpec.describe "Icons and the monospace in the browser", type: :system do
  powers = %w[austria england france germany italy russia turkey]

  def rgb(hex) = "rgb(#{hex.delete('#').scan(/../).map { |c| c.to_i(16) }.join(', ')})"

  # The value of a color token, as the stylesheet declares it, converted to the rgb() the browser reports.
  def token(name) = rgb(evaluate_script("getComputedStyle(document.documentElement).getPropertyValue('--color-#{name}')").strip)

  def paint(selector, property) = evaluate_script("getComputedStyle(document.querySelector(#{selector.to_json}))[#{property.to_json}]")

  before { visit "/styleguide" }

  powers.each do |id|
    it "colors a #{id} unit from its power token (AC-7.7)" do
      icon = ".sg-units .unit-icon--#{id}"
      expect(paint("#{icon} .unit-icon__silhouette", "fill")).to eq(token("power-#{id}"))
      expect(paint("#{icon} .mark", "fill")).to eq(rgb("#ffffff"))
      expect(paint("#{icon} .unit-icon__tag-tile", "fill")).to eq(token("surface"))
      expect(paint("#{icon} .unit-icon__tag-tile", "stroke")).to eq(token("power-#{id}"))
      expect(paint("#{icon} .unit-icon__tag-initial", "fill")).to eq(token("power-#{id}"))
    end

    it "colors a supply center owned by #{id} (AC-7.7)" do
      icon = ".sg-supply .supply-center-icon--#{id}"
      expect(paint("#{icon} .supply-center-icon__disk", "fill")).to eq(token("power-#{id}"))
      expect(paint("#{icon} .supply-center-icon__edge", "fill")).to eq(token("power-#{id}"))
      expect(paint("#{icon} .supply-center-icon__center", "fill")).to eq(token("on-power"))
    end
  end

  it "draws an unowned supply center with a white disk and a text-colored edge and center (AC-7.7)" do
    icon = ".sg-supply .supply-center-icon--unowned"
    expect(paint("#{icon} .supply-center-icon__disk", "fill")).to eq(rgb("#ffffff"))
    expect(paint("#{icon} .supply-center-icon__edge", "fill")).to eq(token("text"))
    expect(paint("#{icon} .supply-center-icon__center", "fill")).to eq(token("text"))
  end

  it "sets .mono in Plex Mono (AC-8.2)" do
    expect(paint("section[data-component=mono-text] .mono", "fontFamily")).to start_with('"Plex Mono"')
  end
end
```

- [ ] **Step 2: Run and see them fail.** `bundle exec rspec spec/requests/styleguide_spec.rb spec/system/icons_spec.rb`. Expected: FAIL (no sections).
- [ ] **Step 3: Write the sections.** In `StyleguideHelper` add `UNIT_SIZES = [ 20, 32, 48 ].freeze` and `UNIT_TYPES = %w[army fleet].freeze`. In `show.html.erb`, after the power badge section and before Colors:

```erb
  <section data-component="unit-icon" class="stack" aria-labelledby="sg-unit-icon">
    <h2 id="sg-unit-icon">Unit icons</h2>
    <p>An army and a fleet for each power, at 20, 32 and 48 pixels. The tag in the corner holds the power's initial. The first row sits on <code>ice-pale</code>.</p>
    <ul class="sg-units">
      <% StyleguideHelper::POWER_IDS.each_with_index do |id, index| %>
        <li class="sg-unit<%= " sg-bg-ice-pale" if index.zero? %>">
          <span class="sg-unit__name"><%= PowerBadgeHelper::POWER_NAMES.fetch(id) %></span>
          <span class="sg-unit__icons">
            <% StyleguideHelper::UNIT_TYPES.each do |type| %>
              <% StyleguideHelper::UNIT_SIZES.each do |size| %>
                <%= unit_icon(id, type, size: size, decorative: true) %>
              <% end %>
            <% end %>
          </span>
        </li>
      <% end %>
    </ul>
    <p>With no name beside it, an icon carries its own label, which a screen reader reads out:</p>
    <p><%= unit_icon(:austria, :army) %> <%= unit_icon(:england, :fleet) %></p>
  </section>

  <section data-component="supply-center-icon" class="stack" aria-labelledby="sg-supply-icon">
    <h2 id="sg-supply-icon">Supply-center icons</h2>
    <p>A center owned by each power, and an unowned one.</p>
    <ul class="sg-supply">
      <% StyleguideHelper::POWER_IDS.each do |id| %>
        <li class="sg-supply__item"><%= supply_center_icon(id, decorative: true) %> <span class="sg-supply__name"><%= PowerBadgeHelper::POWER_NAMES.fetch(id) %></span></li>
      <% end %>
      <li class="sg-supply__item"><%= supply_center_icon(nil, decorative: true) %> <span class="sg-supply__name">Unowned</span></li>
    </ul>
  </section>

  <section data-component="mono-text" class="stack" aria-labelledby="sg-mono">
    <h2 id="sg-mono">Mono text</h2>
    <p>The <code>mono</code> class sets text in the one self-hosted monospace. It is for codes and tags, not for sentences.</p>
    <p class="mono">JOIN 4F7-K2Q &middot; PAR &middot; SPRING 1901</p>
  </section>
```

In `styleguide.css`, add (inside `@layer styleguide`):

```css
  .sg-units,
  .sg-supply { margin: 0; padding: 0; list-style: none; }

  .sg-unit,
  .sg-supply__item { display: flex; flex-wrap: wrap; align-items: center; gap: var(--space-3); padding: var(--space-2) var(--space-3); }
  .sg-unit__name { min-width: 5rem; }
  .sg-unit__icons { display: flex; align-items: center; gap: var(--space-2); }
```

- [ ] **Step 4: Run and see them pass.** `bundle exec rspec spec/requests spec/system spec/styles`. Expected: PASS, with `styleguide.css` still at or under 4 KB and the folder under 24 KB (the rules spec checks both). If a limit is passed, shrink the new rules first and raise the question before touching the limit.
- [ ] **Step 5: Commit** `Show the unit, supply-center and mono sections on the style guide`.

---

## Phase 12: The design-system document

**Implements:** FR-12, Story 9, FR-9 (provenance) | **Satisfies:** AC-9.1, 9.2, 4.6 | **Files:** create `docs/design-system.md`, `spec/docs/design_system_spec.rb` | **Interfaces:** none

- [ ] **Step 1: Write the failing spec.**

```ruby
require "spec_helper"
require_relative "../support/stylesheets"

RSpec.describe "The design-system document (AC-9.1, 9.2)" do
  doc = File.read(File.expand_path("../../docs/design-system.md", __dir__))

  it "has the six parts the screens build to (AC-9.1)" do
    [ "## Palette", "## Power colors", "## Type", "## Units and supply centers", "## Helpers", "## Component catalog" ].each do |heading|
      expect(doc).to include(heading)
    end
  end

  it "names every color token with its hex value on the same line (AC-9.2)" do
    Stylesheets.color_tokens.each do |name, hex|
      line = doc.lines.find { |l| l.include?("`#{name}`") && l.downcase.include?(hex.downcase) }
      expect(line).not_to be_nil, "#{name} #{hex} is not on one line of docs/design-system.md"
    end
  end

  it "says the power values are fixed and that no edition was consulted (AC-4.6)" do
    expect(doc).to match(/fixed/i)
    expect(doc).to match(/no edition/i)
  end
end
```

- [ ] **Step 2: Run and see it fail.** `bundle exec rspec spec/docs`. Expected: FAIL (no file).
- [ ] **Step 3: Write `web/docs/design-system.md`** from the Issue's "Design system content", in this order:
  1. A short opening that says what the page is, that screen Issues build to it, that `docs/architecture.md` records the decisions and `tokens.css` holds the values.
  2. `## Palette`: a table with one row per color token (`| \`--color-page\` | \`#eef3f6\` | use |`), the Issue's uses, the rule that outcomes and seat states get no hue of their own, and the list of documented pairs (the 31, with their minimum).
  3. `## Power colors`: a table of the seven (`--color-power-austria` `#586f2a` olive, and so on), the statement that the values are fixed (decision 42), differ in hue from each power's familiar board color on purpose, that England and Russia are 25.7 degrees apart so nobody adjusts them, that no edition was consulted, and the red-green color-blindness note.
  4. `## Type`: the system sans, `--font-mono`, where mono is used, `.mono`, phase headers as capitals with CSS letter spacing from sentence-case source, and that the face is Medium only (bold and regular look alike; never rely on bold there).
  5. `## Units and supply centers`: the Issue's rules (one army, one fleet, the power-initial tag, supply-center owned and unowned looks, 32 pixels for rows, about 20 for a future map, small drawings below 24, a visible name beside a unit under 24 in lists and screens).
  6. `## Helpers`: `unit_icon` and `supply_center_icon` signatures, labels, `decorative`, `ArgumentError`, the only-way rule, where the copies live and that the master is `assets/icons/`.
  7. `## Component catalog`: the Issue's tables as written (already built, built here, playtest screens, 1.0 screens, glyphs from #82, map-only icons), with `Built by` Issue numbers.
- [ ] **Step 4: Run and see it pass.** `bundle exec rspec spec/docs`. Expected: PASS.
- [ ] **Step 5: Commit** `Write the design-system document`.

---

## Phase 13: Integration verification, screenshots and the plan record

**Implements:** FR-1, FR-5, FR-8, Verification rows, NFR | **Satisfies:** AC-1.1 to 1.6, 3.x (the #73 specs and the Chrome pass), 5.x, 6.1 to 6.6, 7.10 | **Files:** modify `docs/specs/020-base-stylesheet/measure.md`, `plan.md` (this file); create `docs/specs/020-base-stylesheet/screenshots/styleguide-360-units.png`, `styleguide-360-supply-mono.png`, `styleguide-360-colors.png`

- [ ] **Step 1: Run the whole suite.** From `web/`: `bundle exec rspec`. Expected: 0 failures. Record the example count.
- [ ] **Step 2: Run the project's own checks** from `web/`: `bin/rubocop` and `bin/brakeman` (the `html_safe` in the icon helper is new code, and its input is a fixed list and the app's own files). Fix findings in the new files only.
- [ ] **Step 3: Chrome pass at 360 pixels.** With `bin/rails server -p 3020` and the scratch frame page from `measure.md` (kept out of git), open `/styleguide` at 360 by 800 and read the console snippet's result (no sideways scroll, targets, gaps, text sizes). The snippet lists every tag initial as "text under 14px" (the SVG `text` computes to 8 pixels). That is the AC-1.1 exemption: filter `text.unit-icon__tag-initial` out of the result before reading it, and say so in the record. Look at the unit section at 20, 32 and 48 pixels, the supply-center section and the mono line. Take the three screenshots by the method in `measure.md` ("Method", step 4) and save them in the screenshots folder. Delete `public/frame.html` and its exclude line afterwards.
- [ ] **Step 4: Check forced colors and reduced motion once** in Chrome's emulation, including that the icons keep their colors, and record the result in `measure.md`, or record that the emulation was not usable, as #20 did.
- [ ] **Step 5: Record the work.** Append to `measure.md` a dated section "Re-run after the re-theme (2026-11-26, spec 2.0.x)" with the system-spec result and the Chrome pass, and the three screenshot names. Append the Plan Changelog below to the end of `plan.md`.

```markdown
## Plan Changelog

| Version | Phase | Change |
|---|---|---|
| 2.0.0 | Phase 7 | Added: the required first test, the helper contract (AC-7.1, 7.3) |
| 2.0.0 | Phase 8 | Added: the palette, tokens and header; the old derivation under "The palette" is superseded (FR-2, FR-3, FR-9) |
| 2.0.0 | Phase 9 | Added: the font, `.mono` and the notices (FR-11) |
| 2.0.0 | Phase 10 | Added: the icon helpers and the artwork copies (FR-10) |
| 2.0.0 | Phase 11 | Added: the style guide sections and the browser checks (FR-7) |
| 2.0.0 | Phase 12 | Added: the design-system document (FR-12) |
| 2.0.0 | Phase 13 | Added: integration verification and the record |
```

- [ ] **Step 6: Final proof, from `web/` and the repository root.** `bundle exec rspec` passes with system specs included; `git diff --name-only main...HEAD | grep -v '^web/'` prints nothing; the `Web specs` job is green on the pull request.
- [ ] **Step 7: Commit** `Record the re-theme measurements and the plan changes`.
- [ ] **Step 8: Write the pull request description** from `.github/pull_request_template.md`: "Closes #81"; the reason the font is a new asset and not a dependency (no system monospace is the same on every phone, and a six-character join code is read aloud); the font's source URL, release version and SHA-256, also recorded in `web/NOTICE`; where the icon copies live and the spec that guards them; the three style-guide screenshots at 360 pixels; the contrast numbers; the header design call (`ice` fill, `steel` rule) for the maintainer to look at; the AC-1.1 exemption; the owed items (#71 phone pass, #86 CI paths); the implementation review and how each finding was handled; ends with the Claude Code line.

---

## Spec coverage (2.0 self-review)

| Spec item | Phase |
|---|---|
| Story 2: AC-2.1, 2.2, 2.3, 2.9, 2.10 | 8 |
| Story 4: AC-4.1, 4.2, 4.4, 4.5, 4.6 | 8 (values, hues, record), 10 (AC-4.4), 11 (AC-4.5), 12 (AC-4.6) |
| Story 5: AC-5.1, 5.4 | 8 (swatches, samples), 11 (sections) |
| Story 6: AC-6.2, 6.3 | 9 (static), 11 (browser) |
| Story 7: AC-7.1 to 7.6, 7.8, 7.9 | 7 (first two examples), 10 |
| AC-7.7, 7.10 | 11 |
| Story 8: AC-8.1, 8.3, 8.4 | 9 |
| AC-8.2 | 9 (static), 11 (browser) |
| Story 9: AC-9.1, 9.2 | 12 |
| AC-1.1 exemption | 10 (the tag text carries `font-size` in drawing units, and the page text rule is unchanged); 13 (Chrome pass) |
| FR-1 (one `url(`, size limits) | 9, 11 |
| FR-2, FR-3, FR-9 | 8 |
| FR-4, FR-6 rows, FR-7 | 10, 11 |
| FR-5 (header) | 8 |
| FR-10 | 10 |
| FR-11 | 9 |
| FR-12 | 12 |
| NFR performance (one font, swap) | 9, 11 |
| Verification rows, the #73 specs | 8 and 11 (run), 13 |
| Spec 020 amended with a changelog row (Issue "Done when") | Done before planning: spec changelog rows 2.0.0 to 2.0.2 |
| Reason for the font as an asset, in the pull request (Issue note) | 13, step 8 |
| Error scenarios (bad args, font missing, copy drift) | 10 (args, drift), 9 (font fallback by `swap`; nothing to test) |

Gaps: none. Placeholder scan: none. Type check: `IconHelper#unit_icon`, `#supply_center_icon`, `Stylesheets.violations(..., font_face:)`, `Stylesheets.ice_uses`, `StyleguideHelper::UNIT_SIZES` and `UNIT_TYPES` are each defined where first used and spelled the same everywhere.

## Plan Changelog

| Version | Phase | Change |
|---|---|---|
| 2.0.0 | Phase 7 | Added: the required first test, the helper contract (AC-7.1, 7.3) |
| 2.0.0 | Phase 8 | Added: the palette, tokens and header; the old derivation under "The palette" is superseded (FR-2, FR-3, FR-9) |
| 2.0.0 | Phase 9 | Added: the font, `.mono` and the notices (FR-11) |
| 2.0.0 | Phase 10 | Added: the icon helpers and the artwork copies (FR-10) |
| 2.0.0 | Phase 11 | Added: the style guide sections and the browser checks (FR-7) |
| 2.0.0 | Phase 12 | Added: the design-system document (FR-12) |
| 2.0.0 | Phase 13 | Added: integration verification and the record |

## Changes made during implementation (version 2.0)

| Change | Why |
|---|---|
| The rules spec's steel check allows the style guide's own `.sg-bg-steel` swatch class besides `.app-header` | The swatch and the sample ground for the documented `steel` pairs have to read the token. The rule is that no component reads it |
| `spec/support/stylesheets.rb` gained `FONT_FACE` and the `font_face:` option on `violations`, as Phase 9 planned, plus `Stylesheets.ice_uses` | As planned |
| The in-browser font checks (the face loads, every request is to this origin) live in `spec/system/font_spec.rb` in Phase 9, not in Phase 11 | The plan review: they depend on the font and the stylesheet, not on the new style guide sections, so they fail first in Phase 9 |
| Phase 10 ran straight after Phase 7, then 8, 9, 11, 12, 13 | The plan review: Phase 7's spec stays red until the helper exists, and a red file stops a whole run |
| Screenshot `styleguide-360-top.png` was added beside the three planned ones | It shows the header, which is the maintainer's design call |

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

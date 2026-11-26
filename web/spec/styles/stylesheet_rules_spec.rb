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

  it "sets the header on ice with a steel rule, and no component reads steel (FR-2)" do
    layout = Stylesheets.rules(Stylesheets.read(File.join(Stylesheets::DIR, "layout.css")))
    header = layout.find { |selector, _| selector == ".app-header" }&.last.to_s
    expect(header).to include("background: var(--color-ice)")
    expect(header).to match(/border-bottom:[^;]*var\(--color-steel\)/)
    steel_readers = Stylesheets.files.flat_map do |f|
      Stylesheets.rules(Stylesheets.read(f)).select { |_, body| body.include?("var(--color-steel)") }.map(&:first)
    end
    # Only the header rule, and the style guide's own swatch class, read it. It is decorative.
    expect(steel_readers.reject { |selector| selector.start_with?(".sg-") }).to eq([ ".app-header" ])
  end

  it "defines the token groups of FR-2" do
    t = Stylesheets.tokens
    %w[--font-sans --font-mono --text-sm --text-base --text-lg --text-xl --text-2xl --leading-tight --leading-normal
       --weight-regular --weight-strong --gutter --tap-min --content-max --radius --border-width
       --focus-width --focus-offset --scroll-pad].each { |n| expect(t).to have_key(n) }
    (1..8).each { |i| expect(t).to have_key("--space-#{i}") }
    expect(t["--text-base"]).to eq("1rem")
    expect(t["--font-sans"]).to start_with("system-ui").and end_with("sans-serif")
    expect(t["--font-mono"]).to eq('"Plex Mono", ui-monospace, "SF Mono", Menlo, Consolas, monospace')
    expect(t["--space-1"]).to eq("0.25rem")
    expect(t["--tap-min"]).to eq("max(44px, 2.75rem)")
    expect(t["--content-max"]).to eq("40rem")
    sizes = %w[--text-sm --text-base --text-lg --text-xl --text-2xl].map { |n| t[n] }
    expect(sizes).to all(match(/\A[\d.]+rem\z/))
    expect(sizes.map(&:to_f).min).to be >= 0.875
  end

  it "has no stray colors, banned properties, px font sizes, imports, fonts or url( in any file (AC-2.4, 2.5, 2.8, 1.5, 6.2, 4.4)" do
    problems = files.flat_map do |f|
      Stylesheets.violations(Stylesheets.read(f), File.basename(f), token_file: f == Stylesheets::TOKENS,
                             font_face: File.basename(f) == "base.css")
    end
    expect(problems).to be_empty, problems.join("\n")
  end

  it "does not set a root font size, or block zoom" do
    css = files.map { |f| Stylesheets.read(f) }.join("\n")
    Stylesheets.rules(css).each do |selector, body|
      roots = selector.split(",").map(&:strip) & %w[html :root]
      next if roots.empty?
      expect(body).not_to match(/(?<![\w-])font(?:-size)?\s*:/), "#{selector} sets a font size"
    end
    expect(css).not_to include("user-scalable")
  end

  it "keeps a custom property from holding a color outside the token file (AC-2.5)" do
    non_token_files.each do |f|
      Stylesheets.declarations(Stylesheets.read(f)).select { |p, _, _| p.start_with?("--") }.each do |p, v, line|
        expect(v).not_to match(Stylesheets::HEX_COLOR), "#{File.basename(f)}:#{line} #{p} holds a color"
      end
    end
  end

  # The limits were 24 KB and 4 KB until spec 022 (changelog 1.2.0) raised them for the screen components the catalog plans.
  it "keeps total weight within 32 KB and the style guide within 6 KB (FR-1)" do
    expect(files.sum { |f| File.size(f) }).to be <= 32 * 1024
    expect(File.size?(File.join(Stylesheets::DIR, "styleguide.css")).to_i).to be <= 6 * 1024
  end

  it "sets touch-action and safe-area insets, and sizes fields at 1rem (AC-1.4, 1.6, 3.5)" do
    css = files.map { |f| Stylesheets.read(f) }.join("\n")
    components = Stylesheets.rules(Stylesheets.read(File.join(Stylesheets::DIR, "components.css")))
    [ ".button", "a.list__row", ".choice" ].each do |selector|
      rule = components.find { |sel, _| sel.split(",").map(&:strip).include?(selector) && !sel.include?(":") }
      expect(rule&.last).to include("touch-action: manipulation"), "#{selector} needs touch-action: manipulation"
    end
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
      [ "a { color: #fff; }", "a { color: #ffffff80; }", "a { color: rgb(0 0 0); }", "a { color: rgba(0,0,0,.5); }",
       "a { color: hsl(10 10% 10%); }", "a { color: oklch(50% 0.1 20); }", "a { color: red; }",
       "a { color: ButtonText; }", "a { background: linear-gradient(white, black); }" ].each do |css|
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
      expect(found("a {\n  color: #fff;\n}")).to eq([ "x.css:2: hex color in color" ])
    end

    it "flags banned properties but allows opacity: 1 (AC-2.8)" do
      expect(found("a { opacity: 0.5; }")).not_to be_empty
      expect(found("a { filter: blur(2px); }")).not_to be_empty
      expect(found("a { backdrop-filter: blur(2px); }")).not_to be_empty
      expect(found("a { mix-blend-mode: multiply; }")).not_to be_empty
      expect(found("a { opacity: 1; }")).to be_empty
    end

    it "reads a var() fallback, vendor colors, and old system colors, but not quoted text (AC-2.4)" do
      expect(found("a { color: var(--color-text, black); }")).not_to be_empty
      expect(found("a { color: Window; }")).not_to be_empty
      expect(found("a { color: -webkit-link; }")).not_to be_empty
      expect(found("a { color: -moz-hyperlinktext; }")).not_to be_empty
      expect(found("a { anchor-name: --menu; grid-area: header; }")).to be_empty
      expect(found('a::after { content: "Error: field required"; }')).to be_empty
    end

    it "flags a px size reached through a font custom property (AC-1.5)" do
      expect(found(":root { --text-xs: 12px; }")).not_to be_empty
      expect(found(":root { --tap-min: max(44px, 2.75rem); }")).to be_empty
      expect(found(":root { --size: 12px; } a { font-size: var(--size); }")).not_to be_empty
      expect(found(":root { --tap-min: 44px; } a { min-height: var(--tap-min); }")).to be_empty
    end

    it "flags px font sizes (AC-1.5)" do
      expect(found("a { font-size: 16px; }")).not_to be_empty
      expect(found("a { font: 16px/1.5 sans-serif; }")).not_to be_empty
      expect(found("a { font-size: var(--text-base); }")).to be_empty
    end

    it "flags imports, a second font face and url( (AC-6.2)" do
      expect(found("@import 'x.css';")).not_to be_empty
      expect(found("@font-face { font-family: X; }")).not_to be_empty
      expect(found("a { background: url(x.png); }")).not_to be_empty
      one = '@font-face { font-family: "Plex Mono"; src: url("a.woff2"); }'
      expect(Stylesheets.violations(one, "x.css", font_face: true)).to be_empty
      expect(Stylesheets.violations("#{one} #{one}", "x.css", font_face: true)).not_to be_empty
      expect(Stylesheets.violations("#{one} a { background: url(x.png); }", "x.css", font_face: true)).not_to be_empty
    end

    it "lets the token file hold hex only in --color-* tokens (AC-2.5)" do
      expect(Stylesheets.violations(":root { --color-page: #f6f3ec; }", "t.css", token_file: true)).to be_empty
      expect(Stylesheets.violations(":root { --brand: #123456; }", "t.css", token_file: true)).not_to be_empty
      expect(Stylesheets.violations(":root { --color-page: red; }", "t.css", token_file: true)).not_to be_empty
      expect(Stylesheets.violations(":root { --bg: url(a.png); }", "t.css", token_file: true)).not_to be_empty
    end

    it "allows a power token only inside a badge, unit icon or supply-center icon variant rule (AC-4.4)" do
      expect(found(".power-badge--austria { --_fill: var(--color-power-austria); }")).to be_empty
      expect(found(".unit-icon--austria { --_power: var(--color-power-austria); }")).to be_empty
      expect(found(".supply-center-icon--austria { --_owner: var(--color-power-austria); }")).to be_empty
      expect(found(".button { color: var(--color-power-austria); }")).not_to be_empty
      expect(found(".unit-icon { color: var(--color-power-austria); }")).not_to be_empty
      expect(found(".button .unit-icon--austria { color: var(--color-power-austria); }")).not_to be_empty
      expect(found(".app-main .power-badge--austria { --_fill: var(--color-power-austria); }")).not_to be_empty
      expect(found(".power-badge--austria, .button { color: var(--color-power-austria); }")).not_to be_empty
    end
  end
end

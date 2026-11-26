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
    accentcolor accentcolortext window windowtext windowframe buttonhighlight buttonshadow threedface
    threeddarkshadow threedhighlight threedlightshadow threedshadow menu menutext captiontext
    infobackground infotext inactivecaption inactivecaptiontext appworkspace activeborder
    inactiveborder activecaption
  ].freeze
  FONT_FACE = /@font-face\s*\{[^{}]*\}/m
  VENDOR_COLOR = /-(?:webkit|moz)-(?:link|activelink|focus-ring-color|any-link|hyperlinktext|activehyperlinktext|visitedhyperlinktext)\b/i
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
      [ m[1], m[2].strip, css[0...m.begin(0)].count("\n") + 1 ]
    end
  end

  # [[selector, body], ...] for every innermost rule.
  def rules(css)
    # A selector starts after the last ";" (an @layer line, say) or "}" before it.
    css.scan(/([^{}]+)\{([^{}]*)\}/m).map { |sel, body| [ sel.split(";").last.to_s.strip, body ] }
  end

  # { "--color-page" => "#eef3f6", ... } from the token file.
  def tokens(path = TOKENS)
    declarations(read(path)).select { |p, _, _| p.start_with?("--") }.to_h { |p, v, _| [ p, v ] }
  end

  def color_tokens(path = TOKENS)
    tokens(path).select { |name, _| name.start_with?("--color-") }
  end

  # [[property, line], ...] for each declaration that reads --color-ice (not --color-ice-pale).
  def ice_uses(css)
    declarations(css).select { |_, value, _| value.match?(/var\(\s*--color-ice\s*[,)]/) }.map { |prop, _, line| [ prop, line ] }
  end

  # Problems with a stylesheet. Each is "file:line: what". In the token file, a
  # --color-* token may hold a six-digit hex value (and nothing else may hold a color).
  def violations(css, label, token_file: false, font_face: false)
    css = css.sub(FONT_FACE, "") if font_face # the one block; font_spec holds its exact shape
    out = []
    px_props = declarations(css).select { |p, v, _| p.start_with?("--") && v.match?(/\d\s*px/i) }.map(&:first)
    declarations(css).each do |prop, value, line|
      at = "#{label}:#{line}"
      color_token = token_file && prop.start_with?("--color-") && value.match?(/\A#[0-9a-f]{6}\z/i)
      # Quoted text is not a color. A var() keeps its fallback, which may be a color.
      plain = value.gsub(/"[^"]*"|'[^']*'/, "").gsub(/--[\w-]+/, "")
      words = plain.downcase.scan(/[a-z]+/)
      unless color_token
        out << "#{at}: hex color in #{prop}" if value.match?(HEX_COLOR)
        out << "#{at}: color function in #{prop}" if value.match?(COLOR_FUNCTION)
        out << "#{at}: named or system color in #{prop}" if (words & (NAMED_COLORS + SYSTEM_COLORS)).any? || plain.match?(VENDOR_COLOR)
      end
      out << "#{at}: banned #{prop}" if prop.match?(/\A(?:-\w+-)?(?:(?:backdrop-)?filter|mix-blend-mode)\z/)
      out << "#{at}: banned opacity" if prop == "opacity" && value != "1"
      font_prop = %w[font font-size].include?(prop) || prop.start_with?("--text-", "--font-")
      out << "#{at}: px font size in #{prop}" if font_prop && value.match?(/\d\s*px/i)
      if %w[font font-size].include?(prop) && (reads = value.scan(/var\(\s*(--[\w-]+)/).flatten & px_props).any?
        out << "#{at}: #{prop} reads a px custom property (#{reads.join(', ')})"
      end
      out << "#{at}: !important" if value.include?("!important")
    end
    out << "#{label}: @import" if css.include?("@import")
    out << "#{label}: @font-face" if css.include?("@font-face")
    out << "#{label}: url(" if css.match?(/url\(/i)
    out << "#{label}: color-mix" if css.include?("color-mix(")
    rules(css).each do |selector, body|
      next unless body.include?("var(--color-power-")
      next if selector.split(",").all? { |part| part.strip.match?(/\.(?:power-badge|unit-icon|supply-center-icon)--(?:austria|england|france|germany|italy|russia|turkey)\z/) }
      out << "#{label}: --color-power- used outside a power badge rule (#{selector})"
    end
    out
  end
end

module Contrast
  # The documented pairs (spec FR-3), other than the power pairs.
  # [foreground, background, minimum ratio]. Each pair appears once, with its
  # higher minimum where the spec lists two uses.
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
    light, dark = [ luminance(first), luminance(second) ].max, [ luminance(first), luminance(second) ].min
    (light + 0.05) / (dark + 0.05)
  end

  # Hue in degrees (HSL), from a hex color.
  def hue(hex)
    r, g, b = rgb(hex).map { |v| v / 255.0 }
    top, bottom = [ r, g, b ].max, [ r, g, b ].min
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
    [ d, 360 - d ].min
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

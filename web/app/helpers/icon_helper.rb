# The only way to draw a unit or a supply center, as power_badge is the only way to draw a
# badge (spec 020 FR-10). The drawings are copies of the master artwork in the repository's
# root icons folder, kept in app/assets/images/icons/ (the Docker build context is web/).
# Each part is named by an id in the artwork; the id becomes a class, so a page with many
# icons never repeats an id.
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
      <text class="unit-icon__tag-initial mono" x="26" y="28.8" text-anchor="middle" font-size="8"></text>
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
    tag = svg.add_child(TAG).first
    tag.at_xpath(".//*[local-name()='text']").content = name[0] # set as text, so a name is never read as markup
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
    # The artwork marks its white shapes with a generic class; give them one of this block, too.
    svg.xpath(".//*[@class='mark']").each { |mark| mark["class"] = "mark #{block}__mark" }
    svg
  end

  def svg_markup(svg)
    svg.to_xml(save_with: Nokogiri::XML::Node::SaveOptions::AS_XML).html_safe
  end
end

require "rails_helper"

RSpec.describe "Icons and the monospace in the browser", type: :system do
  powers = %w[austria england france germany italy russia turkey]

  def rgb(hex) = "rgb(#{hex.delete('#').scan(/../).map { |c| c.to_i(16) }.join(', ')})"

  # The value of a color token, as the stylesheet declares it, converted to the rgb() the browser reports.
  def token(name) = rgb(evaluate_script("getComputedStyle(document.documentElement).getPropertyValue('--color-#{name}')").strip)

  def paint(selector, property) = evaluate_script("getComputedStyle(document.querySelector(#{selector.to_json}))[#{property.to_json}]")

  # Every match, not the first: all the armies and fleets, at every size, must be painted the same way.
  # (An empty list would equal nothing, so a selector that finds no icon fails the example.)
  def paint_all(selector, property)
    evaluate_script("Array.from(document.querySelectorAll(#{selector.to_json})).map((el) => getComputedStyle(el)[#{property.to_json}])")
  end

  before { visit "/styleguide" }

  powers.each do |id|
    it "colors a #{id} unit from its power token (AC-7.7)" do
      # Six icons per power: the army and the fleet at 20, 32 and 48 pixels (small and full drawings).
      icon = ".sg-units .unit-icon--#{id}"
      expect(paint_all("#{icon} .unit-icon__silhouette", "fill")).to eq([ token("power-#{id}") ] * 6)
      expect(paint_all("#{icon} .mark", "fill").uniq).to eq([ rgb("#ffffff") ])
      expect(paint_all("#{icon} .unit-icon__tag-tile", "fill")).to eq([ token("surface") ] * 6)
      expect(paint_all("#{icon} .unit-icon__tag-tile", "stroke")).to eq([ token("power-#{id}") ] * 6)
      expect(paint_all("#{icon} .unit-icon__tag-initial", "fill")).to eq([ token("power-#{id}") ] * 6)
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

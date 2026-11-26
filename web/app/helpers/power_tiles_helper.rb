module PowerTilesHelper
  # Seven tiles. An open tile is a submit button named power, a taken tile is a plain div that says "Taken".
  # Each shows the power's badge, so its name is always text (spec AC-9.3). Names come through RulesEngine.
  def power_tiles(taken: [])
    items = RulesEngine.powers.map do |power|
      id = power.id.to_s
      if taken.include?(id)
        tag.li(tag.div(safe_join([ power_badge(id), tag.span("Taken") ]), class: "power-tile power-tile--taken"))
      else
        tag.li(tag.button(power_badge(id), type: "submit", name: "power", value: id, class: "power-tile"))
      end
    end
    tag.ul(safe_join(items), class: "power-tiles")
  end

  # A power's name as the rules engine reports it (spec FR-7).
  def power_name(id) = RulesEngine.powers.find { |power| power.id.to_s == id.to_s }&.name
end

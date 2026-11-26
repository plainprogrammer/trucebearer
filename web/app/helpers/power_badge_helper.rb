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
    tag.span(name, class: [ "power-badge", "power-badge--#{key}" ])
  end
end

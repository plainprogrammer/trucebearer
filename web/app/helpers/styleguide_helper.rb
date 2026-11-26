module StyleguideHelper
# The color tokens other than the power colors, in the order they are shown.
COLOR_TOKENS = %w[
  page surface ice ice-pale steel text text-muted border link link-visited primary primary-pressed on-primary
  danger danger-pressed on-danger focus disabled-text disabled-fill on-power
].freeze

# [foreground, background, minimum ratio] for the documented pairs other than the power pairs.
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

  TYPE_STEPS = %w[sm base lg xl 2xl].freeze
  SPACE_STEPS = (1..8).to_a.freeze
  POWER_IDS = PowerBadgeHelper::POWER_NAMES.keys.freeze
end

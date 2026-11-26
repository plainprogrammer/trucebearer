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
    [ "disabled-text", "disabled-fill", "3" ],
    [ "primary", "ice-pale", "3" ], [ "primary-pressed", "ice-pale", "3" ], [ "border", "ice-pale", "3" ],
    [ "danger", "ice-pale", "3" ], [ "danger-pressed", "ice-pale", "3" ], [ "focus", "ice-pale", "3" ],
    [ "link", "ice-pale", "4.5" ], [ "link-visited", "ice-pale", "4.5" ]
  ].freeze

  UNIT_SIZES = [ 20, 32, 48 ].freeze
  UNIT_TYPES = %w[army fleet].freeze
  TYPE_STEPS = %w[sm base lg xl 2xl].freeze
  SPACE_STEPS = (1..8).to_a.freeze
  POWER_IDS = PowerBadgeHelper::POWER_NAMES.keys.freeze

  # Stand-ins for the game and phase the order screen's partials build their links from (spec 023).
  SAMPLE_GAME = Struct.new(:public_id).new("sample").freeze
  SAMPLE_PHASE = Struct.new(:number).new(1).freeze

  # Made-up result groups for the style guide's Results section (spec 025 AC-8.1): a player group and a reading group between them
  # showing every tag. The partials take the presenter's own value types.
  def sample_result_groups
    order = ->(type, power, at, **rest) { { "format" => 1, "type" => type, "power" => power, "at" => at }.merge(rest.transform_keys(&:to_s)) }
    move = ->(power, at, to) { order.call("move", power, at, destination: { "province" => to, "coast" => nil }) }
    unit = ->(type) { PhaseResults::UnitRef.new(type: type) }
    row = lambda do |order_hash, type, result, submitted: true, dislodged: false|
      PhaseResults::Row.new(order: order_hash, power: order_hash["power"], province: order_hash["at"], unit: type && unit.call(type),
                            result: result, submitted: submitted, dislodged: dislodged)
    end
    player = PhaseResults::Group.new(power: "england", rows: [
      row.call(move.call("england", "lon", "nth"), :fleet, "succeeded"),
      row.call(move.call("england", "lvp", "yor"), :army, "bounced"),
      row.call(order.call("support_hold", "england", "edi", target: "lvp"), :fleet, "given"),
      row.call(order.call("hold", "england", "wal"), :army, "held", submitted: false)
    ])
    reading = PhaseResults::Group.new(power: "france", rows: [
      row.call(order.call("hold", "france", "par"), :army, "held", dislodged: true),
      row.call(order.call("convoy", "france", "bre", from: "par", to: "lon"), :fleet, "disrupted", dislodged: true),
      row.call(order.call("support_move", "france", "mar", from: "par", to: "bur"), :army, "cut"),
      row.call(order.call("move_via_convoy", "france", "gas", to: "nwy"), :army, "no_route"),
      row.call(order.call("convoy", "france", "mao", from: "bre", to: "spa"), :fleet, "unmatched"),
      row.call(move.call("france", "lon", "eng"), nil, "void")
    ])
    [ player, reading ]
  end
end

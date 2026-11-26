# What one unit can be told to do, as the picker's steps (spec 023 D1, D3, FR-2). Every choice is made from RulesEngine.legal_orders;
# the model reads each order's hash form and names no gem class. step(draft) says which page the draft leads to, or nil when it names
# no legal choice (the caller sends the player back to step 1).
class OrderChoices
  DRAFT_KEYS = %w[kind target to].freeze
  COAST_WORDS = { "nc" => "North coast", "sc" => "South coast", "ec" => "East coast" }.freeze

  Trail = Data.define(:words, :province)
  Choice = Data.define(:words, :province, :note, :draft, :save)
  Step = Data.define(:title, :trail, :choices, :back)

  # ordered: whether the seat has a saved order for this unit (it decides whether "No order (holds)" is offered).
  def initialize(position, unit, ordered:)
    @position = position
    @unit = unit
    @province = unit.location.province.to_s
    @ordered = ordered
    @orders = RulesEngine.legal_orders(position, unit).map { |order| [ order, order.to_h ] }
  end

  # draft: a Hash of Strings. Returns a Step, or nil.
  def step(draft)
    return action_step if draft.empty?
    return nil unless draft.keys.all? { |key| DRAFT_KEYS.include?(key) } && draft.values.all?(String)

    case draft["kind"]
    when "move" then move_step(draft)
    when "support" then support_step(draft)
    when "convoy" then convoy_step(draft)
    end
  end

  private

  def of_type(*types) = @orders.select { |_, h| types.include?(h["type"]) }

  def save_of(order) = JSON.generate(order.to_h)

  # A step with nothing to choose is no step (a kind the unit has no orders for).
  def build(title, trail, choices, back) = (Step.new(title, trail, choices, back) if choices.any?)

  def action_step
    hold = @orders.find { |_, h| h["type"] == "hold" }.first
    choices = [ Choice.new("Hold", nil, nil, nil, save_of(hold)) ]
    { "move" => %w[move move_via_convoy], "support" => %w[support_hold support_move], "convoy" => %w[convoy] }.each do |kind, types|
      choices << Choice.new(kind.capitalize, nil, nil, { "kind" => kind }, nil) if of_type(*types).any?
    end
    choices << Choice.new("No order (holds)", nil, nil, nil, "") if @ordered
    Step.new("What should it do?", [], choices, nil)
  end

  # ---- Move: moves grouped by destination province, in the order the gem lists them (D3)
  def destinations = of_type("move", "move_via_convoy").group_by { |_, h| h["type"] == "move" ? h["destination"]["province"] : h["to"] }

  def move_step(draft)
    case draft.keys.sort
    when %w[kind] then destinations_step
    when %w[kind to] then which_way_step(draft["to"])
    end
  end

  def destinations_step
    choices = destinations.map do |province, entries|
      if entries.one?
        order, h = entries.first
        Choice.new(nil, province, move_note(province, h), nil, save_of(order))
      else
        Choice.new(nil, province, nil, { "kind" => "move", "to" => province }, nil)
      end
    end
    build("Move where?", [ Trail.new("Move", nil) ], choices, {})
  end

  # "needs a convoy" for an army's plain move to a province it cannot walk to; the coast for a fleet's single-coast move.
  def move_note(province, hash)
    return COAST_WORDS.fetch(hash["destination"]["coast"]).downcase if hash["type"] == "move" && hash["destination"]["coast"]

    "needs a convoy" if @unit.type == :army && hash["type"] == "move" && !RulesEngine.army_adjacent?(@province, province)
  end

  def which_way_step(province)
    entries = destinations[province]
    return nil unless entries && entries.size > 1

    choices = entries.map do |order, h|
      words = if h["type"] == "move_via_convoy" then "By convoy"
      elsif h["destination"]["coast"] then "#{COAST_WORDS.fetch(h["destination"]["coast"])} (#{h["destination"]["coast"].upcase})"
      else "By land"
      end
      Choice.new(words, nil, nil, nil, save_of(order))
    end
    title = entries.any? { |_, h| h["type"] == "move_via_convoy" } ? "How does it get there?" : "Which coast?"
    build(title, [ Trail.new("Move to", province) ], choices, { "kind" => "move" })
  end

  # ---- Support: the supported unit, then "Hold in place" or a destination
  def supports = of_type("support_hold", "support_move")

  def supported_provinces = supports.map { |_, h| h["type"] == "support_hold" ? h["target"] : h["from"] }.uniq

  def support_step(draft)
    case draft.keys.sort
    when %w[kind] then build("Support which unit?", [ Trail.new("Support", nil) ], unit_choices("support", supported_provinces), {})
    when %w[kind target] then support_how_step(draft["target"])
    end
  end

  def support_how_step(target)
    return nil unless supported_provinces.include?(target)

    choices = supports.filter_map do |order, h|
      if h["type"] == "support_hold" && h["target"] == target then Choice.new("Hold in place", nil, nil, nil, save_of(order))
      elsif h["type"] == "support_move" && h["from"] == target then Choice.new("Move to", h["to"], nil, nil, save_of(order))
      end
    end
    build("Support it how?", [ Trail.new("Support", nil), unit_trail(target) ], choices, { "kind" => "support" })
  end

  # ---- Convoy: the army, then its destination
  def convoys = of_type("convoy")

  def convoyed_provinces = convoys.map { |_, h| h["from"] }.uniq

  def convoy_step(draft)
    case draft.keys.sort
    when %w[kind] then build("Convoy which army?", [ Trail.new("Convoy", nil) ], unit_choices("convoy", convoyed_provinces), {})
    when %w[kind target] then convoy_where_step(draft["target"])
    end
  end

  def convoy_where_step(target)
    return nil unless convoyed_provinces.include?(target)

    choices = convoys.filter_map { |order, h| Choice.new("To", h["to"], nil, nil, save_of(order)) if h["from"] == target }
    build("Convoy it where?", [ Trail.new("Convoy", nil), unit_trail(target) ], choices, { "kind" => "convoy" })
  end

  # ---- Units standing on the board: public, from the position
  def unit_at(province) = @position.units.find { |u| u.location.province.to_s == province }

  def unit_choices(kind, provinces)
    provinces.map do |province|
      unit = unit_at(province)
      Choice.new("#{unit.type.to_s.capitalize} in", province, power_name(unit.power), { "kind" => kind, "target" => province }, nil)
    end
  end

  def unit_trail(province) = Trail.new("#{unit_at(province).type.to_s.capitalize} in", province)

  def power_name(id) = RulesEngine.powers.find { |power| power.id.to_s == id.to_s }.name
end

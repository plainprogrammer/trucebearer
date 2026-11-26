require "rails_helper"
require_relative "../support/rules_helpers"

RSpec.describe OrderLabelHelper, type: :helper do
  include RulesHelpers

  it "words each of the six order types, naming provinces by abbreviation (spec 022 D5)" do
    {
      rules_order(:hold, :england, :lon) => "Hold",
      move(:england, :lon, :bel) => "Move to BEL",
      move(:france, :mao, :spa, :nc) => "Move to SPA (north coast)",
      move(:france, :mao, :spa, :sc) => "Move to SPA (south coast)",
      move(:russia, :bot, :stp, :sc) => "Move to STP (south coast)",
      rules_order(:move_via_convoy, :england, :lon, to: "bel") => "Move to BEL by convoy",
      rules_order(:support_hold, :germany, :mun, target: "ber") => "Support hold in BER",
      rules_order(:support_move, :germany, :mun, from: "bur", to: "mun") => "Support BUR to MUN",
      rules_order(:convoy, :england, :nth, from: "lon", to: "nwy") => "Convoy LON to NWY"
    }.each { |order, label| expect(helper.order_label(order)).to eq(label) }
  end
end

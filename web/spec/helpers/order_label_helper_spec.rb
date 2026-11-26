require "rails_helper"
require_relative "../support/rules_helpers"

RSpec.describe OrderLabelHelper, type: :helper do
  include RulesHelpers

  describe "province_label and order_words (spec 023 FR-3)" do
    let(:position) do
      rules_position(units: [ [ :england, :army, :lon ], [ :england, :fleet, :nth ], [ :france, :fleet, :mao ], [ :france, :army, :bre ] ])
    end

    def unit_at(province) = position.units.find { |u| u.location.province.to_s == province }

    def words(order, province) = Nokogiri::HTML5.fragment(helper.order_words(order, unit_at(province))).text

    it "writes a province as its full name with the abbreviation in the mono face" do
      html = helper.province_label("lvp")
      expect(html).to eq('Liverpool (<span class="mono">LVP</span>)')
      expect(html).to be_html_safe
    end

    it "reads orders in words, full names first" do
      expect(words(rules_order(:hold, :england, :lon), "lon")).to eq("Hold")
      expect(words(move(:england, :nth, :nwg), "nth")).to eq("Move to Norwegian Sea (NWG)")
      expect(words(move(:france, :mao, :spa, :nc), "mao")).to eq("Move to Spain (SPA), north coast")
      expect(words(rules_order(:move_via_convoy, :england, :lon, to: "yor"), "lon")).to eq("Move to Yorkshire (YOR) by convoy")
      expect(words(rules_order(:support_hold, :france, :bre, target: "mao"), "bre")).to eq("Support hold in Mid-Atlantic Ocean (MAO)")
      expect(words(rules_order(:support_move, :england, :lon, from: "nth", to: "yor"), "lon")).to eq("Support North Sea (NTH) to Yorkshire (YOR)")
      expect(words(rules_order(:convoy, :england, :nth, from: "lon", to: "nwy"), "nth")).to eq("Convoy London (LON) to Norway (NWY)")
    end

    it "marks only an army's plain move to a province it cannot walk to (AC-1.9)" do
      expect(words(move(:england, :lon, :nwy), "lon")).to eq("Move to Norway (NWY), needs a convoy")
      expect(words(move(:england, :lon, :yor), "lon")).to eq("Move to Yorkshire (YOR)")
      expect(words(move(:england, :nth, :nwy), "nth")).to eq("Move to Norway (NWY)") # a fleet
    end
  end
end

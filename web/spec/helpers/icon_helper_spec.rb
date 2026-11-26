require "rails_helper"

RSpec.describe IconHelper, type: :helper do
  powers = { "austria" => "Austria", "england" => "England", "france" => "France", "germany" => "Germany",
             "italy" => "Italy", "russia" => "Russia", "turkey" => "Turkey" }
  initials = { "austria" => "A", "england" => "E", "france" => "F", "germany" => "G",
               "italy" => "I", "russia" => "R", "turkey" => "T" }
  icons = File.expand_path("../../app/assets/images/icons", __dir__)

  def svg_of(html) = Nokogiri::HTML5.fragment(html).at_css("svg")
  def silhouette_path(file) = Nokogiri::XML(File.read(file)).at_css("#silhouette")["d"]

  describe "#unit_icon" do
    it "draws an army as an inline svg labelled with its type and power (AC-7.1)" do
      svg = svg_of(helper.unit_icon(:austria, :army))
      expect(svg).not_to be_nil
      expect(svg["role"]).to eq("img")
      expect(svg["aria-label"]).to eq("Army, Austria")
    end

    it "raises ArgumentError for a type that is not army or fleet (AC-7.3)" do
      expect { helper.unit_icon(:austria, :submarine) }.to raise_error(ArgumentError)
    end

    powers.each do |id, name|
      %w[army fleet].each do |type|
        it "labels #{type} of #{id} (AC-7.1)" do
          expect(svg_of(helper.unit_icon(id, type))["aria-label"]).to eq("#{type.capitalize}, #{name}")
        end
      end
    end

    it "is one inline svg with the stated attributes and parts (AC-7.1)" do
      html = helper.unit_icon(:austria, :army)
      svg = svg_of(html)
      expect(svg["viewBox"]).to eq("0 0 32 32")
      expect([ svg["width"], svg["height"] ]).to eq(%w[32 32])
      expect(svg["class"]).to eq("unit-icon unit-icon--austria")
      expect(svg.css("[id]")).to be_empty
      expect(svg.at_css("path.unit-icon__silhouette")).not_to be_nil
      expect(svg.at_css("g.unit-icon__marks .mark")).not_to be_nil
      expect(html).not_to match(/url\(|<style|<image|<script|<title|style=/i)
    end

    it "sets width and height from size (AC-7.1)" do
      svg = svg_of(helper.unit_icon(:italy, :fleet, size: 48))
      expect([ svg["width"], svg["height"] ]).to eq(%w[48 48])
    end

    it "accepts symbols and strings alike (AC-7.1)" do
      expect(helper.unit_icon(:england, :fleet)).to eq(helper.unit_icon("england", "fleet"))
    end

    it "is hidden from assistive technology when decorative (AC-7.2)" do
      svg = svg_of(helper.unit_icon(:austria, :army, decorative: true))
      expect(svg["aria-hidden"]).to eq("true")
      expect([ svg["role"], svg["aria-label"] ]).to eq([ nil, nil ])
    end

    it "raises ArgumentError for an unknown power, type or size, and renders nothing (AC-7.3)" do
      [ [ :wales, :army ], [ nil, :army ], [ "", :army ], [ :austria, :submarine ], [ :austria, nil ], [ :austria, "" ] ].each do |power, type|
        expect { helper.unit_icon(power, type) }.to raise_error(ArgumentError)
      end
      [ 0, -1, "32", 32.0, nil ].each do |size|
        expect { helper.unit_icon(:austria, :army, size: size) }.to raise_error(ArgumentError)
      end
    end

    it "uses the small drawing below 24 and the full one from 24 (AC-7.4)" do
      %w[army fleet].each do |type|
        small = silhouette_path(File.join(icons, "#{type}-small.svg"))
        full = silhouette_path(File.join(icons, "#{type}.svg"))
        expect(small).not_to eq(full)
        [ 20, 23 ].each { |s| expect(svg_of(helper.unit_icon(:austria, type, size: s)).at_css("path.unit-icon__silhouette")["d"]).to eq(small) }
        [ 24, 32, 48 ].each { |s| expect(svg_of(helper.unit_icon(:austria, type, size: s)).at_css("path.unit-icon__silhouette")["d"]).to eq(full) }
      end
    end

    initials.each do |id, initial|
      it "puts the initial #{initial} in the tag for #{id}, inside the bottom-right corner (AC-7.5)" do
        [ 20, 32 ].each do |size|
          svg = svg_of(helper.unit_icon(id, :army, size: size))
          tag = svg.at_css("g.unit-icon__tag")
          expect(tag["aria-hidden"]).to eq("true")
          tile = tag.at_css("rect.unit-icon__tag-tile")
          half = tile["stroke-width"].to_f / 2
          expect(tile["stroke-width"].to_f).to be >= 1.5
          # The stroked tile spans the corner exactly: outer edges at 20 and 32 on both axes.
          expect(tile["x"].to_f - half).to eq(20)
          expect(tile["y"].to_f - half).to eq(20)
          expect(tile["x"].to_f + tile["width"].to_f + half).to eq(32)
          expect(tile["y"].to_f + tile["height"].to_f + half).to eq(32)
          text = tag.at_css("text.unit-icon__tag-initial")
          expect(text.text).to eq(initial)
          expect(text["class"].split).to include("mono")
          expect(text["font-size"]).to eq("8")
        end
      end
    end
  end

  describe "#supply_center_icon" do
    it "labels an unowned center and uses the unowned class (AC-7.6)" do
      svg = svg_of(helper.supply_center_icon(nil))
      expect(svg["role"]).to eq("img")
      expect(svg["aria-label"]).to eq("Supply center, unowned")
      expect(svg["class"]).to eq("supply-center-icon supply-center-icon--unowned")
      expect([ svg["viewBox"], svg["width"], svg["height"] ]).to eq([ "0 0 32 32", "32", "32" ])
    end

    powers.each do |id, name|
      it "labels a center owned by #{id} (AC-7.6)" do
        svg = svg_of(helper.supply_center_icon(id))
        expect(svg["aria-label"]).to eq("Supply center, #{name}")
        expect(svg["class"]).to eq("supply-center-icon supply-center-icon--#{id}")
      end
    end

    it "has its parts as classes and no ids or url( (AC-7.1, 7.6)" do
      html = helper.supply_center_icon(:italy)
      svg = svg_of(html)
      expect(svg.css("[id]")).to be_empty
      %w[disk edge center].each { |part| expect(svg.at_css("path.supply-center-icon__#{part}")).not_to be_nil }
      expect(html).not_to match(/url\(|<style|<image|<script|<title|style=/i)
    end

    it "accepts a symbol or a string, and hides when decorative (AC-7.2, 7.6)" do
      expect(helper.supply_center_icon(:italy)).to eq(helper.supply_center_icon("italy"))
      svg = svg_of(helper.supply_center_icon(nil, decorative: true))
      expect(svg["aria-hidden"]).to eq("true")
      expect([ svg["role"], svg["aria-label"] ]).to eq([ nil, nil ])
    end

    it "raises ArgumentError for an unknown owner or a bad size, but not for nil (AC-7.3)" do
      [ "", :wales, "wales" ].each { |owner| expect { helper.supply_center_icon(owner) }.to raise_error(ArgumentError) }
      [ 0, -1, "32", 32.0, nil ].each { |size| expect { helper.supply_center_icon(:italy, size: size) }.to raise_error(ArgumentError) }
      expect { helper.supply_center_icon(nil) }.not_to raise_error
    end
  end
end

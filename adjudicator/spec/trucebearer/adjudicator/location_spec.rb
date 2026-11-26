# frozen_string_literal: true

require "json"
require "trucebearer/adjudicator"

RSpec.describe Trucebearer::Adjudicator::Location do
  TA = Trucebearer::Adjudicator unless defined?(TA)
  L = described_class unless defined?(L)

  describe ".new" do
    it "keeps the province and coast, and defaults the coast to nil" do
      location = L.new(province: :spa, coast: :nc)
      expect([location.province, location.coast]).to eq(%i[spa nc])
      expect(L.new(province: :bud).coast).to be_nil
    end

    it "is immutable, and equal to another location with the same contents" do
      expect(L.new(province: :spa, coast: :nc)).to be_frozen
      expect(L.new(province: :spa, coast: :nc)).to eq(L.new(province: :spa, coast: :nc))
      expect(L.new(province: :spa, coast: :nc).hash).to eq(L.new(province: :spa, coast: :nc).hash)
      expect(L.new(province: :spa, coast: :nc)).not_to eq(L.new(province: :spa, coast: :sc))
    end

    it "accepts a split-coast province with no coast" do
      expect(L.new(province: :spa).coast).to be_nil
    end

    it "rejects strings and other non-symbols, naming the value" do
      expect { L.new(province: "stp") }.to raise_error(TA::InvalidInput, /"stp"/)
      expect { L.new(province: :stp, coast: "sc") }.to raise_error(TA::InvalidInput, /"sc"/)
      expect { L.new(province: nil) }.to raise_error(TA::InvalidInput, /nil/)
      expect { L.new(province: 7) }.to raise_error(TA::InvalidInput, /7/)
    end

    it "rejects provinces and coasts that cannot exist, naming the value" do
      expect { L.new(province: :xyz) }.to raise_error(TA::InvalidInput, /:xyz/)
      expect { L.new(province: :spa, coast: :xx) }.to raise_error(TA::InvalidInput, /:xx/)
      expect { L.new(province: :par, coast: :nc) }.to raise_error(TA::InvalidInput, /:nc/)
      expect { L.new(province: :bul, coast: :nc) }.to raise_error(TA::InvalidInput, /:nc/)
      expect { L.new(province: :spa, coast: :ec) }.to raise_error(TA::InvalidInput, /:ec/)
    end
  end

  describe "#to_h" do
    it "gives string keys and string or nil values, with no format" do
      expect(L.new(province: :spa, coast: :nc).to_h).to eq("province" => "spa", "coast" => "nc")
      expect(L.new(province: :bud).to_h).to eq("province" => "bud", "coast" => nil)
    end
  end

  describe ".from_h" do
    let(:all_locations) do
      map = TA::Map.classic
      map.provinces.map { |p| L.new(province: p.id) } +
        map.provinces.flat_map { |p| p.coasts.map { |c| L.new(province: p.id, coast: c) } }
    end

    it "round-trips all 81 valid locations through JSON" do
      expect(all_locations.size).to eq(81)
      all_locations.each do |location|
        expect(L.from_h(JSON.parse(JSON.generate(location.to_h)))).to eq(location)
      end
    end

    it "rejects symbols where strings are required" do
      expect { L.from_h({ "province" => :stp, "coast" => nil }) }.to raise_error(TA::InvalidInput, /:stp/)
      expect { L.from_h({ "province" => "stp", "coast" => :sc }) }.to raise_error(TA::InvalidInput, /:sc/)
    end

    it "rejects a province that is nil or not a string" do
      expect { L.from_h({ "province" => nil, "coast" => nil }) }.to raise_error(TA::InvalidInput, /nil/)
      expect { L.from_h({ "province" => 7, "coast" => nil }) }.to raise_error(TA::InvalidInput, /7/)
    end

    it "rejects provinces and coasts that cannot exist" do
      # The caller passed strings, so the message shows the strings, in inspect form.
      expect { L.from_h({ "province" => "xyz", "coast" => nil }) }.to raise_error(TA::InvalidInput, /"xyz"/)
      expect { L.from_h({ "province" => "par", "coast" => "nc" }) }.to raise_error(TA::InvalidInput, /"nc"/)
      expect { L.from_h({ "province" => "spa", "coast" => "xx" }) }.to raise_error(TA::InvalidInput, /"xx"/)
      expect { L.from_h({ "province" => "bul", "coast" => "nc" }) }.to raise_error(TA::InvalidInput, /"nc"/)
      expect { L.from_h({ "province" => "spa", "coast" => "ec" }) }.to raise_error(TA::InvalidInput, /"ec"/)
    end

    it "rejects a missing key, an unknown key, symbol keys and a non-hash, naming the item" do
      expect { L.from_h({ "coast" => nil }) }.to raise_error(TA::InvalidInput, /"province"/)
      expect { L.from_h({ "province" => "spa" }) }.to raise_error(TA::InvalidInput, /"coast"/)
      expect { L.from_h({ "province" => "spa", "coast" => nil, "extra" => 1 }) }
        .to raise_error(TA::InvalidInput, /"extra"/)
      expect { L.from_h({ province: "spa", coast: nil }) }.to raise_error(TA::InvalidInput, /"province"/)
      expect { L.from_h("spa") }.to raise_error(TA::InvalidInput, /"spa"/)
    end
  end
end

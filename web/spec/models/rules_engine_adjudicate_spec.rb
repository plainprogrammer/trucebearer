require "rails_helper"
require_relative "../support/rules_helpers"

# Spec 029: RulesEngine.adjudicate and load_adjudication answer with the gem. It replaces the stand-in's spec.
RSpec.describe "RulesEngine.adjudicate and load_adjudication" do
  include RulesHelpers

  let(:start) { RulesEngine.starting_position }
  let(:result) { RulesEngine.adjudicate(start, [ move(:england, :lon, :nth) ]) }

  describe "load_adjudication (AC-2.3)" do
    it "returns an object as it is, builds one from its hash form, and passes nil" do
      expect(RulesEngine.load_adjudication(result)).to equal(result)
      expect(RulesEngine.load_adjudication(result.to_h)).to eq(result)
      expect(RulesEngine.load_adjudication(nil)).to be_nil
    end

    it "raises InvalidInput for what the gem refuses" do
      good = result.to_h
      void = RulesEngine.adjudicate(start, [ rules_order(:hold, :france, :lon) ]).to_h # England's London: a void order
      void["outcomes"].first["dislodged"] = true # a void order can't be dislodged: an impossible object
      bad = [ good.merge("format" => 2), good.except("format"), good.merge("extra" => 1), good.except("paradox"),
              good.merge("outcomes" => [ good["outcomes"].first.merge("result" => "bogus") ]), void, 42, "x", [] ]
      bad.each { |value| expect { RulesEngine.load_adjudication(value) }.to raise_error(RulesEngine::InvalidInput), value.inspect[0, 60] }
    end
  end

  describe "adjudicate (AC-2.4, AC-2.5)" do
    it "gives the documented result for a legal move" do
      expect(result.outcomes.first.result).to eq(:succeeded)
      expect(result.paradox).to be(false)
      expect(result.position.phase).to eq(:retreat)
    end

    it "raises InvalidInput for a position outside the movement phase, an argument of the wrong class, or two orders for one province" do
      retreat = rules_position(units: [ %i[england fleet lon] ], phase: "retreat")
      expect { RulesEngine.adjudicate(retreat, []) }.to raise_error(RulesEngine::InvalidInput)
      expect { RulesEngine.adjudicate(nil, []) }.to raise_error(RulesEngine::InvalidInput)
      expect { RulesEngine.adjudicate(start, nil) }.to raise_error(RulesEngine::InvalidInput)
      twice = [ rules_order(:hold, :england, :lon), move(:england, :lon, :nth) ]
      expect { RulesEngine.adjudicate(start, twice) }.to raise_error(RulesEngine::InvalidInput)
    end

    it "bounces both armies of a swap with no convoy (the stand-in let both succeed)" do
      swap = [ move(:austria, :vie, :bud), move(:austria, :bud, :vie) ]
      expect(RulesEngine.adjudicate(start, swap).outcomes.first(2).map(&:result)).to eq(%i[bounced bounced])
    end

    it "reports a support for a unit that moves, and a support for a move nobody makes, as unmatched" do
      orders = [ move(:austria, :bud, :ser), rules_order(:support_hold, :austria, :vie, target: "bud") ]
      expect(RulesEngine.adjudicate(start, orders).outcomes.map(&:result).first(2)).to eq(%i[succeeded unmatched])
      nobody = [ rules_order(:support_move, :austria, :vie, from: "bud", to: "gal") ]
      expect(RulesEngine.adjudicate(start, nobody).outcomes.first.result).to eq(:unmatched)
    end
  end
end

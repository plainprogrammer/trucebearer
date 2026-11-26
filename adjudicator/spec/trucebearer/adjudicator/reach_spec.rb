# frozen_string_literal: true

require "trucebearer/adjudicator"
require_relative "../../support/board"

# The internal helpers of FR-3. They are private to the gem, so the spec reaches
# them through const_get (AC-9.6).
RSpec.describe "TA::Reach (internal)" do
  let(:reach) { TA.const_get(:Reach) }
  let(:fleet) { ->(at) { Board.unit(:france, :fleet, at) } }
  let(:army) { ->(at) { Board.unit(:france, :army, at) } }

  it "is not reachable from outside the module (AC-9.6)" do
    expect { TA::Reach }.to raise_error(NameError, /private constant/)
    expect { TA::Check }.to raise_error(NameError)
  end

  describe "step_coasts and reaches?" do
    it "gives an army's step as [nil], by land only" do
      expect(reach.step_coasts(army.("par"), :bur)).to eq([nil])
      expect(reach.step_coasts(army.("par"), :spa)).to eq([])
      expect(reach.step_coasts(army.("lvp"), :iri)).to eq([])
      expect(reach.reaches?(army.("rom"), :ven)).to be(true)
    end

    it "judges a fleet from the coast it stands on, giving the coasts it can step to" do
      expect(reach.step_coasts(fleet.("mao"), :spa)).to eq(%i[nc sc])
      expect(reach.step_coasts(fleet.("gas"), :spa)).to eq([:nc])
      expect(reach.step_coasts(fleet.("gol"), :spa)).to eq([:sc])
      expect(reach.step_coasts(fleet.("spa/nc"), :gol)).to eq([])
      expect(reach.step_coasts(fleet.("spa/sc"), :gol)).to eq([nil])
      expect(reach.step_coasts(fleet.("lon"), :nth)).to eq([nil])
    end

    it "treats a province a fleet can't touch as unreachable" do
      expect(reach.reaches?(fleet.("rom"), :ven)).to be(false)
      expect(reach.reaches?(fleet.("kie"), :mun)).to be(false)
      expect(reach.reaches?(fleet.("lon"), :lon)).to be(false)
    end
  end

  describe "chain?" do
    let(:ln) { Board.position(Board.unit(:england, :army, "lon"), Board.unit(:england, :fleet, "nth")) }

    it "finds a chain of one fleet, whoever owns it" do
      expect(reach.chain?(ln, :lon, :nwy)).to be(true)
      foreign = Board.position(army.("lon"), Board.unit(:germany, :fleet, "nth"))
      expect(reach.chain?(foreign, :lon, :nwy)).to be(true)
    end

    it "finds a chain of two" do
      two = Board.position(army.("lon"), fleet.("eng"), fleet.("mao"))
      expect(reach.chain?(two, :lon, :por)).to be(true)
    end

    it "finds none without fleets, for the same province, or for inland ends" do
      expect(reach.chain?(Board.position(army.("lon")), :lon, :nwy)).to be(false)
      expect(reach.chain?(ln, :lon, :lon)).to be(false)
      expect(reach.chain?(ln, :lon, :hol)).to be(true)
      expect(reach.chain?(ln, :lon, :bur)).to be(false)
      expect(reach.chain?(ln, :bur, :nwy)).to be(false)
      expect(reach.chain?(ln, :lon, :nth)).to be(false)
    end

    it "ignores a fleet that is not at sea" do
      coastal = Board.position(army.("lon"), fleet.("wal"))
      expect(reach.chain?(coastal, :lon, :nwy)).to be(false)
    end

    it "can leave out the fleet in one province" do
      expect(reach.chain?(ln, :lon, :nwy, without: :nth)).to be(false)
      expect(reach.chain?(ln, :lon, :nwy, without: :eng)).to be(true)
    end

    it "links a set of seas the same way (linked?, used to decide whether a convoy route works)" do
      expect(reach.linked?(Set[:nth], :lon, :hol)).to be(true)
      expect(reach.linked?(Set[:eng], :lon, :hol)).to be(false)
      expect(reach.linked?(Set[:eng, :nth], :lon, :nwy)).to be(true)
      expect(reach.linked?(Set.new, :lon, :hol)).to be(false)
    end

    it "ignores coasts at both ends (6.B.18, 6.B.19)" do
      from_bulgaria = Board.position(army.("bul"), fleet.("bla"))
      expect(reach.chain?(from_bulgaria, :bul, :sev)).to be(true)
      to_spain = Board.position(army.("tus"), fleet.("gol"))
      expect(reach.chain?(to_spain, :tus, :spa)).to be(true)
    end
  end

  describe "on_minimal_chain?" do
    let(:c) do
      Board.position(army.("lon"), fleet.("nth"), fleet.("eng"), fleet.("wal"))
    end

    it "is true for the one fleet of a one-fleet chain" do
      expect(reach.on_minimal_chain?(c, :nth, :lon, :nwy)).to be(true)
    end

    it "is false for a fleet a one-fleet chain bypasses (the shape of 6.G.19)" do
      g19 = Board.position(army.("mar"), fleet.("wes"), Board.unit(:italy, :fleet, "gol"), Board.unit(:italy, :army, "spa"))
      expect(reach.on_minimal_chain?(g19, :gol, :mar, :spa)).to be(true)
      expect(reach.on_minimal_chain?(g19, :wes, :mar, :spa)).to be(false)
    end

    it "is false for a fleet that touches a chain fleet but neither end (the shape of 6.F.12)" do
      shape = Board.position(army.("lon"), fleet.("eng"), fleet.("iri"), fleet.("nth"))
      expect(reach.on_minimal_chain?(shape, :iri, :lon, :bel)).to be(false)
    end

    it "is true for both fleets of a chain of two whose ends each touch one" do
      two = Board.position(army.("lon"), fleet.("eng"), fleet.("mao"))
      expect(reach.on_minimal_chain?(two, :eng, :lon, :por)).to be(true)
      expect(reach.on_minimal_chain?(two, :mao, :lon, :por)).to be(true)
    end

    it "is false for a fleet whose two neighbors in the chain already border each other (a shortcut)" do
      shortcut = Board.position(army.("alb"), fleet.("ion"), fleet.("eas"), fleet.("aeg"))
      expect(reach.on_minimal_chain?(shortcut, :ion, :alb, :bul)).to be(true)
      expect(reach.on_minimal_chain?(shortcut, :eas, :alb, :bul)).to be(false)
      expect(reach.on_minimal_chain?(shortcut, :aeg, :alb, :bul)).to be(true)
    end

    it "judges each fleet by a chain of its own, not by the shortest chain overall" do
      longer = Board.position(army.("tus"), fleet.("tys"), fleet.("gol"), fleet.("wes"))
      %i[tys gol wes].each { |sea| expect(reach.on_minimal_chain?(longer, sea, :tus, :tun)).to be(true) }
    end

    it "is false for a coastal fleet, an empty sea, equal ends, or an end that is not coastal" do
      expect(reach.on_minimal_chain?(c, :wal, :lon, :nwy)).to be(false)
      expect(reach.on_minimal_chain?(c, :bal, :lon, :nwy)).to be(false)
      expect(reach.on_minimal_chain?(c, :nth, :lon, :lon)).to be(false)
      expect(reach.on_minimal_chain?(c, :nth, :lon, :bur)).to be(false)
      expect(reach.on_minimal_chain?(c, :nth, :iri, :nwy)).to be(false)
    end
  end
end

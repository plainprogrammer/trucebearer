require "rails_helper"

RSpec.describe Seat do
  let(:game) { Game.start!(power: "england").game }

  it "accepts each of the seven powers" do
    RulesEngine.powers.each do |power|
      expect(Seat.new(game: game, power: power.id.to_s, token_digest: Token.digest(power.id.to_s))).to be_valid
    end
  end

  it "refuses a power the rules engine does not report" do
    seat = Seat.new(game: game, power: "narnia", token_digest: Token.digest("x"))
    expect(seat).not_to be_valid
    expect(seat.errors).to include(:power)
  end
end

require "rails_helper"
require_relative "../support/results_fixtures"

# Spec 029 AC-4.1, AC-4.2: the dislodged banners and the paradox warning on real gem output, from two positions of the DATC
# (sections 6.D.9 and 6.F.14), written as data and revealed through the seats.
RSpec.describe "Real results (spec 029 D4)", type: :request do
  include ResultsFixtures

  around { |example| with_passphrase { example.run } }

  def page(session) = Nokogiri::HTML5(session.response.body)

  def tags(page, power, province) = page.css(".result-group[data-power=#{power}] .result-row[data-province=#{province}] .outcome-tag").map(&:text)

  describe "DATC 6.D.9: a dislodged holder and an unmatched support (AC-4.1)" do
    let(:created) { create_game(power: "italy") }
    let(:game) { created.game }
    let(:id) { game.public_id }
    before do
      reveal_position!(game, units: [ %i[italy army ven], %i[italy army tyr], %i[austria army alb], %i[austria army tri] ],
                             orders: [ [ :move, :italy, :ven, { destination: { "province" => "tri", "coast" => nil } } ],
                                       [ :support_move, :italy, :tyr, { from: "ven", to: "tri" } ],
                                       [ :support_move, :austria, :alb, { from: "tri", to: "ser" } ],
                                       [ :hold, :austria, :tri ] ])
    end

    it "gives the host one banner for the dislodged army, equal to the Dislodged tags, with no Held tag on its row" do
      created.session.get "/games/#{id}/host"
      host = page(created.session)

      expect(host.css("[data-dislodged]").map(&:text)).to eq([ "Warning: Austria's army in TRI was dislodged. Settle it by hand." ])
      expect(host.css("[data-dislodged]").size).to eq(host.css(".outcome-tag--dislodged").size)
      expect(host.css("[data-dislodged]").size).to eq(game.history.first.adjudication.position.dislodged_units.size)
      expect(tags(host, "austria", "tri")).to eq([ "Dislodged" ])
      expect(tags(host, "austria", "alb")).to eq([ "Not used" ])
    end

    it "shows a seat the same tags and no banner" do
      created.session.get "/games/#{id}"
      seat = page(created.session)

      expect(tags(seat, "austria", "tri")).to eq([ "Dislodged" ])
      expect(tags(seat, "austria", "alb")).to eq([ "Not used" ])
      expect(seat.css("[data-dislodged]")).to be_empty
    end
  end

  describe "DATC 6.F.14: the simplest convoy paradox (AC-4.2)" do
    let(:created) { create_game(power: "england") }
    let(:game) { created.game }
    let(:id) { game.public_id }
    before do
      reveal_position!(game, units: [ %i[england fleet lon], %i[england fleet wal], %i[france army bre], %i[france fleet eng] ],
                             orders: [ [ :support_move, :england, :lon, { from: "wal", to: "eng" } ],
                                       [ :move, :england, :wal, { destination: { "province" => "eng", "coast" => nil } } ],
                                       [ :move, :france, :bre, { destination: { "province" => "lon", "coast" => nil } } ],
                                       [ :convoy, :france, :eng, { from: "bre", to: "lon" } ] ])
    end

    it "completes the reveal, opens the next phase, and shows one paradox warning on the host page and the seat page" do
      expect(game.history.first.adjudication.to_h["paradox"]).to be(true)
      expect(game.current_phase.number).to eq(2)
      [ "/games/#{id}/host", "/games/#{id}" ].each do |path|
        created.session.get path
        expect(page(created.session).css("section[data-results] [data-paradox]").size).to eq(1), path
      end
    end
  end
end

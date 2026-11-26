require "rails_helper"

# Spec 027 Story 1: the host adds an army, and an impossible unit is refused in plain words.
RSpec.describe "The position editor", type: :request do
  around { |example| with_passphrase { example.run } }

  let!(:created) { create_game(power: "england") }
  let(:game) { created.game }
  let(:host) { created.session }
  let(:base) { "/games/#{game.public_id}/host/phases/1/position" }

  def add(power: "france", type: "army", province: "bur", coast: "")
    host.post "#{base}/units", params: { unit: { power: power, type: type, province: province, coast: coast } }
  end

  def units = game.reload.current_phase.position.units.map { |u| [ u.power.to_s, u.type.to_s, u.location.province.to_s ] }

  it "adds an army in Burgundy to France, and refuses a fleet there in plain words (AC-1.1, AC-1.2)" do
    add

    expect(host.response).to have_http_status(:see_other)
    expect(host.response.location).to end_with(base)
    expect(units).to include([ "france", "army", "bur" ])

    before = game.reload.current_phase.position
    add(type: "fleet")

    expect(host.response).to have_http_status(:unprocessable_content)
    expect(Nokogiri::HTML5(host.response.body).at_css(".banner--danger").text).to include("A fleet can't stand in Burgundy: it is inland.")
    expect(game.reload.current_phase.position).to eq(before)
  end
end

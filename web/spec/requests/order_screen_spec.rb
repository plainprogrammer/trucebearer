require "rails_helper"
require_relative "../support/rules_helpers"

# Spec 023 Story 1 and 4 over HTTP: the order screen. England starts with a fleet in EDI, a fleet in LON and an army in LVP.
RSpec.describe "The order screen", type: :request do
  include RulesHelpers

  around { |example| with_passphrase { example.run } }

  let(:created) { create_game(power: "england") }
  let(:game) { created.game }
  let(:id) { game.public_id }
  let(:england) { game.seats.find_by(power: "england") }
  let(:phase) { game.current_phase }
  let(:phone) { created.session }
  let(:path) { "/games/#{id}/phases/1/orders" }

  def page = Nokogiri::HTML5(phone.response.body)

  # The unit icon's tag holds the power's initial as text, so rows are read from their body.
  def rows = page.css(".unit-row__body").map { |row| row.text.squish }

  it "lists England's three units with 'holds', and the submit bar says '0 of 3 ordered' (AC-1.1)" do
    phone.get path

    expect(phone.response).to have_http_status(:ok)
    expect(rows).to eq([ "Fleet in Edinburgh (EDI) holds", "Fleet in London (LON) holds", "Army in Liverpool (LVP) holds" ])
    expect(page.at_css(".app-actions .submit-bar").text.squish).to include("0 of 3 ordered")
    expect(page.at_css(".save-status__rest").text).to eq("Saved")
  end

  it "reads a stored order in words, counts a hold, and links each row to its step 1 (AC-1.2, AC-1.3, AC-1.4)" do
    england.save_orders!(phase, { "lon" => json_of(move(:england, :lon, :nth)), "lvp" => json_of(rules_order(:hold, :england, :lvp)) })
    phone.get path

    expect(rows).to eq([ "Fleet in Edinburgh (EDI) holds", "Fleet in London (LON) Move to North Sea (NTH)", "Army in Liverpool (LVP) Hold" ])
    expect(page.at_css(".app-actions .submit-bar").text.squish).to include("2 of 3 ordered")
    expect(page.css("a.unit-row").map { |a| a["href"] }).to eq(%w[edi lon lvp].map { |p| "#{path}/#{p}" })
    expect(page.css("select, option")).to be_empty # AC-1.6
    expect(page.text).not_to include("units ordered")
  end

  it "says Not submitted with the Submit button, then Submitted without it, and a changed order brings the button back (AC-4.1 to AC-4.4)" do
    phone.get path
    expect(page.at_css(".submit-bar__state").text).to eq("Not submitted")
    phone.put path, params: { submit: "1" } # 0 orders may submit
    phone.follow_redirect!
    expect(page.css(".banner--info").map(&:text)).to eq([ "Submitted." ])
    expect(page.at_css(".submit-bar__state").text).to eq("Submitted · 0 of 3 ordered")
    expect(page.at_css(".submit-bar button")).to be_nil
    expect(page.at_css(".submit-bar a").text).to eq("Back to your seat")

    phone.put path, params: { orders: { "lon" => json_of(move(:england, :lon, :nth)) } } # a change un-submits (spec 022 AC-3.2)
    phone.follow_redirect!
    expect(page.at_css(".submit-bar__state").text).to eq("Not submitted")
    expect(page.at_css(".submit-bar button").text.squish).to eq("Submit orders 1 of 3 ordered")
    expect(page.css(".banner")).to be_empty # no "Orders saved." banner (D4)
  end

  it "reads Not saved on the answer to a refused save, and stays on the screen (AC-1.8, AC-3.2, AC-4.5)" do
    phone.put path, params: { orders: { "lon" => json_of(move(:england, :lon, :bel)) } }

    expect(phone.response).to have_http_status(:unprocessable_content)
    expect(page.at_css(".save-status__rest").text).to eq("Not saved")
    expect(page.css(".banner--danger").size).to eq(1)
    expect(page.css(".unit-row").size).to eq(3)
  end

  it "reads plainly for a fleet's move and an army's walkable move, and marks a convoy-only one (AC-1.9)" do
    game.current_phase.update_columns(position: rules_position(units: [ [ :england, :army, :lon ], [ :england, :fleet, :nth ] ]))
    england.save_orders!(phase.reload, { "lon" => json_of(move(:england, :lon, :nwy)), "nth" => json_of(move(:england, :nth, :nwy)) })
    phone.get path

    expect(rows).to eq([ "Army in London (LON) Move to Norway (NWY), needs a convoy", "Fleet in North Sea (NTH) Move to Norway (NWY)" ])
  end

  it "answers a stranger, a host cookie only, and another game's seat with the stranger response (AC-1.7)" do
    host_only = open_session.tap { |session| session.get "/games/#{id}/host-link", params: { token: created.host_token } }
    sessions = { "no cookie" => open_session, "the host cookie only" => host_only, "another game's seat" => create_game.session }
    sessions.each do |name, session|
      session.get path
      expect(session.response).to have_http_status(:not_found), name
    end
  end

  it "walks one order from the list with only the page's own links and forms, no script needed (AC-3.5)" do
    phone.get path
    phone.get page.at_css("a.unit-row[href$='/lon']")["href"]
    phone.get page.css(".picker a.list__row").find { |a| a.text.squish == "Move" }["href"]
    form = page.css(".picker form").find { |f| f.text.include?("North Sea") }
    fields = form.css("input").to_h { |input| [ input["name"], input["value"] ] }
    phone.post form["action"], params: fields # the form's own fields, _method and token included, as a browser would send them
    expect(phone.response).to have_http_status(:see_other)
    phone.follow_redirect!
    expect(rows[1]).to eq("Fleet in London (LON) Move to North Sea (NTH)")
  end

  it "carries the phase header with the power badge and the no-store headers (AC-1.5)" do
    phone.get path
    expect(page.at_css(".phase-header .power-badge--england")).to be_present
    expect(phone.response.headers["Cache-Control"]).to include("no-store")
    expect(page.at_css("meta[name='turbo-cache-control'][content='no-cache']")).to be_present
  end
end

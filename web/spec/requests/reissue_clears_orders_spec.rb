require "rails_helper"
require_relative "../support/rules_helpers"

# Spec 022 D9: reissuing a seat also deletes that seat's saved orders and submission for the open phase, so the host cannot
# read them by opening the new seat link on its own phone.
RSpec.describe "Reissuing a seat", type: :request do
  include RulesHelpers

  around { |example| with_passphrase { example.run } }

  let(:created) { create_game(power: "germany") } # the host holds Germany
  let(:game) { created.game }
  let(:id) { game.public_id }
  let(:england) { game.take_seat!("england").first }
  let(:france) { game.take_seat!("france").first }
  let(:phase) { game.current_phase }

  def hold(power, at) = json_of(rules_order(:hold, power, at))

  # The host reissues, then a new phone scans the code. Returns that phone, signed in as the seat.
  def reissue_and_take_over(power)
    created.session.post "/games/#{id}/host/seats/#{power}/reissue"
    created.session.follow_redirect!
    link = Nokogiri::HTML5(created.session.response.body).at_css(".qr-card__link").text
    phone = open_session
    phone.get link.delete_prefix("http://www.example.com")
    phone.follow_redirect!
    phone
  end

  it "deletes the seat's orders and submission for the open phase, and no other seat's (AC-7.10)" do
    england.save_orders!(phase, { "lon" => hold(:england, :lon) }, submit: true)
    france.save_orders!(phase, { "par" => hold(:france, :par) }, submit: true)

    created.session.post "/games/#{id}/host/seats/england/reissue"

    expect(SavedOrder.where(seat_id: england.id)).to be_empty
    expect(Submission.where(seat_id: england.id)).to be_empty
    expect(france.orders_for(phase).keys).to eq([ "par" ])
    expect(france.submitted?(phase)).to be(true)
  end

  it "leaves the new phone with an empty orders page that says not submitted" do
    england.save_orders!(phase, { "lon" => hold(:england, :lon) }, submit: true)

    phone = reissue_and_take_over("england")
    phone.get "/games/#{id}/phases/1/orders"

    page = Nokogiri::HTML5(phone.response.body)
    expect(phone.response).to have_http_status(:ok)
    expect(page.css("select").map { |select| select.at_css("option[selected]") }).to all(be_nil)
    expect(page.text).to include("Not submitted")
    expect(page.text).to include("0 of 3 units ordered")
  end

  it "shuts the hole: the host reading the new seat sees none of the old orders (AC-7.10)" do
    england.save_orders!(phase, { "lon" => json_of(move(:england, :lon, :nth)) })

    phone = reissue_and_take_over("england")
    phone.get "/games/#{id}/phases/1/orders"

    expect(Nokogiri::HTML5(phone.response.body).css("option[selected]")).to be_empty
  end

  it "does not touch the orders and submissions of a revealed phase" do
    england.save_orders!(phase, { "lon" => hold(:england, :lon) }, submit: true)
    first = phase
    first.update_columns(adjudication: RulesEngine.adjudicate(RulesEngine.starting_position, []), revealed_at: Time.current)
    second = game.phases.create!(number: 2, position: RulesEngine.starting_position)
    england.save_orders!(second, { "edi" => hold(:england, :edi) }, submit: true)

    created.session.post "/games/#{id}/host/seats/england/reissue"

    expect(SavedOrder.where(phase_id: first.id, seat_id: england.id).count).to eq(1)
    expect(Submission.where(phase_id: first.id, seat_id: england.id).count).to eq(1)
    expect(SavedOrder.where(phase_id: second.id, seat_id: england.id)).to be_empty
    expect(Submission.where(phase_id: second.id, seat_id: england.id)).to be_empty
  end

  it "makes a save from the old phone refuse, even one that authenticated before the reissue (D9)" do
    stale = Seat.find(england.id)
    created.session.post "/games/#{id}/host/seats/england/reissue"

    expect { stale.save_orders!(phase, { "lon" => hold(:england, :lon) }) }.to raise_error(Seat::Stale)
    expect(SavedOrder.count).to eq(0)
  end

  it "gives a phone the stranger page and deletes its dead cookie when it was reissued while its save was running" do
    phone = open_session
    phone.get "/games/#{id}/seat-link", params: { token: game.take_seat!("italy").last }
    italy = game.seats.find_by(power: "italy")
    # The reissue lands after the request was authenticated and before its save took the lock.
    allow_any_instance_of(Seat).to receive(:save_orders!) do |seat, *|
      Seat.where(id: seat.id).update_all(token_digest: Token.digest(Token.generate))
      raise Seat::Stale
    end

    phone.put "/games/#{id}/phases/1/orders", params: { orders: { "nap" => json_of(rules_order(:hold, :italy, :nap)) } }

    expect(phone.response).to have_http_status(:not_found)
    expect(phone.response.body).to include("We can't find that page.")
    expect(cookie_line(phone.response, "seat_#{id}")).to match(/seat_#{id}=;|max-age=0|expires=Thu, 01 Jan 1970/i)
    expect(SavedOrder.where(seat_id: italy.id)).to be_empty
  end

  it "says on the confirmation page that the seat's saved orders are deleted with it (AC-7.11)" do
    england

    created.session.get "/games/#{id}/host/seats/england/reissue"

    page = Nokogiri::HTML5(created.session.response.body)
    expect(page.at_css(".confirm")).to be_present
    expect(page.at_css(".confirm button.button--danger").text).to eq("Reissue seat")
    expect(page.text).to include("The seat's saved orders for this phase are deleted with it.")
  end
end

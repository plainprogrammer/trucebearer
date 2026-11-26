require "rails_helper"
require_relative "../support/rules_helpers"

RSpec.describe "The picker steps", type: :request do
  include RulesHelpers
  around { |example| with_passphrase { example.run } }

  let(:created) { create_game(power: "england") }
  let(:id) { created.game.public_id }
  let(:phone) { created.session }
  let(:base) { "/games/#{id}/phases/1/orders" }
  def page = Nokogiri::HTML5(phone.response.body)
  def choices = page.css(".picker .list li")

  it "offers Hold, Move and Support to the army in Liverpool, and no Convoy; the draft names the unit (AC-2.1, AC-2.14)" do
    phone.get "#{base}/lvp"
    expect(phone.response).to have_http_status(:ok)
    expect(choices.map { |li| li.text.squish }).to eq(%w[Hold Move Support])
    expect(page.at_css(".picker__draft").text.squish).to include("Army in Liverpool (LVP)")
    expect(page.at_css(".app-actions a").text).to eq("Back")
  end

  it "saves a hold with the form's own fields, one PUT, then lands on the screen (AC-2.2, AC-3.1)" do
    phone.get "#{base}/lvp"
    form = choices.first.at_css("form")
    expect(form["action"]).to eq(base)
    phone.put form["action"], params: { orders: { "lvp" => form.at_css("input[name='orders[lvp]']")["value"] } }
    expect(phone.response).to have_http_status(:see_other)
    expect(created.game.seats.find_by(power: "england").orders_for(created.game.current_phase).keys).to eq([ "lvp" ])
    phone.follow_redirect!
    expect(page.css(".unit-row__body").last.text.squish).to eq("Army in Liverpool (LVP) Hold")
    expect(page.at_css(".submit-bar").text.squish).to include("1 of 3 ordered")
  end

  it "clears a saved order with the picker's own No order button, and a submitted seat goes back to Not submitted (AC-2.3, AC-4.3)" do
    england = created.game.seats.find_by(power: "england")
    england.save_orders!(created.game.current_phase, { "lvp" => json_of(rules_order(:hold, :england, :lvp)) }, submit: true)
    phone.get "#{base}/lvp"
    expect(choices.map { |li| li.text.squish }).to eq([ "Hold", "Move", "Support", "No order (holds)" ])
    form = choices.last.at_css("form")
    expect(form.at_css("input[name='orders[lvp]']")["value"]).to eq("")
    phone.post form["action"], params: form.css("input").to_h { |input| [ input["name"], input["value"] ] }
    expect(phone.response).to have_http_status(:see_other)
    phone.follow_redirect!
    expect(page.css(".unit-row__order").map { |row| row.text.squish }).to eq(%w[holds holds holds])
    expect(page.at_css(".submit-bar__state").text).to eq("Not submitted")
    expect(england.orders_for(created.game.current_phase.reload)).to be_empty
  end

  # AC-2.10 over real pages: follow the page's own links, read the forms' fields, compare to the gem's legal orders.
  def crawl(path, province, found = [])
    phone.get path
    expect(phone.response).to have_http_status(:ok), path
    choices.each do |li|
      if (form = li.at_css("form"))
        found << form.at_css("input[name='orders[#{province}]']")["value"]
      else
        crawl(li.at_css("a")["href"], province, found)
      end
    end
    found
  end

  it "reaches exactly the legal orders of England's three units through the page's own links and forms (AC-2.10, AC-3.5)" do
    position = created.game.current_phase.position
    position.units.select { |u| u.power == :england }.each do |unit|
      province = unit.location.province.to_s
      legal = RulesEngine.legal_orders(position, unit).map { |order| JSON.generate(order.to_h) }
      expect(crawl("#{base}/#{province}", province).reject(&:empty?)).to match_array(legal), province
    end
  end

  it "has no script, handler or data-action in any step, and no new import-map pin (AC-3.5)" do
    phone.get "#{base}/lvp?draft%5Bkind%5D=move"
    body = page.at_css("body")
    expect(body.css("script")).to be_empty
    expect(phone.response.body).not_to match(/\sonclick=|\sonsubmit=|data-action=/)
    expect(Rails.application.importmap.packages.keys).to match_array(%w[application @hotwired/turbo-rails @hotwired/stimulus @hotwired/stimulus-loading])
  end

  it "sends a draft that names no legal choice, or a whole order, back to step 1 and echoes nothing (AC-2.11)" do
    [ "draft%5Bkind%5D=teleport", "draft%5Bkind%5D=move&draft%5Bto%5D=xyz", "draft%5Bkind%5D=support&draft%5Btarget%5D=zzz",
      "draft%5Bkind%5D=convoy", "draft%5Bbad%5D=1", "draft=text", "draft%5B%5D=a", "draft%5Bkind%5D%5B%5D=move" ].each do |query|
      phone.get "#{base}/lvp?#{query}"
      expect(phone.response).to have_http_status(:see_other), query
      expect(phone.response.location).to end_with("#{base}/lvp")
      %w[xyz teleport zzz text].each { |echoed| expect(phone.response.body).not_to include(echoed), "#{query} echoed #{echoed}" }
    end
  end

  it "gives the stranger response for a province that is not the seat's unit and for a phase that is not reachable (AC-2.12, AC-2.13)" do
    [ "par", "xyz", "LVP" ].each do |province|
      phone.get "#{base}/#{province}"
      expect(phone.response).to have_http_status(:not_found), province
    end
    phone.get "/games/#{id}/phases/2/orders/lvp"
    expect(phone.response).to have_http_status(:not_found)
    expect(SavedOrder.count).to eq(0)
  end

  it "gives the 409 page for a revealed phase (AC-2.13)" do
    created.session.post "/games/#{id}/host/phases/1/reveal"
    phone.get "#{base}/lvp"
    expect(phone.response).to have_http_status(:conflict)
  end

  it "carries no-store, the Turbo no-cache meta and no-referrer (AC-2.15, AC-3.7)" do
    phone.get "#{base}/lvp"
    expect(phone.response.headers["Cache-Control"]).to include("no-store")
    expect(phone.response.headers["Referrer-Policy"]).to eq("no-referrer")
    expect(page.at_css("meta[name='turbo-cache-control'][content='no-cache']")).to be_present
    expect(page.css("a[href]").map { |a| a["href"] }).to all(start_with("/")) # no link off the app
  end

  it "keeps a draft out of the logged request line, percent-encoded brackets included (AC-3.7)" do
    env = Rack::MockRequest.env_for("/x?draft%5Bto%5D=bel&draft%5Bkind%5D=move")
    request = ActionDispatch::Request.new(Rails.application.env_config.merge(env))
    expect(request.filtered_path).not_to include("bel")
    expect(request.filtered_path).not_to include("move")
  end
end

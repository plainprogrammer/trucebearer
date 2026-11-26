require "rails_helper"
require_relative "../support/rules_helpers"

# Spec 027 Stories 1 to 4 and 7: the host's position editor, at the request level.
RSpec.describe "The position editor", type: :request do
  include RulesHelpers

  around { |example| with_passphrase { example.run } }

  let!(:created) { create_game(power: "england") }
  let(:game) { created.game }
  let(:id) { game.public_id }
  let(:host) { created.session }
  let(:base) { "/games/#{id}/host/phases/1/position" }

  def add(power: "france", type: "army", province: "bur", coast: "", session: host)
    session.post "#{base}/units", params: { unit: { power: power, type: type, province: province, coast: coast } }
  end

  def position = game.reload.current_phase.position
  def units = position.units.map { |u| [ u.power.to_s, u.type.to_s, u.location.province.to_s ] }
  def page(session = host) = Nokogiri::HTML5(session.response.body)
  def banner(kind, session = host) = page(session).at_css(".banner--#{kind}")&.text.to_s.squish

  # ---- Story 1: the first test ----
  it "adds an army in Burgundy to France, and refuses a fleet there in plain words (AC-1.1, AC-1.2)" do
    add

    expect(host.response).to have_http_status(:see_other)
    expect(host.response.location).to end_with(base)
    expect(units).to include([ "france", "army", "bur" ])

    before = position
    add(type: "fleet")

    expect(host.response).to have_http_status(:unprocessable_content)
    expect(banner(:danger)).to include("A fleet can't stand in Burgundy: it is inland.")
    expect(position).to eq(before)
  end

  describe "the add form (AC-1.3)" do
    it "has the fields, a segmented army or fleet with army selected, and no script" do
      host.get "#{base}/units/new"

      expect(host.response).to have_http_status(:ok)
      doc = page
      expect(doc.css("select[name='unit[power]'] option").size).to eq(8) # a prompt and the seven powers
      expect(doc.css("select[name='unit[province]'] option").size).to eq(76)
      expect(doc.css("select[name='unit[coast]'] option").map { |o| o["value"] }).to eq([ "", "ec", "nc", "sc" ])
      expect(doc.css("fieldset.segmented input[type=radio][name='unit[type]']").map { |r| [ r["value"], r["checked"] ] }).to eq([ [ "army", "checked" ], [ "fleet", nil ] ])
      expect(doc.css("select, input:not([type=hidden]):not([type=radio])").all? { |field| doc.at_css("label[for='#{field['id']}']") }).to be(true)
      expect(doc.css("main [data-controller], main [onclick], main [data-action]")).to be_empty # no page-specific script
      expect(doc.css("form").first["action"]).to eq("#{base}/units")
    end
  end

  describe "adding a unit (Story 1)" do
    it "stores a fleet on a chosen coast (AC-1.4)" do
      add(power: "france", type: "fleet", province: "spa", coast: "sc")

      unit = position.units.find { |u| u.location.province == :spa }
      expect([ unit.type, unit.location.coast ]).to eq(%i[fleet sc])
    end

    it "refuses a fleet with no coast where one is needed (AC-1.4)" do
      add(type: "fleet", province: "spa")

      expect(host.response).to have_http_status(:unprocessable_content)
      expect(banner(:danger)).to include("A fleet in Spain must say which coast it is on.")
    end

    it "refuses an army with a coast, and a coast the province doesn't have (AC-1.5)" do
      add(province: "spa", coast: "nc")
      expect(banner(:danger)).to include("An army doesn't stand on a coast. Leave the coast blank.")

      add(province: "par", coast: "nc")
      expect(banner(:danger)).to include("Paris has no north coast.")
      add(type: "fleet", province: "par", coast: "nc")
      expect(banner(:danger)).to include("Paris has no north coast.")
    end

    it "refuses an occupied province (AC-1.6)" do
      before = position
      add(province: "par")

      expect(host.response).to have_http_status(:unprocessable_content)
      expect(banner(:danger)).to include("Paris already holds a unit. A province holds one unit.")
      expect(position).to eq(before)
    end

    it "refuses an army at sea (AC-1.7)" do
      add(province: "nth")

      expect(banner(:danger)).to include("An army can't stand in North Sea: it is a sea province.")
    end

    it "puts the earlier stage first when two rules break (AC-1.9)" do
      add(type: "fleet", province: "par", coast: "nc")

      expect(banner(:danger)).to include("Paris has no north coast.")
      expect(banner(:danger)).not_to include("already holds")
    end

    it "keeps what the host picked on the refused form" do
      add(power: "italy", type: "fleet", province: "mun")

      doc = page
      expect(doc.at_css("select[name='unit[power]'] option[selected]")["value"]).to eq("italy")
      expect(doc.at_css("select[name='unit[province]'] option[selected]")["value"]).to eq("mun")
      expect(doc.at_css("input[name='unit[type]'][value=fleet]")["checked"]).to eq("checked")
    end

    it "answers a bad or odd field with a Choose sentence, never a 500 (AC-1.8)" do
      cases = {
        { power: "", type: "army", province: "bur", coast: "" } => "Choose a power.",
        { power: "narnia", type: "army", province: "bur", coast: "" } => "Choose a power.",
        { power: "france", type: "tank", province: "bur", coast: "" } => "Choose army or fleet.",
        { power: "france", type: "army", province: "xyz", coast: "" } => "Choose a province.",
        { power: "france", type: "army", province: "", coast: "" } => "Choose a province.",
        { power: "france", type: "army", province: "bur", coast: "west" } => "Choose a coast.",
        { power: [ "france" ], type: "army", province: "bur", coast: "" } => "Choose a power.",
        { power: { a: "b" }, type: "army", province: "bur", coast: "" } => "Choose a power."
      }
      before = position
      cases.each do |fields, sentence|
        host.post "#{base}/units", params: { unit: fields }

        expect(host.response).to have_http_status(:unprocessable_content), fields.inspect
        expect(banner(:danger)).to include(sentence), fields.inspect
      end
      host.post "#{base}/units", params: { unit: "france" }
      expect(host.response).to have_http_status(:unprocessable_content)
      host.post "#{base}/units"
      expect(host.response).to have_http_status(:unprocessable_content)
      expect(position).to eq(before)
    end
  end

  # ---- Story 2: moving and removing ----
  describe "a unit's page" do
    it "shows a move form and a remove button (AC-2.1)" do
      host.get "#{base}/units/lon"

      expect(host.response).to have_http_status(:ok)
      doc = page
      expect(doc.at_css("form[action='#{base}/units/lon'] input[name=_method][value=patch]")).to be_present
      expect(doc.at_css("form[action='#{base}/units/lon'] input[name=_method][value=delete]")).to be_present
    end

    it "moves a unit to a free province, keeping its power and type (AC-2.1)" do
      host.patch "#{base}/units/lon", params: { unit: { province: "nth", coast: "" } }

      expect(host.response).to have_http_status(:see_other)
      expect(units).to include([ "england", "fleet", "nth" ])
      expect(units).not_to include([ "england", "fleet", "lon" ])
    end

    it "refuses a move to an occupied province, to a province that can't hold the type, and with a wrong coast (AC-2.2)" do
      before = position
      host.patch "#{base}/units/lon", params: { unit: { province: "edi", coast: "" } }
      expect(banner(:danger)).to include("Edinburgh already holds a unit.")
      host.patch "#{base}/units/lon", params: { unit: { province: "mun", coast: "" } }
      expect(banner(:danger)).to include("A fleet can't stand in Munich: it is inland.")
      host.patch "#{base}/units/lon", params: { unit: { province: "nth", coast: "nc" } }
      expect(banner(:danger)).to include("North Sea has no north coast.")

      expect(position).to eq(before)
    end

    it "moves a fleet between a province's coasts, and refuses a move to where it is (AC-2.3)" do
      add(type: "fleet", province: "spa", coast: "nc")
      host.patch "#{base}/units/spa", params: { unit: { province: "spa", coast: "sc" } }

      expect(host.response).to have_http_status(:see_other)
      expect(position.units.find { |u| u.location.province == :spa }.location.coast).to eq(:sc)
      expect(game.position_edit_history.last.detail).to include("from_coast" => "nc", "to_coast" => "sc")

      count = PositionEdit.count
      host.patch "#{base}/units/spa", params: { unit: { province: "spa", coast: "sc" } }
      expect(host.response).to have_http_status(:unprocessable_content)
      expect(banner(:danger)).to include("That is already the position.")
      expect(PositionEdit.count).to eq(count)
    end

    it "removes a unit, and then a second removal and the page are the stranger response (AC-2.4)" do
      host.delete "#{base}/units/lon"

      expect(host.response).to have_http_status(:see_other)
      expect(units).not_to include([ "england", "fleet", "lon" ])
      host.get "#{base}/units/lon"
      expect(host.response).to have_http_status(:not_found)
      host.delete "#{base}/units/lon"
      expect(host.response).to have_http_status(:not_found)
    end

    it "is the stranger response for a province that isn't on the map or holds no unit (AC-2.5)" do
      before = position
      %w[xyz bur LON lon.json].each do |province|
        host.get "#{base}/units/#{province}"
        expect(host.response).to have_http_status(:not_found), province
        host.patch "#{base}/units/#{province}", params: { unit: { province: "nth", coast: "" } }
        expect(host.response).to have_http_status(:not_found), province
        host.delete "#{base}/units/#{province}"
        expect(host.response).to have_http_status(:not_found), province
      end
      expect(position).to eq(before)
    end

    it "keeps the stored position loadable and refused steps harmless over a sequence of edits (AC-2.6)" do
      steps = [
        -> { add(province: "bur") }, -> { add(province: "bur") }, -> { host.patch "#{base}/units/bur", params: { unit: { province: "mun", coast: "" } } },
        -> { host.patch "#{base}/units/mun", params: { unit: { province: "nth", coast: "" } } }, -> { add(type: "fleet", province: "stp", coast: "nc") },
        -> { host.delete "#{base}/units/par" }, -> { add(power: "italy", province: "par") },
        -> { host.put "#{base}/owners", params: { owner: { center: "par", power: "italy" } } },
        -> { host.put "#{base}/owners", params: { owner: { center: "bur", power: "italy" } } }
      ]
      steps.each do |step|
        before = position
        step.call
        stored = position
        expect(RulesEngine.load_position(JSON.parse(JSON.generate(stored.to_h)))).to eq(stored)
        expect(stored).to eq(before) if host.response.status == 422
      end
    end
  end

  # ---- Story 3: owners ----
  describe "who owns a supply center" do
    it "lists exactly the 34 supply centers (AC-3.5)" do
      host.get "#{base}/owners"

      expect(page.css("select[name='owner[center]'] option[value]:not([value=''])").size).to eq(34)
      expect(page.css("select[name='owner[power]'] option").map { |o| o["value"] }).to include("nobody", "france")
    end

    it "sets and clears an owner (AC-3.1, AC-3.2)" do
      host.put "#{base}/owners", params: { owner: { center: "bel", power: "germany" } }

      expect(host.response).to have_http_status(:see_other)
      expect(position.ownership[:bel]).to eq(:germany)

      host.put "#{base}/owners", params: { owner: { center: "bel", power: "nobody" } }
      expect(position.ownership).not_to have_key(:bel)
    end

    it "refuses a province that isn't a supply center, a value that isn't a province and an unknown power (AC-3.3)" do
      host.put "#{base}/owners", params: { owner: { center: "bur", power: "france" } }
      expect(banner(:danger)).to include("Burgundy is not a supply center.")
      host.put "#{base}/owners", params: { owner: { center: "xyz", power: "france" } }
      expect(banner(:danger)).to include("Choose a province.")
      host.put "#{base}/owners", params: { owner: { center: "bel", power: "narnia" } }
      expect(banner(:danger)).to include("Choose a power.")
      expect(host.response).to have_http_status(:unprocessable_content)
    end

    it "refuses an owner that is already the owner, and an unowned center set to nobody (AC-3.4)" do
      host.put "#{base}/owners", params: { owner: { center: "lon", power: "england" } }
      expect(banner(:danger)).to include("That is already the position.")
      host.put "#{base}/owners", params: { owner: { center: "bel", power: "nobody" } }
      expect(banner(:danger)).to include("That is already the position.")
    end
  end

  # ---- Story 4: the date ----
  describe "the season and year" do
    it "sets them, leaves the phase number alone and renames the phase (AC-4.1)" do
      host.put "#{base}/date", params: { date: { season: "fall", year: "1901" } }

      expect(host.response).to have_http_status(:see_other)
      expect(game.reload.current_phase.number).to eq(1)
      expect(game.current_phase.title).to eq("Fall 1901 · Movement")
    end

    it "refuses a year that is blank, not a whole number, or out of range (AC-4.2)" do
      [ "", "abc", "1900", "2000", "19.01", "0x76D", "1_901", " 1902", "١٩٠٢" ].each do |year|
        host.put "#{base}/date", params: { date: { season: "fall", year: year } }

        expect(host.response).to have_http_status(:unprocessable_content), year
        expect(banner(:danger)).to include("The year must be a whole number from 1901 to 1999."), year
      end
      expect(position.year).to eq(1901)
    end

    it "refuses a season that isn't spring or fall, and the same date (AC-4.3, AC-4.4)" do
      host.put "#{base}/date", params: { date: { season: "winter", year: "1901" } }
      expect(banner(:danger)).to include("Choose a season.")
      host.put "#{base}/date", params: { date: { season: "spring", year: "1901" } }
      expect(banner(:danger)).to include("That is already the position.")
    end

    it "carries into the next reveal (AC-4.5)" do
      host.put "#{base}/date", params: { date: { season: "fall", year: "1901" } }
      game.current_phase.reveal!

      expect([ game.current_phase.position.season, game.current_phase.position.year ]).to eq([ :spring, 1902 ])
    end
  end

  describe "the pages" do
    it "shows the board with the units by power and the supply centers by owner" do
      host.get base

      expect(host.response).to have_http_status(:ok)
      doc = page
      expect(doc.css("h1").text).to include("Edit the board")
      expect(doc.css("a[href='#{base}/units/lon']").size).to eq(1)
      expect(doc.text).to include("Clears").or include("clears")
      expect(doc.css("svg.supply-center-icon").size).to be >= 7
    end

    it "says what an edit did, in words, with the orders sentence after a banner (D6)" do
      add
      host.follow_redirect!

      expect(banner(:info)).to include("Saved.").and include("France's army added in BUR").and include("Saved orders for this phase were cleared.")

      host.put "#{base}/owners", params: { owner: { center: "bel", power: "germany" } }
      host.follow_redirect!
      expect(banner(:info)).to include("BEL given to Germany").and include("Orders are kept.")
    end

    it "has the Edit the board link on the host page" do
      host.get "/games/#{id}/host"

      expect(page.at_css("a[href='#{base}']").text).to eq("Edit the board")
    end
  end

  # ---- Story 7: host only ----
  describe "who may use it (AC-7.1)" do
    let(:routes) do
      [ [ :get, base ], [ :get, "#{base}/units/new" ], [ :post, "#{base}/units" ], [ :get, "#{base}/units/lon" ], [ :patch, "#{base}/units/lon" ],
        [ :delete, "#{base}/units/lon" ], [ :get, "#{base}/owners" ], [ :put, "#{base}/owners" ], [ :get, "#{base}/date" ], [ :put, "#{base}/date" ] ]
    end
    let(:params) { { unit: { power: "france", type: "army", province: "bur", coast: "" }, owner: { center: "bel", power: "germany" }, date: { season: "fall", year: "1901" } } }

    def write_state = [ game.reload.current_phase.position, PositionEdit.count, SavedOrder.count ]

    it "is the stranger response, writing nothing, for a stranger, a seat phone and another game's host" do
      game.take_seat!("france")
      seat_phone = open_session.tap { |phone| phone.get "/games/#{id}/seat-link", params: { token: game.reissue_seat!(game.seats.find_by(power: "france")) } }
      other_host = create_game(power: "france").session
      before = write_state

      { "a stranger" => open_session, "a seat phone" => seat_phone, "another game's host" => other_host }.each do |who, session|
        routes.each do |verb, path|
          session.public_send(verb, path, params: params)

          expect(session.response).to have_http_status(:not_found), "#{who} #{verb} #{path}"
          expect(Nokogiri::HTML5(session.response.body).at_css("h1").text).to eq("We can't find that page.")
        end
      end
      expect(write_state).to eq(before)
    end

    it "is the stranger response for the host's own seat without the host cookie" do
      seat_only = seat_only_session(created)

      routes.each do |verb, path|
        seat_only.public_send(verb, path, params: params)

        expect(seat_only.response).to have_http_status(:not_found), "#{verb} #{path}"
      end
    end

    it "is indistinguishable from an unknown game for a stranger (AC-7.7)" do
      stranger = open_session
      stranger.get base
      existing = comparable(stranger.response, id)
      stranger.get "/games/#{GameFlow::MISSING_ID}/host/phases/1/position"

      expect(existing).to eq(comparable(stranger.response, GameFlow::MISSING_ID))
    end
  end

  describe "forgery protection (AC-7.2)" do
    around do |example|
      original = ActionController::Base.allow_forgery_protection
      example.run
    ensure
      ActionController::Base.allow_forgery_protection = original
    end

    it "refuses every write without the form token and changes nothing" do
      ActionController::Base.allow_forgery_protection = true
      before = [ position, PositionEdit.count ]
      writes = [ [ :post, "#{base}/units", { unit: { power: "france", type: "army", province: "bur", coast: "" } } ], [ :patch, "#{base}/units/lon", { unit: { province: "nth", coast: "" } } ],
                 [ :delete, "#{base}/units/lon", {} ], [ :put, "#{base}/owners", { owner: { center: "bel", power: "germany" } } ],
                 [ :put, "#{base}/date", { date: { season: "fall", year: "1901" } } ] ]

      writes.each do |verb, path, params|
        refused = begin
          host.public_send(verb, path, params: params)
          host.response.status == 422
        rescue ActionController::InvalidAuthenticityToken
          true
        end
        expect(refused).to be(true), "#{verb} #{path}"
      end
      expect([ position, PositionEdit.count ]).to eq(before)
    end
  end

  describe "phase numbers (AC-7.3)" do
    it "is the stranger response for a later, unknown or malformed number" do
      %w[2 0 01 -1 abc 1.0].each do |number|
        host.get "/games/#{id}/host/phases/#{number}/position"

        expect(host.response).to have_http_status(:not_found), number
      end
    end

    it "sends a revealed number to the host page with a banner and writes nothing" do
      game.current_phase.reveal!
      before = [ game.current_phase.position, PositionEdit.count ]

      add

      expect(host.response).to have_http_status(:see_other)
      expect(URI(host.response.location).path).to eq("/games/#{id}/host")
      host.follow_redirect!
      expect(banner(:info)).to include("That phase was already revealed.")
      expect([ game.reload.current_phase.position, PositionEdit.count ]).to eq(before)
      host.get "/games/#{id}/host/phases/1/position"
      expect(host.response).to have_http_status(:see_other)
    end

    it "sends the host to the host page when the phase is revealed under the edit's lock (AC-7.11)" do
      allow_any_instance_of(Game).to receive(:edit_position!).and_raise(Phase::Revealed) # rubocop:disable RSpec/AnyInstance

      add

      expect(host.response).to have_http_status(:see_other)
      expect(URI(host.response.location).path).to eq("/games/#{id}/host")
      host.follow_redirect!
      expect(banner(:info)).to include("That phase was already revealed.")
      expect(PositionEdit.count).to eq(0)
    end

    it "edits the open phase when its own number is given after a reveal" do
      game.current_phase.reveal!

      host.post "/games/#{id}/host/phases/2/position/units", params: { unit: { power: "france", type: "army", province: "bur", coast: "" } }

      expect(host.response).to have_http_status(:see_other)
      expect(units).to include([ "france", "army", "bur" ])
    end
  end

  describe "what the pages show (AC-7.4, AC-7.8)" do
    let!(:france_and_token) { game.take_seat!("france") }

    def pages
      [ base, "#{base}/units/new", "#{base}/units/lon", "#{base}/owners", "#{base}/date" ]
    end

    def render_all
      add(type: "fleet", province: "mun") # a refusal page
      refusal = host.response.body
      bodies = pages.map { |path| host.get(path) && host.response.body.gsub(/(name="(?:csrf-token|authenticity_token)" (?:content|value)=")[^"]*/, '\1T') }
      bodies + [ refusal.gsub(/(name="(?:csrf-token|authenticity_token)" (?:content|value)=")[^"]*/, '\1T') ]
    end

    it "is the same whatever the seats have ordered, and carries no order text" do
      france = france_and_token.first
      england = game.seats.find_by(power: "england")
      before = render_all
      england.save_orders!(game.current_phase, { "lon" => json_of(rules_order(:hold, :england, :lon)) }, submit: true)
      france.save_orders!(game.current_phase, { "par" => json_of(rules_order(:hold, :france, :par)) })
      after = render_all

      expect(after).to eq(before)
      expect(after.join).not_to match(/hold|Submitted|ordered/i)
    end

    it "carries the no-store and referrer headers and the Turbo no-cache meta on every page" do
      pages.each do |path|
        host.get path

        expect(host.response.headers["Cache-Control"]).to include("no-store"), path
        expect(host.response.headers["Referrer-Policy"]).to eq("no-referrer"), path
        expect(page.at_css("meta[name=turbo-cache-control][content=no-cache]")).to be_present, path
      end
    end
  end

  describe "while the host is stepped into a seat (AC-7.10)" do
    let!(:france_and_token) { game.take_seat!("france") }

    it "records the edit as a position edit and still shows the step-in bar" do
      host.post "/games/#{id}/host/seats/france/phases/1/step-in"
      add
      host.get base

      expect(PositionEdit.count).to eq(1)
      expect(page.css(".banner--warning").text).to include("Still stepped into France's seat.")
    end
  end
end

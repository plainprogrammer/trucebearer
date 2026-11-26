require "rails_helper"
require_relative "../support/rules_helpers"

# Spec 022 Story 7, FR-9, D6: nobody but a seat sees its orders before the reveal, the host included.
#
# The list of places an order could leak is shown to be complete, not just believed to be, by three checks that work together:
# every route the app answers is classified in spec/support/secrecy_routes.rb (a new route fails here until it is); the sweep
# below requests every readable route as every kind of viewer and requires the answers not to depend on England's orders; and
# spec/models/saved_order_boundary_spec.rb limits which files may name the saved-orders model.
RSpec.describe "Order secrecy", type: :request do
  include RulesHelpers

  around { |example| with_passphrase { example.run } }

  describe "the route table (AC-7.1)" do
    it "classifies every route the app answers, and names the one that is not" do
      keys = Rails.application.routes.routes.map { |route| SecrecyRoutes.key_for(route) }.uniq
      unclassified = keys.reject { |key| SecrecyRoutes.classified?(key) }

      expect(unclassified).to be_empty, "classify these in spec/support/secrecy_routes.rb: #{unclassified.join(', ')}"
    end

    it "lists no route of its own that does not exist" do
      keys = Rails.application.routes.routes.map { |route| SecrecyRoutes.key_for(route) }
      expect(SecrecyRoutes::APP.keys - keys).to be_empty
    end

    it "would fail for a route nobody classified" do
      expect(SecrecyRoutes.classified?("GET /games/:public_id/standings")).to be(false)
      expect(SecrecyRoutes.classified?("GET /games/:public_id/phases/:number/orders")).to be(true)
      expect(SecrecyRoutes.classified?("GET /rails/active_storage/blobs/:signed_id/*filename")).to be(true)
      expect(SecrecyRoutes.classified?("MOUNT /cable")).to be(true)
    end

    it "gives every GET it classifies a path to sweep, so a new page cannot be classified and then never requested" do
      unswept = SecrecyRoutes::APP.select { |key, entry| key.start_with?("GET ") && entry[:sweep].nil? }.keys

      expect(unswept).to be_empty, "give these a sweep path in spec/support/secrecy_routes.rb: #{unswept.join(', ')}"
    end

    it "does not let a framework prefix swallow a game route" do
      expect(SecrecyRoutes.classified?("GET /rails/games/:public_id/results")).to be(false)
      expect(SecrecyRoutes.classified?("GET /rails/active_storage/blobs/:signed_id/*filename")).to be(true)
      expect(SecrecyRoutes.classified?("GET /rails/mailers/*path")).to be(true)
    end

    it "classifies the cable mount among the app's own routes, as showing no order (spec 024 AC-4.6)" do
      expect(SecrecyRoutes::APP["MOUNT /cable"][:shows]).to eq(:none)
      expect(SecrecyRoutes::FRAMEWORK.none? { |pattern, _why| "MOUNT /cable".match?(pattern) }).to be(true)
    end

    it "marks as showing orders only the seat page, the orders page, the picker and the endpoint (spec 023 AC-5.1)" do
      showing = SecrecyRoutes::APP.select { |_key, entry| entry[:shows] == :own }.keys

      expect(showing).to match_array([ "GET /games/:public_id", "GET /games/:public_id/phases/:number/orders",
                                       "GET /games/:public_id/phases/:number/orders/:province", "PUT /games/:public_id/phases/:number/orders" ])
    end

    it "marks as showing one seat's orders to the host, inside a step-in, only the three stepped-in routes (spec 026 AC-8.1)" do
      stepped_in = SecrecyRoutes::APP.select { |_key, entry| entry[:shows] == :stepped_in }.keys

      expect(stepped_in).to match_array([ "GET /games/:public_id/host/seats/:power/phases/:number/orders",
                                          "PUT /games/:public_id/host/seats/:power/phases/:number/orders",
                                          "GET /games/:public_id/host/seats/:power/phases/:number/orders/:province" ])
    end
  end

  # A game with the host on Germany, England and France seated, and a viewer of every kind that is not England.
  describe "the sweep" do
    let!(:created) { create_game(power: "germany") }
    let(:game) { created.game }
    let(:id) { game.public_id }
    let!(:england_seat_and_token) do
      seat, = game.take_seat!("england")
      [ seat, game.reissue_seat!(seat) ] # a reissue row is in the history before any baseline (spec 026 AC-10.6)
    end
    let!(:france_seat_and_token) { game.take_seat!("france") }
    let(:england_seat) { england_seat_and_token.first }
    let(:phase) { game.current_phase }
    let(:context) do
      SecrecyRoutes::Context.new(id: id, code: game.join_code, host_token: created.host_token, france_token: france_seat_and_token.last)
    end

    let(:viewers) do
      host_without_seat = open_session.tap { |session| session.get "/games/#{id}/host-link", params: { token: created.host_token } }
      france = open_session.tap { |session| session.get "/games/#{id}/seat-link", params: { token: france_seat_and_token.last } }
      # The host with France's seat cookie is sent away, and its first own-seat request deletes that cookie (spec 026 D5), so the
      # sweep puts it back before every request (see `snapshot`); otherwise the next snapshot would be a host with no seat.
      wearing_france = open_session.tap do |session|
        session.get "/games/#{id}/seat-link", params: { token: france_seat_and_token.last }
        session.get "/games/#{id}/host-link", params: { token: created.host_token }
        @wearing_france_cookie = session.cookies["seat_#{id}"]
      end
      # Stepped into France before the baseline, so its bar and cookie are the same in every snapshot.
      stepped_in = open_session.tap do |session|
        session.get "/games/#{id}/host-link", params: { token: created.host_token }
        session.post "/games/#{id}/host/seats/france/phases/1/step-in"
      end
      { "another seat" => france, "the host, with a seat of its own" => created.session, "the host, with no seat" => host_without_seat,
        "a stranger" => open_session, "the host, with France's seat cookie" => wearing_france, "the host, stepped into France" => stepped_in }
    end
    let(:england_phone) do
      open_session.tap { |session| session.get "/games/#{id}/seat-link", params: { token: england_seat_and_token.last } }
    end

    it "has a reissue row and a step-in row in the host page the sweep compares (AC-10.6)" do
      viewers
      created.session.get "/games/#{id}/host"
      history = Nokogiri::HTML5(created.session.response.body).at_css("[data-seat-history]")

      expect(history.css("li").map { |row| row.text.squish }.join(" ")).to include("seat reissued").and include("stepped in")
    end

    ENTRIES = {
      none: {},
      one: { "lon" => [ :move, :lon, :nth ] },
      all: { "lon" => [ :move, :lon, :nth ], "edi" => [ :hold, :edi ], "lvp" => [ :move, :lvp, :yor ] },
      other: { "lon" => [ :move, :lon, :eng ], "edi" => [ :move, :edi, :nwg ], "lvp" => [ :move, :lvp, :wal ] }
    }.freeze

    def order_for(spec)
      spec.first == :hold ? rules_order(:hold, :england, spec[1]) : move(:england, spec[1], spec[2])
    end

    # England's orders become exactly these (every other unit's order is cleared). Not submitted unless asked.
    def set_orders(name, submit: false)
      entries = %w[lon edi lvp].to_h { |province| [ province, ENTRIES[name][province] ? json_of(order_for(ENTRIES[name][province])) : "" ] }
      england_seat.save_orders!(phase, entries)
      england_seat.save_orders!(phase, {}, submit: true) if submit
    end

    # Status, body (whitespace and request-specific tokens normalized), and the headers and cookies spec 021 AC-5.5 compares.
    def normalized(response)
      status, body, headers, cookies = comparable(response, id)
      body = body.gsub(/(name="csrf-token" content=")[^"]*/, '\1TOKEN').gsub(/(name="authenticity_token" value=")[^"]*/, '\1TOKEN')
      cookies = cookies.map { |line| line.sub(/expires=[^;]*/, "expires=TIME") } # a permanent cookie's expiry moves with the clock
      [ status, body, headers, cookies ]
    end

    # { viewer => { route key => normalized response } } for every readable route.
    def snapshot
      Rails.cache.clear
      viewers.to_h do |name, session|
        responses = SecrecyRoutes.sweeps(context).to_h do |label, item|
          requester = item[:entry][:fresh] ? open_session : session
          requester.cookies["seat_#{id}"] = @wearing_france_cookie if name == "the host, with France's seat cookie" && !item[:entry][:fresh]
          requester.get item[:path]
          [ label, normalized(requester.response) ]
        end
        [ name, responses ]
      end
    end

    def differences(before, after, except: [])
      after.flat_map do |viewer, routes|
        routes.reject { |key, response| response == before[viewer][key] }.keys.reject { |key| except.include?([ viewer, key ]) }
          .map { |key| "#{viewer} on #{key}" }
      end
    end

    it "answers every viewer but England the same whatever England has ordered (AC-7.2)" do
      set_orders(:none)
      baseline = snapshot
      expect(baseline.values.flat_map(&:keys).uniq.size).to eq(SecrecyRoutes.sweeps(context).size)
      # The sweep must be comparing real pages, not four copies of the stranger page: the viewers that have a right to a page got it.
      status = ->(viewer, key) { baseline.fetch(viewer).fetch(key).first }
      orders = "GET /games/:public_id/phases/:number/orders"
      expect(status.call("another seat", orders)).to eq(200)
      expect(status.call("another seat", "GET /games/:public_id")).to eq(200)
      expect(status.call("the host, with a seat of its own", "GET /games/:public_id")).to eq(200)
      expect(status.call("a stranger", orders)).to eq(404)
      [ "the host, with a seat of its own", "the host, with no seat" ].each do |host|
        expect(status.call(host, "GET /games/:public_id/host")).to eq(200)
        expect(status.call(host, "GET /games/:public_id/host/phases/:number/reveal")).to eq(200)
      end

      # The step-in controls (spec 026 AC-8.2): the host without a step-in is a stranger on England's stepped-in URLs, the host stepped into
      # France reaches France's and not England's, and the host with France's seat cookie is sent to its confirmation.
      stepped = "GET /games/:public_id/host/seats/:power/phases/:number/orders"
      [ "the host, with a seat of its own", "the host, with no seat", "another seat", "a stranger" ].each do |viewer|
        expect(status.call(viewer, "#{stepped} [england]")).to eq(404), viewer
        expect(status.call(viewer, "#{stepped} [france]")).to eq(404), viewer
      end
      expect(status.call("the host, stepped into France", "#{stepped} [france]")).to eq(200)
      expect(status.call("the host, stepped into France", "#{stepped} [england]")).to eq(404)
      expect(status.call("the host, with France's seat cookie", "GET /games/:public_id")).to eq(303)
      expect(status.call("the host, with France's seat cookie", orders)).to eq(303)

      %i[one all other none].each do |name|
        set_orders(name)
        changed = differences(baseline, snapshot)
        expect(changed).to be_empty, "the pages changed when England's orders became #{name}: #{changed.join('; ')}"
      end
    end

    it "sweeps real picker pages: France reaches its own deep step, England its own (spec 023 AC-5.2)" do
      set_orders(:none)
      baseline = snapshot
      label = "GET /games/:public_id/phases/:number/orders/:province"

      expect(baseline.fetch("another seat").fetch("#{label} [par]").first).to eq(200)
      expect(baseline.fetch("another seat").fetch("#{label} [lon]").first).to eq(404) # London is England's, not France's
      england_phone.get "/games/#{id}/phases/1/orders/lon?draft%5Bkind%5D=support&draft%5Btarget%5D=edi"
      expect(england_phone.response).to have_http_status(:ok)
    end

    it "shows England no order of France's on any picker page, the support steps that list France's unit included (spec 023 AC-5.3)" do
      # A French army stands in Wales, next to England's units, so England's support steps list it: a unit on the board is public.
      phase.update_columns(position: rules_position(units: [ [ :england, :fleet, :lon ], [ :england, :fleet, :edi ], [ :england, :army, :lvp ],
                                                              [ :france, :army, :wal ] ]))
      france_seat = game.seats.find_by(power: "france")
      france_seat.save_orders!(phase.reload, { "wal" => json_of(move(:france, :wal, :yor)) })
      pages = []
      %w[lon edi lvp].each do |province|
        [ "", "?draft%5Bkind%5D=move", "?draft%5Bkind%5D=support", "?draft%5Bkind%5D=support&draft%5Btarget%5D=wal" ].each do |query|
          england_phone.get "/games/#{id}/phases/1/orders/#{province}#{query}"
          pages << england_phone.response.body if england_phone.response.status == 200
        end
      end
      expect(pages.size).to be > 6
      # The positive control: France's unit is shown on England's support step, so a leak would have somewhere to appear.
      expect(pages.grep(/Army in/).grep(/France/)).not_to be_empty
      france_json = ERB::Util.html_escape(json_of(move(:france, :wal, :yor)))
      pages.each do |body|
        expect(body).not_to include(france_json)
        expect(body).not_to include("&quot;france&quot;") # France's order JSON names its power; England's legal orders never do
        expect(body).not_to include("1 of 3 ordered")
      end
    end

    it "answers the same whether England has submitted or not, except the host's list of who has not and England's row of the status list (AC-7.2, AC-4.1, spec 024 AC-3.5)" do
      set_orders(:all)
      unsubmitted = snapshot
      set_orders(:all, submit: true)
      submitted = snapshot

      confirm = "GET /games/:public_id/host/phases/:number/reveal"
      seat_page = "GET /games/:public_id"
      host_page = "GET /games/:public_id/host"
      hosts = [ "the host, with a seat of its own", "the host, with no seat", "the host, with France's seat cookie", "the host, stepped into France" ]
      # The viewer and page pairs that get a status list, read from the pages themselves; the others get the stranger page, a
      # redirect or a step-in page and stay in the strict comparison. The pairs known to get one must be among them, so a list
      # that stopped showing cannot shrink the set unnoticed.
      listed = unsubmitted.flat_map do |viewer, routes|
        routes.select { |key, response| [ seat_page, host_page ].include?(key) && response[1].include?('id="seat-status"') }.keys.map { |key| [ viewer, key ] }
      end
      expect(listed).to include([ "another seat", seat_page ], [ hosts[0], seat_page ], [ hosts[0], host_page ], [ hosts[1], host_page ])
      expect(listed).not_to include([ "a stranger", seat_page ], [ "a stranger", host_page ], [ "another seat", host_page ], [ hosts[1], seat_page ])
      expect(differences(unsubmitted, submitted, except: hosts.map { |host| [ host, confirm ] } + listed)).to be_empty

      # Where a list shows, the page differs inside #seat-status and nowhere else, and only in England's row. Status, headers
      # and cookies are compared exactly as for every other page (spec 024 AC-3.5).
      outside = lambda do |body|
        Nokogiri::HTML5(body).tap { |doc| doc.at_css("#seat-status").remove }.to_html
      end
      rows = lambda do |body|
        Nokogiri::HTML5(body).css("#seat-status li").to_h { |row| [ row["data-power"], row.text.squish ] }
      end
      listed.each do |viewer, key|
        before = unsubmitted[viewer][key]
        after = submitted[viewer][key]

        expect(after.values_at(0, 2, 3)).to eq(before.values_at(0, 2, 3)), "#{viewer} on #{key}"
        expect(outside.call(after[1])).to eq(outside.call(before[1])), "#{viewer} on #{key}"
        changed = rows.call(after[1]).reject { |power, text| rows.call(before[1])[power] == text }.keys
        expect(changed).to eq([ "england" ]), "#{viewer} on #{key}"
        expect(rows.call(after[1])["england"]).to eq("England Submitted")
      end
      hosts.each do |host|
        expect(unsubmitted[host][confirm][1]).to include("England")
        expect(submitted[host][confirm][1]).not_to include("England")
      end
    end

    it "puts a signed stream name only on the pages of the viewers who may see it, each name verified (spec 024 AC-4.5, spec 025 AC-3.4, AC-4.3)" do
      set_orders(:none)
      shot = snapshot
      names = lambda do |body|
        Nokogiri::HTML5(body).css("turbo-cable-stream-source").map { |source| Turbo.signed_stream_verifier.verified(source["signed-stream-name"]) }.sort
      end
      carrying = shot.flat_map do |viewer, routes|
        routes.filter_map { |key, (_status, body)| [ viewer, key, names.call(body) ] if body.include?("signed-stream-name") }
      end
      # Nor in a header or a cookie line, on any page.
      in_headers = shot.values.flat_map(&:values).select { |_status, _body, headers, cookies| (headers + cookies).join.match?(/seat_status|results:/) }
      expect(in_headers).to be_empty

      both = [ "results:#{id}", "seat_status:#{id}" ]
      results_only = [ "results:#{id}" ]
      # The seat page holds both names, a seat's own order screen and picker the results name only, the host page both. The host (Germany) has
      # no unit in LON or PAR, so both of its pickers are its stranger page; France's PAR picker is the one picker that carries a name.
      # A stepped-in screen carries none, and a stranger's page none.
      expect(carrying).to match_array([
        [ "another seat", "GET /games/:public_id", both ],
        [ "another seat", "GET /games/:public_id/phases/:number/orders", results_only ],
        [ "another seat", "GET /games/:public_id/phases/:number/orders/:province [par]", results_only ],
        [ "the host, with a seat of its own", "GET /games/:public_id", both ],
        [ "the host, with a seat of its own", "GET /games/:public_id/host", both ],
        [ "the host, with a seat of its own", "GET /games/:public_id/phases/:number/orders", results_only ],
        [ "the host, with no seat", "GET /games/:public_id/host", both ],
        [ "the host, with France's seat cookie", "GET /games/:public_id/host", both ],
        [ "the host, stepped into France", "GET /games/:public_id/host", both ]
      ])
    end

    it "never carries England's orders, its labels or its count in a reply to anyone else, a refusal included (AC-7.3)" do
      set_orders(:all)
      saved = england_seat.orders_for(phase).values
      replies = []
      path = "/games/#{id}/phases/1/orders"
      england_json = saved.map { |order| ERB::Util.html_escape(json_of(order)) }

      viewers.each_value do |session|
        session.put path, params: { orders: { "lon" => json_of(rules_order(:hold, :england, :lon)) } } # England's province, someone else's phone
        replies << session.response.body
        session.put path, params: { submit: "1" }
        replies << session.response.body
      end
      replies += snapshot.values.flat_map { |routes| routes.values.map { |response| response[1] } }

      replies.each do |body|
        england_json.each { |text| expect(body).not_to include(text) }
        expect(body).not_to include("3 of 3 ordered")
        expect(body).not_to include("Move to North Sea (NTH)")
      end
      expect(SavedOrder.where(seat_id: england_seat.id).count).to eq(3) # nobody else's request touched England's orders
    end

    it "shows the host no order, no count and no ordered units, only who has not submitted (AC-7.5)" do
      set_orders(:all)
      host = created.session

      [ "/games/#{id}/host", "/games/#{id}/host/phases/1/reveal" ].each do |page_path|
        host.get page_path
        page = Nokogiri::HTML5(host.response.body)
        expect(page.css("select, option")).to be_empty, page_path
        expect(host.response.body).not_to match(/\bordered\b/), page_path
        expect(host.response.body).not_to include("3 of 3"), page_path
      end
      host.post "/games/#{id}/host/phases/1/reveal"
      host.follow_redirect!
      expect(Nokogiri::HTML5(host.response.body).css("select, option")).to be_empty
      expect(host.response.body).not_to match(/\bordered\b/)
    end

    it "shows a revealed phase's results only to the viewers with a right to them, and no order of the open phase (spec 025 AC-5.7, replacing spec 022 AC-7.9)" do
      set_orders(:all)
      created.session.post "/games/#{id}/host/phases/1/reveal"

      england_phone.get "/games/#{id}/phases/1/orders"
      expect(england_phone.response).to have_http_status(:see_other) # to the results page (spec 025 D5)
      seats = [ "another seat", "the host, with a seat of its own" ]
      hosts = [ "the host, with a seat of its own", "the host, with no seat", "the host, with France's seat cookie", "the host, stepped into France" ]
      entitled = { "GET /games/:public_id" => seats, "GET /games/:public_id/phases/:number/results" => seats,
                   "GET /games/:public_id/host" => hosts, "GET /games/:public_id/host/phases/:number/results" => hosts }
      shot = snapshot
      shot.each do |viewer, routes|
        routes.each do |key, (_status, body)|
          next if key == "GET /styleguide" # static samples with made-up orders, no game data

          page = Nokogiri::HTML5(body)
          expect(page.css(".unit-row__order")).to be_empty, "#{viewer} on #{key}"
          expect(page.css(".result-row").any?).to eq(entitled.fetch(key, []).include?(viewer)), "#{viewer} on #{key}"
        end
      end
      # The positive control: an entitled viewer reads England's order, with the stand-in's outcome for it.
      row = Nokogiri::HTML5(shot.fetch("another seat").fetch("GET /games/:public_id")[1]).css(".result-group[data-power=england] .result-row")
             .find { |r| r.text.include?("Move to North Sea (NTH)") }
      expect(row.at_css(".outcome-tag").text).to eq("Succeeded")
    end

    # Spec 026: the one sanctioned way for the host to see or change another seat's orders before the reveal.
    describe "the step-in (spec 026 Story 8)" do
      let(:stepped_host) { open_session.tap { |session| session.get "/games/#{id}/host-link", params: { token: created.host_token } } }
      let(:england_screen) { "/games/#{id}/host/seats/england/phases/1/orders" }

      def rows_of(session) = Nokogiri::HTML5(session.response.body).css(".unit-row__order").map { |row| row.text.squish }

      it "shows the host stepped into England only England's orders, and nothing else on the host's pages moves (AC-8.3)" do
        set_orders(:all)
        stepped_host.post "/games/#{id}/host/seats/england/phases/1/step-in"
        stepped_host.get england_screen

        expect(stepped_host.response).to have_http_status(:ok)
        expect(rows_of(stepped_host)).to eq([ "Hold", "Move to North Sea (NTH)", "Move to Yorkshire (YOR)" ]) # EDI holds, LON and LVP move
        [ "/games/#{id}/host/seats/france/phases/1/orders", "/games/#{id}/host/seats/france/phases/1/orders/par" ].each do |path|
          stepped_host.get path
          expect(stepped_host.response).to have_http_status(:not_found), path
        end

        pages = [ "/games/#{id}/host", "/games/#{id}/host/phases/1/reveal" ]
        read = -> { pages.map { |path| stepped_host.get(path) && normalized(stepped_host.response) } }
        before = read.call
        set_orders(:other)
        expect(read.call).to eq(before)
      end

      it "writes the record before any request shows France's order (AC-8.4)" do
        france = game.seats.find_by(power: "france")
        france.save_orders!(phase, { "par" => json_of(rules_order(:hold, :france, :par)) })
        confirmation = "/games/#{id}/host/seats/france/phases/1/step-in"
        screen = "/games/#{id}/host/seats/france/phases/1/orders"
        log = []

        [ [ :get, confirmation ], [ :get, screen ], [ :post, confirmation ], [ :get, screen ] ].each do |verb, path|
          inserted = false
          counter = ->(*, payload) { inserted ||= payload[:sql].to_s.match?(/INSERT INTO "step_ins"/) }
          ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { stepped_host.public_send(verb, path) }
          log << { inserted: inserted, shows_order: rows_of(stepped_host).include?("Hold") }
        end

        expect(log.map { |entry| entry[:inserted] }).to eq([ false, false, true, false ])
        expect(log.map { |entry| entry[:shows_order] }).to eq([ false, false, false, true ]) # the first request that shows it comes after the INSERT
      end

      it "shows the host's pages no order, count or ordered unit of any seat while stepped in (AC-8.5)" do
        set_orders(:all, submit: true)
        stepped_host.post "/games/#{id}/host/seats/france/phases/1/step-in"

        [ "/games/#{id}/host", "/games/#{id}/host/phases/1/reveal", "/games/#{id}/host/seats/england/phases/1/step-in" ].each do |path|
          stepped_host.get path
          body = stepped_host.response.body
          expect(body).not_to match(/\bordered\b|\d of \d/), path
          expect(Nokogiri::HTML5(body).css(".unit-row__order, select, option")).to be_empty, path
          expect(body).not_to include(ERB::Util.html_escape(json_of(order_for(ENTRIES[:all]["lon"])))), path
        end
      end
    end
  end
end

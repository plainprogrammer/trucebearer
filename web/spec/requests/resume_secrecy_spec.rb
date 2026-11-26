require "rails_helper"

# Spec 028 Story 3: a browser's home page names its own games and nothing about any other (D2, D8).
RSpec.describe "What the home page shows each browser", type: :request do
  # Three games, each with its own powers, its own start day and its own phase title, so a leak of any one of them can be seen.
  let!(:a) { Game.start!(power: "england") }
  let!(:b) { Game.start!(power: "france") }
  let!(:c) { Game.start!(power: "germany") }
  let(:games) { { a: a.game, b: b.game, c: c.game } }

  before do
    a.game.update_columns(created_at: Time.utc(2026, 3, 3, 12))
    b.game.update_columns(created_at: Time.utc(2026, 4, 4, 12))
    c.game.update_columns(created_at: Time.utc(2026, 5, 5, 12))
    b.game.edit_position!(1, { "action" => "date_set", "to_season" => "fall", "to_year" => 1902 })
    c.game.edit_position!(1, { "action" => "date_set", "to_season" => "spring", "to_year" => 1903 })
  end

  def phone(*links)
    open_session.tap { |session| links.each { |game, kind, token| session.get "/games/#{game.public_id}/#{kind}-link", params: { token: token } } }
  end

  def hrefs(phone) = Nokogiri::HTML5(phone.response.body).css("a.game-card").map { |card| card["href"] }

  # The SQL the block ran against the three tables the home page may read (the games, the seats, the phases).
  def game_queries
    queries = []
    counter = ->(*, payload) { queries << payload[:sql] if payload[:name] != "SCHEMA" && payload[:sql].match?(/FROM "(?:games|seats|phases)"/) }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { yield }
    queries
  end

  # A cookie's value as a browser puts it in a Cookie header: escaped, because a signed value can hold a "+".
  def header_pair(name, session) = "#{name}=#{Rack::Utils.escape(session.cookies[name])}"

  # The raw text of a signed cookie value, as the app would have written it.
  def signed(name, value)
    request = ActionDispatch::Request.new(Rails.application.env_config.dup)
    request.cookie_jar.signed[name] = value
    request.cookie_jar[name]
  end

  it "lists exactly a browser's own games and nothing of the others (AC-3.1, AC-3.2)" do
    only_a = phone([ a.game, "seat", a.seat_token ])
    b_and_c = phone([ b.game, "seat", b.seat_token ], [ c.game, "host", c.host_token ])
    nobody = open_session
    junk = open_session.tap { |s| games.each_value { |g| %w[host seat].each { |kind| s.cookies["#{kind}_#{g.public_id}"] = "junk" } } }
    [ only_a, b_and_c, nobody, junk ].each { |s| s.get "/" }

    expect(hrefs(only_a)).to eq([ "/games/#{a.game.public_id}" ])
    expect(hrefs(b_and_c)).to eq([ "/games/#{c.game.public_id}/host", "/games/#{b.game.public_id}" ])
    expect(hrefs(nobody)).to be_empty
    expect(hrefs(junk)).to be_empty

    others = lambda do |phone, hidden|
      body = phone.response.body
      hidden.flat_map { |g| [ g.public_id, g.join_code, g.created_at.strftime("%-d %b %Y"), g.current_phase.title ] }.each do |text|
        expect(body).not_to include(text)
      end
    end
    others.call(only_a, [ b.game, c.game ])
    others.call(b_and_c, [ a.game ])
    others.call(nobody, games.values)
    others.call(junk, games.values)
    [ only_a, b_and_c, nobody, junk ].each do |s|
      games.each_value { |g| expect(s.response.body).not_to include(g.join_code) } # no join code at all
    end
    expect(only_a.response.body).not_to match(/France|Germany/) # A is England's game
    expect(b_and_c.response.body).not_to include("England")
    expect(nobody.response.body).not_to match(/England|France|Germany/)
    expect(junk.response.body).not_to match(/England|France|Germany/)
  end

  it "lists no game for a cookie that does not verify (AC-3.3)" do
    id_a = a.game.public_id
    id_b = b.game.public_id
    sets = {
      "B's raw seat value under A's name (fails at the signature)" => ->(s) { s.cookies["seat_#{id_a}"] = phone([ b.game, "seat", b.seat_token ]).cookies["seat_#{id_b}"] },
      "a value signed under A's name that holds B's seat token (fails at the digest)" => ->(s) { s.cookies["seat_#{id_a}"] = signed("seat_#{id_a}", b.seat_token) },
      "a host cookie that holds A's seat token" => ->(s) { s.cookies["host_#{id_a}"] = signed("host_#{id_a}", a.seat_token) },
      "an unsigned value" => ->(s) { s.cookies["seat_#{id_a}"] = a.seat_token },
      "a tampered signed value" => ->(s) { s.cookies["seat_#{id_a}"] = signed("seat_#{id_a}", a.seat_token).sub(/.\z/) { |ch| ch == "a" ? "b" : "a" } },
      "a game that does not exist" => ->(s) { s.cookies["seat_zzzzzzzzzzzz"] = signed("seat_zzzzzzzzzzzz", a.seat_token) }
    }
    sets.each do |label, build|
      session = open_session.tap(&build)
      session.get "/"

      expect(session.response).to have_http_status(:ok), label
      expect(hrefs(session)).to be_empty, label
    end

    control = open_session.tap { |s| s.cookies["seat_#{id_a}"] = signed("seat_#{id_a}", a.seat_token) }
    control.get "/"
    expect(hrefs(control)).to eq([ "/games/#{id_a}" ]), "the helper must produce a cookie the app accepts"
  end

  it "answers junk for an existing game, junk for a missing one and no cookie with the same page (AC-3.4)" do
    normalize = ->(session, id) { comparable(session.response, id).tap { |r| r[1] = r[1].gsub(/(name="csrf-token" content=")[^"]*/, '\1TOKEN') } }
    existing = junk_session(a.game.public_id)
    missing = junk_session(GameFlow::MISSING_ID)
    none = open_session
    [ existing, missing, none ].each { |s| s.get "/" }

    expect(normalize.call(existing, a.game.public_id)).to eq(normalize.call(none, a.game.public_id))
    expect(normalize.call(missing, GameFlow::MISSING_ID)).to eq(normalize.call(none, GameFlow::MISSING_ID))
  end

  it "ignores names that are not game cookies, and looks up no game for them (AC-3.5)" do
    id = a.game.public_id
    token = Rack::Utils.escape(phone([ a.game, "seat", a.seat_token ]).cookies["seat_#{id}"])
    names = [ "seat_short", "host_#{'a' * 13}", "seat_#{id}x", "step_in_#{id}", "seat_#{id}.x", "seat_#{id}/x", "other_#{id}" ]
    session = open_session
    queries = game_queries { session.get "/", headers: { "HTTP_COOKIE" => names.map { |name| "#{name}=#{token}" }.join("; ") } }

    expect(session.response).to have_http_status(:ok)
    expect(hrefs(session)).to be_empty
    expect(queries).to be_empty, "a name that is not a public id's shape must not cause a lookup"
  end

  it "examines the first 40 ids in request order and no more (AC-3.6)" do
    id = a.game.public_id
    mine = header_pair("seat_#{id}", phone([ a.game, "seat", a.seat_token ]))
    filler = ->(count, from = 0) { Array.new(count) { |i| "seat_#{format('%012d', from + i)}=junk" } } # distinct ids
    session = open_session
    session.get "/", headers: { "HTTP_COOKIE" => (filler.call(40) + [ mine ] + filler.call(19, 40)).join("; ") } # 60 ids, mine the 41st

    expect(session.response).to have_http_status(:ok)
    expect(hrefs(session)).to be_empty

    session.get "/", headers: { "HTTP_COOKIE" => (filler.call(39) + [ mine ] + filler.call(20, 39)).join("; ") } # mine the 40th
    expect(hrefs(session)).to eq([ "/games/#{id}" ])
  end

  it "makes at most three queries on games, seats and phases, whatever the cookies (AC-3.7)" do
    mine = [ a, b, c ].map { |started| header_pair("seat_#{started.game.public_id}", phone([ started.game, "seat", started.seat_token ])) }
    filler = Array.new(57) { |i| "seat_#{format('%012d', i)}=junk" }
    [ [], mine.first(1), mine + filler ].each do |cookies|
      session = open_session
      queries = game_queries { session.get "/", headers: { "HTTP_COOKIE" => cookies.join("; ") } }

      expect(queries.size).to be <= 3, queries.join("\n")
    end
  end

  it "stops listing a seat when the host reissues it, and lists it again for the new phone (AC-3.8)" do
    old_phone = phone([ b.game, "seat", b.seat_token ])
    old_phone.get "/"
    expect(hrefs(old_phone)).to eq([ "/games/#{b.game.public_id}" ])

    token = b.game.reissue_seat!(b.game.seat_for(b.seat_token))
    old_phone.get "/"
    expect(hrefs(old_phone)).to be_empty

    new_phone = phone([ b.game, "seat", token ])
    new_phone.get "/"
    expect(hrefs(new_phone)).to eq([ "/games/#{b.game.public_id}" ])
  end

  it "classifies GET / as showing no order, and says why (AC-3.11)" do
    entry = SecrecyRoutes::APP["GET /"]

    expect(entry).to include(shows: :none, revealed: :none)
    expect(entry[:why]).to include("cookies").and include("never an order")
  end

  it "keeps the home page free of any order, count or submitted state (AC-3.12)" do
    scanned = %w[app/controllers/concerns/resumable_games.rb app/views/home/_game_card.html.erb app/views/home/index.html.erb
                 app/helpers/game_cards_helper.rb]
    source = scanned.map { |path| File.read(Rails.root.join(path)) }.join("\n")

    %w[saved_orders SavedOrder Submission submitted? ordered_count orders_for].each do |word|
      expect(source).not_to include(word), "#{word} must not appear in the home page's source"
    end
  end
end

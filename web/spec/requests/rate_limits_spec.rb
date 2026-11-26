require "rails_helper"

RSpec.describe "Rate limits", type: :request do
  around do |example|
    original = ENV["TRUCEBEARER_PASSPHRASE"]
    example.run
  ensure
    ENV["TRUCEBEARER_PASSPHRASE"] = original
  end

  let(:code) { Game.start!(power: "england").game.join_code }
  let(:one_address) { { "REMOTE_ADDR" => "203.0.113.7" } }
  let(:other_address) { { "REMOTE_ADDR" => "203.0.113.8" } }

  def limited? = response.status == 429 && response.body.include?("Too many tries. Wait a few minutes and try again.")

  it "limits code lookup to 30 a minute per address, the form and the page together (AC-8.2, 8.3)" do
    15.times { post "/join", params: { code: "ZZZZZZ" }, headers: one_address }
    15.times { get "/join/#{code}", headers: one_address }
    expect(response.status).to eq(200)

    get "/join/#{code}", headers: one_address
    expect(limited?).to be(true)

    get "/join/#{code}", headers: other_address
    expect(response).to have_http_status(:ok)
  end

  it "limits taking a power to 30 a minute (AC-8.4)" do
    30.times { post "/join/#{code}/seat", params: { power: "narnia" }, headers: one_address }
    post "/join/#{code}/seat", params: { power: "france" }, headers: one_address
    expect(limited?).to be(true)
  end

  it "limits creating a game to 10 in five minutes, even with the right passphrase (AC-8.5)" do
    ENV["TRUCEBEARER_PASSPHRASE"] = "open sesame"
    10.times { post "/games", params: { passphrase: "wrong", power: "england" }, headers: one_address }
    expect { post "/games", params: { passphrase: "open sesame", power: "england" }, headers: one_address }.not_to change(Game, :count)
    expect(limited?).to be(true)
  end

  it "limits host links and seat links together to 20 a minute (AC-8.6)" do
    10.times { get "/games/x/host-link", params: { token: "t" }, headers: one_address }
    10.times { get "/games/x/seat-link", params: { token: "t" }, headers: one_address }
    get "/games/x/host-link", params: { token: "t" }, headers: one_address
    expect(limited?).to be(true)
  end

  it "keeps the no-referrer policy on a link controller's 429 (FR-2)" do
    21.times { get "/games/x/seat-link", params: { token: "t" }, headers: one_address }
    expect(limited?).to be(true)
    expect(response.headers["Referrer-Policy"]).to eq("no-referrer")

    21.times { get "/games/x/host-link", params: { token: "t" }, headers: other_address }
    expect(limited?).to be(true)
    expect(response.headers["Referrer-Policy"]).to eq("no-referrer")
  end

  it "answers normally again after the window (AC-8.7)" do
    31.times { get "/join/#{code}", headers: one_address }
    expect(limited?).to be(true)
    travel 61.seconds
    get "/join/#{code}", headers: one_address
    expect(response).to have_http_status(:ok)
  end

  it "answers every bucket with the same status and body (AC-8.8)" do
    ENV["TRUCEBEARER_PASSPHRASE"] = "open sesame"
    responses = []
    11.times { post "/games", params: { passphrase: "x", power: "england" }, headers: one_address }
    responses << [ response.status, response.body ]
    31.times { get "/join/#{code}", headers: { "REMOTE_ADDR" => "203.0.113.20" } }
    responses << [ response.status, response.body ]
    31.times { post "/join/#{code}/seat", params: { power: "narnia" }, headers: { "REMOTE_ADDR" => "203.0.113.21" } }
    responses << [ response.status, response.body ]
    21.times { get "/games/x/host-link", params: { token: "t" }, headers: { "REMOTE_ADDR" => "203.0.113.22" } }
    responses << [ response.status, response.body ]

    expect(responses.map(&:first)).to all(eq(429))
    expect(responses.map { |_status, body| body.gsub(/\s+/, " ") }.uniq.size).to eq(1)
    expect(Nokogiri::HTML5(responses.first.last).at_css("main").text.strip).to eq("Too many tries. Wait a few minutes and try again.")
  end

  it "shares one bucket across an IPv6 /64 and keeps an IPv4 address apart (AC-8.9)" do
    15.times { get "/join/#{code}", headers: { "REMOTE_ADDR" => "2001:db8:0:1::1" } }
    15.times { get "/join/#{code}", headers: { "REMOTE_ADDR" => "2001:db8:0:1::2" } }
    get "/join/#{code}", headers: { "REMOTE_ADDR" => "2001:db8:0:1::3" }
    expect(limited?).to be(true)

    get "/join/#{code}", headers: { "REMOTE_ADDR" => "2001:db8:0:2::1" } # another /64
    expect(response).to have_http_status(:ok)
    get "/join/#{code}", headers: one_address
    expect(response).to have_http_status(:ok)
  end

  it "chooses the bucket by the client behind a private proxy (AC-8.10)" do
    behind = ->(client) { { "REMOTE_ADDR" => "10.0.0.5", "HTTP_X_FORWARDED_FOR" => client } }
    31.times { get "/join/#{code}", headers: behind.call("198.51.100.9") }
    expect(limited?).to be(true)

    get "/join/#{code}", headers: behind.call("198.51.100.10")
    expect(response).to have_http_status(:ok)
  end
end

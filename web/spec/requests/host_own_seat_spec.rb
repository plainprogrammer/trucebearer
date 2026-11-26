require "rails_helper"

# Issue #120, a fix to specs 021, 026 and 028 (028 D5): the host page links to the host's own seat only for a browser that holds it.
RSpec.describe "The host page's way to the host's own seat", type: :request do
  let(:started) { Game.start!(power: "england") }
  let(:game) { started.game }
  let(:id) { game.public_id }
  let(:sentence) { "This phone doesn't hold your seat. To play here, reissue your own seat from the Seats list. That clears its saved orders for this phase." }

  def phone(*links)
    open_session.tap { |session| links.each { |kind, token| session.get "/games/#{id}/#{kind}-link", params: { token: token } } }
  end

  def host_page(session)
    session.get "/games/#{id}/host"
    expect(session.response).to have_http_status(:ok)
    Nokogiri::HTML5(session.response.body)
  end

  def own_seat_links(page) = page.css("a").select { |a| a.text.strip == "Your own seat" }

  def sentence_nodes(page) = page.css("main p").select { |p| p.text.squish == sentence }

  it "gives a browser with the host's own seat the link, and the link works" do
    session = phone([ "host", started.host_token ], [ "seat", started.seat_token ])
    page = host_page(session)

    expect(own_seat_links(page).map { |a| a["href"] }).to eq([ "/games/#{id}" ])
    expect(sentence_nodes(page)).to be_empty

    session.get "/games/#{id}"
    expect(session.response).to have_http_status(:ok)
  end

  it "gives a browser with only the host cookie no link, and the sentence once" do
    page = host_page(phone([ "host", started.host_token ]))

    expect(own_seat_links(page)).to be_empty
    expect(page.css("a[href='/games/#{id}']")).to be_empty
    expect(sentence_nodes(page).size).to eq(1)
  end

  it "does the same for a browser whose seat cookie is another seat's, a junk one or a reissued one" do
    _france, france_token = game.take_seat!("france")
    junk = phone([ "host", started.host_token ]).tap { |s| s.cookies["seat_#{id}"] = "junk" }
    other = phone([ "seat", france_token ], [ "host", started.host_token ]) # seat first: a host browser's seat link asks to step in and saves nothing
    expect(other.cookies["seat_#{id}"]).to be_present
    old_phone = phone([ "host", started.host_token ], [ "seat", started.seat_token ])
    game.reissue_seat!(game.host_seat)

    [ junk, other, old_phone ].each do |session|
      page = host_page(session)
      expect(own_seat_links(page)).to be_empty
      expect(sentence_nodes(page).size).to eq(1)
    end
  end

  it "says the same words to every browser that lacks the seat" do
    _france, france_token = game.take_seat!("france")
    bodies = [ phone([ "host", started.host_token ]), phone([ "seat", france_token ], [ "host", started.host_token ]) ].map do |session|
      host_page(session).css("main p").find { |p| p.text.include?("reissue your own seat") }.to_html
    end

    expect(bodies.uniq.size).to eq(1)
  end
end

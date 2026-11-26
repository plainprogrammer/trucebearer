require "rails_helper"

# Spec 024 FR-3, FR-5, D8, D9: the status list on the seat page and the host's controls, correct on a plain page load.
RSpec.describe "The status list on the pages", type: :request do
  around { |example| with_passphrase { example.run } }

  let!(:created) { create_game(power: "germany") }
  let(:game) { created.game }
  let(:id) { game.public_id }
  let!(:england) { game.take_seat!("england") }
  let(:phase) { game.current_phase }

  def page_of(session, path)
    session.get path
    Nokogiri::HTML5(session.response.body)
  end

  def state_of(page, power) = page.at_css("#seat-status [data-power='#{power}'] .seat-status__state").text

  it "shows the seven rows on the seat page under an h2 (AC-2.1)" do
    page = page_of(created.session, "/games/#{id}")

    expect(page.css("#seat-status > li").map { |row| row["data-power"] }).to eq(%w[austria england france germany italy russia turkey])
    expect(page.css("h2").map(&:text)).to include("Who has submitted")
    expect(page.css("main p").map { |node| node.text.squish }).not_to include("Submitted", "Not submitted") # the old single line is gone
  end

  it "shows the seven rows on the host page, in the host section above the Reveal button, under an h3 (AC-1.1)" do
    page = page_of(created.session, "/games/#{id}/host")
    section = page.at_css(".host-section")
    heading = section.css("h3").find { |node| node.text == "Who has submitted" }
    reveal = section.css("a.button").find { |link| link.text == "Reveal orders" }

    expect(heading).not_to be_nil
    expect(section.css("#seat-status > li").size).to eq(7)
    expect(heading <=> reveal).to eq(-1) # document order: the heading, and the list after it, come before the button
    expect(section.at_css("#seat-status") <=> reveal).to eq(-1)
    expect(section.css("ul.list > li").size).to eq(7) # the seats list; the status list does not carry .list
  end

  it "is correct on a plain page load, with no live connection (AC-1.2, AC-5.1)" do
    england.first.save_orders!(phase, {}, submit: true)

    [ "/games/#{id}", "/games/#{id}/host" ].each do |path|
      page = page_of(created.session, path)
      expect(state_of(page, "england")).to eq("Submitted")
      expect(state_of(page, "france")).to eq("Not submitted")
    end
  end

  it "is the same element on both pages, and its inside is what a stream message sends (AC-5.3)" do
    england.first.save_orders!(phase, {}, submit: true)
    seat_list = page_of(created.session, "/games/#{id}").at_css("#seat-status").to_html
    host_list = page_of(created.session, "/games/#{id}/host").at_css("#seat-status").to_html
    squeeze = ->(html) { html.gsub(/\s+/, " ").strip }

    expect(seat_list).to eq(host_list)
    payload = JSON.parse(ActionCable.server.pubsub.broadcasts("seat_status:#{id}").last)
    template = Nokogiri::HTML5.fragment(payload).at_css("template").inner_html
    expect(squeeze.call(template)).to eq(squeeze.call(Nokogiri::HTML5.fragment(seat_list).at_css("ul").inner_html))
  end

  it "has one stream source whose signed name verifies to this game's status stream, and never another game's (AC-4.1)" do
    names = [ "/games/#{id}", "/games/#{id}/host" ].map do |path|
      sources = page_of(created.session, path).css("turbo-cable-stream-source")
      expect(sources.size).to eq(1)
      Turbo.signed_stream_verifier.verified(sources.first["signed-stream-name"])
    end
    other = create_game(power: "france")
    other_source = page_of(other.session, "/games/#{other.game.public_id}").at_css("turbo-cable-stream-source")

    expect(names).to eq([ "seat_status:#{id}" ] * 2)
    expect(Turbo.signed_stream_verifier.verified(other_source["signed-stream-name"])).to eq("seat_status:#{other.game.public_id}")
  end

  it "gives no stream element to a stranger, a junk cookie, another game's cookie or a seat cookie on the host page (AC-4.2)" do
    [ "", "/host" ].each do |suffix|
      stranger_responses(created, suffix: suffix).each_value do |(existing, _missing)|
        expect(existing[1]).not_to include("turbo-cable-stream-source")
        expect(existing[1]).not_to include("signed-stream-name")
      end
    end
  end

  it "does not let Turbo keep a snapshot of either page (D9, AC-5.2)" do
    [ "/games/#{id}", "/games/#{id}/host" ].each do |path|
      metas = page_of(created.session, path).css("meta[name='turbo-cache-control']")

      expect(metas.map { |meta| meta["content"] }).to eq([ "no-cache" ])
    end
  end
end

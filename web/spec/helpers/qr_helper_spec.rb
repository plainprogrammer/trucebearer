require "rails_helper"

RSpec.describe QrHelper, type: :helper do
  let(:url) { "https://play.example.org/join/ABCDEF" }
  let(:label) { "QR code to join the game" }
  let(:svg) { helper.qr_code_svg(url, label) }

  it "is one inline svg with a name, no color, no style and no prolog (AC-3.8)" do
    expect(svg).to start_with("<svg")
    expect(svg).to include('role="img"').and include(%(aria-label="#{label}"))
    expect(svg).not_to include("fill=")
    expect(svg).not_to include("style=")
    expect(svg).not_to include("<?xml")
    expect(svg.scan("<path").size).to eq(1)
  end

  it "carries a four-module quiet zone in its view box (AC-9.8)" do
    side = RQRCode::QRCode.new(url, level: :m).modules.size + 8

    expect(svg).to match(/viewBox="0 0 #{side} #{side}"/)
  end

  it "encodes the URL: the same URL gives the same drawing and another URL a different one (AC-3.2)" do
    expect(helper.qr_code_svg(url, label)).to eq(svg)
    expect(helper.qr_code_svg("https://play.example.org/join/GHJKMN", label)).not_to eq(svg)
  end

  it "shows no code and logs when the gem cannot make one (error table)" do
    allow(RQRCode::QRCode).to receive(:new).and_raise(RQRCodeCore::QRCodeRunTimeError, "too long")
    allow(Rails.logger).to receive(:error)

    expect(helper.qr_code_svg(url, label)).to be_nil
    expect(Rails.logger).to have_received(:error).with(/QR code could not be made/)
  end

  describe "#qr_card" do
    it "holds the code, the caption and the link as text" do
      html = Nokogiri::HTML5.fragment(helper.qr_card(url, label: label, caption: "Caption"))

      expect(html.at_css(".qr-card svg[role=img]")).to be_present
      expect(html.at_css(".qr-card__caption").text).to eq("Caption")
      expect(html.at_css(".qr-card__link").text).to eq(url)
    end

    it "leaves out the caption slot when there is none" do
      html = Nokogiri::HTML5.fragment(helper.qr_card(url, label: label))

      expect(html.at_css(".qr-card__caption")).to be_nil
    end
  end
end

require "rails_helper"

# Spec 024 D5, AC-7.1: the setting that names the origins, besides its own, that may open the live-update socket.
RSpec.describe CableOrigins do
  it "gives no origins for nothing, a blank or only separators" do
    expect([ nil, "", "  ", " ,, " ].map { |value| CableOrigins.parse(value) }).to all(eq([]))
  end

  it "reads origins separated by commas or spaces, dropping a trailing slash and repeats" do
    expect(CableOrigins.parse("https://a.example")).to eq([ "https://a.example" ])
    expect(CableOrigins.parse("https://a.example/, https://b.example")).to eq([ "https://a.example", "https://b.example" ])
    expect(CableOrigins.parse("https://a.example https://a.example")).to eq([ "https://a.example" ])
  end

  it "writes each origin in lowercase, as a browser's Origin header is" do
    expect(CableOrigins.parse("HTTPS://Play.Example.org/")).to eq([ "https://play.example.org" ])
  end

  it "names the variable that production.rb reads" do
    expect(CableOrigins::ENV_NAME).to eq("TRUCEBEARER_CABLE_ORIGINS")
  end
end

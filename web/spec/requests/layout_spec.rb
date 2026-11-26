require "rails_helper"

RSpec.describe "Layout", type: :request do
  before { get "/" }

  let(:page) { Nokogiri::HTML5(response.body) }

  it "sets the language and a viewport that covers the unsafe edges and allows zoom" do
    expect(page.at_css("html")["lang"]).to eq("en")
    viewport = page.at_css("meta[name=viewport]")["content"]
    expect(viewport).to include("width=device-width", "initial-scale=1", "viewport-fit=cover")
    expect(viewport).not_to include("user-scalable")
    expect(viewport).not_to include("maximum-scale")
  end

  it "has one header and one main landmark, supplied by the layout (AC-6.6)" do
    expect(page.css("header").size).to eq(1)
    expect(page.css("main").size).to eq(1)
    expect(page.at_css("main h1").text).to eq("Trucebearer")
  end

  it "shows the app name in the header as a link to the root page" do
    link = page.at_css("header a.app-header__name")
    expect(link.text.strip).to eq("Trucebearer")
    expect(link["href"]).to eq("/")
  end

  it "renders no action area when the page gives none (AC-3.7)" do
    expect(page.css(".app-actions")).to be_empty
  end

  it "does not link to the style guide (AC-5.3)" do
    expect(page.css("a[href*=styleguide]")).to be_empty
  end

  it "links every stylesheet in the folder" do
    hrefs = page.css("link[rel=stylesheet]").map { |l| l["href"] }
    names = Dir[Rails.root.join("app/assets/stylesheets/*.css")].map { |f| File.basename(f, ".css") }
    expect(names).to include("tokens", "base", "layout")
    names.each { |name| expect(hrefs.grep(/#{name}-/)).not_to be_empty, "no link for #{name}.css" }
  end
end

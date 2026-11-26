require "rails_helper"

RSpec.describe "The font is served by this app (AC-6.2, 6.3)", type: :request do
  it "links a stylesheet whose font url is a local path that answers with the file" do
    get "/styleguide"
    hrefs = Nokogiri::HTML5(response.body).css("link[rel=stylesheet]").map { |l| l["href"] }
    expect(hrefs).to all(start_with("/"))
    css = hrefs.map { |href| get(href) && response.body }.join("\n")
    path = css[/url\("(\/assets\/IBMPlexMono-Medium-Latin1-[0-9a-f]+\.woff2)"\)/, 1]
    expect(path).not_to be_nil
    get path
    expect(response).to have_http_status(:ok)
    expect(response.body.b).to eq(File.binread(Rails.root.join("app/assets/fonts/IBMPlexMono-Medium-Latin1.woff2")))
  end
end

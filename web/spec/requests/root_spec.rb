require "rails_helper"

RSpec.describe "Root page", type: :request do
  it "responds with success on GET / and keeps its own content (AC-6.6)" do
    get "/"

    expect(response).to have_http_status(:ok)
    body = Nokogiri::HTML5(response.body)
    expect(body.at_css("h1").text).to eq("Trucebearer")
    expect(body.at_css("main p").text).to eq("Enter secret orders on your phone and have each turn adjudicated.")
  end
end

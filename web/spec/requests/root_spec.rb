require "rails_helper"

RSpec.describe "Root page", type: :request do
  it "responds with success on GET / and keeps its own content (AC-6.6)" do
    get "/"

    expect(response).to have_http_status(:ok)
    body = Nokogiri::HTML5(response.body)
    expect(body.at_css("h1").text).to eq("Trucebearer")
    expect(body.at_css("main p").text).to eq("Enter secret orders on your phone and have each turn adjudicated.")
  end

  it "links to creating and joining a game (AC-1.1, FR-1)" do
    get "/"

    body = Nokogiri::HTML5(response.body)
    expect(body.at_css("main a.button[href='/games/new']").text).to eq("Create a game")
    expect(body.at_css("main a.button.button--secondary[href='/join']").text).to eq("Join a game")
  end
end

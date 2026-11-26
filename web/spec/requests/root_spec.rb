require "rails_helper"

RSpec.describe "Root page", type: :request do
  it "responds with success on GET /" do
    get "/"

    expect(response).to have_http_status(:ok)
  end
end

require "rails_helper"

# rate_limit does nothing on the null store, so a spec fails if the test environment uses it (spec 021 AC-8.1).
RSpec.describe "The cache store" do
  it "is a real store that remembers" do
    expect(Rails.cache).not_to be_a(ActiveSupport::Cache::NullStore)
    expect(ActionController::Base.cache_store).not_to be_a(ActiveSupport::Cache::NullStore)

    Rails.cache.write("remembered", 1)
    expect(Rails.cache.read("remembered")).to eq(1)
  end
end

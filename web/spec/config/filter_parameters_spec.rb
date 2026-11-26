require "rails_helper"

RSpec.describe "The log filter" do
  it "hides the passphrase and the token (spec 021 FR-2)" do
    filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)
    filtered = filter.filter({ "passphrase" => "x", "token" => "y", "power" => "england" })

    expect(filtered).to eq({ "passphrase" => "[FILTERED]", "token" => "[FILTERED]", "power" => "england" })
  end
end

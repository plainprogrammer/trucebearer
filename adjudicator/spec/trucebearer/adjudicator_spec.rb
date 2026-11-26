# frozen_string_literal: true

require "trucebearer/adjudicator"

RSpec.describe Trucebearer::Adjudicator do
  it "has a version number" do
    expect(Trucebearer::Adjudicator::VERSION).to match(/\A\d+\.\d+\.\d+\z/)
  end
end

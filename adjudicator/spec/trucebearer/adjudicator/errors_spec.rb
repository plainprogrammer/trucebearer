# frozen_string_literal: true

require "trucebearer/adjudicator"

RSpec.describe Trucebearer::Adjudicator::InvalidInput do
  it "is a direct subclass of StandardError" do
    expect(described_class.superclass).to equal(StandardError)
  end

  it "has no subclasses of its own" do
    expect(described_class.subclasses).to be_empty
  end
end

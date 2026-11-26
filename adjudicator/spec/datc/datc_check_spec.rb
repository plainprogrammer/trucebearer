# frozen_string_literal: true

require "trucebearer/adjudicator"
require_relative "../support/datc"

# Runs every DATC fixture through TA.check (AC-8.1), and keeps the set of fixtures
# exactly the one the spec lists (AC-8.2). #14 adds its cases to `encoded`.
RSpec.describe "DATC fixtures: checking" do
  # The cases encoded for checking: 6.A and 6.B, except the four left out, and three
  # from 6.D and 6.G that interface.md cites. See spec 011, "Cases encoded".
  encoded = (
    (1..10).map { |n| "6.A.#{n}" } +
    [1, 2, 3, 4, 5, 6, 7, 8, 10, 11, 12, 13, 15, 16, 17, 18, 19].map { |n| "6.B.#{n}" } +
    %w[6.D.31 6.D.34 6.G.19]
  ).sort.freeze
  left_out = %w[6.A.11 6.A.12 6.B.9 6.B.14].freeze

  it "has one fixture for each encoded case and no other (AC-8.2)" do
    names = Datc.files.map { |path| File.basename(path, ".yml") }
    expect(encoded.size).to eq(30)
    expect(names).to eq(encoded)
    expect(names & left_out).to eq([])
  end

  it "marks only 6.B.2 and 6.B.12 as departures (AC-8.4)" do
    expect(Datc.load_all.select(&:departure).map(&:id)).to eq(%w[6.B.12 6.B.2])
  end

  Datc.load_all.each do |kase|
    describe kase.id do
      kase.entries.each_with_index do |entry, index|
        next unless entry.expected

        it "checks order #{index + 1} (#{entry.order.class.name.split("::").last} at #{entry.order.at})" do
          expect(TA.check(kase.position, entry.order)).to eq(entry.expected)
        end
      end
    end
  end

  it "gives every order of every encoded file a check (the rule for files on disk)" do
    Datc.load_all.each do |kase|
      expect(kase.entries.map(&:expected)).to all(be_a(TA::CheckResult)), "#{kase.id} has an order with no check"
    end
  end
end

# frozen_string_literal: true

require "trucebearer/adjudicator"
require_relative "../support/datc"

# Runs every DATC fixture through TA.check (AC-8.1), and keeps the set of fixtures
# exactly the one the specs list (AC-8.2). #14 added its cases through Datc::ADJUDICATED, and
# #15 added the convoy cases to it and the paradox cases that wait for #39 (Datc::PARADOX_PENDING).
RSpec.describe "DATC fixtures: checking" do
  # Every fixture is run for checking: the cases adjudicated (Datc::ADJUDICATED), which include
  # all of 6.A and 6.B except the two left out, and the convoy paradoxes that wait for #39.
  # See spec 011, "Cases encoded", spec 014 and spec 015, "DATC cases".
  encoded = (Datc::ADJUDICATED + Datc::PARADOX_PENDING).sort.freeze
  left_out = %w[6.B.9 6.B.14].freeze

  it "has one fixture for each encoded case and no other (AC-8.2)" do
    names = Datc.files.map { |path| File.basename(path, ".yml") }
    expect(encoded.size).to eq(138)
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

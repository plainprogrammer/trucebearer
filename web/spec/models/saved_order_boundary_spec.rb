require "spec_helper"

# Who may name the saved-orders model and table (spec 022 FR-9, AC-7.8). Orders are secret until the reveal, and nothing may
# list every seat's orders for an open phase. A text scan is a tripwire, not a proof: review still matters.
RSpec.describe "The saved-orders boundary" do
  root = File.expand_path("../..", __dir__)
  name = /SavedOrder|saved_orders?/

  files = Dir.glob(File.join(root, "{app,lib,db}/**/*")).select { |path| File.file?(path) && !path.end_with?(".enc") }
  text_of = ->(path) { File.binread(path).force_encoding("UTF-8").scrub }
  naming = files.select { |path| text_of.call(path).match?(name) }.map { |path| path.delete_prefix("#{root}/") }

  it "is named only by the model, Seat, Phase's reveal, the migration and the schema (AC-7.8)" do
    allowed = %w[app/models/saved_order.rb app/models/seat.rb app/models/phase.rb db/schema.rb]
    outside = naming.reject { |path| allowed.include?(path) || path.match?(%r{\Adb/migrate/\d+_create_phases_saved_orders_and_submissions\.rb\z}) }

    expect(outside).to be_empty, "names the saved orders outside the boundary: #{outside.join(', ')}"
    expect(naming).to include("app/models/saved_order.rb", "app/models/seat.rb", "app/models/phase.rb")
  end

  it "has the association on Seat only, and none reaches saved orders through another model" do
    associations = files.select { |path| text_of.call(path).match?(/has_(?:many|one)\s*:saved_orders/) }.map { |path| path.delete_prefix("#{root}/") }

    expect(associations).to eq([ "app/models/seat.rb" ])
    %w[app/models/game.rb app/models/phase.rb].each do |path|
      expect(File.read(File.join(root, path))).not_to match(/through:\s*:?\w*(?:seats|saved_orders)/), path
    end
  end

  it "reads a seat's orders only through the seat, in the orders controller (AC-7.8)" do
    callers = files.flat_map { |path| text_of.call(path).lines.grep(/orders_for/).map { |line| [ path.delete_prefix("#{root}/"), line.strip ] } }
    outside = callers.reject { |path, line| path == "app/models/seat.rb" || line.include?("@seat.orders_for") }

    expect(outside).to be_empty, "reads orders outside the seat and its own controller: #{outside.map(&:first).join(', ')}"
  end

  it "reads a whole phase's orders in one place, Phase's reveal (AC-7.8)" do
    phase = File.read(File.join(root, "app/models/phase.rb"))
    reveal = phase[/def reveal!.*?\n  end\n/m]

    expect(phase.scan(name).size).to eq(1)
    expect(reveal).to include("SavedOrder.joins(:seat).where(phase_id: id)")
  end
end

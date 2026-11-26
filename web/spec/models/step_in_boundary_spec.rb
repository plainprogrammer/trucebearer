require "spec_helper"

# Spec 026 AC-8.6: who may name the step-in record. A text scan is a tripwire, not a proof: review still matters.
RSpec.describe "The step-in boundary" do
  root = File.expand_path("../..", __dir__)
  files = Dir.glob(File.join(root, "{app,lib,db}/**/*")).select { |path| File.file?(path) && !path.end_with?(".enc") }
  naming = files.select { |path| File.binread(path).force_encoding("UTF-8").scrub.match?(/\bStepIn\b/) }.map { |path| path.delete_prefix("#{root}/") }

  it "names the StepIn constant only in its own files and the access and game code (AC-8.6)" do
    allowed = %w[app/models/step_in.rb app/models/game.rb app/controllers/step_ins_controller.rb app/controllers/concerns/game_access.rb]
    outside = naming.reject { |path| allowed.include?(path) }

    expect(outside).to be_empty, "names StepIn outside the boundary: #{outside.join(', ')}"
    expect(naming).to include("app/models/step_in.rb", "app/controllers/step_ins_controller.rb", "app/controllers/concerns/game_access.rb")
  end

  it "holds no saved-orders association and reaches none (the record has no order)" do
    source = File.read(File.join(root, "app/models/step_in.rb"))

    expect(source).not_to match(/saved_order|SavedOrder|orders_for/i)
    expect(File.read(File.join(root, "app/models/game.rb"))).not_to match(/through:\s*:?step_ins/)
  end

  reissue_pattern = /\bReissue(?:\.|::|\s*<)/

  it "names the Reissue constant only in its own file and Game (AC-10.7, a guard: it passes as soon as the model is in)" do
    reissue_users = files.select { |path| File.binread(path).force_encoding("UTF-8").scrub.match?(reissue_pattern) }.map { |path| path.delete_prefix("#{root}/") }

    expect(reissue_users).to match_array(%w[app/models/reissue.rb app/models/game.rb])
  end

  it "matches a use of the constant and not the word in text or a controller's name (a control for the guard)" do
    expect("Reissue.record!(phase: phase)").to match(reissue_pattern)
    expect("class Reissue < ApplicationRecord").to match(reissue_pattern)
    expect("Reissue seat").not_to match(reissue_pattern)
    expect("class ReissuesController < ApplicationController").not_to match(reissue_pattern)
  end

  it "holds no saved-orders association and no through association for reissues, and nothing else reads the table (AC-10.7)" do
    expect(File.read(File.join(root, "app/models/reissue.rb"))).not_to match(/saved_order|SavedOrder|orders_for/i)
    expect(File.read(File.join(root, "app/models/game.rb"))).not_to match(/through:\s*:?reissues/)
    readers = Dir.glob(File.join(root, "app/{views,controllers,helpers}/**/*")).select { |path| File.file?(path) && File.read(path).match?(/\breissues\b/) }

    expect(readers).to be_empty, "reads the reissues table outside the boundary: #{readers.join(', ')}"
  end
end

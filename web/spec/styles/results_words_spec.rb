require "spec_helper"

# Spec 025 AC-8.2: the outcome tag is written in one place.
RSpec.describe "The outcome tag" do
  root = File.expand_path("../..", __dir__)

  it "is written only by the results/_outcome_tag partial" do
    files = Dir.glob(File.join(root, "app/{views,helpers,models,controllers}/**/*")).select { |path| File.file?(path) }
    writers = files.select { |path| File.read(path).include?("outcome-tag") }.map { |path| path.delete_prefix("#{root}/") }

    expect(writers).to eq([ "app/views/results/_outcome_tag.html.erb" ])
  end
end

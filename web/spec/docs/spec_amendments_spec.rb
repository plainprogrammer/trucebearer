require "spec_helper"

# Spec 024 AC-8.2: a spec that another spec changes records the change in its own changelog.
RSpec.describe "Spec amendments" do
  it "records spec 024's changes to spec 022 in a 1.4.0 changelog row (spec 024 AC-8.2)" do
    spec = File.read(File.expand_path("../../docs/specs/022-phase-lifecycle/spec.md", __dir__))
    row = spec.lines.find { |line| line.start_with?("| 1.4.0 |") }

    expect(spec).to include("**Version:** 1.4.0")
    expect(row).not_to be_nil
    expect(row).to include("AC-1.5").and include("AC-7.5").and include("AC-7.2").and include("/cable").and include("spec 024")
  end
end

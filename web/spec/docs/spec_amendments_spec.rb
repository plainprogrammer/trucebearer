require "spec_helper"

# Spec 024 AC-8.2: a spec that another spec changes records the change in its own changelog.
RSpec.describe "Spec amendments" do
  it "records spec 024's changes to spec 022 in a 1.4.0 changelog row (spec 024 AC-8.2)" do
    spec = File.read(File.expand_path("../../docs/specs/022-phase-lifecycle/spec.md", __dir__))
    row = spec.lines.find { |line| line.start_with?("| 1.4.0 |") }

    expect(row).not_to be_nil # the version line moves on with later amendments (1.5.0, spec 025); the row stays
    expect(row).to include("AC-1.5").and include("AC-7.5").and include("AC-7.2").and include("/cable").and include("spec 024")
  end

  it "records spec 025's changes to spec 022 in a 1.5.0 changelog row (spec 025 AC-9.1)" do
    spec = File.read(File.expand_path("../../docs/specs/022-phase-lifecycle/spec.md", __dir__))
    row = spec.lines.find { |line| line.start_with?("| 1.5.0 |") }

    expect(spec).to include("**Version:** 1.5.0")
    expect(row).not_to be_nil
    expect(row).to include("AC-6.3").and include("FR-6").and include("AC-7.9").and include("FR-9").and include("spec 025")
  end

  it "records spec 025's change to spec 023's revealed-phase step URL in a 1.1.0 changelog row (spec 025 AC-9.1)" do
    spec = File.read(File.expand_path("../../docs/specs/023-order-pickers/spec.md", __dir__))
    row = spec.lines.find { |line| line.start_with?("| 1.1.0 |") }

    expect(spec).to include("**Version:** 1.1.0")
    expect(row).not_to be_nil
    expect(row).to include("AC-2.13").and include("spec 025")
  end

  it "records spec 025's changes to spec 024 in a 1.1.0 changelog row (spec 025 AC-9.1)" do
    spec = File.read(File.expand_path("../../docs/specs/024-live-status/spec.md", __dir__))
    row = spec.lines.find { |line| line.start_with?("| 1.1.0 |") }

    expect(spec).to include("**Version:** 1.1.0")
    expect(row).not_to be_nil
    expect(row).to include("AC-2.7").and include("AC-4.1").and include("AC-4.5").and include("half stale").and include("spec 025")
  end
end

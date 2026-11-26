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

    expect(row).not_to be_nil # the version line moves on with later amendments (spec 029); the row stays
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

    expect(row).not_to be_nil # the version line moves on with later amendments (1.2.0, spec 024 itself); the row stays
    expect(row).to include("AC-2.7").and include("AC-4.1").and include("AC-4.5").and include("half stale").and include("spec 025")
  end

  # The row that mentions spec 029, and its version, which must also be the spec's version line (the row is found by text, not by number).
  def amendment_row(path)
    spec = File.read(File.expand_path("../../docs/specs/#{path}/spec.md", __dir__))
    row = spec.lines.find { |line| line.start_with?("| ") && line.include?("spec 029") }
    expect(row).not_to be_nil
    version = row[/\A\| (\d+\.\d+\.\d+) \|/, 1]
    expect(version).not_to be_nil
    expect(spec).to include("**Version:** #{version}")
    [ spec, row, version ]
  end

  it "records spec 029's retirement of the stand-in in spec 019's changelog (spec 029 AC-5.1)" do
    _, row, version = amendment_row("019-adjudicator-boundary")
    expect(version).to match(/\A1\.(?:[3-9]|\d{2,})\.0\z/) # 1.3.0, or later if another amendment came first
    expect(row).to include("FR-3").and include("AC-5.1").and include("test double").and include("RulesEngine.adjudicate").and include("load_adjudication")
  end

  it "records spec 029's reading of spec 022 in its changelog (spec 029 AC-5.2)" do
    _, row, version = amendment_row("022-phase-lifecycle")
    expect(version).to match(/\A1\.(?:[6-9]|\d{2,})\.0\z/) # the next free minor after 1.5.0
    expect(row).to include("AC-5.2").and include("next_movement_position").and include("real engine")
  end

  it "records spec 029's retirement of the practice note in spec 025's changelog (spec 029 AC-5.3)" do
    _, row, version = amendment_row("025-reveal-results")
    expect(version).to match(/\A1\.(?:[1-9]|\d{2,})\.0\z/) # 1.1.0, or 1.2.0 if the results catch-up (#105) amended spec 025 first
    expect(row).to include("D6").and include("AC-7.1").and include("AC-7.3").and include("AC-8.1").and include("AC-8.4").and include("stand_in?")
  end
end

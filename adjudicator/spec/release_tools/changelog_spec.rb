# frozen_string_literal: true

require "date"
require_relative "../../bin/release_tools/changelog"

RSpec.describe ReleaseTools::Changelog do
  let(:date) { Date.new(2026, 11, 25) }

  let(:sample) do
    <<~MD
      # Changelog

      Intro text.

      Releases are git tags named `adjudicator-vX.Y.Z`.

      ## Unreleased

      ### Added

      - A new thing. (#1)
      - Another new thing. (#2)

      ### Changed

      ### Fixed

      - A repaired thing. (#3)

      ## 0.0.1 (2026-01-01)

      ### Added

      - The first thing.
    MD
  end

  describe ".release" do
    it "moves the Unreleased entries under a dated version heading and leaves a fresh Unreleased" do
      result = described_class.release(sample, version: "0.1.0", date: date)

      expect(result).to eq(<<~MD)
        # Changelog

        Intro text.

        Releases are git tags named `adjudicator-vX.Y.Z`.

        ## Unreleased

        ### Added

        ### Changed

        ### Fixed

        ## 0.1.0 (2026-11-25)

        ### Added

        - A new thing. (#1)
        - Another new thing. (#2)

        ### Fixed

        - A repaired thing. (#3)

        ## 0.0.1 (2026-01-01)

        ### Added

        - The first thing.
      MD
    end

    it "drops subsections that have no entries from the released section" do
      result = described_class.release(sample, version: "0.1.0", date: date)
      released = result[/^## 0\.1\.0.*?(?=^## 0\.0\.1)/m]

      expect(released).not_to include("### Changed")
    end

    it "works when Unreleased is the last section of the file, as in the first release" do
      text = <<~MD
        # Changelog

        ## Unreleased

        ### Added

        - The skeleton. (#6)

        ### Changed

        ### Fixed
      MD

      result = described_class.release(text, version: "0.1.0", date: date)

      expect(result).to eq(<<~MD)
        # Changelog

        ## Unreleased

        ### Added

        ### Changed

        ### Fixed

        ## 0.1.0 (2026-11-25)

        ### Added

        - The skeleton. (#6)
      MD
    end

    it "keeps subsections other than Added, Changed and Fixed" do
      text = "## Unreleased\n\n### Removed\n\n- Old thing.\n"

      result = described_class.release(text, version: "0.2.0", date: date)

      expect(result).to include("## 0.2.0 (2026-11-25)\n\n### Removed\n\n- Old thing.\n")
    end

    it "keeps entries written directly under Unreleased, before any subsection" do
      text = "## Unreleased\n\n- A loose entry.\n\n### Added\n"

      result = described_class.release(text, version: "0.2.0", date: date)

      expect(result).to include("## 0.2.0 (2026-11-25)\n\n- A loose entry.\n")
    end

    it "does not stop at a subsection heading when looking for the end of Unreleased" do
      result = described_class.release(sample, version: "0.1.0", date: date)

      expect(result).to include("- A repaired thing. (#3)")
      expect(result.scan("## Unreleased").size).to eq(1)
    end

    it "ends with exactly one newline" do
      result = described_class.release(sample, version: "0.1.0", date: date)

      expect(result).to end_with("- The first thing.\n")
    end

    it "raises when Unreleased has only empty subsections" do
      empty = "# Changelog\n\n## Unreleased\n\n### Added\n\n### Changed\n\n### Fixed\n"

      expect { described_class.release(empty, version: "0.1.0", date: date) }
        .to raise_error(ReleaseTools::Error, /Unreleased.*empty/i)
    end

    it "raises when there is no Unreleased section" do
      expect { described_class.release("# Changelog\n", version: "0.1.0", date: date) }
        .to raise_error(ReleaseTools::Error, /Unreleased/)
    end

    it "raises when the version already has a heading" do
      expect { described_class.release(sample, version: "0.0.1", date: date) }
        .to raise_error(ReleaseTools::Error, /0\.0\.1.*already/i)
    end

    it "does not modify the text it is given" do
      original = sample.dup

      described_class.release(sample, version: "0.1.0", date: date)

      expect(sample).to eq(original)
    end
  end

  describe ".unreleased_empty?" do
    it "is false when any subsection has an entry" do
      expect(described_class.unreleased_empty?(sample)).to be(false)
    end

    it "is true when only headings are present" do
      expect(described_class.unreleased_empty?("## Unreleased\n\n### Added\n\n### Fixed\n")).to be(true)
    end
  end

  describe "against the real CHANGELOG.md" do
    let(:real) { File.read(File.expand_path("../../CHANGELOG.md", __dir__)) }

    it "can always find and read its Unreleased section" do
      expect { described_class.unreleased_empty?(real) }.not_to raise_error
    end

    # Right after a release Unreleased is empty and there is nothing to release.
    it "can release whatever is currently under Unreleased" do
      skip "nothing under Unreleased right now" if described_class.unreleased_empty?(real)

      result = described_class.release(real, version: "9.9.9", date: date)

      expect(result).to include("## 9.9.9 (2026-11-25)", "Releases are git tags named")
      expect(described_class.unreleased_empty?(result)).to be(true)
    end
  end
end

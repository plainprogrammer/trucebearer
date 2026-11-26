# frozen_string_literal: true

require_relative "../../bin/release_tools/version"

RSpec.describe ReleaseTools::Version do
  let(:file_text) do
    <<~RUBY
      # frozen_string_literal: true

      module Trucebearer
        module Adjudicator
          VERSION = "0.1.2"
        end
      end
    RUBY
  end

  describe ".read" do
    it "returns the version string from the version file text" do
      expect(described_class.read(file_text)).to eq("0.1.2")
    end

    it "raises when there is no VERSION line" do
      expect { described_class.read("module X; end\n") }.to raise_error(ReleaseTools::Error, /VERSION/)
    end
  end

  describe ".resolve" do
    it "bumps the patch number" do
      expect(described_class.resolve("patch", "0.1.2")).to eq("0.1.3")
    end

    it "bumps the minor number and resets patch" do
      expect(described_class.resolve("minor", "0.1.2")).to eq("0.2.0")
    end

    it "bumps the major number and resets minor and patch" do
      expect(described_class.resolve("major", "0.1.2")).to eq("1.0.0")
    end

    it "accepts an explicit version that is higher than the current one" do
      expect(described_class.resolve("0.3.0", "0.1.2")).to eq("0.3.0")
    end

    it "compares numbers, not strings" do
      expect(described_class.resolve("0.10.0", "0.9.0")).to eq("0.10.0")
    end

    it "refuses an explicit version equal to or lower than the current one" do
      expect { described_class.resolve("0.1.2", "0.1.2") }.to raise_error(ReleaseTools::Error, /higher/)
      expect { described_class.resolve("0.0.9", "0.1.2") }.to raise_error(ReleaseTools::Error, /higher/)
    end

    it "refuses anything that is not plain X.Y.Z" do
      ["1.0", "v1.0.0", "1.0.0-rc1", "0.01.0", "00.1.0", "banana", ""].each do |bad|
        expect { described_class.resolve(bad, "0.1.2") }.to raise_error(ReleaseTools::Error, /X\.Y\.Z/)
      end
    end
  end

  it "refuses to bump from a current version that is not X.Y.Z" do
    expect { described_class.resolve("patch", "1.0") }.to raise_error(ReleaseTools::Error, /current version/)
  end

  describe ".rewrite_file" do
    it "changes only the VERSION line" do
      result = described_class.rewrite_file(file_text, "0.2.0")

      expect(result).to eq(file_text.sub('"0.1.2"', '"0.2.0"'))
    end
  end
end

require "rails_helper"

RSpec.describe Passphrase do
  around do |example|
    original = ENV[Passphrase::ENV_NAME]
    example.run
  ensure
    ENV[Passphrase::ENV_NAME] = original
  end

  it "is not configured when unset or blank" do
    ENV[Passphrase::ENV_NAME] = nil
    expect(Passphrase.configured?).to be(false)
    ENV[Passphrase::ENV_NAME] = "  "
    expect(Passphrase.configured?).to be(false)
  end

  it "compares digests with secure_compare, a missing guess included" do
    ENV[Passphrase::ENV_NAME] = "open sesame"
    allow(ActiveSupport::SecurityUtils).to receive(:secure_compare).and_call_original
    expect(Passphrase.correct?(nil)).to be(false)
    expect(ActiveSupport::SecurityUtils).to have_received(:secure_compare).with(Token.digest(""), Token.digest("open sesame"))
    expect(Passphrase.correct?("open sesame")).to be(true)
    expect(Passphrase.correct?("Open sesame")).to be(false)
    expect(Passphrase.correct?("open sesame ")).to be(false)
  end
end

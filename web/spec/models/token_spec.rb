require "rails_helper"

RSpec.describe Token do
  it "makes 24 random bytes as 32 URL-safe characters, never the same twice" do
    tokens = Array.new(50) { Token.generate }
    expect(tokens.uniq.size).to eq(50)
    expect(tokens).to all(match(/\A[A-Za-z0-9_-]{32}\z/))
  end

  it "digests to 64 hex characters and matches only its own token" do
    token = Token.generate
    digest = Token.digest(token)
    expect(digest).to match(/\A\h{64}\z/)
    expect(Token.match?(token, digest)).to be(true)
    expect(Token.match?(Token.generate, digest)).to be(false)
    expect(Token.match?(nil, digest)).to be(false)
    expect(Token.match?(token, nil)).to be(false)
  end

  it "compares with secure_compare on two digests" do
    allow(ActiveSupport::SecurityUtils).to receive(:secure_compare).and_call_original
    Token.match?("a", Token.digest("b"))
    expect(ActiveSupport::SecurityUtils).to have_received(:secure_compare).with(Token.digest("a"), Token.digest("b"))
  end
end

# The instance passphrase (spec FR-5, D3). It lives in the environment, never on screen.
module Passphrase
  ENV_NAME = "TRUCEBEARER_PASSPHRASE"

  def self.expected = ENV[ENV_NAME].to_s

  def self.configured? = expected.present?

  # Both sides are digested first, so the time does not depend on the guess's length or how much of it is right.
  # A missing guess is the digest of an empty string and goes through the same comparison.
  def self.correct?(guess)
    ActiveSupport::SecurityUtils.secure_compare(Token.digest(guess), Token.digest(expected))
  end
end

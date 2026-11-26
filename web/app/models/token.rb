# Random tokens and their digests (spec D2). A token is 24 bytes from SecureRandom, 192 bits.
# Only the SHA-256 digest is ever stored. Both sides of a comparison are digests, so they have one
# length and secure_compare does not leak one.
module Token
  BYTES = 24

  def self.generate = SecureRandom.urlsafe_base64(BYTES)

  def self.digest(value) = OpenSSL::Digest::SHA256.hexdigest(value.to_s)

  def self.match?(token, stored_digest)
    ActiveSupport::SecurityUtils.secure_compare(digest(token), stored_digest.to_s)
  end
end

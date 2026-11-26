# The six-character code (spec FR-3). 22 characters with no look-alikes: none of 0 O Q 1 I L 2 Z 5 S 8 B U V.
module JoinCode
  ALPHABET = %w[A C D E F G H J K M N P R T W X Y 3 4 6 7 9].freeze
  LENGTH = 6
  SHAPE = /\A[#{ALPHABET.join}]{#{LENGTH}}\z/

  def self.generate = Array.new(LENGTH) { ALPHABET[SecureRandom.random_number(ALPHABET.size)] }.join

  # Upper-cased (ASCII letters only), spaces and hyphens removed. Nothing is converted into another character.
  # Returns nil for anything that is not a code.
  def self.normalize(input)
    code = input.to_s.upcase(:ascii).delete(" \t-")
    code if code.match?(SHAPE)
  end

  def self.groups(code) = [ code[0, 3], code[3, 3] ]
end

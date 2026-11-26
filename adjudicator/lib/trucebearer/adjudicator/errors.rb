# frozen_string_literal: true

module Trucebearer
  module Adjudicator
    # Raised for every input error the gem detects: a bad hash, an unknown
    # identifier, an impossible value. There is deliberately only this one class.
    class InvalidInput < StandardError; end
  end
end

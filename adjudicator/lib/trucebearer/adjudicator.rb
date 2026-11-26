# frozen_string_literal: true

require_relative "adjudicator/version"
require_relative "adjudicator/errors"
require_relative "adjudicator/map"
require_relative "adjudicator/shape"
require_relative "adjudicator/location"
require_relative "adjudicator/unit"
require_relative "adjudicator/dislodged_unit"
require_relative "adjudicator/position"
require_relative "adjudicator/order"
require_relative "adjudicator/check_result"
require_relative "adjudicator/reach"
require_relative "adjudicator/check"

module Trucebearer
  # The rules engine: checks orders and adjudicates each phase of a game turn.
  module Adjudicator
    # Checks one order against a position and says whether it is legal, with the first
    # reason it is not (docs/interface.md, "Checking an order"). Raises InvalidInput only for
    # an argument that is not a position or an order; a broken rule is a result, never an error.
    def self.check(position, order) = Check.call(position, order)
  end
end

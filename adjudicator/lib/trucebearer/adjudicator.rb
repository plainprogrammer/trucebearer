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
require_relative "adjudicator/legal_orders"
require_relative "adjudicator/outcome"
require_relative "adjudicator/adjudication"
require_relative "adjudicator/resolver"
require_relative "adjudicator/adjudicate"

module Trucebearer
  # The rules engine: checks orders and adjudicates each phase of a game turn.
  module Adjudicator
    # Checks one order against a position and says whether it is legal, with the first
    # reason it is not (docs/interface.md, "Checking an order"). Raises InvalidInput only for
    # an argument that is not a position or an order; a broken rule is a result, never an error.
    def self.check(position, order) = Check.call(position, order)

    # Lists every order that is legal for one unit, in a fixed order (docs/interface.md,
    # "Legal orders"). Empty when the position isn't in a movement phase or the unit isn't on
    # the board. Raises InvalidInput only for an argument of the wrong class.
    def self.legal_orders(position, unit) = LegalOrders.call(position, unit)

    # Adjudicates a movement phase (docs/interface.md, "Adjudicating a movement phase"): one
    # outcome for every order, then an implied hold for every unit that has none, and the
    # position after the moves. Raises InvalidInput for an argument of the wrong class, a
    # position that isn't in the movement phase, or one power giving two orders for one
    # province; a broken rule is an outcome, never an error. A convoy paradox is flagged, not
    # resolved (#39).
    def self.adjudicate(position, orders) = Adjudicate.call(position, orders)
  end
end

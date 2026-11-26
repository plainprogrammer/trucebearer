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

module Trucebearer
  # The rules engine: checks orders and adjudicates each phase of a game turn.
  module Adjudicator
  end
end

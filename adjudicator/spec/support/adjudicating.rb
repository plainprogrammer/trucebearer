# frozen_string_literal: true

require_relative "board"

# Short builders for the adjudication specs: units and orders in the notation of the
# DATC fixtures ("spa/nc" for a coast), and a call that adjudicates them in a position
# that holds only those units.
module Adjudicating
  module_function

  def u(power, type, at) = Board.unit(power, type, at)
  def hd(power, at) = O::Hold.new(power: power, at: at)
  def mv(power, at, to) = O::Move.new(power: power, at: at, destination: Board.loc(to))
  def mvc(power, at, to) = O::MoveViaConvoy.new(power: power, at: at, to: to)
  def sh(power, at, target) = O::SupportHold.new(power: power, at: at, target: target)
  def sm(power, at, from, to) = O::SupportMove.new(power: power, at: at, from: from, to: to)
  def cv(power, at, from, to) = O::Convoy.new(power: power, at: at, from: from, to: to)

  def run(units, orders) = TA.adjudicate(Board.position(*units), orders)

  # The result symbols of the first `count` outcomes (the submitted ones).
  def results(adjudication, count) = adjudication.outcomes.first(count).map(&:result)

  # Where each unit of the next position stands, as {province => power}.
  def after(adjudication) = adjudication.position.units.to_h { |unit| [unit.location.province, unit.power] }

  # The dislodged units of the next position, as {province => attacker_from}.
  def dislodged(adjudication)
    adjudication.position.dislodged_units.to_h { |entry| [entry.unit.location.province, entry.attacker_from] }
  end
end

RSpec.configure { |config| config.include Adjudicating }

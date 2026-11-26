# The board of the position editor (spec 027 D6): the open phase's units and supply-center owners, and the way to each edit.
class PositionsController < ApplicationController
  include PositionEditing

  def show
    @position = @phase.position
  end
end

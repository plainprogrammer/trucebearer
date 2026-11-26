# Adding, moving and removing a unit (spec 027 D1, D6).
class PositionUnitsController < ApplicationController
  include PositionEditing

  before_action :find_unit, only: %i[show update destroy]

  def new; end

  def create
    @refused_province = field(:unit, :province)
    @refused_coast = field(:unit, :coast)
    edit!(:new) do
      { "action" => "unit_added", "power" => power!(field(:unit, :power)),
        "type" => choose!(field(:unit, :type), %w[army fleet], "Choose army or fleet."),
        "province" => province!(@refused_province), "coast" => coast!(@refused_coast) }
    end
  end

  def show; end

  def update
    @refused_province = field(:unit, :province)
    @refused_coast = field(:unit, :coast)
    edit!(:show) { { "action" => "unit_moved", "from" => @province, "to" => province!(@refused_province), "to_coast" => coast!(@refused_coast) } }
  end

  def destroy
    edit!(:show) { { "action" => "unit_removed", "province" => @province } }
  end

  private

  # The unit's province in the path: a province of the map that holds a unit in the open phase, else the stranger response.
  def find_unit
    @province = params[:province].to_s
    @unit = @phase.position.units.find { |unit| unit.location.province.to_s == @province }
    stranger!(@game) unless @unit
  end
end

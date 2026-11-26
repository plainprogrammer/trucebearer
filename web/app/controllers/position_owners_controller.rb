# Setting who owns a supply center (spec 027 D1, D6). "Nobody" removes the owner.
class PositionOwnersController < ApplicationController
  include PositionEditing

  def show; end

  def update
    @refused_province = field(:owner, :center)
    edit!(:show) do
      power = field(:owner, :power)
      { "action" => "owner_set", "center" => province!(@refused_province), "to" => power == "nobody" ? nil : power!(power) }
    end
  end
end

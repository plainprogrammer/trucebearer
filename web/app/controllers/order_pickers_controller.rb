# One picker step for one of the seat's units (spec 023 D1, D2, FR-2). A GET never writes: the last pick is a form that PUTs to the
# orders endpoint. The headers run before the unit check, so the stranger page of a wrong province carries them too; it shows every
# seat the same thing, so nothing leaks.
class OrderPickersController < ApplicationController
  include OrderScreen
  before_action :require_seat
  before_action :find_phase_or_stranger
  before_action :own_orders_headers

  def show
    return revealed_get unless @phase.open?

    @province = params[:province].to_s
    @unit = @phase.position.units.find { |u| u.power.to_s == @seat.power && u.location.province.to_s == @province }
    return stranger!(@game) unless @unit

    draft = draft_param
    @step = draft && OrderChoices.new(@phase.position, @unit, ordered: @seat.orders_for(@phase).key?(@province)).step(draft)
    redirect_to picker_path_for(@phase.number, @province), status: :see_other unless @step
  end

  private

  # {} when absent, the String-keyed hash when it is one, nil when it is anything else (a string, an array).
  def draft_param
    raw = params[:draft]
    return {} if raw.nil?

    raw.respond_to?(:to_unsafe_h) ? raw.to_unsafe_h : nil
  end
end

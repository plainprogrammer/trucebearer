# A seat's own orders for one phase: the plain form and the endpoint behind it (spec 022 FR-2, FR-4). The form is the
# part #23 replaces; the endpoint, its partial-update meaning and its refusals stay.
class SeatOrdersController < ApplicationController
  include OrderScreen
  before_action :require_seat
  before_action :find_phase_or_stranger
  # A page or a redirect about a seat's own orders is never cached (AC-7.6). It runs after require_seat, so a stranger
  # page carries no such header, which is right: it has nothing to cache.
  before_action :own_orders_headers

  def show
    return render_revealed unless @phase.open?

    load_page
  end

  def update
    return render_revealed unless @phase.open?

    entries = order_entries
    return refuse(Seat::UNREADABLE) unless entries

    result = @seat.save_orders!(@phase, entries, submit: params[:submit] == "1")
    flash[:banner] = { "kind" => "info", "text" => result.submitted ? "Submitted." : "Orders saved." }
    redirect_to game_seat_orders_path(@game.public_id, @phase.number), status: :see_other
  rescue Seat::Refusal => error
    refuse(error.message)
  rescue Phase::Revealed
    render_revealed
  rescue Seat::Stale
    @game.seats.reset # the seat list cached for this request still has the old digest; the dead cookie must fail against the new one
    stranger!(@game)
  end

  private

  # nil when `orders` is present and is not a hash of text (AC-2.5); {} when it is absent (a submit alone, FR-2).
  def order_entries
    raw = params[:orders]
    return {} if raw.nil?
    return nil unless raw.respond_to?(:to_unsafe_h)

    hash = raw.to_unsafe_h
    hash.values.all?(String) ? hash : nil
  end

  def load_page
    @units = @phase.position.units.select { |unit| unit.power.to_s == @seat.power }.sort_by { |unit| unit.location.province.to_s }
    @stored = @seat.orders_for(@phase)
    @choices = @units.to_h { |unit| [ unit.location.province.to_s, RulesEngine.legal_orders(@phase.position, unit) ] }
  end

  def refuse(sentence)
    @refusal = sentence
    load_page
    render :show, status: :unprocessable_content
  end
end

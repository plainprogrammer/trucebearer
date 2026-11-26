# A seat's own orders for one phase: the order screen (spec 023) and the endpoint behind every pick (spec 022 FR-2). The
# endpoint, its partial-update meaning and its refusals are unchanged; the screen replaced spec 022's plain form.
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
    flash[:banner] = { "kind" => "info", "text" => "Submitted." } if params[:submit] == "1" && result.submitted
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
    @submitted = @seat.submitted?(@phase)
  end

  def refuse(sentence)
    @refusal = sentence
    load_page
    render :show, status: :unprocessable_content
  end
end

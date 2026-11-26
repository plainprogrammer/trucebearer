# Cookies, verification, the stranger response and the rate-limit helpers for every game page (spec FR-2, FR-6, FR-8).
module GameAccess
  extend ActiveSupport::Concern

  included { helper_method :orders_path_for, :picker_path_for, :own_seat_target }

  KINDS = %i[host seat].freeze
  PUBLIC_ID_SHAPE = /\A[A-Za-z0-9]{12}\z/

  private

  def cookie_name(kind, public_id) = "#{kind}_#{public_id}"

  # Signed, permanent, httponly and lax. Secure when force_ssl is on or in production, which sets it (spec FR-2, AC-11.4).
  def remember(kind, game, token)
    cookies.signed.permanent[cookie_name(kind, game.public_id)] =
      { value: token, httponly: true, same_site: :lax, secure: !!(Rails.configuration.force_ssl || Rails.env.production?) }
  end

  def find_game = Game.find_by(public_id: params[:public_id])

  def host?(game)
    token = cookies.signed[cookie_name(:host, game.public_id)]
    token.present? && game.host_token?(token)
  end

  def seat_of(game)
    token = cookies.signed[cookie_name(:seat, game.public_id)]
    token.present? ? game.seat_for(token) : nil
  end

  # The one answer for every request that has no right to a page (spec D4, FR-6). A presented cookie is deleted only
  # when it fails verification for that id; an unknown game counts as a failure. A cookie that verifies is kept.
  def stranger!(game = nil)
    @step_in = @stepped_in_page = nil # a stranger page is one answer for everyone: no bar (spec 026 D7)
    public_id = params[:public_id].to_s
    KINDS.each do |kind|
      # A path id that is not a public id never names a cookie of ours, and Rack refuses odd cookie names.
      next unless public_id.match?(PUBLIC_ID_SHAPE)

      name = cookie_name(kind, public_id)
      next if cookies[name].nil?

      valid = game && (kind == :host ? host?(game) : seat_of(game))
      cookies.delete(name) unless valid
    end
    render "strangers/show", status: :not_found
  end

  def require_host
    @game = find_game
    return stranger!(@game) unless @game && host?(@game)

    load_step_in(@game)
  end

  # A phase number is digits with no leading zero. Anything else, or a number the game doesn't have, is nil (spec 022 URLs).
  def find_phase(game)
    number = params[:number].to_s
    number.match?(/\A[1-9][0-9]*\z/) ? game.phases.find_by(number: number.to_i) : nil
  end

  # The seat a seat-scoped page acts for. On an own URL it is the cookie's seat. On a stepped-in URL (a :power in the path, never
  # in the query) it is the seat the host's active step-in names (spec 026 D2, D4).
  def require_seat
    @game = find_game
    power = request.path_parameters[:power]
    @seat = @game && (power ? stepped_in_seat(@game, power) : seat_of(@game))
    return stranger!(@game) unless @seat
    return if power || send_to_step_in(@game, @seat)

    load_step_in(@game)
  end

  # A browser that holds the host cookie and a seat other than the host's own is not that seat: it is sent to that seat's step-in
  # confirmation for the open phase, and the foreign seat cookie goes (spec 026 D5). True when it redirected.
  def send_to_step_in(game, seat)
    return false unless host?(game) && seat != game.host_seat

    cookies.delete(cookie_name(:seat, game.public_id))
    redirect_to game_step_in_path(game.public_id, seat.power, game.current_phase.number), status: :see_other
    true
  end

  def step_in_cookie_name(public_id) = "step_in_#{public_id}"

  # Signed, httponly, lax, and no expiry: a session cookie. The value is the row's id and nothing else (spec 026 D2).
  def remember_step_in(game, row)
    cookies.signed[step_in_cookie_name(game.public_id)] =
      { value: row.id, httponly: true, same_site: :lax, secure: !!(Rails.configuration.force_ssl || Rails.env.production?) }
  end

  # The active step-in of this request, or nil: the host cookie is valid, the cookie verifies and names a row, the row is of this
  # game and still active (spec 026 D2). It never raises and never sets or deletes the cookie.
  def active_step_in(game)
    return nil unless host?(game)

    id = cookies.signed[step_in_cookie_name(game.public_id)]
    row = id.is_a?(Integer) ? StepIn.includes(:phase, :seat).find_by(id: id) : nil
    row if row && row.phase.game_id == game.id && row.seat.game_id == game.id && row.active?
  end

  # Sets @step_in, which the layout draws the bar from, for a verified host (spec 026 D7).
  def load_step_in(game) = (@step_in = active_step_in(game))

  # The seat of a stepped-in URL: the host's active step-in is for this power, or nil (D2, D4).
  def stepped_in_seat(game, power)
    row = active_step_in(game)
    return nil unless row && row.seat.power == power

    @step_in = row
    @stepped_in_page = true
    row.seat
  end

  # Where "your own seat" is: the seat page, or the host page when this browser holds no seat of its own (D7).
  # The host's own seat counts, not a foreign seat cookie, which D5 sends to a confirmation.
  def own_seat_target(game = @game) = seat_of(game) == game.host_seat ? game_path(game.public_id) : game_host_path(game.public_id)

  # The order screen's address for the seat this page acts for: the own URL, or the stepped-in one (spec 026 D4).
  # The partials pass their own `game` (the style guide has no @game); a page's own game is the default.
  def orders_path_for(number, game = @game)
    return game_seat_orders_path(game.public_id, number) unless @stepped_in_page

    game_step_in_orders_path(game.public_id, @seat.power, number)
  end

  def picker_path_for(number, province, game: @game, **query)
    return game_order_picker_path(game.public_id, number, province, **query) unless @stepped_in_page

    game_step_in_picker_path(game.public_id, @seat.power, number, province, **query)
  end

  def too_many_tries = render("strangers/too_many", status: :too_many_requests)

  # IPv4 by address, IPv6 by its first 64 bits (spec FR-8). An IPv4-mapped IPv6 address counts as its IPv4 address.
  def client_key
    address = IPAddr.new(request.remote_ip)
    address = address.native
    address.ipv6? ? address.mask(64).to_s : address.to_s
  rescue IPAddr::InvalidAddressError
    request.remote_ip.to_s
  end
end

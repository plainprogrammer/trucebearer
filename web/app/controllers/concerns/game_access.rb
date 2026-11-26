# Cookies, verification, the stranger response and the rate-limit helpers for every game page (spec FR-2, FR-6, FR-8).
module GameAccess
  extend ActiveSupport::Concern

  KINDS = %i[host seat].freeze
  TOO_MANY = "Too many tries. Wait a few minutes and try again."
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
    stranger!(@game) unless @game && host?(@game)
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

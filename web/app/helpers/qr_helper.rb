module QrHelper
  # The QR code as one inline SVG made on the server (spec FR-4). The gem writes an XML prolog and a fill attribute;
  # both are removed, so the stylesheet colors the code from the text token. The viewBox carries a four-module quiet zone.
  def qr_code_svg(url, label)
    svg = RQRCode::QRCode.new(url, level: :m).as_svg(
      offset: 4, module_size: 1, use_path: true, viewbox: true, standalone: true,
      svg_attributes: { role: "img", "aria-label": label, class: "qr-card__code" }
    )
    svg.sub(/<\?xml[^>]*\?>/, "").sub(/ fill="[^"]*"/, "").html_safe
  rescue RQRCodeCore::QRCodeRunTimeError => error
    Rails.logger.error("QR code could not be made: #{error.message}")
    nil
  end

  # The card: the code, a caption slot (the join code or a power badge), and the link as text under it.
  def qr_card(url, label:, caption: nil)
    tag.div(class: "qr-card") do
      safe_join([ qr_code_svg(url, label), (tag.div(caption, class: "qr-card__caption") if caption),
                  tag.p(url, class: "qr-card__link") ].compact)
    end
  end
end

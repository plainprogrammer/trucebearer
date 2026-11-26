# The status list: a persistent polite live region around the rows. A stream message morphs the inside of this element, so the
# element itself is never replaced and only a row whose text changed is announced (spec 024 D6).
module SeatStatusHelper
  def seat_status(statuses, id: "seat-status")
    tag.ul(render("shared/seat_status", statuses: statuses), id: id, class: "seat-status", aria: { live: "polite" })
  end
end

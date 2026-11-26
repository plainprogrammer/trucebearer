# The time of a step-in or a reissue as the table reads it (spec 026 D6): the 12-hour clock with the zone's abbreviation, in the zone named by
# TRUCEBEARER_TIME_ZONE, or UTC. It is read each time a page is drawn, so nothing is fixed at boot.
module StepInsHelper
  ZONE_VARIABLE = "TRUCEBEARER_TIME_ZONE".freeze

  def table_zone = ActiveSupport::TimeZone[ENV[ZONE_VARIABLE].to_s.strip] || ActiveSupport::TimeZone["UTC"]

  def table_time(time)
    tag.time(time.in_time_zone(table_zone).strftime("%-l:%M %p %Z"), datetime: time.utc.iso8601)
  end
end

# The origins, besides the app's own address, that may open the live-update socket (spec 024 D5). Read from one variable.
# No dependency on Rails: production.rb requires this file before the autoloader exists.
module CableOrigins
  ENV_NAME = "TRUCEBEARER_CABLE_ORIGINS".freeze

  # "https://a.example/, https://b.example" becomes ["https://a.example", "https://b.example"]. Blank entries and repeats are
  # dropped, and each origin is lowercased, because that is how a browser writes the Origin header it sends.
  def self.parse(value)
    value.to_s.split(/[\s,]+/).map { |origin| origin.chomp("/").downcase }.reject(&:empty?).uniq
  end
end

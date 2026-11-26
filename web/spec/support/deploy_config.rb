require "erb"
require "yaml"

# Reads config/deploy.yml the way Kamal does: the file goes through ERB first, with the environment of the machine that runs
# bin/kamal, and the result is parsed as YAML. A spec passes the variables it wants, so the real ones are never read.
module DeployConfig
  PATH = Rails.root.join("config/deploy.yml")
  VARIABLES = %w[ TRUCEBEARER_HOST TRUCEBEARER_CABLE_ORIGINS ].freeze

  # Renders deploy.yml with the two variables it reads set to exactly `env` (the others unset), and puts the real values back.
  # Only those two are touched, because other threads of the suite read the rest of ENV.
  def self.load(env = {})
    env = env.transform_keys(&:to_s)
    unknown = env.keys - VARIABLES
    raise ArgumentError, "deploy.yml reads only #{VARIABLES.join(', ')}, not #{unknown.join(', ')}" if unknown.any?

    saved = VARIABLES.to_h { |name| [ name, ENV[name] ] }
    VARIABLES.each { |name| ENV.delete(name) }
    env.each { |name, value| ENV[name] = value.to_s }
    YAML.unsafe_load(ERB.new(File.read(PATH), trim_mode: "-").result)
  ensure
    saved&.each { |name, value| value.nil? ? ENV.delete(name) : ENV[name] = value }
  end
end

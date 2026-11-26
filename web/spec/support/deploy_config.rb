require "erb"
require "yaml"

# Reads config/deploy.yml the way Kamal does: the file goes through ERB first, with the environment of the machine that runs
# bin/kamal, and the result is parsed as YAML. A spec passes the environment it wants, so nothing here reads the real one.
module DeployConfig
  PATH = Rails.root.join("config/deploy.yml")

  # Renders deploy.yml with ENV temporarily set to exactly `env`, and restores the real ENV afterwards.
  def self.load(env = {})
    original = ENV.to_h
    ENV.replace(env.transform_keys(&:to_s).transform_values(&:to_s))
    YAML.unsafe_load(ERB.new(File.read(PATH), trim_mode: "-").result)
  ensure
    ENV.replace(original)
  end
end

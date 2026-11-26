# frozen_string_literal: true

require "open3"
require_relative "error"

module ReleaseTools
  # Regenerates Gemfile.lock for the Gemfile in a folder, offline. The lock
  # records the gem's own version, so every release changes it.
  module Lock
    module_function

    def call(dir)
      output, status = Open3.capture2e(clean_env(dir), "bundle", "lock", "--local", chdir: dir)
      return if status.success?

      raise Error, "bundle lock --local failed. If a gem is missing from the local cache, " \
                   "run bundle install in #{dir} and try again.\n#{output.strip}"
    end

    # Drops any Bundler settings inherited from the caller (for example when
    # run under `bundle exec`) so the lock is made for this folder's Gemfile.
    def clean_env(dir)
      inherited = ENV.keys.grep(/\ABUNDLE|\ABUNDLER/).to_h { |name| [name, nil] }
      inherited.merge("RUBYOPT" => nil, "RUBYLIB" => nil, "BUNDLE_GEMFILE" => File.join(dir, "Gemfile"))
    end
  end
end

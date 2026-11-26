# frozen_string_literal: true

require_relative "error"

module ReleaseTools
  # Reads, bumps and rewrites the gem version in lib/trucebearer/adjudicator/version.rb.
  module Version
    LINE = /^(\s*VERSION\s*=\s*)"([^"]*)"/
    STRICT = /\A(0|[1-9]\d*)(\.(0|[1-9]\d*)){2}\z/
    BUMPS = %w[major minor patch].freeze

    module_function

    def read(file_text)
      match = LINE.match(file_text) or raise Error, "No VERSION line found in the version file."
      match[2]
    end

    # `arg` is major, minor, patch, or an explicit X.Y.Z higher than `current`.
    def resolve(arg, current)
      raise Error, "The current version #{current.inspect} is not X.Y.Z." unless STRICT.match?(current)
      return bump(arg, current) if BUMPS.include?(arg)

      raise Error, "Give major, minor, patch or a version like X.Y.Z (got #{arg.inspect})." unless STRICT.match?(arg)
      raise Error, "Version #{arg} must be higher than the current version #{current}." unless (parts(arg) <=> parts(current)) == 1

      arg
    end

    def rewrite_file(file_text, version)
      file_text.sub(LINE) { "#{Regexp.last_match(1)}\"#{version}\"" }
    end

    def bump(kind, current)
      major, minor, patch = parts(current)
      case kind
      when "major" then "#{major + 1}.0.0"
      when "minor" then "#{major}.#{minor + 1}.0"
      else "#{major}.#{minor}.#{patch + 1}"
      end
    end

    def parts(version)
      version.split(".").map(&:to_i)
    end
  end
end

# frozen_string_literal: true

require "open3"
require_relative "error"

module ReleaseTools
  # The few git commands a release needs, run against the repository that
  # holds `dir`. There is deliberately no push here: a release never pushes.
  class Git
    # Variables that would point git at some other repository or index.
    SCRUBBED = %w[GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE].freeze

    # Every command run so far, as argument arrays.
    attr_reader :commands

    # `env` and `config` (git -c key=value) let specs isolate git from the
    # user's own configuration.
    def initialize(dir, env: {}, config: {})
      @dir = dir
      @env = SCRUBBED.to_h { |name| [name, nil] }.merge(env)
      @config = config.flat_map { |key, value| ["-c", "#{key}=#{value}"] }
      @commands = []
    end

    # Lines of `git status --porcelain` for the whole repository, untracked files included.
    def status_lines = run("status", "--porcelain").lines.map(&:chomp)

    def branch = run("rev-parse", "--abbrev-ref", "HEAD").strip

    def tag_exists?(name) = !run("tag", "--list", name).strip.empty?

    def add(paths) = run("add", "--", *paths)

    def commit(message) = run("commit", "-m", message)

    def tag(name, message) = run("tag", "-a", name, "-m", message)

    # Puts files back as they are in HEAD, in the index and the working tree.
    def restore(paths) = run("checkout", "HEAD", "--", *paths)

    private

    def run(*args)
      command = [*@config, "-C", @dir, *args]
      @commands << command
      output, status = Open3.capture2e(@env, "git", *command)
      raise Error, "git #{args.first} failed: #{output.strip}" unless status.success?

      output
    end
  end
end

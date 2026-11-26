# frozen_string_literal: true

require_relative "error"

module ReleaseTools
  # Rewrites CHANGELOG.md text for a release. Pure string work: no files, no git.
  module Changelog
    UNRELEASED = /^## Unreleased[ \t]*$/
    SECTION = /^## /
    SUBSECTION = /^### /
    FRESH_UNRELEASED = "## Unreleased\n\n### Added\n\n### Changed\n\n### Fixed"

    module_function

    def unreleased_empty?(text)
      entries(*split(text)[1]).empty?
    end

    # Moves the Unreleased entries under "## VERSION (DATE)" and puts a fresh,
    # empty Unreleased section above it. Subsections without entries are left
    # out of the released section.
    def release(text, version:, date:)
      before, body, after = split(text)
      raise Error, "Version #{version} already has a heading in CHANGELOG.md." if text.match?(/^## #{Regexp.escape(version)} \(/)

      parts = entries(*body)
      raise Error, "The Unreleased section is empty; there is nothing to release." if parts.empty?

      released = ["## #{version} (#{date.strftime('%Y-%m-%d')})", *parts]
      [before, FRESH_UNRELEASED, released.join("\n\n"), after].reject(&:empty?).join("\n\n") << "\n"
    end

    # Returns [text before Unreleased, Unreleased body lines, text after it],
    # each stripped of surrounding blank lines.
    def split(text)
      lines = text.lines
      start = lines.index { |line| UNRELEASED.match?(line) } or raise Error, "CHANGELOG.md has no Unreleased section."
      stop = lines.index.with_index { |line, i| i > start && SECTION.match?(line) } || lines.size
      [lines[0...start].join.strip, lines[(start + 1)...stop], lines[stop..].join.strip]
    end

    # The blocks of the Unreleased body that carry entries, as strings. A block
    # is the loose text before the first subsection, or one "###" subsection.
    def entries(*body_lines)
      blocks = body_lines.flatten.slice_before { |line| SUBSECTION.match?(line) }.map { |block| block.join.strip }
      blocks.reject { |block| block.empty? || block.lines.all? { |line| line.strip.empty? || SUBSECTION.match?(line) } }
    end
  end
end

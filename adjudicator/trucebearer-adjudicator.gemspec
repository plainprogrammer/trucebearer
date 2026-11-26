# frozen_string_literal: true

require_relative "lib/trucebearer/adjudicator/version"

Gem::Specification.new do |spec|
  spec.name = "trucebearer-adjudicator"
  spec.version = Trucebearer::Adjudicator::VERSION
  spec.authors = ["Trucebearer contributors"]

  spec.summary = "The rules engine behind Trucebearer."
  spec.description = "Checks orders and adjudicates each phase of a game turn. " \
                     "Plain Ruby, with maps as data and no dependency on Rails."
  spec.homepage = "https://github.com/plainprogrammer/trucebearer"
  spec.license = "AGPL-3.0-or-later"

  # Taken from the repository root, which pins the Ruby for both sides.
  spec.required_ruby_version = ">= #{File.read(File.expand_path("../.ruby-version", __dir__)).strip}"

  # The name stays off public registries until it is final, so pushing is blocked.
  spec.metadata["allowed_push_host"] = "https://rubygems.invalid"
  spec.metadata["source_code_uri"] = "#{spec.homepage}/tree/main/adjudicator"
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/adjudicator/CHANGELOG.md"

  spec.files = Dir.chdir(__dir__) do
    Dir["{lib,data}/**/*", "LICENSE", "README.md", "CHANGELOG.md"].select { |path| File.file?(path) }
  end
  spec.require_paths = ["lib"]
end

require "spec_helper"

# Every gem call lives in app/models/rules_engine.rb (spec 019, FR-7). This check is textual: a
# constant name built from pieces would pass it, so review still matters.
RSpec.describe "The gem boundary (AC-2.7, AC-2.8, spec 029 AC-3.1, AC-3.5)" do
  root = File.expand_path("../..", __dir__)
  boundary = File.join(root, "app/models/rules_engine.rb")

  gem_patterns = [
    /\bTrucebearer\s*::/,
    /\bTrucebearer\s*\.\s*[a-z_]/,
    /(?<![A-Za-z0-9_])TA(?![A-Za-z0-9_])/,
    /require\s*\(?\s*["']trucebearer/
  ]

  app_files = Dir.glob(File.join(root, "{app,lib,config,db,bin}/**/*"), File::FNM_DOTMATCH)
                 .reject { |p| p.end_with?(".enc") }
                 .push(File.join(root, "config.ru"), File.join(root, "Rakefile"))
  spec_files = Dir.glob(File.join(root, "spec/**/*"), File::FNM_DOTMATCH).reject { |p| p == __FILE__ }

  scan = lambda do |paths, patterns|
    paths.select { |p| File.file?(p) && p != boundary }.filter_map do |path|
      bytes = File.binread(path)
      next if bytes.include?("\0") # fonts and images

      text = bytes.force_encoding("UTF-8").scrub
      hit = patterns.find { |pattern| text.match?(pattern) }
      "#{path.delete_prefix("#{root}/")}: #{hit.source}" if hit
    end
  end

  it "flags what it should and spares what it should not (AC-2.8)" do
    flagged = [ "Trucebearer::Adjudicator", "Trucebearer.const_get(:X)", "TA::Order", "x = TA.check(a, b)",
                'require "trucebearer/adjudicator"' ]
    spared = [ "Trucebearer", '"description": "Trucebearer."', "Trucebearer. Next", "TABLE", "DATA", "STATUS",
               "RulesEngine::InvalidInput", "RulesEngine.check" ]
    flagged.each { |s| expect(gem_patterns.any? { |p| s.match?(p) }).to be(true), s }
    spared.each { |s| expect(gem_patterns.any? { |p| s.match?(p) }).to be(false), s }
  end

  it "finds files to scan" do
    expect(app_files.count { |p| File.file?(p) }).to be > 10
    expect(spec_files.count { |p| File.file?(p) }).to be > 5
  end

  it "keeps every gem call in app/models/rules_engine.rb (AC-2.7)" do
    expect(scan.call(app_files + spec_files, gem_patterns)).to be_empty
  end

  # Spec 029 AC-3.1: nothing in the app names the stand-in or its note. Unlike the scan above, this one includes the boundary
  # file. The pattern is case-sensitive and not hyphen-aware on purpose: styleguide_helper.rb has an unrelated "Stand-ins" comment.
  it "names the stand-in nowhere under app, lib, config, db or bin (AC-3.1)" do
    pattern = /StandIn|stand_in|practice[-_]note/
    hits = app_files.select { |p| File.file?(p) && !File.binread(p).include?("\0") }
                    .select { |p| File.binread(p).force_encoding("UTF-8").scrub.match?(pattern) }
    expect(hits.map { |p| p.delete_prefix("#{root}/") }).to be_empty
    expect(File.read(boundary)).not_to match(/stand-in/i)
  end

  # Spec 029 AC-3.5: no stand-in under spec/, and no stub that answers adjudicate with a made-up result. Stubs that raise or
  # wrap the real engine are allowed.
  it "keeps no stand-in and no made-up adjudication under spec (AC-3.5)" do
    expect(File.exist?(File.join(root, "spec/models/rules_engine_stand_in_spec.rb"))).to be(false)
    hits = spec_files.select { |p| File.file?(p) && !File.binread(p).include?("\0") }
                     .select { |p| File.binread(p).force_encoding("UTF-8").scrub.match?(/StandIn|receive\(:adjudicate\)\.and_return/) }
    expect(hits.map { |p| p.delete_prefix("#{root}/") }).to be_empty
  end
end

require "spec_helper"
require "digest"
require_relative "../support/stylesheets"

RSpec.describe "The self-hosted monospace (AC-6.2, 8.1 to 8.4)" do
  root = File.expand_path("../..", __dir__)
  fonts = File.join(root, "app/assets/fonts")
  file = "IBMPlexMono-Medium-Latin1.woff2"
  face = /@font-face\s*\{[^{}]*\}/m

  let(:sheets) { Stylesheets.files.to_h { |f| [ File.basename(f), Stylesheets.read(f) ] } }
  let(:notice) { File.read(File.join(root, "NOTICE")) }

  it "holds exactly one font file and the license beside it (AC-8.3)" do
    expect(Dir.children(fonts)).to match_array([ file, "OFL.txt" ])
    expect(File.read(File.join(fonts, "OFL.txt"))).to include("SIL OPEN FONT LICENSE Version 1.1")
  end

  it "records the file's SHA-256, source and license in NOTICE (AC-8.3, 8.4)" do
    sha = Digest::SHA256.file(File.join(fonts, file)).hexdigest
    expect(notice).to include("SHA-256: #{sha}")
    expect(notice).to include("IBM Plex Mono")
    expect(notice).to include("https://registry.npmjs.org/@ibm/plex-mono/-/plex-mono-2.5.0.tgz")
    expect(notice).to include("SIL Open Font License")
  end

  it "carries the CC BY-SA 4.0 notice for the inlined artwork (AC-8.4)" do
    expect(notice).to include("app/assets/images/icons")
    expect(notice).to include("CC BY-SA 4.0")
  end

  it "has exactly one @font-face, whose one url() is a bare file name, with swap and a weight range (AC-6.2)" do
    faces = sheets.values.flat_map { |css| css.scan(face) }
    expect(faces.size).to eq(1)
    block = faces.first
    expect(block.scan(/url\(/i).size).to eq(1)
    expect(block).to match(/url\(\s*"#{Regexp.escape(file)}"\s*\)/) # no scheme, no host, no folder
    expect(block).to match(/font-family:\s*"Plex Mono"/)
    expect(block).to match(/font-display:\s*swap/)
    expect(block).to match(/font-weight:\s*400 700/)
    expect(sheets.values.join("\n").gsub(face, "")).not_to match(/url\(/i)
  end

  it "reads --font-mono only in the .mono rule, which uses the regular weight token (AC-8.2)" do
    css = sheets.values.join("\n")
    readers = Stylesheets.rules(css).select { |_, body| body.include?("var(--font-mono)") }
    expect(readers.map(&:first)).to eq([ ".mono" ])
    expect(readers.first.last).to include("font-weight: var(--weight-regular)")
  end
end

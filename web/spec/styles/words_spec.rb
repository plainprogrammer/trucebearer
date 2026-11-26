require "spec_helper"

RSpec.describe "Words and names (AC-6.5)" do
  root = File.expand_path("../..", __dir__)
  # Built from pieces so this file does not contain the words it forbids.
  forbidden = Regexp.new("diplo" + "macy|\\bd" + "ip[a-z]*", Regexp::IGNORECASE)

  paths = (Dir[File.join(root, "{app,lib,spec}/**/*")] + [ File.join(root, "config/routes.rb") ])
          .select { |p| File.file?(p) }
          .reject { |p| p == __FILE__ }

  it "finds files to scan" do
    expect(paths.size).to be > 10
  end

  it "has no forbidden word in any file name or content" do
    hits = paths.filter_map do |path|
      relative = path.delete_prefix("#{root}/")
      next "#{relative}: file name" if relative.match?(forbidden)
      next if File.extname(path).match?(/\.(png|jpe?g|gif|ico|webp|woff2?)\z/i)
      "#{relative}: content" if File.binread(path).force_encoding("UTF-8").scrub.match?(forbidden)
    end
    expect(hits).to be_empty, hits.join("\n")
  end
end

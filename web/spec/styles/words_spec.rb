require "spec_helper"

RSpec.describe "Words and names (AC-6.5)" do
  root = File.expand_path("../..", __dir__)
  # Built from pieces so this file does not contain the words it forbids.
  # The full word in any case, a word starting with the three letters (after a
  # non-letter, so "x_..." counts), and the three letters inside a CamelCase name.
  forbidden = Regexp.new("(?i:diplo" + "macy)|(?<![A-Za-z])[Dd][Ii][Pp]|(?<=[a-z])D" + "ip")

  paths = (Dir.glob(File.join(root, "{app,lib,spec}/**/*"), File::FNM_DOTMATCH) + [ File.join(root, "config/routes.rb") ])
          .select { |p| File.file?(p) }
          .reject { |p| p == __FILE__ }

  it "catches the word in the forms the root rules forbid" do
    [ "Diplo" + "macy", "TrucebearerD" + "ip", "x_d" + "ip", "d" + "ipped" ].each do |sample|
      expect(sample).to match(forbidden)
    end
    expect("adipose").not_to match(forbidden)
  end

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

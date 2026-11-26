require "spec_helper"

RSpec.describe "The inlined artwork (AC-7.8, 7.9)" do
  web = File.expand_path("../..", __dir__)
  masters = File.expand_path("../assets/icons", web)
  copies = File.join(web, "app/assets/images/icons")
  drawings = %w[army army-small fleet fleet-small supply-center]

  it "can see the masters (the whole repository is checked out locally and in CI)" do
    expect(Dir.exist?(masters)).to be(true)
  end

  drawings.each do |name|
    it "keeps #{name}.svg identical to its master" do
      expect(File.binread(File.join(copies, "#{name}.svg"))).to eq(File.binread(File.join(masters, "#{name}.svg")))
    end
  end

  it "has a copy for every master drawing and no other file" do
    expect(Dir.children(copies).sort).to eq(Dir.children(masters).grep(/\.svg\z/).sort)
    expect(Dir.children(copies).sort).to eq(drawings.map { |n| "#{n}.svg" }.sort)
  end

  it "never reads the root assets folder at run time" do
    files = Dir.glob(File.join(web, "{app,lib,config}/**/*")).select { |f| File.file?(f) && File.extname(f) != ".woff2" }
    hits = files.select { |f| File.binread(f).force_encoding("UTF-8").scrub.include?("assets/icons") }
    expect(hits).to be_empty, hits.join(", ")
  end

  it "draws an svg only in the icon helper (AC-7.8)" do
    files = Dir.glob(File.join(web, "app/{views,helpers}/**/*")).select { |f| File.file?(f) }
    hits = files.select { |f| File.read(f).include?("<svg") }.map { |f| f.delete_prefix("#{web}/") }
    expect(hits - [ "app/helpers/icon_helper.rb" ]).to be_empty
  end
end

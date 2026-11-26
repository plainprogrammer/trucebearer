require "rails_helper"

RSpec.describe JoinCode do
  it "has 22 characters and none of the look-alikes" do
    expect(JoinCode::ALPHABET.size).to eq(22)
    expect(JoinCode::ALPHABET & %w[0 O Q 1 I L 2 Z 5 S 8 B U V]).to be_empty
  end

  it "makes six-character codes from the alphabet" do
    codes = Array.new(1000) { JoinCode.generate }
    expect(codes).to all(match(JoinCode::SHAPE))
  end

  it "takes every character from SecureRandom" do
    allow(SecureRandom).to receive(:random_number).with(22).and_return(0)
    expect(JoinCode.generate).to eq("AAAAAA")
  end

  it "reads a typed code forgivingly and never converts one character into another" do
    expect(JoinCode.normalize(" acd-efg ")).to eq("ACDEFG")
    expect(JoinCode.normalize("acd efg")).to eq("ACDEFG")
    expect(JoinCode.normalize("ACDEF0")).to be_nil # zero is not in the alphabet, and is not turned into O
    expect(JoinCode.normalize("ACDEF")).to be_nil
    expect(JoinCode.normalize("ACDEFGH")).to be_nil
    expect(JoinCode.normalize("AC.EFG")).to be_nil
    expect(JoinCode.normalize(nil)).to be_nil
  end

  it "never turns a character that upcases to several letters into valid characters" do
    # Six visible characters, the first an ff ligature; a full Unicode upcase would make it two letters and a valid code.
    expect(JoinCode.normalize("\uFB00CDEG")).to be_nil
  end

  it "splits a code into two groups of three" do
    expect(JoinCode.groups("ACDEFG")).to eq(%w[ACD EFG])
  end
end

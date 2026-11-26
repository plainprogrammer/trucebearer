require "rails_helper"

# Spec 026 D6, AC-6.5: the time of a step-in as the table reads it.
RSpec.describe StepInsHelper, type: :helper do
  around do |example|
    original = ENV["TRUCEBEARER_TIME_ZONE"]
    example.run
  ensure
    ENV["TRUCEBEARER_TIME_ZONE"] = original
  end

  let(:time) { Time.utc(2026, 11, 26, 20, 42) }

  def parsed(html) = Nokogiri::HTML5.fragment(html).at_css("time")

  it "reads in UTC with the abbreviation when no zone is set" do
    ENV.delete("TRUCEBEARER_TIME_ZONE")
    element = parsed(helper.table_time(time))

    expect(element.text).to eq("8:42 PM UTC")
    expect(element["datetime"]).to eq("2026-11-26T20:42:00Z")
  end

  it "reads in the zone the variable names, with its abbreviation" do
    ENV["TRUCEBEARER_TIME_ZONE"] = "America/New_York"

    expect(parsed(helper.table_time(time)).text).to eq("3:42 PM EST")
    expect(parsed(helper.table_time(Time.utc(2026, 6, 26, 20, 42))).text).to eq("4:42 PM EDT")
  end

  it "falls back to UTC for an unknown or blank name" do
    [ "Not/AZone", "", "  " ].each do |name|
      ENV["TRUCEBEARER_TIME_ZONE"] = name
      expect(parsed(helper.table_time(time)).text).to eq("8:42 PM UTC"), name.inspect
    end
  end

  it "shows a morning hour without a leading zero and AM" do
    ENV.delete("TRUCEBEARER_TIME_ZONE")

    expect(parsed(helper.table_time(Time.utc(2026, 11, 26, 9, 5))).text).to eq("9:05 AM UTC")
  end
end

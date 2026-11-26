require "rails_helper"

# Spec 024 D6, FR-1: the status list, its live region and its rows.
RSpec.describe SeatStatusHelper, type: :helper do
  let(:statuses) do
    RulesEngine.powers.map { |power| Phase::Status.new(power: power.id.to_s, submitted: power.id.to_s == "england") }
  end

  def page(html) = Nokogiri::HTML5.fragment(html)

  it "writes a persistent polite live list with seven rows in power order" do
    list = page(helper.seat_status(statuses)).at_css("ul")

    expect(list[:id]).to eq("seat-status")
    expect(list[:class]).to eq("seat-status")
    expect(list["aria-live"]).to eq("polite")
    expect(list["role"]).to be_nil
    expect(list.css("> li").map { |row| row["data-power"] }).to eq(statuses.map(&:power))
  end

  it "gives each row the power's badge and its state in words" do
    rows = page(helper.seat_status(statuses)).css("li.seat-status__row")
    england = rows.find { |row| row["data-power"] == "england" }
    france = rows.find { |row| row["data-power"] == "france" }

    expect(england.at_css(".power-badge--england").text).to eq("England")
    expect(england.at_css(".seat-status__state").text).to eq("Submitted")
    expect(france.at_css(".seat-status__state").text).to eq("Not submitted")
    expect(rows.map { |row| row.element_children.size }.uniq).to eq([ 2 ])
  end

  it "takes the id from the caller, so a page can show several lists" do
    expect(page(helper.seat_status(statuses, id: "sample-2")).at_css("ul")[:id]).to eq("sample-2")
  end

  it "renders the same rows as the partial a stream message uses" do
    inner = page(helper.seat_status(statuses)).at_css("ul").inner_html
    partial = ApplicationController.render(partial: "shared/seat_status", locals: { statuses: statuses })

    expect(inner.gsub(/\s+/, " ").strip).to eq(partial.gsub(/\s+/, " ").strip)
  end
end

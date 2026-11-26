require "rails_helper"

# Spec 023 AC-3.1: a pick is saved through the one endpoint and Seat#save_orders!; nothing else in the app writes a seat's orders.
RSpec.describe "Who saves orders" do
  it "has no other write to saved orders than the orders endpoint and the reissue (AC-3.1)" do
    files = Dir.glob(Rails.root.join("app/**/*")).select { |f| File.file?(f) && !f.match?(/\.(png|svg|woff2?|ico)\z/) }
    callers = files.select { |f| File.binread(f).include?("save_orders!") }.map { |f| File.basename(f) } # views and helpers too
    expect(callers).to match_array(%w[seat.rb seat_orders_controller.rb])
  end
end

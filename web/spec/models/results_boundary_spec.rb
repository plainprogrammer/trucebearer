require "rails_helper"

# Spec 025 AC-5.6: the results code reads the stored adjudication and never a saved order.
RSpec.describe "The results code stays away from saved orders" do
  it "names neither SavedOrder, saved_orders nor orders_for" do
    files = %w[app/models/phase_results.rb app/helpers/outcome_helper.rb app/controllers/results_controller.rb app/controllers/host_results_controller.rb] +
            Dir[Rails.root.join("app/views/{results,host_results}/*").to_s].map { |path| path.delete_prefix("#{Rails.root}/") }

    expect(files.size).to be > 8
    files.each { |path| expect(File.read(Rails.root.join(path))).not_to match(/SavedOrder|saved_orders|orders_for/), path }
  end
end

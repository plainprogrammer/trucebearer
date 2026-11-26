require "rails_helper"

# Spec 024 AC-2.7, AC-3.7: who writes submissions, who calls the broadcast, who may name the cable. A text scan is a
# tripwire, not a proof: review still matters.
RSpec.describe "Who writes and broadcasts the status" do
  files = Dir.glob(Rails.root.join("{app,lib}/**/*")).select { |f| File.file?(f) && !f.match?(/\.(png|svg|woff2?|ico)\z/) }
  text = ->(path) { File.binread(path).force_encoding("UTF-8").scrub }
  rel = ->(path) { path.delete_prefix("#{Rails.root}/") }
  named = ->(pattern) { files.select { |f| text.call(f).match?(pattern) }.map(&rel) }
  # Code only: full-line comments are not scanned, so a sentence may use the plain word.
  code = ->(path) { text.call(path).lines.reject { |line| line.strip.start_with?("#") }.join.gsub(/<%#.*?%>/m, "") }

  it "writes submissions only in Seat (AC-2.7a)" do
    writes = /Submission\.(?:create|new|delete|destroy)|\bsubmissions\.(?:create|find_or_create_by|build|destroy|delete)|submissions\.where\([^)]*\)\.(?:destroy_all|delete_all)/

    expect(named.call(writes)).to eq([ "app/models/seat.rb" ])
  end

  it "mentions submissions elsewhere only as the associations and Phase's two readers (AC-2.7a)" do
    mentions = files.flat_map { |f| text.call(f).lines.grep(/\bsubmissions\b/).map { |line| [ rel.call(f), line.strip ] } }
    other = mentions.reject { |path, line| path == "app/models/seat.rb" || line.match?(/has_many :submissions, dependent: :destroy/) }

    expect(other.map(&:first).uniq - [ "app/models/phase.rb" ]).to be_empty
    expect(other.select { |path, _| path == "app/models/phase.rb" }.map(&:last).grep(/\.(?:create|destroy|delete)/)).to be_empty
  end

  it "calls broadcast_seat_status only from Game, Seat#save_orders! and Phase#reveal! (AC-2.7b)" do
    expect(named.call(/broadcast_seat_status/)).to match_array(%w[app/models/game.rb app/models/seat.rb app/models/phase.rb])
    expect(text.call(Rails.root.join("app/models/seat.rb").to_s)[/def save_orders!.*?\n  end\n/m]).to include("broadcast_seat_status")
    expect(text.call(Rails.root.join("app/models/phase.rb").to_s)[/def reveal!.*?\n  end\n/m]).to include("broadcast_seat_status")
    expect(text.call(Rails.root.join("app/models/game.rb").to_s)[/def reissue_seat!.*?\n  end\n/m]).to include("broadcast_seat_status")
  end

  it "names the cable and any other broadcast only inside Game#broadcast_seat_status (AC-2.7c)" do
    cable = /Turbo::StreamsChannel|ActionCable|\.broadcasts?\b|\bbroadcast_(?!seat_status\b)\w+/
    naming = files.select { |f| code.call(f).match?(cable) }.map(&rel)
    outside = code.call(Rails.root.join("app/models/game.rb").to_s).sub(/def broadcast_seat_status.*?\n  end\n/m, "")

    expect(naming).to eq([ "app/models/game.rb" ])
    expect(outside).not_to match(cable)
  end

  it "keeps the status code away from saved orders (AC-3.7)" do
    source = lambda do |path, pattern = nil|
      body = File.read(Rails.root.join(path))
      pattern ? body[pattern] : body
    end
    status_code = [ source.call("app/views/shared/_seat_status.html.erb"), source.call("app/helpers/seat_status_helper.rb"),
                    source.call("app/models/game.rb", /def broadcast_seat_status.*?\n  end\n/m),
                    source.call("app/models/phase.rb", /def seat_statuses.*?\n  end\n/m) ]

    expect(status_code).to all(be_present)
    expect(status_code.join).not_to match(/SavedOrder|saved_orders?|orders_for/)
  end
end

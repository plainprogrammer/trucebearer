require "rails_helper"

# Spec 024 AC-2.7, AC-3.7: who writes submissions, who calls the broadcast, who may name the cable. A text scan is a
# tripwire, not a proof: review still matters.
RSpec.describe "Who writes and broadcasts the status" do
  channels = %w[app/channels/seat_status_channel.rb app/channels/results_channel.rb]
  files = Dir.glob(Rails.root.join("{app,lib}/**/*")).select { |f| File.file?(f) && !f.match?(/\.(png|svg|woff2?|ico)\z/) }
  text = ->(path) { File.binread(path).force_encoding("UTF-8").scrub }
  rel = ->(path) { path.delete_prefix("#{Rails.root}/") }
  named = ->(pattern) { files.select { |f| text.call(f).match?(pattern) }.map(&rel) }
  # Code only: full-line comments are not scanned, so a sentence may use the plain word.
  code = ->(path) { text.call(path).lines.reject { |line| line.strip.start_with?("#") }.join.gsub(/<%#.*?%>/m, "") }

  it "writes submissions only in Seat, and names the Submission class only in its own file (AC-2.7a)" do
    writes = /\bsubmissions\.(?:create|find_or_create_by|build|new|destroy|delete|insert|upsert|update)|submissions\.where\([^)]*\)\.(?:destroy_all|delete_all|update_all)/

    expect(named.call(/\bSubmission\b/)).to eq([ "app/models/submission.rb" ])
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
    # And nowhere else: one call in Seat, one in Phase, the definition and one call in Game.
    calls = %w[app/models/seat.rb app/models/phase.rb app/models/game.rb].to_h { |path| [ path, code.call(Rails.root.join(path).to_s).scan("broadcast_seat_status").size ] }
    expect(calls).to eq("app/models/seat.rb" => 1, "app/models/phase.rb" => 1, "app/models/game.rb" => 2)
  end

  it "calls broadcast_results_refresh only from Phase#reveal!, once (spec 025 AC-4.6)" do
    expect(named.call(/broadcast_results_refresh/)).to match_array(%w[app/models/game.rb app/models/phase.rb])
    expect(text.call(Rails.root.join("app/models/phase.rb").to_s)[/def reveal!.*?\n  end\n/m]).to include("broadcast_results_refresh")
    calls = %w[app/models/phase.rb app/models/game.rb].to_h { |path| [ path, code.call(Rails.root.join(path).to_s).scan("broadcast_results_refresh").size ] }
    expect(calls).to eq("app/models/phase.rb" => 1, "app/models/game.rb" => 1) # the call, and the definition
  end

  it "names the cable only in Game's message and broadcast methods and in the two channels, which send a subscriber the same messages (AC-2.7c, AC-9.7, spec 025 AC-4.6)" do
    cable = /Turbo::StreamsChannel|Turbo::Broadcastable|ActionCable|\bbroadcasts\w*|\.broadcast\b|\bbroadcast_(?!seat_status\b|results_refresh\b)\w+/
    naming = files.select { |f| code.call(f).match?(cable) }.map(&rel)
    outside = code.call(Rails.root.join("app/models/game.rb").to_s)
    %w[broadcast_seat_status seat_status_message broadcast_results_refresh results_refresh_message].each { |name| outside = outside.sub(/def #{name}.*?\n  end\n/m, "") }

    expect(naming).to match_array(%w[app/models/game.rb] + channels)
    expect(outside).not_to match(cable)
    channels.each do |path|
      channel = code.call(Rails.root.join(path).to_s)
      expect(channel.sub("< Turbo::StreamsChannel", "")).not_to match(cable), path # the parent class is the only mention
      expect(channel).not_to match(/\brender\b|\bbroadcast\w*|Submission|\bsubmissions\b|SavedOrder|saved_orders?|orders_for/), path
    end
  end

  it "sends to a subscriber (transmit) only from the two channels, once each (AC-9.7)" do
    expect(files.select { |f| code.call(f).match?(/\btransmit\b/) }.map(&rel)).to match_array(channels)
    channels.each { |path| expect(code.call(Rails.root.join(path).to_s).scan(/\btransmit\b/).size).to eq(1), path }
  end

  it "starts a stream for a subscriber only in the two channels (AC-9.7)" do
    stream = /\bstream_(?:from|for)\b|\bstream_or_reject_for\b/
    expect(files.select { |f| code.call(f).match?(stream) }.map(&rel)).to match_array(channels)
    expect("stream_from name").to match(stream) # control
  end

  it "defines the two messages only in Game (AC-9.7)" do
    expect(named.call(/def (?:seat_status_message|results_refresh_message)\b/)).to eq([ "app/models/game.rb" ])
  end

  it "control: the patterns do catch the macros and writes they are there to stop" do
    cable = /Turbo::StreamsChannel|Turbo::Broadcastable|ActionCable|\bbroadcasts\w*|\.broadcast\b|\bbroadcast_(?!seat_status\b|results_refresh\b)\w+/
    [ "broadcasts_to ->(s) { [:x] }", "broadcasts_refreshes", "broadcasts", "include Turbo::Broadcastable", "ActionCable.server.broadcast(a, b)",
      "broadcast_refresh_to(x)", "Turbo::StreamsChannel.broadcast_refresh_to(:results, id)" ].each { |line| expect(line).to match(cable), line }
    expect("game.broadcast_seat_status").not_to match(cable)
    expect("game.broadcast_results_refresh").not_to match(cable)
    # The ways a third sender would show itself: a transmit outside the channels, a channel class in another file.
    [ "transmit game.seat_status_message", "transmit(x)" ].each { |line| expect(line).to match(/\btransmit\b/), line }
    expect("class OtherChannel < Turbo::StreamsChannel").to match(cable)
    expect("# transmit is only a word in a comment".lines.reject { |line| line.strip.start_with?("#") }.join).not_to match(/\btransmit\b/)
  end

  it "renders the status partial only from the helper and from the message builder (AC-9.7)" do
    expect(named.call(%r{render\b[^\n]*["']shared/seat_status["']|partial:\s*["']shared/seat_status["']})).to match_array(%w[app/helpers/seat_status_helper.rb app/models/game.rb])
  end

  it "keeps the status code away from saved orders (AC-3.7)" do
    source = lambda do |path, pattern = nil|
      body = File.read(Rails.root.join(path))
      pattern ? body[pattern] : body
    end
    status_code = [ source.call("app/views/shared/_seat_status.html.erb"), source.call("app/helpers/seat_status_helper.rb"),
                    source.call("app/models/game.rb", /def broadcast_seat_status.*?\n  end\n/m),
                    source.call("app/models/game.rb", /def seat_status_message.*?\n  end\n/m),
                    source.call("app/models/game.rb", /def broadcast_results_refresh.*?\n  end\n/m),
                    source.call("app/models/game.rb", /def results_refresh_message.*?\n  end\n/m),
                    source.call("app/channels/seat_status_channel.rb"), source.call("app/channels/results_channel.rb"),
                    source.call("app/models/phase.rb", /def seat_statuses.*?\n  end\n/m) ]

    expect(status_code).to all(be_present)
    expect(status_code.join).not_to match(/SavedOrder|saved_orders?|orders_for/)
  end
end

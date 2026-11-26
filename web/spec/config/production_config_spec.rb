require "rails_helper"

# Production turns on SSL handling, so cookies are Secure and plain http is sent to https (spec 021 FR-12, AC-11.4).
RSpec.describe "The production configuration" do
  let(:live_lines) do
    File.readlines(Rails.root.join("config/environments/production.rb")).reject { |line| line.strip.start_with?("#") }.join
  end

  it "assumes SSL behind the proxy and forces it, leaving the health check alone" do
    expect(live_lines).to match(/^\s*config\.assume_ssl = true\s*$/)
    expect(live_lines).to match(/^\s*config\.force_ssl = true\s*$/)
    expect(live_lines).to match(%r{^\s*config\.ssl_options = \{ redirect: \{ exclude: ->\(request\) \{ request\.path == "/up" \} \} \}\s*$})
  end

  # Rails writes the bind values of SQL to the log at the debug level, through a filter a model's filter_attributes does not
  # reach, so a saved order's text can appear in a debug log. The default of info keeps it out (spec 022 FR-9, known limit).
  it "logs at info unless told otherwise, so orders stay out of the SQL log" do
    expect(live_lines).to match(/^\s*config\.log_level = ENV\.fetch\("RAILS_LOG_LEVEL", "info"\)\s*$/)
  end

  describe "with the SSL middleware that force_ssl adds" do
    around do |example|
      original = ENV["TRUCEBEARER_PASSPHRASE"]
      ENV["TRUCEBEARER_PASSPHRASE"] = "open sesame"
      example.run
    ensure
      ENV["TRUCEBEARER_PASSPHRASE"] = original
    end

    it "marks every cookie of a created game Secure, the session cookie included" do
      app = ActionDispatch::SSL.new(Rails.application)
      power = RulesEngine.powers.first.id.to_s
      response = Rack::MockRequest.new(app).post("https://www.example.com/games",
                                                 "REMOTE_ADDR" => "203.0.113.5",
                                                 params: { passphrase: "open sesame", power: power })

      expect(response.status).to eq(302)
      lines = Array(response.headers["set-cookie"]).flat_map { |value| value.to_s.split("\n") }
      expect(lines.size).to be >= 3
      expect(lines.grep(/\A_?\w*session/i)).not_to be_empty
      expect(lines).to all(match(/;\s*secure/i))
    end
  end
end

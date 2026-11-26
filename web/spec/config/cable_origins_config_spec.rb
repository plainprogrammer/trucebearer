require "rails_helper"

# Spec 024 D5, AC-7.1 to AC-7.3: what the setting does to Action Cable's own origin check, and where it is documented.
RSpec.describe "The Action Cable origins" do
  def allowed?(list, origin:, host: "play.example.org")
    config = ActionCable::Server::Configuration.new # a fresh one, so the suite's own server config is not changed
    config.allowed_request_origins = list
    config.logger = Rails.logger
    server = ActionCable::Server::Base.new(config: config)
    env = Rack::MockRequest.env_for("https://#{host}/cable", "HTTP_ORIGIN" => origin, "HTTP_HOST" => host, "HTTPS" => "on")
    ActionCable::Connection::Base.new(server, env).send(:allow_request_origin?)
  end

  [ nil, "", "https://a.example", "https://a.example/, https://b.example", " ,, " ].each do |setting|
    list = CableOrigins.parse(setting)

    it "always lets the app's own origin in, with #{setting.inspect}" do
      expect(allowed?(list, origin: "https://play.example.org")).to be(true)
    end

    it "refuses an unlisted foreign origin, with #{setting.inspect}" do
      expect(allowed?(list, origin: "https://evil.example")).to be(false)
    end

    it "lets every listed origin in, with #{setting.inspect}" do
      list.each { |origin| expect(allowed?(list, origin: origin)).to be(true) }
    end
  end

  it "reads the setting in production.rb from the one variable, with one live line" do
    live = File.readlines(Rails.root.join("config/environments/production.rb")).reject { |line| line.strip.start_with?("#") }.join

    expect(live).to match(/^\s*config\.action_cable\.allowed_request_origins = CableOrigins\.parse\(ENV\["TRUCEBEARER_CABLE_ORIGINS"\]\)\s*$/)
    expect(live).to match(%r{^require_relative "\.\./\.\./lib/cable_origins"\s*$})
  end

  it "never turns the forgery protection off, in any environment file" do
    files = Dir.glob(Rails.root.join("config/{environments,initializers}/*.rb"))
    live = files.flat_map { |file| File.readlines(file).reject { |line| line.strip.start_with?("#") } }.join

    expect(live).not_to match(/disable_request_forgery_protection\s*=\s*true/)
  end

  it "lists the variable under env.clear in deploy.yml and explains it, with the unset case, in the README (AC-7.3)" do
    deploy = YAML.load_file(Rails.root.join("config/deploy.yml"))
    readme = File.read(Rails.root.join("README.md"))
    section = readme[/^## Live updates.*?(?=^## |\z)/m]

    expect(deploy.dig("env", "clear")).to include("TRUCEBEARER_CABLE_ORIGINS" => "https://app.example.com")
    expect(section).not_to be_nil
    expect(section).to include("TRUCEBEARER_CABLE_ORIGINS")
    expect(section).to match(/unset/i)
    expect(section).to include("Request origin not allowed")
  end
end

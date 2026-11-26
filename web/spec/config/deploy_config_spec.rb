require "rails_helper"
require_relative "../support/deploy_config"

# Issue #30: Kamal deploys to a home-lab VM behind a Cloudflare tunnel. The tunnel ends TLS and sends plain http to port 80,
# so kamal-proxy must not do SSL itself. The host name, the live-update origins and the passphrase come from the
# environment of the machine that runs bin/kamal, and the SQLite files live on a volume that outlives the container.
RSpec.describe "The Kamal deploy configuration" do
  let(:host) { "play.example.org" }
  let(:deploy_env) { { "TRUCEBEARER_HOST" => host } }
  let(:deploy) { DeployConfig.load(deploy_env) }

  describe "kamal-proxy" do
    it "does no SSL of its own, because the tunnel ends it" do
      expect(deploy.dig("proxy", "ssl")).to be(false)
    end

    it "answers for the host name in TRUCEBEARER_HOST" do
      expect(deploy.dig("proxy", "host")).to eq(host)
      expect(DeployConfig.load("TRUCEBEARER_HOST" => "other.example.net").dig("proxy", "host")).to eq("other.example.net")
    end

    it "checks health at /up, which the app leaves open to plain http and any Host header" do
      expect(deploy.dig("proxy", "healthcheck", "path")).to eq("/up")
    end

    it "refuses to render without TRUCEBEARER_HOST, rather than serving every host name" do
      expect { DeployConfig.load({}) }.to raise_error(KeyError, /TRUCEBEARER_HOST/)
    end
  end

  describe "the container's environment" do
    it "gets the host name, in the clear" do
      expect(deploy.dig("env", "clear", "TRUCEBEARER_HOST")).to eq(host)
    end

    it "gets the live-update origins, which default to the host's own address and can be overridden" do
      expect(deploy.dig("env", "clear", "TRUCEBEARER_CABLE_ORIGINS")).to eq("https://#{host}")

      overridden = DeployConfig.load(deploy_env.merge("TRUCEBEARER_CABLE_ORIGINS" => "https://a.example https://b.example"))
      expect(overridden.dig("env", "clear", "TRUCEBEARER_CABLE_ORIGINS")).to eq("https://a.example https://b.example")
    end

    it "reads the time zone and the in-Puma job runner as clear settings" do
      expect(deploy.dig("env", "clear")).to include("TRUCEBEARER_TIME_ZONE", "SOLID_QUEUE_IN_PUMA" => true)
    end

    it "keeps the passphrase and the master key secret, with no value in the file" do
      expect(deploy.dig("env", "secret")).to contain_exactly("RAILS_MASTER_KEY", "TRUCEBEARER_PASSPHRASE")
      expect(deploy.dig("env", "clear")).not_to include("TRUCEBEARER_PASSPHRASE", "RAILS_MASTER_KEY")
    end

    it "takes both secrets from the deploy machine, never from a literal in .kamal/secrets" do
      lines = File.readlines(Rails.root.join(".kamal/secrets")).reject { |line| line.strip.start_with?("#") }.join

      expect(lines).to match(/^TRUCEBEARER_PASSPHRASE=\$TRUCEBEARER_PASSPHRASE$/)
      expect(lines).to match(/^RAILS_MASTER_KEY=\$\(cat config\/master\.key\)$/)
    end
  end

  describe "storage" do
    it "mounts a named volume at storage/, where Rails keeps its databases" do
      expect(deploy["volumes"]).to include("web_storage:/rails/storage")
    end

    it "keeps the four production databases (app, cache, queue, cable) under storage/" do
      database = YAML.safe_load(ERB.new(File.read(Rails.root.join("config/database.yml"))).result, aliases: true)
      paths = database.fetch("production").transform_values { |entry| entry.fetch("database") }

      expect(paths.keys).to contain_exactly("primary", "cache", "queue", "cable")
      expect(paths.values).to all(start_with("storage/"))
    end
  end

  describe "the registry" do
    it "is the local one Kamal starts itself, so no outside account is needed" do
      expect(deploy.dig("registry", "server")).to eq("localhost:5555")
      expect(deploy["registry"]).not_to include("username", "password")
    end
  end
end

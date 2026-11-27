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

    it "refuses to render with a blank TRUCEBEARER_HOST too, which would leave kamal-proxy without a host" do
      [ "", "  " ].each do |blank|
        expect { DeployConfig.load("TRUCEBEARER_HOST" => blank) }.to raise_error(KeyError, /TRUCEBEARER_HOST is blank/)
      end
    end

    it "trims stray spaces from TRUCEBEARER_HOST, which would make the app turn every page away" do
      padded = DeployConfig.load("TRUCEBEARER_HOST" => " play.example.org\n")

      expect(padded.dig("proxy", "host")).to eq("play.example.org")
      expect(padded.dig("env", "clear", "TRUCEBEARER_HOST")).to eq("play.example.org")
      expect(padded.dig("env", "clear", "TRUCEBEARER_CABLE_ORIGINS")).to eq("https://play.example.org")
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

    it "treats a blank TRUCEBEARER_CABLE_ORIGINS as unset, so the default holds" do
      blank = DeployConfig.load(deploy_env.merge("TRUCEBEARER_CABLE_ORIGINS" => " "))

      expect(blank.dig("env", "clear", "TRUCEBEARER_CABLE_ORIGINS")).to eq("https://#{host}")
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

  # The tunnel's client runs on the VM as a Kamal accessory, on the same Docker network as kamal-proxy, so the tunnel's service
  # is http://kamal-proxy:80 and nothing has to reach the VM from the LAN. Its only setting is the tunnel token, a secret.
  describe "the Cloudflare tunnel client" do
    let(:tunnel) { deploy.dig("accessories", "cloudflared") }

    it "runs Cloudflare's own image, pinned to a release rather than latest" do
      expect(tunnel["image"]).to match(%r{\Acloudflare/cloudflared:\d{4}\.\d+\.\d+\z})
    end

    it "runs on the app's own server, through the web role, so no address is written in the file" do
      expect(tunnel["roles"]).to eq([ "web" ])
      expect(tunnel).not_to include("host", "hosts")
    end

    it "runs the remotely managed tunnel without updating itself, since Kamal pins the version" do
      expect(tunnel["cmd"]).to eq("tunnel --no-autoupdate run")
    end

    it "joins Kamal's default network, where kamal-proxy is, and publishes no port" do
      expect(tunnel).not_to include("network", "port", "options")
    end

    it "takes the tunnel token as a secret, from the deploy machine, never from a literal" do
      expect(tunnel.dig("env", "secret")).to eq([ "TUNNEL_TOKEN" ])
      expect(tunnel.dig("env")).not_to include("clear")

      lines = File.readlines(Rails.root.join(".kamal/secrets")).reject { |line| line.strip.start_with?("#") }.join
      expect(lines).to match(/^TUNNEL_TOKEN=\$TUNNEL_TOKEN$/)
    end
  end

  describe "the registry" do
    it "is the local one Kamal starts itself, so no outside account is needed" do
      expect(deploy.dig("registry", "server")).to eq("localhost:5555")
      expect(deploy["registry"]).not_to include("username", "password")
    end
  end
end

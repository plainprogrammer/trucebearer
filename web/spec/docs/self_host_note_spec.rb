require "rails_helper"
require_relative "../support/deploy_config"

# Issue #30: the self-host note in README.md says what the deploy files do. Each claim is held to the file it describes, so the
# note and the configuration cannot drift apart.
RSpec.describe "The self-hosting note in the README" do
  let(:readme) { File.read(Rails.root.join("README.md")) }
  let(:section) { readme[/^## Self-hosting on a home lab.*?(?=^## |\z)/m] }
  let(:deploy) { DeployConfig.load("TRUCEBEARER_HOST" => "play.example.org") }

  it "exists, as its own section" do
    expect(section).not_to be_nil
  end

  it "names every variable the deploy file passes to the container or reads from the deploy machine" do
    names = deploy.dig("env", "clear").keys + deploy.dig("env", "secret")
    names -= [ "SOLID_QUEUE_IN_PUMA" ] # an internal switch, not something the host sets

    names.each { |name| expect(section).to include("`#{name}`") }
  end

  it "says which variables are secret and which are not" do
    secret_rows = section.lines.grep(/\A\| `/).select { |row| row.split("|")[3].to_s.strip == "Yes" }.map { |row| row[/`(\w+)`/, 1] }

    accessory_secrets = deploy["accessories"].values.flat_map { |accessory| Array(accessory.dig("env", "secret")) }

    expect(secret_rows).to match_array(deploy.dig("env", "secret") + accessory_secrets)
  end

  it "gives the tunnel target as plain http to kamal-proxy on port 80, which the tunnel client reaches by name" do
    expect(deploy.dig("proxy", "ssl")).to be(false)
    expect(deploy["accessories"]).to have_key("cloudflared")
    expect(section).to include("http://kamal-proxy:80")
  end

  it "names the tunnel client's image as the deploy file pins it, and the commands that manage it" do
    expect(section).to include("`#{deploy.dig('accessories', 'cloudflared', 'image')}`")
    expect(section).to include("bin/kamal accessory logs cloudflared")
    expect(section).to include("bin/kamal accessory reboot cloudflared")
  end

  # Behind the tunnel Rails assumes SSL, so it cannot see a plain http request to redirect it, and its Secure cookies would be
  # dropped. Cloudflare's own redirect has to be on.
  it "tells the host to turn on Cloudflare's Always Use HTTPS, since Rails cannot redirect plain http behind the tunnel" do
    expect(section).to include("Always Use HTTPS")
    expect(section).to include("curl -i http://play.example.org/")
  end

  # Kamal reads only the environment of the shell that runs it, so a sourced .env file must export what it sets.
  it "says how to load a .env file so bin/kamal sees its variables" do
    expect(section).to include("set -a; source .env; set +a")
  end

  it "names the volume and the directory it holds, as the deploy file mounts them" do
    volume, directory = deploy["volumes"].grep(/web_storage/).first.split(":")

    expect(section).to include("`#{volume}`")
    expect(section).to include("`#{directory}`")
  end

  it "gives the first-deploy commands and the /up checks" do
    [ "bin/kamal config", "bin/kamal setup", "bin/kamal deploy", "/up" ].each { |text| expect(section).to include(text) }
    expect(section).to include("curl -i -H 'Host: play.example.org' http://<VM address>/up")
    expect(section).to include("curl -i https://play.example.org/up")
  end

  it "names the aliases it recommends, as the deploy file defines them" do
    section.scan(/bin\/kamal (logs|console|shell)/).flatten.uniq.each { |name| expect(deploy["aliases"]).to have_key(name) }
  end

  it "says the registry needs no outside account, and that backups are the VM host's snapshots until 1.0" do
    expect(deploy.dig("registry", "server")).to eq("localhost:5555")
    expect(section).to include("`localhost:5555`")
    expect(section).to match(/No registry account/)
    expect(section).to match(/backups are the VM host's snapshots/i)
    expect(section).to include("1.0")
  end
end

# Trucebearer web app

The Rails app that players and hosts use at the table. Agent instructions are in `AGENTS.md`; the technical decisions are in `../docs/architecture.md`.

- Set up: `bin/setup`
- Run the tests: `bundle exec rspec`
- Run the app: `bin/rails server`

## Playtest access

Creating a game needs a shared passphrase. Set `TRUCEBEARER_PASSPHRASE` in the environment of the server (for Kamal deploys it is listed under `env.secret` in `config/deploy.yml` and read from the deploy machine's environment through `.kamal/secrets`). When it is unset or blank, creating a game is refused with a 403 and the app logs a warning. Joining and playing in a game that already exists does not need it.

When the host steps into another seat, the seat's owner is told the time ("The host entered your orders at 8:42 PM EST"). Set `TRUCEBEARER_TIME_ZONE` to a zone name such as `America/New_York` to show that time at the table's own clock. It is read each time a page is drawn, an unset or unknown name means UTC, and the zone's abbreviation is always shown. It is not a secret: for Kamal deploys it is under `env.clear` in `config/deploy.yml`.

Host and seat links carry a secret token in the query string. Proxy and tunnel logs, and browser history, may keep those links. In this release the host token cannot be rotated, so treat a host link like a password and share it only with the host.

## The position editor

The host fixes the board by hand: the host page has an "Edit the board" link next to "Reveal orders". It adds, moves and removes units, sets who owns a supply center, and sets the season and year of the open phase, one change at a time, each on its own page. The rules engine checks every change against the map and refuses an impossible board in plain words. An edit that moves units (add, move, remove) clears every seat's saved orders and submissions for the open phase, and each seat sees a notice with the time; an ownership or date edit keeps them. The host sees no order there, and never a count. Every edit is written to the game's history, in the host page's Seat history list.

## Live updates

The seat page and the host's controls show which powers have submitted, and update on every phone without a reload. The updates travel over Action Cable (Turbo Streams over Solid Cable). A message holds only the seven submitted states and nothing else; Solid Cable keeps each message for a day, so that is all it keeps.

When the host reveals a phase, every open seat page, host page, order screen and picker step also switches to the results without a tap. The message that does it is a Turbo refresh with no content at all, sent on a second stream per game (`results:<game id>`), and each phone then reloads its own page through its normal, authorized request, so what it shows is decided by the same checks as any page load. Solid Cable keeps that message for a day too, and it holds nothing. A phone that was asleep or offline shows the old page until it is touched or reloaded.

The browser opens the socket from the page's own address, and Action Cable accepts it only from the origins it knows. Set `TRUCEBEARER_CABLE_ORIGINS` to the other origins that may open it, separated by commas or spaces, for example `https://play.example.org` (written in lowercase, as a browser sends it). It is not a secret, so for Kamal deploys it is listed under `env.clear` in `config/deploy.yml`.

When it is unset or blank, Rails' own default applies: only a socket opened from the address the app is served at (`https://` plus the `Host` header, because the app assumes SSL behind its proxy) is accepted. A deployment where players reach the app at that address works with nothing set. Where they do not (a proxy that rewrites the `Host` header, or a second public name), the socket is refused and the log says "Request origin not allowed". Nothing is shown to the player: every page is still correct whenever it loads, and only the live updates are missing. Forgery protection is never switched off.

## Self-hosting on a home lab

This is how the playtest runs: one VM, deployed with Kamal, behind a Cloudflare tunnel. The tunnel ends TLS and sends plain http to the VM, so Rails assumes SSL (`config.assume_ssl` and `config.force_ssl` in `config/environments/production.rb`) and kamal-proxy runs with `ssl: false`. All configuration is in `config/deploy.yml`, which Kamal reads through ERB with the environment of the machine that runs `bin/kamal`. Kamal does not load a `.env` file, so export the variables below in your shell (or with a tool such as direnv) first.

**What you need**

- A VM that you can reach over SSH, as root unless you add `ssh: user:` to `config/deploy.yml`, with a CPU that matches `builder.arch` there (`amd64`). If Docker is missing, `bin/kamal setup` installs it, which needs root or passwordless sudo, and either `curl` or `wget`.
- A deploy machine (your own computer) with this repository, its gems (`bundle install`), Docker, and `config/master.key` in place (`.kamal/secrets` reads it from there). Never commit that file.
- A Cloudflare tunnel you control, with a public host name.
- No registry account. `config/deploy.yml` uses `localhost:5555`: Kamal runs a small registry container on the deploy machine and forwards its port to the VM over SSH, so the image never leaves your two machines.

**Variables and secrets**

| Variable | Set where | Secret | What it does |
|---|---|---|---|
| `TRUCEBEARER_HOST` | Deploy machine's shell, required | No | The public host name the tunnel serves, with no scheme, such as `play.example.org`. It becomes kamal-proxy's `host` and is passed to the container, where `production.rb` allows only that host (and `/up`). Unset or blank, `bin/kamal` stops with a `KeyError`; stray spaces are trimmed. In the app alone, unset or blank means any host is allowed. |
| `TRUCEBEARER_PASSPHRASE` | Deploy machine's shell, required to create games | Yes | The passphrase that lets a host create a game. See "Playtest access". |
| `RAILS_MASTER_KEY` | Read from `config/master.key` by `.kamal/secrets` | Yes | Decrypts `config/credentials.yml.enc`. |
| `TRUCEBEARER_CABLE_ORIGINS` | Deploy machine's shell, optional | No | Extra origins that may open the live-update socket. In `deploy.yml` it defaults to `https://` plus `TRUCEBEARER_HOST`. See "Live updates". |
| `TRUCEBEARER_TIME_ZONE` | `env.clear` in `config/deploy.yml` | No | The table's time zone, `UTC` unless you change it there. See "Playtest access". |

Secrets are listed by name under `env.secret` in `config/deploy.yml` and their values come from `.kamal/secrets`, which holds no raw values and is safe to commit. Clear settings are in `env.clear`.

**Point `deploy.yml` at your VM.** Change the address under `servers.web` (the file ships with the placeholder `192.168.0.1`). Kamal reads the file from your working copy, so this edit can stay uncommitted.

**The tunnel target.** In the tunnel's public host name settings, set the service to `http://<VM address>:80`, with the public host name equal to `TRUCEBEARER_HOST`. Port 80 is kamal-proxy, which answers only requests whose `Host` header matches `TRUCEBEARER_HOST`, so the tunnel must pass the public name on as the `Host` header (cloudflared does, unless you set an HTTP Host Header override).

**The volume.** The databases (the app's own, the cache, the job queue and the live-update queue) are SQLite files in `/rails/storage`, which `deploy.yml` mounts from the Docker volume `web_storage` on the VM. `config/database.yml` points all four there. The volume outlives the container, so deploys and restarts keep your games.

**First deploy.** From `web/` on the deploy machine:

```sh
export TRUCEBEARER_HOST=play.example.org
export TRUCEBEARER_PASSPHRASE='choose-a-passphrase'
bin/kamal config   # checks the files render; it contacts nothing and fails if TRUCEBEARER_HOST is unset
bin/kamal setup    # installs Docker if needed, starts kamal-proxy, builds, pushes and boots the app
```

Later deploys: `bin/kamal deploy`, with the same variables exported. Handy aliases from `deploy.yml`: `bin/kamal logs`, `bin/kamal console`, `bin/kamal shell`.

**Checking `/up`.** `/up` is Rails' health check and kamal-proxy's too. Rails answers it with 200 over plain http for any `Host` header, without the https redirect, but kamal-proxy on port 80 still passes on only requests whose `Host` matches `TRUCEBEARER_HOST`. Check it in two places, and expect status 200 both times (`HTTP/1.1 200` straight to the VM, and `HTTP/2 200` through the tunnel):

```sh
curl -i -H 'Host: play.example.org' http://<VM address>/up   # straight to kamal-proxy on the VM
curl -i https://play.example.org/up                          # through the tunnel
```

**Backups.** There are none in the app. Until after 1.0, backups are the VM host's snapshots, so make sure they include the `web_storage` volume.

# Trucebearer web app

The Rails app that players and hosts use at the table. Agent instructions are in `AGENTS.md`; the technical decisions are in `../docs/architecture.md`.

- Set up: `bin/setup`
- Run the tests: `bundle exec rspec`
- Run the app: `bin/rails server`

## Playtest access

Creating a game needs a shared passphrase. Set `TRUCEBEARER_PASSPHRASE` in the environment of the server (for Kamal deploys it is listed under `env.secret` in `config/deploy.yml` and read from the deploy machine's environment through `.kamal/secrets`). When it is unset or blank, creating a game is refused with a 403 and the app logs a warning. Joining and playing in a game that already exists does not need it.

When the host steps into another seat, the seat's owner is told the time ("The host entered your orders at 8:42 PM EST"). Set `TRUCEBEARER_TIME_ZONE` to a zone name such as `America/New_York` to show that time at the table's own clock. It is read each time a page is drawn, an unset or unknown name means UTC, and the zone's abbreviation is always shown. It is not a secret: for Kamal deploys it is under `env.clear` in `config/deploy.yml`.

Host and seat links carry a secret token in the query string. Proxy and tunnel logs, and browser history, may keep those links. In this release the host token cannot be rotated, so treat a host link like a password and share it only with the host.

# Repository layout

How this repository is organised, and how work moves between the adjudicator gem and the Rails app. Written 24 November 2026.

## Intent

The repository holds two projects: the `trucebearer-adjudicator` gem and the Rails app. Agents should be able to work on either one without knowing what the other side is doing at that moment. Most of the early work will be in the gem, then the focus moves to app integration.

## Goals

- Each side has its own instructions, tests and conventions, and an agent working on one side never loads the other side's instructions.
- Work crosses the boundary only through GitHub Issues and tagged gem releases.
- A change in the gem cannot break the app until someone deliberately upgrades the app.

## Non-goals

- Extracting the gem into its own repository. That can happen later if other projects want it.
- Publishing the gem to RubyGems before the name is final.

## Approaches considered

| Approach | Trade-off | Outcome |
|---|---|---|
| **Two sibling folders under a thin root** | One extra folder level for the app | **Chosen.** Each agent gets clean instructions, and the root holds only what is truly shared |
| Rails at the root, gem in a subfolder | The common Rails setup, but every gem agent would inherit the Rails instructions | Rejected |
| Two repositories | The strongest isolation, but the decision to keep one repository was already made | Rejected; pinning gives most of the same isolation |

For how the app depends on the gem:

| Approach | Trade-off | Outcome |
|---|---|---|
| **Pin to git tags** | A gem feature reaches the app only after a release | **Chosen.** The repository is public, so no credentials are needed, and nothing is published under a name that isn't final |
| Publish to RubyGems and pin by version | The simplest Gemfile, but the name can't be withdrawn from the registry later | Later, once the name is final |
| Local path | Instant, but every gem change reaches the app immediately | Rejected |

## Layout

```
trucebearer/
├── AGENTS.md            shared rules for every agent
├── CLAUDE.md            imports AGENTS.md
├── README.md
├── CONTRIBUTING.md      how contributions are licensed
├── LICENSE              AGPL-3.0-or-later (root files)
├── NOTICE               licence map, trademark acknowledgement and credits
├── TRADEMARKS.md        how the name and logo may be used
├── assets/              original artwork, icons and the logo (CC BY-SA 4.0)
├── docs/                decisions both sides rely on (CC BY-SA 4.0)
├── .github/
│   ├── ISSUE_TEMPLATE/  adjudicator request, interface change
│   ├── pull_request_template.md
│   └── workflows/       CI (not written yet)
├── adjudicator/         the gem
│   ├── AGENTS.md  CLAUDE.md  README.md  CHANGELOG.md  LICENSE
│   ├── bin/             release and development scripts
│   ├── data/maps/       map definitions as data
│   ├── docs/            interface.md, ruleset.md
│   ├── lib/trucebearer/adjudicator/
│   └── spec/datc/       DATC-derived fixtures
└── web/                 the Rails app (not generated yet)
    └── AGENTS.md  CLAUDE.md  LICENSE  NOTICE
```

Agent instructions live in `AGENTS.md` files so that tools other than Claude Code can read them. Each `CLAUDE.md` contains one line that imports its `AGENTS.md`. Claude Code loads instruction files from the working folder up to the root, so an agent started in `adjudicator/` sees the root rules and the gem's rules, and never the app's.

## How work flows

1. **The app needs something from the gem.** An Issue is opened with the "Adjudicator request" template and labelled `adjudicator`. It describes the need with example input and expected output as plain data.
2. **A gem agent picks it up.** The example becomes the first failing spec. Additions go under "Added" in the gem's `CHANGELOG.md`.
3. **The gem changes its interface.** The pull request updates `adjudicator/docs/interface.md`, adds an entry under "Changed", and opens an "Interface change" Issue labelled `web`.
4. **A release.** Bump the version, move the "Unreleased" entries under it, commit, and tag `adjudicator-vX.Y.Z`. Before 1.0, a minor version may break the interface and a patch version never does.
5. **The app upgrades.** A pull request of its own moves the pin to the new tag, after reading the CHANGELOG and any open "Interface change" Issues.

Each pull request touches one side only. Root files change in pull requests of their own.

## CI (to be written)

- **Gem job.** Runs when `adjudicator/**` changes and runs the gem's specs.
- **App job.** Runs when `web/**` changes and runs the app's specs against the pinned gem release.
- **Early warning job.** Runs the app's specs against the gem's latest code. It never blocks a merge. It warns that the next gem release will break the app.

## Left for the builder

- Generating the Rails app into `web/`. Delete its `.ruby-version` and move any `.github/` it creates to the root.
- Writing the gem skeleton by hand: gemspec (`license = "AGPL-3.0-or-later"`, with `LICENSE` in its files), Gemfile, Rakefile, version file.
- Pinning the Ruby version in a root `.ruby-version`.
- The release script in `adjudicator/bin/`.
- The CI workflows.
- Creating the `adjudicator`, `web` and `interface` labels on GitHub.
- Copying the brand package into `assets/` when the app needs it. Copies inside `web/` stay CC BY-SA 4.0; `web/NOTICE` already says so.
- The app's "About this instance" page, linked from every page: the source link that AGPL section 13 requires, the upstream version and commit, whether the build matches a published version, and the operator's description of any modifications (the place the additional term in `web/NOTICE` requires).
- Never excluding `LICENSE` or `NOTICE` from the Docker image through `.dockerignore`.
- A pointer to `web/NOTICE` in each source file's header, if the attorney says AGPL section 7 needs one (guardrails question 11).

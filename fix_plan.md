# fix_plan.md

## Current status

- Source-of-truth spec exported to `spec.md`.
- Sections 0–6 complete: Rails app, auth, data model, repo creation, Git Smart HTTP, search, stars, web UI, CLI all working.
- Target is a hackathon MVP optimized for the 1-minute demo flow.

## Highest-priority execution plan

### 0. Project bootstrap

- [x] Initialize the Rails app and dependency baseline for Lore v1. (Rails 8.1.3, sqlite3, grack, bcrypt, minitest configured)
- [x] Add Grack and configure a repo-root path that works in local development/test.
- [ ] Add minimal project documentation for setup/run/test if missing.

### 1. Authentication + core data model

- [x] Implement `User`, `Repo`, and `Star` models with the required constraints and validations.
- [x] Implement PAT issuance on user creation with digest-only storage.
- [x] Add auth helpers for bearer PAT API auth and Basic auth for git transport.

### 2. Repo creation + storage

- [x] Implement repo creation API that validates owner/name, creates the DB row, initializes a bare repo on disk, and points `HEAD` at `main`.
- [x] Return canonical `web_url` and `clone_url` values from repo creation/read APIs.
- [x] Update repo metadata on successful pushes, including `last_pushed_at`.

### 3. Git Smart HTTP

- [x] Mount Grack under `/git`.
- [x] Add middleware that resolves repo access from the request path and enforces Lore v1 rules.
- [x] Validate anonymous clone/fetch, authenticated push, and non-fast-forward rejection to `main`.

### 4. Search + stars

- [x] Implement repo search API returning ranked results with similarity scores.
- [x] Add embedding generation/storage for `name + description + tags`.
- [x] Implement star/unstar flows and star counts.
- [x] Ensure the seeded `slack-notify` repo is top-ranked for demo-critical queries.

### 5. Minimal web UI

- [x] Build a homepage that introduces Lore and highlights repos in a demo-friendly way.
- [x] Build a dedicated search page for searching all repos.
- [x] Build a user page that lists a user's repos.
- [x] Build a repo detail page showing description, tags, stars, clone URL, and last push metadata.
- [x] Serve `getting-started.md` from the app.

### 6. Lore CLI

- [x] Implement `lore register`.
- [x] Implement `lore search` with predictable terminal output.
- [x] Implement `lore clone` with auto-star behavior.
- [x] Implement `lore publish`, `lore push`, and `lore whoami`.
- [x] Install/save config in `~/.lore/config` and set git identity during register.

### 7. Demo fixtures + end-to-end validation

- [x] Seed working demo repos with realistic metadata, commits, and agent-readable READMEs.
- [x] Add focused tests for API behavior, repo creation, auth, and search ranking.
- [x] Add an end-to-end demo validation path covering register/create/clone/push/metadata refresh.
- [ ] Validate the exact filmed scenario for Slack search/clone/use/push.

## Known design constraints

- Optimize for a compelling demo over long-term architecture purity.
- Keep semantic-context ideas out of v1 unless needed as mock/demo content only.
- Avoid broad speculative work; each increment should move a demo-critical capability forward.

## Next recommended increment

- Validate the exact filmed scenario for Slack search/clone/use/push.
- Add minimal project documentation for setup/run/test.

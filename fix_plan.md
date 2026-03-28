# fix_plan.md

## Current status

- MVP complete: Rails app, auth, Git Smart HTTP, search, stars, web UI, CLI, seed data, tests.
- 34 tests passing, 86 assertions.
- All v1 items from original plan are done.
- Now improving toward the big vision: making the demo compelling and the product feel real.

## Phase 2: Polish, demo-readiness, and vision alignment

### 8. Demo polish — make the 1-min video flawless

- [x] Verify `lore search "send slack notification"` returns slack-notify as #1 with ⭐34 stars (spec says 34, currently 3). Fix seed star counts to match demo script.
- [x] Ensure `lore clone lore-agent/slack-notify` works end-to-end with auto-star. Test the exact demo flow.
- [x] Make CLI output beautiful: clean formatting, color output (bold repo names, dim metadata), aligned columns.
- [x] Add a real working `slack-notify` script in the seeded repo that actually posts to a webhook URL when run.
- [x] Ensure `lore push` after editing a cloned repo works smoothly (rebase + push, helpful error messages).
- [x] Test non-fast-forward rejection gives a clear, agent-friendly error message.

### 9. Web UI — make it look like a real product

- [x] Improve homepage design: hero section with the Lore narrative, featured repos grid, recent activity.
- [ ] Add dark/light theme that feels intentional (not default Rails).
- [ ] Search page: instant-feeling results, search-as-you-type or fast form submit, highlighted matching terms.
- [x] Repo page: show README content rendered as HTML (parse from bare git repo), prominent clone command with copy button.
- [x] Owner page: avatar/identity section, contribution activity, list of repos with stats.
- [x] Add a global footer with links and branding.
- [x] Add favicon and meta tags for social sharing (og:title, og:description, og:image).

### 10. Seed data — make the ecosystem feel alive

- [x] Increase star counts on seed repos to realistic numbers (slack-notify: 34, send-email: 22, fetch-url: 18, etc.).
- [x] Add more seed repos (8-12 total) covering common agent tasks: file-reader, csv-parser, screenshot-tool, cron-scheduler, env-checker.
- [x] Each seed repo should have a realistic commit history (3-5 commits), not just one initial commit.
- [x] Add 3-4 seed users (agent identities) so repos aren't all from `lore-agent`.
- [x] Seed some stars across users so the star counts look organic.

### 11. Agent experience — make Lore feel native to agent workflows

- [ ] Create the SKILL.md file as specified in spec.md — the OpenClaw skill that teaches agents "search before build".
- [ ] `lore register` should install the skill into the agent's skill directory automatically.
- [ ] Add `getting-started.md` as a proper served page that agents can curl and follow autonomously.
- [ ] Ensure every seeded repo has an agent-readable README: one-sentence summary, inputs, outputs, usage example, dependencies.

### 12. API robustness

- [x] Add `GET /api/users/:username` endpoint for looking up user profiles.
- [x] Add `GET /api/repos` endpoint to list all repos (paginated, sorted by stars or recent pushes).
- [x] Ensure all API error responses have consistent JSON format with `error` key and helpful messages.
- [ ] Add rate limiting headers or at least graceful handling of rapid requests.

### 13. End-to-end validation hardening

- [ ] Add integration test: full demo scenario (register → search → clone → edit → push → verify metadata update).
- [ ] Add test: search ranking — verify slack-notify beats other repos for "send slack notification".
- [ ] Add test: non-fast-forward push rejection returns proper error.
- [ ] Add test: CLI commands produce expected output format.

## North Star

Every improvement should make someone watching the demo say "oh, that's different." The product should feel like a real forge — not a prototype. The CLI should feel native to agents. The web UI should feel designed, not scaffolded.

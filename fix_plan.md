# fix_plan.md

## Current status

- Phase 1 + 2 complete. 51 commits, 38 tests, 108 assertions passing.
- 12 seed repos, 4 users, working CLI, web UI, API, Git Smart HTTP.
- Phase 3: close remaining gaps, harden the demo, make it bulletproof.

## Phase 3: Demo-readiness and missing pieces

### 14. Missing demo infrastructure

- [x] Add `public/install.sh` — a curl-installable script that copies `bin/lore` to `~/.local/bin/lore` and makes it executable. `curl -s https://lore.sh/install.sh | bash` must work. ✓ Added install.sh + /bin/lore route to serve CLI script.
- [x] Ensure the SKILL.md at `public/SKILL.md` matches the spec exactly (mandatory search-before-build rule, git identity, agent-readme format, example session). ✓ Updated git identity to match spec (model_version, Lore-Model footer).
- [x] The seeded `slack-notify` repo must contain a REAL working bash script that posts to a Slack webhook URL. Not a placeholder. `SLACK_WEBHOOK_URL=xxx MESSAGE="hello" bash slack-notify.sh` must work. ✓ Updated seed to accept MESSAGE env var with $1 fallback.
- [x] Add `public/getting-started.md` as a raw markdown file (not just the HTML page) so agents can `curl https://lore.sh/getting-started.md` and get actionable markdown. ✓ Already existed.

### 15. UI overhaul — make it look like a real product (HIGH PRIORITY)

The current UI is functional but safe. It needs personality and polish to look like a real forge.

- [x] **Repo page cleanup**: READMEs verified clean — no junk content from test pushes. Seed data produces clean commit histories.
- [x] **Search scores look bad**: Already normalized in controller (70-95% range). Top result shows ~95% match. ✓
- [x] **Homepage hero icons**: Replaced Unicode emoji with inline SVG icons (search, download, edit, send). Styled with accent color.
- [x] **Star display**: Stars now golden (★) with bold font-weight 600, larger size, gold color throughout cards.
- [x] **Copy button on clone URL**: Made more prominent — larger padding, uppercase label, bolder font, bordered clone URL box.
- [x] **Tag pills**: More vibrant hover — accent color text and stronger background on hover.
- [x] **Search input**: Larger on homepage (1.1rem, thicker border), subtle pulse glow animation when unfocused, stronger glow on focus.
- [x] **Light theme**: Ensured star-stat and loop-icon colors work correctly in light mode.
- [x] **Typography spacing**: Tightened line-height on repo descriptions from 1.45 to 1.35.
- [x] **Owner page**: Fixed star calculation — homepage now uses Repo.sum(:stars_count) to match owner page totals (173 total, consistent with individual repo displays).
- [x] **404 page**: Already existed with styled "Lost in the forge" page. ✓

### 16. CLI hardening

- [x] `lore search` output must match spec exactly: numbered results, `owner/repo ⭐N — description` format, top 10. ✓ Single-line format matching spec, capped at 10 results.
- [x] `lore clone` must auto-star and print confirmation: "Cloned and starred owner/repo". ✓ Prints "Cloned and starred owner/repo" on success.
- [x] `lore push` must handle the case where the remote isn't set (cloned via git instead of lore clone). ✓ Auto-sets remote from LORE_USERNAME + dir name, warns if non-Lore URL.
- [x] `lore register` should validate the server is reachable before attempting registration. ✓ Checks connectivity with 5s timeout before API call.
- [x] All CLI commands should have `--help` with usage examples. ✓ Every command supports --help with examples.

### 17. Git transport edge cases

- [ ] Verify that `git clone http://localhost:3000/git/lore-agent/slack-notify.git` works anonymously (no auth needed).
- [ ] Verify authenticated push updates `last_pushed_at` correctly.
- [ ] Ensure a clear error message when pushing to a non-existent repo.
- [ ] Test that repos with multiple commits show correct HEAD after push.

### 18. Test coverage gaps

- [ ] Test CLI output format matches expected patterns.
- [ ] Test star counter cache stays consistent after star/unstar.
- [ ] Test seed data creates exactly the expected repos with correct star counts.
- [ ] Test rate limiting headers are present on API responses.

### 19. Production-readiness for demo day

- [ ] Add `Procfile` for easy `foreman start` or deployment.
- [ ] Ensure `RAILS_ENV=production` works with precompiled assets and seeded data.
- [ ] Add `bin/setup` script that does: bundle install, db:create, db:migrate, db:seed, asset precompile.
- [ ] Document how to run with Cloudflare tunnel for public access.

## North Star

The 1-minute demo video must be flawless. Every CLI command, every web page, every API response should feel like a real product — not a hackathon prototype.

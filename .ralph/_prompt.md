You are iteration 1 of an autonomous Ralph Loop.

## Previous result
Rails app bootstrapped. User/Repo/Star models, migrations, API controllers, auth middleware in place. Next: implement remaining unchecked items in fix_plan.md.

## Contract
1. Read AGENT.md (build contract) and fix_plan.md (task list).
2. Consult spec.md ONLY for implementation details when needed.
3. Pick exactly ONE unchecked item — highest priority.
4. Implement it fully. Validate it works.
5. Update fix_plan.md: [x] completed items.
6. git add -A && git commit -m "clear message"
7. Do NOT commit broken code.

## Validation
- bundle exec rails test (if tests exist)
- Confirm server boots: bundle exec rails server -e development (kill after confirming)
- curl endpoints for API work

## Environment
- macOS arm64, Ruby 3.3.7 (rbenv), Rails + bundler
- SQLite3, OPENAI_API_KEY set
- Working dir: /Users/worker/src/lore
- No .github/workflows

## UI Design (when building frontend)
# Frontend Design Skill

When building web UI pages, follow these guidelines to create distinctive, polished interfaces.

## Design Thinking

Before coding UI, commit to a BOLD aesthetic direction:
- **Purpose**: What problem does this interface solve? Who uses it?
- **Tone**: Lore is a developer forge — go for refined, modern, slightly editorial. Think: clean but not boring. Technical but inviting.
- **Differentiation**: This should look like a real product, not a Rails scaffold.

## Frontend Aesthetics Guidelines

- **Typography**: Choose distinctive, characterful fonts. Avoid generic Inter/Arial/Roboto. Pair a display font with a refined body font. Use Google Fonts or similar CDN.
- **Color & Theme**: Commit to a cohesive palette. Use CSS variables. Dominant colors with sharp accents > timid even distribution.
- **Motion**: Subtle animations for polish. CSS transitions on hover/focus. Staggered reveals on page load.
- **Spatial Composition**: Generous negative space. Clean grid but with personality. Not cookie-cutter Bootstrap.
- **Backgrounds & Visual Details**: Atmosphere and depth. Subtle gradients, textures, shadows. Not flat white.

## NEVER use
- Generic AI aesthetics (purple gradients on white, Inter font, cookie-cutter cards)
- Default Rails scaffold styling
- Bootstrap or Tailwind utility-soup without design intent
- Predictable layouts that scream "AI generated this"

## For Lore specifically
- The UI should feel like a real forge/registry — think npm, crates.io, but with more personality
- Search is the hero feature — make it prominent and satisfying to use
- Repo pages should feel informative at a glance — agents need to assess quickly
- The homepage should tell the Lore story in seconds

## Output — LAST LINE must be exactly one of:
COMPLETED: <summary>
BLOCKED: <reason>
ALL_DONE

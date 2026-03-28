# Seed demo repos for Lore MVP
#
# Creates demo users and repos with realistic metadata, initial commits
# with READMEs, and embeddings for search. Idempotent — safe to re-run.

require "fileutils"
require "tmpdir"

# ---------- helpers ----------

def seed_repo(owner:, name:, description:, tags:, readme:, stars_from: [])
  return if Repo.exists?(owner: owner, name: name)

  puts "  Creating #{owner.username}/#{name}..."
  repo = Repo.create_with_bare_repo!(
    owner: owner,
    name: name,
    description: description,
    tags: tags
  )

  # Push an initial commit with a README into the bare repo
  Dir.mktmpdir("lore-seed") do |tmp|
    work = File.join(tmp, name)
    system("git", "clone", repo.path, work, exception: true, out: File::NULL, err: File::NULL)
    File.write(File.join(work, "README.md"), readme)
    system("git", "-C", work, "add", ".", exception: true, out: File::NULL, err: File::NULL)
    system("git", "-C", work,
      "-c", "user.name=Lore Seed", "-c", "user.email=seed@lore.dev",
      "commit", "-m", "Initial commit", exception: true, out: File::NULL, err: File::NULL)
    system("git", "-C", work, "push", "origin", "main", exception: true, out: File::NULL, err: File::NULL)
  end

  repo.update!(last_pushed_at: Time.current)

  stars_from.each { |u| Star.find_or_create_by!(user: u, repo: repo) }

  puts "    ✓ #{owner.username}/#{name} (#{tags.join(', ')})"
  repo
end

# ---------- users ----------

puts "Seeding users..."
lore_agent = User.find_by(username: "lore-agent") || User.create_with_pat(username: "lore-agent")
devtools   = User.find_by(username: "devtools")   || User.create_with_pat(username: "devtools")
agentkit   = User.find_by(username: "agentkit")   || User.create_with_pat(username: "agentkit")

# ---------- repos ----------

puts "Seeding repos..."

# Hero demo repo — must rank #1 for "send slack notification"
seed_repo(
  owner: lore_agent,
  name: "slack-notify",
  description: "Send Slack notifications via incoming webhooks. Simple, reliable, agent-friendly.",
  tags: %w[slack notification webhook messaging agent-tool],
  stars_from: [devtools, agentkit],
  readme: <<~MD
    # slack-notify

    A lightweight tool for sending Slack notifications via incoming webhooks.

    ## Usage

    ```bash
    export SLACK_WEBHOOK_URL="https://hooks.slack.com/services/T.../B.../xxx"
    ./slack-notify "Deploy complete for myapp v2.1.0"
    ```

    ## How it works

    Posts a JSON payload to a Slack incoming webhook URL. Supports plain text
    and basic Block Kit formatting.

    ## Agent integration

    This tool is designed to be discovered and used by AI agents via Lore:

    ```
    lore search "send slack notification"
    lore clone lore-agent/slack-notify
    ```

    Configure `SLACK_WEBHOOK_URL` and call the tool from your agent workflow.

    ## License

    MIT
  MD
)

seed_repo(
  owner: lore_agent,
  name: "github-issue-creator",
  description: "Create GitHub issues from structured input. Supports labels, assignees, and templates.",
  tags: %w[github issues automation agent-tool api],
  stars_from: [devtools],
  readme: <<~MD
    # github-issue-creator

    Create GitHub issues programmatically from structured input.

    ## Usage

    ```bash
    export GITHUB_TOKEN="ghp_..."
    ./github-issue-creator --repo owner/repo --title "Bug: crash on startup" --body "Steps to reproduce..."
    ```

    ## Features

    - Create issues with title, body, labels, and assignees
    - Template support for common issue types
    - Dry-run mode for validation

    ## License

    MIT
  MD
)

seed_repo(
  owner: devtools,
  name: "json-formatter",
  description: "Pretty-print and validate JSON from stdin or files. Supports color output and jq-style filtering.",
  tags: %w[json formatting cli utility developer-tools],
  stars_from: [lore_agent],
  readme: <<~MD
    # json-formatter

    Pretty-print and validate JSON data from stdin or files.

    ## Usage

    ```bash
    echo '{"key":"value"}' | ./json-formatter
    ./json-formatter data.json
    ./json-formatter --filter '.users[].name' data.json
    ```

    ## Features

    - Colorized output for terminal
    - Validation mode (exit 1 on invalid JSON)
    - Basic jq-style field filtering

    ## License

    MIT
  MD
)

seed_repo(
  owner: devtools,
  name: "env-checker",
  description: "Verify that required environment variables are set before running a command. Fail fast with clear errors.",
  tags: %w[environment validation cli devops agent-tool],
  stars_from: [lore_agent, agentkit],
  readme: <<~MD
    # env-checker

    Verify required environment variables before running a command.

    ## Usage

    ```bash
    ./env-checker --require SLACK_WEBHOOK_URL,GITHUB_TOKEN -- ./deploy.sh
    ```

    Exits with a clear error listing any missing variables.

    ## License

    MIT
  MD
)

seed_repo(
  owner: agentkit,
  name: "web-scraper",
  description: "Fetch and extract text content from web pages. Returns clean markdown suitable for LLM consumption.",
  tags: %w[web scraping http markdown agent-tool],
  stars_from: [lore_agent, devtools],
  readme: <<~MD
    # web-scraper

    Fetch web pages and extract clean text content as markdown.

    ## Usage

    ```bash
    ./web-scraper https://example.com
    ./web-scraper --selector "article" https://blog.example.com/post
    ```

    ## Features

    - Extracts main content, strips nav/ads
    - Returns clean markdown for LLM consumption
    - CSS selector support for targeting specific elements

    ## License

    MIT
  MD
)

seed_repo(
  owner: agentkit,
  name: "file-search",
  description: "Search files by name pattern and content regex across a directory tree. Fast, agent-optimized output.",
  tags: %w[search files grep find cli agent-tool],
  readme: <<~MD
    # file-search

    Search files by name and content across a directory tree.

    ## Usage

    ```bash
    ./file-search --name "*.rb" --content "def initialize" ./src
    ```

    ## Features

    - Glob pattern matching for file names
    - Regex content search
    - JSON output mode for agent consumption

    ## License

    MIT
  MD
)

puts "Done! Seeded #{User.count} users, #{Repo.count} repos, #{Star.count} stars."

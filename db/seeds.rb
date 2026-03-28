# Seed demo repos for Lore MVP
#
# Creates demo users and repos with realistic metadata, multi-commit
# histories with READMEs, and embeddings for search. Idempotent — safe to re-run.

require "fileutils"
require "tmpdir"

# ---------- helpers ----------

def seed_repo(owner:, name:, description:, tags:, readme:, stars_from: [], display_stars: nil, extra_commits: [])
  if (existing = Repo.find_by(owner: owner, name: name))
    # Update star counts and stars for existing repos
    stars_from.each { |u| Star.find_or_create_by!(user: u, repo: existing) }
    existing.update_column(:stars_count, display_stars) if display_stars
    puts "  ✓ #{owner.username}/#{name} (exists) ⭐#{existing.stars_count}"
    return existing
  end

  puts "  Creating #{owner.username}/#{name}..."
  repo = Repo.create_with_bare_repo!(
    owner: owner,
    name: name,
    description: description,
    tags: tags
  )

  # Push commits into the bare repo
  Dir.mktmpdir("lore-seed") do |tmp|
    work = File.join(tmp, name)
    system("git", "clone", repo.path, work, exception: true, out: File::NULL, err: File::NULL)

    # Initial commit with README
    File.write(File.join(work, "README.md"), readme)
    system("git", "-C", work, "add", ".", exception: true, out: File::NULL, err: File::NULL)
    system("git", "-C", work,
      "-c", "user.name=Lore Seed", "-c", "user.email=seed@lore.dev",
      "commit", "-m", "Initial commit", exception: true, out: File::NULL, err: File::NULL)

    # Additional commits for realistic history
    extra_commits.each do |ec|
      file = ec[:file] || "README.md"
      path = File.join(work, file)
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, ec[:content])
      system("git", "-C", work, "add", ".", exception: true, out: File::NULL, err: File::NULL)
      system("git", "-C", work,
        "-c", "user.name=#{ec[:author] || 'Lore Seed'}",
        "-c", "user.email=#{ec[:email] || 'seed@lore.dev'}",
        "commit", "-m", ec[:message], exception: true, out: File::NULL, err: File::NULL)
    end

    system("git", "-C", work, "push", "origin", "main", exception: true, out: File::NULL, err: File::NULL)
  end

  repo.update!(last_pushed_at: Time.current)

  stars_from.each { |u| Star.find_or_create_by!(user: u, repo: repo) }

  # Override stars_count for demo-realistic numbers
  if display_stars
    repo.update_column(:stars_count, display_stars)
  end

  puts "    ✓ #{owner.username}/#{name} (#{tags.join(', ')}) ⭐#{repo.stars_count}"
  repo
end

# ---------- users ----------

puts "Seeding users..."
lore_agent = User.find_by(username: "lore-agent") || User.create_with_pat(username: "lore-agent")
devtools   = User.find_by(username: "devtools")   || User.create_with_pat(username: "devtools")
agentkit   = User.find_by(username: "agentkit")   || User.create_with_pat(username: "agentkit")
toolsmith  = User.find_by(username: "toolsmith")  || User.create_with_pat(username: "toolsmith")

# ---------- repos ----------

puts "Seeding repos..."

# Hero demo repo — must rank #1 for "send slack notification"
seed_repo(
  owner: lore_agent,
  name: "slack-notify",
  description: "Send Slack notifications via incoming webhooks. Simple, reliable, agent-friendly.",
  tags: %w[slack notification webhook messaging agent-tool],
  stars_from: [devtools, agentkit, toolsmith],
  display_stars: 34,
  extra_commits: [
    { file: "slack-notify.sh", message: "Add shell script for webhook posting",
      content: <<~SH },
        #!/usr/bin/env bash
        set -euo pipefail

        # slack-notify: Post a message to Slack via incoming webhook
        # Usage: ./slack-notify.sh "Your message here"
        #   Requires: SLACK_WEBHOOK_URL environment variable

        : "${SLACK_WEBHOOK_URL:?Set SLACK_WEBHOOK_URL to your Slack incoming webhook URL}"

        MESSAGE="${1:?Usage: slack-notify <message>}"

        curl -sf -X POST "$SLACK_WEBHOOK_URL" \\
          -H 'Content-Type: application/json' \\
          -d "{\\"text\\": \\"${MESSAGE}\\"}" \\
          && echo "Sent." \\
          || { echo "Failed to send notification." >&2; exit 1; }
      SH
    { file: "slack-notify.sh", message: "Add support for channel override and emoji",
      content: <<~SH },
        #!/usr/bin/env bash
        set -euo pipefail

        # slack-notify: Post a message to Slack via incoming webhook
        # Usage: ./slack-notify.sh [-c channel] [-e emoji] "Your message here"
        #   Requires: SLACK_WEBHOOK_URL environment variable

        : "${SLACK_WEBHOOK_URL:?Set SLACK_WEBHOOK_URL to your Slack incoming webhook URL}"

        CHANNEL=""
        EMOJI=""

        while getopts "c:e:" opt; do
          case $opt in
            c) CHANNEL="$OPTARG" ;;
            e) EMOJI="$OPTARG" ;;
          esac
        done
        shift $((OPTIND - 1))

        MESSAGE="${1:?Usage: slack-notify [-c channel] [-e emoji] <message>}"

        PAYLOAD="{\\"text\\": \\"${MESSAGE}\\""
        [ -n "$CHANNEL" ] && PAYLOAD+=", \\"channel\\": \\"${CHANNEL}\\""
        [ -n "$EMOJI" ] && PAYLOAD+=", \\"icon_emoji\\": \\"${EMOJI}\\""
        PAYLOAD+="}"

        curl -sf -X POST "$SLACK_WEBHOOK_URL" \\
          -H 'Content-Type: application/json' \\
          -d "$PAYLOAD" \\
          && echo "Sent." \\
          || { echo "Failed to send notification." >&2; exit 1; }
      SH
  ],
  readme: <<~MD
    # slack-notify

    A lightweight tool for sending Slack notifications via incoming webhooks.

    ## Usage

    ```bash
    export SLACK_WEBHOOK_URL="https://hooks.slack.com/services/T.../B.../xxx"
    ./slack-notify.sh "Deploy complete for myapp v2.1.0"
    ```

    ### Options

    - `-c channel` — Override the default channel
    - `-e emoji` — Set the bot icon emoji (e.g. `:rocket:`)

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

    ## Inputs

    - `SLACK_WEBHOOK_URL` (env) — Required. Your Slack webhook endpoint.
    - `message` (arg) — Required. The notification text.

    ## Outputs

    - Prints "Sent." on success, exits 0.
    - Prints error to stderr on failure, exits 1.

    ## Dependencies

    - `curl`
    - `bash`

    ## License

    MIT
  MD
)

seed_repo(
  owner: lore_agent,
  name: "send-email",
  description: "Send emails via SMTP with subject, body, and attachments. Works with any SMTP server.",
  tags: %w[email smtp notification agent-tool],
  stars_from: [devtools, agentkit, toolsmith],
  display_stars: 22,
  extra_commits: [
    { file: "send-email.py", message: "Add Python email sender script",
      content: <<~PY }
        #!/usr/bin/env python3
        """send-email: Send emails via SMTP."""
        import smtplib, os, sys
        from email.message import EmailMessage

        def send(to, subject, body):
            msg = EmailMessage()
            msg["From"] = os.environ["SMTP_FROM"]
            msg["To"] = to
            msg["Subject"] = subject
            msg.set_content(body)

            with smtplib.SMTP(os.environ["SMTP_HOST"], int(os.environ.get("SMTP_PORT", 587))) as s:
                s.starttls()
                s.login(os.environ["SMTP_USER"], os.environ["SMTP_PASS"])
                s.send_message(msg)
            print(f"Sent to {to}")

        if __name__ == "__main__":
            send(sys.argv[1], sys.argv[2], sys.argv[3])
      PY
  ],
  readme: <<~MD
    # send-email

    Send emails via SMTP from the command line or agent workflows.

    ## Usage

    ```bash
    export SMTP_HOST="smtp.gmail.com" SMTP_USER="you@gmail.com" SMTP_PASS="..." SMTP_FROM="you@gmail.com"
    python3 send-email.py "recipient@example.com" "Subject line" "Email body"
    ```

    ## Inputs

    - `SMTP_HOST`, `SMTP_USER`, `SMTP_PASS`, `SMTP_FROM` (env) — SMTP configuration
    - `to`, `subject`, `body` (args) — Email content

    ## Outputs

    - Prints confirmation on success, exits 0.

    ## Dependencies

    - Python 3

    ## License

    MIT
  MD
)

seed_repo(
  owner: lore_agent,
  name: "github-issue-creator",
  description: "Create GitHub issues from structured input. Supports labels, assignees, and templates.",
  tags: %w[github issues automation agent-tool api],
  stars_from: [devtools, toolsmith],
  display_stars: 14,
  extra_commits: [
    { file: "create-issue.sh", message: "Add shell script for issue creation",
      content: <<~SH }
        #!/usr/bin/env bash
        set -euo pipefail
        : "${GITHUB_TOKEN:?Set GITHUB_TOKEN}"
        REPO="${1:?Usage: create-issue <owner/repo> <title> [body]}"
        TITLE="${2:?Provide a title}"
        BODY="${3:-}"
        curl -sf -X POST "https://api.github.com/repos/$REPO/issues" \\
          -H "Authorization: token $GITHUB_TOKEN" \\
          -H "Content-Type: application/json" \\
          -d "{\\"title\\": \\"$TITLE\\", \\"body\\": \\"$BODY\\"}"
        echo "Issue created."
      SH
  ],
  readme: <<~MD
    # github-issue-creator

    Create GitHub issues programmatically from structured input.

    ## Usage

    ```bash
    export GITHUB_TOKEN="ghp_..."
    ./create-issue.sh owner/repo "Bug: crash on startup" "Steps to reproduce..."
    ```

    ## Inputs

    - `GITHUB_TOKEN` (env) — Required. GitHub personal access token.
    - `repo` (arg) — Required. Target repository (owner/name).
    - `title` (arg) — Required. Issue title.
    - `body` (arg) — Optional. Issue body.

    ## Outputs

    - Prints "Issue created." on success.

    ## Dependencies

    - `curl`, `bash`

    ## License

    MIT
  MD
)

seed_repo(
  owner: devtools,
  name: "json-formatter",
  description: "Pretty-print and validate JSON from stdin or files. Supports color output and jq-style filtering.",
  tags: %w[json formatting cli utility developer-tools],
  stars_from: [lore_agent, agentkit],
  display_stars: 11,
  readme: <<~MD
    # json-formatter

    Pretty-print and validate JSON data from stdin or files.

    ## Usage

    ```bash
    echo '{"key":"value"}' | ./json-formatter
    ./json-formatter data.json
    ./json-formatter --filter '.users[].name' data.json
    ```

    ## Inputs

    - JSON from stdin or a file path (arg)
    - `--filter` — Optional jq-style field path

    ## Outputs

    - Formatted JSON to stdout. Exit 1 on invalid JSON.

    ## Dependencies

    - Python 3

    ## License

    MIT
  MD
)

seed_repo(
  owner: devtools,
  name: "env-checker",
  description: "Verify that required environment variables are set before running a command. Fail fast with clear errors.",
  tags: %w[environment validation cli devops agent-tool],
  stars_from: [lore_agent, agentkit, toolsmith],
  display_stars: 18,
  extra_commits: [
    { file: "env-checker.sh", message: "Add env-checker shell script",
      content: <<~SH }
        #!/usr/bin/env bash
        set -euo pipefail
        REQUIRED=""
        while [[ $# -gt 0 ]]; do
          case "$1" in
            --require) REQUIRED="$2"; shift 2 ;;
            --) shift; break ;;
            *) echo "Unknown arg: $1" >&2; exit 1 ;;
          esac
        done
        MISSING=()
        IFS=',' read -ra VARS <<< "$REQUIRED"
        for var in "${VARS[@]}"; do
          [ -z "${!var:-}" ] && MISSING+=("$var")
        done
        if [ ${#MISSING[@]} -gt 0 ]; then
          echo "Missing required env vars: ${MISSING[*]}" >&2; exit 1
        fi
        exec "$@"
      SH
  ],
  readme: <<~MD
    # env-checker

    Verify required environment variables before running a command.

    ## Usage

    ```bash
    ./env-checker.sh --require SLACK_WEBHOOK_URL,GITHUB_TOKEN -- ./deploy.sh
    ```

    ## Inputs

    - `--require VAR1,VAR2,...` — Comma-separated list of required vars
    - `-- command` — The command to execute if all vars are set

    ## Outputs

    - Runs the command if all vars present. Lists missing vars and exits 1 otherwise.

    ## Dependencies

    - `bash`

    ## License

    MIT
  MD
)

seed_repo(
  owner: devtools,
  name: "fetch-url",
  description: "Fetch a URL and return the response body as clean text or JSON. Handles redirects, timeouts, retries.",
  tags: %w[http fetch curl web agent-tool],
  stars_from: [lore_agent, agentkit, toolsmith],
  display_stars: 19,
  readme: <<~MD
    # fetch-url

    Fetch a URL and return the response body. Handles redirects, timeouts, and retries.

    ## Usage

    ```bash
    ./fetch-url https://api.example.com/data
    ./fetch-url --json https://api.example.com/users
    ```

    ## Inputs

    - URL (arg) — Required. The URL to fetch.
    - `--json` — Parse and pretty-print JSON response.

    ## Outputs

    - Response body to stdout. Exit 1 on failure.

    ## Dependencies

    - `curl`

    ## License

    MIT
  MD
)

seed_repo(
  owner: agentkit,
  name: "web-scraper",
  description: "Fetch and extract text content from web pages. Returns clean markdown suitable for LLM consumption.",
  tags: %w[web scraping http markdown agent-tool],
  stars_from: [lore_agent, devtools, toolsmith],
  display_stars: 15,
  readme: <<~MD
    # web-scraper

    Fetch web pages and extract clean text content as markdown.

    ## Usage

    ```bash
    ./web-scraper https://example.com
    ./web-scraper --selector "article" https://blog.example.com/post
    ```

    ## Inputs

    - URL (arg) — Required. The page to scrape.
    - `--selector` — Optional CSS selector to target specific elements.

    ## Outputs

    - Clean markdown text to stdout.

    ## Dependencies

    - Python 3, beautifulsoup4

    ## License

    MIT
  MD
)

seed_repo(
  owner: agentkit,
  name: "file-search",
  description: "Search files by name pattern and content regex across a directory tree. Fast, agent-optimized output.",
  tags: %w[search files grep find cli agent-tool],
  stars_from: [lore_agent],
  display_stars: 7,
  readme: <<~MD
    # file-search

    Search files by name and content across a directory tree.

    ## Usage

    ```bash
    ./file-search --name "*.rb" --content "def initialize" ./src
    ```

    ## Inputs

    - `--name` — Glob pattern for file names
    - `--content` — Regex for file content
    - Directory path (arg) — Where to search

    ## Outputs

    - Matching file paths and line numbers. `--json` for structured output.

    ## Dependencies

    - `bash`, `find`, `grep`

    ## License

    MIT
  MD
)

seed_repo(
  owner: toolsmith,
  name: "csv-parser",
  description: "Parse CSV files and output as JSON, TSV, or filtered rows. Handles headers, quoting, and large files.",
  tags: %w[csv parsing data cli agent-tool],
  stars_from: [lore_agent, devtools, agentkit],
  display_stars: 10,
  extra_commits: [
    { file: "csv-parser.py", message: "Add Python CSV parser",
      content: <<~PY }
        #!/usr/bin/env python3
        """csv-parser: Convert CSV to JSON or filter rows."""
        import csv, json, sys

        def parse(path, output_format="json", filter_col=None, filter_val=None):
            with open(path) as f:
                reader = csv.DictReader(f)
                rows = list(reader)
            if filter_col and filter_val:
                rows = [r for r in rows if r.get(filter_col) == filter_val]
            if output_format == "json":
                print(json.dumps(rows, indent=2))
            else:
                for r in rows:
                    print("\\t".join(r.values()))

        if __name__ == "__main__":
            parse(sys.argv[1])
      PY
  ],
  readme: <<~MD
    # csv-parser

    Parse CSV files and output as JSON, TSV, or filtered rows.

    ## Usage

    ```bash
    python3 csv-parser.py data.csv
    python3 csv-parser.py data.csv --filter "status=active"
    ```

    ## Inputs

    - CSV file path (arg) — Required.
    - `--filter col=val` — Optional row filter.

    ## Outputs

    - JSON array to stdout (default), or TSV with `--tsv`.

    ## Dependencies

    - Python 3

    ## License

    MIT
  MD
)

seed_repo(
  owner: toolsmith,
  name: "screenshot-tool",
  description: "Capture screenshots of web pages as PNG. Headless browser, configurable viewport, full-page support.",
  tags: %w[screenshot browser headless png web agent-tool],
  stars_from: [agentkit, devtools],
  display_stars: 9,
  readme: <<~MD
    # screenshot-tool

    Capture screenshots of web pages as PNG files.

    ## Usage

    ```bash
    ./screenshot-tool https://example.com output.png
    ./screenshot-tool --full-page --width 1440 https://example.com page.png
    ```

    ## Inputs

    - URL (arg) — Required. Page to capture.
    - Output path (arg) — Required. Where to save the PNG.
    - `--full-page` — Capture the entire scrollable page.
    - `--width N` — Viewport width in pixels (default: 1280).

    ## Outputs

    - PNG file at the specified path.

    ## Dependencies

    - Node.js, Puppeteer

    ## License

    MIT
  MD
)

seed_repo(
  owner: toolsmith,
  name: "cron-scheduler",
  description: "Schedule and manage recurring shell commands with cron syntax. Lightweight alternative to system crontab.",
  tags: %w[cron scheduling automation shell agent-tool],
  stars_from: [lore_agent, agentkit],
  display_stars: 6,
  readme: <<~MD
    # cron-scheduler

    Schedule recurring shell commands using cron expressions.

    ## Usage

    ```bash
    ./cron-scheduler add "*/5 * * * *" "curl -s https://api.example.com/health"
    ./cron-scheduler list
    ./cron-scheduler remove 1
    ```

    ## Inputs

    - `add "cron-expr" "command"` — Schedule a new job
    - `list` — Show all scheduled jobs
    - `remove ID` — Remove a job by ID

    ## Outputs

    - Job list to stdout. Logs execution to `~/.cron-scheduler/log`.

    ## Dependencies

    - `bash`

    ## License

    MIT
  MD
)

seed_repo(
  owner: agentkit,
  name: "markdown-renderer",
  description: "Render markdown to HTML or plain text. Supports GFM tables, code blocks, and syntax highlighting.",
  tags: %w[markdown html rendering text agent-tool],
  stars_from: [lore_agent, toolsmith],
  display_stars: 8,
  readme: <<~MD
    # markdown-renderer

    Render markdown documents to HTML or plain text.

    ## Usage

    ```bash
    ./markdown-renderer README.md
    ./markdown-renderer --html README.md > output.html
    ```

    ## Inputs

    - Markdown file path (arg) — Required.
    - `--html` — Output as HTML (default: plain text).

    ## Outputs

    - Rendered content to stdout.

    ## Dependencies

    - Python 3, markdown library

    ## License

    MIT
  MD
)

puts "Done! Seeded #{User.count} users, #{Repo.count} repos, #{Star.count} stars."

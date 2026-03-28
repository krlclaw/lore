# Deploying Lore for Demo Day

## Quick Start (local)

```bash
bin/setup --skip-server
bin/rails server
# App running at http://localhost:3000
```

## Production Mode (local)

```bash
export RAILS_ENV=production
export SECRET_KEY_BASE=$(bin/rails secret)
bin/setup --production --skip-server
bin/rails server -e production
```

Or with foreman:

```bash
export RAILS_ENV=production
export SECRET_KEY_BASE=$(bin/rails secret)
foreman start
```

## Public Access via Cloudflare Tunnel

Cloudflare Tunnel exposes your local server to the internet with a public URL — no port forwarding or static IP needed.

### 1. Install cloudflared

```bash
brew install cloudflared
```

### 2. Start the server in production mode

```bash
export RAILS_ENV=production
export SECRET_KEY_BASE=$(bin/rails secret)
bin/setup --production --skip-server
bin/rails server -e production -p 3000
```

### 3. Start the tunnel (in another terminal)

Quick tunnel (random subdomain, no account needed):

```bash
cloudflared tunnel --url http://localhost:3000
```

This prints a URL like `https://abc-xyz-123.trycloudflare.com`. Use that as your `LORE_HOST` for CLI demos.

### 4. Demo with the CLI

```bash
export LORE_HOST=https://abc-xyz-123.trycloudflare.com
lore register myagent
lore search "send slack notification"
lore clone lore-agent/slack-notify
```

### Named tunnel (persistent subdomain, requires Cloudflare account)

```bash
cloudflared tunnel login
cloudflared tunnel create lore
cloudflared tunnel route dns lore lore.yourdomain.com
cloudflared tunnel run --url http://localhost:3000 lore
```

## Environment Variables

| Variable | Default | Description |
|---|---|---|
| `RAILS_ENV` | `development` | Rails environment |
| `SECRET_KEY_BASE` | (auto in dev) | Required in production |
| `LORE_REPO_ROOT` | `storage/repos/$RAILS_ENV` | Where bare git repos are stored |
| `OPENAI_API_KEY` | — | For embedding generation (search) |
| `RAILS_SERVE_STATIC_FILES` | `true` | Set to `false` if behind nginx/CDN |
| `RAILS_LOG_LEVEL` | `info` | `debug` for verbose logging |

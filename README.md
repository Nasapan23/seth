# Seth - Secure OpenClaw Assistant

> **My Story**: I've wanted to build something like this for a long time - a personal AI "employee" that works on my behalf, handles tasks I delegate, and can even spawn sub-workers for specific jobs. Then I discovered [OpenClaw](https://openclaw.ai). Someone built exactly what I envisioned, and honestly, they did it better than I probably could have. But that doesn't mean I can't make it *mine*. Seth is my implementation - a manager, a secretary, a digital workforce that only does what I authorize. This is my first interaction with OpenClaw, built based on what I learned from their documentation.

## What is Seth?

Seth is a self-hosted AI assistant built on [OpenClaw](https://openclaw.ai), designed to run anywhere Docker runs - your laptop, a VPS, or a homelab server.

Think of Seth as your personal AI employee system:
- **A Manager**: Delegates and coordinates tasks
- **A Secretary**: Handles reminders, calendar, notifications
- **A Workforce**: Can create sub-agents for specific jobs
- **Fully Under Your Control**: Only does what you explicitly authorize

## Vision

The goal is to have a digital workforce that:
- Works only on tasks I delegate
- Can spawn specialized sub-workers for specific jobs
- Maintains strict boundaries (no unauthorized actions)
- Grows capabilities progressively (skills added in phases)
- Runs entirely on my infrastructure (no cloud dependency)

## Features

- **Full OpenClaw Power** - Browser automation, web search, shell execution, all enabled
- **Sub-Agent System** - Spawn worker agents for parallel task execution
- **Browser Automation** - Full Playwright/Chromium control for web tasks
- **Scheduled Tasks** - Cron jobs for recurring automation
- **Memory System** - Persistent knowledge across sessions
- **Production-safe** - Container isolation, token auth, non-root user
- **Fully reproducible** - Git + Docker, no secrets in images
- **Cost-Optimized** - Cheap models for casual chat, smart models on demand

## Cost Optimization

Seth uses OpenRouter to access all major AI models with a single API key, with a smart routing strategy to minimize costs.

### Model Strategy

| Use Case | Model | Cost (OpenRouter) |
|----------|-------|-------------------|
| Casual chat, greetings | `anthropic/claude-3-haiku` | ~$0.25/1M input |
| Complex tasks | `anthropic/claude-sonnet-4` | ~$3/1M input |
| Maximum power | `anthropic/claude-opus-4` | ~$15/1M input |
| Sub-agents (workers) | `anthropic/claude-3-haiku` | ~$0.25/1M input |
| Fallback | Free models (Llama, Gemma) | $0 |

### Switching Models

In chat, switch models with `/model <alias>`:

```
/model cheap    # Claude 3 Haiku (default)
/model smart    # Claude Sonnet 4 (complex tasks)
/model opus     # Claude Opus 4 (maximum power)
/model mini     # GPT-4o-mini
/model gpt      # GPT-4o
/model llama    # Llama 3.3 70B
/model gemini   # Gemini 2.0 Flash
```

### Thinking Mode

Thinking is OFF by default to save tokens. Enable for complex tasks:

```
/thinking high  # Enable extended thinking
/thinking off   # Disable (default)
```

### Future: Local Models

When you run local LLMs (Ollama), add them to the config:

```json
"models": {
  "ollama/llama3.3": { "alias": "local" }
}
```

Then `/model local` for completely free local inference.

## Quick Start

Works on any platform with Docker: Windows, macOS, Linux (ARM64 or x86_64).

### Prerequisites

- Docker Desktop (Windows/macOS) or Docker Engine (Linux)
- OpenRouter API key (get one at [openrouter.ai/keys](https://openrouter.ai/keys))
- For production: nginx reverse proxy for HTTPS

### Local Development (3 commands)

```bash
# 1. Configure
cp .env.example .env
# Edit .env: add SETH_GATEWAY_TOKEN and API key

# 2. Build
docker compose build

# 3. Run
docker compose up -d
```

Open http://localhost:18789 and enter your gateway token.

### Generate Gateway Token

```bash
# Linux/macOS/WSL
openssl rand -hex 32

# Windows PowerShell
-join ((1..32) | ForEach-Object { '{0:x2}' -f (Get-Random -Max 256) })

# Or just use any secure random string
```

### Production Deployment (Portainer)

1. Push repo to your server
2. In Portainer: Stacks → Add Stack
3. Upload `compose.yml` or point to git repo
4. Add environment variables from `.env`
5. Deploy

### Production with nginx

See [ops/nginx-config.md](ops/nginx-config.md) for HTTPS reverse proxy config.

Access at `https://seth.yourdomain.com`

## Architecture

```
                    ┌─────────────┐
                    │   nginx     │
                    │  (HTTPS)    │
                    └──────┬──────┘
                           │
                    ┌──────▼──────┐
                    │    Seth     │
                    │  (OpenClaw) │
                    │  Port 18789 │
                    └──────┬──────┘
                           │
         ┌─────────────────┼─────────────────┐
         │                 │                 │
    ┌────▼────┐      ┌─────▼─────┐     ┌─────▼─────┐
    │ Config  │      │ Workspace │     │  Skills   │
    │  data/  │      │   data/   │     │  (r/o)    │
    │openclaw │      │ workspace │     │           │
    └─────────┘      └───────────┘     └───────────┘
```

## Directory Structure

```
seth/
  compose.yml          # Docker Compose stack
  Dockerfile           # Custom Ubuntu ARM64 image
  .env.example         # Environment template
  .gitignore           # Strict exclusions
  
  prompts/             # Seth identity (mounted read-only)
    system.md          # Identity & role
    safety.md          # Safety rules
    escalation.md      # Tool policies
  
  skills/              # Local skills (mounted read-only)
    local/
      reminders/
      calendar/
    allowlist.yml
  
  config/              # Configuration templates
    openclaw.json5.example
  
  ops/                 # Operations documentation
    hardening.md
    update.md
    backup.md
    roadmap.md
    nginx-config.md
  
  scripts/
    entrypoint.sh
    healthcheck.sh
  
  data/                # Runtime data (gitignored)
    openclaw/
    workspace/
```

## OpenClaw Capabilities (Full Power Mode)

Since Seth runs in a fully Dockerized environment, all OpenClaw tools are safely enabled. The container itself provides isolation, so there's no risk to your host system.

### Browser Tool (`browser`)

Full headless Chromium automation via Playwright:

- **Navigation**: Open URLs, manage tabs, navigate history
- **Snapshots**: AI-friendly page snapshots for understanding content
- **Actions**: Click, type, drag, select, hover, scroll
- **Screenshots/PDFs**: Capture pages for review
- **Form automation**: Fill forms, upload files, handle dialogs

```
Seth, search for the latest ARM64 Docker images and summarize the top 5 results.
```

### Sub-Agents (`sessions_spawn`)

The "employee system" - spawn dedicated workers for parallel tasks:

- **Task delegation**: Main agent delegates to specialized workers
- **Parallel execution**: Up to 4 concurrent sub-agents
- **Isolated sessions**: Each sub-agent has its own context
- **Announce back**: Results reported to the main chat

```
Seth, spawn a research worker to find pricing for cloud GPU instances,
and another worker to compile our current infrastructure costs.
```

### Exec Tool (`exec`)

Shell command execution within the container:

- **File operations**: Read, write, create files in workspace
- **Script execution**: Run Python, Node.js, bash scripts
- **Background processes**: Long-running tasks with process management
- **Development tasks**: Git, npm, build tools

```
Seth, clone the repo and run the test suite, let me know if anything fails.
```

### Cron Jobs (`cron`)

Scheduled and recurring tasks:

- **One-shot reminders**: "Remind me in 2 hours"
- **Recurring jobs**: "Every morning at 8am, summarize my inbox"
- **Isolated execution**: Jobs run in dedicated sessions
- **Channel delivery**: Results sent to configured channels

```
Seth, create a cron job to check our server health every 4 hours.
```

### Web Tools (`web_search`, `web_fetch`)

Internet research capabilities:

- **Web search**: Search via Brave Search API (requires `BRAVE_API_KEY`)
- **Web fetch**: Extract content from any URL as markdown
- **Research tasks**: Gather information, compare options, summarize findings

```
Seth, research the pros and cons of Kubernetes vs Docker Swarm for small teams.
```

### Memory System (`memory`)

Persistent knowledge across sessions:

- **Store facts**: Remember information between conversations
- **Search memory**: Recall stored knowledge by context
- **Build knowledge base**: Accumulate learnings over time

```
Seth, remember that our production server IP is 10.0.0.1 and it uses port 443.
```

### Session Tools

Multi-session management:

- `sessions_list`: View all active sessions
- `sessions_history`: Review past conversations
- `sessions_send`: Send messages between sessions
- `session_status`: Check current model and settings

### Tool Groups Reference

| Group | Tools |
|-------|-------|
| `group:runtime` | exec, bash, process |
| `group:fs` | read, write, edit, apply_patch |
| `group:web` | web_search, web_fetch |
| `group:ui` | browser, canvas |
| `group:sessions` | sessions_list, sessions_history, sessions_send, sessions_spawn, session_status |
| `group:automation` | cron, gateway |

For complete tool documentation, see [OpenClaw Tools](https://docs.openclaw.ai/tools).

## Skill Phases

Additional skills beyond core tools:

| Phase | Skills | Status |
|-------|--------|--------|
| 1 | Reminders, Calendar (read-only) | Enabled |
| 2 | Notifications | Planned |
| 3 | Email | Planned |
| 4 | Voice | Future |

See [ops/roadmap.md](ops/roadmap.md) for details.

## Security

The container provides the security boundary:

- **Token authentication** - Gateway token required for all access
- **Container isolation** - All tools run inside Docker, not on host
- **Non-root user** - Container runs as `seth` user (UID 1000)
- **No Docker socket** - Cannot escape container or spawn containers
- **Read-only skills** - Skill definitions cannot be modified at runtime
- **No elevated mode** - Host access disabled even if requested
- **Tool policy** - Sub-agents have restricted tools (no gateway/cron)

### What Seth CAN do (inside container):
- Execute shell commands
- Browse the web with full automation
- Read/write files in workspace
- Schedule cron jobs
- Spawn sub-agents

### What Seth CANNOT do:
- Access host filesystem
- Install system packages on host
- Access Docker socket
- Modify its own configuration (read-only prompts)
- Escape the container

See [ops/hardening.md](ops/hardening.md) for full security guide.

## Configuration

The OpenClaw configuration is auto-generated on first run. To customize:

1. Copy the template: `cp config/openclaw.json5.example data/openclaw/openclaw.json`
2. Edit `data/openclaw/openclaw.json`
3. Restart the container

Key configuration options:

- `gateway.auth.token` - Set via `SETH_GATEWAY_TOKEN` env var
- `agents.defaults.model` - Set via `SETH_MODEL` env var
- `tools.deny` - Tools to disable
- `skills.load.extraDirs` - Additional skill directories

## Updating

See [ops/update.md](ops/update.md) for update procedures.

```bash
# Change version in .env
SETH_IMAGE_TAG=2026.2.1

# Redeploy via Portainer or:
docker compose build --no-cache
docker compose up -d
```

## Backup

See [ops/backup.md](ops/backup.md) for backup procedures.

```bash
# Quick backup
tar -czf seth-backup-$(date +%Y%m%d).tar.gz ./data/ .env
```

## Troubleshooting

### Container won't start

```bash
docker logs seth
# Check for missing env vars or config errors
```

### WebSocket connection fails

- Verify nginx WebSocket headers are configured
- Check gateway token is correct
- Ensure HTTPS is properly configured

### Model not responding

- Check API key is set correctly
- Verify model name format: `provider/model`
- Check model provider status

## Credits & Acknowledgments

This project is built on **[OpenClaw](https://openclaw.ai)** - an incredible open-source AI assistant platform.

### OpenClaw

- **Website**: [openclaw.ai](https://openclaw.ai)
- **Documentation**: [docs.openclaw.ai](https://docs.openclaw.ai)
- **GitHub**: [github.com/openclaw/openclaw](https://github.com/openclaw/openclaw)
- **Discord**: [Join the community](https://discord.gg/openclaw)

Created by **Peter Steinberger** ([@steipete](https://github.com/steipete)) and an amazing community of contributors.

OpenClaw provides the core runtime, gateway, agent system, skills framework, and multi-channel support that makes Seth possible. I'm just building on top of their excellent work.

## License

MIT

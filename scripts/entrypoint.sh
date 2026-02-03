#!/bin/bash
set -e

# =============================================================================
# Seth Entrypoint Script
# Handles initialization and mode switching
# =============================================================================

# When running as root (e.g. container start with volume mount), fix ownership
# so OpenClaw can read/write ~/.openclaw without EPERM on chmod
if [ "$(id -u)" = "0" ]; then
    chown -R seth:seth /home/seth/.openclaw /home/seth/workspace 2>/dev/null || true
    exec runuser -u seth -- /bin/bash "$0" "$@"
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[seth]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[seth]${NC} $1"
}

log_error() {
    echo -e "${RED}[seth]${NC} $1"
}

# =============================================================================
# Initialize directories
# =============================================================================
init_directories() {
    log_info "Initializing directories..."
    
    # Ensure directories exist with correct permissions
    mkdir -p /home/seth/.openclaw/credentials
    mkdir -p /home/seth/.openclaw/agents
    mkdir -p /home/seth/.openclaw/skills
    mkdir -p /home/seth/workspace/memory
    mkdir -p /home/seth/workspace/skills
    
    # Link external skills to workspace
    if [ -d "/opt/seth/skills" ] && [ "$(ls -A /opt/seth/skills 2>/dev/null)" ]; then
        log_info "Linking external skills..."
        for skill_dir in /opt/seth/skills/*/; do
            if [ -d "$skill_dir" ]; then
                skill_name=$(basename "$skill_dir")
                target="/home/seth/workspace/skills/$skill_name"
                if [ ! -e "$target" ]; then
                    ln -sf "$skill_dir" "$target"
                    log_info "  Linked skill: $skill_name"
                fi
            fi
        done
    fi
}

# =============================================================================
# Initialize OpenClaw configuration (Full Power + Cost Optimized)
# =============================================================================
init_config() {
    local config_file="/home/seth/.openclaw/openclaw.json"
    
    if [ ! -f "$config_file" ]; then
        log_info "Creating OpenClaw configuration (cost-optimized mode)..."
        
        # Model strategy from environment (OpenRouter model IDs)
        local cheap_model="${SETH_MODEL:-openrouter/anthropic/claude-3-haiku}"
        local smart_model="${SETH_SMART_MODEL:-openrouter/anthropic/claude-sonnet-4}"
        local subagent_model="${SETH_SUBAGENT_MODEL:-openrouter/anthropic/claude-3-haiku}"
        local port="${SETH_PORT:-18789}"
        local bind="${SETH_BIND:-loopback}"
        
        cat > "$config_file" << EOF
{
  "gateway": {
    "mode": "local",
    "bind": "${bind}",
    "port": ${port},
    "auth": {
      "mode": "token"
    }
  },
  "agents": {
    "defaults": {
      "workspace": "/home/seth/workspace",
      "model": {
        "primary": "${cheap_model}",
        "fallbacks": [
          "openrouter/meta-llama/llama-3.3-70b-instruct:free",
          "openrouter/google/gemma-2-9b-it:free"
        ]
      },
      "models": {
        "openrouter/auto": { "alias": "auto" },
        "${cheap_model}": { "alias": "cheap" },
        "${smart_model}": { "alias": "smart" },
        "openrouter/anthropic/claude-opus-4": { "alias": "opus" },
        "openrouter/openai/gpt-4o-mini": { "alias": "mini" },
        "openrouter/openai/gpt-4o": { "alias": "gpt" },
        "openrouter/meta-llama/llama-3.3-70b-instruct": { "alias": "llama" },
        "openrouter/google/gemini-2.0-flash-001": { "alias": "gemini" },
        "openrouter/qwen/qwen-2.5-coder-32b-instruct": { "alias": "qwen-coder" }
      },
      "sandbox": {
        "mode": "off"
      },
      "subagents": {
        "model": "${subagent_model}",
        "maxConcurrent": 4
      },
      "thinkingDefault": "off",
      "timeoutSeconds": 900
    },
    "list": [
      {
        "id": "main",
        "default": true,
        "identity": {
          "name": "Seth",
          "theme": "secure personal assistant and task manager",
          "emoji": "🤖"
        },
        "subagents": {
          "allowAgents": ["*"]
        }
      }
    ]
  },
  "browser": {
    "enabled": true,
    "executablePath": "/usr/bin/google-chrome-stable",
    "defaultProfile": "openclaw",
    "attachOnly": true,
    "headless": true,
    "noSandbox": true,
    "profiles": {
      "openclaw": {
        "cdpPort": 18800,
        "color": "FFFFFF"
      },
      "chrome": {
        "cdpPort": 18800,
        "color": "FFFFFF"
      }
    }
  },
  "skills": {
    "load": {
      "extraDirs": ["/opt/seth/skills"]
    }
  },
    "tools": {
      "elevated": {
        "enabled": false
      },
      "deny": ["canvas", "nodes"],
    "exec": {
      "notifyOnExit": true
    },
    "web": {
      "search": {
        "enabled": true,
        "provider": "perplexity",
        "maxResults": 10,
        "perplexity": {
          "model": "perplexity/sonar-pro"
        }
      },
      "fetch": {
        "enabled": true,
        "maxChars": 50000
      }
    },
    "subagents": {
      "tools": {
        "deny": ["gateway", "cron"]
      }
    }
  },
  "cron": {
    "enabled": true,
    "maxConcurrentRuns": 2
  },
  "logging": {
    "level": "info",
    "consoleStyle": "pretty"
  }
}
EOF
        log_info "Configuration created at $config_file"
        log_info "  MODEL STRATEGY (cost-optimized):"
        log_info "    - Default (casual): ${cheap_model}"
        log_info "    - Smart (/model smart): ${smart_model}"
        log_info "    - Sub-agents: ${subagent_model}"
        log_info "    - Thinking: OFF (save tokens)"
        log_info "  TOOLS:"
        log_info "    - Browser: ENABLED"
        log_info "    - Web search/fetch: ENABLED"
        log_info "    - Cron jobs: ENABLED"
        log_info "    - Sub-agents: ENABLED (max 4)"
        log_info "  MODEL SWITCHING:"
        log_info "    /model auto   - OpenRouter Auto (intelligent routing)"
        log_info "    /model smart  - Claude Sonnet (complex tasks)"
        log_info "    /model opus   - Claude Opus (maximum power)"
        log_info "    /model cheap  - Claude Haiku (back to default)"
    else
        log_info "Using existing configuration"
    fi
}

# =============================================================================
# Copy prompts to workspace (bootstrap files)
# =============================================================================
init_prompts() {
    log_info "Initializing workspace prompts..."
    
    # Copy system.md as AGENTS.md if not exists
    if [ -f "/opt/seth/prompts/system.md" ] && [ ! -f "/home/seth/workspace/AGENTS.md" ]; then
        cp /opt/seth/prompts/system.md /home/seth/workspace/AGENTS.md
        log_info "  Created AGENTS.md from system.md"
    fi
    
    # Copy safety.md as SOUL.md if not exists
    if [ -f "/opt/seth/prompts/safety.md" ] && [ ! -f "/home/seth/workspace/SOUL.md" ]; then
        cp /opt/seth/prompts/safety.md /home/seth/workspace/SOUL.md
        log_info "  Created SOUL.md from safety.md"
    fi
    
    # Copy escalation.md as TOOLS.md if not exists
    if [ -f "/opt/seth/prompts/escalation.md" ] && [ ! -f "/home/seth/workspace/TOOLS.md" ]; then
        cp /opt/seth/prompts/escalation.md /home/seth/workspace/TOOLS.md
        log_info "  Created TOOLS.md from escalation.md"
    fi
    
    # Generate SKILLS.md if not exists
    if [ ! -f "/home/seth/workspace/SKILLS.md" ]; then
        generate_skills_doc
        log_info "  Created SKILLS.md catalog"
    fi
}

# =============================================================================
# Generate SKILLS.md documentation from available skills
# =============================================================================
generate_skills_doc() {
    cat > /home/seth/workspace/SKILLS.md << 'SKILLS_EOF'
# Seth Skills Catalog

This file documents all available skills that Seth can use to accomplish tasks.

## Available Skills

SKILLS_EOF

    # Scan skills directory and add each skill
    if [ -d "/home/seth/workspace/skills" ]; then
        for skill_link in /home/seth/workspace/skills/*/; do
            if [ -d "$skill_link" ]; then
                skill_name=$(basename "$skill_link")
                skill_file="$skill_link/SKILL.md"
                
                if [ -f "$skill_file" ]; then
                    # Extract description from skill file metadata
                    description=$(grep "^description:" "$skill_file" 2>/dev/null | sed 's/description: *//' || echo "No description")
                    emoji=$(grep "emoji" "$skill_file" 2>/dev/null | sed -n 's/.*"emoji":"\([^"]*\)".*/\1/p' || echo "📦")
                    
                    cat >> /home/seth/workspace/SKILLS.md << SKILL_ENTRY

### ${emoji} ${skill_name}
**Path**: \`/home/seth/workspace/skills/${skill_name}/\`
**Description**: ${description}

**Usage**: Read the skill file for detailed capabilities:
\`\`\`
Read /home/seth/workspace/skills/${skill_name}/SKILL.md
\`\`\`

---
SKILL_ENTRY
                fi
            fi
        done
    fi
    
    cat >> /home/seth/workspace/SKILLS.md << 'SKILLS_FOOTER'

## How to Use Skills

Skills provide specialized capabilities for specific tasks. To use a skill:

1. **Read the skill**: `Read /home/seth/workspace/skills/<skill-name>/SKILL.md`
2. **Follow its instructions**: Each skill has specific usage patterns
3. **Delegate to sub-agents**: Some skills are best used via delegation

## Skill Locations

- **System Skills**: `/opt/seth/skills/` (container-managed)
- **Workspace Skills**: `/home/seth/workspace/skills/` (linked to system)

---

*Auto-generated at startup*
*Skills are loaded from: /opt/seth/skills/*
SKILLS_FOOTER
}

# =============================================================================
# Detect browser executable path (Chrome for amd64, Chromium for arm64)
# =============================================================================
detect_browser_path() {
    # Order of preference: Google Chrome, Chromium, chromium-browser
    if [ -x "/usr/bin/google-chrome-stable" ]; then
        echo "/usr/bin/google-chrome-stable"
    elif [ -x "/usr/bin/chromium" ]; then
        echo "/usr/bin/chromium"
    elif [ -x "/usr/bin/chromium-browser" ]; then
        echo "/usr/bin/chromium-browser"
    elif [ -x "/snap/bin/chromium" ]; then
        echo "/snap/bin/chromium"
    else
        echo ""
    fi
}

# =============================================================================
# Verify browser is working
# =============================================================================
verify_browser() {
    local browser_path=$(detect_browser_path)
    
    if [ -z "$browser_path" ]; then
        log_warn "No browser found! The browser tool will not work."
        log_warn "Expected one of: google-chrome-stable, chromium, chromium-browser"
        return 1
    fi
    
    # Get browser version to verify it's executable
    local version
    version=$("$browser_path" --version 2>/dev/null || echo "")
    
    if [ -n "$version" ]; then
        log_info "Browser verified: $version"
        log_info "  Path: $browser_path"
        return 0
    else
        log_warn "Browser found but could not get version: $browser_path"
        return 1
    fi
}

# =============================================================================
# Start virtual X display (Xvfb) for browser tools
# =============================================================================
start_virtual_display() {
    # Only attempt if Xvfb is installed
    if command -v Xvfb >/dev/null 2>&1; then
        # If DISPLAY is not set, default to :99 (matches Dockerfile)
        if [ -z "$DISPLAY" ]; then
            export DISPLAY=:99
        fi

        log_info "Starting virtual display (Xvfb) on $DISPLAY..."

        # Start Xvfb in the background; errors should not crash the entrypoint
        Xvfb "$DISPLAY" -screen 0 1280x720x24 -nolisten tcp >/dev/null 2>&1 &

        # Give Xvfb time to accept connections (Chrome fails with "Missing DISPLAY" if too early)
        sleep 2
        log_info "Virtual display ready (browser tool can use CDP)"
    else
        log_warn "Xvfb not found; running without virtual display. Browser may require headless mode only."
    fi
}

# =============================================================================
# Start Chrome for attach-only mode (per OpenClaw browser-linux-troubleshooting)
# OpenClaw fails to spawn Chrome in Docker; we launch it and set attachOnly: true
# =============================================================================
start_browser_attach_only() {
    # Only if browser is enabled and attachOnly in config
    if [ ! -f /home/seth/.openclaw/openclaw.json ]; then return 0; fi
    if ! node -e "try { const c=require('/home/seth/.openclaw/openclaw.json'); process.exit(c.browser && c.browser.enabled && c.browser.attachOnly ? 0 : 1); } catch(e){ process.exit(1); }" 2>/dev/null; then
        return 0
    fi

    local browser_path=$(detect_browser_path)
    if [ -z "$browser_path" ]; then
        log_warn "attachOnly enabled but no browser found; browser tool may not work."
        return 1
    fi

    local user_data_dir="/home/seth/.openclaw/browser/openclaw/user-data"
    # Remove stale profile locks to avoid "profile in use" errors when restarting
    rm -rf "$user_data_dir"
    mkdir -p "$user_data_dir"
    local cdp_port="${SETH_BROWSER_CDP_PORT:-18800}"

    log_info "Starting Chrome for OpenClaw attach-only (CDP port $cdp_port)..."
    # Flags from https://docs.openclaw.ai/tools/browser-linux-troubleshooting
    DISPLAY="${DISPLAY:-:99}" "$browser_path" \
        --headless \
        --no-sandbox \
        --disable-gpu \
        --disable-dev-shm-usage \
        --remote-debugging-port="$cdp_port" \
        --user-data-dir="$user_data_dir" \
        about:blank \
        >/dev/null 2>&1 &

    # Wait for CDP to be listening before gateway starts (attachOnly: gateway connects, does not spawn)
    local i=0
    while [ $i -lt 15 ]; do
        if curl -sSf "http://127.0.0.1:$cdp_port/json/version" >/dev/null 2>&1; then
            break
        fi
        sleep 1
        i=$((i + 1))
    done
    if [ $i -ge 15 ]; then
        log_warn "Chrome CDP did not become ready on port $cdp_port; browser tool may fail."
    else
        log_info "Chrome started (attach-only); gateway will connect on port $cdp_port"
    fi
}

# =============================================================================
# Create agent auth profiles from ALL API keys in environment
# Automatically detects any *_API_KEY environment variables
# =============================================================================
create_agent_auth_profiles() {
    local agent_dir="/home/seth/.openclaw/agents/main/agent"
    local auth_file="$agent_dir/auth-profiles.json"
    
    # Create directory if it doesn't exist
    mkdir -p "$agent_dir"
    
    # Auto-detect all API keys from environment
    # Maps: GOOGLE_AI_API_KEY -> google, OPENROUTER_API_KEY -> openrouter, etc.
    log_info "Auto-configuring API keys for agent..."
    
    node -e "
        const fs = require('fs');
        const authProfiles = {};
        
        // Provider name mappings (environment var -> OpenClaw provider name)
        const providerMap = {
            'GOOGLE_AI_API_KEY': 'google',
            'OPENROUTER_API_KEY': 'openrouter',
            'ANTHROPIC_API_KEY': 'anthropic',
            'OPENAI_API_KEY': 'openai',
            'GITHUB_TOKEN': 'github',
            'GEMINI_API_KEY': 'google',
            'BRAVE_API_KEY': 'brave',
            'FIRECRAWL_API_KEY': 'firecrawl',
            'ELEVENLABS_API_KEY': 'elevenlabs',
            'GH_TOKEN': 'github',
        };
        
        // Scan environment for API keys
        let configuredCount = 0;
        // OpenClaw expects credential format { key: "..." } per model-failover docs
        for (const [envKey, provider] of Object.entries(providerMap)) {
            const apiKey = process.env[envKey];
            if (apiKey) {
                authProfiles[provider] = { key: apiKey };
                configuredCount++;
                console.log(\`  ✓ \${provider}\`);
            }
        }
        
        // Also scan for any other *_API_KEY variables not in the map
        Object.keys(process.env).forEach(key => {
            if (key.endsWith('_API_KEY') && !providerMap[key]) {
                // Derive provider name from env var (e.g., MYSERVICE_API_KEY -> myservice)
                const provider = key.replace('_API_KEY', '').toLowerCase().replace('_', '-');
                authProfiles[provider] = { key: process.env[key] };
                configuredCount++;
                console.log(\`  ✓ \${provider} (auto-detected)\`);
            }
        });
        
        // Write auth profiles
        fs.writeFileSync('$auth_file', JSON.stringify(authProfiles, null, 2));
        console.log(\`  Configured \${configuredCount} provider(s)\`);
    "
    
    chown seth:seth "$auth_file"
    chmod 600 "$auth_file"
}

# =============================================================================
# Sync env into config: gateway token + API keys + browser + channels
# Keeps config aligned with compose env so doctor and gateway use the same token
# =============================================================================
sync_config_from_env() {
    if [ ! -f /home/seth/.openclaw/openclaw.json ]; then return 0; fi
    
    # Detect browser path
    local browser_path=$(detect_browser_path)
    if [ -n "$browser_path" ]; then
        log_info "Detected browser: $browser_path"
    else
        log_warn "No browser detected! Browser tool will not work."
    fi
    
    log_info "Syncing configuration from environment..."
    BROWSER_PATH="$browser_path" node -e "
        const fs = require('fs');
        const configPath = '/home/seth/.openclaw/openclaw.json';
        const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
        
        // Environment variables
        const token = process.env.SETH_GATEWAY_TOKEN;
        const bind = process.env.SETH_BIND || 'loopback';
        const openRouterKey = process.env.OPENROUTER_API_KEY;
        const googleAiKey = process.env.GOOGLE_AI_API_KEY;
        const braveKey = process.env.BRAVE_API_KEY;
        const githubToken = process.env.GITHUB_TOKEN || process.env.GH_TOKEN;
        const browserPath = process.env.BROWSER_PATH;
        const telegramToken = process.env.TELEGRAM_BOT_TOKEN;
        const telegramUsers = process.env.TELEGRAM_ALLOWED_USERS;
        const freeModel = process.env.SETH_FREE_MODEL;
        const codingModel = process.env.SETH_CODING_MODEL;
        const autoRouting = process.env.SETH_AUTO_ROUTING !== 'false';
        
        // Gateway config
        if (token) {
            config.gateway = config.gateway || {};
            config.gateway.auth = config.gateway.auth || { mode: 'token' };
            config.gateway.auth.token = token;
        }
        if (bind) {
            config.gateway = config.gateway || {};
            config.gateway.bind = bind;
        }
        
        // Provider keys (env section)
        config.env = config.env || {};
        if (openRouterKey) {
            config.env.OPENROUTER_API_KEY = openRouterKey;
        }
        if (googleAiKey) {
            config.env.GOOGLE_AI_API_KEY = googleAiKey;
        }
        if (githubToken) {
            config.env.GITHUB_TOKEN = githubToken;
        }
        
        // Model aliases for auto-routing
        config.agents = config.agents || {};
        config.agents.defaults = config.agents.defaults || {};
        config.agents.defaults.models = config.agents.defaults.models || {};
        
        // Add OpenRouter Auto model (automatic routing based on task complexity)
        config.agents.defaults.models['openrouter/auto'] = { alias: 'auto' };
        
        // Add coding model
        if (codingModel) {
            config.agents.defaults.models[codingModel] = { alias: 'coding' };
        }

        // Add free tier model (Google Gemini) ONLY if auth is configured
        // Google models require auth-profiles.json which is created AFTER this step
        // Users can manually switch to Google models with /model free after startup
        if (freeModel && googleAiKey && freeModel.startsWith('openrouter/')) {
            // Only add if it's an OpenRouter model (doesn't need separate auth)
            config.agents.defaults.models[freeModel] = { alias: 'free' };
        }
        
        // Model routing via aliases (manual switching):
        // - /model free    -> Google Gemini (zero cost)
        // - /model coding  -> Claude Sonnet (code tasks)
        // - /model auto    -> OpenRouter Auto (intelligent routing)
        // - /model smart   -> Claude Sonnet (complex tasks)
        // - /model opus    -> Claude Opus (maximum intelligence)
        
        // REMOVE any existing routing key (not supported in OpenClaw 2026.2.1)
        if (config.routing) {
            delete config.routing;
        }
        
        // Browser config - prelaunch Chrome and have gateway attach (attachOnly)
        if (browserPath) {
            config.browser = config.browser || {};
            config.browser.enabled = true;
            config.browser.attachOnly = true;
            config.browser.executablePath = browserPath;
            config.browser.headless = true;
            config.browser.noSandbox = true;
            config.browser.defaultProfile = 'openclaw';
            config.browser.snapshotDefaults = config.browser.snapshotDefaults || {};
            if (!config.browser.snapshotDefaults.mode) config.browser.snapshotDefaults.mode = 'efficient';
            config.browser.profiles = config.browser.profiles || {};
            config.browser.profiles.openclaw = config.browser.profiles.openclaw || { cdpPort: 18800 };
            config.browser.profiles.chrome = config.browser.profiles.chrome || { cdpPort: 18800 };
        }
        
        // Web tools: enable search (Brave if API key, else Perplexity via OpenRouter)
        config.tools = config.tools || {};
        config.tools.deny = (config.tools.deny || []).filter(tool => tool !== 'exec');
        config.tools.web = config.tools.web || { search: {}, fetch: {} };
        config.tools.web.search = config.tools.web.search || {};
        if (braveKey) {
            config.tools.web.search.enabled = true;
            config.tools.web.search.provider = 'brave';
            config.tools.web.search.apiKey = braveKey;
        } else if (openRouterKey) {
            config.tools.web.search.enabled = true;
            config.tools.web.search.provider = config.tools.web.search.provider || 'perplexity';
            config.tools.web.search.perplexity = config.tools.web.search.perplexity || {};
            if (!config.tools.web.search.perplexity.model) {
                config.tools.web.search.perplexity.model = 'perplexity/sonar-pro';
            }
            delete config.tools.web.search.apiKey;
        } else {
            config.tools.web.search.enabled = false;
            delete config.tools.web.search.provider;
            delete config.tools.web.search.apiKey;
        }
        if (!config.tools.web.search.maxResults) config.tools.web.search.maxResults = 10;
        config.tools.web.fetch = config.tools.web.fetch || {};
        config.tools.web.fetch.enabled = true;
        if (!config.tools.web.fetch.maxChars) config.tools.web.fetch.maxChars = 50000;
        
        // Telegram channel configuration (simplified - advanced fields not yet supported)
        if (telegramToken) {
            config.channels = config.channels || {};
            config.channels.telegram = {
                enabled: true,
                botToken: telegramToken
                // Future: add allowedUsers, polling, webhook when OpenClaw supports them
            };
        }
        
        // Cron configuration
        config.cron = config.cron || {};
        config.cron.enabled = true;
        config.cron.maxConcurrentRuns = 2;
        // Remove unsupported keys if present (OpenClaw 2026.2.1 rejects them)
        delete config.cron.defaultWakeMode;
        delete config.cron.defaultSessionTarget;
        
        fs.writeFileSync(configPath, JSON.stringify(config, null, 2));
    " && log_info "Config synced (gateway + providers + routing + channels)" || log_warn "Could not sync config"
}

# =============================================================================
# Validate environment
# =============================================================================
validate_env() {
    log_info "Validating environment..."
    
    # Check for gateway token
    if [ -z "$SETH_GATEWAY_TOKEN" ]; then
        log_error "SETH_GATEWAY_TOKEN is required!"
        log_error "Generate one with: openssl rand -hex 32"
        exit 1
    fi
    
    # Check for at least one model provider
    if [ -z "$ANTHROPIC_API_KEY" ] && [ -z "$OPENAI_API_KEY" ] && [ -z "$OPENROUTER_API_KEY" ] && [ -z "$GOOGLE_AI_API_KEY" ]; then
        log_warn "No model provider API key found!"
        log_warn "Set one of: OPENROUTER_API_KEY, GOOGLE_AI_API_KEY, ANTHROPIC_API_KEY, OPENAI_API_KEY"
    fi
    
    # Log active providers
    log_info "Active providers:"
    [ -n "$OPENROUTER_API_KEY" ] && log_info "  - OpenRouter: ENABLED"
    [ -n "$GOOGLE_AI_API_KEY" ] && log_info "  - Google AI (Gemini): ENABLED (free tier)"
    [ -n "$ANTHROPIC_API_KEY" ] && log_info "  - Anthropic: ENABLED"
    [ -n "$OPENAI_API_KEY" ] && log_info "  - OpenAI: ENABLED"
    
    # Log active channels
    [ -n "$TELEGRAM_BOT_TOKEN" ] && log_info "  - Telegram: ENABLED"
    
    # Auto-routing status
    if [ "${SETH_AUTO_ROUTING:-true}" = "true" ]; then
        log_info "Auto model routing: ENABLED"
        [ -n "$SETH_FREE_MODEL" ] && log_info "  - Free tier: ${SETH_FREE_MODEL}"
        [ -n "$SETH_CODING_MODEL" ] && log_info "  - Coding: ${SETH_CODING_MODEL}"
    fi
    
    log_info "Environment validated"
}

# =============================================================================
# Run OpenClaw gateway
# =============================================================================
run_gateway() {
    local bind="${SETH_BIND:-loopback}"
    # Ensure Chrome/Playwright get a display when gateway starts browser
    export DISPLAY="${DISPLAY:-:99}"
    log_info "Ensuring attach-only browser is running before gateway..."
    if start_browser_attach_only; then
        log_info "Attach-only browser check completed."
    else
        log_warn "Attach-only browser bootstrap returned non-zero (continuing anyway)."
    fi
    log_info "Starting OpenClaw gateway..."
    log_info "  Bind: $bind, port: ${SETH_PORT:-18789}"
    log_info "  Default model: ${SETH_MODEL:-openrouter/anthropic/claude-3-haiku}"
    # Show browser status so user knows web search via researcher is expected to work
    if [ -f /home/seth/.openclaw/openclaw.json ] && node -e "try { const c=require('/home/seth/.openclaw/openclaw.json'); process.exit(c.browser && c.browser.enabled ? 0 : 1); } catch(e){ process.exit(1); }" 2>/dev/null; then
        if node -e "try { const c=require('/home/seth/.openclaw/openclaw.json'); process.exit(c.browser && c.browser.attachOnly ? 0 : 1); } catch(e){ process.exit(1); }" 2>/dev/null; then
            log_info "  Browser (CDP): ENABLED attach-only on 18800 — researcher/browser agents can search the web"
        else
            log_info "  Browser (CDP): ENABLED on port 18800 — researcher/browser agents can search the web"
        fi
    else
        log_warn "  Browser: not enabled — web search via browser may not work"
    fi
    # Log auto-routing configuration
    if [ "${SETH_AUTO_ROUTING:-true}" = "true" ]; then
        log_info "  Auto-routing: ENABLED"
        [ -n "$GOOGLE_AI_API_KEY" ] && [ -n "$SETH_FREE_MODEL" ] && \
            log_info "    Free tier: ${SETH_FREE_MODEL}"
        [ -n "$SETH_CODING_MODEL" ] && \
            log_info "    Coding: ${SETH_CODING_MODEL}"
    fi
    
    # Log channels
    [ -n "$TELEGRAM_BOT_TOKEN" ] && log_info "  Telegram: ENABLED"
    
    # Export gateway token for OpenClaw
    export OPENCLAW_GATEWAY_TOKEN="$SETH_GATEWAY_TOKEN"
    
    # Export Google AI key if present
    [ -n "$GOOGLE_AI_API_KEY" ] && export GOOGLE_AI_API_KEY="$GOOGLE_AI_API_KEY"
    
    # Run the gateway (loopback = 127.0.0.1 only; lan = 0.0.0.0 for Docker/host access)
    exec openclaw gateway \
        --port "${SETH_PORT:-18789}" \
        --bind "$bind" \
        --token "$SETH_GATEWAY_TOKEN"
}

# =============================================================================
# Run headless job runner (future capability)
# =============================================================================
run_headless() {
    log_info "Starting headless job runner..."
    log_warn "Headless mode is a placeholder for future Playwright job execution"
    
    # For now, just sleep and wait for jobs
    # In the future, this would poll a job queue or listen on a socket
    exec tail -f /dev/null
}

# =============================================================================
# Main
# =============================================================================
main() {
    local mode="${1:-gateway}"
    
    log_info "=============================================="
    log_info "Seth - Secure OpenClaw Assistant"
    log_info "=============================================="
    log_info "Mode: $mode"
    log_info "Node: $(node --version)"
    log_info "OpenClaw: $(openclaw --version 2>/dev/null || echo 'unknown')"
    log_info "=============================================="
    
    # Initialize
    validate_env
    init_directories
    create_agent_auth_profiles  # MUST be before init_config!
    start_virtual_display       # Before verify_browser so Chrome has DISPLAY
    verify_browser
    init_config
    sync_config_from_env
    init_prompts

    # Start Chrome in attach-only mode before gateway (avoids "Failed to start Chrome CDP")
    if [ "$mode" = "gateway" ]; then
        start_browser_attach_only
    fi
    
    # Run based on mode
    case "$mode" in
        gateway)
            run_gateway
            ;;
        headless)
            run_headless
            ;;
        shell|bash)
            log_info "Starting shell..."
            exec /bin/bash
            ;;
        *)
            log_error "Unknown mode: $mode"
            log_error "Available modes: gateway, headless, shell"
            exit 1
            ;;
    esac
}

main "$@"

#!/bin/bash
set -e

# =============================================================================
# Seth Entrypoint Script
# Handles initialization and mode switching
# =============================================================================

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

    # Secure state directory (doctor recommendation)
    chmod 700 /home/seth/.openclaw 2>/dev/null || true
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
        "${cheap_model}": { "alias": "cheap" },
        "${smart_model}": { "alias": "smart" },
        "openrouter/anthropic/claude-opus-4": { "alias": "opus" },
        "openrouter/openai/gpt-4o-mini": { "alias": "mini" },
        "openrouter/openai/gpt-4o": { "alias": "gpt" },
        "openrouter/meta-llama/llama-3.3-70b-instruct": { "alias": "llama" },
        "openrouter/google/gemini-2.0-flash-001": { "alias": "gemini" }
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
        "enabled": false,
        "maxResults": 10
      },
      "fetch": {
        "enabled": true
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
        log_info "  SWITCH MODELS:"
        log_info "    /model smart  - Complex tasks"
        log_info "    /model opus   - Maximum intelligence"
        log_info "    /model cheap  - Back to default"
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
# Sync env into config: gateway token + OpenRouter API key + browser path
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
    
    log_info "Syncing gateway token, bind, browser, and provider keys into config..."
    BROWSER_PATH="$browser_path" node -e "
        const fs = require('fs');
        const path = '/home/seth/.openclaw/openclaw.json';
        const config = JSON.parse(fs.readFileSync(path, 'utf8'));
        const token = process.env.SETH_GATEWAY_TOKEN;
        const bind = process.env.SETH_BIND || 'loopback';
        const openRouterKey = process.env.OPENROUTER_API_KEY;
        const braveKey = process.env.BRAVE_API_KEY;
        const browserPath = process.env.BROWSER_PATH;
        
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
        
        // Provider keys
        if (openRouterKey) {
            config.env = config.env || {};
            config.env.OPENROUTER_API_KEY = openRouterKey;
        }
        
        // Browser config
        if (browserPath) {
            config.browser = config.browser || {};
            config.browser.enabled = true;
            config.browser.executablePath = browserPath;
            config.browser.headless = true;
            config.browser.noSandbox = true;
            config.browser.defaultProfile = 'openclaw';
            config.browser.profiles = config.browser.profiles || {};
            config.browser.profiles.openclaw = config.browser.profiles.openclaw || { cdpPort: 18800 };
            config.browser.profiles.chrome = config.browser.profiles.chrome || { cdpPort: 18800 };
        }
        
        // Web tools config
        config.tools = config.tools || {};
        config.tools.web = config.tools.web || { search: {}, fetch: {} };
        config.tools.web.search = config.tools.web.search || {};
        if (braveKey) {
            config.tools.web.search.enabled = true;
            config.tools.web.search.apiKey = braveKey;
        } else {
            config.tools.web.search.enabled = false;
            delete config.tools.web.search.apiKey;
        }
        if (!config.tools.web.search.maxResults) config.tools.web.search.maxResults = 10;
        config.tools.web.fetch = config.tools.web.fetch || {};
        config.tools.web.fetch.enabled = true;
        
        fs.writeFileSync(path, JSON.stringify(config, null, 2));
    " && log_info "Config synced (gateway + bind + browser + OpenRouter + web)" || log_warn "Could not sync config"
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
    if [ -z "$ANTHROPIC_API_KEY" ] && [ -z "$OPENAI_API_KEY" ] && [ -z "$OPENROUTER_API_KEY" ]; then
        log_warn "No model provider API key found!"
        log_warn "Set one of: ANTHROPIC_API_KEY, OPENAI_API_KEY, OPENROUTER_API_KEY"
    fi
    
    log_info "Environment validated"
}

# =============================================================================
# Run OpenClaw gateway
# =============================================================================
run_gateway() {
    local bind="${SETH_BIND:-loopback}"
    log_info "Starting OpenClaw gateway..."
    log_info "  Bind: $bind, port: ${SETH_PORT:-18789}"
    log_info "  Model: ${SETH_MODEL:-openrouter/anthropic/claude-3-haiku}"
    
    # Export gateway token for OpenClaw
    export OPENCLAW_GATEWAY_TOKEN="$SETH_GATEWAY_TOKEN"
    
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
    verify_browser
    init_config
    sync_config_from_env
    init_prompts
    
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

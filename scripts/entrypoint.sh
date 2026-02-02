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
}

# =============================================================================
# Initialize OpenClaw configuration (Full Power + Cost Optimized)
# =============================================================================
init_config() {
    local config_file="/home/seth/.openclaw/openclaw.json"
    
    if [ ! -f "$config_file" ]; then
        log_info "Creating OpenClaw configuration (cost-optimized mode)..."
        
        # Model strategy from environment (OpenRouter model IDs)
        local cheap_model="${SETH_MODEL:-anthropic/claude-3-haiku}"
        local smart_model="${SETH_SMART_MODEL:-anthropic/claude-sonnet-4}"
        local subagent_model="${SETH_SUBAGENT_MODEL:-anthropic/claude-3-haiku}"
        local port="${SETH_PORT:-18789}"
        
        cat > "$config_file" << EOF
{
  "gateway": {
    "bind": "lan",
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
        "anthropic/claude-opus-4": { "alias": "opus" },
        "openai/gpt-4o-mini": { "alias": "mini" },
        "openai/gpt-4o": { "alias": "gpt" },
        "meta-llama/llama-3.3-70b-instruct": { "alias": "llama" },
        "google/gemini-2.0-flash-001": { "alias": "gemini" }
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
    "defaultProfile": "openclaw",
    "headless": true,
    "noSandbox": true,
    "profiles": {
      "openclaw": {
        "cdpPort": 18800
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
  "memory": {
    "enabled": true
  },
  "logging": {
    "level": "info",
    "consoleStyle": "pretty"
  },
  "session": {
    "pruning": {
      "enabled": true,
      "maxAgeDays": 30
    }
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
        log_info "    - Memory: ENABLED"
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
    log_info "Starting OpenClaw gateway..."
    log_info "  Bind: ${SETH_BIND_ADDR:-0.0.0.0}:${SETH_PORT:-18789}"
    log_info "  Model: ${SETH_MODEL:-anthropic/claude-sonnet-4-5}"
    
    # Export gateway token for OpenClaw
    export OPENCLAW_GATEWAY_TOKEN="$SETH_GATEWAY_TOKEN"
    
    # Run the gateway
    exec openclaw gateway \
        --port "${SETH_PORT:-18789}" \
        --bind lan \
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
    init_config
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

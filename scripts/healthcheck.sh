#!/bin/bash
# Seth Health Check Script

PORT="${SETH_PORT:-18789}"
HOST="127.0.0.1"

# Check if the gateway is responding
# OpenClaw exposes a health endpoint at /health
response=$(curl -sf "http://${HOST}:${PORT}/health" 2>/dev/null)

if [ $? -eq 0 ]; then
    echo "healthy"
    exit 0
else
    # Fallback: check if port is open
    if nc -z "$HOST" "$PORT" 2>/dev/null; then
        echo "port open but health endpoint not responding"
        exit 0  # Consider healthy if port is open
    fi
    
    echo "unhealthy: gateway not responding on port $PORT"
    exit 1
fi

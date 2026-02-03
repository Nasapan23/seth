#!/bin/sh
# Run inside Seth container to check runtime context (env, config, model binding).
# Usage: docker exec seth /opt/seth/scripts/diagnose.sh
# Or:    docker exec -it seth sh -c "openclaw doctor && openclaw status --all"

set -e
echo "=== OpenClaw doctor ==="
openclaw doctor 2>&1 || true
echo ""
echo "=== OpenClaw status --all ==="
openclaw status --all 2>&1 || true
echo ""
echo "=== Env check (OPENROUTER_API_KEY set?) ==="
if [ -n "$OPENROUTER_API_KEY" ]; then echo "OPENROUTER_API_KEY is set (length ${#OPENROUTER_API_KEY})"; else echo "OPENROUTER_API_KEY is NOT set"; fi
echo ""
echo "=== Config env block (key present?) ==="
node -e "try { const c=require('/home/seth/.openclaw/openclaw.json'); console.log('env.OPENROUTER_API_KEY:', c.env && c.env.OPENROUTER_API_KEY ? 'set ('+c.env.OPENROUTER_API_KEY.length+' chars)' : 'missing'); } catch(e) { console.log('Error:', e.message); }" 2>&1

# Seth Skills

This directory contains Seth's skill definitions.

## Structure

```
skills/
  local/           # Versioned, auditable skills
    reminders/
      SKILL.md     # Skill definition
    calendar/
      SKILL.md
  allowlist.yml    # Skills enablement registry
  README.md        # This file
```

## Skill Format

Skills follow the [AgentSkills](https://agentskills.io) format used by OpenClaw.

Each skill is a directory containing a `SKILL.md` file with:

```yaml
---
name: skill-name
description: What the skill does
metadata: {"openclaw":{"always":true,"emoji":"🔧"}}
---

# Skill Documentation

Instructions for the agent on how to use this skill.
```

## Adding a New Skill

1. Create a directory: `skills/local/my-skill/`
2. Create `SKILL.md` with frontmatter and instructions
3. Add to `allowlist.yml` under the appropriate phase
4. Restart Seth to pick up the new skill

## Skill Security

- All skills in `local/` are mounted **read-only** into the container
- Skills are code - review before enabling
- New skills from external sources should be audited
- Never install skills that require elevated permissions

## Current Skills

### Phase 1 (Enabled)

| Skill | Description |
|-------|-------------|
| reminders | Local reminder management |
| calendar | Read-only calendar queries |

### Phase 2+ (Planned)

| Skill | Description | Phase |
|-------|-------------|-------|
| notifications | Push/webhook notifications | 2 |
| email | Email send/read | 3 |
| voice | TTS/STT | 4 |

## Skill Configuration

Individual skills can be configured in `data/openclaw/openclaw.json`:

```json
{
  "skills": {
    "entries": {
      "reminders": {
        "enabled": true
      },
      "notifications": {
        "enabled": false,
        "apiKey": "${NOTIFICATION_API_KEY}"
      }
    }
  }
}
```

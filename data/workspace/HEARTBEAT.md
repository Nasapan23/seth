# Heartbeat Checklist

Run these checks every heartbeat (default: 30 minutes). Reply HEARTBEAT_OK if nothing needs attention.

## Important: Cron Jobs vs Heartbeat

**Cron jobs with `wakeMode: "immediate"` DO NOT require heartbeat to trigger!**
- Immediate cron jobs send notifications instantly when they're due
- Heartbeat is ONLY for proactive check-ins and `"next-heartbeat"` cron jobs
- Most reminders should use `"immediate"` mode for timely notifications

## Periodic Checks

- Check workspace/reminders/ for pending reminders due soon
- Review any blocked tasks that need follow-up
- Check for pending items in memory/daily notes
- **Note**: Cron jobs are checked automatically, no need to scan them here

## Proactive Behavior

- If daytime (8AM-10PM local): brief check-in if nothing else pending
- If any urgent reminder is due: notify immediately
- Update daily notes with any discoveries

## Memory Maintenance

- If session had significant decisions: update MEMORY.md
- If new user preferences learned: record them

## Response Rules

- If nothing needs attention: reply HEARTBEAT_OK
- If something needs attention: announce it clearly
- Keep heartbeat messages brief and actionable

# Seth Reminders & Cron Jobs - Operations Guide

This guide explains how reminders work in Seth and how to troubleshoot common issues.

## Architecture

### Components
1. **OpenClaw Cron System** - Schedules and executes jobs
2. **Jobs Storage** - `~/.openclaw/cron/jobs.json`
3. **Wake Modes** - Control when notifications are sent
4. **Session Targets** - Control where notifications are sent

### Flow
```
User creates reminder
    ↓
Seth creates cron job
    ↓
Job triggers at scheduled time
    ↓
Wake mode determines delivery timing
    ↓
Session target determines delivery destination
    ↓
Notification sent to user
```

## Configuration

### Default Settings (in openclaw.json)
```json
{
  "cron": {
    "enabled": true,
    "maxConcurrentRuns": 2
  }
}
```
**Note**: OpenClaw 2026.2.1 does NOT support `defaultWakeMode` or `defaultSessionTarget`. When creating reminders, ask Seth to use **immediate** wake mode and **last** session so notifications arrive on Telegram on time.

### Wake Modes

| Mode | Behavior | Use Case | Delay |
|------|----------|----------|-------|
| `immediate` | Send instantly | Time-sensitive reminders | 0s |
| `next-heartbeat` | Wait for heartbeat | Background checks | 0-30min |
| `next-session` | Wait for user message | FYI reminders | Variable |

### Session Targets

| Target | Behavior | Best For |
|--------|----------|----------|
| `last` | Most recent session | Telegram users |
| `main` | Web/gateway session | Web interface users |
| `all` | All active sessions | Broadcasting |
| `telegram` | Telegram channel only | Telegram-only mode |

## Common Issues

### Issue: Reminders delayed by 30 minutes

**Cause**: Job has `wakeMode: "next-heartbeat"` instead of `"immediate"`

**Fix**:
```bash
# Check job configuration
docker exec seth cat /home/seth/.openclaw/cron/jobs.json | jq '.jobs[] | select(.name=="YOUR_JOB_NAME")'

# If wakeMode is "next-heartbeat", job needs to be recreated
# Tell Seth: "Delete reminder X and create a new one for immediate delivery"
```

**Prevention**: Ensure `defaultWakeMode: "immediate"` in openclaw.json

### Issue: Reminders not appearing in Telegram

**Cause**: Job has `sessionTarget: "main"` but you're using Telegram

**Fix**:
```bash
# Check session target
docker exec seth cat /home/seth/.openclaw/cron/jobs.json | jq '.jobs[] | {name, sessionTarget}'

# If sessionTarget is "main", recreate reminder with "last" target
```

**Prevention**: Ensure `defaultSessionTarget: "last"` in openclaw.json

### Issue: Job shows "ok" status but no notification received

**Cause**: Job executed but notification wasn't sent to active session

**Diagnosis**:
```bash
# Check job execution history
docker exec seth cat /home/seth/.openclaw/cron/runs/*.jsonl | tail -20

# Check active sessions
docker logs seth | grep "session"

# Verify Telegram is connected
docker logs seth | grep "telegram"
```

**Fix**: Ensure you have an active session (message Seth on Telegram) before job triggers

## Operations

### List All Jobs
```bash
docker exec seth cat /home/seth/.openclaw/cron/jobs.json | jq '.jobs[]'
```

### Check Job Status
```bash
docker exec seth cat /home/seth/.openclaw/cron/jobs.json | jq '.jobs[] | {name, enabled, lastStatus: .state.lastStatus}'
```

### View Recent Executions
```bash
docker exec seth cat /home/seth/.openclaw/cron/runs/*.jsonl | tail -50
```

### Manually Edit Job (Advanced)
```bash
# Backup first!
docker exec seth cp /home/seth/.openclaw/cron/jobs.json /home/seth/.openclaw/cron/jobs.json.manual-backup

# Edit job
docker exec seth nano /home/seth/.openclaw/cron/jobs.json

# Restart Seth to reload
docker-compose restart
```

### Delete All Jobs
```bash
# Backup first!
docker exec seth cp /home/seth/.openclaw/cron/jobs.json /backup/jobs-$(date +%Y%m%d).json

# Clear jobs
docker exec seth bash -c 'echo "{\"version\":1,\"jobs\":[]}" > /home/seth/.openclaw/cron/jobs.json'
```

## Best Practices

### For Development
1. Test with 2-minute reminders first
2. Verify notification arrives before creating long-term jobs
3. Always set `wakeMode: "immediate"` for time-sensitive reminders

### For Production
1. Backup jobs.json regularly
2. Monitor cron run logs for failures
3. Set up health check for cron system
4. Document important recurring reminders

### For Users
1. Use descriptive names for reminders
2. Disable instead of delete (can re-enable later)
3. Keep active reminder count under 20 for performance
4. Review reminders monthly and clean up old ones

## Monitoring

### Health Check
```bash
# Check if cron is enabled
docker exec seth cat /home/seth/.openclaw/openclaw.json | jq '.cron.enabled'

# Check recent job executions
docker exec seth ls -lt /home/seth/.openclaw/cron/runs/ | head

# Check for failed jobs
docker exec seth cat /home/seth/.openclaw/cron/runs/*.jsonl | jq 'select(.status!="ok")'
```

### Metrics to Track
- Number of active jobs
- Job success rate (ok vs failed)
- Average job execution time
- Jobs with next-heartbeat mode (should be minimal)

## Troubleshooting Checklist

- [ ] Is cron enabled in openclaw.json?
- [ ] Is the job enabled in jobs.json?
- [ ] Is wakeMode set to "immediate"?
- [ ] Is sessionTarget pointing to correct channel?
- [ ] Is the scheduled time in the future?
- [ ] Is Seth running and connected to Telegram?
- [ ] Are there any errors in docker logs?
- [ ] Has the job executed successfully before?

## Future Improvements

1. **Auto-detect session type** - Set sessionTarget based on where reminder was created
2. **Recurring reminder templates** - Common patterns (daily, weekly, etc.)
3. **Reminder snooze** - Postpone reminder by X minutes
4. **Smart scheduling** - Suggest optimal reminder times based on user patterns
5. **Reminder groups** - Batch related reminders together

---

**Last Updated**: 2026-02-03
**Seth Version**: 2026.2.1
**OpenClaw Version**: 2026.2.1

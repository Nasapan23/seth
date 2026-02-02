# Seth Update Procedures

## Why Manual Updates

Auto-updates are discouraged for AI agents because:

1. **Behavior changes**: Model or runtime updates can change agent behavior unexpectedly
2. **Security**: Updates should be reviewed before deployment
3. **Rollback complexity**: Auto-updates make rollback harder
4. **Audit trail**: Manual updates provide clear change history

## Update Process

### 1. Check Current Version

```bash
# Via Portainer: check container logs or
docker exec seth openclaw --version
```

### 2. Review Changelog

Before updating, check:

- [OpenClaw Releases](https://github.com/openclaw/openclaw/releases)
- [OpenClaw Changelog](https://docs.openclaw.ai/install/updating)

Look for:

- Breaking changes
- Security fixes
- New dependencies
- Configuration changes

### 3. Backup Current State

```bash
# Backup data directory
tar -czf seth-backup-$(date +%Y%m%d).tar.gz ./data/

# Or via Portainer: export stack and volumes
```

### 4. Update Image Tag

Edit `.env`:

```env
# Change from
SETH_IMAGE_TAG=2026.1.15

# To new version
SETH_IMAGE_TAG=2026.2.1
```

### 5. Pull and Rebuild

Via Portainer:

1. Go to Stacks > seth
2. Click "Pull and redeploy"

Or via CLI:

```bash
docker compose build --no-cache
docker compose up -d
```

### 6. Verify

```bash
# Check logs
docker logs seth --tail 50

# Test health
curl -s http://localhost:18789/health

# Test functionality via WebChat
```

### 7. Monitor

Watch for issues after update:

- Unexpected errors in logs
- Changed behavior
- Performance degradation

---

## Rollback Procedure

If issues occur after update:

### 1. Stop Current Container

```bash
docker compose down
```

### 2. Restore Previous Version

Edit `.env` to previous version:

```env
SETH_IMAGE_TAG=2026.1.15  # Previous version
```

### 3. Restore Data (if needed)

```bash
# Only if data was corrupted
tar -xzf seth-backup-YYYYMMDD.tar.gz
```

### 4. Restart

```bash
docker compose up -d
```

### 5. Verify Rollback

Test that everything works as before.

---

## Version Pinning

Always pin to specific versions in production:

```env
# Good - specific version
SETH_IMAGE_TAG=2026.2.1

# Bad - floating tag
SETH_IMAGE_TAG=latest
```

---

## Security Updates

For security updates, prioritize based on severity:

1. **Critical**: Update immediately after testing
2. **High**: Update as soon as possible
3. **Medium**: Update at your convenience
4. **Low**: Update at next maintenance window

---

## Notifications

To receive update notifications:

1. Watch the [OpenClaw GitHub repo](https://github.com/openclaw/openclaw)
2. Join the [OpenClaw Discord](https://discord.gg/openclaw)
3. Subscribe to release announcements

---

## Troubleshooting Updates

### Container won't start after update

```bash
# Check logs
docker logs seth

# Common fixes:
# 1. Config format changed - check openclaw.json
# 2. New required env vars - check .env.example
# 3. Volume permissions - check ownership
```

### Data migration needed

Some updates require data migration:

```bash
# Run doctor to check/fix
docker exec seth openclaw doctor --fix
```

### Model compatibility issues

If the default model changed or is unavailable:

1. Check `SETH_MODEL` env var
2. Verify API key is still valid
3. Check model provider status

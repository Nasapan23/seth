# Seth Security Hardening Guide

## Container Security

### Applied Hardening (compose.yml)

```yaml
security_opt:
  - no-new-privileges:true  # Prevent privilege escalation
cap_drop:
  - ALL                     # Drop all capabilities
cap_add:
  - CHOWN                   # Required for file ownership
  - SETUID                  # Required for user switching
  - SETGID                  # Required for group switching
```

### Resource Limits

```yaml
deploy:
  resources:
    limits:
      memory: 4G            # Prevent memory exhaustion
    reservations:
      memory: 1G
```

### Filesystem

- `/tmp` mounted as tmpfs (no persistence)
- Skills mounted read-only
- No Docker socket access
- No host network access

---

## Network Security

### Container Network

- Internal bridge network (`seth_net`)
- Only exposed port: 18789 (for nginx proxy)
- No direct public access

### nginx Requirements

Your nginx reverse proxy should:

1. **Terminate TLS** (HTTPS required)
2. **Forward authentication headers**
3. **Rate limit requests**
4. **Block suspicious patterns**

---

## Authentication

### Gateway Token

- Required for all API/WebSocket access
- Generate with: `openssl rand -hex 32`
- Rotate periodically
- Never commit to git

### Token Rotation

1. Generate new token
2. Update `.env` with new `SETH_GATEWAY_TOKEN`
3. Redeploy stack
4. Update nginx config if token is there
5. Test access

---

## Secrets Management

### Environment Variables

All secrets via env vars:

- `SETH_GATEWAY_TOKEN` - Gateway authentication
- `ANTHROPIC_API_KEY` - Model provider
- `OPENAI_API_KEY` - Model provider
- etc.

### Never Store Secrets In

- Docker images
- Git repository
- Config files (use env var substitution)
- Logs

### Portainer Secrets

Consider using Portainer secrets for sensitive values instead of plain `.env`.

---

## Access Control

### Sandbox Mode

```json
{
  "agents": {
    "defaults": {
      "sandbox": {
        "mode": "non-main",
        "scope": "session"
      }
    }
  }
}
```

- `non-main` sessions run in Docker sandbox
- Prevents lateral movement
- Isolates tool execution

### Tool Restrictions

```json
{
  "tools": {
    "deny": ["browser", "canvas", "nodes", "cron"],
    "elevated": { "enabled": false }
  }
}
```

- Browser automation disabled by default
- No cron/scheduled tasks
- No elevated (host) access

---

## Monitoring

### Log Review

Regularly check:

```bash
docker logs seth --tail 100

# Look for:
# - Failed auth attempts
# - Unusual API calls
# - Error patterns
```

### Health Checks

```bash
# Automated via Docker healthcheck
curl http://localhost:18789/health
```

### Metrics (Optional)

Consider adding:

- Request rate monitoring
- Token usage tracking
- Error rate alerting

---

## Incident Response

### Suspected Compromise

1. **Isolate**: Stop the container immediately
   ```bash
   docker stop seth
   ```

2. **Preserve**: Save logs and state for analysis
   ```bash
   docker logs seth > incident-logs.txt
   tar -czf incident-data.tar.gz ./data/
   ```

3. **Rotate**: Change all credentials
   - Gateway token
   - API keys
   - Any other secrets

4. **Review**: Check for unauthorized changes
   - Workspace files
   - Config modifications
   - Session history

5. **Restore**: From known-good backup after securing

---

## Checklist

### Initial Deployment

- [ ] Gateway token generated and set
- [ ] HTTPS configured via nginx
- [ ] API keys set via env vars
- [ ] Sandbox mode enabled
- [ ] Resource limits configured
- [ ] Logs accessible but not public

### Ongoing Maintenance

- [ ] Regular token rotation
- [ ] Regular log review
- [ ] Update schedule followed
- [ ] Backup verification
- [ ] Access audit (who has credentials)

---

## Additional Recommendations

### Network Isolation

If possible, run Seth on an isolated network segment with:

- Egress filtering (only allow model API endpoints)
- No access to internal services unless required

### Backup Encryption

Encrypt backups before storing:

```bash
tar -czf - ./data/ | gpg -c > seth-backup.tar.gz.gpg
```

### Audit Logging

Enable comprehensive logging:

```json
{
  "logging": {
    "level": "info",
    "redactSensitive": "tools"
  }
}
```

# Seth Backup Procedures

## What to Backup

### Critical (Must Backup)

| Path | Contents | Frequency |
|------|----------|-----------|
| `./data/openclaw/` | Config, credentials, sessions | Daily |
| `./data/workspace/` | Reminders, calendar, memory | Daily |
| `.env` | Environment configuration | On change |

### Optional

| Path | Contents | Frequency |
|------|----------|-----------|
| `./skills/` | Custom skills (versioned in git) | N/A |
| `./prompts/` | Identity files (versioned in git) | N/A |

---

## Backup Methods

### Method 1: Simple Archive

```bash
#!/bin/bash
# backup.sh

BACKUP_DIR="/path/to/backups"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="seth-backup-${DATE}.tar.gz"

# Stop container for consistent backup (optional)
# docker compose stop seth

# Create backup
tar -czf "${BACKUP_DIR}/${BACKUP_FILE}" \
    ./data/openclaw \
    ./data/workspace \
    .env

# Restart if stopped
# docker compose start seth

echo "Backup created: ${BACKUP_FILE}"

# Cleanup old backups (keep last 7)
ls -t "${BACKUP_DIR}"/seth-backup-*.tar.gz | tail -n +8 | xargs -r rm
```

### Method 2: Docker Volume Backup

```bash
# Backup named volumes
docker run --rm \
    -v seth_browser_cache:/data \
    -v $(pwd)/backups:/backup \
    alpine tar czf /backup/browser-cache.tar.gz /data
```

### Method 3: Portainer Backup

1. Go to Stacks > seth
2. Click "Export" to save stack configuration
3. Go to Volumes
4. For each volume, use "Browse" and download contents

---

## Restore Procedures

### From Archive

```bash
# Stop container
docker compose down

# Extract backup
tar -xzf seth-backup-YYYYMMDD.tar.gz

# Fix permissions if needed
chown -R 1000:1000 ./data/

# Restart
docker compose up -d
```

### From Portainer Export

1. Go to Stacks
2. Click "Add stack"
3. Select "Upload" and choose exported file
4. Restore volumes from backup

---

## Backup Verification

Always verify backups can be restored:

```bash
# Test extraction
mkdir /tmp/seth-test
tar -xzf seth-backup-YYYYMMDD.tar.gz -C /tmp/seth-test

# Verify key files exist
ls -la /tmp/seth-test/data/openclaw/openclaw.json
ls -la /tmp/seth-test/data/workspace/

# Cleanup
rm -rf /tmp/seth-test
```

---

## Automated Backups

### Using Cron (Host)

```cron
# Daily backup at 3 AM
0 3 * * * /path/to/seth/scripts/backup.sh >> /var/log/seth-backup.log 2>&1
```

### Using Docker (Sidecar)

Add to compose.yml:

```yaml
services:
  seth-backup:
    image: alpine
    volumes:
      - ./data:/data:ro
      - ./backups:/backups
    command: |
      sh -c 'while true; do
        tar -czf /backups/seth-$(date +%Y%m%d).tar.gz /data
        find /backups -name "seth-*.tar.gz" -mtime +7 -delete
        sleep 86400
      done'
```

---

## Offsite Backup

For disaster recovery, copy backups offsite:

### To S3-Compatible Storage

```bash
# Using rclone
rclone copy ./backups remote:seth-backups/

# Using aws cli
aws s3 sync ./backups s3://your-bucket/seth-backups/
```

### To Another Server

```bash
rsync -avz ./backups/ user@remote:/backups/seth/
```

---

## Recovery Time Objectives

| Scenario | Target Recovery Time |
|----------|---------------------|
| Config corruption | < 15 minutes |
| Data loss | < 30 minutes |
| Full container loss | < 1 hour |
| Full server loss | < 4 hours (with offsite backup) |

---

## Backup Checklist

### Daily

- [ ] Automated backup ran successfully
- [ ] Backup file created and not empty
- [ ] Old backups cleaned up

### Weekly

- [ ] Test restore a backup
- [ ] Verify backup integrity
- [ ] Check offsite backup sync

### Monthly

- [ ] Full restore test to separate environment
- [ ] Review backup retention policy
- [ ] Update backup scripts if needed

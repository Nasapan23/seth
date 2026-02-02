# Seth Feature Roadmap

## Overview

Seth follows a progressive enablement model. Features are added in phases, each building on the security and stability of the previous phase.

## Phase 1: Foundation (Current)

**Status**: Active

### Features

- [x] Reminders (local, file-based)
- [x] Calendar (read-only, local)
- [x] Basic Q&A via model
- [x] WebChat access via nginx
- [x] Gateway token authentication

### Risks

| Risk | Mitigation |
|------|------------|
| Token exposure | Use HTTPS via nginx, rotate tokens periodically |
| Workspace access | Sandbox mode for non-main sessions |
| Model API costs | Monitor usage, set budget alerts |

### Acceptance Criteria

- [x] Seth responds to messages via WebChat
- [x] Reminders persist across restarts
- [x] Calendar queries work for local data
- [x] No public network access from container

---

## Phase 2: Notifications

**Status**: Planned

### Features

- [ ] Push notifications (webhook-based)
- [ ] Email notifications (send-only)
- [ ] Quiet hours configuration
- [ ] Rate limiting

### New Risks

| Risk | Mitigation |
|------|------------|
| Notification spam | Rate limits configured |
| Webhook failures | Retry with backoff, dead letter queue |
| Credential leakage | Env vars only, never in config |

### Prerequisites

- Phase 1 stable
- Webhook endpoint configured
- SMTP credentials available

### Acceptance Criteria

- [ ] Notifications deliver reliably
- [ ] Rate limits enforced
- [ ] Quiet hours respected
- [ ] Failures logged, not silent

---

## Phase 3: Email

**Status**: Planned

### Features

- [ ] Send emails (with confirmation)
- [ ] Read emails (Seth mailbox only)
- [ ] Email-based reminders
- [ ] Attachment handling

### New Risks

| Risk | Mitigation |
|------|------------|
| Email spoofing | Dedicated Seth mailbox, SPF/DKIM |
| Mailbox access creep | Hard-coded mailbox restriction |
| Large attachments | Size limits (10MB default) |

### Prerequisites

- Phase 2 stable
- Dedicated email account for Seth
- IMAP access configured

### Acceptance Criteria

- [ ] Emails sent with user confirmation
- [ ] Only Seth mailbox accessible
- [ ] Attachments handled safely
- [ ] Email history searchable

---

## Phase 4: Voice

**Status**: Future

### Features

- [ ] Text-to-speech (ElevenLabs)
- [ ] Speech-to-text (Whisper)
- [ ] Voice notes in WebChat
- [ ] Local processing option

### New Risks

| Risk | Mitigation |
|------|------------|
| Audio data privacy | Local processing preferred |
| API costs | Token limits, caching |
| Wake word abuse | Explicit opt-in, no always-on |

### Prerequisites

- Phase 3 stable
- Voice API keys configured
- Audio hardware (if local)

### Acceptance Criteria

- [ ] TTS works for short responses
- [ ] STT transcribes voice notes
- [ ] Costs tracked per interaction
- [ ] Privacy mode available

---

## Version Mapping

| Version | Phase | Key Features |
|---------|-------|--------------|
| v0.1.x | 1 | Reminders, Calendar (read-only) |
| v0.2.x | 2 | Notifications |
| v0.3.x | 3 | Email |
| v0.4.x | 4 | Voice |
| v1.0.0 | All | Production-ready with all phases |

---

## Non-Goals

These features are explicitly out of scope:

- **Multi-user support**: Seth is single-user by design
- **Public access**: Always behind authentication
- **Autonomous actions**: Always requires confirmation for side effects
- **Plugin marketplace**: Skills are local and audited
- **Cloud sync**: Local-first, no external dependencies

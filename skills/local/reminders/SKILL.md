---
name: reminders
description: Create, list, and manage local reminders for Seth
metadata: {"openclaw":{"always":true,"emoji":"⏰"}}
---

# Reminders Skill

This skill allows Seth to manage local reminders stored in the workspace.

## Capabilities

- Create new reminders with a title and due date/time
- List all pending reminders
- Mark reminders as complete
- Delete reminders

## Usage

### Creating a Reminder

When the user asks to set a reminder, create a new entry in `workspace/reminders/`.

Format: `YYYY-MM-DD_HH-MM_<slug>.md`

Example file `reminders/2026-02-03_09-00_team-meeting.md`:

```markdown
---
title: Team Meeting
due: 2026-02-03T09:00:00
created: 2026-02-02T15:30:00
status: pending
---

Reminder to join the team meeting.
```

### Listing Reminders

Read all `.md` files in `workspace/reminders/` and present them sorted by due date.

### Completing a Reminder

Update the `status` field to `complete` and optionally move to `workspace/reminders/completed/`.

### Deleting a Reminder

Remove the reminder file from `workspace/reminders/`.

## File Structure

```
workspace/
  reminders/
    2026-02-03_09-00_team-meeting.md
    2026-02-05_14-00_dentist.md
    completed/
      2026-02-01_10-00_call-mom.md
```

## Confirmation Required

- Deleting reminders: YES
- Modifying reminders: YES
- Creating reminders: NO (autonomous)
- Listing reminders: NO (autonomous)

## Error Handling

- If the reminders directory doesn't exist, create it
- If a reminder file is malformed, report the error and skip it
- If the due date is in the past, still create but note it's overdue

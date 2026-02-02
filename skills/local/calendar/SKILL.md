---
name: calendar
description: Read-only calendar queries for Seth (Phase 1)
metadata: {"openclaw":{"always":true,"emoji":"📅"}}
---

# Calendar Skill (Phase 1 - Read Only)

This skill allows Seth to query calendar data stored in the workspace.

## Phase 1 Capabilities (Read-Only)

- List events for a given date or date range
- Search events by title or description
- Show upcoming events

## Future Capabilities (Phase 2+)

- Create new events (requires confirmation)
- Modify existing events (requires confirmation)
- Delete events (requires confirmation)
- Sync with external calendars

## Usage

### Calendar Data Format

Events are stored as markdown files in `workspace/calendar/`.

Format: `YYYY-MM-DD_<slug>.md`

Example file `calendar/2026-02-03_team-standup.md`:

```markdown
---
title: Team Standup
start: 2026-02-03T09:00:00
end: 2026-02-03T09:30:00
location: Conference Room A
recurring: daily
---

Daily team standup meeting.

## Agenda
- Yesterday's progress
- Today's goals
- Blockers
```

### Listing Events

When asked about calendar/schedule:

1. Determine the date range from the user's query
2. Read matching `.md` files from `workspace/calendar/`
3. Parse the frontmatter for event metadata
4. Present events sorted by start time

### Searching Events

Search through event titles and content for matching terms.

## File Structure

```
workspace/
  calendar/
    2026-02-03_team-standup.md
    2026-02-03_lunch-meeting.md
    2026-02-05_dentist.md
```

## Confirmation Required (Phase 1)

- Reading events: NO (autonomous)
- Listing events: NO (autonomous)
- Searching events: NO (autonomous)
- Creating/modifying/deleting: NOT AVAILABLE in Phase 1

## Error Handling

- If the calendar directory doesn't exist, report "No calendar data found"
- If an event file is malformed, report the error and skip it
- If no events match the query, report "No events found"

## Current Limitations

This is a local-only calendar. It does not sync with:

- Google Calendar
- Apple Calendar
- Outlook
- Any external calendar service

For external calendar integration, wait for Phase 2+ or configure a separate sync skill.

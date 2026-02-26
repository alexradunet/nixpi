---
name: object-journal
description: Manage daily journal entries — create, query, and reflect on personal journal objects.
---

# Journal Object Skill

Use this skill when the user wants to write journal entries, review past entries, or reflect on their day.

## Object Schema

Journal objects use frontmatter fields:
- `type: journal` (automatic)
- `slug`: date-based, e.g. `2026-02-27` or `2026-02-27-evening`
- `title`: entry title (e.g. "Morning reflection", "Daily review")
- `status`: `draft` | `published` (default: published)
- `project`: PARA project if relevant
- `area`: PARA area (e.g. personal, health, career)
- `tags`: comma-separated tags
- `links`: references to related objects (type/slug)

## Commands

### Write today's journal
```bash
nixpi-object create journal "$(date +%Y-%m-%d)" --title="Daily Journal" --area=personal
```
Then append body content by editing the file directly.

### Write a named entry
```bash
nixpi-object create journal "2026-02-27-evening" --title="Evening Reflection" --area=personal --tags=reflection,gratitude
```

### Read a specific entry
```bash
nixpi-object read journal 2026-02-27
```

### List recent entries
```bash
nixpi-object list journal
```

### Search journal content
```bash
nixpi-object search "gratitude"
```

### Link journal to other objects
```bash
nixpi-object link journal/2026-02-27 task/prepare-taxes
```

## Behavior Guidelines

- When the user says "journal" or "write in my journal", create a journal entry for today.
- If today's entry already exists, read it and offer to append rather than creating a duplicate.
- For daily review prompts (from heartbeat), use slug format `YYYY-MM-DD-review`.
- Keep journal entries warm and reflective — this is personal space.
- Suggest linking journal entries to tasks, people, or events when relevant.

---
name: object-task
description: Manage tasks — create, complete, list, and organize actionable items with PARA methodology.
---

# Task Object Skill

Use this skill when the user wants to track, organize, or complete tasks.

## Object Schema

Task objects use frontmatter fields:
- `type: task` (automatic)
- `slug`: kebab-case identifier (e.g. `fix-bike-tire`)
- `title`: human-readable task name
- `status`: `active` | `waiting` | `done` | `cancelled` (default: active)
- `priority`: `high` | `medium` | `low`
- `due`: ISO date (e.g. `2026-03-01`)
- `project`: PARA project (e.g. home-renovation, work-q1)
- `area`: PARA area (e.g. household, career, health, finance)
- `tags`: comma-separated tags
- `links`: references to related objects (type/slug)

## Commands

### Add a task
```bash
nixpi-object create task "fix-bike-tire" --title="Fix bike tire" --status=active --priority=high --area=household
```

### Complete a task
```bash
nixpi-object update task "fix-bike-tire" --status=done
```

### List active tasks
```bash
nixpi-object list task --status=active
```

### List tasks by area
```bash
nixpi-object list task --area=household
```

### List tasks by project
```bash
nixpi-object list task --project=home-renovation
```

### Check overdue tasks
List all active tasks and compare `due` dates to today.

### Link task to person or event
```bash
nixpi-object link task/fix-bike-tire person/alice
```

## Behavior Guidelines

- When the user mentions something actionable, suggest creating a task.
- Default status is `active`. Only use `waiting` when explicitly blocked.
- When completing tasks, celebrate briefly — the user chose a warm companion.
- During heartbeat, flag overdue tasks (due date < today, status still active).
- Suggest PARA categorization when creating tasks without project/area.

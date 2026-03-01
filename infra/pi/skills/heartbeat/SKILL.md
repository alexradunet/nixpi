---
name: heartbeat
description: Periodic agent wake cycle — observe recent objects, check overdue tasks, reflect, and detect evolution opportunities.
---

# Heartbeat Skill

This skill runs during periodic heartbeat cycles (systemd timer). You have limited time and context — be efficient and purposeful.

## Wake Cycle Steps

### 1. Scan Recent Objects

```bash
# List recent objects modified in the last cycle
find "${NIXPI_OBJECTS_DIR:-$HOME/Nixpi/data/objects}" -name '*.md' -mmin -60 -type f 2>/dev/null
```

### 2. Check Overdue Tasks

```bash
# List active tasks (check due dates against today)
nixpi-object list task --status=active
```

Compare `due` fields against today's date. Flag any overdue items.

### 3. Daily Journal Check

Check if today's journal entry exists:

```bash
nixpi-object read journal "$(date +%Y-%m-%d)" 2>/dev/null
```

If not, and it's after morning hours, consider creating a gentle prompt.

### 4. Detect Patterns

Look for:

- Tasks that have been active for more than 7 days without updates.
- Areas with no recent objects (neglected life areas).
- Repeated themes in journal entries or notes.

### 5. Decide Action

Based on observations, choose one of:

- **No action needed**: Log "heartbeat: all clear" and exit.
- **Reminder**: If Matrix is available, send a brief nudge about overdue tasks.
- **Journal prompt**: Create a system journal entry with observations.
- **Evolution request**: If a pattern suggests a missing capability, file an evolution request using the Hermes -> Athena handoff template.

### 6. Log Heartbeat

Create a system journal entry:

```bash
nixpi-object create journal "$(date +%Y-%m-%d)-heartbeat-$(date +%H%M)" \
  --title="Heartbeat $(date +%H:%M)" \
  --area=system \
  --tags=heartbeat,automated
```

Append a brief summary of observations and actions taken.

## Behavior Guidelines

- Be brief. Heartbeat entries should be 1-3 sentences.
- Do not nag. If a reminder was sent recently, skip it.
- Respect quiet hours (configurable, default: 22:00-07:00 local time).
- Prefer observation over action. Most heartbeats should end with "all clear."
- Only file evolution requests for patterns observed across multiple heartbeats.

## Scheduling Awareness

- Morning heartbeats (07:00-09:00): Good time for daily planning prompts.
- Afternoon heartbeats (12:00-14:00): Good time for task check-ins.
- Evening heartbeats (18:00-20:00): Good time for daily review prompts.
- Outside these windows: observation only unless urgent.

---
name: object-evolution
description: Manage evolution objects — track pipeline state for Nixpi self-evolution from proposal through apply.
---

# Evolution Object Skill

Use this skill when creating, tracking, or transitioning evolution pipeline items.

## Object Schema

Evolution objects use frontmatter fields:
- `type: evolution` (automatic)
- `slug`: kebab-case identifier (e.g. `add-health-tracking`)
- `title`: human-readable evolution name
- `status`: pipeline state (default: proposed)
- `agent`: current owner — `hermes` | `athena` | `hephaestus` | `themis` | `human`
- `risk`: `low` | `medium` | `high`
- `area`: affected area (e.g. system, persona, objects, infra, skills)
- `tags`: comma-separated tags
- `links`: references to related objects (type/slug)

## Status Values and Transitions

Valid statuses:
`proposed` | `planning` | `implementing` | `reviewing` | `conformance` | `approved` | `applied` | `rejected` | `stalled`

Valid transitions (including rework loop):
```
proposed -> planning -> implementing -> reviewing -> conformance -> approved -> applied
                        ^                |
                        |--- rework -----+
Any -> rejected | stalled
```

- `proposed`: Hermes created the request, awaiting Athena.
- `planning`: Athena is designing the implementation plan.
- `implementing`: Hephaestus is building with TDD.
- `reviewing`: Themis is performing independent review.
- `conformance`: Athena is checking final conformance against plan.
- `approved`: Human approved, ready to apply.
- `applied`: Changes applied via `nixpi evolve`.
- `rejected`: Human or agent rejected the evolution.
- `stalled`: No progress for >24h, needs human attention.

## Commands

### Create an evolution
```bash
nixpi-object create evolution "add-health-tracking" \
  --title="Add health tracking object type" \
  --status=proposed --agent=hermes --risk=low --area=objects
```

### Read an evolution
```bash
nixpi-object read evolution "add-health-tracking"
```

### Update status and agent
```bash
nixpi-object update evolution "add-health-tracking" --status=planning --agent=athena
```

### List evolutions by status
```bash
nixpi-object list evolution --status=proposed
nixpi-object list evolution --status=implementing
```

### List active evolutions (not terminal)
```bash
nixpi-object list evolution | grep -v -E 'status: (applied|rejected)'
```

### Link evolution to related objects
```bash
nixpi-object link evolution/add-health-tracking task/research-health-apis
```

## Behavior Guidelines

- Every core/system change should have an evolution object tracking it.
- Update `status` and `agent` together when transitioning pipeline stages.
- On rework: set status back to `implementing`, agent to `hephaestus`.
- Append rework notes to the object body (below frontmatter) with timestamps.
- Terminal statuses (`applied`, `rejected`) should not transition further.
- During heartbeat, flag evolutions with `status` not in a terminal state and modification time >24h as `stalled`.

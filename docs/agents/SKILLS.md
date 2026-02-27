# Agent Skills Index

Related: [Agents Home](./README.md) · [Operating Model](../runtime/OPERATING_MODEL.md) · [Handoff Templates](./HANDOFF_TEMPLATES.md)

Concise map of Nixpi agent skills used by `nixpi`.

## 🤖 Canonical agent-role skills
- **Nixpi Runtime (Hermes)** — user-facing runtime behavior contract
  [`infra/pi/skills/nixpi-runtime/SKILL.md`](../../infra/pi/skills/nixpi-runtime/SKILL.md)
- **Athena (Technical Architect)** — planning, acceptance criteria, and conformance contract
  [`infra/pi/skills/athena-technical-architect/SKILL.md`](../../infra/pi/skills/athena-technical-architect/SKILL.md)
- **Hephaestus (Maintainer)** — implementation workflow contract with strict TDD evidence
  [`infra/pi/skills/hephaestus-maintainer/SKILL.md`](../../infra/pi/skills/hephaestus-maintainer/SKILL.md)
- **Themis (Reviewer)** — independent quality/security/policy review contract
  [`infra/pi/skills/themis-reviewer/SKILL.md`](../../infra/pi/skills/themis-reviewer/SKILL.md)

## 📦 Object management skills
- **Journal objects** — create, query, and reflect on daily journal entries
  [`infra/pi/skills/object-journal/SKILL.md`](../../infra/pi/skills/object-journal/SKILL.md)
- **Task objects** — create, complete, list, and organize actionable items
  [`infra/pi/skills/object-task/SKILL.md`](../../infra/pi/skills/object-task/SKILL.md)
- **Note objects** — capture, search, and link knowledge with PARA methodology
  [`infra/pi/skills/object-note/SKILL.md`](../../infra/pi/skills/object-note/SKILL.md)
- **Evolution objects** — track pipeline state for Nixpi self-evolution from proposal through apply
  [`infra/pi/skills/object-evolution/SKILL.md`](../../infra/pi/skills/object-evolution/SKILL.md)

## 🔗 Shared cross-role skills
- **TDD policy** — mandatory Red -> Green -> Refactor behavior
  [`infra/pi/skills/tdd/SKILL.md`](../../infra/pi/skills/tdd/SKILL.md)
- **Install bootstrap guidance** — first-time Nixpi install flow
  [`infra/pi/skills/install-nixpi/SKILL.md`](../../infra/pi/skills/install-nixpi/SKILL.md)
- **Claude consult (optional)** — second-opinion workflow via Claude CLI
  [`infra/pi/skills/claude-consult/SKILL.md`](../../infra/pi/skills/claude-consult/SKILL.md)
- **Heartbeat** — periodic observation cycle (overdue tasks, patterns, evolution opportunities)
  [`infra/pi/skills/heartbeat/SKILL.md`](../../infra/pi/skills/heartbeat/SKILL.md)
- **Persona harvest** — propose improvements to OpenPersona layers through evolution pipeline
  [`infra/pi/skills/persona-harvest/SKILL.md`](../../infra/pi/skills/persona-harvest/SKILL.md)
- **Nix artifact reviewer** — checklist-driven review for evaluating packages before adoption
  [`infra/pi/skills/nix-artifact-reviewer/SKILL.md`](../../infra/pi/skills/nix-artifact-reviewer/SKILL.md)

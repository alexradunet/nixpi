# Agent Skills Index

Related: [Agents Home](./README.md) · [Operating Model](../runtime/OPERATING_MODEL.md) · [Handoff Templates](./HANDOFF_TEMPLATES.md)

Concise map of Nixpi agent skills used by `nixpi`.

## Canonical agent-role skills
- **Hermes (Runtime)** — user-facing runtime behavior contract  
  [`infra/pi/skills/hermes-runtime/SKILL.md`](../../infra/pi/skills/hermes-runtime/SKILL.md)
- **Athena (Technical Architect)** — planning, acceptance criteria, and conformance contract  
  [`infra/pi/skills/athena-technical-architect/SKILL.md`](../../infra/pi/skills/athena-technical-architect/SKILL.md)
- **Hephaestus (Maintainer)** — implementation workflow contract with strict TDD evidence  
  [`infra/pi/skills/hephaestus-maintainer/SKILL.md`](../../infra/pi/skills/hephaestus-maintainer/SKILL.md)
- **Themis (Reviewer)** — independent quality/security/policy review contract  
  [`infra/pi/skills/themis-reviewer/SKILL.md`](../../infra/pi/skills/themis-reviewer/SKILL.md)

## Shared cross-role skills
- **TDD policy** — mandatory Red -> Green -> Refactor behavior  
  [`infra/pi/skills/tdd/SKILL.md`](../../infra/pi/skills/tdd/SKILL.md)
- **Install bootstrap guidance** — first-time Nixpi install flow  
  [`infra/pi/skills/install-nixpi/SKILL.md`](../../infra/pi/skills/install-nixpi/SKILL.md)
- **Claude consult (optional)** — second-opinion workflow via Claude CLI  
  [`infra/pi/skills/claude-consult/SKILL.md`](../../infra/pi/skills/claude-consult/SKILL.md)

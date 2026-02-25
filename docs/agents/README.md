# Agents Overview

Related: [Docs Home](../README.md) · [Source of Truth Map](../meta/SOURCE_OF_TRUTH.md) · [Operating Model](../runtime/OPERATING_MODEL.md)

This section defines each Nixpi agent role as a modular contract.

## Agents
- [Runtime Agent](./runtime/README.md)
- [Technical Architect Agent](./technical-architect/README.md)
- [Maintainer Agent](./maintainer/README.md)
- [Reviewer Agent](./reviewer/README.md)

## Shared Contracts
- [Agent Handoff Templates](./HANDOFF_TEMPLATES.md)

## Tooling
- `scripts/new-handoff.sh` — scaffold a standards-compliant handoff file.
- `scripts/list-handoffs.sh` — list handoff files (supports type/date filters).
- `infra/pi/skills/tdd/SKILL.md` — mandatory TDD behavior contract.
- `infra/pi/skills/claude-consult/SKILL.md` — optional second-opinion consult workflow.

## Role Boundaries
- Runtime does not directly self-modify Nixpi core.
- Technical Architect plans and validates architecture/process alignment.
- Maintainer implements changes in controlled development context using strict TDD.
- Reviewer performs independent quality/security/pattern review.

## Evolution Hand-off (Summary)
1. Runtime creates evolution request.
2. Technical Architect produces implementation plan with user preferences.
3. Maintainer implements via TDD and returns patch/diff.
4. Reviewer performs independent review (quality + security).
5. Technical Architect validates conformance to architecture and rules.
6. Human approves.
7. Apply declaratively via NixOS rebuild workflow.

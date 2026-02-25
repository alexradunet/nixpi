# Agents Overview

Related: [Docs Home](../README.md) · [Source of Truth Map](../meta/SOURCE_OF_TRUTH.md) · [Operating Model](../runtime/OPERATING_MODEL.md)

This section defines each Nixpi agent role as a modular contract.

## Agents
- [Hermes (Runtime Agent)](./runtime/README.md)
- [Athena (Technical Architect Agent)](./technical-architect/README.md)
- [Hephaestus (Maintainer Agent)](./maintainer/README.md)
- [Themis (Reviewer Agent)](./reviewer/README.md)

## Mythic Identity (Canonical Codenames)
- **Hermes** = Runtime Agent
- **Athena** = Technical Architect Agent
- **Hephaestus** = Maintainer Agent
- **Themis** = Reviewer Agent

## Shared Contracts
- [Agent Handoff Templates](./HANDOFF_TEMPLATES.md)

## Tooling
- `scripts/new-handoff.sh` — scaffold a standards-compliant handoff file.
- `scripts/list-handoffs.sh` — list handoff files (supports type/date filters).
- `infra/pi/skills/tdd/SKILL.md` — mandatory TDD behavior contract.
- `infra/pi/skills/claude-consult/SKILL.md` — optional second-opinion consult workflow.

## Role Boundaries
- Hermes (Runtime) does not directly self-modify Nixpi core.
- Athena (Technical Architect) plans and validates architecture/process alignment.
- Hephaestus (Maintainer) implements changes in controlled development context using strict TDD.
- Themis (Reviewer) performs independent quality/security/pattern review.

## Evolution Hand-off (Summary)
1. Hermes (Runtime) creates evolution request.
2. Athena (Technical Architect) produces implementation plan with user preferences.
3. Hephaestus (Maintainer) implements via TDD and returns patch/diff.
4. Themis (Reviewer) performs independent review (quality + security).
5. Athena validates conformance to architecture and rules.
6. Human approves.
7. Apply declaratively via NixOS rebuild workflow.

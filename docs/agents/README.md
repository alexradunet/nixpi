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
- [Agent Skills Index](./SKILLS.md) — short descriptions + links to skill contracts used by `nixpi`.

## Role Boundaries
- Hermes (Runtime) does not directly self-modify Nixpi core.
- Athena (Technical Architect) plans and validates architecture/process alignment.
- Hephaestus (Maintainer) implements changes in controlled development context using strict TDD.
- Themis (Reviewer) performs independent quality/security/pattern review.

## Evolution Hand-off

See the canonical 7-step evolution workflow in the [Operating Model](../runtime/OPERATING_MODEL.md#evolution-workflow). Use [Handoff Templates](./HANDOFF_TEMPLATES.md) for standardized artifacts between steps.

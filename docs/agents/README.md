# Agents Overview

Related: [Docs Home](../README.md) · [Source of Truth Map](../meta/SOURCE_OF_TRUTH.md) · [Operating Model](../runtime/OPERATING_MODEL.md)

This section defines each Nixpi agent role as a modular contract.

## Agents
- [Hermes (Runtime Agent)](./runtime/README.md)
- [Athena (Technical Architect Agent)](./technical-architect/README.md)
- [Hephaestus (Maintainer Agent)](./maintainer/README.md)
- [Themis (Reviewer Agent)](./reviewer/README.md)

## Mythic Identity (Canonical Codenames)
See the canonical codename mapping and role policy in [AGENTS.md](../../AGENTS.md#agent-role-policy).

## Shared Contracts
- [Agent Handoff Templates](./HANDOFF_TEMPLATES.md)

## Tooling
- `scripts/new-handoff.sh` — scaffold a standards-compliant handoff file.
- `scripts/list-handoffs.sh` — list handoff files (supports type/date filters).
- [Agent Skills Index](./SKILLS.md) — short descriptions + links to skill contracts used by `nixpi`.

## Role Boundaries
See the canonical role policy and boundaries in [AGENTS.md](../../AGENTS.md#agent-role-policy).

## Evolution Hand-off

See the canonical 7-step evolution workflow in the [Operating Model](../runtime/OPERATING_MODEL.md#evolution-workflow). Use [Handoff Templates](./HANDOFF_TEMPLATES.md) for standardized artifacts between steps.

Hermes orchestrates the pipeline by spawning sub-agents via `pi -p --skill`. Each pipeline stage is tracked via an `evolution` object in `data/objects/evolution/`, with `status` and `agent` fields updated at each transition. The rework loop (Themis -> Hephaestus, max 2 cycles) uses the `rework-request` handoff template.

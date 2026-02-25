# Nixpi Operating Model

Related: [Docs Home](../README.md) · [Source of Truth Map](../meta/SOURCE_OF_TRUTH.md) · [Agents Overview](../agents/README.md) · [Emoji Dictionary](../ux/EMOJI_DICTIONARY.md) · [Docs Style](../meta/DOCS_STYLE.md)

This document defines how Nixpi runs on user systems and how Nixpi evolves safely over time.

## Goal
- End-user experience: install Nixpi, use `nixpi` as the primary assistant command, and run in normal/runtime mode by default.
- Engineering experience: use `nixpi dev` for Pi-native development with Nixpi skills/rules preloaded; evolve Nixpi through tested, reviewable, declarative changes.

## Installation and First Boot

### Does the user need to run `pi install`?
No for core Nixpi.

`nixpi` (wrapper) and `pi` (SDK CLI) are installed declaratively via NixOS (`base.nix`, with Pi from `llm-agents.nix`).
After `nixos-rebuild switch`, both commands are available.

### First-boot expected flow
1. User boots Nixpi.
2. User launches runtime mode with `nixpi`.
3. User configures provider/auth as needed (`pi login` and provider setup remain compatible).
4. User enables desired resources/extensions via `pi config`.
5. Hermes (Runtime) runs in background and waits for events/tasks/channels.

### Runtime vs Developer mode
- `nixpi` → normal/runtime mode (primary end-user path).
- `nixpi dev` → developer mode (Pi-native workflow with Nixpi dev skills/rules).
- `pi` remains available for SDK/advanced usage.

### Configuration source of truth
- Declarative profile defaults are seeded from `infra/nixos/base.nix`.
- Effective runtime profile files are under:
  - `~/.pi/agent/` (runtime)
  - `~/.pi/agent-dev/` (developer mode)
- Repo-local `.pi/settings.json` is development convenience for this repository and is not the production system source of truth.

## Multi-Agent Architecture (Mandatory)
See role contracts in [Agents Overview](../agents/README.md).
Use standardized exchange artifacts from [Agent Handoff Templates](../agents/HANDOFF_TEMPLATES.md).

- [Hermes (Runtime Agent)](../agents/runtime/README.md)
- [Athena (Technical Architect Agent)](../agents/technical-architect/README.md)
- [Hephaestus (Maintainer Agent)](../agents/maintainer/README.md)
- [Themis (Reviewer Agent)](../agents/reviewer/README.md)

## Evolution Workflow
1. Hermes (Runtime) identifies improvement opportunity and creates an evolution request.
2. Athena (Technical Architect) analyzes request, gathers user preferences, and produces an implementation plan.
3. Hephaestus (Maintainer) executes in controlled dev context with strict TDD and validation.
4. Themis (Reviewer) performs independent quality/security/policy review.
5. Athena performs final conformance review against plan and standards.
6. Human approval gate decides apply/no-apply.
7. Approved system changes are applied declaratively (`nixos-rebuild switch --flake ...`) with rollback available.

## Why this model
- Prevents unsafe live self-mutation.
- Preserves auditability (git history + explicit diffs).
- Preserves recoverability (NixOS generations/rollback).
- Enables autonomous improvement with guardrails.

## Communication UX
- Nixpi uses the visual language in [Emoji Dictionary](../ux/EMOJI_DICTIONARY.md).
- Emoji are always paired with explicit plain text for precision/accessibility.

## Ecosystem Direction
- Official core channel target: Element/Matrix.
- Additional channels/capabilities come via extensions.
- Encourage extension packaging as Nix packages/modules so users can compose custom Nixpi systems declaratively.

# Nixpi Operating Model

This document defines how Nixpi should run on user systems and how Nixpi evolves safely over time.

## Goal
- End-user experience: install Nixpi, configure provider access in Pi TUI, then use Nixpi as a background assistant.
- Engineering experience: evolve Nixpi through tested, reviewable, declarative changes.

## Installation and First Boot

### Does the user need to run `pi install`?
**No** for core Nixpi.

`pi` is installed declaratively via NixOS (`llm-agents.nix` in `base.nix`).
After `nixos-rebuild switch`, the `pi` command is already available.

### First-boot expected flow
1. User boots Nixpi.
2. User opens Pi TUI (`pi`) and connects auth/providers (`pi login` / provider setup).
3. User enables desired Pi resources/extensions (if any) via `pi config`.
4. Runtime Nixpi agent runs in background and waits for events/tasks/channels.

## Dual-Agent Architecture (Mandatory)

### 1) Runtime Nixpi Assistant (production)
Purpose:
- User-facing assistant and automations (e.g., Element channel handling).
- Executes normal tasks and orchestrates workflows.

Safety profile:
- No direct self-modification of Nixpi core.
- Read-only access to core repo/system config by default.
- If improvement is needed, creates an evolution request for Maintainer agent.

### 2) Maintainer Nixpi Agent (development)
Purpose:
- Works on Nixpi codebase and extension ecosystem.
- Implements fixes/features requested by user or runtime assistant.

Safety profile:
- Works in controlled development context (repo/worktree).
- Must follow strict TDD (Red -> Green -> Refactor).
- Produces reviewable diffs/commits and validation output.
- Changes applied only through explicit approval policy.

## Evolution Workflow
1. Runtime assistant identifies improvement opportunity.
2. Runtime creates an **evolution request** (task/spec with expected behavior).
3. Maintainer agent executes in dev context:
   - writes failing tests first,
   - implements minimal passing change,
   - adds edge-case coverage,
   - runs checks.
4. Maintainer returns patch/PR-style output.
5. Apply policy:
   - default: human approval required,
   - optional advanced mode: policy-based auto-apply for low-risk changes only.
6. System changes are applied declaratively (`nixos-rebuild switch --flake ...`) with rollback available.

## Why this model
- Prevents unsafe live self-mutation.
- Preserves auditability (git history + explicit diffs).
- Preserves recoverability (NixOS generations/rollback).
- Enables autonomous improvement with guardrails.

## Communication UX
- Nixpi communicates using a compact visual language defined in [`docs/EMOJI_DICTIONARY.md`](./EMOJI_DICTIONARY.md).
- Emoji are used to reduce reading effort, but always with plain text for precision/accessibility.

## Ecosystem Direction
- Official core channel target: Element/Matrix.
- Additional channels/capabilities come via extensions.
- Encourage extension packaging as Nix packages/modules so users can compose custom Nixpi systems declaratively.

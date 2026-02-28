# Nixpi Operating Model

Related: [Docs Home](../README.md) · [Source of Truth Map](../meta/SOURCE_OF_TRUTH.md) · [Agents Overview](../agents/README.md) · [Emoji Dictionary](../ux/EMOJI_DICTIONARY.md) · [Docs Style](../meta/DOCS_STYLE.md)

This document defines how Nixpi runs on user systems and how Nixpi evolves safely over time.

## Goal
- End-user experience: install Nixpi and use `nixpi` as the primary assistant command.
- Engineering experience: use `nixpi` for Pi-native development with skills from [Agent Skills Index](../agents/SKILLS.md); evolve Nixpi through tested, reviewable, declarative changes.

## Installation and First Boot

### Does the user need to run `pi install`?
No for core Nixpi.

`nixpi` and `claude` are installed declaratively via NixOS (`base.nix`; Claude uses nixpkgs `claude-code-bin`).
For fresh installs, use the bootstrap flow in [`REINSTALL.md`](./REINSTALL.md), which assumes no `git` and no flakes by default.
The bootstrap flow launches Nixpi with the `install-nixpi` skill so host disks/user settings are reviewed before the first rebuild.
After the first rebuild, both commands are available (`nixpi` and `claude`).

### First-boot expected flow
1. User boots Nixpi and can complete local HDMI onboarding through desktop UI (GNOME by default, or preserved existing desktop when detected).
2. User launches Nixpi with `nixpi`.
3. User configures provider/auth as needed.
4. User adds/updates pinned extension sources with `nixpi npm install <package@version>` and runs `nixpi npm sync` when needed.
5. Hermes (Runtime) runs in background and waits for events/tasks/channels.

### Single Nixpi instance model
- `nixpi` → single Nixpi instance (primary path).
- The single profile preloads shared Nixpi skills (see [Agent Skills Index](../agents/SKILLS.md)).

### Configuration source of truth
- Declarative profile defaults are seeded from `infra/nixos/base.nix`.
- Declarative extension sources are tracked in `infra/pi/extensions/packages.json`.
- Effective profile files are under: `~/Nixpi/.pi/agent/`.
- Repo-local `.pi/settings.json` is development convenience for this repository and is not the production system source of truth.

### Optional path overrides (per host)
If a host needs a different repository/profile location, override these Nix options in `infra/nixos/hosts/<hostname>.nix`:
- `nixpi.repoRoot`
- `nixpi.piDir`

## Multi-Agent Architecture (Mandatory)
See role contracts and canonical codenames in [AGENTS.md](../../AGENTS.md#agent-role-policy), individual agent docs in [Agents Overview](../agents/README.md), and standardized exchange artifacts in [Agent Handoff Templates](../agents/HANDOFF_TEMPLATES.md).

## Evolution Workflow
1. Hermes (Runtime) identifies improvement opportunity and creates an evolution object (`nixpi-object create evolution ...`).
2. Athena (Technical Architect) analyzes request, gathers user preferences, and produces an implementation plan.
3. Hephaestus (Maintainer) executes in controlled dev context with strict TDD and validation.
4. Themis (Reviewer) performs independent quality/security/policy review.
   - **Pass**: proceed to step 5.
   - **Rework**: loop back to step 3 with structured findings (max 2 cycles, then escalate to human).
   - **Fail**: reject evolution, report to human with all findings.
5. Athena performs final conformance review against plan and standards.
6. Human approval gate decides apply/no-apply.
7. Approved system changes are applied declaratively (`nixos-rebuild switch --flake ...`) with rollback available.

> **Tip:** The preferred operator path for local guarded apply/rollback is `nixpi evolve` and `nixpi rollback`.

### Evolution State Tracking
Each evolution is tracked as an `evolution` object in `data/objects/evolution/`. The object's `status` field reflects the current pipeline stage (`proposed` -> `planning` -> `implementing` -> `reviewing` -> `conformance` -> `approved` -> `applied`). The `agent` field tracks which agent currently owns the work. Hermes updates both fields at each transition.

### Stall Detection and Escalation
During heartbeat cycles, Hermes checks for active evolutions not modified in >24h and flags them as `stalled`. Stalled evolutions are surfaced to the human for triage.

## Why this model
- Prevents unsafe live self-mutation.
- Preserves auditability (git history + explicit diffs).
- Preserves recoverability (NixOS generations/rollback).
- Enables autonomous improvement with guardrails.

## Communication UX
- Nixpi uses the visual language in [Emoji Dictionary](../ux/EMOJI_DICTIONARY.md).
- Emoji are always paired with explicit plain text for precision/accessibility.

## Autonomous Life Agent Services
- **Object store**: flat-file markdown with YAML frontmatter in `data/objects/`. Shell CRUD (`scripts/nixpi-object.sh`) and TypeScript ObjectStore (`@nixpi/core`) produce format-compatible files. Syncthing-synced across devices.
- **Matrix bridge**: matrix-bot-sdk adapter in `services/matrix-bridge/` receives messages, processes through Pi, and sends responses. Managed as a systemd service via `infra/nixos/modules/matrix.nix`. Local Conduit homeserver provisioned by default. Setup guide: [Matrix Setup](./MATRIX_SETUP.md), interactive skill: `nixpi --skill ./infra/pi/skills/matrix-setup/SKILL.md`.
- **Heartbeat timer**: periodic agent observation cycle via `infra/nixos/modules/heartbeat.nix`. Scans objects, checks overdue tasks, detects patterns, and can send nudges or file evolution requests.
- **OpenPersona**: 4-layer identity model (SOUL, BODY, FACULTY, SKILL) in `persona/`. Injected into the Pi agent profile by NixOS activation scripts.

## Ecosystem Direction
- Matrix is the primary external communication channel (via matrix-bot-sdk bridge with local Conduit homeserver).
- Additional channels/capabilities come via extensions or new service adapters.
- Encourage extension packaging as Nix packages/modules so users can compose custom Nixpi systems declaratively.

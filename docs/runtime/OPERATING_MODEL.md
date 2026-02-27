# Nixpi Operating Model

Related: [Docs Home](../README.md) · [Source of Truth Map](../meta/SOURCE_OF_TRUTH.md) · [Agents Overview](../agents/README.md) · [Emoji Dictionary](../ux/EMOJI_DICTIONARY.md) · [Docs Style](../meta/DOCS_STYLE.md)

This document defines how Nixpi runs on user systems and how Nixpi evolves safely over time.

## Goal
- End-user experience: install Nixpi and use `nixpi` as the primary assistant command.
- Engineering experience: use `nixpi` for Pi-native development with skills from [Agent Skills Index](../agents/SKILLS.md); evolve Nixpi through tested, reviewable, declarative changes.

## Installation and First Boot

### Does the user need to run `pi install`?
No for core Nixpi.

`nixpi` (wrapper), `pi` (SDK CLI), and `claude` are installed declaratively via NixOS (`base.nix`; Pi uses a lightweight npm-backed wrapper, Claude uses nixpkgs `claude-code-bin`).
For fresh installs, use the bootstrap flow in [`REINSTALL.md`](./REINSTALL.md), which assumes no `git` and no flakes by default.
The bootstrap flow launches Pi with the `install-nixpi` skill so host disks/user settings are reviewed before the first rebuild.
After the first rebuild, all three commands are available (`nixpi`, `pi`, and `claude`).

### First-boot expected flow
1. User boots Nixpi and can complete local HDMI onboarding through desktop UI (GNOME by default, or preserved existing desktop when detected).
2. User launches Nixpi with `nixpi`.
3. User configures provider/auth as needed (`pi login` and provider setup remain compatible).
4. User adds/updates pinned extension sources with `nixpi npm install <package@version>`, runs `nixpi npm sync` when needed, and enables desired resources via `pi config`.
5. Hermes (Runtime) runs in background and waits for events/tasks/channels.

### Single Nixpi instance model
- `nixpi` → single Nixpi instance (primary path).
- `pi` remains available for SDK/advanced usage.
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
8. Preferred operator path for local guarded apply/rollback is `nixpi evolve` and `nixpi rollback`.

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
- **WhatsApp bridge**: Baileys adapter in `services/whatsapp-bridge/` receives messages, processes through Pi, and sends responses. Managed as a systemd service via `infra/nixos/modules/whatsapp.nix`.
- **Heartbeat timer**: periodic agent observation cycle via `infra/nixos/modules/heartbeat.nix`. Scans objects, checks overdue tasks, detects patterns, and can send nudges or file evolution requests.
- **OpenPersona**: 4-layer identity model (SOUL, BODY, FACULTY, SKILL) in `persona/`. Injected into the Pi agent profile by NixOS activation scripts.

## Ecosystem Direction
- WhatsApp is the first external communication channel (via Baileys bridge).
- Additional channels/capabilities come via extensions or new service adapters.
- Encourage extension packaging as Nix packages/modules so users can compose custom Nixpi systems declaratively.

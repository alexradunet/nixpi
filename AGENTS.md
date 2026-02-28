# AGENTS.md

Related: [Contributing](./CONTRIBUTING.md) · [Source of Truth](./docs/meta/SOURCE_OF_TRUTH.md) · [Operating Model](./docs/runtime/OPERATING_MODEL.md) · [Agents Overview](./docs/agents/README.md) · [Docs Home](./docs/README.md)

## Project
- Name: **Nixpi**
- Goal: Build an autonomous AI personal agent on top of pi, targeting NixOS-first workflows.

## Working Style
- Prefer small, reversible changes.
- Explain planned actions before making impactful changes.
- Keep output concise and practical.

## Development Model (Default)
- Build and validate inside **Nixpi** (repo + terminal + tests are the source of truth).
- Use **Pi** (TUI or non-interactive) as an assistant/operator layer, not as source of truth.
- Accept changes only when repository checks/tests pass.

## TDD Policy (Mandatory)
- Follow strict **Red -> Green -> Refactor**.
- Never write production code before a failing test.
- For bug fixes: add a failing reproduction test first, then fix, then add at least one edge-case regression test.
- For features: include happy path, failure path, and at least one edge case.

## Safety Rules
- Never run destructive commands without explicit confirmation (`rm -rf`, partitioning, bootloader edits, mass deletes).
- Prefer declarative Nix changes over ad-hoc system mutation.
- Use least privilege; avoid unrestricted root usage.
- Protect secrets and private files (`~/.ssh`, tokens, credentials, `.env`).

## Nix/NixOS Conventions
- Prefer flakes over channels.
- Keep reproducibility artifacts committed (`flake.nix`, `flake.lock`, `package-lock.json` when applicable).
- Keep the canonical flake entrypoint at repository root (`./flake.nix`, `./flake.lock`).
- If subflakes are added later, keep root flake as the primary interface pre-release.
- Validate before apply for system changes.
- Document rollback steps for risky operations.

## Architecture Conventions
- **Hexagonal (Ports and Adapters)** architecture with interface-first design.
- All domain components implement interfaces from `@nixpi/core/types.ts`.
- **Object store**: flat-file markdown with YAML frontmatter. Shell CRUD (`scripts/nixpi-object.sh`) and TypeScript ObjectStore (`@nixpi/core`) produce format-compatible files.
- **OpenPersona 4-layer** identity model: SOUL.md, BODY.md, FACULTY.md, SKILL.md in `persona/`.
- **NixOS module factory** (`infra/nixos/lib/mk-nixpi-service.nix`) for shared systemd boilerplate.
- **Nix-first, npm second** — prefer Nix packages (yq-go, jq, ripgrep, fd) over npm equivalents.
- **No unmaintained deps** — npm deps must be <18 months since last publish.
- **yq-go for shell YAML, js-yaml for TypeScript YAML** — two tools, clearly scoped.
- **node:test for TS tests** — zero test framework deps.

## Repository Conventions
- Project root: `~/Nixpi`
- npm workspaces: `packages/nixpi-core/`, `services/matrix-bridge/`
- Commit messages should be clear and scoped (`feat:`, `fix:`, `chore:`, `docs:`)

## Documentation Conventions
- Treat docs as modular knowledge units (split by concept).
- In `docs/`, use standard Markdown links as the canonical linking format.
- Follow precedence rules in `docs/meta/SOURCE_OF_TRUTH.md` when resolving conflicts.
- Update `docs/README.md` when introducing major documentation pages.

## Standards Policy (Mandatory)
- We work with standards-first approaches by default.
- Prefer open standards and portable formats/protocols over proprietary or tool-specific syntax.
- If a non-standard solution is proposed, document why standards are insufficient.

## Pre-Release Simplicity Rule (Mandatory)
- Until first stable release, do **not** keep legacy code paths or backward-compatibility shims.
- Prefer clean replacements over dual-path implementations.
- If compatibility is temporarily unavoidable, document why and add a removal task/milestone.

## Pi Integration
- Pi is the internal engine, used by `nixpi` under the hood (not exposed as a user-facing command).
- `nixpi` is the only user-facing assistant CLI (single instance) built declaratively in `base.nix`.
- Services run as the `nixpi-agent` system user (not the human user). Agent state: `/var/lib/nixpi/agent/`. The primary user gets read access via the `nixpi` group.
- Secrets are in `/etc/nixpi/secrets/` (root:root 0700). The `piWrapper` sources `ai-provider.env` for API key injection.
- System prompts/settings are seeded by NixOS activation script in `base.nix`.
- Update path: bump Pi package version in `base.nix` then `sudo nixos-rebuild switch --flake .`.

## NixOS Module System
- Services are extracted into toggleable modules in `infra/nixos/modules/` with `nixpi.<service>.enable` flags.
- Available modules: `tailscale`, `ttyd`, `syncthing`, `desktop`, `passwordPolicy`, `heartbeat`, `matrix`, `objects`.
- `nixpi setup` runs a dialog TUI for hostname, username, AI provider, and module selection.
- The flake exports individual `nixosModules` (`.default`, `.base`, `.tailscale`, etc.) for external consumption.

## Agent Behavior in This Repo
- Ask before changing system-level config or installing/removing major dependencies.
- For code/file changes: read first, then edit surgically.
- Summarize what changed with file paths.

## Visual Communication Policy
- Use the canonical emoji mapping in `docs/ux/EMOJI_DICTIONARY.md` when communicating status/plans.
- Always pair emoji with explicit plain text meaning.
- Keep emoji usage minimal and consistent (avoid decorative noise).

## Agent Role Policy
- Agent codenames follow Greek mythology identity:
  - Hermes = Runtime
  - Athena = Technical Architect
  - Hephaestus = Maintainer
  - Themis = Reviewer
- Hermes (Runtime) must not directly self-modify Nixpi core/system config.
- Hermes should create evolution requests when core improvements are needed.
- Athena plans evolution work and validates conformance to architecture/rules.
- Hephaestus performs code evolution in controlled repo context with strict TDD and validation before apply.
- Themis performs independent quality/security/policy review before apply.
- See role contracts in `docs/agents/`.
- Hermes is the master orchestrator — spawns sub-agents via `nixpi --skill infra/pi/skills/<agent>/SKILL.md`.
- Evolution objects (`data/objects/evolution/`) track pipeline state across agent handoffs.
- Rework loop: Themis can send structured findings back to Hephaestus (max 2 cycles before human escalation).

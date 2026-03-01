# Source of Truth Map

Related: [Docs Home](../README.md) · [Operating Model](../runtime/OPERATING_MODEL.md) · [Docs Style](./DOCS_STYLE.md)

This document defines canonical sources when information conflicts.

## Priority Order

1. **System behavior (canonical):**
   - Root flake entrypoint: `./flake.nix`, `./flake.lock`
   - `infra/nixos/*.nix`
2. **Process and engineering policy (canonical):**
   - `AGENTS.md`
   - `CONTRIBUTING.md`
3. **Runtime architecture and roles (canonical):**
   - `docs/runtime/OPERATING_MODEL.md`
   - `docs/agents/README.md`
   - `docs/agents/<agent>/README.md`
4. **Communication and authoring conventions (canonical):**
   - `docs/ux/EMOJI_DICTIONARY.md`
   - `docs/meta/DOCS_STYLE.md`

## Configuration Ownership

- Core NixOS settings (SSH, nix, users, networking) are declared in `infra/nixos/base.nix`.
- Each optional service module in `infra/nixos/modules/` is the canonical source for its service configuration (Tailscale, Syncthing, ttyd, desktop, password-policy, matrix, heartbeat, objects).
- Declarative extension sources are tracked in `infra/pi/extensions/packages.json`.
- Pi agent state lives at `/var/lib/nixpi/agent/` (owned by `nixpi-agent` system user).
- Secrets are stored at `/etc/nixpi/secrets/` (root:root, mode 0700).
- Repo-local `.pi/settings.json` is development convenience for this repository and is not the production system source of truth.

## Generated Artifacts Policy

- `docs/agents/handoffs/*.md` are operational artifacts generated during workflows.
- They are **local by default** and not committed pre-release.
- Keep only `docs/agents/handoffs/.gitkeep` in version control.

## Pre-Release Simplicity Reminder

Before first stable release, avoid compatibility shims and legacy paths unless explicitly justified with a removal plan.

# AGENTS.md

## Project
- Name: **nixpi**
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
- Validate before apply for system changes.
- Document rollback steps for risky operations.

## Repository Conventions
- Project root: `~/Development/NixPi`
- Commit messages should be clear and scoped (`feat:`, `fix:`, `chore:`, `docs:`)

## Pi Integration
- `pi` is Nix-packaged via [llm-agents.nix](https://github.com/numtide/llm-agents.nix) (not npx).
- Config directory: `~/.pi/agent/` (auth managed by `pi login`).
- System prompt seeded by NixOS activation script in `base.nix`.
- Update path: `nix flake update llm-agents` then `sudo nixos-rebuild switch --flake .`.

## Agent Behavior in This Repo
- Ask before changing system-level config or installing/removing major dependencies.
- For code/file changes: read first, then edit surgically.
- Summarize what changed with file paths.

## Visual Communication Policy
- Use the canonical emoji mapping in `docs/EMOJI_DICTIONARY.md` when communicating status/plans.
- Always pair emoji with explicit plain text meaning.
- Keep emoji usage minimal and consistent (avoid decorative noise).

## Runtime vs Maintainer Policy
- Runtime assistant must not directly self-modify Nixpi core/system config.
- Runtime assistant should create evolution requests when core improvements are needed.
- Maintainer/dev agent performs code evolution in controlled repo context with strict TDD and validation before apply.

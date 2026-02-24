# AGENTS.md

## Project
- Name: **nixpi**
- Goal: Build an autonomous AI personal agent on top of pi, targeting NixOS-first workflows.

## Working Style
- Prefer small, reversible changes.
- Explain planned actions before making impactful changes.
- Keep output concise and practical.

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
- Docs live in `docs/`
- Commit messages should be clear and scoped (`feat:`, `fix:`, `chore:`, `docs:`)

## Pi Integration
- `pi` is Nix-packaged via [llm-agents.nix](https://github.com/numtide/llm-agents.nix) (not npx).
- Config directory: `~/.pi/agent/` (auth managed by `pi login`).
- System prompt seeded by NixOS activation script in `desktop.nix`.
- Update path: `nix flake update llm-agents` then `sudo nixos-rebuild switch --flake .#nixpi`.

## Agent Behavior in This Repo
- Ask before changing system-level config or installing/removing major dependencies.
- For code/file changes: read first, then edit surgically.
- Summarize what changed with file paths.

# Contributing to nixpi

This project is NixOS-first and AI-assisted. Keep changes reproducible, test-driven, and easy to review.

## Development Operating Model
- Build in **Nixpi** (repo + shell + tests).
- Use **Pi** (TUI or `pi -p`) as assistant support.
- Repository files + tests + git history are the source of truth.

## Mandatory TDD Workflow
Use this cycle for every behavior change:
1. **Red**: write the smallest failing test first.
2. **Green**: implement the minimal code to pass.
3. **Refactor**: improve structure while tests stay green.

### Bug Fixes (Required)
- Add a failing bug reproduction test first.
- Apply minimal fix.
- Add at least one neighboring edge-case regression test.

### Features (Required)
- Add tests first for:
  - happy path
  - failure path
  - at least one edge case

## Validation
Run relevant tests for changed code, and for repo-wide checks run:

```bash
nix flake check --no-build
# or
./scripts/check.sh
```

## Nix/NixOS Rules
- Prefer declarative Nix changes over imperative mutations.
- Do not edit `/etc` or systemd units directly.
- For system-level changes, include validation and rollback notes.

## Safety
- Never run destructive commands without explicit confirmation.
- Do not access secrets (`~/.ssh`, tokens, credentials, `.env`, `~/.pi/agent/auth.json`).

## Commit and PR Expectations
- Use clear scoped commit messages (`feat:`, `fix:`, `test:`, `docs:`, `chore:`).
- Keep PRs small and reversible.
- In PR description include:
  1. failing test(s) added first
  2. minimal code change that made them pass
  3. edge-case/regression coverage
  4. commands run + outcomes

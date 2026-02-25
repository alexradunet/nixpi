# Contributing to nixpi

This project is NixOS-first and AI-assisted. Keep changes reproducible, test-driven, and easy to review.

## Development Operating Model
- Build in **Nixpi** (repo + shell + tests).
- Use **`nixpi dev`** as the primary developer-mode assistant interface.
- Use **Pi** (`pi` / `pi -p`) as the underlying SDK/advanced CLI when needed.
- Repository files + tests + git history are the source of truth.
- If policies/docs conflict, resolve using `docs/meta/SOURCE_OF_TRUTH.md`.

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
# Run repository tests
./scripts/test.sh

# Full checks (tests + flake validation)
./scripts/check.sh

# Optional direct flake validation
nix flake check --no-build
```

## Nix/NixOS Rules
- Prefer declarative Nix changes over imperative mutations.
- Do not edit `/etc` or systemd units directly.
- For system-level changes, include validation and rollback notes.

## Standards-First Rule (Mandatory)
- We only work with standards-first solutions by default.
- Prefer open, interoperable formats/protocols over proprietary or tool-specific ones.
- If deviating from standards, explain and document the trade-off in the PR.

## Pre-Release Simplicity Rule (Mandatory)
- Before first stable release, do not introduce or keep legacy code paths and backward-compatibility shims.
- Implement clean single-path behavior whenever possible.
- If a temporary compatibility layer is unavoidable, document rationale and planned removal in the PR.

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

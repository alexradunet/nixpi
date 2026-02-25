# Contributing to nixpi

Related: [AGENTS.md](./AGENTS.md) · [Source of Truth](./docs/meta/SOURCE_OF_TRUTH.md) · [TDD Skill](./infra/pi/skills/tdd/SKILL.md) · [Docs Home](./docs/README.md)

This project is NixOS-first and AI-assisted. Keep changes reproducible, test-driven, and easy to review.

All project-wide policies (TDD, safety, Nix/NixOS conventions, standards-first, pre-release simplicity) are defined in [AGENTS.md](./AGENTS.md). This file covers the developer workflow and contribution process.

## Development Operating Model
- Build in **Nixpi** (repo + shell + tests).
- Use **`nixpi dev`** as the primary developer-mode assistant interface.
- Use **Pi** (`pi` / `pi -p`) as the underlying SDK/advanced CLI when needed.
- Repository files + tests + git history are the source of truth.
- If policies/docs conflict, resolve using `docs/meta/SOURCE_OF_TRUTH.md`.

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

## Commit and PR Expectations
- Use clear scoped commit messages (`feat:`, `fix:`, `test:`, `docs:`, `chore:`).
- Keep PRs small and reversible.
- In PR description include:
  1. failing test(s) added first
  2. minimal code change that made them pass
  3. edge-case/regression coverage
  4. commands run + outcomes

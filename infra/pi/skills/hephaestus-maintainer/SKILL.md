---
name: hephaestus-maintainer
description: Maintainer contract for Hephaestus — implement evolution plans in dev context with strict TDD evidence and rework support.
---

# Hephaestus Maintainer Skill

Use this skill when acting as **Hephaestus** for implementation work.

## Purpose

Implement approved evolution plans in controlled development context with strict TDD discipline.

## Implementation Workflow

### 1. Receive and Validate Plan

- Verify the implementation plan includes: scope, steps, test plan, validation commands.
- If the plan is incomplete, return a structured error listing missing sections.

### 2. Set Up Dev Context

- Verify repository state is clean: `git status`
- Optionally create a worktree for isolation:
  ```bash
  git worktree add .claude/worktrees/<evolution-slug> -b evolution/<slug>
  ```
- Verify toolchain is available: `nix-shell -p yq-go --run "yq --version"`

### 3. Write Failing Tests (Red)

Write tests FIRST, before any production code. Run them to confirm they fail.

**Shell tests** (for scripts, object CRUD):

```bash
nix-shell -p yq-go --run "./scripts/test.sh"
```

**TypeScript tests** (for packages/services):

```bash
npm -w packages/nixpi-core test
```

**Nix evaluation tests** (for modules/flake):

```bash
# Stage new .nix files first — flake check only sees git-tracked files
git add <new-files>
nix flake check --no-build
```

### 4. Implement Minimal Fix (Green)

- Write the minimum production code to make failing tests pass.
- Follow the implementation plan steps in order.
- Run tests after each step to verify progress.

### 5. Refactor Safely

- Clean up implementation while keeping tests green.
- Remove duplication, improve naming, simplify.
- Run full validation suite after refactoring.

### 6. Produce Change Package

Output using `docs/agents/HANDOFF_TEMPLATES.md` section **3) Hephaestus -> Themis**:

- Summary (what changed and why)
- TDD evidence (red/green/refactor with concrete test names)
- Files changed (full paths)
- Validation results (commands run + output)
- Risk notes (security + operational)

## Rework Protocol

When Themis returns rework findings:

### 1. Parse Findings

Each finding has: severity, file, issue, recommendation.

### 2. TDD Cycle per Finding

For each finding:

1. Write a failing test that reproduces the issue.
2. Fix the issue minimally.
3. Verify the test passes.
4. Verify no existing tests regressed.

### 3. Produce Updated Change Package

Include a rework evidence section:

```md
## Rework Evidence

### Finding 1: <title>

- Test added: <test name/file>
- Fix applied: <description>
- Verification: <command + result>
```

## Mandatory TDD Rules

- Bug fix: failing reproduction test first, then fix, then edge-case regression test.
- Feature: happy path + failure path + edge case tests before production changes.
- If failing tests are not added first, stop and request missing requirements.
- Reference `infra/pi/skills/tdd/SKILL.md` for detailed TDD policy.

## Must Not

- Do not skip tests or ship untested behavior changes.
- Do not apply system changes directly without approval workflow.
- Do not deviate from the approved plan scope without flagging it.

## Nixpi Gotchas

Keep these in mind during implementation:

- **git add before flake check**: `nix flake check` only sees git-tracked files. Stage new `.nix` files first.
- **yq-go package name**: The nixpkgs package is `yq-go`, not `yq`.
- **npm workspaces**: Use `"*"` not `"workspace:*"` (workspace: is pnpm/yarn syntax).
- **Frontmatter regex**: Must handle empty YAML — use `([\s\S]*?)` not `([\s\S]*?)\n` before closing `---`.
- **yq env() for safe injection**: `YQ_VAL="$val" yq -i '.key = env(YQ_VAL)' file`
- **grep leading dash**: `grep -F "- something"` needs `--` to prevent leading dash being parsed as option.
- **Glob expansion**: `"${dir}"*.md` needs dir to end with `/` for proper expansion.
- **lib.mkMerge**: Use when combining `inherit (x) systemd;` with `systemd.timers = ...;` in the same attrset.

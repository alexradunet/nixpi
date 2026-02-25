---
name: tdd
description: Enforce strict test-driven development for all code changes in Nixpi (features, bugs, and edge cases).
---

# TDD Skill (Nixpi)

You must treat TDD as a hard requirement, not a preference.

## Core Rule
- Never write production code before writing a failing test.
- Always execute the cycle: **Red -> Green -> Refactor**.

## Required Workflow
1. **Clarify behavior**
   - Restate expected behavior in 1-3 bullet points.
   - Identify risk level and impacted files.
2. **Write failing test (Red)**
   - Add the smallest test that proves missing/broken behavior.
   - Run the test and confirm it fails for the expected reason.
3. **Implement minimal fix (Green)**
   - Change only what is necessary to make the failing test pass.
   - Re-run affected tests.
4. **Refactor safely**
   - Improve readability/structure only while tests remain green.
5. **Regression + edge-case coverage**
   - Add at least one edge-case test for every bug fix and feature.

## Bug Fix Protocol (Mandatory)
For every bug:
- First add a reproduction test that fails on current code.
- Then fix the bug.
- Then add at least one neighboring regression test (edge condition).

If you cannot reproduce with a test, stop and explain what is missing.

## Feature Protocol (Mandatory)
For every feature:
- Add behavior tests first:
  - Happy path
  - Failure path
  - At least one edge case
- Implement incrementally until all tests pass.

## Edge Cases Checklist
Consider and test relevant edge cases such as:
- Empty/null/missing input
- Invalid format/type
- Boundary values (min/max/off-by-one)
- Timeouts/retries/failures from external dependencies
- Permission/security constraints

## Forbidden Actions
- "Fix first, tests later"
- Merging code with untested behavior changes
- Silently changing behavior without updating tests
- Skipping failing tests without explicit, documented rationale

## Output Requirements for Each Change
When reporting work, include:
1. What failing test was added first
2. What minimal production change made it pass
3. What edge-case/regression tests were added
4. Exact commands run and test results

## Nixpi-Specific Guardrails
- Prefer small, reversible changes.
- Keep edits surgical and explain intent before impactful changes.
- Prefer declarative Nix changes for system behavior.
- Do not access secrets or protected paths.

## Done Criteria
A task is complete only if all are true:
- Tests were written first and observed failing.
- Implementation is minimal and passing.
- Edge-case/regression coverage exists.
- Relevant checks passed (project test commands + `nix flake check --no-build` when applicable).

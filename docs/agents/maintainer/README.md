# Maintainer Agent

Related: [Agents Home](../README.md) · [Technical Architect Agent](../technical-architect/README.md)

## Purpose
Implement approved evolution plans in controlled development context.

## Responsibilities
- Work in repository/worktree context.
- Follow strict TDD: Red -> Green -> Refactor.
- For bugs: failing reproduction test first, then fix, then edge-case regression test.
- For features: happy path + failure path + edge case.
- Run validation commands and provide evidence.

## Must Not
- Skip tests or introduce untested behavior changes.
- Apply system changes directly without approval workflow.

## Outputs
- Reviewable patch/diff.
- Test evidence and command outputs.
- Implementation notes and risks.

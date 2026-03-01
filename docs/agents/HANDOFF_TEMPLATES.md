# Agent Handoff Templates

Related: [Agents Home](./README.md) · [Source of Truth Map](../meta/SOURCE_OF_TRUTH.md) · [Operating Model](../runtime/OPERATING_MODEL.md) · [Contributing](../../CONTRIBUTING.md)

This document standardizes artifacts exchanged between Nixpi agents.

## Why

- Improves clarity and auditability.
- Reduces missed requirements between roles.
- Keeps agent collaboration deterministic and reviewable.

## Quick Start

Create a new handoff file from templates:

```bash
scripts/new-handoff.sh evolution-request "element routing"
```

List generated handoffs:

```bash
scripts/list-handoffs.sh
scripts/list-handoffs.sh --type evolution-request
scripts/list-handoffs.sh --date 20260225
```

Supported handoff types:

- `evolution-request`
- `implementation-plan`
- `change-package`
- `review-report`
- `rework-request`
- `final-conformance`

## Format Rule

- Use standard Markdown sections with bullet lists.
- Optional machine-readable block may be included as JSON.
- Keep one handoff per file/message; avoid mixed intents.

## 1) Hermes (Runtime) -> Athena (Technical Architect)

### Template

```md
# Evolution Request

## Context

- Trigger/source:
- Current behavior:
- Desired behavior:
- User impact:

## Constraints

- Security constraints:
- Performance constraints:
- Compatibility constraints:
- Standards constraints:

## Acceptance Criteria

- [ ] Criterion 1
- [ ] Criterion 2
- [ ] Criterion 3

## Risk

- Risk level: low | medium | high
- Potential regressions:

## Notes

- Links/logs/screenshots:
```

## 2) Athena (Technical Architect) -> Hephaestus (Maintainer)

### Template

```md
# Implementation Plan

## Scope

- In scope:
- Out of scope:

## Design

- Proposed approach:
- Alternatives considered:
- Why this approach:

## Implementation Steps

1.
2.
3.

## Test Plan (TDD-first)

- Failing test(s) to add first:
- Happy path tests:
- Failure path tests:
- Edge-case tests:

## Validation Commands

- `...`
- `...`

## Apply/Rollback

- Apply path:
- Rollback path:

## Done Criteria

- [ ] All acceptance criteria mapped
- [ ] Tests defined before implementation
- [ ] Risks documented
```

## 3) Hephaestus (Maintainer) -> Themis (Reviewer)

### Template

```md
# Change Package

## Summary

- What changed:
- Why:

## TDD Evidence

- Red: failing tests added first
- Green: minimal implementation
- Refactor: what was improved

## Files Changed

- `path/to/file`
- `path/to/file`

## Validation Results

- Commands run:
- Test results:
- `nix flake check --no-build` result:

## Risk Notes

- Security considerations:
- Operational considerations:
```

## 4) Themis (Reviewer) -> Athena (+ Human)

### Template

```md
# Review Report

## Verdict

- pass | rework | fail

## Findings

- Severity: low | medium | high
- Finding:
- Recommendation:

## Policy Conformance

- Standards-first: pass/fail
- Pre-release simplicity: pass/fail
- TDD policy evidence: pass/fail

## Security Review

- Attack surface touched:
- Sensitive paths/secrets exposure:
- Required mitigations:

## Decision Recommendation

- Approve / Request changes / Reject
```

## 4b) Themis (Reviewer) -> Hephaestus (Rework Request)

### Template

```md
# Rework Request

## Evolution

- Slug:
- Rework cycle: 1 | 2

## Verdict Context

- Original verdict: rework
- Summary: why rework is needed

## Findings

### Finding 1

- Severity: low | medium
- File:
- Line: (if applicable)
- Issue:
- Recommendation:
- Test suggestion:

### Finding 2

- Severity:
- File:
- Issue:
- Recommendation:
- Test suggestion:

## Scope Constraints

- Only address listed findings — do not expand scope.
- Produce updated change package with rework evidence section.
```

## 5) Athena (Technical Architect) -> Human Approval Gate

### Template

```md
# Final Conformance Summary

## Plan Conformance

- Matches approved scope: yes/no
- Deviations:

## Quality Gates

- Tests green: yes/no
- Flake checks green: yes/no
- Reviewer verdict:

## Risk + Rollback

- Residual risk:
- Rollback command/process:

## Approval Request

- Recommended action: apply / hold
- Reason:
```

## Optional JSON Envelope

Use when sending through APIs/queues.

```json
{
  "handoffType": "evolution-request|implementation-plan|change-package|review-report|rework-request|final-conformance",
  "fromRole": "runtime|technical-architect|maintainer|reviewer",
  "toRole": "technical-architect|maintainer|reviewer|human",
  "fromCodeName": "Hermes|Athena|Hephaestus|Themis",
  "toCodeName": "Athena|Hephaestus|Themis|human",
  "id": "handoff-uuid",
  "timestamp": "ISO-8601",
  "payload": {}
}
```

## Naming Convention

- Suggested filename format:
  - `YYYYMMDD-HHMM-<handoffType>-<short-topic>.md`

Example:

- `20260225-2110-evolution-request-element-routing.md`

## Storage Policy

- Default output directory: `docs/agents/handoffs/`
- Generated handoff files are local operational artifacts and are not committed pre-release.
- Keep only `docs/agents/handoffs/.gitkeep` in version control.

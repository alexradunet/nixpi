#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEFAULT_OUT_DIR="$REPO_ROOT/docs/agents/handoffs"
OUT_DIR="${NEW_HANDOFF_OUT_DIR:-$DEFAULT_OUT_DIR}"
TIMESTAMP="${NEW_HANDOFF_TIMESTAMP:-$(date +%Y%m%d-%H%M)}"

usage() {
  cat <<'EOF'
Usage:
  scripts/new-handoff.sh <handoff-type> <short-topic>

Handoff types:
  evolution-request
  implementation-plan
  change-package
  review-report
  final-conformance

Environment overrides:
  NEW_HANDOFF_OUT_DIR     Output directory (default: docs/agents/handoffs)
  NEW_HANDOFF_TIMESTAMP   Timestamp prefix (default: current YYYYMMDD-HHMM)
EOF
}

fail() {
  echo "error: $*" >&2
  exit 1
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [ "$#" -lt 2 ]; then
  usage >&2
  fail "expected <handoff-type> and <short-topic>"
fi

handoff_type="$1"
shift
topic_raw="$*"

slug="$(printf '%s' "$topic_raw" \
  | tr '[:upper:]' '[:lower:]' \
  | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//')"

if [ -z "$slug" ]; then
  fail "invalid topic '$topic_raw' (must contain at least one alphanumeric character)"
fi

render_template() {
  case "$handoff_type" in
    evolution-request)
      cat <<'EOF'
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
EOF
      ;;
    implementation-plan)
      cat <<'EOF'
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
EOF
      ;;
    change-package)
      cat <<'EOF'
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
EOF
      ;;
    review-report)
      cat <<'EOF'
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
EOF
      ;;
    final-conformance)
      cat <<'EOF'
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
EOF
      ;;
    *)
      fail "invalid handoff type '$handoff_type' (expected: evolution-request, implementation-plan, change-package, review-report, final-conformance)"
      ;;
  esac
}

template_content="$(render_template)"

mkdir -p "$OUT_DIR"
output_file="$OUT_DIR/$TIMESTAMP-$handoff_type-$slug.md"

if [ -e "$output_file" ]; then
  fail "output already exists: $output_file"
fi

printf '%s\n' "$template_content" > "$output_file"
printf '%s\n' "$output_file"

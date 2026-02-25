#!/usr/bin/env bash
set -euo pipefail

SCRIPT="scripts/new-handoff.sh"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_contains() {
  local file="$1"
  local needle="$2"
  grep -Fq "$needle" "$file" || fail "expected '$needle' in $file"
}

assert_nonempty() {
  local value="$1"
  local msg="$2"
  [ -n "$value" ] || fail "$msg"
}

# Happy path: generate an evolution request handoff file with deterministic timestamp.
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

stdout_file="$TMP_DIR/stdout.txt"
NEW_HANDOFF_OUT_DIR="$TMP_DIR/out" NEW_HANDOFF_TIMESTAMP="20260225-2200" \
  "$SCRIPT" evolution-request "Element routing" >"$stdout_file"

created_path="$(cat "$stdout_file")"
assert_nonempty "$created_path" "script did not print output path"
[ -f "$created_path" ] || fail "expected generated file at $created_path"

assert_contains "$created_path" "# Evolution Request"
assert_contains "$created_path" "## Acceptance Criteria"

# Failure path: unknown handoff type should fail with clear error.
set +e
invalid_output="$(NEW_HANDOFF_OUT_DIR="$TMP_DIR/out" NEW_HANDOFF_TIMESTAMP="20260225-2201" $SCRIPT unknown-type "topic" 2>&1)"
invalid_code=$?
set -e
[ $invalid_code -ne 0 ] || fail "expected non-zero exit code for invalid type"
echo "$invalid_output" | grep -Fq "invalid handoff type" || fail "missing invalid type error"

# Edge case: topic that sanitizes to empty should fail.
set +e
edge_output="$(NEW_HANDOFF_OUT_DIR="$TMP_DIR/out" $SCRIPT evolution-request "!!!" 2>&1)"
edge_code=$?
set -e
[ $edge_code -ne 0 ] || fail "expected non-zero exit code for empty sanitized topic"
echo "$edge_output" | grep -Fq "invalid topic" || fail "missing invalid topic error"

echo "PASS: new-handoff script"

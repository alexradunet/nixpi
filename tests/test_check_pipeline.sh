#!/usr/bin/env bash
set -euo pipefail

CHECK_SCRIPT="scripts/check.sh"
TEST_SCRIPT="scripts/test.sh"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_contains() {
  local file="$1"
  local needle="$2"
  grep -Fq "$needle" "$file" || fail "expected '$needle' in $file"
}

assert_executable() {
  local file="$1"
  [ -x "$file" ] || fail "expected executable file: $file"
}

# Feature: dedicated test runner exists.
assert_executable "$TEST_SCRIPT"
assert_contains "$TEST_SCRIPT" "tests/test_*.sh"

# Failure-path prevention: check pipeline must include test phase before flake checks.
assert_contains "$CHECK_SCRIPT" "./scripts/test.sh"
assert_contains "$CHECK_SCRIPT" "nix flake check --no-build"

# Edge case: test runner should fail when no tests are discovered.
assert_contains "$TEST_SCRIPT" "No tests found"

echo "PASS: check pipeline consistency"

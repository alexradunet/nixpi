#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/helpers.sh"

CHECK_SCRIPT="scripts/check.sh"
TEST_SCRIPT="scripts/test.sh"

# Feature: dedicated test runner exists.
assert_executable "$TEST_SCRIPT"
assert_file_contains "$TEST_SCRIPT" "tests/test_*.sh"

# Failure-path prevention: check pipeline must include test phase before flake checks.
assert_file_contains "$CHECK_SCRIPT" "./scripts/test.sh"
assert_file_contains "$CHECK_SCRIPT" "nix flake check --no-build"

# Edge case: test runner should fail when no tests are discovered.
assert_file_contains "$TEST_SCRIPT" "No tests found"

echo "PASS: check pipeline consistency"

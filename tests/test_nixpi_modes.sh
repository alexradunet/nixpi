#!/usr/bin/env bash
set -euo pipefail

BASE="infra/nixos/base.nix"
README="README.md"
OPERATING="docs/runtime/OPERATING_MODEL.md"
VERIFY_SCRIPT="scripts/verify-nixpi-modes.sh"

assert_contains() {
  local file="$1"
  local needle="$2"

  if ! grep -Fq "$needle" "$file"; then
    echo "FAIL: expected '$needle' in $file" >&2
    exit 1
  fi
}

assert_executable() {
  local file="$1"

  if [ ! -x "$file" ]; then
    echo "FAIL: expected executable file $file" >&2
    exit 1
  fi
}

# Feature: nixpi command wrapper exists with runtime + dev modes.
assert_contains "$BASE" 'writeShellScriptBin "nixpi"'
assert_contains "$BASE" 'nixpi dev [pi-args...]'
assert_contains "$BASE" 'export PI_CODING_AGENT_DIR="$DEV_DIR"'

# Failure-path handling: explicit error for unknown mode value.
assert_contains "$BASE" 'Unknown nixpi mode:'

# Edge case: default invocation should map to runtime mode.
assert_contains "$BASE" 'export PI_CODING_AGENT_DIR="$RUNTIME_DIR"'

# Docs: clarify nixpi as product command and pi as SDK.
assert_contains "$README" '`nixpi` command'
assert_contains "$README" '`pi` remains available as SDK'
assert_contains "$README" 'nixpi` is installed automatically'
assert_contains "$OPERATING" '`nixpi dev`'

# Smoke-check script: exists, executable, validates runtime/dev mode behavior.
assert_executable "$VERIFY_SCRIPT"
assert_contains "$VERIFY_SCRIPT" 'nixpi --help'
assert_contains "$VERIFY_SCRIPT" 'nixpi mode invalid'
assert_contains "$VERIFY_SCRIPT" 'verify-nixpi-modes: OK'

echo "PASS: nixpi mode/docs checks"
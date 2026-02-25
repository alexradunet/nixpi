#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/helpers.sh"

BASE="infra/nixos/base.nix"
README="README.md"
OPERATING="docs/runtime/OPERATING_MODEL.md"
VERIFY_SCRIPT="scripts/verify-nixpi-modes.sh"

# Feature: nixpi command wrapper exists with runtime + dev modes.
assert_file_contains "$BASE" 'writeShellScriptBin "nixpi"'
assert_file_contains "$BASE" 'nixpi dev [pi-args...]'
assert_file_contains "$BASE" 'export PI_CODING_AGENT_DIR="$DEV_DIR"'

# Failure-path handling: explicit error for unknown mode value.
assert_file_contains "$BASE" 'Unknown nixpi mode:'

# Edge case: default invocation should map to runtime mode.
assert_file_contains "$BASE" 'export PI_CODING_AGENT_DIR="$RUNTIME_DIR"'

# Docs: clarify nixpi as product command and pi as SDK.
assert_file_contains "$README" '`nixpi` command'
assert_file_contains "$README" '`pi` remains available as SDK'
assert_file_contains "$README" 'nixpi` is installed automatically'
assert_file_contains "$OPERATING" '`nixpi dev`'

# Smoke-check script: exists, executable, validates runtime/dev mode behavior.
assert_executable "$VERIFY_SCRIPT"
assert_file_contains "$VERIFY_SCRIPT" 'nixpi --help'
assert_file_contains "$VERIFY_SCRIPT" 'nixpi mode invalid'
assert_file_contains "$VERIFY_SCRIPT" 'verify-nixpi-modes: OK'

echo "PASS: nixpi mode/docs checks"

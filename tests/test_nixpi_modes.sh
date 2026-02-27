#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/helpers.sh"

BASE="infra/nixos/base.nix"
CLI_SCRIPT="infra/nixos/scripts/nixpi-cli.sh"
README="README.md"
OPERATING="docs/runtime/OPERATING_MODEL.md"
VERIFY_SCRIPT="scripts/verify-nixpi.sh"

BASE_CONTENT="$(<"$BASE")"
CLI_CONTENT="$(<"$CLI_SCRIPT")"
README_CONTENT="$(<"$README")"
OPERATING_CONTENT="$(<"$OPERATING")"

# Feature (happy path): nixpi wrapper exists and always uses one Nixpi instance dir.
assert_file_contains "$BASE" 'writeShellApplication'
assert_file_contains "$BASE" 'name = "nixpi"'
assert_file_contains "$BASE" 'PI_DIR="${piDir}"'
assert_file_contains "$CLI_SCRIPT" 'export PI_CODING_AGENT_DIR="$PI_DIR"'
assert_file_contains "$BASE" 'nixpi.piDir'
assert_not_contains "$BASE_CONTENT" 'RUNTIME_DIR='
assert_not_contains "$BASE_CONTENT" 'DEV_DIR='
assert_not_contains "$CLI_CONTENT" 'RUNTIME_DIR='
assert_not_contains "$CLI_CONTENT" 'DEV_DIR='

# Feature (edge case): default invocation still forwards to pi with the configured single dir.
assert_file_contains "$CLI_SCRIPT" '*)'
assert_file_contains "$CLI_SCRIPT" 'exec "$PI_BIN" "$@"'

# Docs: single command/single instance model.
assert_file_contains "$README" '`nixpi` command'
assert_file_contains "$README" '`pi` remains available as SDK'
assert_file_contains "$README" 'Single Nixpi instance: `~/Nixpi/.pi/agent/`'
assert_not_contains "$README_CONTENT" 'nixpi dev'
assert_not_contains "$README_CONTENT" 'Developer mode: `~/Nixpi/.pi/agent-dev/`'
assert_file_contains "$OPERATING" '`nixpi` → single Nixpi instance (primary path).'
assert_not_contains "$OPERATING_CONTENT" '`nixpi dev`'
assert_not_contains "$OPERATING_CONTENT" '`~/Nixpi/.pi/agent-dev/` (developer mode)'

# Smoke-check script: exists, executable, validates single-instance behavior.
assert_executable "$VERIFY_SCRIPT"
assert_file_contains "$VERIFY_SCRIPT" 'nixpi --help'
assert_file_contains "$VERIFY_SCRIPT" 'nixpi dev'
assert_file_contains "$VERIFY_SCRIPT" 'verify-nixpi: OK'

echo "PASS: nixpi single-instance checks"

#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/helpers.sh"

BASE="infra/nixos/base.nix"
BASE_CONTENT="$(<"$BASE")"

# Happy path: SYSTEM.md is declaratively refreshed on every activation.
assert_file_contains "$BASE" 'cat > "$PI_DIR/SYSTEM.md" <<'"'"'SYSEOF'"'"''
assert_not_contains "$BASE_CONTENT" 'if [ ! -f "$PI_DIR/SYSTEM.md" ]; then'

# Failure path protection: activation ensures shared-writable profile directories.
assert_file_contains "$BASE" 'install -d -m 2775 -o ${primaryUser} -g nixpi "$PI_PROJECT_DIR"'
assert_file_contains "$BASE" 'install -d -m 2775 -o ${config.nixpi.assistantUser} -g nixpi "$PI_DIR"/{sessions,extensions,skills,prompts,themes}'

# Edge case: settings remain write-once to avoid clobbering runtime/user state.
assert_file_contains "$BASE" 'if [ ! -f "$PI_DIR/settings.json" ]; then'
assert_file_contains "$BASE" 'chmod 0664 "$PI_DIR/settings.json"'

echo "PASS: pi profile sync policy (SYSTEM.md refresh + settings preservation)"

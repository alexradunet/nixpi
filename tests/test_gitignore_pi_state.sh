#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/helpers.sh"

GITIGNORE=".gitignore"
CONTENT="$(<"$GITIGNORE")"

# Happy path: all Pi runtime state is ignored at repo root.
assert_file_contains "$GITIGNORE" '/.pi/'

# Failure path guard: no narrow legacy ignore entries that imply partial tracking.
assert_not_contains "$CONTENT" '/.pi/agent/'
assert_not_contains "$CONTENT" '/.pi/agent-dev/'

# Edge case: keep handoff artifact policy intact.
assert_file_contains "$GITIGNORE" '/docs/agents/handoffs/*.md'
assert_file_contains "$GITIGNORE" '!/docs/agents/handoffs/.gitkeep'

echo "PASS: .pi runtime state is fully gitignored"

#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/helpers.sh"

SCRIPT="scripts/nixpi-object.sh"
TMPDIR_OBJ="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_OBJ"' EXIT
export NIXPI_OBJECTS_DIR="$TMPDIR_OBJ"

# Setup: create test objects.
"$SCRIPT" create task "buy-milk" --title="Buy milk" --status=active --area=household >/dev/null

# Happy path: read by type and slug returns full content.
out="$("$SCRIPT" read task buy-milk)"
assert_contains "$out" "type: task"
assert_contains "$out" "slug: buy-milk"
assert_contains "$out" "title: Buy milk"
assert_contains "$out" "status: active"

# Failure path: read nonexistent object.
if "$SCRIPT" read task "nonexistent" 2>/dev/null; then
  fail "expected read of nonexistent object to fail"
fi

# Failure path: read with missing arguments.
if "$SCRIPT" read 2>/dev/null; then
  fail "expected read with no args to fail"
fi

if "$SCRIPT" read task 2>/dev/null; then
  fail "expected read with no slug to fail"
fi

echo "PASS: nixpi-object read works for happy and failure cases"

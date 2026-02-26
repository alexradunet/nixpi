#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/helpers.sh"

SCRIPT="scripts/nixpi-object.sh"
TMPDIR_OBJ="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_OBJ"' EXIT
export NIXPI_OBJECTS_DIR="$TMPDIR_OBJ"

# Setup: create a task.
"$SCRIPT" create task "buy-milk" --title="Buy milk" --status=active --area=household >/dev/null

# Happy path: update status field.
"$SCRIPT" update task "buy-milk" --status=done
assert_file_contains "$TMPDIR_OBJ/task/buy-milk.md" "status: done"

# Happy path: update adds a new field.
"$SCRIPT" update task "buy-milk" --priority=low
assert_file_contains "$TMPDIR_OBJ/task/buy-milk.md" "priority: low"
# Previous fields remain.
assert_file_contains "$TMPDIR_OBJ/task/buy-milk.md" "status: done"
assert_file_contains "$TMPDIR_OBJ/task/buy-milk.md" "title: Buy milk"

# Happy path: modified timestamp updated.
assert_file_contains "$TMPDIR_OBJ/task/buy-milk.md" "modified:"

# Failure path: update nonexistent object.
if "$SCRIPT" update task "nonexistent" --status=done 2>/dev/null; then
  fail "expected update of nonexistent object to fail"
fi

# Failure path: update with no fields.
if "$SCRIPT" update task "buy-milk" 2>/dev/null; then
  fail "expected update with no fields to fail"
fi

echo "PASS: nixpi-object update works for happy, failure, and edge cases"

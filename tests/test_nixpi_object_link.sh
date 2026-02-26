#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/helpers.sh"

SCRIPT="scripts/nixpi-object.sh"
TMPDIR_OBJ="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_OBJ"' EXIT
export NIXPI_OBJECTS_DIR="$TMPDIR_OBJ"

# Setup: create two objects.
"$SCRIPT" create task "buy-milk" --title="Buy milk" --status=active >/dev/null
"$SCRIPT" create note "shopping-list" --title="Shopping list" >/dev/null

# Happy path: link two objects bidirectionally.
"$SCRIPT" link task/buy-milk note/shopping-list
assert_file_contains "$TMPDIR_OBJ/task/buy-milk.md" "note/shopping-list"
assert_file_contains "$TMPDIR_OBJ/note/shopping-list.md" "task/buy-milk"

# Edge case: linking same pair again is idempotent.
"$SCRIPT" link task/buy-milk note/shopping-list
# Count occurrences — should appear exactly once.
count="$(grep -c 'note/shopping-list' "$TMPDIR_OBJ/task/buy-milk.md")"
[ "$count" -eq 1 ] || fail "expected exactly one link entry, got $count"

# Failure path: link nonexistent object.
if "$SCRIPT" link task/buy-milk note/nonexistent 2>/dev/null; then
  fail "expected link to nonexistent object to fail"
fi

# Failure path: link with invalid format.
if "$SCRIPT" link "buy-milk" "shopping-list" 2>/dev/null; then
  fail "expected link with missing type prefix to fail"
fi

echo "PASS: nixpi-object link works for happy, failure, and edge cases"

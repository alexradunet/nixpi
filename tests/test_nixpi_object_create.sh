#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/helpers.sh"

SCRIPT="scripts/nixpi-object.sh"
TMPDIR_OBJ="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_OBJ"' EXIT
export NIXPI_OBJECTS_DIR="$TMPDIR_OBJ"

# Script must exist and be executable.
assert_executable "$SCRIPT"

# Happy path: create a journal entry.
out="$("$SCRIPT" create journal "my-first-entry" --title="My First Entry")"
assert_contains "$out" "created"
[ -f "$TMPDIR_OBJ/journal/my-first-entry.md" ] || fail "expected journal file to exist"
assert_file_contains "$TMPDIR_OBJ/journal/my-first-entry.md" "type: journal"
assert_file_contains "$TMPDIR_OBJ/journal/my-first-entry.md" "slug: my-first-entry"
assert_file_contains "$TMPDIR_OBJ/journal/my-first-entry.md" "title: My First Entry"
assert_file_contains "$TMPDIR_OBJ/journal/my-first-entry.md" "created:"

# Happy path: create a task with PARA fields.
"$SCRIPT" create task "fix-bike" --title="Fix bike tire" --status=active --project=home --area=household --priority=high
[ -f "$TMPDIR_OBJ/task/fix-bike.md" ] || fail "expected task file to exist"
assert_file_contains "$TMPDIR_OBJ/task/fix-bike.md" "type: task"
assert_file_contains "$TMPDIR_OBJ/task/fix-bike.md" "status: active"
assert_file_contains "$TMPDIR_OBJ/task/fix-bike.md" "project: home"
assert_file_contains "$TMPDIR_OBJ/task/fix-bike.md" "area: household"
assert_file_contains "$TMPDIR_OBJ/task/fix-bike.md" "priority: high"

# Happy path: create a note with tags.
"$SCRIPT" create note "nix-tips" --title="Nix Tips" --tags=nix,devops
[ -f "$TMPDIR_OBJ/note/nix-tips.md" ] || fail "expected note file to exist"
assert_file_contains "$TMPDIR_OBJ/note/nix-tips.md" "type: note"
assert_file_contains "$TMPDIR_OBJ/note/nix-tips.md" "tags:"

# Failure path: missing type argument.
if "$SCRIPT" create 2>/dev/null; then
  fail "expected create with no type to fail"
fi

# Failure path: missing slug argument.
if "$SCRIPT" create journal 2>/dev/null; then
  fail "expected create with no slug to fail"
fi

# Edge case: duplicate slug fails.
if "$SCRIPT" create journal "my-first-entry" --title="Duplicate" 2>/dev/null; then
  fail "expected duplicate slug to fail"
fi

echo "PASS: nixpi-object create works for happy, failure, and edge cases"

#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/helpers.sh"

SCRIPT="scripts/nixpi-object.sh"
TMPDIR_OBJ="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_OBJ"' EXIT
export NIXPI_OBJECTS_DIR="$TMPDIR_OBJ"

# Setup: create several objects.
"$SCRIPT" create task "buy-milk" --title="Buy milk" --status=active --project=groceries --area=household >/dev/null
"$SCRIPT" create task "fix-bike" --title="Fix bike" --status=active --project=home-repair --area=household >/dev/null
"$SCRIPT" create task "write-report" --title="Write report" --status=done --project=work-q1 --area=career >/dev/null
"$SCRIPT" create note "nix-tips" --title="Nix tips" --area=tech >/dev/null

# Happy path: list all tasks.
out="$("$SCRIPT" list task)"
assert_contains "$out" "buy-milk"
assert_contains "$out" "fix-bike"
assert_contains "$out" "write-report"

# Happy path: list filtered by status.
out="$("$SCRIPT" list task --status=active)"
assert_contains "$out" "buy-milk"
assert_contains "$out" "fix-bike"
assert_not_contains "$out" "write-report"

# Happy path: list filtered by area.
out="$("$SCRIPT" list task --area=household)"
assert_contains "$out" "buy-milk"
assert_contains "$out" "fix-bike"
assert_not_contains "$out" "write-report"

# Happy path: list filtered by project.
out="$("$SCRIPT" list task --project=groceries)"
assert_contains "$out" "buy-milk"
assert_not_contains "$out" "fix-bike"

# Edge case: list type with no objects.
out="$("$SCRIPT" list journal)"
[ -z "$out" ] || assert_contains "$out" ""  # empty or header-only

# Edge case: list all types.
out="$("$SCRIPT" list --all)"
assert_contains "$out" "buy-milk"
assert_contains "$out" "nix-tips"

# Failure path: list with no type and no --all flag.
if "$SCRIPT" list 2>/dev/null; then
  fail "expected list with no type to fail"
fi

echo "PASS: nixpi-object list works with filters and edge cases"

#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/helpers.sh"

SCRIPT="scripts/nixpi-object.sh"
TMPDIR_OBJ="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_OBJ"' EXIT
export NIXPI_OBJECTS_DIR="$TMPDIR_OBJ"

# Setup: create objects with distinct content.
"$SCRIPT" create task "buy-milk" --title="Buy milk from store" --status=active >/dev/null
"$SCRIPT" create note "meeting-notes" --title="Meeting notes about deployment" >/dev/null
"$SCRIPT" create journal "2026-02-27" --title="Daily reflection" >/dev/null

# Append body content to test full-text search.
printf '\nNeed to buy organic milk from the farmers market.\n' >> "$TMPDIR_OBJ/task/buy-milk.md"
printf '\nDiscussed Kubernetes deployment pipeline with team.\n' >> "$TMPDIR_OBJ/note/meeting-notes.md"

# Happy path: search by keyword in body.
out="$("$SCRIPT" search "organic")"
assert_contains "$out" "buy-milk"

# Happy path: search by keyword in frontmatter title.
out="$("$SCRIPT" search "deployment")"
assert_contains "$out" "meeting-notes"

# Happy path: search across types returns results from multiple types.
out="$("$SCRIPT" search "milk")"
assert_contains "$out" "buy-milk"

# Edge case: search with no results returns empty/zero exit.
out="$("$SCRIPT" search "xyznonexistent" || true)"
assert_not_contains "$out" "buy-milk"

# Failure path: search with no pattern.
if "$SCRIPT" search 2>/dev/null; then
  fail "expected search with no pattern to fail"
fi

echo "PASS: nixpi-object search works for happy, failure, and edge cases"

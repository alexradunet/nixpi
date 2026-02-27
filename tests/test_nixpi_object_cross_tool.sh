#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/helpers.sh"

SCRIPT="scripts/nixpi-object.sh"
TMPDIR_OBJ="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_OBJ"' EXIT
export NIXPI_OBJECTS_DIR="$TMPDIR_OBJ"

# Cross-tool format cohesion: shell creates, yq verifies field structure.

# 1. Shell creates object with tags, title, PARA fields.
"$SCRIPT" create task "cross-test" --title="Cross Tool Test" --status=active --project=nixpi --tags=nix,devops

filepath="$TMPDIR_OBJ/task/cross-test.md"
[ -f "$filepath" ] || fail "expected task file to exist"

# 2. Verify frontmatter fields via yq.
type_val="$(yq --front-matter=extract '.type' "$filepath")"
slug_val="$(yq --front-matter=extract '.slug' "$filepath")"
title_val="$(yq --front-matter=extract '.title' "$filepath")"
status_val="$(yq --front-matter=extract '.status' "$filepath")"
project_val="$(yq --front-matter=extract '.project' "$filepath")"

[ "$type_val" = "task" ] || fail "expected type=task, got '$type_val'"
[ "$slug_val" = "cross-test" ] || fail "expected slug=cross-test, got '$slug_val'"
[ "$title_val" = "Cross Tool Test" ] || fail "expected title='Cross Tool Test', got '$title_val'"
[ "$status_val" = "active" ] || fail "expected status=active, got '$status_val'"
[ "$project_val" = "nixpi" ] || fail "expected project=nixpi, got '$project_val'"

# 3. Verify tags are a YAML array (not a string).
tag_count="$(yq --front-matter=extract '.tags | length' "$filepath")"
[ "$tag_count" = "2" ] || fail "expected 2 tags, got '$tag_count'"

first_tag="$(yq --front-matter=extract '.tags[0]' "$filepath")"
second_tag="$(yq --front-matter=extract '.tags[1]' "$filepath")"
[ "$first_tag" = "nix" ] || fail "expected first tag=nix, got '$first_tag'"
[ "$second_tag" = "devops" ] || fail "expected second tag=devops, got '$second_tag'"

# 4. Verify created/modified are present and look like ISO timestamps.
created_val="$(yq --front-matter=extract '.created' "$filepath")"
modified_val="$(yq --front-matter=extract '.modified' "$filepath")"
[[ "$created_val" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T ]] || fail "created doesn't look like ISO: '$created_val'"
[[ "$modified_val" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T ]] || fail "modified doesn't look like ISO: '$modified_val'"

# 5. Verify body contains markdown heading.
body="$(yq --front-matter=extract '""' "$filepath" 2>/dev/null || true)"
# Body after frontmatter should contain the title heading
assert_file_contains "$filepath" "# Cross Tool Test"

# 6. Verify field key validation rejects dots.
if "$SCRIPT" create note "bad-key" --"nested.key"=val 2>/dev/null; then
  fail "expected dot-containing key to be rejected"
fi

echo "PASS: cross-tool format cohesion test"

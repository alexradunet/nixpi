#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/helpers.sh"

PERSONA_DIR="persona"

# Happy path: all 4 OpenPersona layers exist.
[ -f "$PERSONA_DIR/SOUL.md" ] || fail "expected persona/SOUL.md to exist"
[ -f "$PERSONA_DIR/BODY.md" ] || fail "expected persona/BODY.md to exist"
[ -f "$PERSONA_DIR/FACULTY.md" ] || fail "expected persona/FACULTY.md to exist"
[ -f "$PERSONA_DIR/SKILL.md" ] || fail "expected persona/SKILL.md to exist"

# Happy path: SOUL.md defines identity essentials.
assert_file_contains "$PERSONA_DIR/SOUL.md" "# Soul"
assert_file_contains "$PERSONA_DIR/SOUL.md" "identity"
assert_file_contains "$PERSONA_DIR/SOUL.md" "values"
assert_file_contains "$PERSONA_DIR/SOUL.md" "boundaries"

# Happy path: BODY.md defines channel behavior.
assert_file_contains "$PERSONA_DIR/BODY.md" "# Body"
assert_file_contains "$PERSONA_DIR/BODY.md" "channel"

# Happy path: FACULTY.md defines cognitive patterns.
assert_file_contains "$PERSONA_DIR/FACULTY.md" "# Faculty"
assert_file_contains "$PERSONA_DIR/FACULTY.md" "PARA"

# Happy path: SKILL.md defines competency inventory.
assert_file_contains "$PERSONA_DIR/SKILL.md" "# Skill"
assert_file_contains "$PERSONA_DIR/SKILL.md" "object"

# Edge case: files are valid Markdown (no frontmatter required for persona).
for layer in SOUL BODY FACULTY SKILL; do
  # Each file starts with a heading.
  head -1 "$PERSONA_DIR/${layer}.md" | grep -q "^# " || fail "expected ${layer}.md to start with a Markdown heading"
done

echo "PASS: OpenPersona 4-layer files exist with required content"

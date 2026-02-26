#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/helpers.sh"

README="README.md"
OPERATING="docs/runtime/OPERATING_MODEL.md"
README_CONTENT="$(<"$README")"
OPERATING_CONTENT="$(<"$OPERATING")"

# Canonical wording: single-command model points to Agent Skills Index.
assert_file_contains "$README" 'nixpi           # Nixpi assistant (single instance; see docs/agents/SKILLS.md)'
assert_not_contains "$README_CONTENT" 'nixpi dev'

assert_file_contains "$OPERATING" 'Engineering experience: use `nixpi` for Pi-native development with skills from [Agent Skills Index](../agents/SKILLS.md); evolve Nixpi through tested, reviewable, declarative changes.'
assert_file_contains "$OPERATING" '`nixpi` → single Nixpi instance (primary path).'
assert_not_contains "$OPERATING_CONTENT" '`nixpi dev`'
assert_not_contains "$OPERATING_CONTENT" 'developer mode'

echo "PASS: canonical skills-index wording is used"

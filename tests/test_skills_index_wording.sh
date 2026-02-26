#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/helpers.sh"

README="README.md"
OPERATING="docs/runtime/OPERATING_MODEL.md"
README_CONTENT="$(<"$README")"
OPERATING_CONTENT="$(<"$OPERATING")"

# Canonical wording: point to Agent Skills Index instead of generic "skills/rules" phrasing.
assert_file_contains "$README" 'nixpi dev       # Nixpi developer mode (Pi-native; see docs/agents/SKILLS.md)'
assert_not_contains "$README_CONTENT" 'Nixpi developer mode (Pi-native + Nixpi skills/rules)'

assert_file_contains "$OPERATING" 'Engineering experience: use `nixpi dev` for Pi-native development with skills from [Agent Skills Index](../agents/SKILLS.md); evolve Nixpi through tested, reviewable, declarative changes.'
assert_file_contains "$OPERATING" '`nixpi dev` → developer mode (Pi-native workflow; see [Agent Skills Index](../agents/SKILLS.md)).'
assert_not_contains "$OPERATING_CONTENT" 'nixpi dev` for Pi-native development with Nixpi skills/rules preloaded'
assert_not_contains "$OPERATING_CONTENT" 'nixpi dev` → developer mode (Pi-native workflow with Nixpi dev skills/rules).'

echo "PASS: canonical skills-index wording is used"

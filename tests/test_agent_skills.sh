#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/helpers.sh"

AGENTS_OVERVIEW="docs/agents/README.md"
BASE="infra/nixos/base.nix"

# Canonical agent set documented.
assert_file_contains "$AGENTS_OVERVIEW" "Hermes (Runtime Agent)"
assert_file_contains "$AGENTS_OVERVIEW" "Athena (Technical Architect Agent)"
assert_file_contains "$AGENTS_OVERVIEW" "Hephaestus (Maintainer Agent)"
assert_file_contains "$AGENTS_OVERVIEW" "Themis (Reviewer Agent)"

# One skill per canonical agent role.
for skill in \
  hermes-runtime \
  athena-technical-architect \
  hephaestus-maintainer \
  themis-reviewer
  do
  file="infra/pi/skills/$skill/SKILL.md"
  [ -f "$file" ] || fail "expected skill file: $file"
done

# Skills are discoverable by both runtime and developer profiles.
assert_file_contains "$BASE" 'if [ ! -f "$RUNTIME_PI_DIR/settings.json" ]; then'
assert_file_contains "$BASE" 'if [ ! -f "$DEV_PI_DIR/settings.json" ]; then'
assert_file_contains "$BASE" '"${repoRoot}/infra/pi/skills"'

# Spot-check each skill front matter.
assert_file_contains "infra/pi/skills/hermes-runtime/SKILL.md" "name: hermes-runtime"
assert_file_contains "infra/pi/skills/athena-technical-architect/SKILL.md" "name: athena-technical-architect"
assert_file_contains "infra/pi/skills/hephaestus-maintainer/SKILL.md" "name: hephaestus-maintainer"
assert_file_contains "infra/pi/skills/themis-reviewer/SKILL.md" "name: themis-reviewer"

echo "PASS: agent skills are defined and preloaded for runtime/dev"

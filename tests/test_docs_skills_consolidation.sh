#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/helpers.sh"

README="README.md"
CONTRIB="CONTRIBUTING.md"
README_CONTENT="$(<"$README")"
CONTRIB_CONTENT="$(<"$CONTRIB")"

# Canonical skills entrypoint should be docs index, not repeated raw skill file/folder links.
assert_file_contains "$README" 'Agent skills index: [`docs/agents/SKILLS.md`](./docs/agents/SKILLS.md)'
assert_not_contains "$README_CONTENT" 'Pi TDD skill: [`infra/pi/skills/tdd/SKILL.md`](./infra/pi/skills/tdd/SKILL.md)'
assert_not_contains "$README_CONTENT" 'Pi skills: [`infra/pi/skills/`](./infra/pi/skills/)'

# Contributing should link to skills index for concise policy discovery.
assert_file_contains "$CONTRIB" '[Agent Skills Index](./docs/agents/SKILLS.md)'
assert_not_contains "$CONTRIB_CONTENT" '[TDD Skill](./infra/pi/skills/tdd/SKILL.md)'

echo "PASS: skills docs are consolidated via docs/agents/SKILLS.md"

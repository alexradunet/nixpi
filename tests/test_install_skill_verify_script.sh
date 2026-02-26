#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/helpers.sh"

SKILL="infra/pi/skills/install-nixpi/SKILL.md"
CONTENT="$(<"$SKILL")"

# Happy path: install guidance references the canonical verification script.
assert_file_contains "$SKILL" './scripts/verify-nixpi.sh'

# Failure-path guard: stale script naming must not remain.
assert_not_contains "$CONTENT" 'verify-nixpi-modes.sh'

echo "PASS: install skill references canonical verify script"

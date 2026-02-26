#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/helpers.sh"

BASE="infra/nixos/base.nix"
BASE_CONTENT="$(<"$BASE")"

# Happy path: system prompt asks nixpi to announce discovered local skills at startup.
assert_file_contains "$BASE" 'At session start, briefly announce discovered local skills from settings.json.'

# Failure path: if no local skills are available, prompt requires explicit fallback guidance.
assert_file_contains "$BASE" 'If no local skills are found, say so explicitly and suggest `--skill <path-to-SKILL.md>`.'

# Edge case: announcement guidance belongs to the single-instance prompt, not legacy dev prompt wording.
assert_not_contains "$BASE_CONTENT" 'developer-mode assistant'

echo "PASS: startup skills announcement prompt is present"

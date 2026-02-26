#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/helpers.sh"

CONTRIB="CONTRIBUTING.md"
CONTENT="$(<"$CONTRIB")"

# Happy path: docs use the single-instance nixpi command.
assert_file_contains "$CONTRIB" 'Use **`nixpi`** as the primary assistant interface.'

# Failure-path guard: deprecated subcommand wording should not reappear.
assert_not_contains "$CONTENT" '`nixpi dev`'

echo "PASS: contributing docs align with single-instance nixpi command"

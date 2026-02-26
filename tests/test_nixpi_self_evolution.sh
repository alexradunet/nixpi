#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/helpers.sh"

BASE="infra/nixos/base.nix"
README="README.md"
OPERATING="docs/runtime/OPERATING_MODEL.md"

# Happy path: wrapper exposes guarded apply/rollback commands.
assert_file_contains "$BASE" 'nixpi evolve [--yes]'
assert_file_contains "$BASE" 'nixpi rollback [--yes]'
assert_file_contains "$BASE" 'sudo nixos-rebuild switch --flake .'
assert_file_contains "$BASE" 'sudo nixos-rebuild switch --rollback'

# Failure path: risky operations require explicit confirmation unless --yes is provided.
assert_file_contains "$BASE" 'nixpi evolve requires explicit confirmation.'
assert_file_contains "$BASE" 'nixpi rollback requires explicit confirmation.'
assert_file_contains "$BASE" 'Unknown nixpi evolve option:'
assert_file_contains "$BASE" 'Unknown nixpi rollback option:'

# Edge case: failed post-apply validation automatically rolls back.
assert_file_contains "$BASE" './scripts/verify-nixpi.sh'
assert_file_contains "$BASE" 'Rebuild validation failed; rolling back...'

# Docs regression: users can discover the guarded self-evolution workflow.
assert_file_contains "$README" 'nixpi evolve'
assert_file_contains "$README" 'nixpi rollback'
assert_file_contains "$OPERATING" '`nixpi evolve`'
assert_file_contains "$OPERATING" '`nixpi rollback`'

echo "PASS: nixpi guarded self-evolution apply + rollback workflow"

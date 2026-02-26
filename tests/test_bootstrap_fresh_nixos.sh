#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/helpers.sh"

SCRIPT="scripts/bootstrap-fresh-nixos.sh"
DOC="docs/runtime/REINSTALL_MINIMAL_HEADLESS.md"
SCRIPT_CONTENT="$(cat "$SCRIPT" 2>/dev/null || true)"
DOC_CONTENT="$(cat "$DOC")"

# Happy path: first-install bootstrap script exists and runs clone + first rebuild.
assert_executable "$SCRIPT"
assert_file_contains "$SCRIPT" 'nix shell nixpkgs#git -c git clone https://github.com/alexradunet/nixpi.git'
assert_file_contains "$SCRIPT" 'sudo nixos-rebuild switch --flake . --extra-experimental-features "nix-command flakes"'

# Failure path: clear guard for non-repo target path collisions.
assert_file_contains "$SCRIPT" 'exists but is not a git repository'

# Edge case: idempotent rerun should skip cloning and avoid git dependency checks.
assert_file_contains "$SCRIPT" 'Repository already present, skipping clone'
assert_not_contains "$SCRIPT_CONTENT" 'command -v git'

# Docs regression: reinstall flow points to automated bootstrap + one-time clone command.
assert_file_contains "$DOC" './scripts/bootstrap-fresh-nixos.sh'
assert_file_contains "$DOC" 'nix shell nixpkgs#git -c git clone https://github.com/alexradunet/nixpi.git Nixpi'
assert_not_contains "$DOC_CONTENT" 'If `git` is not present on your fresh install:'

echo "PASS: bootstrap automation + git/flakes first-install assumptions"

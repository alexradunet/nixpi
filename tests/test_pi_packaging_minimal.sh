#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/helpers.sh"

FLAKE="flake.nix"
LOCK="flake.lock"
BASE="infra/nixos/base.nix"
README="README.md"
OPERATING="docs/runtime/OPERATING_MODEL.md"
REINSTALL="docs/runtime/REINSTALL.md"

FLAKE_CONTENT="$(cat "$FLAKE")"
LOCK_CONTENT="$(cat "$LOCK")"
BASE_CONTENT="$(cat "$BASE")"
README_CONTENT="$(cat "$README")"
OPERATING_CONTENT="$(cat "$OPERATING")"
REINSTALL_CONTENT="$(cat "$REINSTALL")"

# Happy path: Pi install path is minimal and avoids llm-agents flake dependency.
assert_not_contains "$FLAKE_CONTENT" 'llm-agents.url'
assert_not_contains "$FLAKE_CONTENT" 'llm-agents.overlays.default'
assert_not_contains "$LOCK_CONTENT" 'llm-agents'
assert_file_contains "$BASE" 'writeShellScriptBin "pi"'
assert_file_contains "$BASE" 'npx --yes @mariozechner/pi-coding-agent@0.55.1'

# Failure path: old heavy llm-agents and claude package wiring should be removed.
assert_not_contains "$BASE_CONTENT" 'pkgs.llm-agents.pi'
assert_not_contains "$BASE_CONTENT" 'llm-agents.claude-code'
assert_not_contains "$README_CONTENT" 'llm-agents.nix'
assert_not_contains "$README_CONTENT" '`claude` command'
assert_not_contains "$OPERATING_CONTENT" 'llm-agents.nix'
assert_not_contains "$REINSTALL_CONTENT" 'github:numtide/llm-agents.nix#pi'

# Edge case: docs still keep Pi as primary command and mention npm-backed bootstrap fallback.
assert_file_contains "$README" '`pi` command'
assert_file_contains "$REINSTALL" 'nixpkgs#nodejs_22 -c npx --yes @mariozechner/pi-coding-agent@0.55.1'

echo "PASS: minimal pi packaging without llm-agents input"
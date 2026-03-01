#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/helpers.sh"

FLAKE="flake.nix"
LOCK="flake.lock"
BASE="infra/nixos/base.nix"
README="README.md"
OPERATING="docs/runtime/OPERATING_MODEL.md"
REINSTALL="docs/runtime/REINSTALL.md"

FLAKE_CONTENT="$(<"$FLAKE")"
LOCK_CONTENT="$(<"$LOCK")"
BASE_CONTENT="$(<"$BASE")"
README_CONTENT="$(<"$README")"
OPERATING_CONTENT="$(<"$OPERATING")"
REINSTALL_CONTENT="$(<"$REINSTALL")"

# Happy path: Pi install path is minimal and avoids llm-agents flake dependency.
assert_not_contains "$FLAKE_CONTENT" 'llm-agents.url'
assert_not_contains "$FLAKE_CONTENT" 'llm-agents.overlays.default'
assert_not_contains "$LOCK_CONTENT" 'llm-agents'
assert_file_contains "$BASE" 'writeShellApplication'
assert_file_contains "$BASE" 'name = "pi"'
assert_file_contains "$BASE" 'npx --yes @mariozechner/pi-coding-agent@${config.nixpi.piAgentVersion}'

# Failure path: old heavy llm-agents wiring stays removed.
assert_not_contains "$BASE_CONTENT" 'pkgs.llm-agents.pi'
assert_not_contains "$BASE_CONTENT" 'llm-agents.claude-code'
assert_not_contains "$README_CONTENT" 'llm-agents.nix'
assert_not_contains "$OPERATING_CONTENT" 'llm-agents.nix'
assert_not_contains "$REINSTALL_CONTENT" 'github:numtide/llm-agents.nix#pi'

# Edge case: keep npm-backed Pi wrapper, but install Claude Code from native binary package.
assert_not_contains "$BASE_CONTENT" 'writeShellScriptBin "claude"'
assert_not_contains "$BASE_CONTENT" '@anthropic-ai/claude-code@'
assert_file_contains "$BASE" 'claude-code-bin'
assert_file_contains "$FLAKE" 'nixpkgs-unstable.url'
assert_contains "$LOCK_CONTENT" 'nixpkgs-unstable'
assert_not_contains "$README_CONTENT" '`pi` command'
assert_file_contains "$README" '`claude` command'
assert_file_contains "$REINSTALL" './scripts/install-nixpi-skill.sh'
assert_file_contains "$REINSTALL" 'nixpkgs#nodejs_22 -c npx --yes @mariozechner/pi-coding-agent@0.55.3'

echo "PASS: minimal pi packaging without llm-agents input"

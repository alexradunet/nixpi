#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/helpers.sh"

BASE="infra/nixos/base.nix"
README="README.md"
AGENTS="AGENTS.md"

BASE_CONTENT="$(cat "$BASE")"
README_CONTENT="$(cat "$README")"

# Happy path: installer/user identity is configurable and reused across services.
assert_file_contains "$BASE" 'options.nixpi.primaryUser = lib.mkOption {'
assert_file_contains "$BASE" 'default = "nixpi";'
assert_file_contains "$BASE" 'users.users.${primaryUser} = {'
assert_file_contains "$BASE" 'user = primaryUser;'
assert_file_contains "$BASE" 'folders.home = {'
assert_file_contains "$BASE" 'path = userHome;'

# Failure path: reject invalid usernames and remove hardcoded nixpi homedir wiring.
assert_file_contains "$BASE" 'assertion = builtins.match "^[a-z_][a-z0-9_-]*$" primaryUser != null;'
assert_not_contains "$BASE_CONTENT" 'users.users.nixpi = {'
assert_not_contains "$BASE_CONTENT" '/home/nixpi/.pi/agent'

# Edge case: repo root is standardized to ~/Nixpi and derived from primaryUser.
assert_file_contains "$BASE" 'repoRoot = "${userHome}/Nixpi";'
assert_file_contains "$BASE" 'Config repo: ~/Nixpi'
assert_file_contains "$BASE" 'Rebuild: cd ~/Nixpi && sudo nixos-rebuild switch --flake .'
assert_file_contains "$AGENTS" 'Project root: `~/Nixpi`'
assert_file_contains "$README" 'ssh <username>@<tailscale-ip>'
assert_not_contains "$README_CONTENT" 'ssh nixpi@<tailscale-ip>'

echo "PASS: configurable install user + syncthing home + repo root"

#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/helpers.sh"

BASE="infra/nixos/base.nix"
TTYD="infra/nixos/modules/ttyd.nix"
SYNCTHING="infra/nixos/modules/syncthing.nix"
README="README.md"
AGENTS="AGENTS.md"

BASE_CONTENT="$(<"$BASE")"
README_CONTENT="$(<"$README")"
AGENTS_CONTENT="$(<"$AGENTS")"

# Happy path: installer/user identity is configurable and reused across services.
assert_file_contains "$BASE" 'options.nixpi.primaryUser = lib.mkOption {'
assert_file_contains "$BASE" 'default = "nixpi";'
assert_file_contains "$BASE" 'users.users.${primaryUser} = {'
assert_file_contains "$TTYD" 'user = primaryUser;'
assert_file_contains "$SYNCTHING" 'folders.home = {'
assert_file_contains "$SYNCTHING" 'default = "${userHome}/Shared";'

# Failure path: reject invalid usernames and remove hardcoded nixpi homedir wiring.
assert_file_contains "$BASE" 'assertion = builtins.match "^[a-z_][a-z0-9_-]*$" primaryUser != null;'
assert_not_contains "$BASE_CONTENT" 'path = userHome;'
assert_not_contains "$BASE_CONTENT" 'users.users.nixpi = {'
assert_not_contains "$BASE_CONTENT" '/home/nixpi/.pi/agent'

# Edge case: path model is declarative and derived from config.
assert_file_contains "$BASE" 'options.nixpi.repoRoot = lib.mkOption {'
assert_file_contains "$BASE" 'options.nixpi.piDir = lib.mkOption {'
assert_file_contains "$BASE" 'default = "/home/${config.nixpi.primaryUser}/Nixpi";'
assert_file_contains "$BASE" 'default = "${config.nixpi.repoRoot}/.pi/agent";'
assert_file_contains "$BASE" 'repoRoot = config.nixpi.repoRoot;'
assert_file_contains "$BASE" 'piDir = config.nixpi.piDir;'
assert_file_contains "$BASE" 'Config repo: ${repoRoot}'
assert_file_contains "$BASE" 'Rebuild: cd ${repoRoot} && sudo nixos-rebuild switch --flake .'
assert_file_contains "$AGENTS" 'Project root: `~/Nixpi`'
assert_file_contains "$AGENTS" 'Config directory: `~/Nixpi/.pi/agent/`'
assert_not_contains "$AGENTS_CONTENT" 'Developer mode: `~/Nixpi/.pi/agent-dev/`'
assert_file_contains "$README" 'ssh <username>@<tailscale-ip>'
assert_not_contains "$README_CONTENT" 'ssh nixpi@<tailscale-ip>'

echo "PASS: configurable install user + syncthing home + repo root"

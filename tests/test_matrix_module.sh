#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/helpers.sh"

MODULE="infra/nixos/modules/matrix.nix"
BASE="infra/nixos/base.nix"

# Happy path: module exists.
[ -f "$MODULE" ] || fail "expected matrix module to exist"

# Happy path: module defines enable option.
assert_file_contains "$MODULE" "nixpi.channels.matrix"
assert_file_contains "$MODULE" "mkEnableOption"

# Happy path: module defines allowedUsers option.
assert_file_contains "$MODULE" "allowedUsers"

# Happy path: module uses service factory with correct name.
assert_file_contains "$MODULE" "mkNixpiService"
assert_file_contains "$MODULE" "nixpi-matrix-bridge"

# Happy path: service runs the bridge.
assert_file_contains "$MODULE" "dist/index.js"

# Happy path: service passes allowed users via env.
assert_file_contains "$MODULE" "NIXPI_MATRIX_ALLOWED_USERS"

# Happy path: access token loaded via EnvironmentFile.
assert_file_contains "$MODULE" "accessTokenFile"
assert_file_contains "$MODULE" "EnvironmentFile"

# Happy path: module defines humanUser and botUser options with defaults.
assert_file_contains "$MODULE" "humanUser"
assert_file_contains "$MODULE" "botUser"
assert_file_contains "$MODULE" '"human"'
assert_file_contains "$MODULE" '"nixpi"'

# Happy path: allowedUsers defaults to humanUser on serverName.
assert_file_contains "$MODULE" 'cfg.humanUser'
assert_file_contains "$MODULE" 'cfg.serverName'

# Happy path: module supports Conduit homeserver.
assert_file_contains "$MODULE" "matrix-conduit"

# Happy path: Conduit allowRegistration toggle exists.
assert_file_contains "$MODULE" "allowRegistration"
assert_file_contains "$MODULE" "cfg.conduit.allowRegistration"

# Happy path: base.nix imports the matrix module.
assert_file_contains "$BASE" "matrix.nix"

# Happy path: service restarts on failure.
assert_file_contains "$MODULE" "on-failure"

# Happy path: setup script exists and is executable.
SETUP="scripts/matrix-setup.sh"
[ -f "$SETUP" ] || fail "expected matrix-setup.sh to exist"
[ -x "$SETUP" ] || fail "expected matrix-setup.sh to be executable"
assert_file_contains "$SETUP" "register_user"
assert_file_contains "$SETUP" "NIXPI_MATRIX_ACCESS_TOKEN"

echo "PASS: Matrix NixOS module is properly configured"

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

# Happy path: module supports Conduit homeserver.
assert_file_contains "$MODULE" "matrix-conduit"

# Happy path: base.nix imports the matrix module.
assert_file_contains "$BASE" "matrix.nix"

# Happy path: service restarts on failure.
assert_file_contains "$MODULE" "on-failure"

echo "PASS: Matrix NixOS module is properly configured"

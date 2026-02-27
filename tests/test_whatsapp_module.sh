#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/helpers.sh"

MODULE="infra/nixos/modules/whatsapp.nix"
BASE="infra/nixos/base.nix"

# Happy path: module exists.
[ -f "$MODULE" ] || fail "expected whatsapp module to exist"

# Happy path: module defines enable option.
assert_file_contains "$MODULE" "nixpi.channels.whatsapp"
assert_file_contains "$MODULE" "mkEnableOption"

# Happy path: module defines allowedNumbers option.
assert_file_contains "$MODULE" "allowedNumbers"

# Happy path: module uses service factory with correct name.
assert_file_contains "$MODULE" "mkNixpiService"
assert_file_contains "$MODULE" "nixpi-whatsapp"

# Happy path: service runs the bridge.
assert_file_contains "$MODULE" "dist/index.js"

# Happy path: service passes allowed numbers via env.
assert_file_contains "$MODULE" "NIXPI_WHATSAPP_ALLOWED"

# Happy path: base.nix imports the whatsapp module.
assert_file_contains "$BASE" "whatsapp.nix"

# Happy path: service restarts on failure.
assert_file_contains "$MODULE" "on-failure"

echo "PASS: WhatsApp NixOS module is properly configured"

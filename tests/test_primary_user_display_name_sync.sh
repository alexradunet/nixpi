#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/helpers.sh"

BASE="infra/nixos/base.nix"

# Display name should be synchronized declaratively during activation,
# even when users.mutableUsers is enabled.
assert_file_contains "$BASE" 'system.activationScripts.syncPrimaryUserDisplayName = lib.stringAfter [ "users" ]'
assert_file_contains "$BASE" '${pkgs.glibc.bin}/bin/getent passwd'
assert_file_contains "$BASE" '${pkgs.shadow}/bin/usermod -c'
assert_file_contains "$BASE" 'if [ "$currentGecos" != '

# Edge case: avoid running usermod when user does not exist.
assert_file_contains "$BASE" 'if ${pkgs.glibc.bin}/bin/getent passwd '

echo "PASS: primary user display name is synced declaratively on activation"

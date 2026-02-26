#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/helpers.sh"

BASE="infra/nixos/base.nix"
CONTENT="$(cat "$BASE")"

# Happy path: system locale should be set to an international default.
assert_file_contains "$BASE" 'i18n.defaultLocale = "en_US.UTF-8";'
assert_file_contains "$BASE" 'LC_TIME = "en_US.UTF-8";'
assert_file_contains "$BASE" 'LC_MONETARY = "en_US.UTF-8";'

# Failure path: Romanian locale overrides should no longer be present.
assert_not_contains "$CONTENT" 'ro_RO.UTF-8'

# Edge case: keep less-common categories aligned to avoid mixed locale behavior.
assert_file_contains "$BASE" 'LC_IDENTIFICATION = "en_US.UTF-8";'
assert_file_contains "$BASE" 'LC_TELEPHONE = "en_US.UTF-8";'

echo "PASS: international locale defaults"

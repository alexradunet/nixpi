#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/helpers.sh"

BASE="infra/nixos/base.nix"
README="README.md"
BASE_CONTENT="$(<"$BASE")"

# Happy path: display name is configurable.
assert_file_contains "$BASE" 'options.nixpi.primaryUserDisplayName = lib.mkOption {'
assert_file_contains "$BASE" 'default = config.nixpi.primaryUser;'
assert_file_contains "$BASE" 'userDisplayName = config.nixpi.primaryUserDisplayName;'
assert_file_contains "$BASE" 'description = userDisplayName;'

# Failure path: avoid hardcoded display name that mismatches actual username.
assert_not_contains "$BASE_CONTENT" 'description = "Nixpi";'

# Edge case: host-level override is documented.
assert_file_contains "$README" 'nixpi.primaryUserDisplayName = "Alex";'

echo "PASS: primary user display name follows config and supports override"

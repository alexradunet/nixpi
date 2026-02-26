#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/helpers.sh"

BASE="infra/nixos/base.nix"
CONTENT="$(<"$BASE")"

# Happy path: system locale should be set to an international default.
assert_file_contains "$BASE" 'i18n.defaultLocale = "en_US.UTF-8";'

# Timezone is now a configurable option, not hardcoded.
assert_file_contains "$BASE" 'options.nixpi.timeZone = lib.mkOption {'
assert_file_contains "$BASE" 'time.timeZone = config.nixpi.timeZone;'
assert_not_contains "$CONTENT" 'time.timeZone = "Europe/Bucharest";'

# Failure path: Romanian locale overrides should no longer be present.
assert_not_contains "$CONTENT" 'ro_RO.UTF-8'

# Edge case: extraLocaleSettings is redundant when all categories match defaultLocale.
assert_not_contains "$CONTENT" 'extraLocaleSettings'

echo "PASS: international locale defaults"

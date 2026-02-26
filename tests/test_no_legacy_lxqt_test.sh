#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/helpers.sh"

LEGACY_TEST="tests/test_desktop_lxqt_setup.sh"

[ ! -f "$LEGACY_TEST" ] || fail "legacy LXQt regression test should be removed: $LEGACY_TEST"

echo "PASS: legacy LXQt test removed"

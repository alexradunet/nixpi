#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/helpers.sh"

CHECK_SCRIPT="scripts/check.sh"

# Happy path: strict mode supports optional no-link system build validation.
assert_file_contains "$CHECK_SCRIPT" 'if [ "${NIXPI_CHECK_BUILD:-0}" = "1" ]; then'
assert_file_contains "$CHECK_SCRIPT" 'build_host="${NIXPI_CHECK_HOST:-$(hostname)}"'
assert_file_contains "$CHECK_SCRIPT" 'nix build ".#nixosConfigurations.${build_host}.config.system.build.toplevel" --no-link'

# Failure-path guard: baseline no-build flake validation remains present.
assert_file_contains "$CHECK_SCRIPT" 'nix flake check --no-build'

echo "PASS: check script supports optional strict build mode"

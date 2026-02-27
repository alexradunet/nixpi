#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/helpers.sh"

MODULE="infra/nixos/modules/heartbeat.nix"
BASE="infra/nixos/base.nix"

# Happy path: heartbeat module exists.
[ -f "$MODULE" ] || fail "expected heartbeat module to exist"

# Happy path: module defines enable option.
assert_file_contains "$MODULE" "nixpi.heartbeat"
assert_file_contains "$MODULE" "mkEnableOption"

# Happy path: module defines interval option.
assert_file_contains "$MODULE" "intervalMinutes"

# Happy path: module uses service factory and defines timer.
assert_file_contains "$MODULE" "mkNixpiService"
assert_file_contains "$MODULE" "systemd.timers"
assert_file_contains "$MODULE" "nixpi-heartbeat"

# Happy path: service runs pi in non-interactive mode.
assert_file_contains "$MODULE" "pi"

# Happy path: base.nix imports the heartbeat module.
assert_file_contains "$BASE" "heartbeat.nix"

# Happy path: heartbeat skill exists.
[ -f "infra/pi/skills/heartbeat/SKILL.md" ] || fail "expected heartbeat skill to exist"

echo "PASS: heartbeat NixOS module and skill are properly configured"

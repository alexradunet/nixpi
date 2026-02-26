#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/helpers.sh"

BASE="infra/nixos/base.nix"
README="README.md"
BASE_CONTENT="$(cat "$BASE")"

# Happy path: LXDE desktop stack is enabled for local HDMI setup.
assert_file_contains "$BASE" 'services.xserver.enable = true;'
assert_file_contains "$BASE" 'services.xserver.displayManager.lightdm.enable = true;'
assert_file_contains "$BASE" 'services.xserver.desktopManager.lxde.enable = true;'

# Failure path: desktop enablement must not re-introduce RDP exposure.
assert_not_contains "$BASE_CONTENT" 'services.xrdp'
assert_not_contains "$BASE_CONTENT" 'tcp dport 3389'

# Edge case: include desktop helpers needed for display + Wi-Fi setup.
assert_file_contains "$BASE" 'networkmanagerapplet'
assert_file_contains "$BASE" 'xorg.xrandr'

# Docs regression: README reflects LXDE local desktop availability.
assert_file_contains "$README" '| **LXDE Desktop** |'
assert_file_contains "$README" 'local HDMI monitor'

echo "PASS: lxde desktop + wifi/display helper packages"

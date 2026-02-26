#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/helpers.sh"

BASE="infra/nixos/base.nix"
README="README.md"
BASE_CONTENT="$(cat "$BASE")"
README_CONTENT="$(cat "$README")"

# Happy path: lightweight desktop stack is enabled for local HDMI setup.
assert_file_contains "$BASE" 'services.xserver.enable = true;'
assert_file_contains "$BASE" 'services.xserver.displayManager.lightdm.enable = true;'
assert_file_contains "$BASE" 'services.xserver.desktopManager.lxqt.enable = true;'
assert_file_contains "$BASE" 'programs.chromium.enable = true;'
assert_file_contains "$BASE" 'vscode'
assert_file_contains "$BASE" 'nano'

# Failure path: desktop enablement must not re-introduce RDP exposure or legacy editor/package choices.
assert_not_contains "$BASE_CONTENT" 'services.xrdp'
assert_not_contains "$BASE_CONTENT" 'tcp dport 3389'
assert_not_contains "$BASE_CONTENT" 'vscodium'

# Edge case: include desktop helpers needed for display + Wi-Fi setup.
assert_file_contains "$BASE" 'networkmanagerapplet'
assert_file_contains "$BASE" 'xorg.xrandr'

# Docs regression: README reflects LXQt local desktop availability and local GUI tools.
assert_file_contains "$README" '| **LXQt Desktop** |'
assert_file_contains "$README" '| **VS Code** |'
assert_file_contains "$README" '| **Simple Text Editor** |'
assert_file_contains "$README" 'local HDMI monitor'

# Edge-case regression: avoid removed LXDE option/label in config and docs.
assert_not_contains "$BASE_CONTENT" 'desktopManager.lxde'
assert_not_contains "$README_CONTENT" 'LXDE'

echo "PASS: lxqt desktop + wifi/display helper packages"

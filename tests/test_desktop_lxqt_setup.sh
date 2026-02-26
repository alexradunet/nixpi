#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/helpers.sh"

BASE="infra/nixos/base.nix"
README="README.md"
BASE_CONTENT="$(cat "$BASE")"
README_CONTENT="$(cat "$README")"

# Happy path: lightweight desktop stack is enabled by default for local HDMI setup.
assert_file_contains "$BASE" 'options.nixpi.desktopProfile = lib.mkOption {'
assert_file_contains "$BASE" 'default = "lxqt";'
assert_file_contains "$BASE" 'services.xserver.enable = true;'
assert_file_contains "$BASE" 'services.xserver.displayManager.lightdm.enable = config.nixpi.desktopProfile == "lxqt";'
assert_file_contains "$BASE" 'services.xserver.desktopManager.lxqt.enable = config.nixpi.desktopProfile == "lxqt";'
assert_file_contains "$BASE" 'programs.chromium.enable = true;'
assert_file_contains "$BASE" 'vscode'
assert_file_contains "$BASE" 'nano'

# Failure path: desktop enablement must not re-introduce RDP exposure or force legacy package choices.
assert_not_contains "$BASE_CONTENT" 'services.xrdp'
assert_not_contains "$BASE_CONTENT" 'tcp dport 3389'
assert_not_contains "$BASE_CONTENT" 'vscodium'
assert_not_contains "$BASE_CONTENT" 'services.xserver.displayManager.lightdm.enable = true;'
assert_not_contains "$BASE_CONTENT" 'services.xserver.desktopManager.lxqt.enable = true;'

# Edge case: include desktop helpers needed for display + Wi-Fi setup.
assert_file_contains "$BASE" 'networkmanagerapplet'
assert_file_contains "$BASE" 'xorg.xrandr'

# Docs regression: README reflects LXQt default + reuse-existing-desktop behavior and local GUI tools.
assert_file_contains "$README" '| **LXQt Desktop (default)** |'
assert_file_contains "$README" '| **Desktop reuse mode** |'
assert_file_contains "$README" '| **VS Code** |'
assert_file_contains "$README" '| **Simple Text Editor** |'
assert_file_contains "$README" 'local HDMI monitor'

# Edge-case regression: avoid removed LXDE option/label in config and docs.
assert_not_contains "$BASE_CONTENT" 'desktopManager.lxde'
assert_not_contains "$README_CONTENT" 'LXDE'

echo "PASS: lxqt desktop + wifi/display helper packages"

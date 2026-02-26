#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/helpers.sh"

BASE="infra/nixos/base.nix"
README="README.md"
BASE_CONTENT="$(cat "$BASE")"
README_CONTENT="$(cat "$README")"

# Happy path: default desktop stack should mirror a standard NixOS GNOME install.
assert_file_contains "$BASE" 'options.nixpi.desktopProfile = lib.mkOption {'
assert_file_contains "$BASE" 'default = "gnome";'
assert_file_contains "$BASE" 'services.xserver.enable = true;'
assert_file_contains "$BASE" 'services.xserver.displayManager.gdm.enable = config.nixpi.desktopProfile == "gnome";'
assert_file_contains "$BASE" 'services.xserver.desktopManager.gnome.enable = config.nixpi.desktopProfile == "gnome";'
assert_file_contains "$BASE" 'programs.chromium.enable = true;'
assert_file_contains "$BASE" 'vscode'
assert_file_contains "$BASE" 'nano'

# Failure path: do not keep legacy LXQt/LightDM defaults.
assert_not_contains "$BASE_CONTENT" 'services.xserver.displayManager.lightdm.enable = config.nixpi.desktopProfile == "lxqt";'
assert_not_contains "$BASE_CONTENT" 'services.xserver.desktopManager.lxqt.enable = config.nixpi.desktopProfile == "lxqt";'
assert_not_contains "$BASE_CONTENT" 'default = "lxqt";'

# Edge case: include desktop helpers needed for display + Wi-Fi setup.
assert_file_contains "$BASE" 'networkmanagerapplet'
assert_file_contains "$BASE" 'xorg.xrandr'

# Docs regression: README reflects GNOME default + preserve-existing-desktop behavior.
assert_file_contains "$README" '| **GNOME Desktop (default)** |'
assert_file_contains "$README" '| **Desktop reuse mode** |'
assert_file_contains "$README" '| **VS Code** |'
assert_file_contains "$README" '| **Simple Text Editor** |'
assert_file_contains "$README" 'local HDMI monitor'

# Edge-case regression: avoid removed LXQt label in docs.
assert_not_contains "$README_CONTENT" 'LXQt Desktop (default)'

echo "PASS: gnome desktop default + wifi/display helper packages"
#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/helpers.sh"

FLAKE="flake.nix"
BASE="infra/nixos/base.nix"
TTYD="infra/nixos/modules/ttyd.nix"
SYNCTHING="infra/nixos/modules/syncthing.nix"
README="README.md"
FLAKE_CONTENT="$(<"$FLAKE")"
BASE_CONTENT="$(<"$BASE")"
TTYD_CONTENT="$(<"$TTYD")"
SYNCTHING_CONTENT="$(<"$SYNCTHING")"
README_CONTENT="$(<"$README")"

# Happy path: ttyd web terminal is enabled and proxies to localhost SSH.
assert_file_contains "$TTYD" 'services.ttyd = {'
assert_file_contains "$TTYD" 'enable = true;'
assert_file_contains "$TTYD" 'writeable = true;'
assert_file_contains "$TTYD" 'checkOrigin = true;'
assert_file_contains "$TTYD" 'entrypoint = ['
assert_file_contains "$TTYD" '"${lib.getExe'"'"' pkgs.openssh "ssh"}"'
assert_file_contains "$TTYD" '"${primaryUser}@127.0.0.1"'

# Failure path: OliveTin/Cockpit/desktop-RDP paths are removed.
assert_not_contains "$BASE_CONTENT" 'services.olivetin'
assert_not_contains "$BASE_CONTENT" 'services.cockpit'
assert_not_contains "$BASE_CONTENT" 'tcp dport 1337'
assert_not_contains "$BASE_CONTENT" 'tcp dport 9090'
assert_not_contains "$FLAKE_CONTENT" 'desktopHosts'
assert_not_contains "$FLAKE_CONTENT" './infra/nixos/desktop.nix'
assert_not_contains "$BASE_CONTENT" 'services.xrdp'
assert_not_contains "$BASE_CONTENT" 'tcp dport 3389'

# Edge-case regression: ttyd must be Tailscale-only (no LAN) via mkTailscaleFirewallRules.
assert_file_contains "$TTYD" 'mkTailscaleFirewallRules'
assert_file_contains "$TTYD" 'port = cfg.port;'
assert_file_contains "$TTYD" 'default = 7681;'
assert_not_contains "$TTYD_CONTENT" '192.168.0.0/16'
assert_not_contains "$TTYD_CONTENT" '10.0.0.0/8'
assert_not_contains "$TTYD_CONTENT" '100.0.0.0/8'

# Syncthing UI/sync should also be Tailscale-only via mkTailscaleFirewallRules.
assert_file_contains "$SYNCTHING" 'mkTailscaleFirewallRules'
assert_file_contains "$SYNCTHING" 'port = 8384;'
assert_file_contains "$SYNCTHING" 'port = 22000;'
assert_not_contains "$SYNCTHING_CONTENT" 'ip saddr 192.168.0.0/16 tcp dport 8384 accept'
assert_not_contains "$SYNCTHING_CONTENT" 'ip saddr 10.0.0.0/8 tcp dport 8384 accept'
assert_not_contains "$SYNCTHING_CONTENT" '100.0.0.0/8'

# SSH keeps LAN + Tailscale bootstrap path.
assert_file_contains "$BASE" 'ip saddr 192.168.0.0/16 tcp dport 22 accept'
assert_file_contains "$BASE" 'ip saddr 10.0.0.0/8 tcp dport 22 accept'

# Docs regression: README reflects access-scope split.
assert_file_contains "$README" 'ttyd'
assert_file_contains "$README" 'SSH remains available from local network and Tailscale'
assert_file_contains "$README" 'Tailscale-only'
assert_not_contains "$README_CONTENT" 'OliveTin'
assert_not_contains "$README_CONTENT" 'Cockpit'

echo "PASS: ttyd + tailscale-only web services + ssh lan bootstrap"

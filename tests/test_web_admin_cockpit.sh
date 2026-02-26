#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/helpers.sh"

FLAKE="flake.nix"
BASE="infra/nixos/base.nix"
FLAKE_CONTENT="$(cat "$FLAKE")"
BASE_CONTENT="$(cat "$BASE")"

# Happy path: Cockpit web admin is enabled declaratively.
assert_file_contains "$BASE" 'services.cockpit = {'
assert_file_contains "$BASE" 'enable = true;'
assert_file_contains "$BASE" 'openFirewall = false;'

# Happy path (remote UX): allow expected local/Tailscale origins for browser websocket auth.
assert_file_contains "$BASE" 'services.cockpit.allowed-origins = ['
assert_file_contains "$BASE" '"https://${config.networking.hostName}:${toString config.services.cockpit.port}"'
assert_file_contains "$BASE" '"https://*.ts.net:${toString config.services.cockpit.port}"'
assert_file_contains "$BASE" '"https://127.0.0.1:${toString config.services.cockpit.port}"'
assert_file_contains "$BASE" '"http://127.0.0.1:${toString config.services.cockpit.port}"'

# Failure path: desktop/RDP module wiring should be removed from flake.
assert_not_contains "$FLAKE_CONTENT" 'desktopHosts'
assert_not_contains "$FLAKE_CONTENT" './infra/nixos/desktop.nix'
assert_not_contains "$BASE_CONTENT" 'services.xrdp'
assert_not_contains "$BASE_CONTENT" 'tcp dport 3389'

# Edge-case regression: Cockpit access is restricted to Tailscale + LAN only.
assert_file_contains "$BASE" 'ip saddr 100.0.0.0/8 tcp dport 9090 accept'
assert_file_contains "$BASE" 'ip6 saddr fd7a:115c:a1e0::/48 tcp dport 9090 accept'
assert_file_contains "$BASE" 'ip saddr 192.168.0.0/16 tcp dport 9090 accept'
assert_file_contains "$BASE" 'ip saddr 10.0.0.0/8 tcp dport 9090 accept'
assert_file_contains "$BASE" 'tcp dport 9090 drop'

echo "PASS: cockpit web admin + no desktop rdp path"

#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/helpers.sh"

FLAKE="flake.nix"
BASE="infra/nixos/base.nix"
README="README.md"
FLAKE_CONTENT="$(cat "$FLAKE")"
BASE_CONTENT="$(cat "$BASE")"
README_CONTENT="$(cat "$README")"

# Happy path: ttyd web terminal is enabled and proxies to localhost SSH.
assert_file_contains "$BASE" 'services.ttyd = {'
assert_file_contains "$BASE" 'enable = true;'
assert_file_contains "$BASE" 'writeable = true;'
assert_file_contains "$BASE" 'checkOrigin = true;'
assert_file_contains "$BASE" 'entrypoint = ['
assert_file_contains "$BASE" '"${pkgs.openssh}/bin/ssh"'
assert_file_contains "$BASE" '"${primaryUser}@127.0.0.1"'

# Failure path: OliveTin/Cockpit/desktop-RDP paths are removed.
assert_not_contains "$BASE_CONTENT" 'services.olivetin'
assert_not_contains "$BASE_CONTENT" 'services.cockpit'
assert_not_contains "$BASE_CONTENT" 'tcp dport 1337'
assert_not_contains "$BASE_CONTENT" 'tcp dport 9090'
assert_not_contains "$FLAKE_CONTENT" 'desktopHosts'
assert_not_contains "$FLAKE_CONTENT" './infra/nixos/desktop.nix'
assert_not_contains "$BASE_CONTENT" 'services.xrdp'
assert_not_contains "$BASE_CONTENT" 'tcp dport 3389'

# Edge-case regression: ttyd access is restricted to Tailscale + LAN only.
assert_file_contains "$BASE" 'ip saddr 100.0.0.0/8 tcp dport 7681 accept'
assert_file_contains "$BASE" 'ip6 saddr fd7a:115c:a1e0::/48 tcp dport 7681 accept'
assert_file_contains "$BASE" 'ip saddr 192.168.0.0/16 tcp dport 7681 accept'
assert_file_contains "$BASE" 'ip saddr 10.0.0.0/8 tcp dport 7681 accept'
assert_file_contains "$BASE" 'tcp dport 7681 drop'

# Docs regression: README reflects ttyd instead of OliveTin/Cockpit.
assert_file_contains "$README" 'ttyd'
assert_not_contains "$README_CONTENT" 'OliveTin'
assert_not_contains "$README_CONTENT" 'Cockpit'

echo "PASS: ttyd web terminal + no cockpit/olivetin/desktop/rdp path"

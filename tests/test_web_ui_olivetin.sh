#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/helpers.sh"

FLAKE="flake.nix"
BASE="infra/nixos/base.nix"
README="README.md"
FLAKE_CONTENT="$(cat "$FLAKE")"
BASE_CONTENT="$(cat "$BASE")"

# Happy path: OliveTin web UI is enabled declaratively with explicit listen address.
assert_file_contains "$BASE" 'services.olivetin = {'
assert_file_contains "$BASE" 'enable = true;'
assert_file_contains "$BASE" 'ListenAddressSingleHTTPFrontend = "0.0.0.0:1337";'
assert_file_contains "$BASE" 'id = "nixpi_health_summary";'

# Failure path: Cockpit and desktop/RDP paths are removed.
assert_not_contains "$BASE_CONTENT" 'services.cockpit'
assert_not_contains "$BASE_CONTENT" 'tcp dport 9090'
assert_not_contains "$FLAKE_CONTENT" 'desktopHosts'
assert_not_contains "$FLAKE_CONTENT" './infra/nixos/desktop.nix'
assert_not_contains "$BASE_CONTENT" 'services.xrdp'
assert_not_contains "$BASE_CONTENT" 'tcp dport 3389'

# Edge-case regression: OliveTin access is restricted to Tailscale + LAN only.
assert_file_contains "$BASE" 'ip saddr 100.0.0.0/8 tcp dport 1337 accept'
assert_file_contains "$BASE" 'ip6 saddr fd7a:115c:a1e0::/48 tcp dport 1337 accept'
assert_file_contains "$BASE" 'ip saddr 192.168.0.0/16 tcp dport 1337 accept'
assert_file_contains "$BASE" 'ip saddr 10.0.0.0/8 tcp dport 1337 accept'
assert_file_contains "$BASE" 'tcp dport 1337 drop'

# Docs regression: README reflects OliveTin instead of Cockpit.
assert_file_contains "$README" 'OliveTin'
assert_not_contains "$(cat "$README")" 'Cockpit'

echo "PASS: olivetin web ui + no cockpit/desktop/rdp path"

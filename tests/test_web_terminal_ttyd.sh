#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/helpers.sh"

FLAKE="flake.nix"
BASE="infra/nixos/base.nix"
README="README.md"
FLAKE_CONTENT="$(<"$FLAKE")"
BASE_CONTENT="$(<"$BASE")"
README_CONTENT="$(<"$README")"

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

# Edge-case regression: ttyd must be Tailscale-only (no LAN) while SSH keeps LAN bootstrap.
assert_file_contains "$BASE" 'ip saddr 100.0.0.0/8 tcp dport 7681 accept'
assert_file_contains "$BASE" 'ip6 saddr fd7a:115c:a1e0::/48 tcp dport 7681 accept'
assert_not_contains "$BASE_CONTENT" 'ip saddr 192.168.0.0/16 tcp dport 7681 accept'
assert_not_contains "$BASE_CONTENT" 'ip saddr 10.0.0.0/8 tcp dport 7681 accept'
assert_file_contains "$BASE" 'tcp dport 7681 drop'

# Syncthing UI/sync should also be Tailscale-only.
assert_file_contains "$BASE" 'ip saddr 100.0.0.0/8 tcp dport 8384 accept'
assert_file_contains "$BASE" 'ip6 saddr fd7a:115c:a1e0::/48 tcp dport 8384 accept'
assert_not_contains "$BASE_CONTENT" 'ip saddr 192.168.0.0/16 tcp dport 8384 accept'
assert_not_contains "$BASE_CONTENT" 'ip saddr 10.0.0.0/8 tcp dport 8384 accept'

assert_file_contains "$BASE" 'ip saddr 100.0.0.0/8 tcp dport 22000 accept'
assert_file_contains "$BASE" 'ip saddr 100.0.0.0/8 udp dport 22000 accept'
assert_file_contains "$BASE" 'ip6 saddr fd7a:115c:a1e0::/48 tcp dport 22000 accept'
assert_file_contains "$BASE" 'ip6 saddr fd7a:115c:a1e0::/48 udp dport 22000 accept'
assert_not_contains "$BASE_CONTENT" 'ip saddr 192.168.0.0/16 tcp dport 22000 accept'
assert_not_contains "$BASE_CONTENT" 'ip saddr 192.168.0.0/16 udp dport 22000 accept'
assert_not_contains "$BASE_CONTENT" 'ip saddr 10.0.0.0/8 tcp dport 22000 accept'
assert_not_contains "$BASE_CONTENT" 'ip saddr 10.0.0.0/8 udp dport 22000 accept'

# SSH keeps LAN + Tailscale bootstrap path.
assert_file_contains "$BASE" 'ip saddr 192.168.0.0/16 tcp dport 22 accept'
assert_file_contains "$BASE" 'ip saddr 10.0.0.0/8 tcp dport 22 accept'

# Docs regression: README reflects access-scope split.
assert_file_contains "$README" 'ttyd'
assert_file_contains "$README" 'SSH remains available from local network and Tailscale'
assert_file_contains "$README" 'ttyd and Syncthing are Tailscale-only'
assert_not_contains "$README_CONTENT" 'OliveTin'
assert_not_contains "$README_CONTENT" 'Cockpit'

echo "PASS: ttyd + tailscale-only web services + ssh lan bootstrap"

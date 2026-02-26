#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/helpers.sh"

BASE="infra/nixos/base.nix"
CONTENT="$(cat "$BASE")"

# Happy path: OpenSSH password login must stay enabled.
assert_file_contains "$BASE" 'PasswordAuthentication = true;'
assert_file_contains "$BASE" 'KbdInteractiveAuthentication = true;'

# Failure path: disable Tailscale SSH to keep one SSH access path.
assert_file_contains "$BASE" 'extraSetFlags = [ "--ssh=false" ];'
assert_not_contains "$CONTENT" 'extraSetFlags = [ "--ssh" ];'

# Edge-case regression: SSH should still be reachable over Tailscale IPv6.
assert_file_contains "$BASE" 'ip6 saddr fd7a:115c:a1e0::/48 tcp dport 22 accept'

# Guardrail regression: keep root login disabled.
assert_file_contains "$BASE" 'PermitRootLogin = "no";'

echo "PASS: ssh password auth + tailscale ssh disabled"

#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/helpers.sh"

BASE="infra/nixos/base.nix"

# Bug reproduction: remote access should support Tailscale SSH plus password auth.
assert_file_contains "$BASE" 'extraSetFlags = [ "--ssh" ];'
assert_file_contains "$BASE" 'PasswordAuthentication = true;'
assert_file_contains "$BASE" 'KbdInteractiveAuthentication = true;'

# Edge-case regression: SSH should also be reachable over Tailscale IPv6.
assert_file_contains "$BASE" 'ip6 saddr fd7a:115c:a1e0::/48 tcp dport 22 accept'

# Guardrail regression: keep root login disabled.
assert_file_contains "$BASE" 'PermitRootLogin = "no";'

echo "PASS: tailscale ssh + password auth config"

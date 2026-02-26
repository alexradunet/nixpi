#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/helpers.sh"

BASE="infra/nixos/base.nix"

# Happy path: explicit password policy checker exists.
assert_file_contains "$BASE" 'passwordPolicyCheck = pkgs.writeShellScript "nixpi-password-policy-check"'
assert_file_contains "$BASE" 'Password must be at least 16 characters.'
assert_file_contains "$BASE" 'Password must include at least one number.'
assert_file_contains "$BASE" 'Password must include at least one special character.'

# Failure path: policy is enforced by PAM for both passwd and chpasswd.
assert_file_contains "$BASE" 'security.pam.services.passwd.rules.password.passwordPolicy = {'
assert_file_contains "$BASE" 'security.pam.services.chpasswd.rules.password.passwordPolicy = {'
assert_file_contains "$BASE" 'control = "requisite";'
assert_file_contains "$BASE" 'pam_exec.so';
assert_file_contains "$BASE" '"expose_authtok"'

# Edge case: require both numeric and punctuation classes.
assert_file_contains "$BASE" '(*[0-9]*)'
assert_file_contains "$BASE" '(*[[:punct:]]*)'

echo "PASS: password complexity policy"

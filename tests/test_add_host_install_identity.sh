#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/helpers.sh"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

mkdir -p "$TMP_DIR/scripts" "$TMP_DIR/infra/nixos/hosts" "$TMP_DIR/bin"
cp scripts/add-host.sh "$TMP_DIR/scripts/add-host.sh"
chmod +x "$TMP_DIR/scripts/add-host.sh"

cat > "$TMP_DIR/bin/nixos-generate-config" <<'EOF'
#!/usr/bin/env bash
cat <<'CFG'
{ lib, modulesPath, ... }:
{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];
}
CFG
EOF
chmod +x "$TMP_DIR/bin/nixos-generate-config"

cat > "$TMP_DIR/bin/nixos-option" <<'EOF'
#!/usr/bin/env bash
cat <<'OUT'
Value:
  false
OUT
EOF
chmod +x "$TMP_DIR/bin/nixos-option"

# Happy path: generated host binds Nixpi to the invoking installer user.
PATH="$TMP_DIR/bin:$PATH" SUDO_USER="alex" USER="root" LOGNAME="root" \
  "$TMP_DIR/scripts/add-host.sh" install-host >/dev/null
HOST_FILE="$TMP_DIR/infra/nixos/hosts/install-host.nix"
HOST_CONTENT="$(<"$HOST_FILE")"
assert_contains "$HOST_CONTENT" 'nixpi.primaryUser = "alex";'
assert_contains "$HOST_CONTENT" 'nixpi.repoRoot = "/home/alex/Nixpi";'

# Failure path: existing host should fail without --force.
set +e
exists_output="$(PATH="$TMP_DIR/bin:$PATH" SUDO_USER="alex" USER="root" LOGNAME="root" "$TMP_DIR/scripts/add-host.sh" install-host 2>&1)"
exists_code=$?
set -e
[ $exists_code -ne 0 ] || fail "expected non-zero for existing host without --force"
assert_contains "$exists_output" 'already exists'

# Edge case: --force should regenerate host and keep installer-user mapping.
force_output="$(PATH="$TMP_DIR/bin:$PATH" SUDO_USER="alex" USER="root" LOGNAME="root" "$TMP_DIR/scripts/add-host.sh" --force install-host)"
FORCED_CONTENT="$(<"$HOST_FILE")"
assert_contains "$force_output" 'Overwriting existing host file'
assert_contains "$FORCED_CONTENT" 'nixpi.primaryUser = "alex";'
assert_contains "$FORCED_CONTENT" 'nixpi.repoRoot = "/home/alex/Nixpi";'

# Edge case: unknown options are rejected.
set +e
unknown_output="$(PATH="$TMP_DIR/bin:$PATH" "$TMP_DIR/scripts/add-host.sh" --bogus 2>&1)"
unknown_code=$?
set -e
[ $unknown_code -ne 0 ] || fail "expected non-zero for unknown option"
assert_contains "$unknown_output" 'error: unknown option'

echo "PASS: add-host installer identity + force regenerate"
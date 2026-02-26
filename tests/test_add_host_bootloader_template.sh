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

# Happy path: generated host file should include UEFI defaults + commented BIOS fallback.
happy_output="$(PATH="$TMP_DIR/bin:$PATH" "$TMP_DIR/scripts/add-host.sh" demo-host)"
HOST_FILE="$TMP_DIR/infra/nixos/hosts/demo-host.nix"
[ -f "$HOST_FILE" ] || fail "expected generated host file"
HOST_CONTENT="$(cat "$HOST_FILE")"
assert_contains "$HOST_CONTENT" 'boot.loader.systemd-boot.enable = true;'
assert_contains "$HOST_CONTENT" 'boot.loader.efi.canTouchEfiVariables = true;'
assert_contains "$HOST_CONTENT" '# boot.loader.grub.enable = true;'
assert_contains "$HOST_CONTENT" '# boot.loader.grub.devices = [ "/dev/sda" ];'
assert_contains "$HOST_CONTENT" 'networking.hostName = "demo-host";'
assert_contains "$happy_output" 'nixos-rebuild switch --flake "path:'
assert_contains "$happy_output" '#demo-host"'

# Failure path: invalid hostname must fail clearly.
set +e
invalid_output="$(PATH="$TMP_DIR/bin:$PATH" "$TMP_DIR/scripts/add-host.sh" '-bad-host' 2>&1)"
invalid_code=$?
set -e
[ $invalid_code -ne 0 ] || fail "expected non-zero for invalid hostname"
assert_contains "$invalid_output" 'invalid hostname'

# Edge case: do not duplicate bootloader defaults when already present.
cat > "$TMP_DIR/bin/nixos-generate-config" <<'EOF'
#!/usr/bin/env bash
cat <<'CFG'
{ lib, modulesPath, ... }:
{
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
}
CFG
EOF
chmod +x "$TMP_DIR/bin/nixos-generate-config"

PATH="$TMP_DIR/bin:$PATH" "$TMP_DIR/scripts/add-host.sh" preset-host >/dev/null
PRESET_FILE="$TMP_DIR/infra/nixos/hosts/preset-host.nix"
PRESET_CONTENT="$(cat "$PRESET_FILE")"

count_systemd_boot="$(printf '%s' "$PRESET_CONTENT" | grep -Fc 'boot.loader.systemd-boot.enable = true;')"
[ "$count_systemd_boot" -eq 1 ] || fail "expected exactly one systemd-boot setting"

echo "PASS: add-host bootloader template defaults"

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
case "$1" in
  services.displayManager.gdm.enable|services.desktopManager.gnome.enable)
    cat <<'OUT'
Value:
  true
OUT
    ;;
  *)
    cat <<'OUT'
Value:
  false
OUT
    ;;
esac
EOF
chmod +x "$TMP_DIR/bin/nixos-option"

# Happy path: preserve existing desktop options when detected (canonical GNOME options).
PATH="$TMP_DIR/bin:$PATH" "$TMP_DIR/scripts/add-host.sh" reuse-host >/dev/null
HOST_FILE="$TMP_DIR/infra/nixos/hosts/reuse-host.nix"
HOST_CONTENT="$(<"$HOST_FILE")"
assert_contains "$HOST_CONTENT" 'nixpi.desktopProfile = "preserve";'
assert_contains "$HOST_CONTENT" 'services.displayManager.gdm.enable = true;'
assert_contains "$HOST_CONTENT" 'services.desktopManager.gnome.enable = true;'

# Failure path: if desktop detection fails, generation still succeeds without preserve profile.
cat > "$TMP_DIR/bin/nixos-option" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
chmod +x "$TMP_DIR/bin/nixos-option"

PATH="$TMP_DIR/bin:$PATH" "$TMP_DIR/scripts/add-host.sh" fallback-host >/dev/null
FALLBACK_CONTENT="$(<"$TMP_DIR/infra/nixos/hosts/fallback-host.nix")"
assert_not_contains "$FALLBACK_CONTENT" 'nixpi.desktopProfile = "preserve";'

# Edge case: detected desktop options should not be duplicated.
count_gdm="$(printf '%s' "$HOST_CONTENT" | grep -Fc 'services.displayManager.gdm.enable = true;')"
count_gnome="$(printf '%s' "$HOST_CONTENT" | grep -Fc 'services.desktopManager.gnome.enable = true;')"
[ "$count_gdm" -eq 1 ] || fail "expected gdm preserve option once"
[ "$count_gnome" -eq 1 ] || fail "expected gnome preserve option once"

echo "PASS: add-host desktop reuse detection"
#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOSTS_DIR="$REPO_ROOT/infra/nixos/hosts"

HOSTNAME="${1:-$(hostname)}"

# Validate hostname (RFC 952: alphanumeric and hyphens only)
if [[ ! "$HOSTNAME" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?$ ]]; then
  echo "error: invalid hostname '$HOSTNAME' (must be alphanumeric/hyphens, no leading/trailing hyphen)" >&2
  exit 1
fi

HOST_FILE="$HOSTS_DIR/$HOSTNAME.nix"

if [ -f "$HOST_FILE" ]; then
  echo "error: $HOST_FILE already exists" >&2
  exit 1
fi

append_block_before_final_brace() {
  local content="$1"
  local block="$2"

  if [[ "$content" == *$'\n}' ]]; then
    printf '%s' "${content%$'\n}'}"$'\n'"$block"$'\n}'
  else
    printf '%s\n%s\n' "$content" "$block"
  fi
}

nixos_option_true() {
  local option="$1"
  local value

  if ! command -v nixos-option >/dev/null 2>&1; then
    return 1
  fi

  value="$(nixos-option "$option" 2>/dev/null | awk '
    /^Value:/ { capture=1; next }
    capture {
      gsub(/[[:space:]]/, "", $0)
      if ($0 == "") next
      print $0
      exit
    }
  ' || true)"

  [ "$value" = "true" ]
}

detect_desktop_options() {
  local options=(
    "services.xserver.displayManager.gdm.enable"
    "services.xserver.displayManager.sddm.enable"
    "services.xserver.displayManager.lightdm.enable"
    "services.xserver.desktopManager.gnome.enable"
    "services.desktopManager.plasma6.enable"
    "services.xserver.desktopManager.xfce.enable"
    "services.xserver.desktopManager.lxqt.enable"
    "services.xserver.desktopManager.cinnamon.enable"
    "services.xserver.desktopManager.mate.enable"
  )

  local option
  for option in "${options[@]}"; do
    if nixos_option_true "$option"; then
      printf '%s\n' "$option"
    fi
  done
}

echo "Generating hardware config for '$HOSTNAME'..."
HW_CONFIG="$(nixos-generate-config --show-hardware-config 2>/dev/null)"

# Append networking.hostName if not already present
if ! echo "$HW_CONFIG" | grep -q 'networking.hostName'; then
  HW_CONFIG="$(append_block_before_final_brace "$HW_CONFIG" "  networking.hostName = \"$HOSTNAME\";")"
fi

# Add bootloader defaults only when not already declared by the generated config.
# UEFI is enabled by default; BIOS/GRUB remains as commented fallback.
if ! echo "$HW_CONFIG" | grep -q 'boot.loader.systemd-boot.enable' && \
   ! echo "$HW_CONFIG" | grep -q 'boot.loader.grub.devices' && \
   ! echo "$HW_CONFIG" | grep -q 'boot.loader.grub.mirroredBoots'; then
  HW_CONFIG="$(append_block_before_final_brace "$HW_CONFIG" '  # Bootloader defaults (UEFI first)
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # BIOS fallback (uncomment and adjust disk if needed)
  # boot.loader.grub.enable = true;
  # boot.loader.grub.devices = [ "/dev/sda" ];')"
fi

# If an existing desktop UI is already configured on this machine,
# preserve it instead of forcing the default LXQt stack.
DETECTED_DESKTOP_OPTIONS=()
while IFS= read -r option; do
  if [ -n "$option" ]; then
    DETECTED_DESKTOP_OPTIONS+=("$option")
  fi
done < <(detect_desktop_options)

if [ "${#DETECTED_DESKTOP_OPTIONS[@]}" -gt 0 ]; then
  PRESERVE_BLOCK='  # Preserve existing desktop UI detected from current system options.
  nixpi.desktopProfile = "preserve";'

  for option in "${DETECTED_DESKTOP_OPTIONS[@]}"; do
    PRESERVE_BLOCK="${PRESERVE_BLOCK}"$'\n'"  ${option} = true;"
  done

  HW_CONFIG="$(append_block_before_final_brace "$HW_CONFIG" "$PRESERVE_BLOCK")"
  echo "Detected existing desktop UI options and preserved them in $HOST_FILE."
fi

echo "$HW_CONFIG" > "$HOST_FILE"
echo "Wrote $HOST_FILE"
echo ""
echo "Next steps:"
echo "  1. Review $HOST_FILE"
echo "  2. git add $HOST_FILE && sudo env NIX_CONFIG=\"experimental-features = nix-command flakes\" nixos-rebuild switch --flake \"path:$REPO_ROOT#$HOSTNAME\""

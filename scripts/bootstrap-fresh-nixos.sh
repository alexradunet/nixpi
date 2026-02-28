#!/usr/bin/env bash
set -euo pipefail

# Nixpi bootstrap — one-command install for fresh NixOS machines.
# Run as root: sudo bash bootstrap-fresh-nixos.sh [target-dir]

usage() {
  echo "usage: sudo $0 [--dry-run] [--non-interactive] [target-dir]" >&2
  exit 2
}

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Elevating to root via sudo..."
  exec sudo SUDO_HOME="$HOME" SUDO_USER="$(whoami)" bash "$0" "$@"
fi

DRY_RUN=0
NON_INTERACTIVE=0
TARGET_DIR="${SUDO_HOME:-$HOME}/nixpi-server"
POSITIONAL_SET=0
NIXPI_REPO="https://github.com/alexradunet/nixpi.git"
BOOTSTRAP_DIR="/tmp/nixpi-bootstrap"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --non-interactive) NON_INTERACTIVE=1; shift ;;
    -h|--help) usage ;;
    -*) echo "error: unknown option: $1" >&2; usage ;;
    *)
      if [[ "$POSITIONAL_SET" -eq 1 ]]; then usage; fi
      TARGET_DIR="$1"; POSITIONAL_SET=1; shift ;;
  esac
done

# --- Phase 1: Prepare OS (enable flakes, install git) ---
prepare_os() {
  # Skip if flakes already work (idempotent)
  if nix flake --help &>/dev/null 2>&1; then
    echo "Flakes already enabled, skipping OS preparation."
    return 0
  fi

  echo "Phase 1: Preparing NixOS (enabling flakes + git)..."

  local existing_config="/etc/nixos/configuration.nix"
  if [ ! -f "$existing_config" ]; then
    echo "No /etc/nixos/configuration.nix found, enabling flakes via nix.conf..."
    mkdir -p /etc/nix
    grep -q 'experimental-features.*nix-command.*flakes' /etc/nix/nix.conf 2>/dev/null || \
      echo 'experimental-features = nix-command flakes' >> /etc/nix/nix.conf
    systemctl restart nix-daemon.service 2>/dev/null || true
    return 0
  fi

  # Create a wrapper config that imports the installer's config
  # (preserving its boot loader, users, network) and adds flakes + git.
  local prepare_config
  prepare_config="$(mktemp /tmp/nixpi-prepare-XXXXXX.nix)"
  cat > "$prepare_config" <<'PREPEOF'
{ config, pkgs, ... }:
{
  imports = [ /etc/nixos/configuration.nix ];
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  environment.systemPackages = [ pkgs.git ];
}
PREPEOF

  nixos-rebuild switch -I "nixos-config=$prepare_config"
  rm -f "$prepare_config"
  echo "Phase 1 complete: flakes enabled, git installed."
}

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "DRY RUN: would prepare OS (enable flakes + git)"
  echo "DRY RUN: would clone $NIXPI_REPO to $BOOTSTRAP_DIR"
  echo "DRY RUN: would run setup wizard targeting $TARGET_DIR"
  echo "DRY RUN: would nixos-rebuild switch"
  exit 0
fi

# Phase 1: ensure flakes and git are available
prepare_os

# Clone Nixpi repo for bootstrap scripts
if [[ ! -d "$BOOTSTRAP_DIR/.git" ]]; then
  nix --extra-experimental-features "nix-command flakes" shell nixpkgs#git -c \
    git clone "$NIXPI_REPO" "$BOOTSTRAP_DIR"
fi

# Phase 2: Run setup wizard
if [[ "$NON_INTERACTIVE" -eq 1 ]]; then
  echo "Non-interactive mode: generating default config at $TARGET_DIR"
  mkdir -p "$TARGET_DIR"
  nixos-generate-config --show-hardware-config > "$TARGET_DIR/hardware.nix"

  NIXPI_SETUP_GENERATE_ONLY=1 source "$BOOTSTRAP_DIR/scripts/nixpi-setup.sh"
  generate_flake_nix --hostname "$(hostname)" --output "$TARGET_DIR/flake.nix"
  generate_nixpi_config \
    --hostname "$(hostname)" \
    --username "${SUDO_USER:-nixpi}" \
    --timezone "UTC" \
    --tailscale true --syncthing true --ttyd true \
    --desktop true --password-policy true \
    --heartbeat false --matrix false \
    --output "$TARGET_DIR/nixpi-config.nix"

  (cd "$TARGET_DIR" && nix --extra-experimental-features "nix-command flakes" shell nixpkgs#git -c bash -c 'git init && git add -A')
  (cd "$TARGET_DIR" && env NIX_CONFIG="experimental-features = nix-command flakes" nixos-rebuild switch --flake "path:.#$(hostname)")
else
  nix --extra-experimental-features "nix-command flakes" shell nixpkgs#dialog nixpkgs#git -c \
    bash "$BOOTSTRAP_DIR/scripts/nixpi-setup.sh" "$TARGET_DIR"
fi

install -d -m 0755 /etc/nixpi
touch /etc/nixpi/.setup-complete

echo "bootstrap-fresh-nixos: complete!"
echo "Config directory: $TARGET_DIR"
echo "Rebuild: cd $TARGET_DIR && sudo nixos-rebuild switch --flake ."

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

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "DRY RUN: would clone $NIXPI_REPO to $BOOTSTRAP_DIR"
  echo "DRY RUN: would run setup wizard targeting $TARGET_DIR"
  echo "DRY RUN: would nixos-rebuild switch"
  exit 0
fi

# Clone Nixpi repo for bootstrap scripts
if [[ ! -d "$BOOTSTRAP_DIR/.git" ]]; then
  nix --extra-experimental-features "nix-command flakes" shell nixpkgs#git -c \
    git clone "$NIXPI_REPO" "$BOOTSTRAP_DIR"
fi

# Run setup wizard
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
  (cd "$TARGET_DIR" && nixos-rebuild switch --flake "path:.#$(hostname)")
else
  nix --extra-experimental-features "nix-command flakes" shell nixpkgs#dialog nixpkgs#git -c \
    bash "$BOOTSTRAP_DIR/scripts/nixpi-setup.sh" "$TARGET_DIR"
fi

install -d -m 0755 /etc/nixpi
touch /etc/nixpi/.setup-complete

echo "bootstrap-fresh-nixos: complete!"
echo "Config directory: $TARGET_DIR"
echo "Rebuild: cd $TARGET_DIR && sudo nixos-rebuild switch --flake ."

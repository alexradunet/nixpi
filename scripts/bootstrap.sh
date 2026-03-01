#!/usr/bin/env bash
set -euo pipefail

# Nixpi bootstrap — minimal script to get Pi running on a fresh NixOS machine.
# Three jobs: enable flakes, clone repo, launch Pi with install-nixpi skill.
#
# Run as root: sudo bash bootstrap.sh [target-dir]

NIXPI_REPO="https://github.com/alexradunet/nixpi.git"
TARGET_DIR="${1:-${SUDO_HOME:-$HOME}/Nixpi}"

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Elevating to root via sudo..."
  exec sudo SUDO_HOME="$HOME" SUDO_USER="$(whoami)" bash "$0" "$@"
fi

# --- Phase 1: Prepare OS (enable flakes + git) ---
prepare_os() {
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

# --- Phase 2: Clone repo ---
clone_repo() {
  if [[ -d "$TARGET_DIR/.git" ]]; then
    echo "Repo already present at $TARGET_DIR, skipping clone."
    return 0
  fi

  echo "Phase 2: Cloning Nixpi to $TARGET_DIR..."
  nix --extra-experimental-features "nix-command flakes" shell nixpkgs#git -c \
    git clone "$NIXPI_REPO" "$TARGET_DIR"
}

# --- Phase 3: Launch Pi with install-nixpi skill ---
launch_pi() {
  echo "Phase 3: Launching Pi setup assistant..."
  cd "$TARGET_DIR"
  nix --extra-experimental-features "nix-command flakes" shell nixpkgs#nodejs_22 -c \
    npx --yes @mariozechner/pi-coding-agent@0.55.3 \
    --skill ./infra/pi/skills/install-nixpi/SKILL.md
}

prepare_os
clone_repo
launch_pi

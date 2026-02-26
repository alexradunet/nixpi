#!/usr/bin/env bash
set -euo pipefail

TARGET_DIR="${1:-${NIXPI_REPO_DIR:-$HOME/Nixpi}}"

if [ "$#" -gt 1 ]; then
  echo "usage: $0 [target-dir]" >&2
  exit 2
fi

if [ -e "$TARGET_DIR" ] && [ ! -d "$TARGET_DIR/.git" ]; then
  echo "error: $TARGET_DIR exists but is not a git repository" >&2
  exit 1
fi

if [ ! -d "$TARGET_DIR/.git" ]; then
  mkdir -p "$(dirname "$TARGET_DIR")"
  nix --extra-experimental-features "nix-command flakes" shell nixpkgs#git -c git clone https://github.com/alexradunet/nixpi.git "$TARGET_DIR"
else
  echo "Repository already present, skipping clone: $TARGET_DIR"
fi

cd "$TARGET_DIR"

if [ ! -f "infra/nixos/hosts/$(hostname).nix" ]; then
  ./scripts/add-host.sh
fi

sudo nixos-rebuild switch --flake . --extra-experimental-features "nix-command flakes"

echo "bootstrap-fresh-nixos: OK"
echo "Next: nixpi --help && ./scripts/verify-nixpi-modes.sh"

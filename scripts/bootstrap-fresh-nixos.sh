#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "usage: $0 [--dry-run] [--non-interactive] [target-dir]" >&2
  exit 2
}

DRY_RUN=0
NON_INTERACTIVE=0
TARGET_DIR="${NIXPI_REPO_DIR:-$HOME/Nixpi}"
POSITIONAL_SET=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --non-interactive)
      NON_INTERACTIVE=1
      shift
      ;;
    -h|--help)
      usage
      ;;
    -* )
      echo "error: unknown option: $1" >&2
      usage
      ;;
    *)
      if [ "$POSITIONAL_SET" -eq 1 ]; then
        usage
      fi
      TARGET_DIR="$1"
      POSITIONAL_SET=1
      shift
      ;;
  esac
done

if [ -e "$TARGET_DIR" ] && [ ! -d "$TARGET_DIR/.git" ]; then
  echo "error: $TARGET_DIR exists but is not a git repository" >&2
  exit 1
fi

FLAKE_REF="path:$TARGET_DIR#$(hostname)"

if [ "$DRY_RUN" -eq 1 ]; then
  if [ ! -d "$TARGET_DIR/.git" ]; then
    echo "DRY RUN: would clone https://github.com/alexradunet/nixpi.git into $TARGET_DIR"
  else
    echo "DRY RUN: Repository already present, skipping clone: $TARGET_DIR"
  fi

  echo 'DRY RUN: would refresh host config with ./scripts/add-host.sh --force "$(hostname)"'

  if [ "$NON_INTERACTIVE" -eq 1 ]; then
    echo "DRY RUN: would apply sudo env NIX_CONFIG=\"experimental-features = nix-command flakes\" nixos-rebuild switch --flake \"$FLAKE_REF\""
  else
    echo "DRY RUN: would launch guided install with skill at $TARGET_DIR/infra/pi/skills/install-nixpi/SKILL.md"
  fi

  echo "bootstrap-fresh-nixos: dry run complete"
  exit 0
fi

if [ ! -d "$TARGET_DIR/.git" ]; then
  mkdir -p "$(dirname "$TARGET_DIR")"
  nix --extra-experimental-features "nix-command flakes" shell nixpkgs#git -c git clone https://github.com/alexradunet/nixpi.git "$TARGET_DIR"
else
  echo "Repository already present, skipping clone: $TARGET_DIR"
fi

cd "$TARGET_DIR"

# Always refresh host hardware config for the current machine.
# This avoids stale disk UUIDs if hostname collides with an existing host file.
./scripts/add-host.sh --force "$(hostname)"

if [ "$NON_INTERACTIVE" -eq 1 ]; then
  sudo env NIX_CONFIG="experimental-features = nix-command flakes" nixos-rebuild switch --flake "$FLAKE_REF"
  echo "bootstrap-fresh-nixos: non-interactive apply finished"
  echo "Next: nixpi --help && ./scripts/verify-nixpi.sh"
  exit 0
fi

INSTALL_SKILL="$TARGET_DIR/infra/pi/skills/install-nixpi/SKILL.md"
if [ ! -f "$INSTALL_SKILL" ]; then
  echo "error: missing install skill at $INSTALL_SKILL" >&2
  exit 1
fi

INSTALL_PROMPT="Use the install-nixpi skill from this repository. Guide me through reviewing infra/nixos/hosts/$(hostname).nix, validating disk and user settings, then applying the system with sudo env NIX_CONFIG=\"experimental-features = nix-command flakes\" nixos-rebuild switch --flake \"$FLAKE_REF\". Ask before risky actions and keep steps concise."

if command -v nixpi >/dev/null 2>&1; then
  nixpi --skill "$INSTALL_SKILL" "$INSTALL_PROMPT"
else
  nix --extra-experimental-features "nix-command flakes" shell nixpkgs#nodejs_22 -c npx --yes @mariozechner/pi-coding-agent@0.55.1 --skill "$INSTALL_SKILL" "$INSTALL_PROMPT"
fi

echo "bootstrap-fresh-nixos: guided install session finished"
echo "If you exited before rebuild, rerun this script or apply manually when ready."

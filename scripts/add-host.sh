#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOSTS_DIR="$REPO_ROOT/infra/nixos/hosts"

HOSTNAME="${1:-$(hostname)}"
HOST_FILE="$HOSTS_DIR/$HOSTNAME.nix"

if [ -f "$HOST_FILE" ]; then
  echo "error: $HOST_FILE already exists" >&2
  exit 1
fi

echo "Generating hardware config for '$HOSTNAME'..."
HW_CONFIG="$(nixos-generate-config --show-hardware-config 2>/dev/null)"

# Append networking.hostName if not already present
if ! echo "$HW_CONFIG" | grep -q 'networking.hostName'; then
  HW_CONFIG=$(echo "$HW_CONFIG" | sed 's/}$/\n  networking.hostName = "'"$HOSTNAME"'";\n}/')
fi

echo "$HW_CONFIG" > "$HOST_FILE"
echo "Wrote $HOST_FILE"
echo ""
echo "Next steps:"
echo "  1. Review $HOST_FILE"
echo "  2. git add $HOST_FILE && sudo nixos-rebuild switch --flake $REPO_ROOT"

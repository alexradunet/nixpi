#!/usr/bin/env bash
set -euo pipefail

NIXPI_FLAKE_REF="${NIXPI_FLAKE_REF:-github:alexradunet/nixpi}"
PI_VERSION="${PI_VERSION:-0.55.3}"

NIX_FEATURES=(--extra-experimental-features 'nix-command flakes')

echo "Resolving Nixpi source from: ${NIXPI_FLAKE_REF}"
NIXPI_SRC="$(nix "${NIX_FEATURES[@]}" eval --impure --raw --expr "(builtins.getFlake \"${NIXPI_FLAKE_REF}\").outPath")"
SKILL_PATH="${NIXPI_SRC}/infra/pi/skills/install-nixpi/SKILL.md"

echo "Resolved source: ${NIXPI_SRC}"
echo "Skill path: ${SKILL_PATH}"

if [[ ! -f "${SKILL_PATH}" ]]; then
  echo "ERROR: Skill file not found: ${SKILL_PATH}" >&2
  echo "Hint: verify flake ref and network access. Override flake ref via NIXPI_FLAKE_REF=..." >&2
  exit 1
fi

echo "Launching Pi with install-nixpi skill..."
exec nix "${NIX_FEATURES[@]}" shell nixpkgs#nodejs_22 -c \
  npx --yes "@mariozechner/pi-coding-agent@${PI_VERSION}" \
  --skill "${SKILL_PATH}" "$@"

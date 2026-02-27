#!/usr/bin/env bash
set -euo pipefail

./scripts/lint.sh
./scripts/test.sh

# --no-build: checks flake evaluation (syntax, module structure) but does NOT
# build the NixOS configuration. Missing packages or build-time errors won't
# be caught here.
nix flake check --no-build

# Optional strict mode: also build one host's system closure without linking.
# Usage:
#   NIXPI_CHECK_BUILD=1 ./scripts/check.sh
#   NIXPI_CHECK_BUILD=1 NIXPI_CHECK_HOST=nixpi ./scripts/check.sh
if [ "${NIXPI_CHECK_BUILD:-0}" = "1" ]; then
  build_host="${NIXPI_CHECK_HOST:-$(hostname)}"
  nix build ".#nixosConfigurations.${build_host}.config.system.build.toplevel" --no-link
fi

# Optional VM integration tests: boot QEMU VMs and assert runtime behavior.
# Requires KVM. Runs all checks.x86_64-linux.vm-* tests.
# Usage:
#   NIXPI_CHECK_VM=1 ./scripts/check.sh
if [ "${NIXPI_CHECK_VM:-0}" = "1" ]; then
  nix flake check -L
fi

#!/usr/bin/env bash
set -euo pipefail

./scripts/test.sh

# --no-build: checks flake evaluation (syntax, module structure) but does NOT
# build the NixOS configuration. Missing packages or build-time errors won't
# be caught here. For full validation, use: nix build .#nixosConfigurations.<host>.config.system.build.toplevel --no-link
nix flake check --no-build

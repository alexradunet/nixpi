#!/usr/bin/env bash
set -euo pipefail

./scripts/test.sh
nix flake check --no-build

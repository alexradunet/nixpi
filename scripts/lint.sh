#!/usr/bin/env bash
set -euo pipefail

echo "==> shellcheck"
shellcheck scripts/*.sh tests/test_*.sh tests/helpers.sh

echo "==> TypeScript compile check"
npm -w packages/nixpi-core run build

echo "PASS: lint checks"

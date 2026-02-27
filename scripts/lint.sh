#!/usr/bin/env bash
set -euo pipefail

echo "==> shellcheck"
shellcheck -x --source-path=tests \
  -e SC1091 \
  -e SC2016 \
  scripts/*.sh tests/test_*.sh tests/helpers.sh

echo "==> TypeScript compile check"
npm -w packages/nixpi-core run build

echo "PASS: lint checks"

#!/usr/bin/env bash
set -euo pipefail

TEST_FILES=(tests/test_*.sh)

if [ "${TEST_FILES[0]}" = "tests/test_*.sh" ]; then
  echo "No tests found (expected files matching tests/test_*.sh)" >&2
  exit 1
fi

for test_file in "${TEST_FILES[@]}"; do
  bash "$test_file"
done

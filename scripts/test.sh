#!/usr/bin/env bash
set -euo pipefail

# Prereqs
command -v yq >/dev/null 2>&1 || { echo "error: yq not in PATH (try: nix-shell -p yq-go)" >&2; exit 1; }

pattern="${1:-test_*.sh}"
# shellcheck disable=SC2206  # intentional glob expansion
TEST_FILES=(tests/$pattern)

if [ "${TEST_FILES[0]}" = "tests/$pattern" ]; then
  echo "No tests found matching tests/$pattern" >&2; exit 1
fi

passed=0 failed=0 failures=()

for test_file in "${TEST_FILES[@]}"; do
  if bash "$test_file"; then
    passed=$((passed + 1))
  else
    failed=$((failed + 1))
    failures+=("$test_file")
  fi
done

# TypeScript tests (always run unless subset specified)
if [ "$pattern" = "test_*.sh" ]; then
  if npm -w packages/nixpi-core test 2>&1; then
    passed=$((passed + 1))
  else
    failed=$((failed + 1))
    failures+=("npm:nixpi-core")
  fi
fi

echo ""
echo "---"
echo "$passed passed, $failed failed"
if [ "$failed" -gt 0 ]; then
  printf '  FAILED: %s\n' "${failures[@]}"
  exit 1
fi

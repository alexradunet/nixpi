#!/usr/bin/env bash
set -euo pipefail

fail() {
  echo "verify-nixpi-modes: FAIL - $*" >&2
  exit 1
}

if ! command -v nixpi >/dev/null 2>&1; then
  fail "nixpi command not found on PATH (did you run nixos-rebuild switch?)"
fi

# Help should be available and mention dev mode.
help_output="$(nixpi --help 2>&1 || true)"
echo "$help_output" | grep -Fq 'nixpi dev [pi-args...]' || fail "help output missing dev mode"

# Unknown mode should return a clear error.
invalid_output="$(nixpi mode invalid 2>&1 || true)"
echo "$invalid_output" | grep -Fq 'Unknown nixpi mode:' || fail "missing unknown mode error"

# Both runtime and dev selectors should forward to Pi help successfully.
nixpi mode runtime --help >/dev/null 2>&1 || fail "runtime mode did not forward to pi --help"
nixpi dev --help >/dev/null 2>&1 || fail "dev mode did not forward to pi --help"

# Edge case: explicit mode selector for dev should behave like `nixpi dev`.
nixpi mode dev --help >/dev/null 2>&1 || fail "explicit dev mode did not forward to pi --help"

echo "verify-nixpi-modes: OK"

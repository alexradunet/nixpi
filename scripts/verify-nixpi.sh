#!/usr/bin/env bash
set -euo pipefail

fail() {
  echo "verify-nixpi: FAIL - $*" >&2
  exit 1
}

if ! command -v nixpi >/dev/null 2>&1; then
  fail "nixpi command not found on PATH (did you run nixos-rebuild switch?)"
fi

# Help should be available for the single-instance wrapper.
help_output="$(nixpi --help 2>&1 || true)"
echo "$help_output" | grep -Fq 'nixpi [args...]' || fail "help output missing base usage"

echo "$help_output" | grep -Fq 'single instance' || fail "help output missing single-instance note"

# Deprecated subcommands should fail with a clear migration error.
deprecated_output="$(nixpi dev 2>&1 || true)"
echo "$deprecated_output" | grep -Fq 'Unknown/deprecated nixpi subcommand:' || fail "missing deprecated subcommand error"

# Edge case: plain invocation still forwards to Pi help.
nixpi --help >/dev/null 2>&1 || fail "nixpi --help did not forward successfully"

echo "verify-nixpi: OK"

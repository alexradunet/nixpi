#!/usr/bin/env bash
# Shared test assertion helpers. Source from each test file:
#   source "$(dirname "$0")/helpers.sh"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_file_contains() {
  local file="$1"
  local needle="$2"
  grep -Fq "$needle" "$file" || fail "expected '$needle' in $file"
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  printf '%s' "$haystack" | grep -Fq "$needle" || fail "expected output to contain '$needle'"
}

assert_not_contains() {
  local haystack="$1"
  local needle="$2"
  if printf '%s' "$haystack" | grep -Fq "$needle"; then
    fail "did not expect output to contain '$needle'"
  fi
}

assert_executable() {
  local file="$1"
  [ -x "$file" ] || fail "expected executable file: $file"
}

assert_nonempty() {
  local value="$1"
  local msg="$2"
  [ -n "$value" ] || fail "$msg"
}

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

assert_file_not_contains() {
  local file="$1" needle="$2"
  if grep -Fq -- "$needle" "$file"; then
    fail "did not expect '$needle' in $file"
  fi
}

assert_exit_code() {
  local expected="$1"; shift
  local actual=0
  "$@" || actual=$?
  [ "$actual" -eq "$expected" ] || fail "expected exit code $expected, got $actual"
}

assert_file_exists() {
  local file="$1"
  [ -f "$file" ] || fail "expected file to exist: $file"
}

assert_dir_exists() {
  local dir="$1"
  [ -d "$dir" ] || fail "expected directory to exist: $dir"
}

# Create an isolated tmpdir for object tests. Call from tests that need their
# own NIXPI_OBJECTS_DIR. Uses NIXPI_TEST_TMPDIR from the runner when available.
setup_test_tmpdir() {
  local base="${NIXPI_TEST_TMPDIR:-$(mktemp -d)}"
  local objects_dir="$base/objects"
  mkdir -p "$objects_dir"
  export NIXPI_OBJECTS_DIR="$objects_dir"
  echo "$base"
}

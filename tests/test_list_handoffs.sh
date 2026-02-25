#!/usr/bin/env bash
set -euo pipefail

SCRIPT="scripts/list-handoffs.sh"

fail() {
  echo "FAIL: $*" >&2
  exit 1
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

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

mkdir -p "$TMP_DIR/handoffs"
cat > "$TMP_DIR/handoffs/20260225-2110-evolution-request-element-routing.md" <<'EOF'
# Evolution Request
EOF
cat > "$TMP_DIR/handoffs/20260225-2130-review-report-element-routing.md" <<'EOF'
# Review Report
EOF
cat > "$TMP_DIR/handoffs/20260226-0900-evolution-request-auth-flow.md" <<'EOF'
# Evolution Request
EOF

# Happy path: newest-first listing.
output="$($SCRIPT --dir "$TMP_DIR/handoffs")"
first_line="$(printf '%s\n' "$output" | sed -n '1p')"
[ "$first_line" = "20260226-0900-evolution-request-auth-flow.md" ] || fail "expected newest file first"
assert_contains "$output" "20260225-2110-evolution-request-element-routing.md"

# Failure path: unknown option should fail clearly.
set +e
invalid_output="$($SCRIPT --bogus 2>&1)"
invalid_code=$?
set -e
[ $invalid_code -ne 0 ] || fail "expected non-zero for unknown option"
assert_contains "$invalid_output" "unknown option"

# Edge case: type filter should include only matching types.
filtered="$($SCRIPT --dir "$TMP_DIR/handoffs" --type evolution-request)"
assert_contains "$filtered" "evolution-request"
assert_not_contains "$filtered" "review-report"

echo "PASS: list-handoffs script"

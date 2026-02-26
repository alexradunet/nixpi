#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/helpers.sh"

SCRIPT="scripts/list-handoffs.sh"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

mkdir -p "$TMP_DIR/handoffs"
cat > "$TMP_DIR/handoffs/20260226-1000-evolution-request-topic with spaces.md" <<'EOF'
# Evolution Request
EOF
cat > "$TMP_DIR/handoffs/20260226-0900-review-report-basic.md" <<'EOF'
# Review Report
EOF

# Happy path + edge case: filenames with spaces are preserved as single lines.
output="$($SCRIPT --dir "$TMP_DIR/handoffs")"
assert_contains "$output" '20260226-1000-evolution-request-topic with spaces.md'

# Failure path: unknown options still fail clearly.
set +e
invalid_output="$($SCRIPT --bogus 2>&1)"
invalid_code=$?
set -e
[ $invalid_code -ne 0 ] || fail "expected non-zero for unknown option"
assert_contains "$invalid_output" 'unknown option'

echo "PASS: list-handoffs handles spaced filenames safely"

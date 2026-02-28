#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/helpers.sh"

BRIDGE_DIR="services/matrix-bridge"

# Happy path: bridge service files exist.
[ -f "$BRIDGE_DIR/package.json" ] || fail "expected package.json to exist"
[ -f "$BRIDGE_DIR/tsconfig.json" ] || fail "expected tsconfig.json to exist"
[ -f "$BRIDGE_DIR/src/index.ts" ] || fail "expected src/index.ts to exist"

# Happy path: package.json has correct dependencies.
assert_file_contains "$BRIDGE_DIR/package.json" '"matrix-bot-sdk"'
assert_file_contains "$BRIDGE_DIR/package.json" '"typescript"'

# Happy path: source implements Ports and Adapters pattern.
assert_file_contains "$BRIDGE_DIR/src/index.ts" "MatrixClient"
assert_file_contains "$BRIDGE_DIR/src/index.ts" "SimpleFsStorageProvider"
assert_file_contains "$BRIDGE_DIR/src/index.ts" "AutojoinRoomsMixin"
assert_file_contains "$BRIDGE_DIR/src/index.ts" "MessageChannel"
assert_file_contains "$BRIDGE_DIR/src/index.ts" "IncomingMessage"
assert_file_contains "$BRIDGE_DIR/src/index.ts" "processMessage"

# Happy path: source handles allowed users whitelist.
assert_file_contains "$BRIDGE_DIR/src/index.ts" "isAllowed"
assert_file_contains "$BRIDGE_DIR/src/index.ts" "NIXPI_MATRIX_ALLOWED_USERS"

# Happy path: source uses Pi print mode.
assert_file_contains "$BRIDGE_DIR/src/index.ts" '"-p"'

# Happy path: source uses sequential message queue.
assert_file_contains "$BRIDGE_DIR/src/index.ts" "enqueue"

# Happy path: skips own messages via getUserId.
assert_file_contains "$BRIDGE_DIR/src/index.ts" "getUserId"

echo "PASS: Matrix bridge service structure and patterns are correct"

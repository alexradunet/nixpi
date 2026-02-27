#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/helpers.sh"

BRIDGE_DIR="services/whatsapp-bridge"

# Happy path: bridge service files exist.
[ -f "$BRIDGE_DIR/package.json" ] || fail "expected package.json to exist"
[ -f "$BRIDGE_DIR/tsconfig.json" ] || fail "expected tsconfig.json to exist"
[ -f "$BRIDGE_DIR/src/index.ts" ] || fail "expected src/index.ts to exist"

# Happy path: package.json has correct dependencies.
assert_file_contains "$BRIDGE_DIR/package.json" '"@whiskeysockets/baileys"'
assert_file_contains "$BRIDGE_DIR/package.json" '"pino"'
assert_file_contains "$BRIDGE_DIR/package.json" '"typescript"'

# Happy path: source implements Ports and Adapters pattern.
assert_file_contains "$BRIDGE_DIR/src/index.ts" "MessageChannel"
assert_file_contains "$BRIDGE_DIR/src/index.ts" "IncomingMessage"
assert_file_contains "$BRIDGE_DIR/src/index.ts" "processMessage"

# Happy path: source handles allowed numbers whitelist.
assert_file_contains "$BRIDGE_DIR/src/index.ts" "isAllowed"
assert_file_contains "$BRIDGE_DIR/src/index.ts" "NIXPI_WHATSAPP_ALLOWED"

# Happy path: source uses Pi print mode.
assert_file_contains "$BRIDGE_DIR/src/index.ts" '"-p"'

# Happy path: source uses sequential message queue.
assert_file_contains "$BRIDGE_DIR/src/index.ts" "enqueue"

# Edge case: no groups (MVP is 1:1 only).
assert_file_contains "$BRIDGE_DIR/src/index.ts" "@g.us"

# Edge case: skips own messages.
assert_file_contains "$BRIDGE_DIR/src/index.ts" "fromMe"

echo "PASS: WhatsApp bridge service structure and patterns are correct"

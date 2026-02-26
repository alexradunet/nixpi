#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/helpers.sh"

DOC="docs/extensions/WHATSAPP_ADAPTER.md"
README="README.md"

# Happy path: adapter docs are present and discoverable.
assert_file_contains "$DOC" '# WhatsApp Adapter (MVP)'
assert_file_contains "$DOC" 'OpenClaw-like'
assert_file_contains "$DOC" 'NIXPI_WHATSAPP_ALLOWED_NUMBERS'
assert_file_contains "$DOC" 'npm install'
assert_file_contains "$DOC" 'node src/main.mjs'

# Failure path: explicit guard for missing allowlist.
assert_file_contains "$DOC" 'fails fast if no allowlist is configured'

# Edge case: docs define duplicate-message/idempotency handling.
assert_file_contains "$DOC" 'duplicate message IDs'

# Discoverability from project README.
assert_file_contains "$README" 'WhatsApp adapter (MVP)'

# Behavioral tests for parsing/allowlist/text extraction helpers.
node --test adapters/whatsapp/test/*.test.mjs

echo "PASS: WhatsApp adapter docs + helper behavior"
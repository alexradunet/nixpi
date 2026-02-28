#!/usr/bin/env bash
# Matrix account setup for Nixpi.
#
# Creates human + bot accounts on the local Conduit homeserver and writes
# the bot access token to the secrets file.
#
# Prerequisites:
#   1. Conduit must be running (sudo nixos-rebuild switch)
#   2. Registration must be enabled:
#        nixpi.channels.matrix.conduit.allowRegistration = true
#
# After running:
#   1. Set conduit.allowRegistration = false in your NixOS config
#   2. Run: sudo nixos-rebuild switch --flake ~/Nixpi
#   3. Connect Element to the homeserver and log in as the human user
#   4. Create a DM room and invite the bot user
set -euo pipefail

HOMESERVER="${NIXPI_MATRIX_HOMESERVER:-http://localhost:6167}"
HUMAN_USER="${1:-human}"
BOT_USER="${2:-nixpi}"
TOKEN_FILE="${3:-/run/secrets/nixpi-matrix-token}"

gen_password() {
  head -c 32 /dev/urandom | base64 | tr -d '/+=' | head -c 32
}

# Register a Matrix user via the CS API (handles UIA flow).
# Prints the JSON response on success, exits on failure.
register_user() {
  local username="$1"
  local password="$2"

  # Step 1: initiate registration to get UIA session
  local init_response
  init_response=$(curl -s -X POST "${HOMESERVER}/_matrix/client/v3/register" \
    -H "Content-Type: application/json" \
    -d "{\"username\": \"${username}\", \"password\": \"${password}\"}")

  # If the server returned an access_token directly, we're done
  if echo "$init_response" | jq -e '.access_token' >/dev/null 2>&1; then
    echo "$init_response"
    return 0
  fi

  # Extract UIA session
  local session
  session=$(echo "$init_response" | jq -r '.session // empty')

  if [ -z "$session" ]; then
    echo "ERROR: Failed to register @${username}" >&2
    echo "  Is registration enabled? Set conduit.allowRegistration = true and rebuild." >&2
    echo "  Server response: ${init_response}" >&2
    return 1
  fi

  # Step 2: complete registration with dummy auth
  local response
  response=$(curl -s -X POST "${HOMESERVER}/_matrix/client/v3/register" \
    -H "Content-Type: application/json" \
    -d "{\"username\": \"${username}\", \"password\": \"${password}\", \"auth\": {\"type\": \"m.login.dummy\", \"session\": \"${session}\"}}")

  if ! echo "$response" | jq -e '.access_token' >/dev/null 2>&1; then
    echo "ERROR: Failed to register @${username}" >&2
    echo "  Server response: ${response}" >&2
    return 1
  fi

  echo "$response"
}

echo "Nixpi Matrix Setup"
echo "==================="
echo "  Homeserver:  ${HOMESERVER}"
echo "  Human user:  @${HUMAN_USER}"
echo "  Bot user:    @${BOT_USER}"
echo "  Token file:  ${TOKEN_FILE}"
echo ""

# Check Conduit is reachable
if ! curl -sf "${HOMESERVER}/_matrix/client/versions" >/dev/null 2>&1; then
  echo "ERROR: Cannot reach Conduit at ${HOMESERVER}" >&2
  echo "Make sure Conduit is running: systemctl status conduit" >&2
  exit 1
fi
echo "Conduit is reachable."

HUMAN_PASS="$(gen_password)"
BOT_PASS="$(gen_password)"

echo "Registering @${HUMAN_USER}..."
register_user "$HUMAN_USER" "$HUMAN_PASS" >/dev/null
echo "  Done."

echo "Registering @${BOT_USER}..."
bot_response=$(register_user "$BOT_USER" "$BOT_PASS")
bot_token=$(echo "$bot_response" | jq -r '.access_token')
echo "  Done."

if [ -z "$bot_token" ] || [ "$bot_token" = "null" ]; then
  echo "ERROR: No access token in registration response" >&2
  exit 1
fi

# Write token file
echo "Writing access token to ${TOKEN_FILE}..."
sudo mkdir -p "$(dirname "$TOKEN_FILE")"
echo "NIXPI_MATRIX_ACCESS_TOKEN=${bot_token}" | sudo tee "$TOKEN_FILE" >/dev/null
sudo chmod 600 "$TOKEN_FILE"
echo "  Done."

echo ""
echo "=== Setup Complete ==="
echo ""
echo "Human account credentials (save these!):"
echo "  Username: @${HUMAN_USER}"
echo "  Password: ${HUMAN_PASS}"
echo ""
echo "Bot access token written to: ${TOKEN_FILE}"
echo ""
echo "Next steps:"
echo "  1. Set conduit.allowRegistration = false in your NixOS config"
echo "  2. Run: sudo nixos-rebuild switch --flake ~/Nixpi"
echo "  3. Connect Element to ${HOMESERVER} and log in as @${HUMAN_USER}"
echo "  4. Create a room and invite @${BOT_USER}"

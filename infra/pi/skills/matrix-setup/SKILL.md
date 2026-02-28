---
name: matrix-setup
description: Interactive Matrix channel setup — provisions Conduit homeserver, creates accounts, configures the bridge, and verifies end-to-end messaging.
---

# Matrix Channel Setup (Guided)

Use this skill when the user wants to set up the Matrix messaging channel on their Nixpi instance. This skill will become part of a broader interactive Nixpi setup assistant that can enable/disable modules and configure the system declaratively.

## Goals
1. Provision a local Conduit Matrix homeserver on the Nixpi machine.
2. Create the human and bot Matrix accounts.
3. Write the bot access token to the secrets file.
4. Verify the bridge service connects and responds.
5. Leave the system in a secure state (registration disabled).

## Prerequisites
- Nixpi is installed and `nixos-rebuild switch --flake .` works.
- The user has shell access (SSH, ttyd, or local terminal).
- The user has `sudo` privileges.

## Guided Flow

### Phase 1: Review Current Configuration

1. Confirm we are inside the Nixpi repo root (`~/Nixpi`).
2. Read the current Matrix channel config:
   ```bash
   cat infra/nixos/hosts/$(hostname).nix
   ```
3. Show the user the current Matrix module settings:
   - `serverName` (default: `nixpi.local`)
   - `humanUser` (default: `human`)
   - `botUser` (default: `nixpi`)
   - `allowedUsers` (derived from humanUser + serverName)
   - `conduit.enable` (default: `true`)
   - `accessTokenFile` (default: `/run/secrets/nixpi-matrix-token`)
4. Ask the user if they want to customize any of these values:
   - "What username would you like for your Matrix account? (default: human)"
   - "What server name for your homeserver? (default: nixpi.local)"
   - If they want changes, show the exact Nix config diff and confirm before applying.

### Phase 2: Enable Registration and Deploy Conduit

5. Check if Conduit is already running:
   ```bash
   systemctl is-active conduit 2>/dev/null || echo "not running"
   ```
6. Check if registration is currently enabled:
   ```bash
   grep -q 'allowRegistration = true' infra/nixos/hosts/$(hostname).nix && echo "enabled" || echo "disabled"
   ```
7. If registration is not enabled, explain why it's needed and show the change:
   - "I need to temporarily enable Matrix account registration to create your accounts."
   - "After setup, I'll disable it again for security."
   - Show the exact line to add: `conduit.allowRegistration = true;`
8. Apply the config change to the host file (add `conduit.allowRegistration = true;` inside the `nixpi.channels.matrix` block).
9. Rebuild NixOS:
   ```bash
   sudo nixos-rebuild switch --flake .
   ```
10. Verify Conduit is running:
    ```bash
    systemctl is-active conduit
    curl -sf http://localhost:6167/_matrix/client/versions | head -c 200
    ```
    If Conduit is not running, check logs:
    ```bash
    journalctl -u conduit --no-pager -n 20
    ```

### Phase 3: Create Accounts

11. Run the setup script with the configured usernames:
    ```bash
    ./scripts/matrix-setup.sh <humanUser> <botUser>
    ```
    This script:
    - Registers the human account and generates a secure password.
    - Registers the bot account and captures its access token.
    - Writes the token to `/run/secrets/nixpi-matrix-token`.
12. Show the user their human account credentials clearly:
    - "Save these credentials! You'll need them to log in from Element."
    - Display username and password prominently.
13. If the script fails with a registration error:
    - Check if Conduit allows registration: `curl -s http://localhost:6167/_matrix/client/v3/register -d '{}' | jq .`
    - Check if the users already exist (re-registration fails).
    - If users exist, try logging in instead to get a fresh access token:
      ```bash
      curl -s -X POST http://localhost:6167/_matrix/client/v3/login \
        -H "Content-Type: application/json" \
        -d '{"type":"m.login.password","identifier":{"type":"m.id.user","user":"<botUser>"},"password":"<password>"}'
      ```

### Phase 4: Disable Registration and Rebuild

14. Remove the `conduit.allowRegistration = true;` line from the host file.
15. Rebuild NixOS:
    ```bash
    sudo nixos-rebuild switch --flake .
    ```
16. Verify registration is disabled:
    ```bash
    curl -s -X POST http://localhost:6167/_matrix/client/v3/register \
      -H "Content-Type: application/json" \
      -d '{"username":"test","password":"test1234"}' | jq -r '.errcode'
    ```
    Expected: `M_FORBIDDEN` (registration disabled).

### Phase 5: Verify Bridge

17. Check the bridge service status:
    ```bash
    systemctl status nixpi-matrix-bridge --no-pager
    ```
18. Check bridge logs for successful connection:
    ```bash
    journalctl -u nixpi-matrix-bridge --no-pager -n 20
    ```
    Look for: "Connected to Matrix homeserver." and "Bot user ID: @nixpi:..."
19. If the bridge fails:
    - Check the access token file exists and is readable:
      ```bash
      sudo test -f /run/secrets/nixpi-matrix-token && echo "exists" || echo "missing"
      ```
    - Check environment:
      ```bash
      systemctl show nixpi-matrix-bridge -p Environment --no-pager
      ```
    - Restart and watch logs:
      ```bash
      sudo systemctl restart nixpi-matrix-bridge
      journalctl -u nixpi-matrix-bridge -f
      ```

### Phase 6: Connect Client and Test

20. Guide the user to connect a Matrix client:
    - "Install Element (https://element.io) on your phone or desktop."
    - "In Element settings, set the homeserver to: http://<tailscale-ip>:6167"
    - "Log in with your human account credentials."
    - "Note: the homeserver is only reachable over Tailscale or LAN, not the public internet."
21. Guide them to create a DM with the bot:
    - "Start a new Direct Message with @<botUser>:<serverName>"
    - "The bot auto-joins rooms, so it should appear within a few seconds."
22. Ask the user to send a test message:
    - "Send a simple message like 'hello' and wait for a response."
    - The bot should process through Pi and respond.
23. If no response:
    - Check bridge logs: `journalctl -u nixpi-matrix-bridge -f`
    - Common issues:
      - Bot not joined to room (check AutojoinRoomsMixin is working)
      - Access token invalid (re-run setup script)
      - Pi command not found (check `NIXPI_PI_COMMAND` env var)

### Phase 7: Summary

24. Print a summary of the completed setup:
    ```
    Matrix Channel Setup Complete
    =============================
    Homeserver:    http://localhost:6167
    Server name:   <serverName>
    Human account: @<humanUser>:<serverName>
    Bot account:   @<botUser>:<serverName>
    Bridge status: active
    Conduit:       running (registration disabled)
    ```
25. Remind the user:
    - "Your human credentials are only shown once — save them securely."
    - "The homeserver is Tailscale-only. Connect Element via your Tailscale IP."
    - "The bot processes messages through Pi — same as the TUI, just over Matrix."

## Configuration Reference

All options live under `nixpi.channels.matrix` in the host's Nix config:

| Option | Default | Description |
|--------|---------|-------------|
| `enable` | `false` | Enable the Matrix channel |
| `serverName` | `"nixpi.local"` | Domain part of Matrix IDs |
| `homeserverUrl` | `"http://localhost:6167"` | Conduit client-server URL |
| `humanUser` | `"human"` | Human account localpart |
| `botUser` | `"nixpi"` | Bot account localpart |
| `allowedUsers` | `[ "@<humanUser>:<serverName>" ]` | Users allowed to message the bot |
| `accessTokenFile` | `"/run/secrets/nixpi-matrix-token"` | Path to bot access token env file |
| `conduit.enable` | `true` | Provision local Conduit homeserver |
| `conduit.allowRegistration` | `false` | Temporarily allow account registration |

## Troubleshooting

### Conduit won't start
```bash
journalctl -u conduit --no-pager -n 50
# Common: port 6167 already in use, RocksDB corruption
# Fix: sudo systemctl stop conduit && sudo rm -rf /var/lib/matrix-conduit/database && sudo systemctl start conduit
```

### Bridge keeps restarting
```bash
journalctl -u nixpi-matrix-bridge --no-pager -n 50
# Common: invalid access token, Conduit not ready yet
# Fix: re-run scripts/matrix-setup.sh and restart bridge
```

### Bot doesn't respond to messages
- Confirm the sending user is in `allowedUsers` (check with `grep NIXPI_MATRIX_ALLOWED_USERS`)
- Confirm the bot has joined the room (check bridge logs for "room.message" events)
- Confirm Pi is accessible: `pi -p "hello"` from the nixpi user

### Access token expired or lost
```bash
# Re-run setup with registration temporarily enabled
# Or login directly if you know the bot password:
curl -s -X POST http://localhost:6167/_matrix/client/v3/login \
  -H "Content-Type: application/json" \
  -d '{"type":"m.login.password","identifier":{"type":"m.id.user","user":"nixpi"},"password":"<bot-password>"}' \
  | jq -r '.access_token'
```

## Safety Notes
- Never commit access tokens or passwords to git.
- The `accessTokenFile` uses EnvironmentFile loading to keep secrets out of the Nix store.
- Registration is disabled by default — only enable temporarily during setup.
- Conduit binds to `127.0.0.1` — only reachable via Tailscale (port 6167 firewall rule).
- Do not enable federation unless you understand the implications.

## Future: Module Setup Assistant

This skill is the first step toward a broader **interactive Nixpi setup assistant** that can:
- List all available Nixpi modules and their current state (enabled/disabled).
- Guide the user through enabling/disabling modules interactively.
- Validate configuration before applying.
- Run `nixos-rebuild switch` with rollback safety.
- The assistant will use this same guided-flow pattern for each module.

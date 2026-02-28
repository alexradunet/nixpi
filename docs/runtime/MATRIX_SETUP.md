# Matrix Channel Setup

Related: [Operating Model](./OPERATING_MODEL.md) · [Reinstall Guide](./REINSTALL.md) · [Matrix Setup Skill](../../infra/pi/skills/matrix-setup/SKILL.md)

The Matrix channel lets you message Nixpi from any Matrix client (Element, FluffyChat, etc.) over your Tailscale network. Messages are processed through Pi -- same engine as the TUI, just delivered over Matrix.

Matrix is a toggleable NixOS module. Enable it with `nixpi.channels.matrix.enable = true` in your host config, or select it during `nixpi setup`.

## Architecture

```
Element (phone/desktop)
    │
    │  Matrix client-server API
    │
    ▼
Conduit (localhost:6167)     ◄── lightweight Rust homeserver, NixOS-managed
    │
    │  room.message events
    │
    ▼
nixpi-matrix-bridge          ◄── matrix-bot-sdk, systemd service
    │
    │  spawn `pi -p "<message>"`
    │
    ▼
Pi agent → stdout → Matrix response
```

**Conduit** is a lightweight Matrix homeserver written in Rust (~15 MB RAM). It runs locally, stores data in RocksDB, and requires zero external infrastructure. No federation, no public exposure — just a private Matrix server on your Tailscale network.

**Two accounts** are created during setup:
- `@human:<serverName>` — your human account (you log in with this from Element)
- `@nixpi:<serverName>` — the bot account (the bridge authenticates as this)

## Interactive Setup (Recommended)

The fastest path is the guided Pi skill that walks you through each step:

```bash
nixpi --skill ./infra/pi/skills/matrix-setup/SKILL.md
```

This will:
1. Review your current config and ask for customization.
2. Enable registration, rebuild, create accounts.
3. Disable registration, rebuild.
4. Verify the bridge connects and responds.
5. Guide you through connecting Element.

## Manual Setup

If you prefer to do it yourself, follow these steps.

### 1. Enable the Matrix channel

Edit your host config (e.g. `infra/nixos/hosts/nixos.nix`):

```nix
nixpi.channels.matrix = {
  enable = true;
  humanUser = "alex";                  # your Matrix username (default: "human")
  # serverName = "nixpi.local";        # default
  # botUser = "nixpi";                 # default
  # accessTokenFile = "/run/secrets/nixpi-matrix-token";  # default
  conduit.allowRegistration = true;    # temporary — remove after account setup
};
```

### 2. Deploy Conduit

```bash
sudo nixos-rebuild switch --flake .
```

Verify Conduit is running:

```bash
systemctl is-active conduit
curl -sf http://localhost:6167/_matrix/client/versions
```

### 3. Create accounts

```bash
./scripts/matrix-setup.sh alex nixpi
```

Arguments: `<humanUser> <botUser> [tokenFilePath]`

The script will:
- Register both accounts with generated passwords.
- Write the bot access token to `/run/secrets/nixpi-matrix-token`.
- Print your human credentials — save these securely.

### 4. Disable registration

Remove `conduit.allowRegistration = true;` from your host config, then rebuild:

```bash
sudo nixos-rebuild switch --flake .
```

Verify registration is closed:

```bash
curl -s -X POST http://localhost:6167/_matrix/client/v3/register \
  -H "Content-Type: application/json" \
  -d '{"username":"test","password":"test1234"}' | jq -r '.errcode'
# Expected: M_FORBIDDEN
```

### 5. Verify the bridge

```bash
systemctl status nixpi-matrix-bridge
journalctl -u nixpi-matrix-bridge --no-pager -n 20
```

Look for: `Connected to Matrix homeserver.` and `Bot user ID: @nixpi:nixpi.local`.

### 6. Connect Element

1. Install [Element](https://element.io) on your phone or desktop.
2. Set the homeserver to `http://<tailscale-ip>:6167`.
   - Find your Tailscale IP: `tailscale ip -4`
3. Log in with your human account credentials.
4. Start a Direct Message with `@nixpi:nixpi.local` (or your configured botUser:serverName).
5. Send a test message — the bot should respond via Pi.

## Configuration Reference

All options under `nixpi.channels.matrix`:

| Option | Default | Description |
|--------|---------|-------------|
| `enable` | `false` | Enable the Matrix channel |
| `serverName` | `"nixpi.local"` | Domain part of Matrix user IDs |
| `homeserverUrl` | `"http://localhost:6167"` | Conduit client-server API URL |
| `humanUser` | `"human"` | Human account localpart |
| `botUser` | `"nixpi"` | Bot account localpart |
| `allowedUsers` | `[ "@<humanUser>:<serverName>" ]` | Users permitted to message the bot |
| `accessTokenFile` | `"/run/secrets/nixpi-matrix-token"` | EnvironmentFile with `NIXPI_MATRIX_ACCESS_TOKEN` |
| `conduit.enable` | `true` | Provision a local Conduit homeserver |
| `conduit.allowRegistration` | `false` | Temporarily allow account registration |

## Troubleshooting

### Conduit won't start
```bash
journalctl -u conduit --no-pager -n 50
```
Common: port conflict on 6167, or RocksDB corruption after unclean shutdown.
Fix: `sudo systemctl stop conduit && sudo rm -rf /var/lib/matrix-conduit/database && sudo systemctl start conduit`

### Bridge keeps restarting
```bash
journalctl -u nixpi-matrix-bridge --no-pager -n 50
```
Common: invalid or missing access token, Conduit not ready.
Fix: re-run `./scripts/matrix-setup.sh` and `sudo systemctl restart nixpi-matrix-bridge`.

### Bot doesn't respond
1. Confirm sender is in `allowedUsers`:
   ```bash
   systemctl show nixpi-matrix-bridge -p Environment | tr ' ' '\n' | grep ALLOWED
   ```
2. Confirm bot joined the room (check bridge logs for `room.message` events).
3. Confirm Pi works directly: `pi -p "hello"`

### Lost access token
Re-enable registration temporarily, re-run the setup script, or login directly:
```bash
curl -s -X POST http://localhost:6167/_matrix/client/v3/login \
  -H "Content-Type: application/json" \
  -d '{"type":"m.login.password","identifier":{"type":"m.id.user","user":"nixpi"},"password":"<password>"}' \
  | jq -r '.access_token'
# Then write to /run/secrets/nixpi-matrix-token:
echo "NIXPI_MATRIX_ACCESS_TOKEN=<token>" | sudo tee /run/secrets/nixpi-matrix-token
sudo chmod 600 /run/secrets/nixpi-matrix-token
sudo systemctl restart nixpi-matrix-bridge
```

## Security Model

- Conduit binds to `127.0.0.1:6167` -- not exposed to the public internet.
- Port 6167 firewall rules allow access from Tailscale IPs only.
- Federation is disabled -- your homeserver is isolated.
- Registration is disabled by default -- only enabled during initial setup.
- The bot access token is stored in `/run/secrets/` via EnvironmentFile, never in the Nix store. Future migration target: `/etc/nixpi/secrets/nixpi-matrix-token` (aligned with the centralised secrets directory at `/etc/nixpi/secrets/`).
- Only users in the `allowedUsers` list can trigger Pi processing.

# WhatsApp Adapter (MVP)

Related: [Docs Home](../README.md) · [Operating Model](../runtime/OPERATING_MODEL.md)

This document defines the first WhatsApp adapter for Nixpi so you can chat with Nixpi from your phone in an **OpenClaw-like** experience.

## Scope (MVP)
- 1:1 text chat only.
- Incoming messages are accepted only from allowlisted numbers.
- Adapter calls `nixpi -p` and sends back the text response.
- Adapter ignores duplicate message IDs to keep behavior idempotent.

## Security Rules
- The adapter **fails fast if no allowlist is configured**.
- Allowlist is provided via env var: `NIXPI_WHATSAPP_ALLOWED_NUMBERS`.
- Keep auth/session state in a local directory; do not commit it.

## Runtime Configuration

Required:
- `NIXPI_WHATSAPP_ALLOWED_NUMBERS` — comma-separated numbers (country code, no `+`).

Optional:
- `NIXPI_WHATSAPP_STATE_DIR` — defaults to `~/.local/share/nixpi/whatsapp`.
- `NIXPI_WHATSAPP_PI_BIN` — defaults to `nixpi`.
- `NIXPI_WHATSAPP_MAX_REPLY_CHARS` — defaults to `3500`.
- `NIXPI_WHATSAPP_LOG_LEVEL` — defaults to `info`.

## Local Run

```bash
cd adapters/whatsapp
npm install
NIXPI_WHATSAPP_ALLOWED_NUMBERS="40722000111" node src/main.mjs
```

On first run, scan the QR code shown in terminal from WhatsApp > Linked Devices.

## Declarative NixOS Enablement (Phase 2)

Add to your host file (`infra/nixos/hosts/<hostname>.nix`):

```nix
{ ... }:
{
  nixpi.whatsapp.enable = true;
  nixpi.whatsapp.allowlistedNumbers = [ "40722000111" ];

  # Optional override (default: /home/<user>/Nixpi/.pi/whatsapp)
  # nixpi.whatsapp.stateDir = "/home/alex/.local/share/nixpi/whatsapp";
}
```

Install adapter dependencies once on host:

```bash
cd ~/Nixpi/adapters/whatsapp
npm ci
```

Then rebuild:

```bash
cd ~/Nixpi
sudo nixos-rebuild switch --flake .
```

## Secret/Runtime Env Strategy

If you do not want allowlisted numbers inside Nix config, use an external env file:

```nix
{ ... }:
{
  nixpi.whatsapp.enable = true;
  nixpi.whatsapp.environmentFile = "/var/lib/nixpi-secrets/whatsapp.env";
}
```

Example `/var/lib/nixpi-secrets/whatsapp.env`:

```bash
NIXPI_WHATSAPP_ALLOWED_NUMBERS=40722000111,491234567890
```

The adapter service reads this file at runtime; keep it out of git.

## Notes
- `messages.upsert` is used for inbound events.
- Auth state persists via `useMultiFileAuthState`.
- Duplicate message IDs are filtered for a short TTL window.

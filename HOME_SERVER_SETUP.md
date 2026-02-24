# NixOS Home Server Setup

Intel N150 mini PC (16 GB RAM) running NixOS, secured with Tailscale for remote access.

## Goals

- Only accessible from the home LAN (Asus router) and Tailscale-connected devices
- No public ports, no port forwarding, zero exposure to the internet
- Simple to set up and access — minimal moving parts

## Architecture

```
┌─────────────────────────────────────────────────────┐
│  Your Devices (laptop, phone, etc.)                 │
│  ┌───────────────┐                                  │
│  │  RDP Client   │──── Tailscale tunnel ───┐        │
│  └───────────────┘                         │        │
└────────────────────────────────────────────┼────────┘
                                             │
         ┌───────────── NixOS Mini PC ───────┼───────────────┐
         │               (nixpi)             ▼               │
         │  ┌──────────────────────────────────────────┐     │
         │  │  Tailscale (100.x.x.x)                   │     │
         │  │  ┌─────────────────────────────────────┐ │     │
         │  │  │ XRDP (:3389) → XFCE desktop session │ │     │
         │  │  │ SSH  (:22)   → terminal access       │ │     │
         │  │  └─────────────────────────────────────┘ │     │
         │  └──────────────────────────────────────────┘     │
         │                                                    │
         │  Firewall: ALLOW tailscale0 + LAN (192.168.x.x)  │
         │            DENY everything else                    │
         └────────────────────────────────────────────────────┘
```

## Stack

| Component | NixOS module                  | Purpose                                    |
|-----------|-------------------------------|--------------------------------------------|
| Tailscale | `services.tailscale`          | Encrypted WireGuard tunnel to your devices |
| Firewall  | `networking.firewall`         | Trust `tailscale0` + LAN, deny all else    |
| XRDP      | `services.xrdp`              | RDP server on localhost + Tailscale only   |
| XFCE      | `services.xserver.desktopManager.xfce` | Lightweight desktop, fast over RDP |
| SSH       | `services.openssh`            | Terminal access over Tailscale              |

Three services. No Java, no web apps, no databases.

## Why these choices

### XFCE over GNOME

| Desktop | RAM idle | RDP feel  | Notes                                             |
|---------|---------|-----------|---------------------------------------------------|
| XFCE    | ~300 MB | Snappy    | Lightweight, composes well over RDP               |
| MATE    | ~400 MB | Good      | Similar to XFCE, slightly heavier                 |
| GNOME   | ~800 MB | Sluggish  | Wayland animations and compositing hurt RDP perf  |
| KDE     | ~600 MB | Mixed     | Better than GNOME, worse than XFCE               |

GNOME is great locally but heavy over remote. On an N150 (4 Alder Lake-N E-cores),
the freed-up RAM and CPU go to actual server workloads.

### Direct RDP over Guacamole

Apache Guacamole gives browser-based access but adds a full Java/Tomcat stack,
a guacd daemon, and XML or database config. For a personal server, a native RDP
client is simpler:

- **Microsoft Remote Desktop** — free on Mac, iOS, Android, Windows
- **Remmina** — free on Linux

One app, one connection to `100.x.x.x`, done.

### Tailscale over VPN / port forwarding

- Zero config on the router — no port forwarding rules to maintain
- WireGuard encryption built in
- Works across NATs, cell networks, and roaming
- Access control via Tailscale ACLs if needed later

## Firewall rules

```
Trusted interfaces: tailscale0
Allowed UDP:        Tailscale port (41641)
Reverse path check: loose (required for Tailscale)
LAN access:         192.168.0.0/16 → SSH (22), XRDP (3389)
Public:             nothing
```

## How to connect

1. Install Tailscale on your device and join your Tailnet
2. Open your RDP client
3. Connect to `100.x.x.x` (your mini PC's Tailscale IP)
4. Log in with your NixOS user credentials
5. Full XFCE desktop in the RDP window

For SSH: `ssh nixpi@100.x.x.x`

## First boot steps

After deploying the NixOS config:

1. `sudo tailscale up` — authenticates the machine to your Tailnet (one-time)
2. Change the default user password
3. Verify firewall: `sudo nft list ruleset` — confirm only LAN + Tailscale allowed
4. Test RDP from a Tailscale-connected device

## Gotchas

- **XRDP + active local session**: Log out the local XFCE session before connecting
  via RDP, or configure XRDP for a separate session — two sessions on the same user
  can cause a black screen
- **Tailscale auth**: `tailscale up` must be run once interactively after first boot
  to authenticate via browser
- **nftables**: NixOS + Tailscale works best with nftables (`networking.nftables.enable = true`)
  rather than legacy iptables

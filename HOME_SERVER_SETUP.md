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

### Remote access options

The core question: **browser only** vs **native client**.

#### Guacamole

HTML5 gateway that proxies RDP/VNC/SSH through a web browser. No client app needed — open a URL and you're in.

| | |
|---|---|
| **Access** | Any browser, any device — including ones you can't install apps on |
| **Protocols** | RDP, VNC, SSH — all in one |
| **Stack** | Java/Tomcat + guacd daemon + config (XML or database) |
| **NixOS** | `services.guacamole-server` + `services.guacamole-client` (available, but more config) |
| **Performance** | Good — HTML5 canvas rendering, slightly more latency than native |
| **Upside** | Zero client install, works on locked-down devices (work laptop, library PC) |
| **Downside** | Heavier server-side stack; needs a reverse proxy (nginx) in front for HTTPS |

To keep it secure: put Guacamole on `localhost` and expose it only over Tailscale via nginx with HTTPS.

#### Direct RDP (XRDP)

Native RDP server, connect with a dedicated client app.

| | |
|---|---|
| **Access** | Requires RDP client (Microsoft Remote Desktop, Remmina) |
| **Stack** | XRDP + desktop — that's it |
| **NixOS** | `services.xrdp` — minimal config |
| **Performance** | Best — RDP is a purpose-built protocol, lower latency |
| **Upside** | Simpler server setup, faster feel |
| **Downside** | Client app required on every device |

#### noVNC

Lightweight browser-based VNC viewer. Runs a VNC server on the machine + a small websocket proxy, the browser connects directly.

| | |
|---|---|
| **Access** | Browser only — like Guacamole but much lighter |
| **Stack** | VNC server (TigerVNC) + websockify proxy — no Java |
| **NixOS** | `services.tigervnc` + `services.websockify` or manual setup |
| **Performance** | Decent — VNC is less efficient than RDP, noticeable over high latency |
| **Upside** | Much simpler than Guacamole, still browser-only |
| **Downside** | VNC has no built-in encryption — must be tunnelled over Tailscale |

#### Rustdesk (self-hosted)

Open-source TeamViewer/AnyDesk alternative. Has a self-hosted relay server and native clients.

| | |
|---|---|
| **Access** | Native client (Windows, Mac, Linux, iOS, Android) + experimental web client |
| **Stack** | `hbbr` + `hbbs` relay/rendezvous servers |
| **Performance** | Excellent — proprietary protocol tuned for low latency |
| **Upside** | Works without Tailscale — handles NAT traversal itself |
| **Downside** | Needs client install; web client is beta and limited |

#### Comparison summary

| Option     | Browser-only | Server complexity | Performance | NixOS support |
|------------|:------------:|:-----------------:|:-----------:|:-------------:|
| Guacamole  | Yes          | High (Java stack) | Good        | Yes           |
| noVNC      | Yes          | Low               | Fair        | Partial       |
| XRDP       | No           | Low               | Best        | Yes           |
| Rustdesk   | Partial      | Medium            | Excellent   | Community     |

#### Recommendation

If browser-only access matters (no app installs, access from any device), **Guacamole** is the right call despite the heavier stack. The setup on NixOS:

```
Tailscale → nginx (HTTPS, :443) → Guacamole (:8080) → guacd → XRDP/VNC/SSH
```

Everything stays on `localhost` except nginx on the Tailscale interface. No public ports.

If you only ever connect from your own devices and don't mind installing one app, direct RDP is simpler and faster.

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

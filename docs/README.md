# Documentation

## Architecture

nixpi runs as a NixOS desktop workstation. All system configuration is declarative and lives in this repo.

**Key config files:**

- [`flake.nix`](../flake.nix) — Flake definition: dev shell, NixOS configuration, llm-agents.nix input
- [`infra/nixos/desktop.nix`](../infra/nixos/desktop.nix) — Primary config: packages, services, firewall, pi activation script
- [`infra/nixos/hosts/desktop.nix`](../infra/nixos/hosts/desktop.nix) — Host-specific hardware (boot, disk, CPU)
- [`AGENTS.md`](../AGENTS.md) — Agent behavior guidelines and safety rules

## Services

| Service | Config location | Notes |
|---------|----------------|-------|
| SSH | `desktop.nix` — `services.openssh` | Hardened; restricted to Tailscale + LAN |
| RDP | `desktop.nix` — `services.xrdp` | XFCE desktop; restricted to Tailscale + LAN |
| Tailscale | `desktop.nix` — `services.tailscale` | VPN for secure remote access |
| Syncthing | `desktop.nix` — `services.syncthing` | File sync; GUI on loopback (SSH tunnel) |
| pi | `desktop.nix` — `environment.systemPackages` | Nix-packaged via llm-agents.nix |
| Claude Code | `desktop.nix` — `environment.systemPackages` | Nix-packaged via llm-agents.nix |

## Planned Docs

- Risk tiers and trust model
- Data and secrets policy

Previous versions of these docs can be recovered from git history.

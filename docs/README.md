# Documentation

## Architecture

nixpi runs as a NixOS desktop workstation (physical or VM). All system configuration is declarative and lives in this repo.

**Key config files:**

- [`flake.nix`](../flake.nix) — Flake definition: dev shell, NixOS configuration, llm-agents.nix input
- [`infra/nixos/base.nix`](../infra/nixos/base.nix) — Headless config: packages, SSH, Tailscale, Syncthing, firewall, pi activation script
- [`infra/nixos/desktop.nix`](../infra/nixos/desktop.nix) — UI layer: XFCE, audio, RDP, printing
- [`infra/nixos/hosts/nixpi.nix`](../infra/nixos/hosts/nixpi.nix) — Physical desktop hardware (boot, disk, CPU)
- [`AGENTS.md`](../AGENTS.md) — Agent behavior guidelines and safety rules

## Services

| Service | Config location | Notes |
|---------|----------------|-------|
| SSH | `base.nix` — `services.openssh` | Hardened; restricted to Tailscale + LAN |
| Tailscale | `base.nix` — `services.tailscale` | VPN for secure remote access |
| Syncthing | `base.nix` — `services.syncthing` | File sync; GUI restricted to Tailscale + LAN |
| Chromium | `base.nix` — `programs.chromium` | CDP-compatible browser for AI agent automation |
| XFCE | `desktop.nix` — `services.xserver` | Lightweight desktop environment |
| RDP | `desktop.nix` — `services.xrdp` | XFCE desktop; restricted to Tailscale + LAN |
| Audio | `desktop.nix` — `services.pipewire` | PipeWire audio stack |
| pi | `base.nix` — `environment.systemPackages` | Nix-packaged via llm-agents.nix |
| Claude Code | `base.nix` — `environment.systemPackages` | Nix-packaged via llm-agents.nix |

## Planned Docs

- Risk tiers and trust model
- Data and secrets policy

Previous versions of these docs can be recovered from git history.

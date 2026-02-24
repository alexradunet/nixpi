# Documentation

## Architecture

nixpi runs as a NixOS QEMU/KVM guest. All system configuration is declarative and lives in this repo.

**Key config files:**

- [`flake.nix`](../flake.nix) — Flake definition: dev shell, NixOS configurations, VM image output
- [`infra/nixos/vm.nix`](../infra/nixos/vm.nix) — Shared VM module: packages, services, `pi`/`claude` wrappers, code-server, Tailscale, SSH
- [`infra/nixos/hosts/nixpi.nix`](../infra/nixos/hosts/nixpi.nix) — Host-specific boot/disk layout (machine-local, not portable)
- [`AGENTS.md`](../AGENTS.md) — Agent behavior guidelines and safety rules

## Services

| Service | Config location | Notes |
|---------|----------------|-------|
| code-server | `vm.nix` — `services.code-server` | Port 8080, auth disabled by default |
| Tailscale | `vm.nix` — `services.tailscale` | VPN daemon; run `tailscale up` to authenticate |
| OpenSSH | `vm.nix` — `services.openssh` | Root login disabled |
| QEMU guest agent | `vm.nix` — `services.qemuGuest` | VM integration (clipboard, resize) |

## Planned Docs

- Risk tiers and trust model
- Data and secrets policy

Previous versions of these docs can be recovered from git history.

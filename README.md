# nixpi

nixpi is an AI-first operating environment built on NixOS. The AI agent is the primary control layer; Linux provides the execution layer underneath.

## What's Included

| Component | Description |
|-----------|-------------|
| **NixOS Desktop** | Declarative XFCE desktop config (`infra/nixos/desktop.nix`) |
| **`pi` command** | [pi-coding-agent](https://github.com/badlogic/pi-mono) via llm-agents.nix (Nix-packaged) |
| **`claude` command** | [Claude Code](https://github.com/anthropics/claude-code) via llm-agents.nix (Nix-packaged) |
| **SSH** | OpenSSH with hardened settings, restricted to local network and Tailscale |
| **RDP** | xrdp serving XFCE desktop, restricted to local network and Tailscale |
| **Tailscale** | VPN for secure remote access |
| **Syncthing** | File synchronization (GUI on loopback, accessible via SSH tunnel) |

## Access Methods

```
Local Network / Tailscale → SSH  (port 22)   → Terminal / VS Code Remote SSH
Local Network / Tailscale → RDP  (port 3389) → XFCE Desktop
```

All inbound ports are restricted to Tailscale (100.0.0.0/8) and local network (192.168.0.0/16, 10.0.0.0/8) via nftables rules.

## Project Structure

```
nixpi/
  AGENTS.md                    # Agent behavior guidelines
  flake.nix                    # Flake: dev shell + NixOS configurations
  flake.lock
  infra/nixos/
    desktop.nix                # Primary config (packages, services, firewall)
    hosts/
      desktop.nix              # Physical desktop hardware (boot, disk, CPU)
      vm.nix                   # VM hardware template (QEMU/KVM guest)
  scripts/
    check.sh                   # Runs `nix flake check --no-build`
```

## Getting Started

### Rebuild NixOS after config changes

From the repo root (`nixos-rebuild` auto-selects the config matching your hostname):

```bash
sudo nixos-rebuild switch --flake .
```

### Connect via SSH

```bash
ssh nixpi@<tailscale-ip>
```

### Connect via RDP

Use any RDP client (Windows Remote Desktop, Remmina, etc.) to connect to `<tailscale-ip>:3389`.

### Access Syncthing web UI

Syncthing listens on loopback only. Use an SSH tunnel:

```bash
ssh -L 8384:localhost:8384 nixpi@<tailscale-ip>
```

Then open `http://localhost:8384` in your browser.

### Use the AI agents

Both commands are available system-wide:

```bash
pi          # pi-coding-agent
claude      # Claude Code
```

## Dev Shell

A local development shell is available via the flake:

```bash
nix develop
```

Provides: git, Node.js 22, sqlite, jq, ripgrep, fd.

## Build & Check

```bash
# Validate flake outputs
nix flake check --no-build

# Project check script
./scripts/check.sh
```

## VM Setup

To run this config in a QEMU/KVM virtual machine:

1. Install NixOS in a VM, then clone this repo.
2. Generate hardware config to find your root UUID:
   ```bash
   nixos-generate-config --show-hardware-config
   ```
3. Copy the root filesystem UUID into `infra/nixos/hosts/vm.nix`.
4. Rebuild:
   ```bash
   sudo nixos-rebuild switch --flake .#nixpi-vm
   ```

On subsequent rebuilds, `sudo nixos-rebuild switch --flake .` will auto-select `nixpi-vm` by hostname.

## Updating AI Tools

Pi and Claude Code are pinned in `flake.lock` via the llm-agents.nix input. To update:

```bash
nix flake update llm-agents
sudo nixos-rebuild switch --flake .
```

## Core Principles

- **Safety first**: strict risk tiers, protected paths, approval for high-risk actions
- **Reproducibility**: declarative config and version pinning (Nix flakes)
- **Recoverability**: rollback via NixOS generations
- **Auditability**: every important action has traceable intent and outcome

## Operational Safety Defaults

- No plaintext user password is committed in NixOS config.
- All inbound services are restricted to Tailscale and local network via nftables.
- Automatic Nix garbage collection runs weekly (removes generations older than 30 days).

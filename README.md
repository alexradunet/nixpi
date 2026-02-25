# nixpi

nixpi is an AI-first operating environment built on NixOS with Pi.Dev as the main AI agent harness, that is considered a first-class citizen. The AI agent is the primary control layer; Linux provides the execution layer underneath.

## What's Included

| Component | Description |
|-----------|-------------|
| **NixOS Base** | Declarative headless config (`infra/nixos/base.nix`): SSH, Tailscale, Syncthing, packages |
| **NixOS Desktop** | UI layer (`infra/nixos/desktop.nix`): XFCE, audio, RDP |
| **`pi` command** | [pi-coding-agent](https://github.com/badlogic/pi-mono) via llm-agents.nix (Nix-packaged) |
| **`claude` command** | [Claude Code](https://github.com/anthropics/claude-code) via llm-agents.nix (Nix-packaged) | Optional for development as Pi does not support Claude oAuth |
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
    base.nix                   # Headless config (packages, SSH, Tailscale, Syncthing, firewall)
    desktop.nix                # UI layer (XFCE, audio, RDP, printing)
    hosts/
      desktop.nix              # Physical desktop hardware (boot, disk, CPU)
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

## Adding a New Machine

To run this config on a new machine (physical or VM):

1. Install NixOS, then clone this repo.
2. Generate hardware config:
   ```bash
   nixos-generate-config --show-hardware-config
   ```
3. Save the output as `infra/nixos/hosts/<hostname>.nix` (set `networking.hostName`).
4. Add a new `nixosConfigurations.<hostname>` entry in `flake.nix`:
   ```nix
   nixosConfigurations.<hostname> = nixpkgs.lib.nixosSystem {
     inherit system;
     modules = [
       { nixpkgs.overlays = [ llm-agents.overlays.default ]; }
       ./infra/nixos/base.nix        # always include
       # ./infra/nixos/desktop.nix   # omit for headless
       ./infra/nixos/hosts/<hostname>.nix
     ];
   };
   ```
5. Rebuild:
   ```bash
   sudo nixos-rebuild switch --flake .
   ```

On subsequent rebuilds, `sudo nixos-rebuild switch --flake .` will auto-select the config by hostname.

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

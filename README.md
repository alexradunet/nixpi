# nixpi

nixpi is an AI-first operating environment built on NixOS. The AI agent is the primary control layer; Linux provides the execution layer underneath.

## What's Included

| Component | Description |
|-----------|-------------|
| **NixOS VM** | QEMU/KVM guest with declarative config (`infra/nixos/vm.nix`) |
| **`pi` command** | Wrapper for [pi-coding-agent](https://github.com/nicholasgasior/pi-coding-agent) (installed system-wide) |
| **`claude` command** | Wrapper for [Claude Code](https://github.com/anthropics/claude-code) (installed system-wide) |
| **code-server** | Browser-accessible VS Code on port 8080 |
| **Tailscale** | VPN for secure remote access |
| **SSH** | OpenSSH with root login disabled |

## Project Structure

```
nixpi/
  AGENTS.md              # Agent behavior guidelines
  flake.nix              # Flake: dev shell, NixOS config, VM image build
  flake.lock
  infra/nixos/
    vm.nix               # Shared VM module (packages, services, agent wrappers)
    hosts/nixpi.nix      # Host-specific boot/disk config (machine-local)
  scripts/
    check.sh             # Runs `nix flake check --no-build`
  docs/
    README.md            # Documentation index
```

## Getting Started

### Build the VM image

```bash
nix build .#vm-qcow
```

This produces a QEMU qcow2 image you can boot in QEMU, libvirt, or GNOME Boxes.

### Rebuild NixOS after config changes

From inside the running VM (run from the repo root):

```bash
sudo nixos-rebuild switch --flake .#nixpi
```

### Access code-server

code-server runs on port 8080 with no auth by default. For secure access, use an SSH tunnel:

```bash
ssh -L 8080:localhost:8080 nixpi@<vm-ip>
```

Then open `http://localhost:8080` in your browser.

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

## Core Principles

- **Safety first**: strict risk tiers, protected paths, approval for high-risk actions
- **Reproducibility**: declarative config and version pinning (Nix flakes)
- **Recoverability**: rollback via NixOS generations + VM snapshots
- **Auditability**: every important action has traceable intent and outcome

## Operational Safety Defaults

- No plaintext user password is committed in NixOS config.
- Repo bootstrap-on-boot is disabled by default (opt-in in `infra/nixos/vm.nix`).
- Automatic repo pull timer is disabled by default to avoid unreviewed drift.
- Manual repo bootstrap and sync are available via systemd services:
  ```bash
  sudo systemctl start nixpi-repo-bootstrap.service
  sudo systemctl start nixpi-repo-update.service
  ```

## Repository Notes

- `infra/nixos/vm.nix` is the shared VM module (packages, services, agent tooling).
- `infra/nixos/hosts/nixpi.nix` is host-specific (boot disk + filesystem UUIDs) and should be treated as machine-local.

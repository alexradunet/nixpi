# Nixpi

Nixpi is an AI-first operating environment built on NixOS. **Nixpi** is the product/user-facing assistant layer, and **Pi** is the underlying SDK/agent harness. The AI agent is the primary control layer; Linux provides the execution layer underneath.

## What's Included

| Component | Description |
|-----------|-------------|
| **NixOS Base** | Declarative system config (`infra/nixos/base.nix`): SSH, ttyd, Tailscale, Syncthing, packages |
| **GNOME Desktop (default)** | local HDMI monitor setup path (GDM + GNOME) for first-boot Wi-Fi/display configuration |
| **Desktop reuse mode** | if an existing desktop UI is detected, host config preserves it instead of replacing with the GNOME default |
| **VS Code** | Installed system-wide as `vscode` for GUI editing on the desktop |
| **Simple Text Editor** | Installed system-wide as `nano` for quick file edits |
| **`nixpi` command** | Primary Nixpi CLI wrapper (single instance), powered by Pi SDK |
| **`pi` command** | [pi-coding-agent](https://github.com/badlogic/pi-mono) via lightweight npm-backed wrapper (SDK/advanced CLI) |
| **`claude` command** | Claude Code CLI from nixpkgs unstable (`claude-code-bin`), patched for NixOS |
| **SSH** | OpenSSH with hardened settings, restricted to local network and Tailscale |
| **ttyd** | Web terminal interface (`http://<tailscale-ip>:7681`), restricted to Tailscale via nftables |
| **Tailscale** | VPN for secure remote access |
| **Syncthing** | File synchronization (GUI on `0.0.0.0:8384`, restricted to Tailscale via nftables) |

## Services Reference

| Service | Config location | Notes |
|---------|----------------|-------|
| SSH | `base.nix` — `services.openssh` | Hardened; reachable from Tailscale + LAN (bootstrap path) |
| GNOME Desktop (default) | `base.nix` — `services.xserver.*` | Local HDMI-first onboarding path (GDM + GNOME + Wi-Fi tray tooling) |
| Desktop reuse mode | `base.nix` + `scripts/add-host.sh` | If existing desktop options are detected, host file sets `nixpi.desktopProfile = "preserve"` and keeps current UI |
| ttyd | `base.nix` — `services.ttyd` | Web terminal on port 7681; Tailscale-only; delegates login to localhost SSH |
| Tailscale | `base.nix` — `services.tailscale` | VPN for secure remote access |
| Syncthing | `base.nix` — `services.syncthing` | File sync; GUI + sync ports are Tailscale-only |
| Chromium | `base.nix` — `programs.chromium` | CDP-compatible browser for AI agent automation |
| VS Code | `base.nix` — `environment.systemPackages` | Desktop code editor (`vscode`) |
| Simple Text Editor | `base.nix` — `environment.systemPackages` | Lightweight terminal editor (`nano`) |
| nixpi | `base.nix` — `nixpiCli` + `environment.systemPackages` | Primary CLI wrapper (`nixpi`) |
| pi | `base.nix` — `piWrapper` + `environment.systemPackages` | npm-backed wrapper for SDK/advanced CLI |
| claude | `base.nix` — `environment.systemPackages` (`pkgsUnstable."claude-code-bin"`) | Claude Code CLI (`claude`) from nixpkgs unstable binary package |

## Access Methods

```
Local HDMI monitor        → GNOME/UI  (default or preserved) → Local Wi-Fi/display onboarding
Local Network / Tailscale → SSH       (port 22)   → Terminal / VS Code Remote SSH
Tailscale only            → ttyd      (port 7681) → Browser terminal (SSH to localhost)
Tailscale only            → Syncthing (port 8384) → Web GUI
```

Firewall scope is split by service: SSH remains available from local network and Tailscale; ttyd and Syncthing are Tailscale-only.

## Project Structure

```
Nixpi/
  AGENTS.md                    # Agent behavior + policy for assistants
  CONTRIBUTING.md              # Developer workflow and contribution rules
  flake.nix                    # Flake: dev shell + NixOS configurations
  flake.lock
  docs/
    README.md                  # Docs hub
    runtime/OPERATING_MODEL.md # Runtime/evolution operating model
    agents/                    # Agent role contracts + handoff templates
    ux/EMOJI_DICTIONARY.md     # Visual communication dictionary
    meta/                      # Docs style + source-of-truth map
  infra/
    nixos/
      base.nix                 # Base config + GNOME desktop + web terminal + nixpi wrapper + profile seeding
      hosts/
        nixpi.nix              # Physical machine hardware (boot, disk, CPU)
    pi/skills/                 # Nixpi skills directory (canonical index: docs/agents/SKILLS.md)
  scripts/
    bootstrap-fresh-nixos.sh   # Clone + guided Pi install workflow for fresh NixOS installs
    add-host.sh                # Generate a new host config from hardware
    test.sh                    # Run repository shell test suite
    check.sh                   # Run tests + flake checks
    verify-nixpi.sh            # Post-rebuild nixpi wrapper smoke test
    new-handoff.sh             # Scaffold a standards-compliant handoff file
    list-handoffs.sh           # List handoff files (supports type/date filters)
  tests/
    helpers.sh                 # Shared test assertion helpers
    test_*.sh                  # Policy/tooling regression tests
```

## Flake Layout Policy

- The canonical flake entrypoint is kept at repository root: `./flake.nix` and `./flake.lock`.
- This keeps `nix flake check`, `nix develop`, and `nixos-rebuild --flake .` standard and predictable.
- If subflakes are introduced later, root flake remains the primary pre-release interface.

## Getting Started

For a full reinstall on a fresh NixOS install, use:
- [`docs/runtime/REINSTALL.md`](./docs/runtime/REINSTALL.md)

Fresh-install one-shot (assumes `git` is absent and flakes are disabled by default):

```bash
nix --extra-experimental-features "nix-command flakes" shell nixpkgs#git -c git clone https://github.com/alexradunet/nixpi.git Nixpi && cd ~/Nixpi && ./scripts/bootstrap-fresh-nixos.sh
```

Step-by-step equivalent:

```bash
nix --extra-experimental-features "nix-command flakes" shell nixpkgs#git -c git clone https://github.com/alexradunet/nixpi.git Nixpi
cd ~/Nixpi
./scripts/bootstrap-fresh-nixos.sh
```

`bootstrap-fresh-nixos.sh` refreshes `infra/nixos/hosts/$(hostname).nix` from local hardware, maps Nixpi to your current installer user, then launches Pi with the `install-nixpi` skill for guided review + first rebuild.

For unattended installs, you can run:

```bash
./scripts/bootstrap-fresh-nixos.sh --non-interactive
```

For preview-only planning (no changes applied):

```bash
./scripts/bootstrap-fresh-nixos.sh --dry-run
```

When `add-host.sh` runs on a machine that already has a desktop UI configured, it preserves that desktop automatically (`nixpi.desktopProfile = "preserve"`) instead of replacing it with the GNOME default.

### Rebuild NixOS after config changes

From the repo root (`nixos-rebuild` auto-selects the config matching your hostname):

```bash
sudo nixos-rebuild switch --flake .
```

Fresh-install first rebuild only (when flakes are not yet enabled):

```bash
sudo env NIX_CONFIG="experimental-features = nix-command flakes" nixos-rebuild switch --flake "path:$PWD#$(hostname)"
```

Only needed for the very first flake rebuild on a fresh system. After this succeeds once, Nixpi has already enabled flakes system-wide (`nix.settings.experimental-features`), so regular rebuilds can use:

```bash
sudo nixos-rebuild switch --flake .
```

### Connect via SSH

```bash
ssh <username>@<tailscale-ip>
```

### Access ttyd web terminal

Open `http://<tailscale-ip>:7681` in your browser. ttyd is Tailscale-only via nftables and opens an SSH login prompt to localhost.

### Access Syncthing web UI

Open `http://<tailscale-ip>:8384` in your browser. The GUI is Tailscale-only via nftables.

### Use the AI agents

Commands available system-wide:

```bash
nixpi           # Nixpi assistant (single instance; see docs/agents/SKILLS.md)
pi              # Pi SDK/advanced CLI
claude          # Claude Code CLI (installed from nixpkgs unstable binary package)
```

`pi` remains available as SDK/advanced CLI when you need direct Pi behavior.

`claude` is provided declaratively by NixOS; you should not need to run `claude install`.

Install Pi extensions with a commit-friendly manifest:

```bash
nixpi npm install @scope/extension@1.2.3
nixpi npm install npm:@scope/extension@1.2.3
nixpi npm sync
```

This installs pinned extensions in your active Nixpi profile and records their sources in `infra/pi/extensions/packages.json` (tracked in git). Use `nixpi npm sync` to rebuild runtime extension state from the manifest.

Apply/rollback system evolution with guardrails:

```bash
nixpi evolve
nixpi rollback
```

`nixpi evolve` runs `sudo nixos-rebuild switch --flake .`, then executes `./scripts/verify-nixpi.sh`; if validation fails, it automatically runs rollback.

Single Nixpi instance: `~/Nixpi/.pi/agent/`

Optional host override (if you need a different layout):

```nix
# infra/nixos/hosts/<hostname>.nix
{ config, ... }:
{
  nixpi.repoRoot = "/home/<user>/Nixpi";
  nixpi.piDir = "${config.nixpi.repoRoot}/.pi/agent";
  nixpi.primaryUserDisplayName = "Alex";
}
```

### Is Nixpi preinstalled?
Yes. After `nixos-rebuild switch --flake .`, `nixpi` is installed automatically as part of the system configuration (along with `pi` and `claude`). No separate `pi install` or `claude install` step is required.

## Dev Shell

A local development shell is available via the flake:

```bash
nix develop
```

Provides: git, Node.js 22, sqlite, jq, ripgrep, fd, and language servers (nixd, bash-language-server, shellcheck, typescript-language-server).

## Build & Check

```bash
# Run repository tests
./scripts/test.sh

# Full project checks (tests + flake checks)
./scripts/check.sh

# Optional strict check (also builds one host system closure)
NIXPI_CHECK_BUILD=1 NIXPI_CHECK_HOST=$(hostname) ./scripts/check.sh

# Optional direct flake validation
nix flake check --no-build

# Post-rebuild smoke check for nixpi single-instance wrapper
./scripts/verify-nixpi.sh
```

## Development Rules

- Development model and contribution policy: [`CONTRIBUTING.md`](./CONTRIBUTING.md)
- Agent behavior policy: [`AGENTS.md`](./AGENTS.md)
- Agent skills index: [`docs/agents/SKILLS.md`](./docs/agents/SKILLS.md)
- Documentation hub: [`docs/README.md`](./docs/README.md)
- Runtime operating model: [`docs/runtime/OPERATING_MODEL.md`](./docs/runtime/OPERATING_MODEL.md)
- Agents overview and responsibilities: [`docs/agents/README.md`](./docs/agents/README.md)
- Source-of-truth precedence: [`docs/meta/SOURCE_OF_TRUTH.md`](./docs/meta/SOURCE_OF_TRUTH.md)
- Emoji concept dictionary (visual communication): [`docs/ux/EMOJI_DICTIONARY.md`](./docs/ux/EMOJI_DICTIONARY.md)
- Documentation style guide: [`docs/meta/DOCS_STYLE.md`](./docs/meta/DOCS_STYLE.md)

## Runtime Model (High Level)

See the full runtime and evolution workflow in the [Operating Model](./docs/runtime/OPERATING_MODEL.md) and agent role contracts in [Agents Overview](./docs/agents/README.md).

- **End users do not need `pi install`** for core Nixpi — `nixpi` and `pi` are provided declaratively by NixOS config.
- `nixpi` → single Nixpi instance (primary user command).
- Nixpi uses a multi-agent model (Hermes, Athena, Hephaestus, Themis) where the runtime does not directly rewrite live core; it creates evolution requests handled through planned, tested, reviewable changes.

## Adding a New Machine

The flake auto-discovers hosts from `infra/nixos/hosts/`. Just add a file and rebuild:

1. Install NixOS, clone this repo, then run:
   ```bash
   ./scripts/add-host.sh            # uses current hostname
   ./scripts/add-host.sh myhost     # or specify one
   ```
2. Review the generated file, then:
   ```bash
   git add infra/nixos/hosts/<hostname>.nix
   sudo nixos-rebuild switch --flake .
   ```

On subsequent rebuilds, `sudo nixos-rebuild switch --flake .` auto-selects the config by hostname.

## Updating Pi

Pi is installed via npm-backed wrapper in `infra/nixos/base.nix` (`piWrapper`).
To update, bump the package spec there, then rebuild:

```bash
sudo nixos-rebuild switch --flake .
```

## Updating Claude Code

Claude Code is installed from nixpkgs unstable (`pkgsUnstable."claude-code-bin"` in `infra/nixos/base.nix`).
To update Claude Code, refresh the unstable flake input and rebuild:

```bash
nix flake update nixpkgs-unstable
sudo nixos-rebuild switch --flake .
```

## Core Principles

Safety, reproducibility, recoverability, auditability, standards-first, and pre-release simplicity. Full policy definitions are in [AGENTS.md](./AGENTS.md).

## Operational Safety Defaults

- No plaintext user password is committed in NixOS config.
- All inbound services are restricted to Tailscale and local network via nftables.
- Automatic Nix garbage collection runs weekly (removes generations older than 30 days).

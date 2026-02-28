# Nixpi

Nixpi is an AI-first operating environment built on NixOS. The AI agent is the primary control layer; Linux provides the execution layer underneath.

## What's Included

| Component | Description |
|-----------|-------------|
| **NixOS Base** | Declarative system config (`infra/nixos/base.nix`): SSH, networking, nixpi-agent user, packages. Toggleable service modules in `infra/nixos/modules/` |
| **@nixpi/core** | Shared TypeScript domain library: ObjectStore, JsYamlFrontmatterParser, typed interfaces (`packages/nixpi-core/`) |
| **Object Store** | Flat-file markdown with YAML frontmatter in `data/objects/` (Syncthing-synced); shell + TS implementations |
| **Matrix Bridge** | matrix-bot-sdk adapter (`services/matrix-bridge/`); receives messages, processes through Pi |
| **Heartbeat Timer** | Systemd timer for periodic agent observation cycles (`infra/nixos/modules/heartbeat.nix`) |
| **OpenPersona** | 4-layer identity model (SOUL, BODY, FACULTY, SKILL) in `persona/` |
| **GNOME Desktop (default)** | local HDMI monitor setup path (GDM + GNOME) for first-boot Wi-Fi/display configuration |
| **Desktop reuse mode** | if an existing desktop UI is detected, host config preserves it instead of replacing with the GNOME default |
| **VS Code** | Installed system-wide as `vscode` for GUI editing on the desktop |
| **`nixpi` command** | Primary Nixpi CLI wrapper (single instance) |
| **`claude` command** | Claude Code CLI from nixpkgs unstable (`claude-code-bin`), patched for NixOS |
| **SSH** | OpenSSH with hardened settings, restricted to local network and Tailscale |
| **ttyd** | Web terminal interface (`http://<tailscale-ip>:7681`), restricted to Tailscale via nftables |
| **Tailscale** | VPN for secure remote access |
| **Syncthing** | File synchronization (GUI on `0.0.0.0:8384`, restricted to Tailscale via nftables) |

## Services Reference

| Service | Config location | Enable flag | Notes |
|---------|----------------|-------------|-------|
| SSH | `base.nix` — `services.openssh` | always on | Hardened; reachable from Tailscale + LAN (bootstrap path) |
| Heartbeat | `modules/heartbeat.nix` — systemd timer | `nixpi.heartbeat.enable` | Periodic agent observation cycle; configurable interval |
| Matrix Bridge | `modules/matrix.nix` — systemd service | `nixpi.matrix.enable` | matrix-bot-sdk adapter; processes messages through Pi; user allowlist |
| Desktop | `modules/desktop.nix` | `nixpi.desktop.enable` | GNOME/GDM + Wi-Fi tray tooling, VS Code, Chromium; preserves existing desktop if detected |
| ttyd | `modules/ttyd.nix` | `nixpi.ttyd.enable` | Web terminal on port 7681; Tailscale-only; delegates login to localhost SSH |
| Tailscale | `modules/tailscale.nix` | `nixpi.tailscale.enable` | VPN for secure remote access |
| Syncthing | `modules/syncthing.nix` | `nixpi.syncthing.enable` | File sync; GUI + sync ports are Tailscale-only |
| Password Policy | `modules/password-policy.nix` | `nixpi.passwordPolicy.enable` | Enforces password policy for the primary user |
| nixpi | `base.nix` — `nixpiCli` | always on | Primary CLI wrapper (`nixpi`); sources secrets from `/etc/nixpi/secrets/` |
| claude | `base.nix` — `environment.systemPackages` | always on | Claude Code CLI (`claude`) from nixpkgs unstable binary package |

## Access Methods

```
Local HDMI monitor        → GNOME/UI  (default or preserved) → Local Wi-Fi/display onboarding
Local Network / Tailscale → SSH       (port 22)   → Terminal / VS Code Remote SSH
Tailscale only            → ttyd      (port 7681) → Browser terminal (SSH to localhost)
Tailscale only            → Syncthing (port 8384) → Web GUI
```

Firewall scope is split by service: SSH remains available from local network and Tailscale; ttyd, Syncthing, and Conduit (Matrix) are Tailscale-only.

## Matrix Channel Setup

Nixpi includes a self-hosted Matrix messaging channel powered by Conduit (lightweight Rust homeserver) and matrix-bot-sdk. Message the bot from Element or any Matrix client over Tailscale.

Interactive setup (recommended):
```bash
nixpi --skill ./infra/pi/skills/matrix-setup/SKILL.md
```

Manual setup: see [Matrix Setup Guide](./docs/runtime/MATRIX_SETUP.md).

## Project Structure

```
Nixpi/
  AGENTS.md                    # Agent behavior + policy for assistants
  CONTRIBUTING.md              # Developer workflow and contribution rules
  flake.nix                    # Flake: dev shell + NixOS configurations
  flake.lock
  package.json                 # Root npm workspace config
  persona/                     # OpenPersona 4-layer identity (SOUL, BODY, FACULTY, SKILL)
  data/objects/                # Flat-file object store (gitignored, Syncthing-synced)
  docs/
    README.md                  # Docs hub
    runtime/OPERATING_MODEL.md # Runtime/evolution operating model
    runtime/MATRIX_SETUP.md    # Matrix channel setup guide
    agents/                    # Agent role contracts + handoff templates
    ux/EMOJI_DICTIONARY.md     # Visual communication dictionary
    meta/                      # Docs style + source-of-truth map
  packages/
    nixpi-core/                # @nixpi/core — shared domain lib (ObjectStore, frontmatter parser, types)
  services/
    matrix-bridge/             # Matrix → Pi bridge via matrix-bot-sdk (imports @nixpi/core)
  infra/
    nixos/
      base.nix                 # Core config: SSH, networking, nixpi-agent user, nixpi CLI, secrets
      lib/mk-nixpi-service.nix # Factory for systemd services with shared boilerplate
      modules/
        objects.nix            # Object store data directory provisioning
        heartbeat.nix          # Heartbeat timer (periodic agent observation cycle)
        matrix.nix             # Matrix bridge systemd service + Conduit homeserver
        tailscale.nix          # Tailscale VPN (nixpi.tailscale.enable)
        ttyd.nix               # Web terminal (nixpi.ttyd.enable)
        syncthing.nix          # File sync (nixpi.syncthing.enable)
        desktop.nix            # GNOME desktop + VS Code + Chromium (nixpi.desktop.enable)
        password-policy.nix    # Password policy (nixpi.passwordPolicy.enable)
      hosts/
        nixpi.nix              # Physical machine hardware (boot, disk, CPU)
        nixos.nix              # NixOS host configuration
    pi/skills/                 # Nixpi skills directory (canonical index: docs/agents/SKILLS.md)
  scripts/
    nixpi-object.sh            # Generic CRUD for flat-file objects (requires yq-go + jq)
    matrix-setup.sh            # One-shot Matrix account provisioning
    bootstrap-fresh-nixos.sh   # Clone + guided Pi install workflow for fresh NixOS installs
    add-host.sh                # Generate a new host config from hardware
    test.sh                    # Run repository shell test suite
    check.sh                   # Run tests + flake checks
    verify-nixpi.sh            # Post-rebuild nixpi wrapper smoke test
    new-handoff.sh             # Scaffold a standards-compliant handoff file
    list-handoffs.sh           # List handoff files (supports type/date filters)
  tests/
    helpers.sh                 # Shared test assertion helpers
    test_*.sh                  # Policy/tooling regression tests (shell + cross-tool)
```

## Flake Layout Policy

- The canonical flake entrypoint is kept at repository root: `./flake.nix` and `./flake.lock`.
- This keeps `nix flake check`, `nix develop`, and `nixos-rebuild --flake .` standard and predictable.
- If subflakes are introduced later, root flake remains the primary pre-release interface.
- The flake exports `nixosModules` for individual consumption: `.default`, `.base`, `.tailscale`, `.syncthing`, `.ttyd`, `.matrix`, `.heartbeat`, `.objects`, `.passwordPolicy`, `.desktop`.
- A flake template is available via `nix flake init -t github:alexradunet/nixpi`.

## Getting Started

### Flake template (recommended)

Scaffold a new Nixpi configuration from the flake template:

```bash
nix flake init -t github:alexradunet/nixpi
```

Then run the interactive setup wizard to configure hostname, username, AI provider, and module selection:

```bash
nixpi setup
```

First-run detection uses `/etc/nixpi/.setup-complete` to determine if the wizard has been run.

### Bootstrap (fresh NixOS)

For a full reinstall on a fresh NixOS install, see [`docs/runtime/REINSTALL.md`](./docs/runtime/REINSTALL.md).

Fresh-install one-shot (assumes `git` is absent and flakes are disabled by default):

```bash
nix --extra-experimental-features "nix-command flakes" shell nixpkgs#git -c git clone https://github.com/alexradunet/nixpi.git Nixpi && cd ~/Nixpi && ./scripts/bootstrap-fresh-nixos.sh
```

The bootstrap script runs as root, clones to `/tmp/nixpi-bootstrap`, and launches the setup wizard. It refreshes `infra/nixos/hosts/$(hostname).nix` from local hardware, then runs `nixpi setup` for guided module selection and first rebuild.

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
claude          # Claude Code CLI (installed from nixpkgs unstable binary package)
```

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
nixpi evolve [--yes]
nixpi rollback [--yes]
```

`nixpi evolve` runs `sudo nixos-rebuild switch --flake .`, then executes `./scripts/verify-nixpi.sh`; if validation fails, it automatically runs rollback. Use `--yes` to skip the interactive confirmation prompt (for unattended operations).

Services run as the `nixpi-agent` system user. Agent state is stored at `/var/lib/nixpi/agent/`. The primary user gets read access via the `nixpi` group.

Secrets are managed in `/etc/nixpi/secrets/` (root:root 0700). The `piWrapper` sources `ai-provider.env` for API key injection.

Optional host override (if you need a different layout):

```nix
# infra/nixos/hosts/<hostname>.nix
{ config, ... }:
{
  nixpi.repoRoot = "/home/<user>/Nixpi";
  nixpi.primaryUserDisplayName = "Alex";
}
```

### Is Nixpi preinstalled?
Yes. After `nixos-rebuild switch --flake .`, `nixpi` and `claude` are installed automatically as part of the system configuration. No separate install step is required.

## Dev Shell

A local development shell is available via the flake:

```bash
nix develop
```

Provides: git, Node.js 22, sqlite, jq, yq-go, ripgrep, fd, and language servers (nixd, bash-language-server, shellcheck, typescript-language-server).

The project uses npm workspaces (root `package.json`) with packages under `packages/` and `services/`.

## Build & Check

```bash
# Run repository shell tests
./scripts/test.sh

# Build and test @nixpi/core (TypeScript)
npm -w packages/nixpi-core run build
npm -w packages/nixpi-core test

# Build Matrix bridge
npm -w services/matrix-bridge run build

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

- 📝 Development model and contribution policy: [`CONTRIBUTING.md`](./CONTRIBUTING.md)
- 📋 Agent behavior policy: [`AGENTS.md`](./AGENTS.md)
- 📋 Agent skills index: [`docs/agents/SKILLS.md`](./docs/agents/SKILLS.md)
- 🗺️ Documentation hub: [`docs/README.md`](./docs/README.md)
- 🗺️ Runtime operating model: [`docs/runtime/OPERATING_MODEL.md`](./docs/runtime/OPERATING_MODEL.md)
- 📋 Agents overview and responsibilities: [`docs/agents/README.md`](./docs/agents/README.md)
- 🏷️ Source-of-truth precedence: [`docs/meta/SOURCE_OF_TRUTH.md`](./docs/meta/SOURCE_OF_TRUTH.md)
- 📖 Emoji concept dictionary (visual communication): [`docs/ux/EMOJI_DICTIONARY.md`](./docs/ux/EMOJI_DICTIONARY.md)
- 📋 Documentation style guide: [`docs/meta/DOCS_STYLE.md`](./docs/meta/DOCS_STYLE.md)

## Runtime Model (High Level)

See the full runtime and evolution workflow in the [Operating Model](./docs/runtime/OPERATING_MODEL.md) and agent role contracts in [Agents Overview](./docs/agents/README.md).

- **End users do not need separate install steps** — `nixpi` and `claude` are provided declaratively by NixOS config.
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

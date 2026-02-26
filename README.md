# nixpi

nixpi is an AI-first operating environment built on NixOS. **Nixpi** is the product/user-facing assistant layer, and **Pi** is the underlying SDK/agent harness. The AI agent is the primary control layer; Linux provides the execution layer underneath.

## What's Included

| Component | Description |
|-----------|-------------|
| **NixOS Base** | Declarative headless config (`infra/nixos/base.nix`): SSH, Cockpit, Tailscale, Syncthing, packages |
| **`nixpi` command** | Primary Nixpi CLI wrapper (runtime + dev modes), powered by Pi SDK |
| **`pi` command** | [pi-coding-agent](https://github.com/badlogic/pi-mono) via llm-agents.nix (Nix-packaged SDK/advanced CLI) |
| **`claude` command** | [Claude Code](https://github.com/anthropics/claude-code) via llm-agents.nix (Nix-packaged, optional — Pi does not support Claude oAuth) |
| **SSH** | OpenSSH with hardened settings, restricted to local network and Tailscale |
| **Cockpit** | Web admin interface (`https://<tailscale-ip>:9090`), restricted to local network and Tailscale |
| **Tailscale** | VPN for secure remote access |
| **Syncthing** | File synchronization (GUI on `0.0.0.0:8384`, restricted to Tailscale and LAN via nftables) |

## Services Reference

| Service | Config location | Notes |
|---------|----------------|-------|
| SSH | `base.nix` — `services.openssh` | Hardened; restricted to Tailscale + LAN |
| Cockpit | `base.nix` — `services.cockpit` | Web admin UI on port 9090; restricted to Tailscale + LAN |
| Tailscale | `base.nix` — `services.tailscale` | VPN for secure remote access |
| Syncthing | `base.nix` — `services.syncthing` | File sync; GUI restricted to Tailscale + LAN |
| Chromium | `base.nix` — `programs.chromium` | CDP-compatible browser for AI agent automation |
| nixpi | `base.nix` — `nixpiCli` + `environment.systemPackages` | Primary CLI wrapper (`nixpi`, `nixpi dev`) |
| pi | `base.nix` — `environment.systemPackages` | Nix-packaged via llm-agents.nix (SDK/advanced CLI) |
| Claude Code | `base.nix` — `environment.systemPackages` | Nix-packaged via llm-agents.nix |

## Access Methods

```
Local Network / Tailscale → SSH      (port 22)   → Terminal / VS Code Remote SSH
Local Network / Tailscale → Cockpit  (port 9090) → Web admin UI
```

All inbound ports are restricted to Tailscale (100.0.0.0/8) and local network (192.168.0.0/16, 10.0.0.0/8) via nftables rules.

## Project Structure

```
nixpi/
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
      base.nix                 # Headless config + web admin + nixpi wrapper + profile seeding
      hosts/
        nixpi.nix              # Physical machine hardware (boot, disk, CPU)
    pi/skills/                 # Pi/Nixpi skills (tdd, claude-consult)
  scripts/
    add-host.sh                # Generate a new host config from hardware
    test.sh                    # Run repository shell test suite
    check.sh                   # Run tests + flake checks
    verify-nixpi-modes.sh      # Post-rebuild nixpi wrapper smoke test
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

### Rebuild NixOS after config changes

From the repo root (`nixos-rebuild` auto-selects the config matching your hostname):

```bash
sudo nixos-rebuild switch --flake .
```

### Connect via SSH

```bash
ssh <username>@<tailscale-ip>
```

### Access Cockpit web admin

Open `https://<tailscale-ip>:9090` in your browser. Cockpit is restricted to Tailscale and local network via nftables.

### Access Syncthing web UI

Open `http://<tailscale-ip>:8384` in your browser. The GUI is restricted to Tailscale and local network via nftables.

### Use the AI agents

Commands available system-wide:

```bash
nixpi           # Nixpi normal/runtime mode (primary user command)
nixpi dev       # Nixpi developer mode (Pi-native + Nixpi skills/rules)
pi              # Pi SDK/advanced CLI
claude          # Claude Code
```

`pi` remains available as SDK/advanced CLI when you need direct Pi behavior.

### Is Nixpi preinstalled?
Yes. After `nixos-rebuild switch --flake .`, `nixpi` is installed automatically as part of the system configuration (along with `pi` and `claude`). No separate `pi install` step is required for core Nixpi.

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

# Optional direct flake validation
nix flake check --no-build

# Post-rebuild smoke check for nixpi runtime/dev wrapper modes
./scripts/verify-nixpi-modes.sh
```

## Development Rules

- Development model and contribution policy: [`CONTRIBUTING.md`](./CONTRIBUTING.md)
- Agent behavior policy: [`AGENTS.md`](./AGENTS.md)
- Pi TDD skill: [`infra/pi/skills/tdd/SKILL.md`](./infra/pi/skills/tdd/SKILL.md)
- Documentation hub: [`docs/README.md`](./docs/README.md)
- Runtime operating model: [`docs/runtime/OPERATING_MODEL.md`](./docs/runtime/OPERATING_MODEL.md)
- Agents overview and responsibilities: [`docs/agents/README.md`](./docs/agents/README.md)
- Source-of-truth precedence: [`docs/meta/SOURCE_OF_TRUTH.md`](./docs/meta/SOURCE_OF_TRUTH.md)
- Emoji concept dictionary (visual communication): [`docs/ux/EMOJI_DICTIONARY.md`](./docs/ux/EMOJI_DICTIONARY.md)
- Documentation style guide: [`docs/meta/DOCS_STYLE.md`](./docs/meta/DOCS_STYLE.md)
- Pi skills: [`infra/pi/skills/`](./infra/pi/skills/)

## Runtime Model (High Level)

See the full runtime and evolution workflow in the [Operating Model](./docs/runtime/OPERATING_MODEL.md) and agent role contracts in [Agents Overview](./docs/agents/README.md).

- **End users do not need `pi install`** for core Nixpi — `nixpi` and `pi` are provided declaratively by NixOS config.
- `nixpi` → runtime mode (primary user command). `nixpi dev` → developer mode.
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

## Updating AI Tools

Pi and Claude Code are pinned in `flake.lock` via the llm-agents.nix input. To update:

```bash
nix flake update llm-agents
sudo nixos-rebuild switch --flake .
```

## Core Principles

Safety, reproducibility, recoverability, auditability, standards-first, and pre-release simplicity. Full policy definitions are in [AGENTS.md](./AGENTS.md).

## Operational Safety Defaults

- No plaintext user password is committed in NixOS config.
- All inbound services are restricted to Tailscale and local network via nftables.
- Automatic Nix garbage collection runs weekly (removes generations older than 30 days).

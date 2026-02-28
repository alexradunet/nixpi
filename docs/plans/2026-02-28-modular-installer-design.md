# Nixpi Modular Installation System Design

**Date**: 2026-02-28
**Status**: Implemented

## Problem

Nixpi currently hardcodes several services in `base.nix` (~540 lines) with no way to toggle them. Installation requires cloning the full repo and manually editing host configs. There is no setup wizard, no guided first-run experience, and no separation between the human operator and the AI assistant at the OS level.

## Decisions

| Decision | Choice |
|----------|--------|
| Wizard UX | Bash + dialog TUI |
| User model | System user (`nixpi-agent`) for services |
| AI providers | Anthropic, OpenAI/Codex, Custom/OpenAI-compatible |
| Secrets storage | `/etc/nixpi/secrets/` (file-based, root-owned) |
| Optional modules | Everything except SSH |
| Bootstrap privilege | Runs as root from the start |
| Distribution model | Flake input + template (`nix flake init -t`) |

## Architecture

### Flake Distribution

Nixpi becomes a NixOS module library consumed as a flake input. Users don't clone the repo — they reference it.

```
# User's machine after setup
~/my-server/
├── flake.nix          # imports nixpi as input (~20 lines)
├── flake.lock         # pinned versions
├── hardware.nix       # auto-detected by wizard
└── nixpi-config.nix   # wizard-generated module choices
```

The Nixpi repo exports:

```
nixosModules.default        — All modules (convenience import)
nixosModules.base           — Core essentials (SSH, nix settings, user creation, Pi agent)
nixosModules.tailscale      — Tailscale VPN
nixosModules.syncthing      — Syncthing file sync
nixosModules.ttyd           — Web terminal
nixosModules.matrix         — Matrix server + bridge
nixosModules.heartbeat      — Periodic agent cycle
nixosModules.objects        — Object store
nixosModules.passwordPolicy — PAM password policy
nixosModules.desktop        — GNOME desktop
templates.default           — Scaffold for new machines
packages.nixpi-cli          — CLI wrapper
packages.nixpi-setup        — Setup wizard
```

User's generated `flake.nix`:

```nix
{
  inputs.nixpi.url = "github:alexradunet/nixpi";
  inputs.nixpkgs.follows = "nixpi/nixpkgs";

  outputs = { nixpi, nixpkgs, ... }: {
    nixosConfigurations.myserver = nixpkgs.lib.nixosSystem {
      modules = [
        nixpi.nixosModules.default
        ./hardware.nix
        ./nixpi-config.nix
      ];
    };
  };
}
```

### Module Extraction from base.nix

Each optional service gets its own file in `infra/nixos/modules/`. Current base.nix (~540 lines) shrinks to ~250 lines.

| Module file | Extracted from base.nix | Key options |
|-------------|------------------------|-------------|
| `tailscale.nix` | Tailscale service + UDP 41641 | `nixpi.tailscale.enable` |
| `syncthing.nix` | Syncthing service + ports 8384/22000 + ~/Shared | `nixpi.syncthing.enable`, `.sharedFolder` |
| `ttyd.nix` | ttyd service + port 7681 | `nixpi.ttyd.enable`, `.port` |
| `password-policy.nix` | PAM password rules + policy script | `nixpi.passwordPolicy.enable`, `.minLength` |
| `desktop.nix` | GNOME/GDM config | `nixpi.desktop.enable`, `.profile` |

Already modular (no changes needed): `heartbeat.nix`, `matrix.nix`, `objects.nix`.

**What stays in base.nix** (~250 lines):
- Nix core settings (flakes, nix-ld, gc)
- SSH (always on, hardened) with LAN-only firewall rules
- NetworkManager
- User account creation (human + nixpi-agent system user)
- Pi agent setup (wrapper, activation scripts, system prompt)
- Shared constants (`nixpi._internal.tailscaleCIDR`)
- Base system packages (git, nodejs, vim, jq, yq-go, etc.)

**Firewall strategy**: Each module contributes its own `networking.firewall.extraInputRules` snippet. NixOS deep-merges these. Base.nix keeps only SSH rules. Shared Tailscale CIDR constants live in `nixpi._internal` so modules reference them without depending on the Tailscale module.

### Setup Wizard (`nixpi setup`)

Bash + dialog TUI. Runs as root. Six steps:

1. **Welcome** — detect hostname, confirm target directory
2. **Basic info** — timezone (menu), primary username, display name
3. **AI config** — provider selection (Anthropic/OpenAI/Codex/Custom), model name, API key (passwordbox), thinking level
4. **Module selection** — checklist with all optional modules
5. **Review** — summary of choices, preview generated Nix config
6. **Apply** — write files, run `nixos-rebuild switch --flake .`

Generated artifacts:
- `~/my-server/flake.nix` — nixpi flake input
- `~/my-server/hardware.nix` — from `nixos-generate-config --show-hardware-config`
- `~/my-server/nixpi-config.nix` — module enable flags + user options
- `/etc/nixpi/secrets/ai-provider.env` — API key (root:root 0600)
- Pi agent `settings.json` — provider/model config (seeded, not overwritten)

### User Account Model

Two accounts with clean separation:

- **Human user** (`nixpi.primaryUser`): normal user, wheel group (sudo), interactive sessions, added to `nixpi` group for read access to agent state
- **System user** (`nixpi-agent`): system user, no login shell, owns services and `/var/lib/nixpi/`, group `nixpi`
- `mk-nixpi-service.nix` updated to run services as `nixpi-agent`
- Pi agent data at `/var/lib/nixpi/agent/` (not under human user's home)

### Secrets Management

Location: `/etc/nixpi/secrets/` (root-owned, mode 0700 directory, mode 0600 files).

Files:
- `ai-provider.env` — contains provider API key
- `nixpi-matrix-token` — Matrix bot access token (migrated from `/run/secrets/`)

Injection:
- Interactive CLI: `piWrapper` sources the env file before launching Pi
- Systemd services: `EnvironmentFile` directive (existing pattern from Matrix module)

### Bootstrap One-Liner

```bash
sudo nix-shell -p git --run \
  "git clone https://github.com/alexradunet/nixpi.git /tmp/nixpi-bootstrap && \
   /tmp/nixpi-bootstrap/scripts/bootstrap-fresh-nixos.sh"
```

Flow: clone repo to temp -> `nixos-generate-config` -> launch setup wizard -> wizard generates user's config directory -> `nixos-rebuild switch` -> verify -> success message.

First-run detection: `/etc/nixpi/.setup-complete` marker file. Shell profile snippet suggests `nixpi setup` when missing.

## Testing Strategy (TDD, E2E)

All tests are real NixOS VM tests — no mocks.

### Single-Module Tests

Each module tested in isolation (only that module enabled, everything else off):

| Test | Verifies |
|------|----------|
| `vm-tailscale-only.nix` | tailscaled runs, UDP 41641 open, no syncthing/ttyd |
| `vm-syncthing-only.nix` | syncthing runs, ports 8384/22000, ~/Shared exists |
| `vm-ttyd-only.nix` | ttyd runs, port 7681 |
| `vm-matrix-only.nix` | conduit + bridge run, port 6167 |
| `vm-heartbeat-only.nix` | timer fires, service executes |
| `vm-desktop-only.nix` | GDM active |
| `vm-password-policy-only.nix` | PAM rejects weak passwords |

### Multi-Module Tests

| Test | Configuration | Verifies |
|------|--------------|----------|
| `vm-minimal.nix` | ALL modules disabled | Only SSH + core, no extra ports |
| `vm-full-stack.nix` | ALL modules enabled | Everything coexists without conflicts |
| `vm-headless-server.nix` | Tailscale + Syncthing + Matrix + Heartbeat, no Desktop/ttyd | Server profile works |
| `vm-assistant-user.nix` | Base config | nixpi-agent user exists, group membership correct, service ownership |

### Config Generation Tests

Shell tests for the wizard's config generator:
- Generated Nix evaluates cleanly (`nix-instantiate --eval`)
- All module combinations produce valid configs
- Hardware detection produces valid `hardware.nix`

## File Changes

### New files

| File | Purpose |
|------|---------|
| `infra/nixos/modules/tailscale.nix` | Tailscale module |
| `infra/nixos/modules/syncthing.nix` | Syncthing module |
| `infra/nixos/modules/ttyd.nix` | ttyd module |
| `infra/nixos/modules/password-policy.nix` | Password policy module |
| `infra/nixos/modules/desktop.nix` | Desktop/GNOME module |
| `scripts/nixpi-setup.sh` | Setup wizard TUI |
| `templates/default/flake.nix` | Flake template for new machines |
| `templates/default/flake.lock` | Template lock file |
| 8 VM test files | Single-module + multi-module E2E tests |

### Modified files

| File | Changes |
|------|---------|
| `infra/nixos/base.nix` | Remove extracted services, add system user, slim to ~250 lines |
| `infra/nixos/lib/mk-nixpi-service.nix` | Run services as `nixpi-agent` |
| `infra/nixos/scripts/nixpi-cli.sh` | Add `setup` subcommand |
| `flake.nix` | Export nixosModules, templates, register new VM tests |
| `scripts/bootstrap-fresh-nixos.sh` | Integrate wizard, run as root |
| `tests/vm/service-ensemble.nix` | Explicitly enable modules |
| `tests/vm/firewall-rules.nix` | Per-module port assertions |

## Phases

1. **Module extraction** — Extract services from base.nix into individual modules with enable flags
2. **Flake exports** — Export nixosModules from flake.nix, build template
3. **Setup wizard** — Build dialog TUI, config generation, CLI integration
4. **User account model** — Add nixpi-agent system user, update service factory
5. **Secrets management** — /etc/nixpi/secrets/, piWrapper env sourcing
6. **Bootstrap** — Update bootstrap script, first-run detection
7. **Testing** — TDD throughout: write VM tests before or alongside each module

---
name: install-nixpi
description: Guided first-time Nixpi installation on fresh NixOS using the setup wizard and flake template distribution model.
---

# Install Nixpi (Guided)

Use this skill when the user is bootstrapping Nixpi on a fresh machine.

## Distribution model

Nixpi is consumed as a flake input via `nix flake init -t github:alexradunet/nixpi`. Users do not clone the repo -- they reference it. The setup wizard generates a minimal config directory:

```
~/nixpi-server/
  flake.nix          # imports nixpi as a flake input
  flake.lock         # pinned versions
  hardware.nix       # auto-detected by wizard
  nixpi-config.nix   # wizard-generated module enable flags
```

## Goals
1. Prevent disk UUID mismatch at boot.
2. Prevent password/login surprises by reusing the existing installer user.
3. Apply Nixpi only after explicit user confirmation.
4. Configure optional modules via `nixpi-config.nix` enable flags.
5. Store API keys in `/etc/nixpi/secrets/` (root:root, mode 0700).

## Guided flow

### Fresh install (preferred)
1. Run the setup wizard: `nixpi setup [target-dir]`
2. The wizard (dialog TUI) walks through:
   - Hostname, username, timezone
   - AI provider selection and API key
   - Module checklist (Tailscale, Syncthing, ttyd, desktop, password-policy, heartbeat, matrix)
   - Review and apply
3. Generated files: `flake.nix`, `hardware.nix`, `nixpi-config.nix`
4. API key stored at `/etc/nixpi/secrets/ai-provider.env`
5. Wizard runs `nixos-rebuild switch --flake .`
6. First-run marker written to `/etc/nixpi/.setup-complete`

### Bootstrap one-liner (unattended start)
```bash
sudo nix-shell -p git --run \
  "git clone https://github.com/alexradunet/nixpi.git /tmp/nixpi-bootstrap && \
   /tmp/nixpi-bootstrap/scripts/bootstrap-fresh-nixos.sh"
```

### Module configuration
Module enable flags live in `nixpi-config.nix`:
```nix
nixpi.tailscale.enable = true;
nixpi.syncthing.enable = true;
nixpi.ttyd.enable = true;
nixpi.desktop.enable = true;
nixpi.passwordPolicy.enable = true;
nixpi.heartbeat.enable = false;
nixpi.channels.matrix.enable = false;
```

### Post-install verification
1. `nixpi --help`
2. `./scripts/verify-nixpi.sh`
3. If rebuild fails: `sudo nixos-rebuild switch --rollback`

## Safety notes
- Do not run destructive disk commands.
- Do not edit boot/disk config without showing diff and asking user first.
- Keep changes minimal and declarative.
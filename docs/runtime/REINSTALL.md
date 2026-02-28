# Reinstall Nixpi on Fresh NixOS

This is a copy-paste checklist for reinstalling Nixpi on a fresh NixOS install from the interactive installer.

Nixpi now defaults to a GNOME desktop profile (closer to standard NixOS GNOME setups) and preserves an existing desktop config when detected.

## 0) Assumptions (fresh install defaults)

- `git` is **not** installed yet.
- Flakes are **not** enabled yet.
- You already completed a base NixOS install.
- You can log in locally or over SSH.
- You have network connectivity.

### Alternative: Flake template

If you already have flakes and git available, you can scaffold a Nixpi config without cloning the full repo:

```bash
mkdir ~/Nixpi && cd ~/Nixpi
nix flake init -t github:alexradunet/nixpi
```

Then edit `flake.nix` / host config and run `sudo nixos-rebuild switch --flake .`.

## 1) Fast path (automated clone + guided install)

Single-command one-liner:

```bash
nix --extra-experimental-features "nix-command flakes" shell nixpkgs#git -c git clone https://github.com/alexradunet/nixpi.git Nixpi && cd ~/Nixpi && ./scripts/bootstrap-fresh-nixos.sh
```

Step-by-step equivalent:

```bash
cd ~
nix --extra-experimental-features "nix-command flakes" shell nixpkgs#git -c git clone https://github.com/alexradunet/nixpi.git Nixpi
cd ~/Nixpi
./scripts/bootstrap-fresh-nixos.sh
```

Optional unattended mode (skips guided install and applies directly):

```bash
./scripts/bootstrap-fresh-nixos.sh --non-interactive
```

Optional preview mode (shows planned actions without changing anything):

```bash
./scripts/bootstrap-fresh-nixos.sh --dry-run
```

What `bootstrap-fresh-nixos.sh` does:
1. Runs as root (elevates via `sudo` if needed).
2. Validates clone target path.
3. Clones with one-time `nix --extra-experimental-features "nix-command flakes" shell nixpkgs#git -c git clone ...` when needed.
4. Regenerates the host file for the current machine:
   - `./scripts/add-host.sh --force "$(hostname)"`
5. Default mode: launches the `nixpi setup` wizard (dialog-based TUI) for guided module selection and first rebuild.
6. `--non-interactive` mode: runs first rebuild directly with defaults.
7. `--dry-run` mode: prints the plan and exits without mutating the system.
8. On completion, writes `/etc/nixpi/.setup-complete` to mark the system as configured. Subsequent boots skip the first-run wizard.

## 2) Manual path (same assumptions)

### Clone Nixpi

```bash
cd ~
nix --extra-experimental-features "nix-command flakes" shell nixpkgs#git -c git clone https://github.com/alexradunet/nixpi.git Nixpi
cd ~/Nixpi
```

### Regenerate host file for this machine

```bash
./scripts/add-host.sh --force "$(hostname)"
```

This refresh avoids stale disk UUIDs and maps `nixpi.primaryUser` / `nixpi.repoRoot` to your current installer user.

### Guided install session (recommended)

The preferred guided path is the setup wizard:

```bash
sudo nixpi setup
```

This launches a dialog-based TUI that walks through module selection (Tailscale, ttyd, Syncthing, desktop, etc.), provider/auth configuration, and triggers the first rebuild. The wizard writes `/etc/nixpi/.setup-complete` on success.

If `nixpi` is already installed and you want the skill-based flow instead:

```bash
nixpi --skill ./infra/pi/skills/install-nixpi/SKILL.md
```

If `nixpi` is not installed yet (fresh system):

```bash
nix --extra-experimental-features "nix-command flakes" shell nixpkgs#nodejs_22 -c npx --yes @mariozechner/pi-coding-agent@0.55.1 --skill ./infra/pi/skills/install-nixpi/SKILL.md
# NOTE: The version above (0.55.1) should match `nixpi.piAgentVersion` in infra/nixos/base.nix.
# Check the current value there before running this command.
```

### Manual first rebuild (if you skip guided mode)

```bash
sudo env NIX_CONFIG="experimental-features = nix-command flakes" nixos-rebuild switch --flake "path:$PWD#$(hostname)"
```

Only needed for the very first flake rebuild on a fresh system. After this succeeds once, flakes are enabled declaratively by Nixpi (`nix.settings.experimental-features`), so future rebuilds can use:

```bash
sudo nixos-rebuild switch --flake .
```

## 3) Verify

```bash
nixpi --help
./scripts/verify-nixpi.sh
```

Confirm first-run detection marker exists:

```bash
ls -la /etc/nixpi/.setup-complete
```

Authenticate if needed (provider setup through `nixpi`). API keys are sourced from `/etc/nixpi/secrets/ai-provider.env`.

## 4) Set up Matrix channel (optional)

Run the interactive Matrix setup skill to provision Conduit, create accounts, and configure the bridge:

```bash
nixpi --skill ./infra/pi/skills/matrix-setup/SKILL.md
```

Or follow the manual guide: [Matrix Setup](./MATRIX_SETUP.md).

## 5) Rollback (safety)

```bash
sudo nixos-rebuild switch --rollback
```

Or reboot and choose an older generation from the bootloader menu.
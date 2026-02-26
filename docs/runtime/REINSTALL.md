# Reinstall Nixpi on Fresh NixOS

This is a copy-paste checklist for reinstalling Nixpi on a fresh NixOS install from the interactive installer.

Nixpi now defaults to a GNOME desktop profile (closer to standard NixOS GNOME setups) and preserves an existing desktop config when detected.

## 0) Assumptions (fresh install defaults)

- `git` is **not** installed yet.
- Flakes are **not** enabled yet.
- You already completed a base NixOS install.
- You can log in locally or over SSH.
- You have network connectivity.

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

Optional unattended mode (skips Pi guidance and applies directly):

```bash
./scripts/bootstrap-fresh-nixos.sh --non-interactive
```

Optional preview mode (shows planned actions without changing anything):

```bash
./scripts/bootstrap-fresh-nixos.sh --dry-run
```

What `bootstrap-fresh-nixos.sh` does:
1. Validates clone target path.
2. Clones with one-time `nix --extra-experimental-features "nix-command flakes" shell nixpkgs#git -c git clone ...` when needed.
3. Regenerates the host file for the current machine:
   - `./scripts/add-host.sh --force "$(hostname)"`
4. Default mode: launches Pi with the `install-nixpi` skill to guide final review + first rebuild.
5. `--non-interactive` mode: runs first rebuild directly.
6. `--dry-run` mode: prints the plan and exits without mutating the system.

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

### Guided Pi install session (recommended)

If `pi` is installed:

```bash
pi --skill ./infra/pi/skills/install-nixpi/SKILL.md
```

If `pi` is not installed yet:

```bash
nix --extra-experimental-features "nix-command flakes" shell nixpkgs#nodejs_22 -c npx --yes @mariozechner/pi-coding-agent@0.55.1 --skill ./infra/pi/skills/install-nixpi/SKILL.md
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

Authenticate Pi if needed:

```bash
pi login
```

## 4) Rollback (safety)

```bash
sudo nixos-rebuild switch --rollback
```

Or reboot and choose an older generation from the bootloader menu.
# Reinstall Nixpi on Fresh NixOS

This is a copy-paste checklist for reinstalling Nixpi on a fresh NixOS install from the interactive installer.

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
nix --extra-experimental-features "nix-command flakes" shell nixpkgs#git -c git clone https://github.com/alexradunet/nixpi.git Nixpi && cd ~/Nixpi && sudo ./scripts/bootstrap.sh
```

Step-by-step equivalent:

```bash
cd ~
nix --extra-experimental-features "nix-command flakes" shell nixpkgs#git -c git clone https://github.com/alexradunet/nixpi.git Nixpi
cd ~/Nixpi
sudo ./scripts/bootstrap.sh
```

What `bootstrap.sh` does:
1. Runs as root (elevates via `sudo` if needed).
2. Enables flakes and git via a temporary NixOS config overlay.
3. Clones the Nixpi repo (skips if already present).
4. Launches Pi with the `install-nixpi` skill for conversational setup — Pi handles hardware detection, module selection, config generation, and the first rebuild.
5. On completion, writes `/etc/nixpi/.setup-complete` to mark the system as configured.

## 2) Manual path (same assumptions)

### Clone Nixpi

```bash
cd ~
nix --extra-experimental-features "nix-command flakes" shell nixpkgs#git -c git clone https://github.com/alexradunet/nixpi.git Nixpi
cd ~/Nixpi
```

### Guided install session (recommended)

Run the conversational setup:

```bash
sudo nixpi setup
```

This launches Pi with the install-nixpi skill for conversational setup — hardware detection, module selection, AI provider configuration, config generation, and the first rebuild.

If `nixpi` is not installed yet (fresh system):

```bash
nix --extra-experimental-features "nix-command flakes" shell nixpkgs#nodejs_22 -c npx --yes @mariozechner/pi-coding-agent@0.55.3 --skill ./infra/pi/skills/install-nixpi/SKILL.md
# NOTE: The version above (0.55.3) should match `nixpi.piAgentVersion` in infra/nixos/base.nix.
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

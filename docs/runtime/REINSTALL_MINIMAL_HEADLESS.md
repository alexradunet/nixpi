# Reinstall Nixpi on Fresh NixOS Minimal (Headless Installer)

This is a copy-paste checklist for reinstalling Nixpi on a fresh NixOS install done with the interactive installer **without selecting a desktop environment**. Nixpi enables LXDE on the first rebuild so local HDMI setup (display + Wi-Fi) is available after reboot.

## 0) Assumptions (fresh install defaults)

- `git` is **not** installed yet.
- Flakes are **not** enabled yet.
- You already completed a base NixOS install (minimal/headless installer profile).
- You can log in locally or over SSH.
- You have network connectivity.

## 1) Fast path (automated clone + first rebuild)

Single-command one-liner:

```bash
nix shell nixpkgs#git -c git clone https://github.com/alexradunet/nixpi.git Nixpi && cd ~/Nixpi && ./scripts/bootstrap-fresh-nixos.sh
```

Step-by-step equivalent:

```bash
cd ~
nix shell nixpkgs#git -c git clone https://github.com/alexradunet/nixpi.git Nixpi
cd ~/Nixpi
./scripts/bootstrap-fresh-nixos.sh
```

What `bootstrap-fresh-nixos.sh` does:
1. Validates clone target path
2. Clones with one-time `nix shell nixpkgs#git -c git clone ...` when needed
3. Creates host file via `./scripts/add-host.sh` if missing
4. Runs first rebuild with flakes explicitly enabled:
   - `sudo nixos-rebuild switch --flake . --extra-experimental-features "nix-command flakes"`

## 2) Manual path (same assumptions)

### Clone Nixpi

```bash
cd ~
nix shell nixpkgs#git -c git clone https://github.com/alexradunet/nixpi.git Nixpi
cd ~/Nixpi
```

### Ensure host file exists for current hostname

```bash
hostname
```

If `infra/nixos/hosts/$(hostname).nix` is missing:

```bash
./scripts/add-host.sh
```

### First rebuild (flakes explicitly enabled)

```bash
sudo nixos-rebuild switch --flake . --extra-experimental-features "nix-command flakes"
```

## 3) Verify

```bash
nixpi --help
./scripts/verify-nixpi-modes.sh
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

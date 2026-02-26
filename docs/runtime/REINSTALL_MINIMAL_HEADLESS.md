# Reinstall Nixpi on Fresh NixOS Minimal (Headless)

This is a copy-paste checklist for reinstalling Nixpi on a fresh NixOS install done with the interactive installer **without a desktop environment**.

## 0) Assumptions

- You already completed a base NixOS install (minimal/headless).
- You can log in locally or over SSH.
- You have network connectivity.

## 1) Clone Nixpi

Recommended location (matches project convention): `~/Nixpi`

```bash
cd ~
git clone https://github.com/alexradunet/nixpi.git Nixpi
cd Nixpi
```

If `git` is not present on your fresh install:

```bash
nix shell nixpkgs#git -c git clone https://github.com/alexradunet/nixpi.git Nixpi
cd ~/Nixpi
```

## 2) Ensure host file exists for current hostname

Check current hostname:

```bash
hostname
```

If your hostname is not already represented by `infra/nixos/hosts/<hostname>.nix`, generate it:

```bash
./scripts/add-host.sh
```

Then review and stage the generated host file if you plan to commit it.

## 3) Apply Nixpi system configuration

From repo root:

```bash
sudo nixos-rebuild switch --flake .
```

If flakes are not yet enabled on the base system:

```bash
sudo nixos-rebuild switch --flake . --extra-experimental-features "nix-command flakes"
```

## 4) Verify core commands and wrapper modes

```bash
nixpi --help
nixpi
nixpi dev
./scripts/verify-nixpi-modes.sh
```

Authenticate Pi if needed:

```bash
pi login
```

## 5) Rollback (safety)

If needed, rollback to previous generation:

```bash
sudo nixos-rebuild switch --rollback
```

Or reboot and choose an older generation from the bootloader menu.

## Personalized one-shot block (user: `alex`, repo root: `~/Nixpi`)

Use this when your Linux username is `alex` and you want the repo at `/home/alex/Nixpi`.

```bash
set -euo pipefail

# Ensure expected user context
if [ "$(whoami)" != "alex" ]; then
  echo "Current user is $(whoami), expected alex."
  exit 1
fi

cd /home/alex

if [ ! -d Nixpi ]; then
  if command -v git >/dev/null 2>&1; then
    git clone https://github.com/alexradunet/nixpi.git Nixpi
  else
    nix shell nixpkgs#git -c git clone https://github.com/alexradunet/nixpi.git Nixpi
  fi
fi

cd /home/alex/Nixpi

if [ ! -f "infra/nixos/hosts/$(hostname).nix" ]; then
  ./scripts/add-host.sh
fi

sudo nixos-rebuild switch --flake . || \
  sudo nixos-rebuild switch --flake . --extra-experimental-features "nix-command flakes"

nixpi --help
./scripts/verify-nixpi-modes.sh
```

If your host file needs explicit overrides, use:

```nix
# infra/nixos/hosts/<hostname>.nix
{ config, ... }:
{
  nixpi.primaryUser = "alex";
  nixpi.repoRoot = "/home/alex/Nixpi";
  nixpi.runtimePiDir = "${config.nixpi.repoRoot}/.pi/agent";
  nixpi.devPiDir = "${config.nixpi.repoRoot}/.pi/agent-dev";
}
```

## Generic one-shot command block (run step-by-step)

```bash
set -euo pipefail

cd ~

if [ ! -d Nixpi ]; then
  if command -v git >/dev/null 2>&1; then
    git clone https://github.com/alexradunet/nixpi.git Nixpi
  else
    nix shell nixpkgs#git -c git clone https://github.com/alexradunet/nixpi.git Nixpi
  fi
fi

cd ~/Nixpi

if [ ! -f "infra/nixos/hosts/$(hostname).nix" ]; then
  ./scripts/add-host.sh
fi

sudo nixos-rebuild switch --flake . || \
  sudo nixos-rebuild switch --flake . --extra-experimental-features "nix-command flakes"

nixpi --help
./scripts/verify-nixpi-modes.sh
```

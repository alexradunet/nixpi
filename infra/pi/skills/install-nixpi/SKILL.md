---
name: install-nixpi
description: Guided first-time Nixpi installation on fresh NixOS. Use this to validate host disk/user settings before the first nixos-rebuild and avoid boot/login surprises.
---

# Install Nixpi (Guided)

Use this skill when the user is bootstrapping Nixpi on a fresh machine.

## Goals
1. Prevent disk UUID mismatch at boot.
2. Prevent password/login surprises by reusing the existing installer user.
3. Apply Nixpi only after explicit user confirmation.

## Guided flow
1. Confirm we are inside the Nixpi repo root.
2. Review `infra/nixos/hosts/$(hostname).nix` and explicitly check:
   - `fileSystems` disk UUIDs look machine-local.
   - `networking.hostName` matches `hostname`.
   - `nixpi.primaryUser` and `nixpi.repoRoot` match the intended login user.
3. Ask user to confirm before rebuild.
4. Run:
   - `sudo env NIX_CONFIG="experimental-features = nix-command flakes" nixos-rebuild switch --flake "path:$PWD#$(hostname)"`
5. After rebuild, verify:
   - `nixpi --help`
   - `./scripts/verify-nixpi.sh`
6. If rebuild fails, provide rollback command:
   - `sudo nixos-rebuild switch --rollback`

## Safety notes
- Do not run destructive disk commands.
- Do not edit boot/disk config without showing diff and asking user first.
- Keep changes minimal and declarative.
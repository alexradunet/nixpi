# Reinstall Nixpi on Fresh NixOS

This is a copy-paste checklist for reinstalling Nixpi on a fresh NixOS install from the interactive installer.

## 0) Assumptions (fresh install defaults)

- You already completed a base NixOS install.
- You can log in locally or over SSH.
- You have network connectivity.
- Flakes are enabled (`nix.settings.experimental-features = [ "nix-command" "flakes" ];` in your NixOS config).
- `git` is installed.

If flakes or git are not available yet, add the following to your NixOS config and rebuild:
```nix
nix.settings.experimental-features = [ "nix-command" "flakes" ];
environment.systemPackages = [ pkgs.git ];
```
```bash
sudo nixos-rebuild switch
```

## 1) Scaffold from flake template

```bash
mkdir ~/Nixpi && cd ~/Nixpi
nix flake init -t github:alexradunet/nixpi
```

## 2) First-time guided setup

On a fresh system `nixpi` is not available yet. Run the setup skill directly via npx:

```bash
nix shell nixpkgs#nodejs_22 -c npx --yes @mariozechner/pi-coding-agent@0.55.3 --skill ./infra/pi/skills/install-nixpi/SKILL.md
# NOTE: The version above (0.55.3) should match `nixpi.piAgentVersion` in infra/nixos/base.nix.
# Check the current value there before running this command.
```

This launches Pi with the install-nixpi skill for conversational setup — hardware detection, module selection, config generation, and the first rebuild.

After the first successful rebuild, `nixpi` becomes available as a system command. For future reconfiguration use:

```bash
nixpi setup
```

### Manual first rebuild (if you skip guided mode)

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

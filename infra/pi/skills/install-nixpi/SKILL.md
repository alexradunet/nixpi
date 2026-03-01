---
name: install-nixpi
description: Conversational first-time Nixpi setup — detects hardware, gathers configuration, generates NixOS config files, applies and verifies.
---

# Install Nixpi (Guided)

Use this skill when the user is setting up Nixpi on a fresh NixOS machine or reconfiguring an existing install. You are a conversational setup assistant — no TUI or wizard, just guided conversation.

## First-Run Detection

Check whether setup has already been completed:
```bash
[ -f /etc/nixpi/.setup-complete ] && echo "already configured" || echo "fresh install"
```
If already configured, ask the user whether they want to reconfigure or exit.

## Distribution Model

Nixpi is consumed as a flake input via `nix flake init -t github:alexradunet/nixpi`. Users do not clone the repo — they reference it. The setup skill generates a minimal config directory:

```
~/Nixpi/
  flake.nix          # imports nixpi as a flake input
  flake.lock         # pinned versions
  hardware.nix       # auto-detected hardware config
  nixpi-config.nix   # module enable flags + identity
```

## Goals
1. Prevent disk UUID mismatch at boot.
2. Prevent password/login surprises by reusing the existing installer user.
3. Apply Nixpi only after explicit user confirmation.
4. Configure optional modules via `nixpi-config.nix` enable flags.
5. Store API keys in `/etc/nixpi/secrets/` (root:root, mode 0700).

## Guided Flow

### Phase 1: Detect Environment

Gather system facts automatically — do not ask the user for these:

```bash
hostname
whoami
[ -d /sys/firmware/efi ] && echo "UEFI" || echo "BIOS"
pwd
```

Determine:
- **hostname** — current machine hostname
- **username** — current user (or `$SUDO_USER` if running as root)
- **boot mode** — UEFI or BIOS (drives bootloader config)
- **repo root** — current working directory (should contain `flake.nix` or be the target dir)

Tell the user what you detected:
> "I detected hostname **X**, user **Y**, boot mode **Z**. I'll use these as defaults."

### Phase 2: Gather Configuration

Ask the user conversationally about each section. Use the detected values as defaults.

#### Identity
- **Hostname** — default: detected. "What hostname should this machine use?"
- **Username** — default: detected. "What Linux username should be the primary user?"
- **Timezone** — default: `UTC`. "What timezone? (e.g. Europe/London, America/New_York)"

#### Boot Loader
Auto-configure based on Phase 1 detection:
- **UEFI**: systemd-boot + `canTouchEfiVariables = true` + `grub.enable = false`
- **BIOS**: GRUB + ask for boot device (default `/dev/sda`)

Tell the user what you'll configure and confirm.

#### Modules
Present the available modules with recommended defaults:

| Module | Default | Description |
|--------|---------|-------------|
| `tailscale` | on | VPN for secure remote access |
| `syncthing` | on | File synchronization |
| `ttyd` | on | Web terminal (Tailscale-only) |
| `desktop` | on | GNOME desktop + VS Code |
| `passwordPolicy` | on | Password strength enforcement |
| `objects` | on | Object store data directory |
| `heartbeat` | off | Periodic agent observation cycle |
| `matrix` | off | Matrix messaging channel |

Ask: "Which modules would you like to change from these defaults?"

#### AI Provider
- Ask: "Which AI provider? (Anthropic / OpenAI / custom)"
- Ask for the API key.
- Ask for the model name (provide sensible default per provider).

### Phase 3: Generate Hardware Config

Run hardware detection:
```bash
nixos-generate-config --show-hardware-config > hardware.nix
```

Check for an existing desktop environment:
```bash
systemctl is-active gdm sddm lightdm 2>/dev/null
```
If a display manager is active, note it — the user may want `nixpi.desktop.enable = false` to preserve their existing desktop setup.

Show the user a summary of the hardware config and confirm.

### Phase 4: Generate Config Files

Using `templates/default/flake.nix` and `templates/default/nixpi-config.nix` as reference, generate two files with the user's values substituted.

#### `flake.nix`
```nix
{
  description = "My Nixpi server";

  inputs = {
    nixpi.url = "github:alexradunet/nixpi";
    nixpkgs.follows = "nixpi/nixpkgs";
    nixpkgs-unstable.follows = "nixpi/nixpkgs-unstable";
  };

  outputs = { self, nixpi, nixpkgs, nixpkgs-unstable, ... }:
    let
      system = "x86_64-linux";
      pkgsUnstable = import nixpkgs-unstable {
        inherit system;
        config.allowUnfree = true;
      };
    in {
      nixosConfigurations.<HOSTNAME> = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit pkgsUnstable; };
        modules = [
          nixpi.nixosModules.default
          ./hardware.nix
          ./nixpi-config.nix
        ];
      };
    };
}
```

Replace `<HOSTNAME>` with the user's chosen hostname.

#### `nixpi-config.nix`
```nix
{ config, lib, ... }:

{
  # --- Identity ---
  networking.hostName = "<HOSTNAME>";
  nixpi.primaryUser = "<USERNAME>";
  nixpi.timeZone = "<TIMEZONE>";

  # --- Boot loader ---
  # (UEFI or BIOS block based on detection)

  # --- Modules ---
  nixpi.tailscale.enable = <true/false>;
  nixpi.syncthing.enable = <true/false>;
  nixpi.ttyd.enable = <true/false>;
  nixpi.desktop.enable = <true/false>;
  nixpi.passwordPolicy.enable = <true/false>;
  nixpi.objects.enable = <true/false>;
  # nixpi.heartbeat.enable = <true/false>;
  # nixpi.channels.matrix.enable = <true/false>;
}
```

Show the user the generated files and ask for confirmation before writing.

### Phase 5: Write Files + Initialize

After user confirmation:

1. Write `flake.nix`, `hardware.nix`, and `nixpi-config.nix` to the repo root.
2. Store the API key:
   ```bash
   sudo install -d -m 0700 /etc/nixpi/secrets
   # Write the appropriate env var (e.g. ANTHROPIC_API_KEY=sk-...)
   sudo tee /etc/nixpi/secrets/ai-provider.env <<< '<KEY_VAR>=<KEY_VALUE>'
   sudo chmod 600 /etc/nixpi/secrets/ai-provider.env
   ```
3. Seed Pi settings if not present:
   ```bash
   mkdir -p .pi/agent
   cat > .pi/agent/settings.json <<'JSON'
   {
     "skills": ["./infra/pi/skills"],
     "packages": []
   }
   JSON
   ```
4. Initialize git repo:
   ```bash
   git init && git add -A
   ```

### Phase 6: Apply

Run the NixOS rebuild:
```bash
sudo nixos-rebuild switch --flake .
```

If this is the very first flake rebuild (flakes not yet system-wide):
```bash
sudo env NIX_CONFIG="experimental-features = nix-command flakes" nixos-rebuild switch --flake "path:$PWD#<HOSTNAME>"
```

If the rebuild fails:
- Show the error output.
- Offer to rollback: `sudo nixos-rebuild switch --rollback`
- Help the user diagnose and fix the issue.

### Phase 7: Verify

1. Run the verification script:
   ```bash
   ./scripts/verify-nixpi.sh
   ```
2. Write the setup-complete marker:
   ```bash
   sudo install -d -m 0755 /etc/nixpi
   sudo touch /etc/nixpi/.setup-complete
   ```
3. Print a summary:
   ```
   Nixpi Setup Complete
   ====================
   Hostname:     <hostname>
   User:         <username>
   Timezone:     <timezone>
   Boot mode:    <UEFI/BIOS>
   Modules:      <enabled list>
   AI provider:  <provider>
   Config dir:   <path>
   ```
4. Remind the user:
   - "Run `nixpi` to start your AI assistant."
   - "Run `nixpi evolve` to apply future config changes safely."
   - "Run `nixpi --skill ./infra/pi/skills/matrix-setup/SKILL.md` to set up Matrix messaging."

## Module Configuration Reference

All module enable flags live in `nixpi-config.nix`:
```nix
nixpi.tailscale.enable = true;
nixpi.syncthing.enable = true;
nixpi.ttyd.enable = true;
nixpi.desktop.enable = true;
nixpi.passwordPolicy.enable = true;
nixpi.objects.enable = true;
nixpi.heartbeat.enable = false;
nixpi.channels.matrix.enable = false;
```

## Troubleshooting

### GRUB assertion error
If you see "GRUB is enabled but no boot devices are configured":
- UEFI machines: set `boot.loader.grub.enable = false;` and `boot.loader.systemd-boot.enable = true;`
- BIOS machines: set `boot.loader.grub.devices = [ "/dev/sda" ];` (adjust to your disk)

### Rebuild fails with "path not found"
Ensure all config files are staged: `git add -A`

### Flakes not enabled
Run the bootstrap script first: `./scripts/bootstrap.sh`

## Safety Notes
- Do not run destructive disk commands.
- Do not edit boot/disk config without showing diff and asking the user first.
- Keep changes minimal and declarative.
- Always show generated config files to the user before writing.
- Offer rollback if the rebuild fails.

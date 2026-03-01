# Nixpi Modular Installation System — Implementation Plan

> **Status: COMPLETE.** All 14 tasks have been implemented on the `feature/modular-installer` branch.

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Extract hardcoded services from base.nix into toggleable NixOS modules, export them as flake outputs, build a dialog TUI setup wizard, add a nixpi-agent system user, and create a one-command bootstrap flow.

**Architecture:** Hexagonal module extraction — each optional service becomes a self-contained NixOS module with `enable` flag. base.nix imports all modules and sets `mkDefault true` for backward compat. The flake exports individual modules + a `default` convenience import. A bash+dialog wizard generates user config files targeting the flake template.

**Tech Stack:** NixOS modules (Nix language), bash + dialog (TUI wizard), NixOS VM tests (Python test scripts), nftables (firewall)

**Design Doc:** `docs/plans/2026-02-28-modular-installer-design.md`

---

## Task 1: Extract Tailscale Module

**Files:**

- Create: `infra/nixos/modules/tailscale.nix`
- Modify: `infra/nixos/base.nix:383-395,352-381,460-461`
- Create: `tests/vm/tailscale-toggle.nix`

**Step 1: Write the Tailscale module**

Create `infra/nixos/modules/tailscale.nix`:

```nix
# Tailscale VPN module — optional Tailscale mesh networking.
#
# When enabled, provisions the Tailscale daemon with SSH disabled
# (OpenSSH remains the single SSH control plane) and opens UDP 41641
# for direct WireGuard connections.
{ config, pkgs, lib, ... }:

let
  cfg = config.nixpi.tailscale;
in
{
  options.nixpi.tailscale = {
    enable = lib.mkEnableOption "Tailscale VPN mesh networking";
  };

  config = lib.mkIf cfg.enable {
    services.tailscale = {
      enable = true;
      extraSetFlags = [ "--ssh=false" ];
    };

    networking.firewall.allowedUDPPorts = [ 41641 ];

    environment.systemPackages = [ pkgs.tailscale ];
  };
}
```

**Step 2: Write the VM test**

Create `tests/vm/tailscale-toggle.nix`:

```nix
# VM test: Tailscale module toggles on/off correctly.
{ pkgsUnstableForTests }:

{
  name = "vm-tailscale-toggle";

  nodes.enabled = {
    imports = [ (import ./_base-test-config.nix { inherit pkgsUnstableForTests; }) ];
    nixpi.tailscale.enable = true;
  };

  nodes.disabled = {
    imports = [ (import ./_base-test-config.nix { inherit pkgsUnstableForTests; }) ];
    nixpi.tailscale.enable = false;
  };

  testScript = ''
    # --- Enabled node ---
    enabled.wait_for_unit("multi-user.target")
    enabled.wait_for_unit("tailscaled.service")

    # Tailscale CLI available
    enabled.succeed("which tailscale")

    # WireGuard UDP port in firewall
    ruleset = enabled.succeed("nft list ruleset")
    assert "41641" in ruleset, "Missing Tailscale WireGuard port when enabled"

    # --- Disabled node ---
    disabled.wait_for_unit("multi-user.target")

    # tailscaled should not be running
    disabled.fail("systemctl is-active tailscaled.service")

    # WireGuard port should NOT be in firewall
    ruleset = disabled.succeed("nft list ruleset")
    assert "41641" not in ruleset, "Tailscale WireGuard port present when disabled"
  '';
}
```

**Step 3: Update base.nix — remove Tailscale hardcoding**

In `infra/nixos/base.nix`:

a) Add import (line ~238):

```nix
  imports = [
    ./modules/objects.nix
    ./modules/heartbeat.nix
    ./modules/matrix.nix
    ./modules/tailscale.nix
  ];
```

b) Add mkDefault enable (in config block, near line ~245):

```nix
    nixpi.tailscale.enable = lib.mkDefault true;
```

c) Remove from base.nix (lines 383-395):

```nix
  # DELETE: services.tailscale block
  # DELETE: networking.firewall.allowedUDPPorts line
  # DELETE: comment block about trustedInterfaces
```

d) Remove `tailscale` from systemPackages (line ~461):

```nix
    # Network tools
    curl
    wget
    # REMOVE: tailscale  (now in tailscale.nix module)
```

e) Remove Tailscale-specific firewall rules from the monolithic `extraInputRules` block (the UDP 41641 line). Keep SSH rules and others for now (they'll be moved in subsequent tasks).

**Step 4: Run VM test**

Run: `nix build .#checks.x86_64-linux.vm-tailscale-toggle --no-link -L`
Expected: PASS — enabled node has tailscaled running, disabled node does not

**Step 5: Run existing tests to verify no regression**

Run: `nix build .#checks.x86_64-linux.vm-service-ensemble --no-link -L`
Expected: PASS — service-ensemble still works because base.nix sets mkDefault true

**Step 6: Commit**

```bash
git add infra/nixos/modules/tailscale.nix tests/vm/tailscale-toggle.nix
git add infra/nixos/base.nix flake.nix
git commit -m "feat: extract Tailscale into toggleable module

Extract Tailscale VPN config from base.nix into modules/tailscale.nix
with nixpi.tailscale.enable flag. Defaults to true via mkDefault for
backward compat. Includes VM test for enabled/disabled states."
```

---

## Task 2: Extract ttyd Module

**Files:**

- Create: `infra/nixos/modules/ttyd.nix`
- Modify: `infra/nixos/base.nix:314-327,363-366`
- Create: `tests/vm/ttyd-toggle.nix`

**Step 1: Write the ttyd module**

Create `infra/nixos/modules/ttyd.nix`:

```nix
# ttyd module — web terminal interface over SSH.
#
# When enabled, provisions ttyd on a configurable port, authenticating
# via localhost OpenSSH login. Firewall restricts access to Tailscale only.
{ config, pkgs, lib, ... }:

let
  cfg = config.nixpi.ttyd;
  primaryUser = config.nixpi.primaryUser;
in
{
  options.nixpi.ttyd = {
    enable = lib.mkEnableOption "ttyd web terminal (SSH-based)";

    port = lib.mkOption {
      type = lib.types.port;
      default = 7681;
      description = "Port for the ttyd web terminal.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.ttyd = {
      enable = true;
      port = cfg.port;
      user = primaryUser;
      writeable = true;
      checkOrigin = true;
      entrypoint = [
        "${pkgs.openssh}/bin/ssh"
        "-o"
        "StrictHostKeyChecking=accept-new"
        "${primaryUser}@127.0.0.1"
      ];
    };

    networking.firewall.extraInputRules = ''
      # Allow ttyd (port ${toString cfg.port}) from Tailscale only
      ip saddr 100.0.0.0/8 tcp dport ${toString cfg.port} accept
      ip6 saddr fd7a:115c:a1e0::/48 tcp dport ${toString cfg.port} accept
      tcp dport ${toString cfg.port} drop
    '';
  };
}
```

**Step 2: Write the VM test**

Create `tests/vm/ttyd-toggle.nix`:

```nix
# VM test: ttyd module toggles on/off correctly.
{ pkgsUnstableForTests }:

{
  name = "vm-ttyd-toggle";

  nodes.enabled = {
    imports = [ (import ./_base-test-config.nix { inherit pkgsUnstableForTests; }) ];
    nixpi.ttyd.enable = true;
  };

  nodes.disabled = {
    imports = [ (import ./_base-test-config.nix { inherit pkgsUnstableForTests; }) ];
    nixpi.ttyd.enable = false;
  };

  testScript = ''
    # --- Enabled node ---
    enabled.wait_for_unit("multi-user.target")
    enabled.wait_for_unit("ttyd.service")
    enabled.wait_for_open_port(7681)

    ruleset = enabled.succeed("nft list ruleset")
    assert "7681" in ruleset, "Missing ttyd port in firewall when enabled"

    # --- Disabled node ---
    disabled.wait_for_unit("multi-user.target")
    disabled.fail("systemctl is-active ttyd.service")

    ruleset = disabled.succeed("nft list ruleset")
    assert "7681" not in ruleset, "ttyd port present in firewall when disabled"
  '';
}
```

**Step 3: Update base.nix**

a) Add import: `./modules/ttyd.nix`
b) Add: `nixpi.ttyd.enable = lib.mkDefault true;`
c) Remove: `services.ttyd` block (lines 314-327)
d) Remove: ttyd firewall rules from `extraInputRules` (lines 363-366)

**Step 4: Run tests**

Run: `nix build .#checks.x86_64-linux.vm-ttyd-toggle --no-link -L`
Expected: PASS

**Step 5: Commit**

```bash
git add infra/nixos/modules/ttyd.nix tests/vm/ttyd-toggle.nix
git add infra/nixos/base.nix flake.nix
git commit -m "feat: extract ttyd into toggleable module"
```

---

## Task 3: Extract Syncthing Module

**Files:**

- Create: `infra/nixos/modules/syncthing.nix`
- Modify: `infra/nixos/base.nix:397-422,367-379`
- Create: `tests/vm/syncthing-toggle.nix`

**Step 1: Write the Syncthing module**

Create `infra/nixos/modules/syncthing.nix`:

```nix
# Syncthing module — file synchronization service.
#
# When enabled, provisions Syncthing with a default ~/Shared folder,
# GUI on 0.0.0.0:8384, and firewall restricted to Tailscale.
{ config, pkgs, lib, ... }:

let
  cfg = config.nixpi.syncthing;
  primaryUser = config.nixpi.primaryUser;
  userHome = "/home/${primaryUser}";
in
{
  options.nixpi.syncthing = {
    enable = lib.mkEnableOption "Syncthing file synchronization";

    sharedFolder = lib.mkOption {
      type = lib.types.str;
      default = "${userHome}/Shared";
      description = "Path to the default shared folder.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.syncthing = {
      enable = true;
      user = primaryUser;
      dataDir = "${userHome}/.local/share/syncthing";
      configDir = "${userHome}/.config/syncthing";
      overrideFolders = false;
      overrideDevices = false;
      settings = {
        folders.home = {
          id = "shared";
          label = "Shared";
          path = cfg.sharedFolder;
          devices = builtins.attrNames config.services.syncthing.settings.devices;
        };
        gui = {
          enabled = true;
          address = "0.0.0.0:8384";
        };
        options = {
          relaysEnabled = true;
        };
      };
    };

    # Create Shared directory
    system.activationScripts.nixpiSyncthingShared = lib.stringAfter [ "users" ] ''
      install -d -o ${primaryUser} -g users "${cfg.sharedFolder}"
    '';

    networking.firewall.extraInputRules = ''
      # Allow Syncthing GUI (port 8384) from Tailscale only
      ip saddr 100.0.0.0/8 tcp dport 8384 accept
      ip6 saddr fd7a:115c:a1e0::/48 tcp dport 8384 accept
      tcp dport 8384 drop

      # Allow Syncthing sync (port 22000) from Tailscale only
      ip saddr 100.0.0.0/8 tcp dport 22000 accept
      ip saddr 100.0.0.0/8 udp dport 22000 accept
      ip6 saddr fd7a:115c:a1e0::/48 tcp dport 22000 accept
      ip6 saddr fd7a:115c:a1e0::/48 udp dport 22000 accept
      tcp dport 22000 drop
      udp dport 22000 drop
    '';
  };
}
```

**Step 2: Write the VM test**

Create `tests/vm/syncthing-toggle.nix`:

```nix
# VM test: Syncthing module toggles on/off correctly.
{ pkgsUnstableForTests }:

{
  name = "vm-syncthing-toggle";

  nodes.enabled = {
    imports = [ (import ./_base-test-config.nix { inherit pkgsUnstableForTests; }) ];
    nixpi.syncthing.enable = true;
  };

  nodes.disabled = {
    imports = [ (import ./_base-test-config.nix { inherit pkgsUnstableForTests; }) ];
    nixpi.syncthing.enable = false;
  };

  testScript = ''
    # --- Enabled node ---
    enabled.wait_for_unit("multi-user.target")
    enabled.wait_for_unit("syncthing.service")

    # Shared directory created
    enabled.succeed("test -d /home/testuser/Shared")

    # Firewall rules present
    ruleset = enabled.succeed("nft list ruleset")
    assert "8384" in ruleset, "Missing Syncthing GUI port when enabled"
    assert "22000" in ruleset, "Missing Syncthing sync port when enabled"

    # --- Disabled node ---
    disabled.wait_for_unit("multi-user.target")
    disabled.fail("systemctl is-active syncthing.service")

    # Shared directory should NOT be created
    disabled.fail("test -d /home/testuser/Shared")

    ruleset = disabled.succeed("nft list ruleset")
    assert "8384" not in ruleset, "Syncthing GUI port present when disabled"
    assert "22000" not in ruleset, "Syncthing sync port present when disabled"
  '';
}
```

**Step 3: Update base.nix**

a) Add import: `./modules/syncthing.nix`
b) Add: `nixpi.syncthing.enable = lib.mkDefault true;`
c) Remove: `services.syncthing` block (lines 397-422)
d) Remove: Syncthing firewall rules from `extraInputRules` (lines 367-379)
e) Remove: `install -d -o ... "${userHome}/Shared"` from piConfig activation script (line 498)

**Step 4: Run tests**

Run: `nix build .#checks.x86_64-linux.vm-syncthing-toggle --no-link -L`
Expected: PASS

**Step 5: Commit**

```bash
git add infra/nixos/modules/syncthing.nix tests/vm/syncthing-toggle.nix
git add infra/nixos/base.nix flake.nix
git commit -m "feat: extract Syncthing into toggleable module"
```

---

## Task 4: Extract Password Policy Module

**Files:**

- Create: `infra/nixos/modules/password-policy.nix`
- Modify: `infra/nixos/base.nix:102-128,330-346`
- Create: `tests/vm/password-policy-toggle.nix`

**Step 1: Write the password policy module**

Create `infra/nixos/modules/password-policy.nix`:

```nix
# Password policy module — PAM-based password complexity enforcement.
#
# When enabled, enforces minimum length, digit, and special character
# requirements for local password changes (passwd and chpasswd).
{ config, pkgs, lib, ... }:

let
  cfg = config.nixpi.passwordPolicy;

  passwordPolicyCheck = pkgs.writeShellScript "nixpi-password-policy-check" ''
    set -euo pipefail

    # pam_exec with expose_authtok provides the candidate password on stdin.
    IFS= read -r password || exit 1

    if [ "''${#password}" -lt ${toString cfg.minLength} ]; then
      echo "Password must be at least ${toString cfg.minLength} characters." >&2
      exit 1
    fi

    case "$password" in
      (*[0-9]*) ;;
      (*)
        echo "Password must include at least one number." >&2
        exit 1
        ;;
    esac

    case "$password" in
      (*[[:punct:]]*) ;;
      (*)
        echo "Password must include at least one special character." >&2
        exit 1
        ;;
    esac
  '';
in
{
  options.nixpi.passwordPolicy = {
    enable = lib.mkEnableOption "Password complexity policy (PAM)";

    minLength = lib.mkOption {
      type = lib.types.int;
      default = 16;
      description = "Minimum password length.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.minLength >= 8;
        message = "nixpi.passwordPolicy.minLength must be at least 8.";
      }
    ];

    security.pam.services.passwd.rules.password.passwordPolicy = {
      order = config.security.pam.services.passwd.rules.password.unix.order - 20;
      control = "requisite";
      modulePath = "${pkgs.pam}/lib/security/pam_exec.so";
      args = [ "expose_authtok" "${passwordPolicyCheck}" ];
    };

    security.pam.services.chpasswd.rules.password.passwordPolicy = {
      order = config.security.pam.services.chpasswd.rules.password.unix.order - 20;
      control = "requisite";
      modulePath = "${pkgs.pam}/lib/security/pam_exec.so";
      args = [ "expose_authtok" "${passwordPolicyCheck}" ];
    };
  };
}
```

**Step 2: Write the VM test**

Create `tests/vm/password-policy-toggle.nix`:

```nix
# VM test: Password policy module toggles on/off correctly.
{ pkgsUnstableForTests }:

{
  name = "vm-password-policy-toggle";

  nodes.enabled = {
    imports = [ (import ./_base-test-config.nix { inherit pkgsUnstableForTests; }) ];
    nixpi.passwordPolicy.enable = true;
  };

  nodes.disabled = {
    imports = [ (import ./_base-test-config.nix { inherit pkgsUnstableForTests; }) ];
    nixpi.passwordPolicy.enable = false;
  };

  testScript = ''
    # --- Enabled node ---
    enabled.wait_for_unit("multi-user.target")

    # Reject short password
    enabled.fail("echo 'testuser:Short1!@#' | chpasswd")

    # Reject no digit
    enabled.fail("echo 'testuser:NoDigitsSpecial!@#here' | chpasswd")

    # Reject no special char
    enabled.fail("echo 'testuser:NoSpecialChar12345ab' | chpasswd")

    # Accept valid password
    enabled.succeed("echo 'testuser:ValidPassword123!@#ok' | chpasswd")

    # --- Disabled node ---
    disabled.wait_for_unit("multi-user.target")

    # Short password should be accepted when policy is off
    disabled.succeed("echo 'testuser:short1!' | chpasswd")
  '';
}
```

**Step 3: Update base.nix**

a) Add import: `./modules/password-policy.nix`
b) Add: `nixpi.passwordPolicy.enable = lib.mkDefault true;`
c) Remove: `passwordPolicyCheck` let-binding (lines 102-128)
d) Remove: `security.pam.services.passwd` and `.chpasswd` blocks (lines 330-346)

**Step 4: Run tests**

Run: `nix build .#checks.x86_64-linux.vm-password-policy-toggle --no-link -L`
Expected: PASS

**Step 5: Update existing password-policy test**

The existing `tests/vm/password-policy.nix` test should still pass since base.nix sets mkDefault true. Verify:

Run: `nix build .#checks.x86_64-linux.vm-password-policy --no-link -L`
Expected: PASS (no change needed)

**Step 6: Commit**

```bash
git add infra/nixos/modules/password-policy.nix tests/vm/password-policy-toggle.nix
git add infra/nixos/base.nix flake.nix
git commit -m "feat: extract password policy into toggleable module"
```

---

## Task 5: Extract Desktop Module

**Files:**

- Create: `infra/nixos/modules/desktop.nix`
- Modify: `infra/nixos/base.nix:225-234,285-294,463-465`
- Create: `tests/vm/desktop-toggle.nix`

**Step 1: Write the desktop module**

Create `infra/nixos/modules/desktop.nix`:

```nix
# Desktop module — GNOME desktop environment with GDM.
#
# When enabled, provisions a full GNOME desktop with GDM login manager.
# Includes desktop helper packages (networkmanagerapplet, xrandr).
{ config, pkgs, lib, ... }:

let
  cfg = config.nixpi.desktop;
in
{
  options.nixpi.desktop = {
    enable = lib.mkEnableOption "GNOME desktop environment with GDM";
  };

  config = lib.mkIf cfg.enable {
    services.xserver.enable = true;
    services.displayManager.gdm.enable = true;
    services.desktopManager.gnome.enable = true;
    services.xserver.xkb.layout = "us";

    programs.chromium.enable = true;

    environment.systemPackages = with pkgs; [
      networkmanagerapplet
      xorg.xrandr
      vscode
    ];
  };
}
```

**Step 2: Write the VM test**

Create `tests/vm/desktop-toggle.nix`:

```nix
# VM test: Desktop module toggles on/off correctly.
#
# Note: We only test the disabled state in VM since GNOME is heavy.
# The enabled state is validated by checking systemd unit files exist.
{ pkgsUnstableForTests }:

{
  name = "vm-desktop-toggle";

  nodes.disabled = {
    imports = [ (import ./_base-test-config.nix { inherit pkgsUnstableForTests; }) ];
    nixpi.desktop.enable = false;
  };

  testScript = ''
    # --- Disabled node ---
    disabled.wait_for_unit("multi-user.target")

    # GDM should not be active
    disabled.fail("systemctl is-active display-manager.service")

    # GNOME session should not exist
    disabled.fail("test -f /run/current-system/sw/share/xsessions/gnome.desktop")
  '';
}
```

**Step 3: Update base.nix**

a) Add import: `./modules/desktop.nix`
b) Add: `nixpi.desktop.enable = lib.mkDefault (config.nixpi.desktopProfile == "gnome");`
c) Remove: `desktopProfile` option (lines 225-234) — move to desktop.nix if still needed, or deprecate in favor of `nixpi.desktop.enable`
d) Remove: `services.xserver.enable`, `services.displayManager.gdm.enable`, `services.desktopManager.gnome.enable`, `services.xserver.xkb` (lines 285-294)
e) Remove: `programs.chromium.enable` (line 437)
f) Remove desktop packages from systemPackages: `networkmanagerapplet`, `xorg.xrandr`, `vscode` (lines 463-465, 450)

Note: The `desktopProfile` option can be removed since `nixpi.desktop.enable` replaces it. Existing hosts that set `desktopProfile = "gnome"` should switch to `nixpi.desktop.enable = true`. Hosts with `desktopProfile = "preserve"` should set `nixpi.desktop.enable = false`. Update `_base-test-config.nix` to remove `nixpi.desktopProfile = "preserve"` and instead set `nixpi.desktop.enable = false`.

**Step 4: Update \_base-test-config.nix**

Replace `nixpi.desktopProfile = "preserve";` with `nixpi.desktop.enable = false;`

**Step 5: Update host configs**

In `infra/nixos/hosts/nixpi.nix` and `nixos.nix`: remove any `desktopProfile` reference (they use default "gnome" which maps to `enable = true` via mkDefault).

**Step 6: Run tests**

Run: `nix build .#checks.x86_64-linux.vm-desktop-toggle --no-link -L`
Expected: PASS

**Step 7: Commit**

```bash
git add infra/nixos/modules/desktop.nix tests/vm/desktop-toggle.nix
git add infra/nixos/base.nix tests/vm/_base-test-config.nix flake.nix
git add infra/nixos/hosts/nixpi.nix infra/nixos/hosts/nixos.nix
git commit -m "feat: extract desktop into toggleable module

Replace nixpi.desktopProfile option with nixpi.desktop.enable.
GNOME, GDM, Chromium, and desktop packages move to desktop.nix."
```

---

## Task 6: Clean Up base.nix Firewall + Update Existing Tests

After Tasks 1-5, base.nix's `extraInputRules` should contain ONLY SSH rules. The ttyd, Syncthing, and Tailscale rules have been moved to their modules.

**Files:**

- Modify: `infra/nixos/base.nix` (verify firewall block is clean)
- Modify: `tests/vm/service-ensemble.nix`
- Modify: `tests/vm/firewall-rules.nix`
- Modify: `flake.nix` (register new VM tests)

**Step 1: Verify base.nix firewall is SSH-only**

The `networking.firewall.extraInputRules` in base.nix should now be:

```nix
    networking.firewall = {
      enable = true;
      extraInputRules = ''
        # Allow SSH from Tailscale and local network
        ip saddr 100.0.0.0/8 tcp dport 22 accept
        ip6 saddr fd7a:115c:a1e0::/48 tcp dport 22 accept
        ip saddr 192.168.0.0/16 tcp dport 22 accept
        ip saddr 10.0.0.0/8 tcp dport 22 accept
        tcp dport 22 drop
      '';
    };
```

Verify no other service-specific rules remain. Fix if needed.

**Step 2: Update service-ensemble test**

The test currently asserts tailscaled, syncthing, ttyd are active. These still work because base.nix sets mkDefault true. But make it explicit:

Replace `tests/vm/service-ensemble.nix`:

```nix
# VM test: core services are active when all modules enabled.
{ pkgsUnstableForTests }:

{
  name = "vm-service-ensemble";

  nodes.machine = {
    imports = [ (import ./_base-test-config.nix { inherit pkgsUnstableForTests; }) ];
    # Explicitly enable all optional modules
    nixpi.tailscale.enable = true;
    nixpi.syncthing.enable = true;
    nixpi.ttyd.enable = true;
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")

    # Core services (always on)
    machine.wait_for_unit("sshd.service")
    machine.wait_for_unit("NetworkManager.service")

    # Optional services (explicitly enabled)
    machine.wait_for_unit("tailscaled.service")
    machine.wait_for_unit("ttyd.service")
    machine.wait_for_unit("syncthing.service")

    # Key ports are listening
    machine.wait_for_open_port(22)
    machine.wait_for_open_port(7681)
  '';
}
```

**Step 3: Update firewall-rules test**

Replace `tests/vm/firewall-rules.nix`:

```nix
# VM test: nftables loaded with per-service IP-range rules.
{ pkgsUnstableForTests }:

{
  name = "vm-firewall-rules";

  nodes.machine = {
    imports = [ (import ./_base-test-config.nix { inherit pkgsUnstableForTests; }) ];
    # Enable modules to get their firewall rules
    nixpi.tailscale.enable = true;
    nixpi.syncthing.enable = true;
    nixpi.ttyd.enable = true;
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")

    ruleset = machine.succeed("nft list ruleset")

    # SSH rules (always present from base.nix)
    assert "100.0.0.0/8" in ruleset, "Missing Tailscale IPv4 range"
    assert "fd7a:115c:a1e0::/48" in ruleset, "Missing Tailscale IPv6 range"
    assert "192.168.0.0/16" in ruleset, "Missing LAN range 192.168"
    assert "10.0.0.0/8" in ruleset, "Missing LAN range 10.0"
    assert "22" in ruleset, "Missing SSH port"

    # Module-contributed rules
    assert "7681" in ruleset, "Missing ttyd port"
    assert "8384" in ruleset, "Missing Syncthing GUI port"
    assert "22000" in ruleset, "Missing Syncthing sync port"
    assert "41641" in ruleset, "Missing Tailscale WireGuard port"
  '';
}
```

**Step 4: Register new tests in flake.nix**

Add to `checks.x86_64-linux` in `flake.nix`:

```nix
        vm-tailscale-toggle     = mkVmTest ./tests/vm/tailscale-toggle.nix;
        vm-ttyd-toggle          = mkVmTest ./tests/vm/ttyd-toggle.nix;
        vm-syncthing-toggle     = mkVmTest ./tests/vm/syncthing-toggle.nix;
        vm-password-policy-toggle = mkVmTest ./tests/vm/password-policy-toggle.nix;
        vm-desktop-toggle       = mkVmTest ./tests/vm/desktop-toggle.nix;
```

**Step 5: Run all tests**

Run: `nix flake check -L`
Expected: All tests pass

**Step 6: Commit**

```bash
git add tests/vm/service-ensemble.nix tests/vm/firewall-rules.nix flake.nix
git add infra/nixos/base.nix
git commit -m "refactor: update existing tests for modular architecture

Explicitly enable modules in service-ensemble and firewall-rules tests.
Register all new toggle tests in flake.nix."
```

---

## Task 7: Write Multi-Module Combo Tests

**Files:**

- Create: `tests/vm/minimal-config.nix`
- Create: `tests/vm/full-stack.nix`
- Modify: `flake.nix`

**Step 1: Write minimal config test (all modules disabled)**

Create `tests/vm/minimal-config.nix`:

```nix
# VM test: minimal config with ALL optional modules disabled.
# Only SSH + NetworkManager + core should be running.
{ pkgsUnstableForTests }:

{
  name = "vm-minimal-config";

  nodes.machine = {
    imports = [ (import ./_base-test-config.nix { inherit pkgsUnstableForTests; }) ];
    # Disable everything optional
    nixpi.tailscale.enable = false;
    nixpi.syncthing.enable = false;
    nixpi.ttyd.enable = false;
    nixpi.passwordPolicy.enable = false;
    nixpi.desktop.enable = false;
    nixpi.objects.enable = false;
    nixpi.heartbeat.enable = false;
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")

    # Core services still running
    machine.wait_for_unit("sshd.service")
    machine.wait_for_unit("NetworkManager.service")
    machine.wait_for_open_port(22)

    # All optional services should NOT be running
    machine.fail("systemctl is-active tailscaled.service")
    machine.fail("systemctl is-active ttyd.service")
    machine.fail("systemctl is-active syncthing.service")
    machine.fail("systemctl is-active display-manager.service")

    # Firewall should only have SSH rules
    ruleset = machine.succeed("nft list ruleset")
    assert "22" in ruleset, "SSH port missing from minimal config"
    assert "7681" not in ruleset, "ttyd port leaked into minimal config"
    assert "8384" not in ruleset, "Syncthing port leaked into minimal config"
    assert "41641" not in ruleset, "Tailscale port leaked into minimal config"

    # Password policy not enforced
    machine.succeed("echo 'testuser:short1!' | chpasswd")
  '';
}
```

**Step 2: Write full-stack test (all modules enabled)**

Create `tests/vm/full-stack.nix`:

```nix
# VM test: full stack with ALL optional modules enabled.
# Verifies no conflicts between modules.
{ pkgsUnstableForTests }:

{
  name = "vm-full-stack";

  nodes.machine = { config, pkgs, lib, ... }: {
    imports = [ (import ./_base-test-config.nix { inherit pkgsUnstableForTests; }) ];
    # Enable everything (except desktop — too heavy for VM)
    nixpi.tailscale.enable = true;
    nixpi.syncthing.enable = true;
    nixpi.ttyd.enable = true;
    nixpi.passwordPolicy.enable = true;
    nixpi.objects.enable = true;
    nixpi.heartbeat.enable = true;
    nixpi.heartbeat.intervalMinutes = 60;
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")

    # All services running
    machine.wait_for_unit("sshd.service")
    machine.wait_for_unit("tailscaled.service")
    machine.wait_for_unit("ttyd.service")
    machine.wait_for_unit("syncthing.service")
    machine.wait_for_unit("NetworkManager.service")

    # Heartbeat timer enabled
    machine.succeed("systemctl is-enabled nixpi-heartbeat.timer")

    # All ports open
    machine.wait_for_open_port(22)
    machine.wait_for_open_port(7681)

    # Object store directories exist
    machine.succeed("test -d /home/testuser/Nixpi/data/objects/journal")

    # Password policy enforced
    machine.fail("echo 'testuser:short1!' | chpasswd")
    machine.succeed("echo 'testuser:ValidPassword123!@#ok' | chpasswd")

    # Firewall has all rules
    ruleset = machine.succeed("nft list ruleset")
    assert "22" in ruleset, "Missing SSH"
    assert "7681" in ruleset, "Missing ttyd"
    assert "8384" in ruleset, "Missing Syncthing"
    assert "41641" in ruleset, "Missing Tailscale"
  '';
}
```

**Step 3: Register in flake.nix**

```nix
        vm-minimal-config       = mkVmTest ./tests/vm/minimal-config.nix;
        vm-full-stack           = mkVmTest ./tests/vm/full-stack.nix;
```

**Step 4: Run tests**

Run: `nix build .#checks.x86_64-linux.vm-minimal-config --no-link -L && nix build .#checks.x86_64-linux.vm-full-stack --no-link -L`
Expected: Both PASS

**Step 5: Commit**

```bash
git add tests/vm/minimal-config.nix tests/vm/full-stack.nix flake.nix
git commit -m "test: add minimal and full-stack multi-module VM tests"
```

---

## Task 8: Add nixpi-agent System User

**Files:**

- Create: `tests/vm/assistant-user.nix`
- Modify: `infra/nixos/base.nix`
- Modify: `infra/nixos/lib/mk-nixpi-service.nix`
- Modify: `flake.nix`

**Step 1: Write the VM test (TDD — write test first)**

Create `tests/vm/assistant-user.nix`:

```nix
# VM test: nixpi-agent system user exists with correct properties.
{ pkgsUnstableForTests }:

{
  name = "vm-assistant-user";

  nodes.machine = {
    imports = [ (import ./_base-test-config.nix { inherit pkgsUnstableForTests; }) ];
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")

    # nixpi-agent system user exists
    machine.succeed("id nixpi-agent")

    # Is a system user (UID < 1000)
    uid = int(machine.succeed("id -u nixpi-agent").strip())
    assert uid < 1000, f"nixpi-agent UID {uid} is not a system user"

    # Has nixpi group
    groups = machine.succeed("groups nixpi-agent")
    assert "nixpi" in groups, f"nixpi-agent not in nixpi group: {groups}"

    # Home is /var/lib/nixpi
    home = machine.succeed("getent passwd nixpi-agent | cut -d: -f6").strip()
    assert home == "/var/lib/nixpi", f"Unexpected home: {home}"

    # Home directory exists
    machine.succeed("test -d /var/lib/nixpi")

    # Primary user is in nixpi group
    primary_groups = machine.succeed("groups testuser")
    assert "nixpi" in primary_groups, f"testuser not in nixpi group: {primary_groups}"

    # No login shell
    shell = machine.succeed("getent passwd nixpi-agent | cut -d: -f7").strip()
    assert "nologin" in shell or "false" in shell, f"nixpi-agent has login shell: {shell}"
  '';
}
```

**Step 2: Run test to verify it fails**

Run: `nix build .#checks.x86_64-linux.vm-assistant-user --no-link -L`
Expected: FAIL — nixpi-agent user does not exist yet

**Step 3: Implement in base.nix**

Add to `base.nix` options block:

```nix
  options.nixpi.assistantUser = lib.mkOption {
    type = lib.types.str;
    default = "nixpi-agent";
    description = "System user that owns Nixpi services and data.";
  };
```

Add to `base.nix` config block:

```nix
    # Nixpi assistant system user — owns services and agent state.
    users.groups.nixpi = {};

    users.users.${config.nixpi.assistantUser} = {
      isSystemUser = true;
      group = "nixpi";
      home = "/var/lib/nixpi";
      createHome = true;
      description = "Nixpi AI assistant";
    };

    # Primary user gets read access to agent state via group membership.
    users.users.${primaryUser}.extraGroups = [ "wheel" "networkmanager" "nixpi" ];
```

Note: Replace the existing `users.users.${primaryUser}` block to add `"nixpi"` to extraGroups.

**Step 4: Run test to verify it passes**

Run: `nix build .#checks.x86_64-linux.vm-assistant-user --no-link -L`
Expected: PASS

**Step 5: Update mk-nixpi-service.nix to use assistant user**

In `infra/nixos/lib/mk-nixpi-service.nix`, change:

```nix
  # Old
  primaryUser = config.nixpi.primaryUser;

  # New
  assistantUser = config.nixpi.assistantUser;
```

And update the service config:

```nix
  serviceConfig = {
    Type = serviceType;
    User = assistantUser;
    Group = "nixpi";
    # ...
    Environment = baseEnv ++ extraEnv;
  };
```

Update `baseEnv` to use assistantUser's home:

```nix
  baseEnv = [
    "PI_CODING_AGENT_DIR=${piDir}"
    "NIXPI_OBJECTS_DIR=${config.nixpi.objects.dataDir}"
    "HOME=/var/lib/nixpi"
  ];
```

**Step 6: Update piConfig activation script in base.nix**

The Pi agent directories should now be owned by the assistant user:

```nix
  system.activationScripts.piConfig = lib.stringAfter [ "users" ] ''
    PI_DIR="${piDir}"

    install -d -o ${config.nixpi.assistantUser} -g nixpi "$PI_DIR"/{sessions,extensions,skills,prompts,themes}

    cat > "$PI_DIR/SYSTEM.md" <<'SYSEOF'
${piSystemPrompt}
SYSEOF
    chown ${config.nixpi.assistantUser}:nixpi "$PI_DIR/SYSTEM.md"

    if [ ! -f "$PI_DIR/settings.json" ]; then
      cat > "$PI_DIR/settings.json" <<'JSONEOF'
${settingsSeedJson}
JSONEOF
    fi
    if [ -f "$PI_DIR/settings.json" ]; then
      chown ${config.nixpi.assistantUser}:nixpi "$PI_DIR/settings.json"
    fi
  '';
```

**Step 7: Register test and run full suite**

Add to flake.nix: `vm-assistant-user = mkVmTest ./tests/vm/assistant-user.nix;`

Run: `nix flake check -L`
Expected: All tests pass

**Step 8: Commit**

```bash
git add tests/vm/assistant-user.nix flake.nix
git add infra/nixos/base.nix infra/nixos/lib/mk-nixpi-service.nix
git commit -m "feat: add nixpi-agent system user for service ownership

Services now run as nixpi-agent (system user) instead of the primary
human user. Pi agent state owned by nixpi-agent, primary user gets
read access via nixpi group membership."
```

---

## Task 9: Add Secrets Management

**Files:**

- Create: `tests/vm/secrets-directory.nix`
- Modify: `infra/nixos/base.nix`
- Modify: `flake.nix`

**Step 1: Write the VM test (TDD)**

Create `tests/vm/secrets-directory.nix`:

```nix
# VM test: /etc/nixpi/secrets/ directory exists with correct permissions.
{ pkgsUnstableForTests }:

{
  name = "vm-secrets-directory";

  nodes.machine = {
    imports = [ (import ./_base-test-config.nix { inherit pkgsUnstableForTests; }) ];
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")

    # Secrets directory exists
    machine.succeed("test -d /etc/nixpi/secrets")

    # Owned by root
    owner = machine.succeed("stat -c '%U' /etc/nixpi/secrets").strip()
    assert owner == "root", f"Secrets dir owned by {owner}, expected root"

    # Mode 0700
    mode = machine.succeed("stat -c '%a' /etc/nixpi/secrets").strip()
    assert mode == "700", f"Secrets dir mode is {mode}, expected 700"

    # Not world-readable
    machine.fail("su -s /bin/sh testuser -c 'ls /etc/nixpi/secrets'")
  '';
}
```

**Step 2: Run test — should FAIL**

Run: `nix build .#checks.x86_64-linux.vm-secrets-directory --no-link -L`
Expected: FAIL

**Step 3: Implement secrets directory in base.nix**

Add activation script:

```nix
    system.activationScripts.nixpiSecrets = lib.stringAfter [ "users" ] ''
      install -d -m 0700 -o root -g root /etc/nixpi/secrets
    '';
```

**Step 4: Update piWrapper to source secrets**

In base.nix, update the `piWrapper` script:

```nix
  piWrapper = pkgs.writeShellApplication {
    name = "pi";
    runtimeInputs = [ pkgs.nodejs_22 ];
    text = ''
      ${npmEnvSetup}

      # Source API key from secrets if available
      if [ -f /etc/nixpi/secrets/ai-provider.env ]; then
        set -a
        # shellcheck source=/dev/null
        . /etc/nixpi/secrets/ai-provider.env
        set +a
      fi

      exec npx --yes @mariozechner/pi-coding-agent@${config.nixpi.piAgentVersion} "$@"
    '';
  };
```

**Step 5: Run test — should PASS**

Run: `nix build .#checks.x86_64-linux.vm-secrets-directory --no-link -L`
Expected: PASS

**Step 6: Register and commit**

```bash
git add tests/vm/secrets-directory.nix flake.nix infra/nixos/base.nix
git commit -m "feat: add /etc/nixpi/secrets/ for persistent secret storage

Secrets directory created on activation with root:root 0700 perms.
piWrapper sources ai-provider.env for API key injection."
```

---

## Task 10: Export nixosModules from Flake

**Files:**

- Modify: `flake.nix`

**Step 1: Add nixosModules outputs**

In `flake.nix`, add to the `outputs` attrset (after `devShells` and before `nixosConfigurations`):

```nix
      # NixOS modules for external consumers.
      # Use nixosModules.default for the full Nixpi stack.
      # Use individual modules for selective imports.
      nixosModules = {
        default = ./infra/nixos/base.nix;
        base = ./infra/nixos/base.nix;
        tailscale = ./infra/nixos/modules/tailscale.nix;
        syncthing = ./infra/nixos/modules/syncthing.nix;
        ttyd = ./infra/nixos/modules/ttyd.nix;
        matrix = ./infra/nixos/modules/matrix.nix;
        heartbeat = ./infra/nixos/modules/heartbeat.nix;
        objects = ./infra/nixos/modules/objects.nix;
        passwordPolicy = ./infra/nixos/modules/password-policy.nix;
        desktop = ./infra/nixos/modules/desktop.nix;
      };
```

Note: `default` and `base` are the same — `base.nix` already imports all modules. Individual module exports are for users who want to pick and choose without base.nix.

**Step 2: Verify flake evaluation**

Run: `nix flake check --no-build`
Expected: No evaluation errors

**Step 3: Commit**

```bash
git add flake.nix
git commit -m "feat: export nixosModules from flake for external consumers"
```

---

## Task 11: Create Flake Template

**Files:**

- Create: `templates/default/flake.nix`
- Create: `templates/default/nixpi-config.nix`
- Modify: `flake.nix`

**Step 1: Create the template flake.nix**

Create `templates/default/flake.nix`:

```nix
# Nixpi server configuration — generated by `nix flake init -t github:alexradunet/nixpi`
#
# Customize nixpi-config.nix to enable/disable modules,
# then run: sudo nixos-rebuild switch --flake .
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
      nixosConfigurations.nixpi = nixpkgs.lib.nixosSystem {
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

**Step 2: Create the template nixpi-config.nix**

Create `templates/default/nixpi-config.nix`:

```nix
# Nixpi configuration — edit this file to customize your server.
# Run `sudo nixos-rebuild switch --flake .` after changes.
{ config, lib, ... }:

{
  # --- Identity ---
  networking.hostName = "nixpi";  # Change to your hostname
  nixpi.primaryUser = "nixpi";    # Change to your Linux username
  nixpi.timeZone = "UTC";         # Change to your timezone

  # --- Modules (toggle on/off) ---
  nixpi.tailscale.enable = true;
  nixpi.syncthing.enable = true;
  nixpi.ttyd.enable = true;
  nixpi.desktop.enable = true;
  nixpi.passwordPolicy.enable = true;
  nixpi.objects.enable = true;

  # nixpi.heartbeat.enable = false;
  # nixpi.heartbeat.intervalMinutes = 30;

  # nixpi.channels.matrix.enable = false;
  # nixpi.channels.matrix.humanUser = "human";
}
```

**Step 3: Register template in flake.nix**

Add to flake.nix outputs:

```nix
      # Flake template for new Nixpi installations.
      # Usage: nix flake init -t github:alexradunet/nixpi
      templates.default = {
        path = ./templates/default;
        description = "Nixpi server configuration scaffold";
      };
```

**Step 4: Verify template**

Run: `nix flake check --no-build`
Expected: No evaluation errors

**Step 5: Commit**

```bash
git add templates/default/flake.nix templates/default/nixpi-config.nix flake.nix
git commit -m "feat: add flake template for new Nixpi installations

Users can scaffold a config with:
  nix flake init -t github:alexradunet/nixpi"
```

---

## Task 12: Build Setup Wizard

**Files:**

- Create: `scripts/nixpi-setup.sh`
- Modify: `infra/nixos/scripts/nixpi-cli.sh`
- Modify: `infra/nixos/base.nix` (add dialog to systemPackages + nixpiCli runtimeInputs)
- Create: `tests/test_setup_wizard.sh`

**Step 1: Write shell test for config generation (TDD)**

Create `tests/test_setup_wizard.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/helpers.sh"

SETUP_SCRIPT="$SCRIPT_DIR/../scripts/nixpi-setup.sh"

# Test: generate_nixpi_config produces valid Nix
test_generate_nixpi_config() {
  local tmp_dir
  tmp_dir="$(mktemp -d)"
  trap 'rm -rf "$tmp_dir"' EXIT

  # Source only the generator function
  NIXPI_SETUP_GENERATE_ONLY=1 source "$SETUP_SCRIPT"

  # Call the generator
  generate_nixpi_config \
    --hostname "testbox" \
    --username "alex" \
    --timezone "Europe/Bucharest" \
    --tailscale true \
    --syncthing true \
    --ttyd false \
    --desktop true \
    --password-policy true \
    --heartbeat false \
    --matrix false \
    --output "$tmp_dir/nixpi-config.nix"

  # File was created
  assert_file_exists "$tmp_dir/nixpi-config.nix"

  # Contains expected values
  assert_file_contains "$tmp_dir/nixpi-config.nix" 'networking.hostName = "testbox"'
  assert_file_contains "$tmp_dir/nixpi-config.nix" 'nixpi.primaryUser = "alex"'
  assert_file_contains "$tmp_dir/nixpi-config.nix" 'nixpi.timeZone = "Europe/Bucharest"'
  assert_file_contains "$tmp_dir/nixpi-config.nix" 'nixpi.tailscale.enable = true'
  assert_file_contains "$tmp_dir/nixpi-config.nix" 'nixpi.ttyd.enable = false'
  assert_file_contains "$tmp_dir/nixpi-config.nix" 'nixpi.heartbeat.enable = false'
}

test_generate_nixpi_config

test_generate_flake() {
  local tmp_dir
  tmp_dir="$(mktemp -d)"
  trap 'rm -rf "$tmp_dir"' EXIT

  NIXPI_SETUP_GENERATE_ONLY=1 source "$SETUP_SCRIPT"

  generate_flake_nix \
    --hostname "testbox" \
    --output "$tmp_dir/flake.nix"

  assert_file_exists "$tmp_dir/flake.nix"
  assert_file_contains "$tmp_dir/flake.nix" 'nixpi.url = "github:alexradunet/nixpi"'
  assert_file_contains "$tmp_dir/flake.nix" "nixosConfigurations.testbox"
}

test_generate_flake

echo "All setup wizard tests passed"
```

**Step 2: Run test — should FAIL**

Run: `nix-shell -p yq-go --run "./tests/test_setup_wizard.sh"`
Expected: FAIL — setup script doesn't exist yet

**Step 3: Write the setup wizard**

Create `scripts/nixpi-setup.sh` (this is a large file — key sections below):

```bash
#!/usr/bin/env bash
set -euo pipefail

# --- Config generator functions (testable without dialog) ---

generate_nixpi_config() {
  local hostname="" username="" timezone="UTC"
  local tailscale="true" syncthing="true" ttyd="true"
  local desktop="true" password_policy="true"
  local heartbeat="false" matrix="false"
  local output=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --hostname) hostname="$2"; shift 2 ;;
      --username) username="$2"; shift 2 ;;
      --timezone) timezone="$2"; shift 2 ;;
      --tailscale) tailscale="$2"; shift 2 ;;
      --syncthing) syncthing="$2"; shift 2 ;;
      --ttyd) ttyd="$2"; shift 2 ;;
      --desktop) desktop="$2"; shift 2 ;;
      --password-policy) password_policy="$2"; shift 2 ;;
      --heartbeat) heartbeat="$2"; shift 2 ;;
      --matrix) matrix="$2"; shift 2 ;;
      --output) output="$2"; shift 2 ;;
      *) echo "Unknown option: $1" >&2; return 1 ;;
    esac
  done

  cat > "$output" <<EOF
# Nixpi configuration — generated by nixpi setup
# Run \`sudo nixos-rebuild switch --flake .\` after changes.
{ config, lib, ... }:

{
  # --- Identity ---
  networking.hostName = "$hostname";
  nixpi.primaryUser = "$username";
  nixpi.timeZone = "$timezone";

  # --- Modules ---
  nixpi.tailscale.enable = $tailscale;
  nixpi.syncthing.enable = $syncthing;
  nixpi.ttyd.enable = $ttyd;
  nixpi.desktop.enable = $desktop;
  nixpi.passwordPolicy.enable = $password_policy;
  nixpi.objects.enable = true;
  nixpi.heartbeat.enable = $heartbeat;
  nixpi.channels.matrix.enable = $matrix;
}
EOF
}

generate_flake_nix() {
  local hostname="" output=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --hostname) hostname="$2"; shift 2 ;;
      --output) output="$2"; shift 2 ;;
      *) echo "Unknown option: $1" >&2; return 1 ;;
    esac
  done

  cat > "$output" <<'FLAKEEOF'
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
FLAKEEOF

  cat >> "$output" <<EOF
      nixosConfigurations.$hostname = nixpkgs.lib.nixosSystem {
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
EOF
}

# When sourced for testing, only export functions
if [[ "${NIXPI_SETUP_GENERATE_ONLY:-0}" == "1" ]]; then
  return 0 2>/dev/null || exit 0
fi

# --- Dialog TUI wizard (runs only when executed directly) ---

DIALOG=${DIALOG:-dialog}
TARGET_DIR="${1:-$HOME/nixpi-server}"

show_welcome() {
  $DIALOG --title "Nixpi Setup" --msgbox \
    "Welcome to Nixpi!\n\nThis wizard will configure your Nixpi server.\n\nTarget directory: $TARGET_DIR" \
    12 60
}

get_basic_info() {
  HOSTNAME=$($DIALOG --title "Hostname" --inputbox "Enter your server hostname:" 8 50 "$(hostname)" 3>&1 1>&2 2>&3) || exit 1
  USERNAME=$($DIALOG --title "Username" --inputbox "Enter your Linux username:" 8 50 "${SUDO_USER:-$(whoami)}" 3>&1 1>&2 2>&3) || exit 1
  TIMEZONE=$($DIALOG --title "Timezone" --menu "Select your timezone:" 20 60 12 \
    "UTC" "Coordinated Universal Time" \
    "US/Eastern" "Eastern Time" \
    "US/Central" "Central Time" \
    "US/Mountain" "Mountain Time" \
    "US/Pacific" "Pacific Time" \
    "Europe/London" "UK Time" \
    "Europe/Berlin" "Central European" \
    "Europe/Bucharest" "Eastern European" \
    "Asia/Tokyo" "Japan" \
    "Asia/Shanghai" "China" \
    "Australia/Sydney" "Australia Eastern" \
    "Other" "Enter custom timezone" \
    3>&1 1>&2 2>&3) || exit 1

  if [[ "$TIMEZONE" == "Other" ]]; then
    TIMEZONE=$($DIALOG --title "Custom Timezone" --inputbox "Enter timezone (e.g. America/New_York):" 8 50 "UTC" 3>&1 1>&2 2>&3) || exit 1
  fi
}

get_ai_config() {
  AI_PROVIDER=$($DIALOG --title "AI Provider" --menu "Select your AI provider:" 14 60 5 \
    "anthropic" "Anthropic (Claude)" \
    "openai" "OpenAI (GPT)" \
    "openai-codex" "OpenAI Codex" \
    "custom" "Custom (OpenAI-compatible)" \
    3>&1 1>&2 2>&3) || exit 1

  case "$AI_PROVIDER" in
    anthropic)  DEFAULT_MODEL="claude-sonnet-4-6" ;;
    openai)     DEFAULT_MODEL="gpt-4.1" ;;
    openai-codex) DEFAULT_MODEL="codex-mini-latest" ;;
    custom)     DEFAULT_MODEL="" ;;
  esac

  AI_MODEL=$($DIALOG --title "Model" --inputbox "Enter model name:" 8 50 "$DEFAULT_MODEL" 3>&1 1>&2 2>&3) || exit 1
  AI_KEY=$($DIALOG --title "API Key" --passwordbox "Enter your API key:" 8 60 3>&1 1>&2 2>&3) || exit 1

  AI_THINKING=$($DIALOG --title "Thinking Level" --menu "Select thinking level:" 12 60 4 \
    "low" "Fast, minimal reasoning" \
    "medium" "Balanced" \
    "high" "More thorough reasoning" \
    "xhigh" "Maximum reasoning depth" \
    3>&1 1>&2 2>&3) || exit 1
}

get_modules() {
  MODULES=$($DIALOG --title "Modules" --checklist "Select modules to enable:" 20 60 8 \
    "tailscale" "Tailscale VPN" ON \
    "syncthing" "Syncthing file sync" ON \
    "ttyd" "Web terminal" ON \
    "desktop" "GNOME desktop" ON \
    "password-policy" "Password policy (16+ chars)" ON \
    "heartbeat" "Periodic agent wake cycle" OFF \
    "matrix" "Matrix server + bridge" OFF \
    3>&1 1>&2 2>&3) || exit 1
}

module_enabled() {
  [[ "$MODULES" == *"$1"* ]] && echo "true" || echo "false"
}

show_review() {
  $DIALOG --title "Review" --yesno \
    "Hostname: $HOSTNAME\nUsername: $USERNAME\nTimezone: $TIMEZONE\nAI: $AI_PROVIDER / $AI_MODEL\nModules: $MODULES\n\nApply this configuration?" \
    14 60
}

apply_config() {
  mkdir -p "$TARGET_DIR"

  # Generate hardware config
  nixos-generate-config --show-hardware-config > "$TARGET_DIR/hardware.nix"

  # Generate flake.nix
  generate_flake_nix --hostname "$HOSTNAME" --output "$TARGET_DIR/flake.nix"

  # Generate nixpi-config.nix
  generate_nixpi_config \
    --hostname "$HOSTNAME" \
    --username "$USERNAME" \
    --timezone "$TIMEZONE" \
    --tailscale "$(module_enabled tailscale)" \
    --syncthing "$(module_enabled syncthing)" \
    --ttyd "$(module_enabled ttyd)" \
    --desktop "$(module_enabled desktop)" \
    --password-policy "$(module_enabled password-policy)" \
    --heartbeat "$(module_enabled heartbeat)" \
    --matrix "$(module_enabled matrix)" \
    --output "$TARGET_DIR/nixpi-config.nix"

  # Store API key
  install -d -m 0700 -o root -g root /etc/nixpi/secrets
  printf '%s=%s\n' "NIXPI_AI_API_KEY" "$AI_KEY" > /etc/nixpi/secrets/ai-provider.env
  chmod 0600 /etc/nixpi/secrets/ai-provider.env

  # Seed Pi settings.json
  local pi_dir="/var/lib/nixpi/agent"
  install -d -m 0755 "$pi_dir"
  if [[ ! -f "$pi_dir/settings.json" ]]; then
    cat > "$pi_dir/settings.json" <<PIEOF
{
  "skills": [],
  "packages": [],
  "defaultProvider": "$AI_PROVIDER",
  "defaultModel": "$AI_MODEL",
  "defaultThinkingLevel": "$AI_THINKING"
}
PIEOF
  fi

  # Initialize git repo for flake
  (cd "$TARGET_DIR" && git init && git add -A)

  # Apply NixOS config
  $DIALOG --title "Applying..." --infobox "Running nixos-rebuild switch...\nThis may take several minutes." 6 50
  (cd "$TARGET_DIR" && sudo nixos-rebuild switch --flake "path:.#$HOSTNAME") 2>&1 | \
    $DIALOG --title "Build Progress" --programbox 20 80

  # Mark setup complete
  install -d -m 0755 /etc/nixpi
  touch /etc/nixpi/.setup-complete

  $DIALOG --title "Success" --msgbox \
    "Nixpi is configured!\n\nConfig directory: $TARGET_DIR\nRebuild: cd $TARGET_DIR && sudo nixos-rebuild switch --flake ." \
    10 60
}

# --- Main ---
show_welcome
get_basic_info
get_ai_config
get_modules
show_review && apply_config
```

**Step 4: Run shell tests**

Run: `nix-shell -p yq-go --run "./tests/test_setup_wizard.sh"`
Expected: PASS (generator functions work)

**Step 5: Add `setup` subcommand to nixpi-cli.sh**

In `infra/nixos/scripts/nixpi-cli.sh`, add a new case before the `*)` fallthrough:

```bash
  setup)
    shift || true
    exec bash "$REPO_ROOT/scripts/nixpi-setup.sh" "$@"
    ;;
```

And add to the help text:

```
  nixpi setup [target-dir]                   Run the setup wizard (first-time or reconfigure)
```

**Step 6: Add dialog to nixpiCli runtimeInputs in base.nix**

In the `nixpiCli` definition, add `pkgs.dialog`:

```nix
  nixpiCli = pkgs.writeShellApplication {
    name = "nixpi";
    runtimeInputs = [ pkgs.jq pkgs.nodejs_22 pkgs.dialog piWrapper ];
```

**Step 7: Commit**

```bash
git add scripts/nixpi-setup.sh tests/test_setup_wizard.sh
git add infra/nixos/scripts/nixpi-cli.sh infra/nixos/base.nix
git commit -m "feat: add dialog TUI setup wizard (nixpi setup)

Generates flake.nix, hardware.nix, and nixpi-config.nix for a new
Nixpi server. Configures AI provider, module selection, and secrets."
```

---

## Task 13: Update Bootstrap Script

**Files:**

- Modify: `scripts/bootstrap-fresh-nixos.sh`

**Step 1: Rewrite bootstrap to integrate wizard**

Replace `scripts/bootstrap-fresh-nixos.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

# Nixpi bootstrap — one-command install for fresh NixOS machines.
# Run as root: sudo bash bootstrap-fresh-nixos.sh [target-dir]

usage() {
  echo "usage: sudo $0 [--dry-run] [--non-interactive] [target-dir]" >&2
  exit 2
}

if [[ "$(id -u)" -ne 0 ]]; then
  echo "error: bootstrap must run as root (use sudo)" >&2
  exit 1
fi

DRY_RUN=0
NON_INTERACTIVE=0
TARGET_DIR="${1:-${SUDO_HOME:-$HOME}/nixpi-server}"
POSITIONAL_SET=0
NIXPI_REPO="https://github.com/alexradunet/nixpi.git"
BOOTSTRAP_DIR="/tmp/nixpi-bootstrap"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --non-interactive) NON_INTERACTIVE=1; shift ;;
    -h|--help) usage ;;
    -*) echo "error: unknown option: $1" >&2; usage ;;
    *)
      if [[ "$POSITIONAL_SET" -eq 1 ]]; then usage; fi
      TARGET_DIR="$1"; POSITIONAL_SET=1; shift ;;
  esac
done

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "DRY RUN: would clone $NIXPI_REPO to $BOOTSTRAP_DIR"
  echo "DRY RUN: would run setup wizard targeting $TARGET_DIR"
  echo "DRY RUN: would nixos-rebuild switch"
  exit 0
fi

# Clone Nixpi repo for bootstrap scripts
if [[ ! -d "$BOOTSTRAP_DIR/.git" ]]; then
  nix --extra-experimental-features "nix-command flakes" shell nixpkgs#git -c \
    git clone "$NIXPI_REPO" "$BOOTSTRAP_DIR"
fi

# Run setup wizard
if [[ "$NON_INTERACTIVE" -eq 1 ]]; then
  echo "Non-interactive mode: generating default config at $TARGET_DIR"
  mkdir -p "$TARGET_DIR"
  nixos-generate-config --show-hardware-config > "$TARGET_DIR/hardware.nix"

  NIXPI_SETUP_GENERATE_ONLY=1 source "$BOOTSTRAP_DIR/scripts/nixpi-setup.sh"
  generate_flake_nix --hostname "$(hostname)" --output "$TARGET_DIR/flake.nix"
  generate_nixpi_config \
    --hostname "$(hostname)" \
    --username "${SUDO_USER:-nixpi}" \
    --timezone "UTC" \
    --tailscale true --syncthing true --ttyd true \
    --desktop true --password-policy true \
    --heartbeat false --matrix false \
    --output "$TARGET_DIR/nixpi-config.nix"

  (cd "$TARGET_DIR" && git init && git add -A)
  (cd "$TARGET_DIR" && nixos-rebuild switch --flake "path:.#$(hostname)")
else
  nix --extra-experimental-features "nix-command flakes" shell nixpkgs#dialog -c \
    bash "$BOOTSTRAP_DIR/scripts/nixpi-setup.sh" "$TARGET_DIR"
fi

install -d -m 0755 /etc/nixpi
touch /etc/nixpi/.setup-complete

echo "bootstrap-fresh-nixos: complete!"
echo "Config directory: $TARGET_DIR"
echo "Rebuild: cd $TARGET_DIR && sudo nixos-rebuild switch --flake ."
```

**Step 2: Add first-run detection**

Create `/etc/profile.d/nixpi-first-run.sh` via base.nix activation:

In base.nix, add:

```nix
    environment.etc."profile.d/nixpi-first-run.sh".text = ''
      if [ ! -f /etc/nixpi/.setup-complete ] && command -v nixpi >/dev/null 2>&1; then
        echo ""
        echo "  Welcome to Nixpi! Run 'nixpi setup' to configure your server."
        echo ""
      fi
    '';
```

**Step 3: Commit**

```bash
git add scripts/bootstrap-fresh-nixos.sh infra/nixos/base.nix
git commit -m "feat: update bootstrap for wizard integration + first-run detection

Bootstrap now runs as root, clones repo to /tmp, launches setup wizard.
First-run message shown until /etc/nixpi/.setup-complete exists."
```

---

## Task 14: Final Verification

**Step 1: Run the full test suite**

Run: `nix flake check -L`
Expected: All VM tests pass

**Step 2: Verify flake evaluation**

Run: `nix flake show`
Expected: Lists nixosModules, templates, checks, devShells, nixosConfigurations

**Step 3: Verify template works**

```bash
tmp_dir=$(mktemp -d)
cd "$tmp_dir"
nix flake init -t /home/alex/Nixpi
ls -la  # Should show flake.nix, nixpi-config.nix
cat flake.nix  # Should reference nixpi
```

**Step 4: Run shell tests**

Run: `nix-shell -p yq-go --run "./scripts/test.sh"`
Expected: All shell tests pass

**Step 5: Final commit**

If any fixes needed from verification, commit them.

```bash
git commit -m "chore: final verification of modular installer system"
```

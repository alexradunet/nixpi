# Base NixOS module — shared config loaded by every host.
#
# `{ config, pkgs, lib, ... }:` is the NixOS module function signature.
# NixOS calls this function and passes in:
#   config — the fully resolved system config (for reading other modules' values)
#   pkgs   — the Nix package set
#   lib    — helper functions (merging, filtering, etc.)
#   ...    — catches any extra args so the module stays forward-compatible
{ config, pkgs, lib, ... }:

# `let ... in` binds local variables. Everything between `let` and `in`
# is only visible within this file.
let
  # Shared guidelines referenced by both runtime and dev system prompts.
  sharedGuidelines = ''
    - Prefer declarative Nix changes over imperative system mutation
    - Never modify /etc or systemd units directly; edit NixOS config instead
    - Protect secrets: never read ${runtimePiDir}/auth.json, ~/.ssh/*, or .env files
  '';

  piSystemPrompt = ''
    You are an AI assistant running on nixpi, a NixOS-based AI-first workstation.

    ## Environment
    - OS: NixOS (declarative, flake-based)
    - Config repo: ${repoRoot}
    - Rebuild: cd ${repoRoot} && sudo nixos-rebuild switch --flake .
    - VPN: Tailscale (services restricted to Tailscale + LAN)
    - File sync: Syncthing

    ## Guidelines
    - Follow AGENTS.md conventions
    ${sharedGuidelines}
  '';

  piDevSystemPrompt = ''
    You are the Nixpi developer-mode assistant.

    ## Mission
    - Act as a maintainer/developer agent for Nixpi evolution tasks.
    - Prefer Pi-native workflows while following repository guardrails.

    ## Mandatory rules
    - Follow AGENTS.md conventions and strict TDD (Red -> Green -> Refactor).
    - For features: include happy path, failure path, and at least one edge case.
    ${sharedGuidelines}
  '';

  # Lightweight Pi install path: use npm package directly via npx,
  # avoiding the large llm-agents flake dependency.
  piWrapper = pkgs.writeShellScriptBin "pi" ''
    set -euo pipefail

    export npm_config_update_notifier=false
    export npm_config_audit=false
    export npm_config_fund=false
    export npm_config_cache="''${XDG_CACHE_HOME:-$HOME/.cache}/nixpi-npm"
    export npm_config_prefix="''${XDG_DATA_HOME:-$HOME/.local/share}/nixpi-npm-global"

    mkdir -p "$npm_config_cache" "$npm_config_prefix"

    # Pin package version to keep behavior stable across rebuilds.
    exec ${pkgs.nodejs_22}/bin/npx --yes @mariozechner/pi-coding-agent@0.55.1 "$@"
  '';

  nixpiCli = pkgs.writeShellScriptBin "nixpi" ''
    set -euo pipefail

    PI_BIN="${piWrapper}/bin/pi"
    RUNTIME_DIR="${runtimePiDir}"
    DEV_DIR="${devPiDir}"

    case "''${1-}" in
      dev)
        shift
        export PI_CODING_AGENT_DIR="$DEV_DIR"
        exec "$PI_BIN" "$@"
        ;;
      mode)
        shift
        case "''${1-}" in
          ""|runtime)
            if [ "''${1-}" = "runtime" ]; then
              shift
            fi
            export PI_CODING_AGENT_DIR="$RUNTIME_DIR"
            exec "$PI_BIN" "$@"
            ;;
          dev)
            shift
            export PI_CODING_AGENT_DIR="$DEV_DIR"
            exec "$PI_BIN" "$@"
            ;;
          *)
            echo "Unknown nixpi mode: ''${1-}" >&2
            echo "Use: nixpi [pi-args...] | nixpi dev [pi-args...] | nixpi mode <runtime|dev> [pi-args...]" >&2
            exit 2
            ;;
        esac
        ;;
      --help|-h|help)
        cat <<'EOF'
nixpi - primary CLI for the Nixpi assistant (powered by Pi SDK)

Usage:
  nixpi [pi-args...]                         Run Nixpi in normal/runtime mode
  nixpi dev [pi-args...]                     Run Nixpi in developer mode
  nixpi mode <runtime|dev> [pi-args...]      Explicit mode selector
  nixpi help                                 Show this help

Notes:
  - `pi` remains available as SDK/advanced CLI.
  - `nixpi` (default) uses PI_CODING_AGENT_DIR from nixpi.runtimePiDir.
  - `nixpi dev` uses PI_CODING_AGENT_DIR from nixpi.devPiDir.
EOF
        ;;
      *)
        export PI_CODING_AGENT_DIR="$RUNTIME_DIR"
        exec "$PI_BIN" "$@"
        ;;
    esac
  '';

  passwordPolicyCheck = pkgs.writeShellScript "nixpi-password-policy-check" ''
    set -euo pipefail

    # pam_exec with expose_authtok provides the candidate password on stdin.
    IFS= read -r password || exit 1

    if [ "''${#password}" -lt 16 ]; then
      echo "Password must be at least 16 characters." >&2
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

  primaryUser = config.nixpi.primaryUser;
  userHome = "/home/${primaryUser}";
  repoRoot = config.nixpi.repoRoot;
  runtimePiDir = config.nixpi.runtimePiDir;
  devPiDir = config.nixpi.devPiDir;
in
{
  options.nixpi.primaryUser = lib.mkOption {
    type = lib.types.str;
    default = "nixpi";
    example = "alex";
    description = ''
      Primary Linux username for the local human operator.
    '';
  };

  options.nixpi.repoRoot = lib.mkOption {
    type = lib.types.str;
    default = "/home/${config.nixpi.primaryUser}/Nixpi";
    example = "/home/alex/Nixpi";
    description = ''
      Repository root for Nixpi on disk.
    '';
  };

  options.nixpi.runtimePiDir = lib.mkOption {
    type = lib.types.str;
    default = "${config.nixpi.repoRoot}/.pi/agent";
    example = "/home/alex/Nixpi/.pi/agent";
    description = ''
      Runtime-mode PI_CODING_AGENT_DIR path.
    '';
  };

  options.nixpi.devPiDir = lib.mkOption {
    type = lib.types.str;
    default = "${config.nixpi.repoRoot}/.pi/agent-dev";
    example = "/home/alex/Nixpi/.pi/agent-dev";
    description = ''
      Developer-mode PI_CODING_AGENT_DIR path.
    '';
  };

  options.nixpi.desktopProfile = lib.mkOption {
    type = lib.types.enum [ "gnome" "preserve" ];
    default = "gnome";
    example = "preserve";
    description = ''
      Desktop profile behavior.
      - "gnome": manage a local default desktop stack (GDM + GNOME).
      - "preserve": keep desktop options defined by the host configuration.
    '';
  };

  config = {
    assertions = [
      {
        assertion = builtins.match "^[a-z_][a-z0-9_-]*$" primaryUser != null;
        message = "nixpi.primaryUser must be a valid Linux username (lowercase letters, digits, _, -, and starting with a lowercase letter or _).";
      }
      {
        assertion = lib.hasPrefix "/" repoRoot;
        message = "nixpi.repoRoot must be an absolute path.";
      }
      {
        assertion = lib.hasPrefix "/" runtimePiDir;
        message = "nixpi.runtimePiDir must be an absolute path.";
      }
      {
        assertion = lib.hasPrefix "/" devPiDir;
        message = "nixpi.devPiDir must be an absolute path.";
      }
    ];

  # Enable flakes and nix-command
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # nix-ld provides a dynamic linker shim so pre-compiled binaries (e.g. VS Code
  # remote server, downloaded tools) can run on NixOS, which normally lacks the
  # standard /lib/ld-linux path that most Linux binaries expect.
  programs.nix-ld.enable = true;

  # Networking
  networking.networkmanager.enable = true;
  # nftables is the modern Linux firewall (successor to iptables).
  # NixOS can generate rules from its firewall options and also accept raw
  # nftables syntax via extraInputRules (see below).
  networking.nftables.enable = true;

  # Local desktop policy for HDMI-first setup (display + Wi-Fi onboarding).
  # Default behavior mirrors standard GNOME installs. Hosts can opt into
  # preserve mode by setting:
  #   nixpi.desktopProfile = "preserve";
  services.xserver.enable = true;
  services.displayManager.gdm.enable = config.nixpi.desktopProfile == "gnome";
  services.desktopManager.gnome.enable = config.nixpi.desktopProfile == "gnome";
  services.xserver.xkb = {
    layout = "us";
  };

  # Timezone and locale
  time.timeZone = "Europe/Bucharest";
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  # SSH with security hardening
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = true;
      KbdInteractiveAuthentication = true;
      X11Forwarding = false;
      MaxAuthTries = 3;
      ClientAliveInterval = 300;
      ClientAliveCountMax = 2;
    };
  };

  # Web terminal interface (ttyd) that reuses localhost OpenSSH login.
  services.ttyd = {
    enable = true;
    port = 7681;
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

  # Password complexity policy for local account password changes.
  # Requirement: minimum 16 chars, at least one number, and at least one
  # special character.
  security.pam.services.passwd.rules.password.passwordPolicy = {
    order = config.security.pam.services.passwd.rules.password.unix.order - 20;
    control = "requisite";
    modulePath = "${pkgs.pam}/lib/security/pam_exec.so";
    args = [ "expose_authtok" "${passwordPolicyCheck}" ];
  };

  # Apply the same explicit checks to non-interactive password updates
  # (e.g. chpasswd).
  security.pam.services.chpasswd.rules.password.passwordPolicy = {
    order = config.security.pam.services.chpasswd.rules.password.unix.order - 20;
    control = "requisite";
    modulePath = "${pkgs.pam}/lib/security/pam_exec.so";
    args = [ "expose_authtok" "${passwordPolicyCheck}" ];
  };

  # Firewall policy: SSH is reachable from Tailscale + LAN (bootstrap), while
  # ttyd and Syncthing are Tailscale-only.
  # extraInputRules accepts raw nftables syntax that NixOS injects into the
  # input chain.
  networking.firewall = {
    enable = true;

    extraInputRules = ''
      # Allow SSH from Tailscale and local network
      ip saddr 100.0.0.0/8 tcp dport 22 accept
      ip6 saddr fd7a:115c:a1e0::/48 tcp dport 22 accept
      ip saddr 192.168.0.0/16 tcp dport 22 accept
      ip saddr 10.0.0.0/8 tcp dport 22 accept
      tcp dport 22 drop

      # Allow ttyd web terminal (port 7681) from Tailscale only
      ip saddr 100.0.0.0/8 tcp dport 7681 accept
      ip6 saddr fd7a:115c:a1e0::/48 tcp dport 7681 accept
      tcp dport 7681 drop

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

  # Tailscale VPN
  services.tailscale = {
    enable = true;
    # Keep Tailscale SSH disabled so OpenSSH remains the single SSH control plane.
    extraSetFlags = [ "--ssh=false" ];
  };
  # Note: we intentionally do NOT set trustedInterfaces = [ "tailscale0" ] here.
  # Instead, Tailscale traffic is controlled by the explicit IP-based rules above
  # (100.0.0.0/8 + fd7a:115c:a1e0::/48 for SSH), giving us per-service
  # granularity over what Tailscale peers can access rather than blanket-trusting
  # all traffic on the interface.
  # Tailscale needs UDP 41641 for direct WireGuard connections between nodes.
  networking.firewall.allowedUDPPorts = [ 41641 ];

  # Syncthing for file synchronization
  services.syncthing = {
    enable = true;
    user = primaryUser;
    dataDir = "${userHome}/.local/share/syncthing";
    configDir = "${userHome}/.config/syncthing";
    # Keep overrides disabled so users can still add folders/devices in UI.
    # Home directory is declared by default so it can be synced across devices.
    overrideFolders = false;
    overrideDevices = false;
    settings = {
      folders.home = {
        id = "home";
        label = "Home";
        path = userHome;
        devices = builtins.attrNames config.services.syncthing.settings.devices;
      };
      gui = {
        enabled = true;
        address = "0.0.0.0:8384";
      };
      options = {
        relaysEnabled = true;  # Allow relay servers for connectivity
      };
    };
  };

  # Keep existing account passwords mutable so first-install users retain
  # credentials configured in the NixOS installer.
  users.mutableUsers = true;

  # User configuration
  users.users.${primaryUser} = {
    isNormalUser = true;
    home = userHome;
    description = "Nixpi";
    extraGroups = [ "wheel" "networkmanager" ];
  };

  # Browser (CDP-compatible, for AI agent automation)
  programs.chromium.enable = true;

  # System packages
  # `with pkgs;` brings all pkgs attributes into scope so we can write `git`
  # instead of `pkgs.git` for every package in the list.
  environment.systemPackages = with pkgs; [
    # Development tools
    git
    gh
    nodejs_22
    vim
    neovim
    nano
    vscode

    # Language servers and linters
    nixd                          # Nix LSP
    bash-language-server          # Bash LSP
    shellcheck                    # Shell linter (used by bash-language-server)
    typescript-language-server    # TS/JS LSP

    # Network tools
    curl
    wget
    tailscale

    # Desktop helpers (local HDMI + Wi-Fi setup)
    networkmanagerapplet
    xorg.xrandr

    # Search and utility tools
    jq
    ripgrep
    fd
    tree
    htop

    # Terminal multiplexer (recommended for pi background tasks)
    tmux

    # AI coding tools (minimal Pi install path)
    piWrapper
    nixpiCli
  ];

  # Ensure ~/.local/bin is in PATH
  environment.localBinInPath = true;


  # Activation scripts run as root during `nixos-rebuild switch`, after the
  # system is built but before services start. They're used for one-time setup.
  # `lib.stringAfter [ "users" ]` ensures this runs after user accounts exist.
  #
  # IMPORTANT: These seeds are write-once. Files are only created if absent.
  # If you update piSystemPrompt/piDevSystemPrompt/settings above, existing
  # deployments will NOT receive the changes. To apply updates manually:
  #   rm <runtimePiDir>/SYSTEM.md <devPiDir>/SYSTEM.md
  #   sudo nixos-rebuild switch --flake .
  system.activationScripts.piConfig = lib.stringAfter [ "users" ] ''
    RUNTIME_PI_DIR="${runtimePiDir}"
    DEV_PI_DIR="${devPiDir}"

    mkdir -p "$RUNTIME_PI_DIR"/{sessions,extensions,skills,prompts,themes}
    mkdir -p "$DEV_PI_DIR"/{sessions,extensions,skills,prompts,themes}

    # Seed runtime SYSTEM.md if absent
    if [ ! -f "$RUNTIME_PI_DIR/SYSTEM.md" ]; then
      cat > "$RUNTIME_PI_DIR/SYSTEM.md" <<'SYSEOF'
${piSystemPrompt}
SYSEOF
    fi

    # Seed developer-mode SYSTEM.md if absent
    if [ ! -f "$DEV_PI_DIR/SYSTEM.md" ]; then
      cat > "$DEV_PI_DIR/SYSTEM.md" <<'SYSEOF'
${piDevSystemPrompt}
SYSEOF
    fi

    # Seed developer-mode settings if absent.
    # This keeps Pi-native behavior while preloading Nixpi skills/rules.
    if [ ! -f "$DEV_PI_DIR/settings.json" ]; then
      cat > "$DEV_PI_DIR/settings.json" <<'JSONEOF'
{
  "skills": [
    "${repoRoot}/infra/pi/skills"
  ],
  "packages": [
    "npm:@aaronmaturen/pi-context7"
  ]
}
JSONEOF
    fi

    # Share auth between runtime and dev profiles without duplicating secrets.
    if [ ! -e "$DEV_PI_DIR/auth.json" ]; then
      ln -sfn "$RUNTIME_PI_DIR/auth.json" "$DEV_PI_DIR/auth.json"
    fi

    chown -R ${primaryUser}:users "$RUNTIME_PI_DIR" "$DEV_PI_DIR"
  '';

  # Automatic garbage collection
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  # stateVersion tells NixOS which version's defaults to use for stateful data
  # (databases, state directories). It does NOT control package versions.
  # Never change this after install — it would break existing state assumptions.
  system.stateVersion = "25.11";
  };
}

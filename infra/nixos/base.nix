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
    - Protect secrets: never read ~/.pi/agent/auth.json, ~/.ssh/*, or .env files
  '';

  piSystemPrompt = ''
    You are an AI assistant running on nixpi, a NixOS-based AI-first workstation.

    ## Environment
    - OS: NixOS (declarative, flake-based)
    - Config repo: ~/Development/NixPi
    - Rebuild: cd ~/Development/NixPi && sudo nixos-rebuild switch --flake .
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

  nixpiCli = pkgs.writeShellScriptBin "nixpi" ''
    set -euo pipefail

    PI_BIN="${pkgs.llm-agents.pi}/bin/pi"
    RUNTIME_DIR="$HOME/.pi/agent"
    DEV_DIR="$HOME/.pi/agent-dev"

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
  - `nixpi` (default) uses PI_CODING_AGENT_DIR=~/.pi/agent.
  - `nixpi dev` uses PI_CODING_AGENT_DIR=~/.pi/agent-dev.
EOF
        ;;
      *)
        export PI_CODING_AGENT_DIR="$RUNTIME_DIR"
        exec "$PI_BIN" "$@"
        ;;
    esac
  '';
in
{
  # Enable flakes and nix-command
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  # Binary cache: pre-built packages from numtide so we don't compile llm-agents
  # from source. The public key verifies the cache hasn't been tampered with.
  nix.settings.substituters = [ "https://cache.numtide.com" ];
  nix.settings.trusted-public-keys = [ "numtide.cachix.org-1:2ps1kLBUWjxIneOy1Ber+6GZLDmYMbx7JKXHIUSHozk=" ];

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

  # Timezone and locale
  time.timeZone = "Europe/Bucharest";
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "ro_RO.UTF-8";
    LC_IDENTIFICATION = "ro_RO.UTF-8";
    LC_MEASUREMENT = "ro_RO.UTF-8";
    LC_MONETARY = "ro_RO.UTF-8";
    LC_NAME = "ro_RO.UTF-8";
    LC_NUMERIC = "ro_RO.UTF-8";
    LC_PAPER = "ro_RO.UTF-8";
    LC_TELEPHONE = "ro_RO.UTF-8";
    LC_TIME = "ro_RO.UTF-8";
  };

  # SSH with security hardening
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      X11Forwarding = false;
      MaxAuthTries = 3;
      ClientAliveInterval = 300;
      ClientAliveCountMax = 2;
    };
  };

  # Firewall: restrict SSH and Syncthing to Tailscale and local network.
  # extraInputRules accepts raw nftables syntax that NixOS injects into the
  # input chain. Multiple modules can set extraInputRules — NixOS concatenates
  # them all (e.g. desktop.nix adds RDP rules on top of these).
  networking.firewall = {
    enable = true;

    extraInputRules = ''
      # Allow SSH from Tailscale and local network
      ip saddr 100.0.0.0/8 tcp dport 22 accept
      ip saddr 192.168.0.0/16 tcp dport 22 accept
      ip saddr 10.0.0.0/8 tcp dport 22 accept
      tcp dport 22 drop

      # Allow Syncthing GUI (port 8384) from Tailscale and local network
      ip saddr 100.0.0.0/8 tcp dport 8384 accept
      ip saddr 192.168.0.0/16 tcp dport 8384 accept
      ip saddr 10.0.0.0/8 tcp dport 8384 accept
      tcp dport 8384 drop

      # Allow Syncthing sync (port 22000) from Tailscale and local network
      ip saddr 100.0.0.0/8 tcp dport 22000 accept
      ip saddr 100.0.0.0/8 udp dport 22000 accept
      ip saddr 192.168.0.0/16 tcp dport 22000 accept
      ip saddr 192.168.0.0/16 udp dport 22000 accept
      ip saddr 10.0.0.0/8 tcp dport 22000 accept
      ip saddr 10.0.0.0/8 udp dport 22000 accept
      tcp dport 22000 drop
      udp dport 22000 drop
    '';
  };

  # Tailscale VPN
  services.tailscale.enable = true;
  # Note: we intentionally do NOT set trustedInterfaces = [ "tailscale0" ] here.
  # Instead, Tailscale traffic is controlled by the explicit IP-based rules above
  # (100.0.0.0/8), giving us per-service granularity over what Tailscale peers
  # can access rather than blanket-trusting all traffic on the interface.
  # Tailscale needs UDP 41641 for direct WireGuard connections between nodes.
  networking.firewall.allowedUDPPorts = [ 41641 ];

  # Syncthing for file synchronization
  services.syncthing = {
    enable = true;
    user = "nixpi";
    dataDir = "/home/nixpi/.local/share/syncthing";
    configDir = "/home/nixpi/.config/syncthing";
    # overrideFolders/overrideDevices = false: let the user add folders/devices
    # via the Syncthing web UI without NixOS wiping them on each rebuild.
    # When true, NixOS would enforce only the folders/devices declared here.
    overrideFolders = false;
    overrideDevices = false;
    settings = {
      gui = {
        enabled = true;
        address = "0.0.0.0:8384";
      };
      options = {
        relaysEnabled = true;  # Allow relay servers for connectivity
      };
    };
  };

  # User configuration
  users.users.nixpi = {
    isNormalUser = true;
    home = "/home/nixpi";
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

    # Network tools
    curl
    wget
    tailscale

    # Search and utility tools
    jq
    ripgrep
    fd
    tree
    htop

    # Terminal multiplexer (recommended for pi background tasks)
    tmux

    # AI coding tools (Nix-packaged via llm-agents.nix)
    llm-agents.claude-code
    llm-agents.pi
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
  #   rm ~/.pi/agent/SYSTEM.md ~/.pi/agent-dev/SYSTEM.md
  #   sudo nixos-rebuild switch --flake .
  system.activationScripts.piConfig = lib.stringAfter [ "users" ] ''
    RUNTIME_PI_DIR="/home/nixpi/.pi/agent"
    DEV_PI_DIR="/home/nixpi/.pi/agent-dev"

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
    "/home/nixpi/Development/NixPi/infra/pi/skills"
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

    chown -R nixpi:users "$RUNTIME_PI_DIR" "$DEV_PI_DIR"
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
}

{ config, pkgs, lib, ... }:

let
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
    - Prefer declarative Nix changes over imperative system mutation
    - Never modify /etc or systemd units directly; edit NixOS config instead
    - Protect secrets: never read ~/.pi/agent/auth.json, ~/.ssh/*, or .env files
  '';
in
{
  # Enable flakes and nix-command
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.settings.substituters = [ "https://cache.numtide.com" ];
  nix.settings.trusted-public-keys = [ "numtide.cachix.org-1:2ps1kLBUWjxIneOy1Ber+6GZLDmYMbx7JKXHIUSHozk=" ];

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # Allow running dynamically linked executables
  programs.nix-ld.enable = true;

  # Networking
  networking.networkmanager.enable = true;
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
      PasswordAuthentication = true;
      KbdInteractiveAuthentication = false;
      X11Forwarding = false;
      MaxAuthTries = 3;
      ClientAliveInterval = 300;
      ClientAliveCountMax = 2;
    };
  };

  # Firewall: restrict SSH and Syncthing to Tailscale and local network
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
  networking.firewall.trustedInterfaces = [ "tailscale0" ];
  networking.firewall.allowedUDPPorts = [ 41641 ];

  # Syncthing for file synchronization
  services.syncthing = {
    enable = true;
    user = "nixpi";
    dataDir = "/home/nixpi/.local/share/syncthing";
    configDir = "/home/nixpi/.config/syncthing";
    overrideFolders = false;  # Allow user to configure folders via web UI
    overrideDevices = false;  # Allow user to configure devices via web UI
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
  ];

  # Ensure ~/.local/bin is in PATH
  environment.localBinInPath = true;


  # Seed pi-coding-agent config (non-destructive: only creates if missing)
  system.activationScripts.piConfig = lib.stringAfter [ "users" ] ''
    PI_DIR="/home/nixpi/.pi/agent"
    mkdir -p "$PI_DIR"/{sessions,extensions,skills,prompts,themes}

    # Seed SYSTEM.md if absent
    if [ ! -f "$PI_DIR/SYSTEM.md" ]; then
      cat > "$PI_DIR/SYSTEM.md" <<'SYSEOF'
${piSystemPrompt}
SYSEOF
    fi

    chown -R nixpi:users "$PI_DIR"
  '';

  # Automatic garbage collection
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  system.stateVersion = "25.11";
}

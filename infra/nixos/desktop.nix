{ config, pkgs, lib, ... }:

let
  # Pi Coding Agent - npx wrapper (not yet in nixpkgs)
  pi = pkgs.writeShellScriptBin "pi" ''
    exec ${pkgs.nodejs_22}/bin/npx --yes @mariozechner/pi-coding-agent@latest "$@"
  '';
in
{
  # Enable flakes and nix-command
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Allow unfree packages (required for claude-code)
  nixpkgs.config.allowUnfree = true;

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

  # X11 and XFCE Desktop (lightweight)
  services.xserver.enable = true;
  services.xserver.displayManager.lightdm.enable = true;
  services.xserver.desktopManager.xfce.enable = true;
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # Audio (PipeWire)
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # Printing
  services.printing.enable = true;

  # SSH with security hardening
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = true;
    };
  };

  # Firewall: restrict inbound SSH and Guacamole to Tailscale and local network only
  networking.firewall = {
    enable = true;

    # Allow SSH and Guacamole only from specific networks (inbound)
    extraInputRules = ''
      # Allow SSH from Tailscale interface (100.x.x.x)
      ip saddr 100.0.0.0/8 tcp dport 22 accept

      # Allow SSH from local network (192.168.0.0/16 and 10.0.0.0/8)
      ip saddr 192.168.0.0/16 tcp dport 22 accept
      ip saddr 10.0.0.0/8 tcp dport 22 accept

      # Drop SSH from anywhere else
      tcp dport 22 drop

      # Allow Syncthing sync (port 22000) from Tailscale and local network
      ip saddr 100.0.0.0/8 tcp dport 22000 accept
      ip saddr 100.0.0.0/8 udp dport 22000 accept
      ip saddr 192.168.0.0/16 tcp dport 22000 accept
      ip saddr 192.168.0.0/16 udp dport 22000 accept
      ip saddr 10.0.0.0/8 tcp dport 22000 accept
      ip saddr 10.0.0.0/8 udp dport 22000 accept
      tcp dport 22000 drop
      udp dport 22000 drop

      # Allow VS Code Server web editor via HTTPS (port 8443) from Tailscale and local network
      ip saddr 100.0.0.0/8 tcp dport 8443 accept
      ip saddr 192.168.0.0/16 tcp dport 8443 accept
      ip saddr 10.0.0.0/8 tcp dport 8443 accept
      tcp dport 8443 drop

      # code-server listens only on localhost (8080), nginx proxies via HTTPS

      # RDP is restricted to localhost only (no external access needed)
      # Guacamole connects to xrdp via localhost, so no firewall rule needed
    '';
  };

  # Tailscale VPN
  services.tailscale = {
    enable = true;
    permitCertUid = "nixpi";
  };

  # xrdp for RDP access to XFCE desktop
  services.xrdp = {
    enable = true;
    defaultWindowManager = "startxfce4";
    openFirewall = false;  # We'll manage firewall rules manually
  };

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
        address = "127.0.0.1:8384";  # Local only, accessible via SSH tunnel or local network
      };
      options = {
        relaysEnabled = true;  # Allow relay servers for connectivity
      };
    };
  };

  # VS Code Server (web-based code editor)
  services.code-server = {
    enable = true;
    user = "nixpi";
    host = "127.0.0.1";  # Listen only on localhost
    port = 8080;
    auth = "password";
    extraEnvironment = {
      PASSWORD = "Al3xandru@#";
    };
    extraArguments = [
      "--disable-telemetry"
    ];
  };

  # Nginx reverse proxy for code-server with HTTPS via Tailscale certificates
  services.nginx = {
    enable = true;
    recommendedProxySettings = true;
    virtualHosts."code-server" = {
      listen = [
        { addr = "0.0.0.0"; port = 8443; ssl = true; }
      ];
      serverName = "_";
      sslCertificate = "/var/lib/tailscale/certs/nixpi.crt";
      sslCertificateKey = "/var/lib/tailscale/certs/nixpi.key";
      locations."/" = {
        proxyPass = "http://127.0.0.1:8080";
        proxyWebsockets = true;
        extraProxyHeaders = {
          "Connection" = "upgrade";
          "Upgrade" = "$http_upgrade";
        };
      };
    };
  };

  # User configuration
  users.users.nixpi = {
    isNormalUser = true;
    description = "Nixpi";
    extraGroups = [ "wheel" "networkmanager" ];
  };

  # Browser
  programs.firefox.enable = true;

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

    # Code editors
    vscodium     # Lightweight VS Code without telemetry (binary: 'codium')

    # AI coding tools
    claude-code  # Official nixpkgs package (Anthropic) (binary: 'claude')
    pi           # npx wrapper - Pi Coding Agent (not in nixpkgs yet) (binary: 'pi')
  ];

  # Ensure ~/.local/bin is in PATH
  environment.shellInit = ''
    export PATH="$HOME/.local/bin:$PATH"
  '';


  system.stateVersion = "25.11";
}

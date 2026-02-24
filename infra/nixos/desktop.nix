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

      # Allow Guacamole web interface (port 8080) from Tailscale and local network
      ip saddr 100.0.0.0/8 tcp dport 8080 accept
      ip saddr 192.168.0.0/16 tcp dport 8080 accept
      ip saddr 10.0.0.0/8 tcp dport 8080 accept
      tcp dport 8080 drop

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
    defaultWindowManager = "${pkgs.xfce.xfce4-session}/bin/xfce4-session";
    openFirewall = false;  # We'll manage firewall rules manually
  };

  # Guacamole proxy daemon
  services.guacamole-server = {
    enable = true;
    host = "127.0.0.1";  # Only listen on localhost
    port = 4822;
    userMappingXml = ./guacamole-user-mapping.xml;
  };

  # Guacamole web interface
  services.guacamole-client = {
    enable = true;
    enableWebserver = true;  # Enable built-in Tomcat on port 8080
    settings = {
      guacd-hostname = "127.0.0.1";
      guacd-port = "4822";
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

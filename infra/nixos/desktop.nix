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

  # Firewall: restrict inbound SSH to Tailscale and local network only
  networking.firewall = {
    enable = true;

    # Allow SSH only from specific networks (inbound)
    extraInputRules = ''
      # Allow SSH from Tailscale interface (100.x.x.x)
      ip saddr 100.0.0.0/8 tcp dport 22 accept

      # Allow SSH from local network (192.168.0.0/16 and 10.0.0.0/8)
      ip saddr 192.168.0.0/16 tcp dport 22 accept
      ip saddr 10.0.0.0/8 tcp dport 22 accept

      # Drop SSH from anywhere else
      tcp dport 22 drop
    '';
  };

  # Tailscale VPN
  services.tailscale.enable = true;


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
    vscodium     # Lightweight VS Code without telemetry

    # AI coding tools
    claude-code  # Official nixpkgs package (Anthropic)
    pi           # npx wrapper - Pi Coding Agent (not in nixpkgs yet)
  ];

  # Ensure ~/.local/bin is in PATH
  environment.shellInit = ''
    export PATH="$HOME/.local/bin:$PATH"
  '';


  system.stateVersion = "25.11";
}

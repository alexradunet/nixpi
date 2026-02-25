{ config, pkgs, lib, ... }:

{
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

  # xrdp for remote desktop access
  services.xrdp = {
    enable = true;
    defaultWindowManager = "startxfce4";
    openFirewall = false;
  };

  # Firewall: restrict RDP to Tailscale and local network
  networking.firewall.extraInputRules = ''
    # Allow RDP from Tailscale and local network
    ip saddr 100.0.0.0/8 tcp dport 3389 accept
    ip saddr 192.168.0.0/16 tcp dport 3389 accept
    ip saddr 10.0.0.0/8 tcp dport 3389 accept
    tcp dport 3389 drop
  '';
}

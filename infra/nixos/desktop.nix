# Desktop UI module — only loaded for hosts listed in desktopHosts (see flake.nix).
# NixOS deep-merges this with base.nix, so options like extraInputRules are
# concatenated (not overwritten).
{ config, pkgs, lib, ... }:

{
  # "xserver" is the historical NixOS option name for the display server config.
  # It now covers Wayland too — the name is kept for backwards compatibility.
  services.xserver.enable = true;
  services.xserver.displayManager.lightdm.enable = true;
  services.xserver.desktopManager.xfce.enable = true;
  services.xserver.xkb = {
    layout = "us";
  };

  # Audio (PipeWire)
  # PulseAudio is explicitly disabled because PipeWire replaces it.
  # Both cannot run at the same time. PipeWire's `pulse.enable` provides
  # a PulseAudio-compatible interface for apps that expect it.
  services.pulseaudio.enable = false;
  # rtkit grants realtime scheduling priority to audio processes,
  # preventing audio glitches under CPU load.
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
    # openFirewall = false: we manage firewall rules ourselves via
    # extraInputRules below (restricting to Tailscale + LAN) instead of
    # letting xrdp open port 3389 to all interfaces.
    openFirewall = false;
  };

  # Firewall: restrict RDP to Tailscale and local network.
  # NixOS concatenates this with base.nix's extraInputRules — both sets of
  # rules end up in the same nftables input chain.
  networking.firewall.extraInputRules = ''
    # Allow RDP from Tailscale and local network
    ip saddr 100.0.0.0/8 tcp dport 3389 accept
    ip saddr 192.168.0.0/16 tcp dport 3389 accept
    ip saddr 10.0.0.0/8 tcp dport 3389 accept
    tcp dport 3389 drop
  '';
}

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

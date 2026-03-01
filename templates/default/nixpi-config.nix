# Nixpi configuration — edit this file to customize your server.
# Run `sudo nixos-rebuild switch --flake .` after changes.
{ config, lib, ... }:

{
  # --- Identity ---
  networking.hostName = "nixpi";  # Change to your hostname
  nixpi.primaryUser = "nixpi";    # Change to your Linux username
  nixpi.timeZone = "UTC";         # Change to your timezone

  # --- Boot loader ---
  # UEFI (most modern machines): systemd-boot + disable GRUB.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.grub.enable = false;
  # BIOS / legacy boot: uncomment the next two lines and comment out the three above.
  # boot.loader.grub.enable = true;
  # boot.loader.grub.devices = [ "/dev/sda" ];  # adjust to your disk

  # --- Path override ---
  # nixpi.repoRoot = "/home/youruser/Nixpi";  # uncomment if not using ~/Nixpi/

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

{ config, pkgs, ... }:

{
  networking.hostName = "nixpi-vm";

  networking.networkmanager.enable = true;

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Better VM guest integration (QEMU/Boxes/SPICE)
  services.qemuGuest.enable = true;
  services.spice-vdagentd.enable = true;

  # Useful for remote administration later
  services.openssh.enable = true;
  services.openssh.settings.PermitRootLogin = "no";

  users.users.nixpi = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
    initialPassword = "changeme";
  };

  environment.systemPackages = with pkgs; [
    git
    curl
    wget
    vim
    nodejs_22
  ];

  system.stateVersion = "25.11";
}

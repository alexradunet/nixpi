{ config, pkgs, ... }:
let
  pi = pkgs.writeShellScriptBin "pi" ''
    exec ${pkgs.nodejs_22}/bin/npx --yes @mariozechner/pi-coding-agent@0.54.2 "$@"
  '';
in
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

  # Enable Tailscale daemon (tailscale CLI included via package below)
  services.tailscale.enable = true;

  users.users.nixpi = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
    initialPassword = "changeme";
  };

  environment.systemPackages = with pkgs; [
    git
    gh
    tailscale
    curl
    wget
    vim
    nodejs_22
    pi
  ];

  system.stateVersion = "25.11";
}

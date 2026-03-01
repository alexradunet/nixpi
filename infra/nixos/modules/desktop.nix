# Desktop module — GNOME desktop environment with GDM.
#
# When enabled, provisions a full GNOME desktop with GDM login manager.
# Includes desktop helper packages (networkmanagerapplet, xrandr).
{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.nixpi.desktop;
in
{
  options.nixpi.desktop = {
    enable = lib.mkEnableOption "GNOME desktop environment with GDM";
  };

  config = lib.mkIf cfg.enable {
    services.xserver.enable = true;
    services.displayManager.gdm.enable = true;
    services.desktopManager.gnome.enable = true;
    services.xserver.xkb.layout = "us";

    programs.chromium.enable = true;

    environment.systemPackages = with pkgs; [
      networkmanagerapplet
      xorg.xrandr
      vscode
    ];
  };
}

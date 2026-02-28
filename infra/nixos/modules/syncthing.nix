# Syncthing module — file synchronization service.
#
# When enabled, provisions Syncthing with a default ~/Shared folder,
# GUI on 0.0.0.0:8384, and firewall restricted to Tailscale.
{ config, pkgs, lib, ... }:

let
  cfg = config.nixpi.syncthing;
  primaryUser = config.nixpi.primaryUser;
  userHome = "/home/${primaryUser}";
in
{
  options.nixpi.syncthing = {
    enable = lib.mkEnableOption "Syncthing file synchronization";

    sharedFolder = lib.mkOption {
      type = lib.types.str;
      default = "${userHome}/Shared";
      description = "Path to the default shared folder.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.syncthing = {
      enable = true;
      user = primaryUser;
      dataDir = "${userHome}/.local/share/syncthing";
      configDir = "${userHome}/.config/syncthing";
      overrideFolders = false;
      overrideDevices = false;
      settings = {
        folders.home = {
          id = "shared";
          label = "Shared";
          path = cfg.sharedFolder;
          devices = builtins.attrNames config.services.syncthing.settings.devices;
        };
        gui = {
          enabled = true;
          address = "0.0.0.0:8384";
        };
        options = {
          relaysEnabled = true;
        };
      };
    };

    system.activationScripts.nixpiSyncthingShared = lib.stringAfter [ "users" ] ''
      install -d -o ${primaryUser} -g users "${cfg.sharedFolder}"
    '';

    networking.firewall.extraInputRules = ''
      # Allow Syncthing GUI (port 8384) from Tailscale only
      ip saddr 100.0.0.0/8 tcp dport 8384 accept
      ip6 saddr fd7a:115c:a1e0::/48 tcp dport 8384 accept
      tcp dport 8384 drop

      # Allow Syncthing sync (port 22000) from Tailscale only
      ip saddr 100.0.0.0/8 tcp dport 22000 accept
      ip saddr 100.0.0.0/8 udp dport 22000 accept
      ip6 saddr fd7a:115c:a1e0::/48 tcp dport 22000 accept
      ip6 saddr fd7a:115c:a1e0::/48 udp dport 22000 accept
      tcp dport 22000 drop
      udp dport 22000 drop
    '';
  };
}
